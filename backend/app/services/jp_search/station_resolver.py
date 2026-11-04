"""Quy đổi ga người dùng chọn/gõ thành tập `jp_stations.id` để lọc tin (D11).

Một ga thật (vd 渋谷) có nhiều dòng `jp_stations` — mỗi tuyến một dòng. Lọc theo
1 dòng sẽ bỏ sót tin gắn tuyến khác ⇒ gom mọi dòng cùng `name_ja` + `prefecture`.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session, joinedload

from app.domain.jp.transit import Station

_EKI_SUFFIX = "駅"


def _ids_for_groups(db: Session, groups: set[tuple[str, Optional[str]]]) -> list[int]:
    if not groups:
        return []
    conds = [
        and_(Station.name_ja == name, Station.prefecture.is_(None) if pref is None else Station.prefecture == pref)
        for name, pref in groups
    ]
    return [sid for (sid,) in db.query(Station.id).filter(or_(*conds)).order_by(Station.id)]


def resolve_station_ids(
    db: Session, *, station_id: Optional[int] = None, station_name: Optional[str] = None,
) -> Optional[list[int]]:
    """None = không lọc ga; [] = ga không tồn tại (kết quả tìm phải rỗng)."""
    if station_id is not None:
        station = db.get(Station, station_id)
        return [] if station is None else _ids_for_groups(db, {(station.name_ja, station.prefecture)})
    name = (station_name or "").strip().removesuffix(_EKI_SUFFIX).strip()
    if name:
        rows = db.query(Station.name_ja, Station.prefecture).filter(Station.name_ja == name).distinct().all()
        return _ids_for_groups(db, {(n, p) for n, p in rows})
    return None


def search_stations(db: Session, q: str, limit: int = 10) -> list[dict]:
    """Gợi ý ga theo tên (khớp một phần, ja hoặc en) — cho AI/autocomplete."""
    # Escape ký tự đại diện LIKE để "%" / "_" do AI gõ không khớp mọi ga.
    escaped = q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    term = f"%{escaped}%"
    limit = min(max(limit, 1), 20)
    rows = (
        db.query(Station)
        .options(joinedload(Station.line))
        .filter(or_(Station.name_ja.ilike(term, escape="\\"), Station.name_en.ilike(term, escape="\\")))
        .order_by(Station.name_ja, Station.id)
        .limit(limit)
        .all()
    )
    return [
        {"id": s.id, "name_ja": s.name_ja, "name_en": s.name_en,
         "line_name_ja": s.line.name_ja if s.line else None, "prefecture": s.prefecture}
        for s in rows
    ]
