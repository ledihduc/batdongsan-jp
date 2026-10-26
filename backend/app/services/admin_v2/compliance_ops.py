"""Tin cậy & pháp lý (Admin V2) — DTO + thao tác trên các service domain SẴN CÓ.

Không viết lại nghiệp vụ: KYC dùng `services/kyc/operator_business_service`,
uỷ quyền dùng `services/admin/admin_delegation_actions`, tranh chấp dùng
`services/admin/admin_dispute_service`, chủ sở hữu mất dùng
`services/owner_death/*`, retention dùng `services/retention/*`. Các service đó
chỉ flush → `run_command` commit MỘT lần cùng nhật ký quản trị.

Ngoại lệ: `PdplTierService.run_daily_transitions()` tự commit theo từng tầng
(thiết kế cho cron) — xem `run_retention()`.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta
from typing import Any, Optional

from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app import models
from app.domain.bank_account_reveal_log import BankAccountRevealLog
from app.domain.delegation import Delegation, DelegationApproval
from app.domain.operator_business import OperatorBusinessProfile
from app.domain.owner_death import OwnerDeathCertificate
from app.domain.tenant_authority import TenantAuthorityFlag
from app.services.admin_v2 import documents as docs
from app.services.admin_v2.core import etag, hash_ip, iso, mask_phone, user_brief, utcnow

logger = logging.getLogger(__name__)

KYC_SLA_HOURS = 48
DISPUTE_SLA_HOURS = 48
DEATH_SLA_HOURS = 24
ARCHIVE_AFTER_DAYS = 30

# ── Legal hold (admin_cases.legal_hold) ───────────────────────────────────────

# source_type → (model, khoá int?) — mã trùng với loại việc trong work_items
# để một case dùng chung cho hộp việc và legal hold.
LEGAL_HOLD_SOURCES: dict[str, tuple[Any, bool]] = {
    "dispute": (TenantAuthorityFlag, False),
    "delegation": (Delegation, False),
    "kyc": (OperatorBusinessProfile, True),
    "owner_death": (OwnerDeathCertificate, False),
    "rental_journey": (models.RentalJourney, True),
    "contract": (models.Contract, True),
    "platform_payment": (models.PlatformPayment, True),
    "user": (models.User, True),
}


def load_hold_target(db: Session, source_type: str, source_id: str):
    spec = LEGAL_HOLD_SOURCES.get(source_type)
    if spec is None:
        return None
    model, int_key = spec
    try:
        return db.get(model, int(source_id) if int_key else str(source_id))
    except (TypeError, ValueError):
        return None


def case_of(db: Session, source_type: str, source_id: Any) -> Optional[models.AdminCase]:
    return db.query(models.AdminCase).filter_by(source_type=source_type, source_id=str(source_id)).first()


def held_ids(db: Session, source_type: str, ids: list) -> set[str]:
    if not ids:
        return set()
    rows = (
        db.query(models.AdminCase.source_id)
        .filter(models.AdminCase.source_type == source_type,
                models.AdminCase.source_id.in_([str(i) for i in ids]),
                models.AdminCase.legal_hold == True)  # noqa: E712
        .all()
    )
    return {r[0] for r in rows}


def case_version(c: Optional[models.AdminCase]) -> str:
    return str(c.version) if c is not None else "0"


def case_dict(db: Session, c: Optional[models.AdminCase], cache: Optional[dict] = None) -> Optional[dict]:
    if c is None:
        return None
    return {
        "id": c.id, "source_type": c.source_type, "source_id": c.source_id, "status": c.status,
        "priority": c.priority, "legal_hold": bool(c.legal_hold),
        "assignee": user_brief(db, c.assignee_user_id, cache), "internal_note": c.internal_note,
        "version": str(c.version), "updated_at": iso(c.updated_at),
    }


def set_legal_hold(db: Session, *, actor_id: int, source_type: str, source_id: str, hold: bool,
                   reason: str) -> tuple[models.AdminCase, bool]:
    c = case_of(db, source_type, source_id)
    if c is None:
        c = models.AdminCase(source_type=source_type, source_id=str(source_id), priority="normal",
                             status="open", version=0, legal_hold=False)
        db.add(c)
        db.flush()
    before = bool(c.legal_hold)
    c.legal_hold = hold
    c.version = (c.version or 0) + 1
    c.updated_at = utcnow()
    db.add(models.AdminCaseEvent(case_id=c.id, actor_user_id=actor_id, kind="legal_hold",
                                 payload={"legal_hold": hold, "reason": reason}))
    db.flush()
    return c, before


# ── Tiện ích ──────────────────────────────────────────────────────────────────


def _age_hours(created: Optional[datetime], now: datetime) -> Optional[float]:
    if created is None:
        return None
    return round((now - created).total_seconds() / 3600, 1)


def _sla(created: Optional[datetime], hours: int, open_: bool, now: datetime) -> dict:
    due = created + timedelta(hours=hours) if created else None
    return {"sla_due_at": iso(due), "overdue": bool(open_ and due is not None and due < now)}


def admin_history(db: Session, entity_type: str, entity_id: Any, limit: int = 50) -> list[dict]:
    L = models.AdminActionLog
    rows = (
        db.query(L).filter(L.entity_type == entity_type, L.entity_id == str(entity_id),
                           L.action.notin_(("document.open",)))
        .order_by(L.id.desc()).limit(limit).all()
    )
    cache: dict = {}
    return [{
        "id": r.id, "action": r.action, "actor": user_brief(db, r.actor_user_id, cache), "reason": r.reason,
        "before": r.before_json, "after": r.after_json, "result": r.result, "created_at": iso(r.created_at),
    } for r in rows]


# ── KYC ───────────────────────────────────────────────────────────────────────

KYC_STATUSES = ("pending", "verified", "rejected", "revoked", "pending_legal_rep_change")


def kyc_version(p: OperatorBusinessProfile) -> str:
    return etag(p.id, p.verification_status, iso(p.updated_at), p.legal_representative_cccd_front_path)


def kyc_row(db: Session, p: OperatorBusinessProfile, cache: dict, holds: set[str], now: datetime) -> dict:
    open_ = p.verification_status in ("pending", "pending_legal_rep_change")
    return {
        "id": p.id,
        "ref": f"KYC-{p.id:05d}",
        "user": user_brief(db, p.user_id, cache),
        "business_name": p.business_name,
        "business_registration_number": p.business_registration_number,
        "verification_status": p.verification_status,
        "legal_representative_name": p.legal_representative_name,
        "legal_representative_phone_masked": mask_phone(p.legal_representative_phone),
        "gpkd_issued_at": iso(p.gpkd_issued_at),
        "gpkd_expires_at": iso(p.gpkd_expires_at),
        "created_at": iso(p.created_at),
        "updated_at": iso(p.updated_at),
        "age_hours": _age_hours(p.created_at, now),
        **_sla(p.created_at, KYC_SLA_HOURS, open_, now),
        "legal_hold": str(p.id) in holds,
        "version": kyc_version(p),
    }


def kyc_detail(db: Session, p: OperatorBusinessProfile) -> dict:
    cache: dict = {}
    now = utcnow()
    c = case_of(db, "kyc", p.id)
    out = kyc_row(db, p, cache, {str(p.id)} if c and c.legal_hold else set(), now)
    out.update({
        "gpkd_industry_codes": p.gpkd_industry_codes_json or [],
        "verified_at": iso(p.verified_at),
        "verified_by": user_brief(db, p.verified_by_user_id, cache),
        "previous_legal_rep": user_brief(db, p.previous_legal_rep_user_id, cache),
        "legal_rep_changed_at": iso(p.legal_rep_changed_at),
        "has_legal_rep_cccd_hash": bool(p.legal_representative_cccd_number_hash),
        "documents": docs.describe("operator_business_profile", p),
        "allowed_actions": {
            "approve": p.verification_status == "pending",
            "reject": p.verification_status == "pending",
            "revoke_gpkd": p.verification_status == "verified",
            "approve_legal_rep_change": p.verification_status == "pending_legal_rep_change",
        },
        "case": case_dict(db, c, cache),
        "case_version": case_version(c),
        "history": admin_history(db, "kyc", p.id),
    })
    return out


# ── Uỷ quyền ──────────────────────────────────────────────────────────────────

DELEGATION_STATUSES = ("pending_op_kyc", "active", "paused", "terminating", "terminated", "archived")


def delegation_version(d: Delegation) -> str:
    return etag(d.id, d.status, d.paused_reason, iso(d.updated_at))


def _num(v) -> Optional[float]:
    try:
        return float(v) if v is not None else None
    except (TypeError, ValueError):
        return None


def delegation_row(db: Session, d: Delegation, cache: dict, holds: set[str]) -> dict:
    return {
        "id": d.id,
        "ref": f"UQ-{d.id[:8].upper()}",
        "owner": user_brief(db, d.owner_id, cache),
        "operator": user_brief(db, d.operator_id, cache),
        "status": d.status,
        "paused_reason": d.paused_reason,
        "paused_until": iso(d.paused_until),
        "role_preset": d.role_preset,
        "scope_type": d.scope_type,
        "poa_format": d.poa_format,
        "has_poa_document": bool(d.poa_document_path),
        "activated_at": iso(d.activated_at),
        "terminate_requested_at": iso(d.terminate_requested_at),
        "terminate_reason": d.terminate_reason,
        "terminated_at": iso(d.terminated_at),
        "archived_at": iso(d.archived_at),
        "retention_tier": d.retention_tier,
        "created_at": iso(d.created_at),
        "updated_at": iso(d.updated_at),
        "legal_hold": d.id in holds,
        "version": delegation_version(d),
    }


def _approval_dict(db: Session, a: DelegationApproval, cache: dict) -> dict:
    return {
        "id": a.id, "action_type": a.action_type, "entity_type": a.entity_type, "entity_id": a.entity_id,
        "status": a.status, "sla_class": a.sla_class, "expires_at": iso(a.expires_at),
        "requester": user_brief(db, a.requester_user_id, cache),
        "decided_at": iso(a.decided_at), "decided_by": user_brief(db, a.decided_by_user_id, cache),
        "decision_reason": a.decision_reason, "escalation_state": a.escalation_state,
        "requires_biometric": bool(a.requires_biometric), "requested_amount_vnd": _num(a.requested_amount_vnd),
        "lockdown_fraud_termination": bool(getattr(a, "lockdown_fraud_termination", False)),
        "created_at": iso(a.created_at),
    }


def delegation_audit_trail(db: Session, delegation_id: str, limit: int = 100) -> list[dict]:
    """Cùng logic `AdminDashboardService.audit_trail_for_delegation` nhưng CÓ GIỚI HẠN
    (bản gốc tải toàn bộ change_logs của uỷ quyền) và mới nhất trước."""
    C = models.ChangeLog
    rows = (
        db.query(C).filter(C.acted_via_delegation_id == delegation_id)
        .order_by(C.created_at.desc(), C.id.desc()).limit(limit).all()
    )
    cache: dict = {}
    out = []
    for r in rows:
        extra = None
        if r.after_json:
            try:
                extra = json.loads(r.after_json)
            except (TypeError, ValueError):
                extra = {"raw": str(r.after_json)[:500]}
        out.append({
            "id": r.id, "action": r.action, "actor": user_brief(db, r.actor_id, cache),
            "on_behalf_of": user_brief(db, r.on_behalf_of_user_id, cache),
            "entity_type": r.entity_type, "entity_id": r.entity_id, "extra": extra,
            "created_at": iso(r.created_at),
        })
    return out


def delegation_detail(db: Session, d: Delegation) -> dict:
    cache: dict = {}
    c = case_of(db, "delegation", d.id)
    out = delegation_row(db, d, cache, {d.id} if c and c.legal_hold else set())
    A = DelegationApproval
    approvals_q = db.query(A).filter(A.delegation_id == d.id)
    approvals_total = approvals_q.order_by(None).count()
    approvals = approvals_q.order_by(A.created_at.desc()).limit(50).all()
    disputes = (
        db.query(TenantAuthorityFlag).filter(TenantAuthorityFlag.delegation_id == d.id)
        .order_by(TenantAuthorityFlag.created_at.desc()).limit(20).all()
    )
    out.update({
        "commission_pct": _num(d.commission_pct),
        "commission_fixed_vnd": _num(d.commission_fixed_vnd),
        "thresholds": {
            "monthly_rent_vnd": _num(d.threshold_monthly_rent_vnd),
            "term_months": d.threshold_term_months,
            "expense_vnd": _num(d.threshold_expense_vnd),
            "rent_change_pct": _num(d.threshold_rent_change_pct),
            "refund_vnd": _num(d.threshold_refund_vnd),
        },
        "scope_target_ids": d.scope_target_ids,
        "out_of_office": {"start": iso(d.out_of_office_start), "end": iso(d.out_of_office_end)},
        "approvals": [_approval_dict(db, a, cache) for a in approvals],
        "approvals_total": approvals_total,
        "disputes": [{"id": f.id, "status": f.status, "created_at": iso(f.created_at)} for f in disputes],
        "audit_trail": delegation_audit_trail(db, d.id),
        "documents": docs.describe("delegation", d),
        "allowed_actions": {"force_revoke": d.status != "archived" and d.status != "terminated"},
        "case": case_dict(db, c, cache),
        "case_version": case_version(c),
        "history": admin_history(db, "delegation", d.id),
    })
    return out


def operator_version(db: Session, user_id: int) -> str:
    rows = (
        db.query(Delegation.id, Delegation.status, Delegation.paused_reason)
        .filter(Delegation.operator_id == user_id, Delegation.status.in_(("active", "paused")))
        .order_by(Delegation.id).all()
    )
    return etag(user_id, [list(r) for r in rows])


def operator_summary(db: Session, user_id: int) -> dict:
    D = Delegation
    counts = dict(
        db.query(D.status, func.count(D.id)).filter(D.operator_id == user_id).group_by(D.status).all()
    )
    admin_suspended = db.query(func.count(D.id)).filter(
        D.operator_id == user_id, D.status == "paused", D.paused_reason == "admin_suspend").scalar() or 0
    kyc = db.query(OperatorBusinessProfile).filter(OperatorBusinessProfile.user_id == user_id).first()
    u = db.get(models.User, user_id)
    return {
        "user": user_brief(db, user_id),
        "is_operator_capable": bool(getattr(u, "is_operator_capable", False)) if u else False,
        "delegations_by_status": {k: int(v) for k, v in counts.items()},
        "delegations_active": int(counts.get("active", 0)),
        "delegations_admin_suspended": int(admin_suspended),
        "suspended": admin_suspended > 0 and not counts.get("active"),
        "kyc": None if kyc is None else {"id": kyc.id, "verification_status": kyc.verification_status,
                                         "business_name": kyc.business_name},
        "allowed_actions": {"suspend": bool(counts.get("active")), "reinstate": admin_suspended > 0},
        "version": operator_version(db, user_id),
    }


# ── Tranh chấp ────────────────────────────────────────────────────────────────

DISPUTE_STATUSES = ("pending", "escalated", "valid", "invalid")


def dispute_version(f: TenantAuthorityFlag) -> str:
    return etag(f.id, f.status, iso(f.reviewed_at))


def _tenant(db: Session, tenant_id: Optional[int]) -> Optional[dict]:
    t = db.get(models.Tenant, tenant_id) if tenant_id else None
    if t is None:
        return None
    return {"id": t.id, "name": t.full_name, "phone_masked": mask_phone(t.phone), "host_id": t.host_id}


def dispute_row(db: Session, f: TenantAuthorityFlag, cache: dict, holds: set[str], now: datetime) -> dict:
    open_ = f.status in ("pending", "escalated")
    return {
        "id": f.id,
        "ref": f"TC-{f.id[:8].upper()}",
        "tenant": _tenant(db, f.tenant_id),
        "reported_operator": user_brief(db, f.reported_operator_user_id, cache),
        "delegation_id": f.delegation_id,
        "report_reason": f.report_reason,
        "status": f.status,
        "reviewed_at": iso(f.reviewed_at),
        "reviewed_by": user_brief(db, f.reviewed_by_admin_id, cache),
        "created_at": iso(f.created_at),
        "age_hours": _age_hours(f.created_at, now),
        **_sla(f.created_at, DISPUTE_SLA_HOURS, open_, now),
        "legal_hold": f.id in holds,
        "version": dispute_version(f),
    }


def dispute_detail(db: Session, f: TenantAuthorityFlag) -> dict:
    cache: dict = {}
    c = case_of(db, "dispute", f.id)
    out = dispute_row(db, f, cache, {f.id} if c and c.legal_hold else set(), utcnow())
    d = db.get(Delegation, f.delegation_id) if f.delegation_id else None
    out.update({
        "delegation": None if d is None else delegation_row(db, d, cache, held_ids(db, "delegation", [d.id])),
        "allowed_actions": {"escalate": f.status == "pending", "resolve": f.status in ("pending", "escalated")},
        "case": case_dict(db, c, cache),
        "case_version": case_version(c),
        "history": admin_history(db, "dispute", f.id),
    })
    return out


# ── Chủ sở hữu mất ────────────────────────────────────────────────────────────

DEATH_STATUSES = ("pending", "verified", "rejected")


def death_version(c: OwnerDeathCertificate) -> str:
    return etag(c.id, c.verification_status, iso(c.verified_at), c.executor_user_id)


def death_row(db: Session, c: OwnerDeathCertificate, cache: dict, holds: set[str], now: datetime) -> dict:
    open_ = c.verification_status == "pending"
    return {
        "id": c.id,
        "ref": f"CSM-{c.id[:8].upper()}",
        "owner": user_brief(db, c.owner_user_id, cache),
        "submitted_by": user_brief(db, c.submitted_by_user_id, cache),
        "executor": user_brief(db, c.executor_user_id, cache),
        "executor_onboarded_at": iso(c.executor_onboarded_at),
        "verification_status": c.verification_status,
        "verified_at": iso(c.verified_at),
        "verified_by": user_brief(db, c.verified_by_admin_id, cache),
        "has_notarized_poa": bool(c.notarized_poa_path),
        "created_at": iso(c.created_at),
        "age_hours": _age_hours(c.created_at, now),
        **_sla(c.created_at, DEATH_SLA_HOURS, open_, now),
        "legal_hold": c.id in holds,
        "version": death_version(c),
    }


def death_detail(db: Session, c: OwnerDeathCertificate) -> dict:
    cache: dict = {}
    case = case_of(db, "owner_death", c.id)
    out = death_row(db, c, cache, {c.id} if case and case.legal_hold else set(), utcnow())
    D = Delegation
    by_status = dict(db.query(D.status, func.count(D.id)).filter(D.owner_id == c.owner_user_id).group_by(D.status).all())
    inherit = None
    if c.executor_user_id:
        iv = (db.query(D).filter(D.owner_id == c.owner_user_id, D.operator_id == c.executor_user_id,
                                 D.role_preset == "owner_view").order_by(D.created_at.desc()).first())
        if iv is not None:
            inherit = {"delegation_id": iv.id, "status": iv.status, "paused_until": iso(iv.paused_until)}
    out.update({
        "heir": None if not c.executor_user_id else {
            "user": user_brief(db, c.executor_user_id, cache),
            "onboarded_at": iso(c.executor_onboarded_at),
            "inherit_view": inherit,
        },
        "owner_delegations_by_status": {k: int(v) for k, v in by_status.items()},
        "documents": docs.describe("owner_death_certificate", c),
        "allowed_actions": {"verify": c.verification_status == "pending",
                            "reject": c.verification_status == "pending"},
        "case": case_dict(db, case, cache),
        "case_version": case_version(case),
        "history": admin_history(db, "owner_death", c.id),
    })
    return out


# ── Retention ─────────────────────────────────────────────────────────────────


def _archive_candidates(db: Session, limit: int):
    cutoff = utcnow() - timedelta(days=ARCHIVE_AFTER_DAYS)
    return (
        db.query(Delegation)
        .filter(Delegation.status == "terminated", Delegation.terminated_at <= cutoff,
                Delegation.archived_at.is_(None))
        .order_by(Delegation.terminated_at.asc()).limit(limit).all()
    )


def _held_delegations(db: Session, ids: list[str]) -> set[str]:
    """Uỷ quyền đang bị giữ: legal hold trực tiếp, hoặc có tranh chấp còn mở /
    tranh chấp đang legal hold."""
    if not ids:
        return set()
    held = held_ids(db, "delegation", ids)
    flags = db.query(TenantAuthorityFlag.id, TenantAuthorityFlag.delegation_id, TenantAuthorityFlag.status).filter(
        TenantAuthorityFlag.delegation_id.in_(ids)).all()
    held_disputes = held_ids(db, "dispute", [f[0] for f in flags])
    for fid, did, st in flags:
        if st in ("pending", "escalated") or fid in held_disputes:
            held.add(did)
    return held


def retention_status(db: Session) -> dict:
    from app.services.retention import PdplTierService

    cutoff = utcnow() - timedelta(days=ARCHIVE_AFTER_DAYS)
    D = Delegation
    due = db.query(func.count(D.id)).filter(D.status == "terminated", D.terminated_at <= cutoff,
                                            D.archived_at.is_(None)).scalar() or 0
    archived = db.query(func.count(D.id)).filter(D.status == "archived").scalar() or 0
    holds = db.query(func.count(models.AdminCase.id)).filter(models.AdminCase.legal_hold == True).scalar() or 0  # noqa: E712
    L = models.AdminActionLog
    runs = (
        db.query(L).filter(L.action.in_(("retention.run", "retention.archive_delegations")))
        .order_by(L.id.desc()).limit(10).all()
    )
    cache: dict = {}
    return {
        "change_logs_tier_distribution": PdplTierService(db).get_retention_stats(),
        "delegations": {"terminated_due_for_archive": int(due), "archived": int(archived),
                        "archive_after_days": ARCHIVE_AFTER_DAYS},
        "legal_holds_active": int(holds),
        "recent_runs": [{
            "id": r.id, "action": r.action, "actor": user_brief(db, r.actor_user_id, cache),
            "reason": r.reason, "result": r.after_json, "created_at": iso(r.created_at),
        } for r in runs],
    }


def run_retention(db: Session) -> dict:
    """Chạy chuyển tầng PDPL. LƯU Ý: service gốc tự commit TỪNG tầng (cron
    idempotent), nên nhật ký quản trị ghi SAU khi chạy xong — nếu ghi nhật ký
    hỏng thì phần dữ liệu đã chuyển tầng vẫn giữ (chạy lại an toàn)."""
    from app.services.retention import PdplTierService

    return PdplTierService(db).run_daily_transitions()


def archive_delegations(db: Session, actor_id: int, batch: int = 500) -> dict:
    """Như `ArchiveService.run_archive_batch` nhưng bỏ qua uỷ quyền đang legal
    hold / có tranh chấp mở, và KHÔNG tự commit (run_command commit một lần)."""
    from app.services.retention import ArchiveService

    svc = ArchiveService(db)
    rows = _archive_candidates(db, batch)
    held = _held_delegations(db, [d.id for d in rows])
    stats: dict = {"checked": len(rows), "archived": 0, "skipped": 0, "held": 0, "held_ids": [], "archived_ids": []}
    for d in rows:
        if d.id in held:
            stats["held"] += 1
            if len(stats["held_ids"]) < 50:
                stats["held_ids"].append(d.id)
            continue
        _, action = svc.archive_delegation(d, actor_user_id=actor_id)
        if action == "archived":
            stats["archived"] += 1
            if len(stats["archived_ids"]) < 50:
                stats["archived_ids"].append(d.id)
        else:
            stats["skipped"] += 1
    return stats


# ── Nhật ký truy cập dữ liệu nhạy cảm ─────────────────────────────────────────

ACCESS_KINDS = ("cccd", "bank_account", "contact", "admin")
ACCESS_CAP = 1000
_ADMIN_ACCESS_ACTIONS = ("pii.reveal", "document.open", "document.sign")


def _access_sources(f: dict):
    from sqlalchemy import and_

    C, B, R, L = models.CCCDAccessLog, BankAccountRevealLog, models.ContactRevealLog, models.AdminActionLog
    uid, df, dt = f.get("user_id"), f.get("date_from"), f.get("date_to")

    def rng(col):
        conds = []
        if df is not None:
            conds.append(col >= df)
        if dt is not None:
            conds.append(col <= dt)
        return conds

    def both(conds):
        return and_(*conds) if conds else None

    out = {}
    out["cccd"] = (C, C.accessed_at, both(([C.user_id == uid] if uid is not None else []) + rng(C.accessed_at)))
    out["bank_account"] = (B, B.revealed_at, both(
        ([or_(B.operator_user_id == uid, B.owner_user_id == uid)] if uid is not None else []) + rng(B.revealed_at)))
    out["contact"] = (R, R.created_at, both(([R.revealed_by == uid] if uid is not None else []) + rng(R.created_at)))
    lq = [L.action.in_(_ADMIN_ACCESS_ACTIONS)]
    if uid is not None:
        lq.append(or_(L.actor_user_id == uid, and_(L.entity_type == "user", L.entity_id == str(uid))))
    out["admin"] = (L, L.created_at, both(lq + rng(L.created_at)))
    return out


def _access_row(db: Session, kind: str, r: Any, cache: dict) -> dict:
    if kind == "cccd":
        folder = (r.file_path or "").replace("\\", "/").rstrip("/").rsplit("/", 2)
        return {
            "actor": user_brief(db, r.user_id, cache), "subject": None, "action": f"cccd.{r.action}",
            "target": {"type": "file", "id": folder[-2] if len(folder) >= 2 else "cccd"},
            "detail": None, "ip_hash": hash_ip(r.ip_address), "created_at": iso(r.accessed_at),
        }
    if kind == "bank_account":
        return {
            "actor": user_brief(db, r.operator_user_id, cache), "subject": user_brief(db, r.owner_user_id, cache),
            "action": "bank_account.reveal", "target": {"type": "delegation", "id": r.delegation_id},
            "detail": None, "ip_hash": hash_ip(r.ip_address), "created_at": iso(r.revealed_at),
        }
    if kind == "contact":
        return {
            "actor": user_brief(db, r.revealed_by, cache), "subject": None, "action": "contact.reveal",
            "target": {"type": "lead", "id": str(r.lead_id)}, "detail": {"contractor_id": r.contractor_id},
            "ip_hash": None, "created_at": iso(r.created_at),
        }
    subject = None
    if r.entity_type == "user" and (r.entity_id or "").isdigit():
        subject = user_brief(db, int(r.entity_id), cache)
    return {
        "actor": user_brief(db, r.actor_user_id, cache), "subject": subject, "action": r.action,
        "target": {"type": r.entity_type, "id": r.entity_id},
        "detail": {"reason": r.reason, "permission": r.permission,
                   **({k: v for k, v in (r.after_json or {}).items() if k in ("field", "index", "category", "via")})},
        "ip_hash": r.ip_hash, "created_at": iso(r.created_at),
    }


def access_logs(db: Session, *, kinds: tuple[str, ...], filters: dict, offset: int, limit: int):
    srcs = _access_sources(filters)
    need = min(offset + limit, ACCESS_CAP)
    merged: list = []
    counts: dict[str, int] = {}
    failed: list[str] = []
    truncated = False
    for kind in kinds:
        model, created, cond = srcs[kind]
        try:
            q = db.query(model)
            if cond is not None:
                q = q.filter(cond)
            counts[kind] = q.order_by(None).count()
            rows = q.order_by(created.desc()).limit(need).all()
        except Exception as exc:  # noqa: BLE001 — bảng thiếu ở môi trường cũ
            db.rollback()
            logger.warning("access log source %s failed: %s", kind, exc)
            counts[kind] = -1
            failed.append(kind)
            continue
        if counts[kind] > ACCESS_CAP and offset + limit > ACCESS_CAP:
            truncated = True
        for r in rows:
            merged.append((getattr(r, created.key) or datetime.min, kind, str(r.id), r))
    merged.sort(key=lambda t: (t[0], t[1], t[2]), reverse=True)
    cache: dict = {}
    data = [{"id": f"{k}:{rid}", "kind": k, **_access_row(db, k, r, cache)}
            for _c, k, rid, r in merged[offset: offset + limit]]
    total = sum(v for v in counts.values() if v > 0)
    return data, total, truncated, counts, failed
