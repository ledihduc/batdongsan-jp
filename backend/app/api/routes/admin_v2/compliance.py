"""Tin cậy & pháp lý — KYC doanh nghiệp, uỷ quyền, tranh chấp, legal hold,
chủ sở hữu mất, retention, nhật ký truy cập dữ liệu nhạy cảm.

Router MỎNG: DTO + gọi service domain qua `app/services/admin_v2/compliance_ops.py`.
Endpoint cũ (`/admin/kyc/*`, `/api/admin/delegations/*`, `/api/admin/disputes/*`,
`/api/admin/owner-death/*`, `/api/admin/retention/*`) GIỮ NGUYÊN cho Flutter.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.database import get_db
from app.domain.delegation import Delegation
from app.domain.operator_business import OperatorBusinessProfile
from app.domain.owner_death import OwnerDeathCertificate
from app.domain.tenant_authority import TenantAuthorityFlag
from app.services.admin_v2 import change_requests, compliance_ops as ops
from app.services.admin_v2.core import (
    AdminContext, CommandResult, PageParams, fail, idempotency_key, if_match, one, page_params, paged,
    paginate, require_any_permission, require_permission, run_command, utcnow,
)

router = APIRouter(prefix="/api/v2/admin/compliance", tags=["admin-v2-compliance"])


class ReasonBody(BaseModel):
    reason: str = Field("", max_length=1000)


def _conflict(exc: Exception):
    return fail(409, "ADMIN_INVALID_STATE", "Trạng thái hồ sơ không cho phép thao tác này", {"detail": str(exc)[:300]})


def _naive(v: Optional[datetime]) -> Optional[datetime]:
    """Giờ có múi (vd +07:00 từ FE) → UTC không múi như cột DB."""
    return v.astimezone(timezone.utc).replace(tzinfo=None) if v is not None and v.tzinfo is not None else v


# ═══ KYC doanh nghiệp ════════════════════════════════════════════════════════


def _kyc(db: Session, profile_id: int) -> OperatorBusinessProfile:
    p = db.get(OperatorBusinessProfile, profile_id)
    if p is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy hồ sơ KYC")
    return p


@router.get("/kyc")
def list_kyc(
    verification_status: str = Query("", max_length=30),
    q: str = Query("", max_length=100),
    overdue: str = Query("", pattern="^(|yes)$"),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_any_permission("kyc.review", "compliance.read")),
    db: Session = Depends(get_db),
):
    P = OperatorBusinessProfile
    query = db.query(P)
    if verification_status:
        if verification_status not in ops.KYC_STATUSES:
            raise fail(422, "ADMIN_BAD_FILTER", "Trạng thái KYC không hợp lệ")
        query = query.filter(P.verification_status == verification_status)
    term = q.strip()
    if term:
        like = f"%{term.lower()}%"
        conds = [func.lower(P.business_name).like(like), P.business_registration_number.like(f"%{term}%"),
                 func.lower(P.legal_representative_name).like(like)]
        if term.isdigit():
            conds += [P.id == int(term), P.user_id == int(term)]
        query = query.filter(or_(*conds))
    if overdue == "yes":
        query = query.filter(P.verification_status.in_(("pending", "pending_legal_rep_change")),
                             P.created_at < utcnow() - timedelta(hours=ops.KYC_SLA_HOURS))
    # Hàng đợi: cũ trước (SLA 48h) — giống `/admin/kyc/queue`.
    rows, total = paginate(query.order_by(P.created_at.asc(), P.id.asc()), page)
    holds = ops.held_ids(db, "kyc", [p.id for p in rows])
    cache: dict = {}
    now = utcnow()
    return paged([ops.kyc_row(db, p, cache, holds, now) for p in rows], total=total, page=page)


@router.get("/kyc/{profile_id}")
def get_kyc(
    profile_id: int,
    ctx: AdminContext = Depends(require_any_permission("kyc.review", "compliance.read")),
    db: Session = Depends(get_db),
):
    return one(ops.kyc_detail(db, _kyc(db, profile_id)))


def _kyc_command(db: Session, ctx: AdminContext, profile_id: int, body: ReasonBody, key: str,
                 expected: Optional[str], action: str, fn_name: str, status: str):
    from app.services.kyc import operator_business_service as svc

    p = _kyc(db, profile_id)

    def do() -> CommandResult:
        before = {"verification_status": p.verification_status}
        try:
            fn = getattr(svc, fn_name)
            if fn_name == "admin_reject_business":
                fn(profile_id=p.id, admin_user_id=ctx.user_id, reason=body.reason.strip(), db=db)
            else:
                fn(profile_id=p.id, admin_user_id=ctx.user_id, db=db)
        except ValueError as exc:
            raise _conflict(exc)
        db.flush()
        return CommandResult(data=ops.kyc_detail(db, p), before=before,
                             after={"verification_status": p.verification_status}, event_status=status)

    return run_command(
        db, ctx, action=action, permission="kyc.review", entity_type="kyc", entity_id=p.id, key=key, fn=do,
        reason=body.reason, reason_required=True, expected_version=expected,
        current_version=lambda: ops.kyc_version(p), event_type=f"admin.{action}",
    )


@router.post("/kyc/{profile_id}/approve")
def approve_kyc(profile_id: int, body: ReasonBody, key: str = Depends(idempotency_key),
                expected: Optional[str] = Depends(if_match),
                ctx: AdminContext = Depends(require_permission("kyc.review")), db: Session = Depends(get_db)):
    return _kyc_command(db, ctx, profile_id, body, key, expected, "kyc.approve", "admin_approve_business", "verified")


@router.post("/kyc/{profile_id}/reject")
def reject_kyc(profile_id: int, body: ReasonBody, key: str = Depends(idempotency_key),
               expected: Optional[str] = Depends(if_match),
               ctx: AdminContext = Depends(require_permission("kyc.review")), db: Session = Depends(get_db)):
    return _kyc_command(db, ctx, profile_id, body, key, expected, "kyc.reject", "admin_reject_business", "rejected")


@router.post("/kyc/{profile_id}/revoke-gpkd")
def revoke_gpkd(profile_id: int, body: ReasonBody, key: str = Depends(idempotency_key),
                expected: Optional[str] = Depends(if_match),
                ctx: AdminContext = Depends(require_permission("kyc.review")), db: Session = Depends(get_db)):
    return _kyc_command(db, ctx, profile_id, body, key, expected, "kyc.revoke_gpkd", "admin_revoke_gpkd", "revoked")


@router.post("/kyc/{profile_id}/approve-legal-rep-change")
def approve_legal_rep_change(profile_id: int, body: ReasonBody, key: str = Depends(idempotency_key),
                             expected: Optional[str] = Depends(if_match),
                             ctx: AdminContext = Depends(require_permission("kyc.review")),
                             db: Session = Depends(get_db)):
    return _kyc_command(db, ctx, profile_id, body, key, expected, "kyc.approve_legal_rep_change",
                        "admin_approve_legal_rep_change", "verified")


# ═══ Uỷ quyền vận hành ═══════════════════════════════════════════════════════


def _delegation(db: Session, delegation_id: str) -> Delegation:
    d = db.get(Delegation, delegation_id)
    if d is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy uỷ quyền")
    return d


@router.get("/delegations")
def list_delegations(
    status: str = Query("", max_length=30),
    owner_id: Optional[int] = Query(None),
    operator_id: Optional[int] = Query(None),
    paused_reason: str = Query("", max_length=50),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("compliance.read")),
    db: Session = Depends(get_db),
):
    D = Delegation
    query = db.query(D)
    if status:
        if status not in ops.DELEGATION_STATUSES:
            raise fail(422, "ADMIN_BAD_FILTER", "Trạng thái uỷ quyền không hợp lệ")
        query = query.filter(D.status == status)
    if owner_id is not None:
        query = query.filter(D.owner_id == owner_id)
    if operator_id is not None:
        query = query.filter(D.operator_id == operator_id)
    if paused_reason:
        query = query.filter(D.paused_reason == paused_reason)
    rows, total = paginate(query.order_by(D.updated_at.desc(), D.id.desc()), page)
    holds = ops.held_ids(db, "delegation", [d.id for d in rows])
    cache: dict = {}
    return paged([ops.delegation_row(db, d, cache, holds) for d in rows], total=total, page=page)


@router.get("/delegations/{delegation_id}")
def get_delegation(
    delegation_id: str,
    ctx: AdminContext = Depends(require_permission("compliance.read")),
    db: Session = Depends(get_db),
):
    return one(ops.delegation_detail(db, _delegation(db, delegation_id)))


class ForceRevokeBody(ReasonBody):
    immediate: bool = True


@router.post("/delegations/{delegation_id}/force-revoke")
def force_revoke(
    delegation_id: str,
    body: ForceRevokeBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("delegations.force_revoke")),
    db: Session = Depends(get_db),
):
    from app.services.admin.admin_delegation_actions import AdminDelegationActions

    d = _delegation(db, delegation_id)

    def do() -> CommandResult:
        if d.status in ("terminated", "archived"):
            raise fail(409, "ADMIN_INVALID_STATE", "Uỷ quyền đã chấm dứt")
        before = {"status": d.status, "paused_reason": d.paused_reason}
        try:
            AdminDelegationActions(db).force_revoke_delegation(
                delegation_id=d.id, admin_user_id=ctx.user_id, reason=body.reason.strip(), immediate=body.immediate)
        except ValueError as exc:
            raise _conflict(exc)
        return CommandResult(data=ops.delegation_detail(db, d), before=before,
                             after={"status": d.status, "terminate_reason": d.terminate_reason},
                             event_status=d.status)

    return run_command(
        db, ctx, action="delegation.force_revoke", permission="delegations.force_revoke", entity_type="delegation",
        entity_id=d.id, key=key, fn=do, reason=body.reason, reason_required=True, reauth=True,
        expected_version=expected, current_version=lambda: ops.delegation_version(d),
        event_type="admin.delegation.force_revoked",
    )


class RevokeRequestBody(BaseModel):
    reason: str = Field("", max_length=1000)
    immediate: bool = True
    dispute_id: Optional[str] = Field(None, max_length=64)


def _exec_revoke(db: Session, approver: AdminContext, payload: dict) -> dict:
    from app.services.admin.admin_delegation_actions import AdminDelegationActions

    d = _delegation(db, str(payload["delegation_id"]))
    if d.status in ("terminated", "archived"):
        raise fail(409, "ADMIN_INVALID_STATE", "Uỷ quyền đã chấm dứt")
    try:
        AdminDelegationActions(db).force_revoke_delegation(
            delegation_id=d.id, admin_user_id=approver.user_id,
            reason=str(payload.get("_reason") or "maker-checker"), immediate=bool(payload.get("immediate", True)))
    except ValueError as exc:
        raise _conflict(exc)
    return {"delegation_id": d.id, "status": d.status}


def _describe_revoke(db: Session, payload: dict) -> str:
    return f"Thu hồi uỷ quyền {str(payload.get('delegation_id'))[:8]}" + (
        f" (tranh chấp {str(payload.get('dispute_id'))[:8]})" if payload.get("dispute_id") else "")


def _preview_revoke(db: Session, payload: dict) -> list:
    d = _delegation(db, str(payload["delegation_id"]))
    return [
        {"label": "Hiệu lực uỷ quyền", "before": d.status, "after": "terminated (khi được duyệt)"},
        {"label": "Người vận hành", "before": "Được thao tác thay chủ nhà", "after": "Mất quyền ngay"
         if payload.get("immediate", True) else "Mất quyền sau thời gian báo trước"},
    ]


def _links_revoke(db: Session, payload: dict) -> list:
    out = [{"label": "Uỷ quyền", "ref": f"UQ-{str(payload.get('delegation_id'))[:8]}",
            "href": f"/admin/compliance/delegations?focus={payload.get('delegation_id')}"}]
    if payload.get("dispute_id"):
        out.append({"label": "Tranh chấp", "ref": f"TC-{str(payload['dispute_id'])[:8]}",
                    "href": f"/admin/compliance/disputes/{payload['dispute_id']}"})
    return out


change_requests.register(
    "delegation_force_revoke", permission="delegations.force_revoke", label="Thu hồi uỷ quyền",
    executor=_exec_revoke, describe=_describe_revoke, preview=_preview_revoke, links=_links_revoke,
)


@router.post("/delegations/{delegation_id}/revoke-requests")
def request_revoke(
    delegation_id: str,
    body: RevokeRequestBody,
    key: str = Depends(idempotency_key),
    ctx: AdminContext = Depends(require_any_permission("disputes.manage", "delegations.force_revoke")),
    db: Session = Depends(get_db),
):
    """Đề nghị thu hồi — chỉ có hiệu lực khi người có quyền thu hồi KHÁC duyệt."""
    d = _delegation(db, delegation_id)

    def do() -> CommandResult:
        if d.status in ("terminated", "archived"):
            raise fail(409, "ADMIN_INVALID_STATE", "Uỷ quyền đã chấm dứt")
        req = change_requests.create(
            db, ctx, kind="delegation_force_revoke", reason=body.reason.strip(),
            payload={"delegation_id": d.id, "immediate": body.immediate, "dispute_id": body.dispute_id},
        )
        return CommandResult(data={"pending_approval": True, "change_request": change_requests.to_dict(db, req, detail=True)},
                             after={"change_request_id": req.id}, event_status="PENDING")

    return run_command(
        db, ctx, action="delegation.revoke_requested", permission="disputes.manage", entity_type="delegation",
        entity_id=d.id, key=key, fn=do, reason=body.reason, reason_required=True,
        event_type="admin.work_item.created",
    )


@router.get("/operators/{user_id}")
def get_operator(
    user_id: int,
    ctx: AdminContext = Depends(require_permission("compliance.read")),
    db: Session = Depends(get_db),
):
    from app import models

    if db.get(models.User, user_id) is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy người dùng")
    return one(ops.operator_summary(db, user_id))


def _operator_command(db: Session, ctx: AdminContext, user_id: int, body: ReasonBody, key: str,
                      expected: Optional[str], suspend: bool):
    from app import models
    from app.services.admin.admin_delegation_actions import AdminDelegationActions

    if db.get(models.User, user_id) is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy người dùng")
    if user_id == ctx.user_id:
        raise fail(403, "ADMIN_SELF_ACTION", "Không thể thao tác trên chính tài khoản của bạn")

    def do() -> CommandResult:
        svc = AdminDelegationActions(db)
        if suspend:
            n = svc.suspend_operator(operator_user_id=user_id, admin_user_id=ctx.user_id, reason=body.reason.strip())
        else:
            n = svc.reinstate_operator(operator_user_id=user_id, admin_user_id=ctx.user_id, reason=body.reason.strip())
        if n == 0:
            raise fail(409, "ADMIN_NOTHING_TO_CHANGE",
                       "Không có uỷ quyền đang hoạt động để đình chỉ" if suspend
                       else "Không có uỷ quyền nào đang bị đình chỉ bởi quản trị")
        key_n = "delegations_paused" if suspend else "delegations_reinstated"
        return CommandResult(data={**ops.operator_summary(db, user_id), key_n: n},
                             after={key_n: n}, event_status="suspended" if suspend else "active")

    action = "operator.suspend" if suspend else "operator.reinstate"
    return run_command(
        db, ctx, action=action, permission="delegations.force_revoke", entity_type="user", entity_id=user_id,
        key=key, fn=do, reason=body.reason, reason_required=True, expected_version=expected,
        current_version=lambda: ops.operator_version(db, user_id), event_type=f"admin.{action}",
    )


@router.post("/operators/{user_id}/suspend")
def suspend_operator(user_id: int, body: ReasonBody, key: str = Depends(idempotency_key),
                     expected: Optional[str] = Depends(if_match),
                     ctx: AdminContext = Depends(require_permission("delegations.force_revoke")),
                     db: Session = Depends(get_db)):
    return _operator_command(db, ctx, user_id, body, key, expected, True)


@router.post("/operators/{user_id}/reinstate")
def reinstate_operator(user_id: int, body: ReasonBody, key: str = Depends(idempotency_key),
                       expected: Optional[str] = Depends(if_match),
                       ctx: AdminContext = Depends(require_permission("delegations.force_revoke")),
                       db: Session = Depends(get_db)):
    return _operator_command(db, ctx, user_id, body, key, expected, False)


# ═══ Tranh chấp (người thuê báo operator không được uỷ quyền) ═════════════════


def _dispute(db: Session, dispute_id: str) -> TenantAuthorityFlag:
    f = db.get(TenantAuthorityFlag, dispute_id)
    if f is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy tranh chấp")
    return f


@router.get("/disputes")
def list_disputes(
    status: str = Query("", max_length=20),
    operator_id: Optional[int] = Query(None),
    delegation_id: str = Query("", max_length=36),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("compliance.read")),
    db: Session = Depends(get_db),
):
    F = TenantAuthorityFlag
    query = db.query(F)
    if status:
        if status not in ops.DISPUTE_STATUSES:
            raise fail(422, "ADMIN_BAD_FILTER", "Trạng thái tranh chấp không hợp lệ")
        query = query.filter(F.status == status)
    if operator_id is not None:
        query = query.filter(F.reported_operator_user_id == operator_id)
    if delegation_id:
        query = query.filter(F.delegation_id == delegation_id)
    rows, total = paginate(query.order_by(F.created_at.asc(), F.id.asc()), page)
    holds = ops.held_ids(db, "dispute", [f.id for f in rows])
    cache: dict = {}
    now = utcnow()
    return paged([ops.dispute_row(db, f, cache, holds, now) for f in rows], total=total, page=page)


@router.get("/disputes/{dispute_id}")
def get_dispute(
    dispute_id: str,
    ctx: AdminContext = Depends(require_permission("compliance.read")),
    db: Session = Depends(get_db),
):
    return one(ops.dispute_detail(db, _dispute(db, dispute_id)))


@router.post("/disputes/{dispute_id}/escalate")
def escalate_dispute(
    dispute_id: str,
    body: ReasonBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("disputes.manage")),
    db: Session = Depends(get_db),
):
    from app.services.admin.admin_dispute_service import AdminDisputeService

    f = _dispute(db, dispute_id)

    def do() -> CommandResult:
        before = {"status": f.status}
        try:
            AdminDisputeService(db).escalate_dispute(dispute_id=f.id, admin_user_id=ctx.user_id,
                                                     reason=body.reason.strip())
        except ValueError as exc:
            raise _conflict(exc)
        return CommandResult(data=ops.dispute_detail(db, f), before=before, after={"status": f.status},
                             event_status=f.status)

    return run_command(
        db, ctx, action="dispute.escalate", permission="disputes.manage", entity_type="dispute", entity_id=f.id,
        key=key, fn=do, reason=body.reason, reason_required=True, expected_version=expected,
        current_version=lambda: ops.dispute_version(f), event_type="admin.dispute.escalated",
    )


class ResolveBody(ReasonBody):
    outcome: str = Field(..., pattern="^(prima_facie_valid|invalid|requires_evidence)$")
    action: str = Field(..., pattern="^(pause_delegation|no_action|request_more_info)$")


@router.post("/disputes/{dispute_id}/resolve")
def resolve_dispute(
    dispute_id: str,
    body: ResolveBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("disputes.manage")),
    db: Session = Depends(get_db),
):
    from app.services.admin.admin_dispute_service import AdminDisputeService

    f = _dispute(db, dispute_id)

    def do() -> CommandResult:
        before = {"status": f.status}
        try:
            res = AdminDisputeService(db).resolve_dispute(
                dispute_id=f.id, admin_user_id=ctx.user_id, outcome=body.outcome, action=body.action,
                reason=body.reason.strip())
        except ValueError as exc:
            raise _conflict(exc)
        detail = ops.dispute_detail(db, f)
        detail["resolution"] = {"outcome": res["outcome"], "action": res["action"],
                                "delegation_paused": bool(res["delegation_paused"])}
        return CommandResult(data=detail, before=before,
                             after={"status": f.status, "outcome": body.outcome, "action": body.action,
                                    "delegation_paused": bool(res["delegation_paused"])},
                             event_status=f.status)

    return run_command(
        db, ctx, action="dispute.resolve", permission="disputes.manage", entity_type="dispute", entity_id=f.id,
        key=key, fn=do, reason=body.reason, reason_required=True, expected_version=expected,
        current_version=lambda: ops.dispute_version(f), event_type="admin.dispute.resolved",
    )


# ═══ Legal hold ══════════════════════════════════════════════════════════════


class LegalHoldBody(ReasonBody):
    source_type: str = Field(..., max_length=40)
    source_id: str = Field(..., min_length=1, max_length=64)
    hold: bool


@router.get("/legal-holds")
def list_legal_holds(
    source_type: str = Query("", max_length=40),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("compliance.read")),
    db: Session = Depends(get_db),
):
    from app import models

    C = models.AdminCase
    query = db.query(C).filter(C.legal_hold == True)  # noqa: E712
    if source_type:
        query = query.filter(C.source_type == source_type)
    rows, total = paginate(query.order_by(C.updated_at.desc(), C.id.desc()), page)
    cache: dict = {}
    return paged([ops.case_dict(db, c, cache) for c in rows], total=total, page=page,
                 source_types=list(ops.LEGAL_HOLD_SOURCES))


@router.post("/legal-holds")
def set_legal_hold(
    body: LegalHoldBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("retention.manage")),
    db: Session = Depends(get_db),
):
    """If-Match = `case_version` của màn chi tiết ("0" khi chưa có case)."""
    if body.source_type not in ops.LEGAL_HOLD_SOURCES:
        raise fail(422, "ADMIN_BAD_SOURCE", "Loại đối tượng không hỗ trợ legal hold",
                   {"allowed": list(ops.LEGAL_HOLD_SOURCES)})
    if ops.load_hold_target(db, body.source_type, body.source_id) is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy đối tượng")

    def do() -> CommandResult:
        c, before = ops.set_legal_hold(db, actor_id=ctx.user_id, source_type=body.source_type,
                                       source_id=body.source_id, hold=body.hold, reason=body.reason.strip())
        if before == body.hold:
            raise fail(409, "ADMIN_NOTHING_TO_CHANGE",
                       "Đối tượng đã ở trạng thái legal hold này")
        return CommandResult(data=ops.case_dict(db, c), before={"legal_hold": before},
                             after={"legal_hold": body.hold}, event_status="hold" if body.hold else "released")

    return run_command(
        db, ctx, action="legal_hold.set" if body.hold else "legal_hold.release", permission="retention.manage",
        entity_type=body.source_type, entity_id=body.source_id, key=key, fn=do, reason=body.reason,
        reason_required=True, expected_version=expected,
        current_version=lambda: ops.case_version(ops.case_of(db, body.source_type, body.source_id)),
        event_type="admin.legal_hold.updated",
    )


# ═══ Chủ sở hữu mất ═══════════════════════════════════════════════════════════


def _cert(db: Session, cert_id: str) -> OwnerDeathCertificate:
    c = db.get(OwnerDeathCertificate, cert_id)
    if c is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy hồ sơ")
    return c


@router.get("/owner-death")
def list_owner_death(
    status: str = Query("", max_length=20),
    owner_id: Optional[int] = Query(None),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("compliance.read")),
    db: Session = Depends(get_db),
):
    C = OwnerDeathCertificate
    query = db.query(C)
    if status:
        if status not in ops.DEATH_STATUSES:
            raise fail(422, "ADMIN_BAD_FILTER", "Trạng thái không hợp lệ")
        query = query.filter(C.verification_status == status)
    if owner_id is not None:
        query = query.filter(C.owner_user_id == owner_id)
    rows, total = paginate(query.order_by(C.created_at.asc(), C.id.asc()), page)
    holds = ops.held_ids(db, "owner_death", [c.id for c in rows])
    cache: dict = {}
    now = utcnow()
    return paged([ops.death_row(db, c, cache, holds, now) for c in rows], total=total, page=page)


@router.get("/owner-death/{cert_id}")
def get_owner_death(
    cert_id: str,
    ctx: AdminContext = Depends(require_permission("compliance.read")),
    db: Session = Depends(get_db),
):
    return one(ops.death_detail(db, _cert(db, cert_id)))


class DeathVerifyBody(ReasonBody):
    in_flight_handling_policy: str = Field("auto_reject", pattern="^(auto_reject|executor_may_decide)$")


@router.post("/owner-death/{cert_id}/verify")
def verify_owner_death(
    cert_id: str,
    body: DeathVerifyBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("disputes.manage")),
    db: Session = Depends(get_db),
):
    from app.services.owner_death import DeathCertificateService, DeathPauseService
    from app.services.owner_death.death_certificate_service import InvalidVerificationStateError

    c = _cert(db, cert_id)

    def do() -> CommandResult:
        try:
            cert = DeathCertificateService(db).verify_death(
                cert_id=c.id, admin_user_id=ctx.user_id, notes=body.reason.strip(),
                in_flight_handling_policy=body.in_flight_handling_policy)
            paused = DeathPauseService(db).pause_all_owner_delegations(cert=cert, admin_user_id=ctx.user_id)
        except (InvalidVerificationStateError, ValueError) as exc:
            raise _conflict(exc)
        detail = ops.death_detail(db, c)
        detail["delegations_paused"] = len(paused)
        detail["sla_warning"] = bool(c.created_at and (utcnow() - c.created_at).total_seconds() > ops.DEATH_SLA_HOURS * 3600)
        return CommandResult(data=detail, before={"verification_status": "pending"},
                             after={"verification_status": c.verification_status, "delegations_paused": len(paused),
                                    "delegation_ids_paused": paused[:100],
                                    "in_flight_handling_policy": body.in_flight_handling_policy},
                             event_status=c.verification_status)

    return run_command(
        db, ctx, action="owner_death.verify", permission="disputes.manage", entity_type="owner_death",
        entity_id=c.id, key=key, fn=do, reason=body.reason, reason_required=True, reauth=True,
        expected_version=expected, current_version=lambda: ops.death_version(c),
        event_type="admin.owner_death.verified",
    )


@router.post("/owner-death/{cert_id}/reject")
def reject_owner_death(
    cert_id: str,
    body: ReasonBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("disputes.manage")),
    db: Session = Depends(get_db),
):
    from app.services.owner_death import DeathCertificateService
    from app.services.owner_death.death_certificate_service import InvalidVerificationStateError

    c = _cert(db, cert_id)
    # Đường cũ đòi lý do ≥10 ký tự cho từ chối giấy chứng tử — giữ cùng ngưỡng.
    if len(body.reason.strip()) < 10:
        raise fail(422, "ADMIN_REASON_REQUIRED", "Cần nhập lý do từ chối (ít nhất 10 ký tự)")

    def do() -> CommandResult:
        try:
            DeathCertificateService(db).reject_death(cert_id=c.id, admin_user_id=ctx.user_id,
                                                     rejection_reason=body.reason.strip())
        except InvalidVerificationStateError as exc:
            raise _conflict(exc)
        return CommandResult(data=ops.death_detail(db, c), before={"verification_status": "pending"},
                             after={"verification_status": c.verification_status}, event_status=c.verification_status)

    return run_command(
        db, ctx, action="owner_death.reject", permission="disputes.manage", entity_type="owner_death",
        entity_id=c.id, key=key, fn=do, reason=body.reason, reason_required=True,
        expected_version=expected, current_version=lambda: ops.death_version(c),
        event_type="admin.owner_death.rejected",
    )


# ═══ Retention ════════════════════════════════════════════════════════════════


@router.get("/retention")
def retention_status(
    ctx: AdminContext = Depends(require_any_permission("retention.manage", "compliance.read")),
    db: Session = Depends(get_db),
):
    return one(ops.retention_status(db))


@router.post("/retention/run")
def retention_run(
    body: ReasonBody,
    key: str = Depends(idempotency_key),
    ctx: AdminContext = Depends(require_permission("retention.manage")),
    db: Session = Depends(get_db),
):
    def do() -> CommandResult:
        res = ops.run_retention(db)
        return CommandResult(data=res, after=res, event_status="error" if res.get("errors") else "ok")

    return run_command(
        db, ctx, action="retention.run", permission="retention.manage", entity_type="retention",
        entity_id="pdpl", key=key, fn=do, reason=body.reason, reason_required=True, reauth=True,
        event_type="admin.retention.ran",
    )


@router.post("/retention/archive-delegations")
def retention_archive(
    body: ReasonBody,
    key: str = Depends(idempotency_key),
    ctx: AdminContext = Depends(require_permission("retention.manage")),
    db: Session = Depends(get_db),
):
    def do() -> CommandResult:
        res = ops.archive_delegations(db, ctx.user_id)
        return CommandResult(data=res, after=res, event_status="ok")

    return run_command(
        db, ctx, action="retention.archive_delegations", permission="retention.manage", entity_type="retention",
        entity_id="delegations", key=key, fn=do, reason=body.reason, reason_required=True, reauth=True,
        event_type="admin.retention.archived",
    )


# ═══ Nhật ký truy cập dữ liệu nhạy cảm ════════════════════════════════════════


@router.get("/access-logs")
def access_logs(
    kind: str = Query("", max_length=60),
    user_id: Optional[int] = Query(None),
    date_from: Optional[datetime] = Query(None),
    date_to: Optional[datetime] = Query(None),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_any_permission("compliance.read", "audit.read")),
    db: Session = Depends(get_db),
):
    kinds = tuple(k for k in kind.split(",") if k) or ops.ACCESS_KINDS
    bad = [k for k in kinds if k not in ops.ACCESS_KINDS]
    if bad:
        raise fail(422, "ADMIN_BAD_FILTER", "Loại nhật ký không hợp lệ", {"allowed": list(ops.ACCESS_KINDS)})
    data, total, truncated, counts, failed = ops.access_logs(
        db, kinds=kinds, filters={"user_id": user_id, "date_from": _naive(date_from), "date_to": _naive(date_to)},
        offset=page.offset, limit=page.limit)
    return paged(data, total=total, page=page, truncated=truncated, counts_by_kind=counts, partial_error=failed)
