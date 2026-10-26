"""Versioned deposit snapshots for new Activity transactions.

Admin owns the policy table.  Transaction creators only ask this service for a
snapshot and persist it alongside the new row; they never reread global policy
when rendering or collecting money later.  That protects historical amounts
from a future percentage edit.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy.orm import Session

from app import models

DEFAULT_SHORT_STAY_PRIMARY_DEPOSIT_BPS = 1000  # 10%
DEFAULT_LONG_TERM_PLATFORM_DEPOSIT_BPS = 5000  # 50%, owner receives remainder


def active_snapshot(db: Session, *, at: datetime | None = None) -> dict:
    point = at or datetime.utcnow()
    item = (
        db.query(models.ActivityPolicyVersion)
        .filter(models.ActivityPolicyVersion.effective_at <= point)
        .order_by(
            models.ActivityPolicyVersion.effective_at.desc(),
            models.ActivityPolicyVersion.policy_version.desc(),
        )
        .first()
    )
    if item is None:
        return {
            "policy_version": 0,
            "short_stay_primary_deposit_bps": DEFAULT_SHORT_STAY_PRIMARY_DEPOSIT_BPS,
            "long_term_platform_deposit_bps": DEFAULT_LONG_TERM_PLATFORM_DEPOSIT_BPS,
            "provenance": "default",
        }
    return {
        "policy_version": item.policy_version,
        "short_stay_primary_deposit_bps": item.short_stay_primary_deposit_bps,
        "long_term_platform_deposit_bps": item.long_term_platform_deposit_bps,
        "provenance": "admin_policy_version",
    }


def apply_short_stay_snapshot(db: Session, reservation: models.Reservation) -> None:
    snapshot = active_snapshot(db)
    bps = int(snapshot["short_stay_primary_deposit_bps"])
    reservation.activity_deposit_policy_version = int(snapshot["policy_version"])
    reservation.activity_primary_deposit_bps = bps
    # ``deposit_paid`` remains the historical record of actual receipt.  This
    # is the required amount for the new policy, not a fake payment.
    reservation.activity_primary_deposit_amount = round(
        float(reservation.total_amount or 0) * bps / 10_000, 2
    )


def apply_long_term_snapshot(db: Session, journey: models.RentalJourney) -> None:
    snapshot = active_snapshot(db)
    bps = int(snapshot["long_term_platform_deposit_bps"])
    journey.deposit_policy_version = int(snapshot["policy_version"])
    journey.platform_deposit_bps = bps


def long_term_split_bps(journey: models.RentalJourney) -> tuple[int, int, str]:
    """Use the journey snapshot; legacy rows retain their historical 50/50."""
    platform_bps = (
        int(journey.platform_deposit_bps)
        if journey.platform_deposit_bps is not None
        else DEFAULT_LONG_TERM_PLATFORM_DEPOSIT_BPS
    )
    platform_bps = max(0, min(10_000, platform_bps))
    provenance = "transaction_snapshot" if journey.deposit_policy_version is not None else "legacy_default"
    return platform_bps, 10_000 - platform_bps, provenance
