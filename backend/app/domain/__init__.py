"""Delegation domain ORM models package (app/domain/).

Import all models here so they are registered on Base.metadata when this package
is imported. The existing app/models.py (single-file) continues to define the
core domain models; this package adds the delegation-specific ORM classes.

NOTE: This package is named 'domain' (not 'models') to avoid Python's package
resolution shadowing app/models.py when both app/models/ and app/models.py exist.
Python prefers package directories over .py files with the same name.

Usage in alembic/env.py:
    import app.domain  # registers delegation ORM classes onto Base.metadata
"""

from app.domain.delegation import Delegation, DelegationApproval, DelegationInvitation
from app.domain.operator_business import OperatorBusinessProfile
from app.domain.owner_death import OwnerDeathCertificate
from app.domain.tenant_authority import TenantAuthorityFlag
from app.domain.bank_account_reveal_log import BankAccountRevealLog
from app.domain.demand_post import DemandPost
from app.domain.service_request import Service, ServiceRequest
# JP market domain models (Phase 00) — register jp_addresses onto Base.metadata.
from app.domain.jp.address import JpAddress
# JP market domain models (Phase 01) — chintai schema
from app.domain.jp.rental_terms import JpRentalTerms
from app.domain.jp.property_info import JpPropertyInfo
from app.domain.jp.transit import TrainLine, Station, TransitAccess
from app.domain.jp.viewing import JpViewing
from app.domain.jp.application import JpTenantApplication, JpApplicationReview
from app.domain.jp.sales_assignment import ListingSalesAssignment

__all__ = [
    "Delegation",
    "DelegationInvitation",
    "DelegationApproval",
    "OperatorBusinessProfile",
    "OwnerDeathCertificate",
    "TenantAuthorityFlag",
    "BankAccountRevealLog",
    "DemandPost",
    "Service",
    "ServiceRequest",
    # JP Phase 00
    "JpAddress",
    # JP Phase 01 — chintai
    "JpRentalTerms",
    "JpPropertyInfo",
    "TrainLine",
    "Station",
    "TransitAccess",
    "JpViewing",
    "JpTenantApplication",
    "JpApplicationReview",
    "ListingSalesAssignment",
]
