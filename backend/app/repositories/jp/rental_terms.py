"""Repository for jp_rental_terms — org-scoped CRUD.

Multi-tenant isolation: every list query MUST filter by org_id.
This is the contract for all JP repositories. See org_id comment below.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.jp.rental_terms import JpRentalTerms


def _now_utc() -> datetime:
    return datetime.utcnow()


class JpRentalTermsRepository:
    """Org-scoped CRUD for jp_rental_terms.

    All list operations require org_id for multi-tenant isolation.
    Missing org_id in list calls is a security boundary violation — callers
    must always pass org_id from the authenticated request context.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id(self, terms_id: int) -> Optional[JpRentalTerms]:
        """Fetch single record by PK. Returns None if not found."""
        return (
            self.db.query(JpRentalTerms)
            .filter(JpRentalTerms.id == terms_id)
            .first()
        )

    def get_by_id_org(self, terms_id: int, org_id: str) -> Optional[JpRentalTerms]:
        """Fetch single record — org-scoped. Returns None if not found or wrong org.

        # MULTI-TENANT ISOLATION: org_id filter enforced here.
        """
        return (
            self.db.query(JpRentalTerms)
            .filter(
                JpRentalTerms.id == terms_id,
                JpRentalTerms.org_id == org_id,  # MULTI-TENANT ISOLATION
            )
            .first()
        )

    def list_by_org(self, org_id: str) -> list[JpRentalTerms]:
        """List all rental terms for an org.

        # MULTI-TENANT ISOLATION: org_id filter is mandatory here.
        """
        return (
            self.db.query(JpRentalTerms)
            .filter(JpRentalTerms.org_id == org_id)  # MULTI-TENANT ISOLATION
            .order_by(JpRentalTerms.id.desc())
            .all()
        )

    def create(
        self,
        *,
        org_id: Optional[str],
        monthly_rent_jpy: Decimal,
        management_fee_jpy: Optional[Decimal] = None,
        shikikin_months: Optional[Decimal] = None,
        reikin_months: Optional[Decimal] = None,
        hoshou_months: Optional[Decimal] = None,
        koushinryo_months: Optional[Decimal] = None,
        brokerage_rate: Optional[Decimal] = None,
        hoshou_fee_jpy: Optional[Decimal] = None,
        tax_treatment: str = "included",
    ) -> JpRentalTerms:
        """Create and flush a new JpRentalTerms record."""
        now = _now_utc()
        terms = JpRentalTerms(
            org_id=org_id,
            region="jp",
            monthly_rent_jpy=monthly_rent_jpy,
            management_fee_jpy=management_fee_jpy,
            shikikin_months=shikikin_months,
            reikin_months=reikin_months,
            hoshou_months=hoshou_months,
            koushinryo_months=koushinryo_months,
            brokerage_rate=brokerage_rate,
            hoshou_fee_jpy=hoshou_fee_jpy,
            tax_treatment=tax_treatment,
            created_at=now,
            updated_at=now,
        )
        self.db.add(terms)
        self.db.flush()
        return terms

    def update(self, terms: JpRentalTerms, **fields: object) -> JpRentalTerms:
        """Apply field updates to an existing terms record and flush."""
        allowed = {
            "monthly_rent_jpy", "management_fee_jpy", "shikikin_months",
            "reikin_months", "hoshou_months", "koushinryo_months",
            "brokerage_rate", "hoshou_fee_jpy", "tax_treatment",
        }
        for key, value in fields.items():
            if key in allowed:
                setattr(terms, key, value)
        terms.updated_at = _now_utc()
        self.db.flush()
        return terms

    def delete(self, terms: JpRentalTerms) -> None:
        """Hard delete a rental terms record."""
        self.db.delete(terms)
        self.db.flush()
