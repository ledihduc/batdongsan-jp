"""Delegation invitation service — token generation, lookup, expiry.

Handles:
  - Token generation (URL-safe, single-use, 7-day TTL per AC-01)
  - Looking up an invitation by token or ID
  - Validation (token not expired, not used, status=pending)
  - Resolving invitee user_id by phone/email
  - Email notification placeholder (phase-08 wires in real delivery)

Security: tokens are URL-safe random 64 chars, never logged in plain text.
"""

from __future__ import annotations

import logging
import secrets
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.delegation import DelegationInvitation

logger = logging.getLogger(__name__)

# Token TTL: 7 days per AC-01
_INVITATION_TTL_DAYS = 7


class InvitationNotFound(Exception):
    """Raised when a token does not correspond to a known invitation."""


class InvitationExpired(Exception):
    """Raised when an invitation token is past its TTL."""


class InvitationAlreadyUsed(Exception):
    """Raised when a single-use token has already been accepted."""


class InvitationInvalidStatus(Exception):
    """Raised when invitation status is not 'pending' for accept/reject."""


class DelegationInvitationService:
    """Service for managing delegation invitation tokens and their lifecycle."""

    def __init__(self, db: Session) -> None:
        self.db = db

    # ------------------------------------------------------------------
    # Token creation
    # ------------------------------------------------------------------

    def generate_token(self) -> str:
        """Generate a URL-safe, 64-char single-use invitation token (AC-01).

        Uses secrets.token_urlsafe which produces cryptographically secure
        random bytes. token_urlsafe(48) gives ~64 chars of base64url output.
        """
        return secrets.token_urlsafe(48)[:64]

    def compute_expiry(self, from_dt: Optional[datetime] = None) -> datetime:
        """Compute invitation expiry: created_at + 7 days (AC-01)."""
        base = from_dt or datetime.utcnow()
        return base + timedelta(days=_INVITATION_TTL_DAYS)

    # ------------------------------------------------------------------
    # Lookup
    # ------------------------------------------------------------------

    def get_by_token(self, token: str) -> Optional[DelegationInvitation]:
        """Look up an invitation by token. Returns None if not found."""
        return (
            self.db.query(DelegationInvitation)
            .filter(DelegationInvitation.token == token)
            .first()
        )

    def get_by_id(self, invitation_id: str) -> Optional[DelegationInvitation]:
        """Look up an invitation by its UUID primary key."""
        return (
            self.db.query(DelegationInvitation)
            .filter(DelegationInvitation.id == invitation_id)
            .first()
        )

    def get_pending_for_owner_invitee(
        self, owner_id: int, invited_phone_or_email: str
    ) -> Optional[DelegationInvitation]:
        """AC-10b: find any pending invitation for same (owner, invitee) pair."""
        return (
            self.db.query(DelegationInvitation)
            .filter(
                DelegationInvitation.owner_id == owner_id,
                DelegationInvitation.invited_phone_or_email == invited_phone_or_email,
                DelegationInvitation.status == "pending",
            )
            .first()
        )

    # ------------------------------------------------------------------
    # Validation helpers
    # ------------------------------------------------------------------

    def validate_for_accept(self, invitation: DelegationInvitation) -> None:
        """Validate invitation is usable for acceptance.

        Raises:
          InvitationExpired: TTL exceeded.
          InvitationAlreadyUsed: token was already consumed.
          InvitationInvalidStatus: status is not 'pending'.
        """
        now = datetime.utcnow()

        if invitation.status != "pending":
            raise InvitationInvalidStatus(
                f"Invitation status is '{invitation.status}', expected 'pending'"
            )
        if invitation.expires_at < now:
            raise InvitationExpired(
                f"Invitation expired at {invitation.expires_at.isoformat()}"
            )
        if invitation.token_used_at is not None:
            raise InvitationAlreadyUsed(
                f"Invitation token was already used at {invitation.token_used_at.isoformat()}"
            )

    def validate_for_reject(self, invitation: DelegationInvitation) -> None:
        """Validate invitation is in a state that allows rejection."""
        if invitation.status != "pending":
            raise InvitationInvalidStatus(
                f"Invitation status is '{invitation.status}', expected 'pending'"
            )

    # ------------------------------------------------------------------
    # User resolution
    # ------------------------------------------------------------------

    def resolve_invited_user_id(
        self, db: Session, invited_phone_or_email: str
    ) -> Optional[int]:
        """Look up user ID by phone or email at invite creation time.

        If the invitee already has an account, we capture their user_id on the
        invitation row to speed up acceptance validation. Returns None if no
        existing account (non-blocking — they may register before accepting).
        """
        from sqlalchemy import or_ as _or
        from app import models

        # Search by email or phone; guard against empty strings
        if not invited_phone_or_email.strip():
            return None

        user = (
            db.query(models.User)
            .filter(
                _or(
                    models.User.email == invited_phone_or_email,
                    models.User.phone == invited_phone_or_email
                    if hasattr(models.User, "phone")
                    else False,
                )
            )
            .first()
        )
        return int(user.id) if user is not None else None

    # ------------------------------------------------------------------
    # Mark consumed
    # ------------------------------------------------------------------

    def mark_consumed(
        self, invitation: DelegationInvitation, accepting_user_id: int
    ) -> None:
        """Mark invitation as accepted and single-use token consumed (AC-01)."""
        now = datetime.utcnow()
        invitation.token_used_at = now
        invitation.accepted_at = now
        invitation.status = "accepted"
        if invitation.invited_user_id is None:
            invitation.invited_user_id = accepting_user_id
        self.db.flush()

    def mark_rejected(self, invitation: DelegationInvitation) -> None:
        """Mark invitation as rejected by invitee."""
        invitation.status = "rejected"
        invitation.rejected_at = datetime.utcnow()
        self.db.flush()

    def mark_revoked_by_owner(self, invitation: DelegationInvitation) -> None:
        """Mark invitation as revoked by the sender (owner)."""
        invitation.status = "revoked_by_owner"
        invitation.revoked_at = datetime.utcnow()
        self.db.flush()

    # ------------------------------------------------------------------
    # Notification (placeholder — Phase 08 wires real delivery)
    # ------------------------------------------------------------------

    def send_invite_notification(
        self,
        invitation: DelegationInvitation,
        accept_url: str,
    ) -> None:
        """Send invitation notification to invitee.

        v1: logs intent only. Phase-08 wires actual email/SMS delivery.
        The accept_url embeds the token for deep-link into the Flutter app.
        """
        logger.info(
            "[DELEGATION INVITE] owner_id=%d sent invite to '%s' (invitation_id=%s, expires=%s). "
            "Accept URL: %s [phase-08 will send real email/SMS]",
            invitation.owner_id,
            invitation.invited_phone_or_email,
            invitation.id,
            invitation.expires_at.isoformat(),
            accept_url,
        )

    def send_revocation_notification(
        self, invitation: DelegationInvitation
    ) -> None:
        """Notify invitee that invitation was revoked. v1: log only."""
        logger.info(
            "[DELEGATION INVITE REVOKED] invitation_id=%s owner_id=%d invitee=%s",
            invitation.id,
            invitation.owner_id,
            invitation.invited_phone_or_email,
        )
