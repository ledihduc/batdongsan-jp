"""FastAPI dependencies dùng chung cho geo-search (tìm địa danh / tỉnh / quanh đây).

Tách riêng khỏi routers để `houses.py` dùng được mà không import chéo router.
`planning.py` giữ `require_postgis` riêng (code PLANNING_DB_UNAVAILABLE) — ở đây dùng
code GEO_DB_UNAVAILABLE cho ngữ cảnh tìm kiếm nhà.
"""

from __future__ import annotations

from fastapi import HTTPException

from app.config import settings


def is_postgis() -> bool:
    """True nếu DB hiện tại là Postgres (giả định đã bật PostGIS trong prod)."""
    return settings.database_url.startswith("postgresql")


def require_postgis() -> None:
    """503 nếu DB không phải Postgres/PostGIS.

    Các nhánh nearby dùng ST_DWithin/ST_Distance sẽ crash raw SQL trên SQLite —
    guard này trả lỗi rõ ràng (kèm CORS header) thay vì 500 trần trụi.
    """
    if not is_postgis():
        raise HTTPException(
            status_code=503,
            detail={
                "code": "GEO_DB_UNAVAILABLE",
                "message": "Tìm kiếm lân cận yêu cầu Postgres/PostGIS — backend đang chạy SQLite dev mode.",
            },
        )


def require_geo_search() -> None:
    """404 khi feature flag geo_search_enabled tắt — ẩn endpoint chưa sẵn sàng."""
    if not settings.geo_search_enabled:
        raise HTTPException(
            status_code=404,
            detail={"code": "GEO_SEARCH_DISABLED", "message": "Tính năng chưa được bật."},
        )
