"""HostProfileRepository — CRUD for HostProfile using user_id (not host_id).

HostProfile is 1-1 with User; the "host scope" is user_id, not a foreign key named host_id.
Therefore, we use direct queries rather than HostScopedRepository (which requires host_id field).
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app import models
from app.repositories.audit import write_change_log
from app.schemas.host_profile import HostProfileCreate, HostProfileUpdate


class HostProfileRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_user_id(self, user_id: int) -> Optional[models.HostProfile]:
        return (
            self.db.query(models.HostProfile)
            .filter(models.HostProfile.user_id == user_id)
            .first()
        )

    def get_by_id(self, profile_id: int) -> Optional[models.HostProfile]:
        return self.db.get(models.HostProfile, profile_id)

    def create(
        self, data: HostProfileCreate, actor_id: Optional[int] = None
    ) -> models.HostProfile:
        now = datetime.utcnow()
        profile = models.HostProfile(
            user_id=data.user_id,
            verified=False,
            bank_account_number=data.bank_account_number,
            bank_name=data.bank_name,
            bank_account_holder=data.bank_account_holder,
            tax_id=data.tax_id,
            payout_schedule=data.payout_schedule or "monthly",
            created_at=now,
            updated_at=now,
        )
        self.db.add(profile)
        self.db.flush()  # get profile.id before audit log
        write_change_log(
            self.db,
            entity_type="host_profile",
            entity_id=profile.id,
            actor_id=actor_id,
            action="create",
            before=None,
            after={"user_id": profile.user_id},
        )
        return profile

    def update(
        self,
        profile: models.HostProfile,
        data: HostProfileUpdate,
        actor_id: Optional[int] = None,
    ) -> models.HostProfile:
        before_snapshot = {
            "bank_account_number": profile.bank_account_number,
            "bank_name": profile.bank_name,
            "bank_account_holder": profile.bank_account_holder,
            "tax_id": profile.tax_id,
            "payout_schedule": profile.payout_schedule,
        }
        update_fields = data.model_dump(exclude_none=True)
        for key, value in update_fields.items():
            setattr(profile, key, value)
        profile.updated_at = datetime.utcnow()
        self.db.flush()
        write_change_log(
            self.db,
            entity_type="host_profile",
            entity_id=profile.id,
            actor_id=actor_id,
            action="update",
            before=before_snapshot,
            after=update_fields,
        )
        return profile

    def set_cccd_paths(
        self,
        profile: models.HostProfile,
        front_path: Optional[str],
        back_path: Optional[str],
        cccd_number_hash: Optional[str] = None,
        actor_id: Optional[int] = None,
    ) -> models.HostProfile:
        if front_path is not None:
            profile.cccd_front_path = front_path
        if back_path is not None:
            profile.cccd_back_path = back_path
        if cccd_number_hash is not None:
            profile.cccd_number_hash = cccd_number_hash
        profile.updated_at = datetime.utcnow()
        self.db.flush()
        write_change_log(
            self.db,
            entity_type="host_profile",
            entity_id=profile.id,
            actor_id=actor_id,
            action="update",
            before=None,
            after={"cccd_uploaded": True},
        )
        return profile
