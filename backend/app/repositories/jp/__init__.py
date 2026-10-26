"""JP repositories package.

All JP repositories enforce org_id-based multi-tenant isolation.
Every list query in these repositories filters by org_id — this is mandatory.
"""

from app.repositories.jp.rental_terms import JpRentalTermsRepository
from app.repositories.jp.property_info import JpPropertyInfoRepository
from app.repositories.jp.transit import (
    TrainLineRepository,
    StationRepository,
    TransitAccessRepository,
)
from app.repositories.jp.viewing import JpViewingRepository
from app.repositories.jp.application import (
    JpTenantApplicationRepository,
    JpApplicationReviewRepository,
)
from app.repositories.jp.sales_assignment import ListingSalesAssignmentRepository

__all__ = [
    "JpRentalTermsRepository",
    "JpPropertyInfoRepository",
    "TrainLineRepository",
    "StationRepository",
    "TransitAccessRepository",
    "JpViewingRepository",
    "JpTenantApplicationRepository",
    "JpApplicationReviewRepository",
    "ListingSalesAssignmentRepository",
]
