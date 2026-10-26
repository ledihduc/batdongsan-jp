"""
Công cụ tiện ích cho người mua/thuê — KHÔNG đụng dữ liệu nhạy cảm.

- POST /api/tools/loan-calculator : máy tính vay mua nhà (stateless, thuần toán).
- GET  /api/tools/compare         : so sánh nhiều BĐS (read-only).

Cả hai gate bằng feature flag trong config (mặc định BẬT vì vô hại: không ghi
DB, không PII, không bên thứ ba). Không dùng `from __future__ import annotations`
để pydantic resolve model chuẩn.
"""

import math

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app import helpers, models
from app.config import settings
from app.database import get_db

router = APIRouter(prefix="/api/tools", tags=["tools"])


# ── Loan calculator ───────────────────────────────────────────────────────────
class LoanRequest(BaseModel):
    # Có thể nhập trực tiếp số tiền vay, HOẶC giá + % trả trước.
    amount_vnd: int | None = Field(default=None, ge=0, le=10**13)
    price_vnd: int | None = Field(default=None, ge=0, le=10**13)
    down_payment_pct: float = Field(default=0, ge=0, le=100)
    annual_rate_pct: float = Field(default=10.0, ge=0, le=100)
    term_months: int = Field(default=240, ge=1, le=600)
    # 'reducing' = dư nợ giảm dần (gốc cố định); 'annuity' = trả đều (EMI).
    method: str = Field(default="reducing")


def _round(x: float) -> int:
    return int(round(x))


@router.post("/loan-calculator")
def loan_calculator(body: LoanRequest):
    if not getattr(settings, "loan_calculator_enabled", True):
        raise HTTPException(status_code=404, detail="Tính năng chưa mở")

    # Xác định số tiền vay.
    if body.amount_vnd is not None:
        principal = float(body.amount_vnd)
    elif body.price_vnd is not None:
        principal = float(body.price_vnd) * (1 - body.down_payment_pct / 100.0)
    else:
        raise HTTPException(
            status_code=422, detail="Cần amount_vnd hoặc price_vnd"
        )
    if principal <= 0:
        raise HTTPException(status_code=422, detail="Số tiền vay phải > 0")

    n = body.term_months
    r = body.annual_rate_pct / 100.0 / 12.0  # lãi suất tháng
    method = body.method if body.method in ("reducing", "annuity") else "reducing"

    schedule_preview = []
    if method == "annuity":
        # Trả đều (EMI): mỗi kỳ trả cùng một số tiền.
        if r == 0:
            monthly = principal / n
        else:
            monthly = principal * r * (1 + r) ** n / ((1 + r) ** n - 1)
        total_payment = monthly * n
        total_interest = total_payment - principal
        remaining = principal
        for m in range(1, min(3, n) + 1):
            interest = remaining * r
            princ = monthly - interest
            remaining -= princ
            schedule_preview.append({
                "month": m,
                "principal": _round(princ),
                "interest": _round(interest),
                "payment": _round(monthly),
                "remaining": _round(max(remaining, 0)),
            })
        result = {
            "monthly_payment": _round(monthly),
            "total_payment": _round(total_payment),
            "total_interest": _round(total_interest),
        }
    else:
        # Dư nợ giảm dần: gốc cố định = P/n, lãi trên dư nợ còn lại.
        monthly_principal = principal / n
        first_interest = principal * r
        first_payment = monthly_principal + first_interest
        last_interest = monthly_principal * r  # dư nợ tháng cuối ~ 1 kỳ gốc
        last_payment = monthly_principal + last_interest
        # Tổng lãi = r * P * (n+1) / 2  (cấp số cộng dư nợ).
        total_interest = r * principal * (n + 1) / 2.0
        total_payment = principal + total_interest
        remaining = principal
        for m in range(1, min(3, n) + 1):
            interest = remaining * r
            payment = monthly_principal + interest
            remaining -= monthly_principal
            schedule_preview.append({
                "month": m,
                "principal": _round(monthly_principal),
                "interest": _round(interest),
                "payment": _round(payment),
                "remaining": _round(max(remaining, 0)),
            })
        result = {
            "monthly_principal": _round(monthly_principal),
            "first_month_payment": _round(first_payment),
            "last_month_payment": _round(last_payment),
            "avg_monthly_payment": _round(total_payment / n),
            "total_payment": _round(total_payment),
            "total_interest": _round(total_interest),
        }

    return {
        "method": method,
        "principal_vnd": _round(principal),
        "term_months": n,
        "annual_rate_pct": body.annual_rate_pct,
        "schedule_preview": schedule_preview,
        "disclaimer": "Kết quả chỉ mang tính tham khảo; lãi suất thực tế do ngân hàng quyết định.",
        **result,
    }


# ── So sánh BĐS ───────────────────────────────────────────────────────────────
_MAX_COMPARE = 4


@router.get("/compare")
def compare_houses(
    ids: str = Query(..., description="Danh sách house id, phân tách dấu phẩy"),
    db: Session = Depends(get_db),
):
    if not getattr(settings, "compare_enabled", True):
        raise HTTPException(status_code=404, detail="Tính năng chưa mở")

    # Parse + khử trùng lặp, giữ thứ tự, giới hạn số lượng.
    seen: set[int] = set()
    parsed: list[int] = []
    for tok in ids.split(","):
        tok = tok.strip()
        if not tok:
            continue
        try:
            hid = int(tok)
        except ValueError:
            raise HTTPException(status_code=422, detail=f"id không hợp lệ: {tok}")
        if hid not in seen:
            seen.add(hid)
            parsed.append(hid)
    if not parsed:
        raise HTTPException(status_code=422, detail="Cần ít nhất 1 id")
    if len(parsed) > _MAX_COMPARE:
        raise HTTPException(
            status_code=422, detail=f"So sánh tối đa {_MAX_COMPARE} BĐS"
        )

    items = []
    for hid in parsed:
        h = db.get(models.House, hid)
        if h is not None:
            items.append(helpers.house_to_dict(db, h))
    return {"count": len(items), "requested": len(parsed), "houses": items}
