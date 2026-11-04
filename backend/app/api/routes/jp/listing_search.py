"""Tìm + xem tin thuê JP công khai (plan 20261027-1102 Phase 04 — AC3, AC4).

Routes:
  GET /api/jp/listings              — tìm theo giá, 間取り, diện tích, tuổi nhà, ga, phút đi bộ
  GET /api/jp/listings/{listing_id} — chi tiết đúng key `JpListing.fromJson`

Router mỏng: parse + validate tham số, logic ở `app.services.jp_search`.
Chỉ đọc, không cần đăng nhập; gắn require_region('jp') ở router và ở include_router.
"""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.domain.jp.property_info import LAYOUT_VALUES
from app.schemas.jp.listing_search import JpListingDetailResponse, JpListingSearchResponse
from app.services.jp_search.listing_search_service import (
    MAX_PAGE,
    MAX_PAGE_SIZE,
    JpListingFilters,
    get_listing_detail,
    search_listings,
)

router = APIRouter(
    prefix="/api/jp",
    tags=["jp-listing-search"],
    dependencies=[Depends(require_region("jp"))],
)

_UNSUPPORTED = "Chưa hỗ trợ — nhận nhưng không lọc (D10)."


def _parse_layouts(raw: Optional[str]) -> tuple[str, ...]:
    values = tuple(v.strip() for v in (raw or "").split(",") if v.strip())
    bad = [v for v in values if v not in LAYOUT_VALUES]
    if bad:
        raise HTTPException(
            status_code=422,
            detail={"code": "VALIDATION_ERROR", "message": f"layouts không hợp lệ: {', '.join(bad)}"},
        )
    return values


@router.get("/listings", response_model=JpListingSearchResponse)
def list_jp_listings(
    layouts: Optional[str] = Query(None, description="間取り, phân tách bằng dấu phẩy (vd '1LDK,2DK')"),
    min_rent: Optional[int] = Query(None, ge=0),
    max_rent: Optional[int] = Query(None, ge=0),
    min_area: Optional[float] = Query(None, ge=0),
    max_area: Optional[float] = Query(None, ge=0),
    max_building_age: Optional[int] = Query(None, ge=0),
    max_walk_min: Optional[int] = Query(
        None, ge=0, le=60, description="0 = không giới hạn (drawer Flutter gửi 0 cho 制限なし); không kèm ga ⇒ xét mọi ga",
    ),
    station_id: Optional[int] = Query(None, ge=1, description="Gom mọi tuyến cùng tên ga (D11)"),
    pets_ok: Optional[bool] = Query(None, description=_UNSUPPORTED),
    no_guarantor: Optional[bool] = Query(None, description=_UNSUPPORTED),
    instruments_ok: Optional[bool] = Query(None, description=_UNSUPPORTED),
    corporate_ok: Optional[bool] = Query(None, description=_UNSUPPORTED),
    page: int = Query(1, ge=1, le=MAX_PAGE),  # chặn OFFSET tràn bigint ⇒ 500
    page_size: int = Query(20, ge=1, le=MAX_PAGE_SIZE),
    db: Session = Depends(get_db),
) -> JpListingSearchResponse:
    filters = JpListingFilters(
        layouts=_parse_layouts(layouts),
        min_rent=min_rent, max_rent=max_rent, min_area=min_area, max_area=max_area,
        max_building_age=max_building_age, max_walk_min=max_walk_min, station_id=station_id,
        page=page, page_size=page_size,
    )
    flags = {"pets_ok": pets_ok, "no_guarantor": no_guarantor,
             "instruments_ok": instruments_ok, "corporate_ok": corporate_ok}
    result = search_listings(db, filters)
    return JpListingSearchResponse(
        items=result.items, total=result.total, page=result.page, page_size=result.page_size,
        ignored_filters=[name for name, value in flags.items() if value is not None],
    )


@router.get("/listings/{listing_id}", response_model=JpListingDetailResponse)
def get_jp_listing(listing_id: int, db: Session = Depends(get_db)) -> JpListingDetailResponse:
    detail = get_listing_detail(db, listing_id)
    if detail is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy tin")
    return JpListingDetailResponse(**detail)
