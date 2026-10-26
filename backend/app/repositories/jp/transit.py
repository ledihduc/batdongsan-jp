"""Repositories for JP transit reference data and transit access.

TransitAccessRepository — org-scoped CRUD (listing <-> station associations).
TrainLineRepository — shared reference data CRUD (no org scope).
StationRepository — shared reference data CRUD (no org scope).
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.jp.transit import Station, TrainLine, TransitAccess


def _now_utc() -> datetime:
    return datetime.utcnow()


class TrainLineRepository:
    """CRUD for jp_train_lines reference data.

    TrainLine is shared reference data — no org_id scoping needed.
    Write operations are restricted to admin/import script context.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id(self, line_id: int) -> Optional[TrainLine]:
        return self.db.query(TrainLine).filter(TrainLine.id == line_id).first()

    def get_by_ekidata_cd(self, ekidata_line_cd: int) -> Optional[TrainLine]:
        """Fetch by external reference code — used for idempotent import."""
        return (
            self.db.query(TrainLine)
            .filter(TrainLine.ekidata_line_cd == ekidata_line_cd)
            .first()
        )

    def list_all(self, *, operator: Optional[str] = None) -> list[TrainLine]:
        """List all train lines, optionally filtered by operator."""
        q = self.db.query(TrainLine)
        if operator:
            q = q.filter(TrainLine.operator == operator)
        return q.order_by(TrainLine.name_ja).all()

    def upsert(
        self,
        *,
        name_ja: str,
        ekidata_line_cd: Optional[int] = None,
        name_en: Optional[str] = None,
        operator: Optional[str] = None,
    ) -> TrainLine:
        """Upsert train line by ekidata_line_cd (create or update)."""
        now = _now_utc()
        existing: Optional[TrainLine] = None
        if ekidata_line_cd is not None:
            existing = self.get_by_ekidata_cd(ekidata_line_cd)

        if existing is not None:
            existing.name_ja = name_ja
            if name_en is not None:
                existing.name_en = name_en
            if operator is not None:
                existing.operator = operator
            existing.updated_at = now
            self.db.flush()
            return existing

        line = TrainLine(
            name_ja=name_ja,
            name_en=name_en,
            operator=operator,
            ekidata_line_cd=ekidata_line_cd,
            created_at=now,
            updated_at=now,
        )
        self.db.add(line)
        self.db.flush()
        return line


class StationRepository:
    """CRUD for jp_stations reference data.

    Station is shared reference data — no org_id scoping.
    Write operations are restricted to admin/import script context.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id(self, station_id: int) -> Optional[Station]:
        return self.db.query(Station).filter(Station.id == station_id).first()

    def get_by_ekidata_cd(self, ekidata_station_cd: int) -> Optional[Station]:
        """Fetch by external reference code — used for idempotent import."""
        return (
            self.db.query(Station)
            .filter(Station.ekidata_station_cd == ekidata_station_cd)
            .first()
        )

    def search_by_name(self, name_query: str, prefecture: Optional[str] = None) -> list[Station]:
        """Search stations by Japanese name prefix (e.g. '渋谷')."""
        q = self.db.query(Station).filter(
            Station.name_ja.ilike(f"%{name_query}%")
        )
        if prefecture:
            q = q.filter(Station.prefecture == prefecture)
        return q.order_by(Station.name_ja).limit(20).all()

    def list_by_line(self, line_id: int) -> list[Station]:
        """List all stations on a specific train line."""
        return (
            self.db.query(Station)
            .filter(Station.line_id == line_id)
            .order_by(Station.name_ja)
            .all()
        )

    def upsert(
        self,
        *,
        name_ja: str,
        ekidata_station_cd: Optional[int] = None,
        line_id: Optional[int] = None,
        name_en: Optional[str] = None,
        prefecture: Optional[str] = None,
        latitude: Optional[Decimal] = None,
        longitude: Optional[Decimal] = None,
    ) -> Station:
        """Upsert station by ekidata_station_cd (create or update)."""
        now = _now_utc()
        existing: Optional[Station] = None
        if ekidata_station_cd is not None:
            existing = self.get_by_ekidata_cd(ekidata_station_cd)

        if existing is not None:
            existing.name_ja = name_ja
            if name_en is not None:
                existing.name_en = name_en
            if prefecture is not None:
                existing.prefecture = prefecture
            if latitude is not None:
                existing.latitude = latitude
            if longitude is not None:
                existing.longitude = longitude
            if line_id is not None:
                existing.line_id = line_id
            existing.updated_at = now
            self.db.flush()
            return existing

        station = Station(
            name_ja=name_ja,
            name_en=name_en,
            line_id=line_id,
            prefecture=prefecture,
            latitude=latitude,
            longitude=longitude,
            ekidata_station_cd=ekidata_station_cd,
            created_at=now,
            updated_at=now,
        )
        self.db.add(station)
        self.db.flush()
        return station


class TransitAccessRepository:
    """Org-scoped CRUD for jp_transit_access (listing <-> station walk time).

    Multi-tenant isolation: every list query MUST filter by org_id.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id_org(self, access_id: int, org_id: str) -> Optional[TransitAccess]:
        """Fetch single record — org-scoped.

        # MULTI-TENANT ISOLATION: org_id filter enforced here.
        """
        return (
            self.db.query(TransitAccess)
            .filter(
                TransitAccess.id == access_id,
                TransitAccess.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def list_by_listing_org(self, listing_id: str, org_id: str) -> list[TransitAccess]:
        """List all transit access records for a listing within an org.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        return (
            self.db.query(TransitAccess)
            .filter(
                TransitAccess.listing_id == listing_id,
                TransitAccess.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .order_by(TransitAccess.walk_min)
            .all()
        )

    def filter_listings_by_station(
        self, station_id: int, org_id: str, max_walk_min: int = 15
    ) -> list[str]:
        """Return listing_ids accessible from a station within walk_min budget.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        rows = (
            self.db.query(TransitAccess.listing_id)
            .filter(
                TransitAccess.station_id == station_id,
                TransitAccess.walk_min <= max_walk_min,
                TransitAccess.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .all()
        )
        return [r.listing_id for r in rows]

    def create(
        self,
        *,
        listing_id: str,
        station_id: int,
        walk_min: int,
        org_id: Optional[str],
    ) -> TransitAccess:
        """Create and flush a new TransitAccess record."""
        now = _now_utc()
        access = TransitAccess(
            listing_id=listing_id,
            station_id=station_id,
            walk_min=walk_min,
            org_id=org_id,
            region="jp",
            created_at=now,
            updated_at=now,
        )
        self.db.add(access)
        self.db.flush()
        return access

    def delete(self, access: TransitAccess) -> None:
        """Hard delete a transit access record."""
        self.db.delete(access)
        self.db.flush()

    def delete_by_listing_org(self, listing_id: str, org_id: str) -> int:
        """Delete all transit access records for a listing (used on listing edit).

        Returns count of deleted records.
        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        rows = self.list_by_listing_org(listing_id, org_id)
        for row in rows:
            self.db.delete(row)
        self.db.flush()
        return len(rows)
