"""Async repository for jp_addresses table.

Pattern: thin data-access layer — no business logic.
Follows the new arch pattern (app/repositories/jp/) per CLAUDE.md.

Note: Uses SQLAlchemy async session for consistency with new arch pattern.
The sync session variant is available when needed by passing sync Session.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.jp.address import JpAddress
from app.schemas.jp.address import JpAddressCreate


class JpAddressRepository:
    """Repository for jp_addresses table operations.

    Uses synchronous SQLAlchemy session (consistent with existing repos in this
    codebase — async migration is tracked in AI-REFACTOR-PLAN).
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_postal_code(self, postal_code: str) -> list[JpAddress]:
        """Return all address records for a given postal code.

        Args:
            postal_code: 7-digit code without hyphen (already normalized by caller).

        Returns:
            List of JpAddress ORM objects (may be empty if not cached).
        """
        stmt = (
            select(JpAddress)
            .where(JpAddress.postal_code == postal_code)
            .order_by(JpAddress.id)
        )
        return list(self.db.execute(stmt).scalars().all())

    def get_by_id(self, address_id: int) -> Optional[JpAddress]:
        """Fetch a single address record by PK.

        Args:
            address_id: Primary key.

        Returns:
            JpAddress or None if not found.
        """
        stmt = select(JpAddress).where(JpAddress.id == address_id)
        return self.db.execute(stmt).scalar_one_or_none()

    def create(self, data: JpAddressCreate) -> JpAddress:
        """Persist a new jp_address record.

        Args:
            data: Validated JpAddressCreate schema.

        Returns:
            The newly created JpAddress ORM object (flushed, not yet committed).
        """
        record = JpAddress(**data.model_dump())
        self.db.add(record)
        self.db.flush()
        return record

    def bulk_create(self, records: list[JpAddressCreate]) -> list[JpAddress]:
        """Persist multiple address records in a single flush.

        Args:
            records: List of validated JpAddressCreate schemas.

        Returns:
            List of created JpAddress ORM objects.
        """
        orm_objects = [JpAddress(**r.model_dump()) for r in records]
        self.db.add_all(orm_objects)
        self.db.flush()
        return orm_objects

    def exists_for_postal_code(self, postal_code: str) -> bool:
        """Check whether any record exists for the given postal code.

        Used to decide whether to call the external API or serve from cache.
        """
        stmt = select(JpAddress.id).where(JpAddress.postal_code == postal_code).limit(1)
        return self.db.execute(stmt).scalar_one_or_none() is not None
