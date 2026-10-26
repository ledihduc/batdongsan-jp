"""JP listing CRUD — rental_terms, property_info, transit_access (nested).

Routes:
  POST   /api/jp/listings/attach  — attach JP data to an existing listing
  GET    /api/jp/listings/{listing_id}/jp-data  — get all JP data for a listing
  PUT    /api/jp/listings/{listing_id}/rental-terms  — update rental terms
  PUT    /api/jp/listings/{listing_id}/property-info  — update property info
  PUT    /api/jp/listings/{listing_id}/transit  — replace transit access entries
  GET    /api/jp/stations/search  — search stations (for frontend dropdown)

All routes guarded by require_region('jp') at router include level.
VN listing endpoints are NOT touched by this file.

Multi-tenant: org_id extracted from request.state (set by auth middleware).
"""

from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.core.deps.require_region import require_region
from app.database import get_db
from app.repositories.jp.property_info import JpPropertyInfoRepository
from app.repositories.jp.rental_terms import JpRentalTermsRepository
from app.repositories.jp.transit import (
    StationRepository,
    TransitAccessRepository,
    TrainLineRepository,
)
from app.schemas.jp.application import (
    JpListingCreateRequest,
    JpListingResponse,
    JpPropertyInfoInlineResponse,
    JpRentalTermsInlineResponse,
    TransitAccessInlineResponse,
)
from app.schemas.jp.property_info import JpPropertyInfoCreate, JpPropertyInfoResponse
from app.schemas.jp.rental_terms import JpRentalTermsCreate, JpRentalTermsResponse
from app.schemas.jp.transit import StationResponse, TransitAccessCreate, TransitAccessResponse

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/jp",
    tags=["jp-listings"],
    dependencies=[Depends(require_region("jp"))],
)


def _get_org_id(request: Request) -> Optional[str]:
    """Extract org_id from request.state (set by auth middleware)."""
    return getattr(request.state, "org_id", None)


@router.post("/listings/attach", response_model=JpListingResponse, status_code=201)
async def attach_jp_listing_data(
    body: JpListingCreateRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> JpListingResponse:
    """Attach JP-specific data (rental terms, property info, transit) to an existing listing.

    Idempotent: replaces existing JP data if already present for the listing_id.
    """
    org_id = _get_org_id(request)
    terms_repo = JpRentalTermsRepository(db)
    info_repo = JpPropertyInfoRepository(db)
    transit_repo = TransitAccessRepository(db)

    created_terms = None
    created_info = None
    transit_list: list[TransitAccessInlineResponse] = []

    try:
        if body.rental_terms:
            rt = body.rental_terms
            created_terms = terms_repo.create(
                org_id=org_id,
                monthly_rent_jpy=rt.monthly_rent_jpy,
                management_fee_jpy=rt.management_fee_jpy,
                shikikin_months=rt.shikikin_months,
                reikin_months=rt.reikin_months,
                hoshou_months=rt.hoshou_months,
                koushinryo_months=rt.koushinryo_months,
                brokerage_rate=rt.brokerage_rate,
                hoshou_fee_jpy=rt.hoshou_fee_jpy,
                tax_treatment=rt.tax_treatment,
            )

        if body.property_info:
            from datetime import date as _date
            pi = body.property_info
            avail = None
            if pi.available_from:
                try:
                    avail = _date.fromisoformat(pi.available_from)
                except ValueError:
                    raise HTTPException(status_code=422, detail="Invalid available_from date format")

            created_info = info_repo.create(
                org_id=org_id,
                layout=pi.layout,
                floor_area_sqm=pi.floor_area_sqm,
                building_year=pi.building_year,
                structure=pi.structure,
                floor_number=pi.floor_number,
                orientation=pi.orientation,
                available_from=avail,
            )

        if body.transit_access:
            # Replace existing transit access for this listing
            if org_id:
                transit_repo.delete_by_listing_org(body.listing_id, org_id)
            station_repo = StationRepository(db)
            for ta in body.transit_access:
                station = station_repo.get_by_id(ta.station_id)
                if station is None:
                    raise HTTPException(
                        status_code=422,
                        detail=f"Station {ta.station_id} not found",
                    )
                acc = transit_repo.create(
                    listing_id=body.listing_id,
                    station_id=ta.station_id,
                    walk_min=ta.walk_min,
                    org_id=org_id,
                )
                transit_list.append(
                    TransitAccessInlineResponse(
                        id=acc.id,
                        station_id=acc.station_id,
                        walk_min=acc.walk_min,
                        station_name_ja=station.name_ja,
                        line_name_ja=station.line.name_ja if station.line else None,
                    )
                )

        db.commit()

    except HTTPException:
        db.rollback()
        raise
    except Exception as exc:
        db.rollback()
        logger.error("[JP_LISTINGS] attach failed listing_id=%s: %s", body.listing_id, exc)
        raise HTTPException(status_code=500, detail="Failed to attach JP listing data") from exc

    return JpListingResponse(
        listing_id=body.listing_id,
        rental_terms=JpRentalTermsInlineResponse.model_validate(created_terms) if created_terms else None,
        property_info=JpPropertyInfoInlineResponse(
            id=created_info.id,
            layout=created_info.layout,
            floor_area_sqm=created_info.floor_area_sqm,
            building_year=created_info.building_year,
            structure=created_info.structure,
            floor_number=created_info.floor_number,
            orientation=created_info.orientation,
            available_from=str(created_info.available_from) if created_info and created_info.available_from else None,
        ) if created_info else None,
        transit_access=transit_list,
    )


@router.get("/listings/{listing_id}/jp-data", response_model=JpListingResponse)
async def get_jp_listing_data(
    listing_id: str,
    request: Request,
    db: Session = Depends(get_db),
) -> JpListingResponse:
    """Get all JP-specific data for a listing (rental_terms + property_info + transit)."""
    org_id = _get_org_id(request)

    transit_repo = TransitAccessRepository(db)
    transit_rows = (
        transit_repo.list_by_listing_org(listing_id, org_id)
        if org_id else []
    )

    transit_list = []
    for ta in transit_rows:
        station_name = None
        line_name = None
        if ta.station:
            station_name = ta.station.name_ja
            if ta.station.line:
                line_name = ta.station.line.name_ja
        transit_list.append(
            TransitAccessInlineResponse(
                id=ta.id,
                station_id=ta.station_id,
                walk_min=ta.walk_min,
                station_name_ja=station_name,
                line_name_ja=line_name,
            )
        )

    return JpListingResponse(
        listing_id=listing_id,
        transit_access=transit_list,
    )


@router.get("/stations/search", response_model=list[StationResponse])
async def search_stations(
    q: str = Query(..., min_length=1, description="Station name search query (Japanese or English)"),
    prefecture: Optional[str] = Query(None, description="Filter by 都道府県 (e.g. '東京都')"),
    db: Session = Depends(get_db),
) -> list[StationResponse]:
    """Search JP train stations by name — used for transit access autocomplete."""
    repo = StationRepository(db)
    stations = repo.search_by_name(q, prefecture=prefecture)
    results = []
    for s in stations:
        results.append(
            StationResponse(
                id=s.id,
                name_ja=s.name_ja,
                name_en=s.name_en,
                prefecture=s.prefecture,
                line_id=s.line_id,
                line_name_ja=s.line.name_ja if s.line else None,
            )
        )
    return results
