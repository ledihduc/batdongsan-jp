"""JP schemas package."""

from app.schemas.jp.rental_terms import (
    JpRentalTermsCreate,
    JpRentalTermsUpdate,
    JpRentalTermsResponse,
)
from app.schemas.jp.property_info import (
    JpPropertyInfoCreate,
    JpPropertyInfoUpdate,
    JpPropertyInfoResponse,
)
from app.schemas.jp.transit import (
    TransitAccessCreate,
    TransitAccessResponse,
    StationResponse,
    TrainLineResponse,
)
from app.schemas.jp.viewing import (
    JpViewingCreate,
    JpViewingConfirmRequest,
    JpViewingCancelRequest,
    JpViewingResponse,
)
from app.schemas.jp.application import (
    JpTenantApplicationCreate,
    JpTenantApplicationUpdate,
    JpTenantApplicationResponse,
    JpApplicationReviewCreate,
    JpApplicationReviewResponse,
    JpListingCreateRequest,
    JpListingResponse,
)

__all__ = [
    "JpRentalTermsCreate",
    "JpRentalTermsUpdate",
    "JpRentalTermsResponse",
    "JpPropertyInfoCreate",
    "JpPropertyInfoUpdate",
    "JpPropertyInfoResponse",
    "TransitAccessCreate",
    "TransitAccessResponse",
    "StationResponse",
    "TrainLineResponse",
    "JpViewingCreate",
    "JpViewingConfirmRequest",
    "JpViewingCancelRequest",
    "JpViewingResponse",
    "JpTenantApplicationCreate",
    "JpTenantApplicationUpdate",
    "JpTenantApplicationResponse",
    "JpApplicationReviewCreate",
    "JpApplicationReviewResponse",
    "JpListingCreateRequest",
    "JpListingResponse",
]
