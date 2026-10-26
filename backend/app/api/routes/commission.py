"""Commission reporting endpoints — read-only, scoped to actor identity.

Endpoints:
    GET /api/commission/operator/{operator_id}/dashboard?period=YYYY-MM
        → OperatorCommissionDashboard (AC-34)
        IDOR: only operator OR admin can call for their own operator_id.

    GET /api/commission/owner/{owner_id}/report?period=YYYY-MM
        → OwnerCommissionReport (AC-36 data; full export via separate POST if needed)
        IDOR: only owner OR admin.

Auth strategy:
    Uses request.state.actor_ctx if set (phase-02 delegation-aware context).
    Falls back to require_host (plain JWT) if actor_ctx not available — ensures
    backward compatibility while phase-02 is being integrated.

IMPORTANT: No auto-transfer code in this module. Commission amounts are
    reported only. Auto-transfer requires NHNN license (O4, AC-35).
"""

from __future__ import annotations

import re
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import auth
from app.database import get_db
from app.services.commission.commission_report import (
    CommissionReportService,
    OperatorCommissionDashboard,
    OwnerCommissionReport,
)

router = APIRouter(prefix="/api/commission", tags=["commission"])

_PERIOD_RE = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")


# ── Pydantic response schemas ──────────────────────────────────────────────────


class OwnerBreakdownOut(BaseModel):
    owner_id: int
    owner_name: str
    invoice_count: int
    total_commission_amount: float
    total_platform_fee_amount: float
    total_expected_owner_payout: float


class OperatorDashboardOut(BaseModel):
    operator_id: int
    period: str
    per_owner: list[OwnerBreakdownOut]
    total_commission_amount: float
    total_invoices_paid: int
    total_collection_shortfall: float


class CommissionLineItemOut(BaseModel):
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
    paid_at: Optional[str]  # ISO datetime string


class OwnerReportOut(BaseModel):
    owner_id: int
    period: str
    invoices: list[CommissionLineItemOut]
    total_commission_paid_to_operators: float
    total_platform_fees: float
    total_owner_payout: float


# ── Helpers ────────────────────────────────────────────────────────────────────


def _validate_period(period: str) -> str:
    """Validate YYYY-MM format. Raises 422 on bad input."""
    if not _PERIOD_RE.match(period):
        raise HTTPException(
            status_code=422,
            detail="period must be in format YYYY-MM (e.g. 2026-07)",
        )
    return period


def _get_actor_id(request: Request, claims: dict) -> tuple[int, str]:
    """Return (actor_user_id, actor_role) from actor_ctx or JWT claims.

    Phase-02 populates request.state.actor_ctx when X-Acting-As-Delegation-Id
    header is present. Falls back to JWT claims when phase-02 is not wired.
    """
    actor_ctx = getattr(request.state, "actor_ctx", None)
    if actor_ctx is not None:
        actor_user = getattr(actor_ctx, "actor_user", None)
        if actor_user is not None:
            role = getattr(actor_user, "role", "host")
            return int(actor_user.id), str(role)

    # Fallback: use JWT sub + role
    return int(claims["sub"]), str(claims.get("role", "host"))


def _to_dashboard_out(dashboard: OperatorCommissionDashboard) -> OperatorDashboardOut:
    return OperatorDashboardOut(
        operator_id=dashboard.operator_id,
        period=dashboard.period,
        per_owner=[
            OwnerBreakdownOut(
                owner_id=ob.owner_id,
                owner_name=ob.owner_name,
                invoice_count=ob.invoice_count,
                total_commission_amount=ob.total_commission_amount,
                total_platform_fee_amount=ob.total_platform_fee_amount,
                total_expected_owner_payout=ob.total_expected_owner_payout,
            )
            for ob in dashboard.per_owner
        ],
        total_commission_amount=dashboard.total_commission_amount,
        total_invoices_paid=dashboard.total_invoices_paid,
        total_collection_shortfall=dashboard.total_collection_shortfall,
    )


def _to_report_out(report: OwnerCommissionReport) -> OwnerReportOut:
    return OwnerReportOut(
        owner_id=report.owner_id,
        period=report.period,
        invoices=[
            CommissionLineItemOut(
                invoice_id=li.invoice_id,
                invoice_number=li.invoice_number,
                period_start=li.period_start,
                period_end=li.period_end,
                total_amount=li.total_amount,
                paid_amount=li.paid_amount,
                commission_rate=li.commission_rate,
                commission_amount=li.commission_amount,
                platform_fee_pct=li.platform_fee_pct,
                platform_fee_amount=li.platform_fee_amount,
                expected_owner_payout=li.expected_owner_payout,
                paid_at=li.paid_at.isoformat() if li.paid_at else None,
            )
            for li in report.invoices
        ],
        total_commission_paid_to_operators=report.total_commission_paid_to_operators,
        total_platform_fees=report.total_platform_fees,
        total_owner_payout=report.total_owner_payout,
    )


# ── Endpoints ──────────────────────────────────────────────────────────────────


@router.get(
    "/operator/{operator_id}/dashboard",
    response_model=OperatorDashboardOut,
    summary="Operator commission dashboard (AC-34)",
)
def operator_dashboard(
    operator_id: int,
    period: str = Query(..., description="Billing period — YYYY-MM format"),
    request: Request = None,  # type: ignore[assignment]
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_host),
) -> OperatorDashboardOut:
    """Return commission summary for an operator for a given period.

    IDOR guard: only the operator themselves (or admin) may call this endpoint.
    Used by Flutter OperatorPortfolioScreen (phase-07).
    """
    _validate_period(period)

    actor_id, actor_role = _get_actor_id(request, claims)

    # IDOR check: operator can only see their own dashboard; admin sees all
    if actor_role != "admin" and actor_id != operator_id:
        raise HTTPException(
            status_code=403,
            detail="Chỉ operator sở hữu hoặc admin mới có thể xem dashboard này.",
        )

    svc = CommissionReportService()
    dashboard = svc.get_operator_dashboard(db, operator_id=operator_id, period=period)
    return _to_dashboard_out(dashboard)


@router.get(
    "/owner/{owner_id}/report",
    response_model=OwnerReportOut,
    summary="Owner commission report (AC-36 data)",
)
def owner_commission_report(
    owner_id: int,
    period: str = Query(..., description="Billing period — YYYY-MM format"),
    request: Request = None,  # type: ignore[assignment]
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_host),
) -> OwnerReportOut:
    """Return owner's monthly commission breakdown for a given period.

    IDOR guard: only the owner themselves (or admin) may call this endpoint.
    Bank account details are NOT included in this response (AC-53 masking).
    Full TNCN/VAT export is a separate future endpoint (out-of-scope v1 CLI step).
    """
    _validate_period(period)

    actor_id, actor_role = _get_actor_id(request, claims)

    # IDOR check: owner can only see their own report; admin sees all
    if actor_role != "admin" and actor_id != owner_id:
        raise HTTPException(
            status_code=403,
            detail="Chỉ chủ sở hữu hoặc admin mới có thể xem báo cáo này.",
        )

    svc = CommissionReportService()
    report = svc.get_owner_commission_report(db, owner_id=owner_id, period=period)
    return _to_report_out(report)
