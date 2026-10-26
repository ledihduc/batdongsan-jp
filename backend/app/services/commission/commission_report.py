"""CommissionReportService — read-only aggregation of commission data per delegation/period.

Used by operator dashboard (AC-34) and owner commission report (AC-36).

All methods are read-only (SELECT only — no mutations). This enforces the
track-only principle of v1 (AC-35: no auto-transfer).

NO auto-transfer: commission amounts are reported, never remitted automatically.
NHNN intermediary license required for auto-transfer (O4 — v2 Q4 2026).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app import models


# ── Response shapes ────────────────────────────────────────────────────────────


@dataclass
class OwnerCommissionBreakdown:
    """Commission earned per owner property for an operator."""
    owner_id: int
    owner_name: str
    invoice_count: int
    total_commission_amount: float
    total_platform_fee_amount: float
    total_expected_owner_payout: float


@dataclass
class OperatorCommissionDashboard:
    """Operator dashboard: commission summary for a given period (AC-34)."""
    operator_id: int
    period: str  # 'YYYY-MM'
    per_owner: list[OwnerCommissionBreakdown] = field(default_factory=list)
    total_commission_amount: float = 0.0
    total_invoices_paid: int = 0

    # AC-37: partially collected invoices
    total_collection_shortfall: float = 0.0


@dataclass
class CommissionLineItem:
    """Single invoice row in the commission report."""
    invoice_id: int
    invoice_number: str
    period_start: str
    period_end: str
    total_amount: float
    paid_amount: float
    commission_rate: Optional[float]
    commission_amount: float
    platform_fee_pct: Optional[float]
    platform_fee_amount: float
    expected_owner_payout: float
    paid_at: Optional[datetime]


@dataclass
class OwnerCommissionReport:
    """Owner's monthly commission report (AC-36)."""
    owner_id: int
    period: str  # 'YYYY-MM'
    invoices: list[CommissionLineItem] = field(default_factory=list)
    total_commission_paid_to_operators: float = 0.0
    total_platform_fees: float = 0.0
    total_owner_payout: float = 0.0


# ── Service ────────────────────────────────────────────────────────────────────


class CommissionReportService:
    """Read-only commission aggregation for operator dashboard and owner reports.

    All methods accept a SQLAlchemy session and query against paid invoices only.
    Unpaid/draft invoices are excluded from commission aggregation.
    """

    def get_operator_dashboard(
        self,
        db: Session,
        *,
        operator_id: int,
        period: str,
    ) -> OperatorCommissionDashboard:
        """Build operator commission dashboard for a given period (AC-34).

        Args:
            db:          SQLAlchemy session.
            operator_id: Operator user ID.
            period:      'YYYY-MM' string.

        Returns:
            OperatorCommissionDashboard with per-owner breakdown + totals.
        """
        period_start = f"{period}-01"
        # period_end = last day of month (simple prefix match via >= / <=)
        year = int(period[:4])
        month = int(period[5:7])
        import calendar
        last_day = calendar.monthrange(year, month)[1]
        period_end = f"{period}-{last_day:02d}"

        # Fetch paid invoices within period for owners delegated to this operator
        invoices = self._fetch_paid_invoices_for_operator(
            db, operator_id=operator_id, period_start=period_start, period_end=period_end
        )

        dashboard = OperatorCommissionDashboard(
            operator_id=operator_id,
            period=period,
        )

        # Group by owner_id for per-owner breakdown
        owner_map: dict[int, list[models.Invoice]] = {}
        for inv in invoices:
            owner_map.setdefault(inv.host_id, []).append(inv)

        for owner_id, owner_invoices in owner_map.items():
            owner = db.get(models.User, owner_id)
            owner_name = owner.name if owner else f"Owner#{owner_id}"

            commission_total = sum(float(inv.commission_amount or 0) for inv in owner_invoices)
            platform_fee_total = sum(float(inv.platform_fee_amount or 0) for inv in owner_invoices)
            payout_total = sum(
                max(0.0, float(inv.total_amount or 0)
                    - float(inv.commission_amount or 0)
                    - float(inv.platform_fee_amount or 0))
                for inv in owner_invoices
            )
            shortfall = sum(
                max(0.0, float(inv.total_amount or 0) - float(inv.paid_amount or 0))
                for inv in owner_invoices
            )

            dashboard.per_owner.append(OwnerCommissionBreakdown(
                owner_id=owner_id,
                owner_name=owner_name,
                invoice_count=len(owner_invoices),
                total_commission_amount=commission_total,
                total_platform_fee_amount=platform_fee_total,
                total_expected_owner_payout=payout_total,
            ))
            dashboard.total_commission_amount += commission_total
            dashboard.total_invoices_paid += len(owner_invoices)
            dashboard.total_collection_shortfall += shortfall

        return dashboard

    def get_owner_commission_report(
        self,
        db: Session,
        *,
        owner_id: int,
        period: str,
    ) -> OwnerCommissionReport:
        """Build owner's monthly commission report (AC-36).

        Returns all paid invoices for the owner in the period with commission breakdown.
        """
        period_start = f"{period}-01"
        import calendar
        year = int(period[:4])
        month = int(period[5:7])
        last_day = calendar.monthrange(year, month)[1]
        period_end = f"{period}-{last_day:02d}"

        invoices = (
            db.query(models.Invoice)
            .filter(
                models.Invoice.host_id == owner_id,
                models.Invoice.status == "paid",
                models.Invoice.period_start >= period_start,
                models.Invoice.period_end <= period_end,
            )
            .order_by(models.Invoice.period_start)
            .all()
        )

        report = OwnerCommissionReport(owner_id=owner_id, period=period)

        for inv in invoices:
            commission_amount = float(inv.commission_amount or 0)
            platform_fee_amount = float(inv.platform_fee_amount or 0)
            expected_payout = max(
                0.0,
                float(inv.total_amount or 0) - commission_amount - platform_fee_amount,
            )
            commission_rate = float(inv.commission_rate) if inv.commission_rate is not None else None
            platform_fee_pct = float(inv.platform_fee_pct) if inv.platform_fee_pct is not None else None

            report.invoices.append(CommissionLineItem(
                invoice_id=inv.id,
                invoice_number=inv.invoice_number,
                period_start=inv.period_start,
                period_end=inv.period_end,
                total_amount=float(inv.total_amount or 0),
                paid_amount=float(inv.paid_amount or 0),
                commission_rate=commission_rate,
                commission_amount=commission_amount,
                platform_fee_pct=platform_fee_pct,
                platform_fee_amount=platform_fee_amount,
                expected_owner_payout=expected_payout,
                paid_at=inv.paid_at,
            ))
            report.total_commission_paid_to_operators += commission_amount
            report.total_platform_fees += platform_fee_amount
            report.total_owner_payout += expected_payout

        return report

    # ── Internal helpers ───────────────────────────────────────────────────────

    def _fetch_paid_invoices_for_operator(
        self,
        db: Session,
        *,
        operator_id: int,
        period_start: str,
        period_end: str,
    ) -> list[models.Invoice]:
        """Fetch paid invoices scoped to delegations where operator_id matches.

        Joins through the Delegation table to find invoices belonging to owners
        who have an active delegation with this operator.

        Falls back to empty list if Delegation models are not available.
        """
        try:
            from app.domain.delegation import Delegation
        except ImportError:
            return []

        # Find all owner_ids with an active delegation to this operator
        delegations = (
            db.query(Delegation)
            .filter(
                Delegation.operator_id == operator_id,
                Delegation.status == "active",
            )
            .all()
        )
        owner_ids = [d.owner_id for d in delegations]

        if not owner_ids:
            return []

        return (
            db.query(models.Invoice)
            .filter(
                models.Invoice.host_id.in_(owner_ids),
                models.Invoice.status == "paid",
                models.Invoice.period_start >= period_start,
                models.Invoice.period_end <= period_end,
            )
            .order_by(models.Invoice.host_id, models.Invoice.period_start)
            .all()
        )
