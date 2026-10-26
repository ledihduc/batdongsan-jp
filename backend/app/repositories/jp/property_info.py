"""Repository for jp_property_info — org-scoped CRUD.

Multi-tenant isolation: every list query MUST filter by org_id.
"""

from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.jp.property_info import JpPropertyInfo


def _now_utc() -> datetime:
    return datetime.utcnow()


class JpPropertyInfoRepository:
    """Org-scoped CRUD for jp_property_info."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id(self, info_id: int) -> Optional[JpPropertyInfo]:
        """Fetch single record by PK. Returns None if not found."""
        return self.db.query(JpPropertyInfo).filter(JpPropertyInfo.id == info_id).first()

    def get_by_id_org(self, info_id: int, org_id: str) -> Optional[JpPropertyInfo]:
        """Fetch single record — org-scoped.

        # MULTI-TENANT ISOLATION: org_id filter enforced here.
        """
        return (
            self.db.query(JpPropertyInfo)
            .filter(
                JpPropertyInfo.id == info_id,
                JpPropertyInfo.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def list_by_org(
        self,
        org_id: str,
        *,
        layout: Optional[str] = None,
        structure: Optional[str] = None,
    ) -> list[JpPropertyInfo]:
        """List property info records for an org, with optional filters.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        q = (
            self.db.query(JpPropertyInfo)
            .filter(JpPropertyInfo.org_id == org_id)  # MULTI-TENANT ISOLATION
        )
        if layout:
            q = q.filter(JpPropertyInfo.layout == layout)
        if structure:
            q = q.filter(JpPropertyInfo.structure == structure)
        return q.order_by(JpPropertyInfo.id.desc()).all()

    def create(
        self,
        *,
        org_id: Optional[str],
        layout: Optional[str] = None,
        floor_area_sqm: Optional[Decimal] = None,
        building_year: Optional[int] = None,
        structure: Optional[str] = None,
        floor_number: Optional[int] = None,
        orientation: Optional[str] = None,
        available_from: Optional[date] = None,
    ) -> JpPropertyInfo:
        """Create and flush a new JpPropertyInfo record."""
        now = _now_utc()
        info = JpPropertyInfo(
            org_id=org_id,
            region="jp",
            layout=layout,
            floor_area_sqm=floor_area_sqm,
            building_year=building_year,
            structure=structure,
            floor_number=floor_number,
            orientation=orientation,
            available_from=available_from,
            created_at=now,
            updated_at=now,
        )
        self.db.add(info)
        self.db.flush()
        return info

    def update(self, info: JpPropertyInfo, **fields: object) -> JpPropertyInfo:
        """Apply field updates to an existing record and flush."""
        allowed = {
            "layout", "floor_area_sqm", "building_year", "structure",
            "floor_number", "orientation", "available_from",
        }
        for key, value in fields.items():
            if key in allowed:
                setattr(info, key, value)
        info.updated_at = _now_utc()
        self.db.flush()
        return info

    def delete(self, info: JpPropertyInfo) -> None:
        """Hard delete a property info record."""
        self.db.delete(info)
        self.db.flush()
