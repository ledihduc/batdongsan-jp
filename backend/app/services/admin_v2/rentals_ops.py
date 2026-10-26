"""Read model + tiện ích lệnh cho module Giao dịch thuê của Admin V2.

Chỉ ĐỌC và ĐÓNG GÓI. Mọi chuyển trạng thái đi qua service miền
(`rental_journey_service`, `reservation_service`) — ở đây không có dòng nào gán
`.status`. Lý do: backoffice mà tự ghi trạng thái thì bỏ qua đúng những luật
(chiếm dụng phòng, hoàn tiền, thông báo) mà app dựa vào.

Chứng từ (ảnh hợp đồng, minh chứng cọc, ảnh bàn giao/hư hỏng, CCCD) chỉ trả
ĐƯỜNG DẪN kèm `private: true`, và chỉ ở màn chi tiết. Người không có
`rental_documents.read` nhận `path: null` — biết là có giấy tờ, không biết ở đâu.
Module documents cấp signed URL riêng.
"""

from __future__ import annotations

import json
import logging
from datetime import date, datetime, timedelta
from typing import Any, Callable, Iterable, Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.services import activity_deposit_policy_service, rental_journey_policy as policy
from app.services.admin_v2.core import AdminContext, etag, fail, iso, mask_email, mask_phone, user_brief, utcnow

logger = logging.getLogger(__name__)

STALLED_HOURS = 72
# Khớp hộp việc (`work_items.journey_stalled`): ba trạng thái này không còn việc.
CLOSED_JOURNEY = ("COMPLETED", "CANCELLED", "CUSTOMER_DECLINED")

JOURNEY_STATUS_LABELS = {
    policy.WAITING_VIEWING: "Chờ xem nhà",
    policy.CUSTOMER_INTERESTED: "Khách muốn thuê",
    policy.CUSTOMER_DECLINED: "Khách không thuê",
    policy.CONTRACT_READY: "Đã có hợp đồng, chờ cọc",
    policy.DEPOSITS_PENDING: "Đang nộp cọc",
    policy.CUSTOMER_CONFIRMATION_PENDING: "Đủ cọc, chờ chốt",
    policy.COMPLETED: "Đã chốt thuê",
    policy.CANCELLED: "Đã huỷ",
    policy.DISPUTED: "Đang tranh chấp",
}
DEPOSIT_KIND_LABELS = {"APP_DEPOSIT": "Cọc nền tảng", "OWNER_DEPOSIT": "Cọc chủ nhà"}
DEPOSIT_STATUS_LABELS = {
    "PENDING": "Chưa nộp minh chứng",
    "SUBMITTED": "Đã nộp minh chứng",
    "ACKNOWLEDGED": "Chủ nhà đã xác nhận nhận cọc",
}
REPORT_STATUS_LABELS = {"PENDING": "Chờ xử lý", "VALID": "Báo cáo đúng", "INVALID": "Báo cáo không đúng"}
ACTOR_ROLES = ("customer", "sale", "owner", "admin", "system")

DEPOSIT_VERIFY_ACTION = "deposit.verify"
DEPOSIT_ENTITY = "rental_journey_payment"
JOURNEY_ENTITY = "rental_journey"
REPORT_ENTITY = "rental_journey_report"
RESERVATION_ENTITY = "reservation"

TIMELINE_CAP = 300  # mỗi nguồn — một hồ sơ thật không có chừng này sự kiện


# ── Tiện ích chung ────────────────────────────────────────────────────────────


def vnd(value: Any) -> Optional[int]:
    """Tiền VND số nguyên — cột Float cũ không được rò số lẻ ra DTO."""
    if value is None:
        return None
    try:
        return int(round(float(value)))
    except (TypeError, ValueError):
        return None


def docs(paths: Optional[Iterable[str]], allowed: bool) -> list[dict]:
    return [{"path": p if allowed else None, "private": True} for p in (paths or []) if p]


def ref(prefix: str, row_id: Optional[int]) -> Optional[str]:
    return f"{prefix}-{int(row_id):05d}" if row_id else None


def domain(fn: Callable, *args, **kwargs):
    """Gọi service miền; dịch lỗi chuỗi kiểu cũ sang envelope backoffice.

    Service cũ trả 400 cho "sai bước" — với backoffice đó là xung đột trạng
    thái (409), để FE hiện "tải lại" thay vì "dữ liệu nhập sai".
    """
    try:
        return fn(*args, **kwargs)
    except HTTPException as exc:
        if isinstance(exc.detail, dict) and "code" in exc.detail:
            raise
        status = 409 if exc.status_code == 400 else exc.status_code
        code = {404: "ADMIN_NOT_FOUND", 422: "ADMIN_VALIDATION"}.get(status, "ADMIN_TRANSITION_NOT_ALLOWED")
        raise fail(status, code, str(exc.detail)) from exc


def publish_safely(fn: Callable, *args, **kwargs) -> None:
    """Publish realtime SAU commit; lỗi socket không được biến lệnh đã ghi thành 500."""
    try:
        fn(*args, **kwargs)
    except Exception as exc:  # noqa: BLE001
        logger.warning("admin publish failed: %s", exc)


def parse_day(value: Optional[str], field: str) -> Optional[date]:
    if not value:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise fail(422, "ADMIN_BAD_FILTER", f"Ngày không hợp lệ ({field}), dùng YYYY-MM-DD")


def admin_logs(db: Session, pairs: list[tuple[str, str]], cap: int = TIMELINE_CAP) -> list[models.AdminActionLog]:
    """Nhật ký quản trị của nhiều thực thể (entity_type, entity_id)."""
    from sqlalchemy import and_, or_

    if not pairs:
        return []
    L = models.AdminActionLog
    conds = [and_(L.entity_type == t, L.entity_id == str(i)) for t, i in pairs]
    return (
        db.query(L).filter(or_(*conds), L.result == "success")
        .order_by(L.created_at.asc(), L.id.asc()).limit(cap).all()
    )


# ── Nơi chốn: tin / phòng / toà ───────────────────────────────────────────────


def place(db: Session, house_id: Optional[int], room_id: Optional[int]) -> dict:
    house = db.get(models.House, house_id) if house_id else None
    room = db.get(models.Room, room_id) if room_id else None
    building = db.get(models.Building, room.building_id) if room else None
    if house is not None:
        title = house.title
    elif room is not None:
        title = f"Phòng {room.code}" + (f" · {building.name}" if building else "")
    else:
        title = "Tin/phòng đã gỡ"
    return {
        "title": title,
        "house": None if house is None else {"id": house.id, "title": house.title, "status": house.status},
        "room": None if room is None else {"id": room.id, "code": room.code, "status": room.status},
        "building": None if building is None else {"id": building.id, "name": building.name},
    }


# ── Hành trình thuê dài hạn ───────────────────────────────────────────────────


def payments_of(db: Session, journey_ids: list[int]) -> dict[int, dict[str, models.RentalJourneyPayment]]:
    out: dict[int, dict[str, models.RentalJourneyPayment]] = {}
    if not journey_ids:
        return out
    for p in db.query(models.RentalJourneyPayment).filter(models.RentalJourneyPayment.journey_id.in_(journey_ids)):
        out.setdefault(p.journey_id, {})[p.kind] = p
    return out


def has_proof(p: Optional[models.RentalJourneyPayment]) -> bool:
    # Cùng định nghĩa với rental_journey_service._has_proof.
    return bool(p and p.proof_urls and p.submitted_at)


def is_stalled(j: models.RentalJourney, now: Optional[datetime] = None) -> bool:
    now = now or utcnow()
    return j.status not in CLOSED_JOURNEY and j.updated_at is not None and j.updated_at < now - timedelta(hours=STALLED_HOURS)


def journey_version(j: models.RentalJourney, payments: dict[str, models.RentalJourneyPayment]) -> str:
    return etag(
        j.id, j.status, iso(j.updated_at), j.contract_id,
        sorted((p.kind, p.status, p.amount, iso(p.submitted_at), iso(p.acknowledged_at)) for p in payments.values()),
    )


def open_report_counts(db: Session, journey_ids: list[int]) -> dict[int, int]:
    from sqlalchemy import func

    if not journey_ids:
        return {}
    R = models.RentalJourneyReport
    rows = (
        db.query(R.journey_id, func.count(R.id))
        .filter(R.journey_id.in_(journey_ids), R.status == "PENDING")
        .group_by(R.journey_id).all()
    )
    return {jid: int(n) for jid, n in rows}


def journey_row(db: Session, j: models.RentalJourney, payments: dict, open_reports: int, cache: dict) -> dict:
    p = place(db, j.house_id, j.room_id)
    return {
        "id": j.id,
        "ref": ref("HT", j.id),
        "status": j.status,
        "status_label": JOURNEY_STATUS_LABELS.get(j.status, j.status),
        "stalled": is_stalled(j),
        "has_dispute": j.status == policy.DISPUTED or open_reports > 0,
        "open_reports": open_reports,
        "subject": {"title": p["title"], "house_id": j.house_id, "room_id": j.room_id,
                    "building_name": p["building"]["name"] if p["building"] else None},
        "customer": user_brief(db, j.customer_id, cache),
        "sale": user_brief(db, j.sale_id, cache),
        "owner": user_brief(db, j.owner_id, cache),
        "total_deposit": vnd(j.total_deposit),
        "deposits": {
            kind: {"status": pay.status, "amount": vnd(pay.amount), "has_proof": has_proof(pay),
                   "acknowledged": pay.acknowledged_at is not None}
            for kind, pay in sorted(payments.items())
        },
        "has_contract_documents": bool(j.contract_urls),
        "contract_id": j.contract_id,
        "created_at": iso(j.created_at),
        "updated_at": iso(j.updated_at),
        "version": journey_version(j, payments),
    }


def verifications(db: Session, payment_ids: list[int]) -> dict[int, models.AdminActionLog]:
    """Kết luận xác minh cọc gần nhất của backoffice (record-only) theo khoản cọc."""
    if not payment_ids:
        return {}
    L = models.AdminActionLog
    rows = (
        db.query(L)
        .filter(L.action == DEPOSIT_VERIFY_ACTION, L.entity_type == DEPOSIT_ENTITY,
                L.entity_id.in_([str(i) for i in payment_ids]), L.result == "success")
        .order_by(L.id.asc()).all()
    )
    # Tăng dần theo id → dòng sau ghi đè: giữ lần xác minh MỚI NHẤT.
    return {int(r.entity_id): r for r in rows}


def verification_dto(db: Session, log: Optional[models.AdminActionLog], payment: models.RentalJourneyPayment,
                     cache: dict) -> Optional[dict]:
    if log is None:
        return None
    after = log.after_json or {}
    # Minh chứng nộp lại SAU lần xác minh → kết luận cũ không còn nói về ảnh hiện tại.
    stale = bool(payment.submitted_at and log.created_at and payment.submitted_at > log.created_at)
    return {
        "decision": after.get("decision"),
        "by": user_brief(db, log.actor_user_id, cache),
        "at": iso(log.created_at),
        "reason": log.reason,
        "domain_acknowledged": bool(after.get("domain_acknowledged")),
        "stale": stale,
    }


DEPOSIT_CASE = "deposit_review"  # trùng mã nguồn hộp việc → xác minh xong là rời hộp việc
DEPOSIT_REVIEW_STATE = {"done": "verified", "waiting": "rejected"}


def deposit_cases(db: Session, payment_ids: list[int]) -> dict[int, models.AdminCase]:
    if not payment_ids:
        return {}
    rows = db.query(models.AdminCase).filter(
        models.AdminCase.source_type == DEPOSIT_CASE,
        models.AdminCase.source_id.in_([str(i) for i in payment_ids])).all()
    return {int(c.source_id): c for c in rows}


def deposit_version(p: models.RentalJourneyPayment, case: Optional[models.AdminCase]) -> str:
    # Phiên bản case tăng mỗi lần xác minh → hai người cùng xác minh, người sau bị 409.
    return etag(p.id, p.status, p.amount, iso(p.submitted_at), iso(p.acknowledged_at),
                sorted(p.proof_urls or []), case.version if case else 0)


def deposit_row(db: Session, p: models.RentalJourneyPayment, j: Optional[models.RentalJourney],
                last_verify: Optional[models.AdminActionLog], case: Optional[models.AdminCase],
                cache: dict) -> dict:
    return {
        "id": p.id,
        "ref": ref("COC", p.id),
        "journey_id": p.journey_id,
        "journey_ref": ref("HT", p.journey_id),
        "journey_status": j.status if j else None,
        "journey_status_label": JOURNEY_STATUS_LABELS.get(j.status, j.status) if j else None,
        "kind": p.kind,
        "kind_label": DEPOSIT_KIND_LABELS.get(p.kind, p.kind),
        "amount": vnd(p.amount),
        "status": p.status,
        "status_label": DEPOSIT_STATUS_LABELS.get(p.status, p.status),
        "proof_count": len(p.proof_urls or []),
        "submitted_by": user_brief(db, p.submitted_by, cache),
        "submitted_at": iso(p.submitted_at),
        "acknowledged_by": user_brief(db, p.acknowledged_by, cache),
        "acknowledged_at": iso(p.acknowledged_at),
        "customer": user_brief(db, j.customer_id, cache) if j else None,
        "owner": user_brief(db, j.owner_id, cache) if j else None,
        "admin_verification": verification_dto(db, last_verify, p, cache),
        "verification_state": DEPOSIT_REVIEW_STATE.get(case.status, "unverified") if case else "unverified",
        "updated_at": iso(p.updated_at),
        "version": deposit_version(p, case),
    }


def report_version(r: models.RentalJourneyReport) -> str:
    return etag(r.id, r.status)


def report_dto(db: Session, r: models.RentalJourneyReport, cache: dict, allow_docs: bool) -> dict:
    return {
        "id": r.id,
        "ref": ref("BCG", r.id),
        "journey_id": r.journey_id,
        "reporter": user_brief(db, r.reporter_id, cache),
        "reported": user_brief(db, r.reported_user_id, cache),
        "reason_code": r.reason_code,
        "detail": r.detail,
        "evidence": docs(r.evidence_urls, allow_docs),
        "status": r.status,
        "status_label": REPORT_STATUS_LABELS.get(r.status, r.status),
        "created_at": iso(r.created_at),
        "version": report_version(r),
    }


def missing_documents(j: models.RentalJourney, payments: dict, verify: dict[int, Any]) -> list[dict]:
    app_p = payments.get("APP_DEPOSIT")
    own_p = payments.get("OWNER_DEPOSIT")
    app_v = verify.get(app_p.id) if app_p else None
    app_verified = bool(
        app_v is not None and (app_v.after_json or {}).get("decision") == "verified"
        and not (app_p.submitted_at and app_v.created_at and app_p.submitted_at > app_v.created_at)
    )
    items = [
        ("contract_documents", "Ảnh/tệp hợp đồng", bool(j.contract_urls), True),
        ("app_deposit_proof", "Minh chứng cọc nền tảng", has_proof(app_p), True),
        ("owner_deposit_proof", "Minh chứng cọc chủ nhà", has_proof(own_p), True),
        ("owner_deposit_acknowledged", "Chủ nhà xác nhận đã nhận cọc", bool(own_p and own_p.acknowledged_at), False),
        ("app_deposit_verified", "Tài chính đã xác minh cọc nền tảng", app_verified, False),
        ("signed_contract", "Hợp đồng trong sổ chủ nhà (sau khi chốt)", bool(j.contract_id),
         j.status == policy.COMPLETED),
    ]
    return [{"code": c, "label": lbl, "done": done, "required": req} for c, lbl, done, req in items]


def admin_journey_actions(j: models.RentalJourney, payments: dict) -> list[str]:
    """Lệnh backoffice khả dụng — suy từ CHÍNH policy miền với actor='admin'."""
    own = payments.get("OWNER_DEPOSIT")
    acts = policy.available_actions(
        actor="admin", status=j.status, has_contract=bool(j.contract_urls),
        has_app_proof=has_proof(payments.get("APP_DEPOSIT")), has_owner_proof=has_proof(own),
        owner_proof_acknowledged=bool(own and own.acknowledged_at),
    )
    out = []
    if policy.CANCEL_JOURNEY in acts:
        out.append("cancel")
    return out


def journey_detail(db: Session, ctx: AdminContext, j: models.RentalJourney) -> dict:
    cache: dict = {}
    allow_docs = ctx.has("rental_documents.read")
    payments = payments_of(db, [j.id]).get(j.id, {})
    verify = verifications(db, [p.id for p in payments.values()])
    dcases = deposit_cases(db, [p.id for p in payments.values()])
    reports = (
        db.query(models.RentalJourneyReport).filter(models.RentalJourneyReport.journey_id == j.id)
        .order_by(models.RentalJourneyReport.id.asc()).limit(50).all()
    )
    open_reports = sum(1 for r in reports if r.status == "PENDING")
    appt = db.get(models.ViewingAppointment, j.appointment_id) if j.appointment_id else None
    contract = db.get(models.Contract, j.contract_id) if j.contract_id else None
    platform_bps, owner_bps, provenance = activity_deposit_policy_service.long_term_split_bps(j)
    row = journey_row(db, j, payments, open_reports, cache)
    return {
        **row,
        "place": place(db, j.house_id, j.room_id),
        "parties": {
            "customer": row["customer"], "sale": row["sale"], "owner": row["owner"],
        },
        "appointment": None if appt is None else {
            "id": appt.id,
            "ref": ref("LX", appt.id),
            "loai": appt.loai,
            "booking_date": appt.booking_date,
            "booking_time": appt.booking_time,
            "status": appt.status,
            "canonical_status": appt.canonical_status,
            "hinh_thuc": appt.hinh_thuc,
            "created_at": iso(appt.created_at),
        },
        "contract_documents": {
            "files": docs(j.contract_urls, allow_docs),
            "note": j.contract_note,
            "submitted_by": user_brief(db, j.contract_submitted_by, cache),
            "submitted_at": iso(j.contract_submitted_at),
        },
        "contract": None if contract is None else {
            "id": contract.id,
            "ref": ref("HD", contract.id),
            "status": contract.status,
            "room_id": contract.room_id,
            "start_date": contract.start_date,
            "end_date": contract.end_date,
            "monthly_rent": vnd(contract.monthly_rent),
            "deposit": vnd(contract.deposit),
        },
        "deposit_policy": {
            "policy_version": j.deposit_policy_version,
            "platform_bps": platform_bps,
            "owner_bps": owner_bps,
            "provenance": provenance,
        },
        "deposits": [
            {**deposit_row(db, p, j, verify.get(p.id), dcases.get(p.id), cache),
             "proofs": docs(p.proof_urls, allow_docs)}
            for _, p in sorted(payments.items())
        ],
        "missing_documents": missing_documents(j, payments, verify),
        "reports": [report_dto(db, r, cache, allow_docs) for r in reports],
        "cancel_reason": j.cancel_reason,
        "cancelled_at": iso(j.cancelled_at),
        "completed_at": iso(j.completed_at),
        "available_admin_actions": admin_journey_actions(j, payments),
        "documents_redacted": not allow_docs,
    }


_EVENT_LABELS = {
    "VIEWING_RESULT_RECORDED": "Khách ghi kết quả sau xem",
    "CONTRACT_SUBMITTED": "Gửi hợp đồng",
    "PAYMENT_PROOF_SUBMITTED": "Nộp minh chứng cọc",
    "OWNER_DEPOSIT_ACKNOWLEDGED": "Xác nhận đã nhận cọc chủ nhà",
    "RENTAL_CONFIRMED_BY_OWNER": "Chủ nhà chốt thuê",
    "RENTAL_CONFIRMED_BY_CUSTOMER": "Khách chốt thuê",
    "JOURNEY_CANCELLED": "Huỷ hồ sơ",
    "PARTICIPANT_REPORTED": "Báo cáo người tham gia",
    "REPORT_DECIDED": "Kết luận báo cáo",
    "RENT_INTENT_RECORDED": "Khách báo muốn thuê",
    # Sự kiện lịch xem (viewing_events)
    "VIEWING_PROPOSAL_SENT": "Đề xuất giờ xem khác",
    "VIEWING_PROPOSAL_ACCEPTED": "Khách nhận giờ đề xuất",
    "VIEWING_CONFIRMED": "Xác nhận lịch xem",
    "VIEWING_CANCELLED": "Huỷ lịch xem",
    "VIEWING_ISSUE_REPORTED": "Báo sự cố buổi xem",
    "VIEWING_RENT_NOW": "Khách chọn thuê ngay",
}


def _role(raw: Optional[str]) -> str:
    return raw if raw in ACTOR_ROLES else "system"


def journey_timeline(db: Session, j: models.RentalJourney) -> tuple[list[dict], bool]:
    """Gộp sự kiện hồ sơ, khoản cọc, nhật ký quản trị, sự kiện lịch xem — theo thời gian.

    Trả (mục, truncated). Thứ tự ổn định: (thời điểm, thứ tự nguồn, id).
    """
    cache: dict = {}
    entries: list[tuple] = []
    truncated = False
    party_role = {j.customer_id: "customer", j.sale_id: "sale", j.owner_id: "owner"}

    ev = (
        db.query(models.RentalJourneyEvent).filter(models.RentalJourneyEvent.journey_id == j.id)
        .order_by(models.RentalJourneyEvent.created_at.asc(), models.RentalJourneyEvent.id.asc())
        .limit(TIMELINE_CAP + 1).all()
    )
    truncated |= len(ev) > TIMELINE_CAP
    seen_types: set[tuple[str, Optional[str]]] = set()
    for e in ev[:TIMELINE_CAP]:
        kind = (e.payload or {}).get("kind") if isinstance(e.payload, dict) else None
        seen_types.add((e.event_type, kind))
        entries.append((e.created_at, 1, e.id, {
            "source": "journey_event", "type": e.event_type,
            "label": _EVENT_LABELS.get(e.event_type, e.event_type),
            "actor": user_brief(db, e.actor_id, cache), "actor_role": _role(e.actor_role),
            "from_status": e.from_status, "to_status": e.to_status, "payload": e.payload or {},
        }))

    # Khoản cọc: chỉ bù mốc khi KHÔNG có sự kiện tương ứng (dữ liệu trước khi có event).
    for kind, p in sorted(payments_of(db, [j.id]).get(j.id, {}).items()):
        if p.submitted_at and ("PAYMENT_PROOF_SUBMITTED", kind) not in seen_types:
            entries.append((p.submitted_at, 2, p.id, {
                "source": "deposit", "type": "DEPOSIT_SUBMITTED",
                "label": f"Nộp minh chứng {DEPOSIT_KIND_LABELS.get(kind, kind).lower()}",
                "actor": user_brief(db, p.submitted_by, cache),
                "actor_role": party_role.get(p.submitted_by, "system"),
                "from_status": None, "to_status": None,
                "payload": {"kind": kind, "amount": vnd(p.amount), "deposit_id": p.id},
            }))
        if p.acknowledged_at and ("OWNER_DEPOSIT_ACKNOWLEDGED", kind) not in seen_types:
            entries.append((p.acknowledged_at, 2, p.id, {
                "source": "deposit", "type": "DEPOSIT_ACKNOWLEDGED",
                "label": "Xác nhận đã nhận cọc chủ nhà",
                "actor": user_brief(db, p.acknowledged_by, cache),
                "actor_role": party_role.get(p.acknowledged_by, "admin"),
                "from_status": None, "to_status": None,
                "payload": {"kind": kind, "deposit_id": p.id},
            }))
        pay_ids = [p.id]
        for log in admin_logs(db, [(DEPOSIT_ENTITY, str(i)) for i in pay_ids]):
            entries.append(_admin_entry(db, log, cache, order=3))

    report_ids = [r[0] for r in db.query(models.RentalJourneyReport.id).filter(
        models.RentalJourneyReport.journey_id == j.id).limit(50)]
    logs = admin_logs(db, [(JOURNEY_ENTITY, str(j.id))] + [(REPORT_ENTITY, str(i)) for i in report_ids])
    truncated |= len(logs) >= TIMELINE_CAP
    for log in logs:
        entries.append(_admin_entry(db, log, cache, order=3))

    if j.appointment_id:
        appt = db.get(models.ViewingAppointment, j.appointment_id)
        if appt is not None and appt.created_at:
            entries.append((appt.created_at, 0, appt.id, {
                "source": "viewing", "type": "VIEWING_BOOKED", "label": "Khách đặt lịch xem",
                "actor": user_brief(db, appt.guest_id, cache), "actor_role": "customer",
                "from_status": None, "to_status": None,
                "payload": {"appointment_id": appt.id, "booking_date": appt.booking_date,
                            "booking_time": appt.booking_time},
            }))
        vev = (
            db.query(models.ViewingEvent).filter(models.ViewingEvent.appointment_id == j.appointment_id)
            .order_by(models.ViewingEvent.created_at.asc(), models.ViewingEvent.id.asc())
            .limit(TIMELINE_CAP + 1).all()
        )
        truncated |= len(vev) > TIMELINE_CAP
        for e in vev[:TIMELINE_CAP]:
            entries.append((e.created_at, 0, e.id, {
                "source": "viewing", "type": e.event_type, "label": _EVENT_LABELS.get(e.event_type, e.event_type),
                "actor": user_brief(db, e.actor_user_id, cache), "actor_role": _role(e.actor_role),
                "from_status": e.from_status, "to_status": e.to_status, "payload": e.payload or {},
            }))

    return _sorted(entries), truncated


def _admin_entry(db: Session, log: models.AdminActionLog, cache: dict, *, order: int) -> tuple:
    return (log.created_at, order, log.id, {
        "source": "admin", "type": log.action, "label": ADMIN_ACTION_LABELS.get(log.action, log.action),
        "actor": user_brief(db, log.actor_user_id, cache), "actor_role": "admin",
        "from_status": (log.before_json or {}).get("status") if isinstance(log.before_json, dict) else None,
        "to_status": (log.after_json or {}).get("status") if isinstance(log.after_json, dict) else None,
        "payload": {"reason": log.reason, "entity_type": log.entity_type, "entity_id": log.entity_id,
                    "after": log.after_json},
    })


ADMIN_ACTION_LABELS = {
    "rental_journey.cancel": "Quản trị huỷ hồ sơ",
    "rental_journey_report.decide": "Quản trị kết luận báo cáo",
    DEPOSIT_VERIFY_ACTION: "Tài chính xác minh cọc",
    "reservation.approve": "Quản trị duyệt đơn",
    "reservation.reject": "Quản trị từ chối đơn",
    "reservation.cancel": "Quản trị huỷ đơn",
}


def _sorted(entries: list[tuple]) -> list[dict]:
    entries.sort(key=lambda e: (e[0] or datetime.min, e[1], e[2]))
    out = []
    for at, _o, _i, body in entries:
        out.append({"at": iso(at), **body})
    return out


# ── Lịch xem ──────────────────────────────────────────────────────────────────


def viewing_row(db: Session, v: models.ViewingAppointment, journey_id: Optional[int], cache: dict) -> dict:
    from app.services import lich_xem_service

    try:
        anchor = lich_xem_service.neo_cua(db, v)
        host_id, sale_id = anchor.chu_nha_id, anchor.sale_id
        if host_id is None and anchor.house is not None:
            host_id = anchor.house.host_id
    except Exception as exc:  # noqa: BLE001 — một lịch neo hỏng không làm hỏng cả trang
        logger.warning("viewing anchor failed #%s: %s", v.id, exc)
        host_id = sale_id = None
    p = place(db, v.house_id, v.room_id)
    return {
        "id": v.id,
        "ref": ref("LX", v.id),
        "loai": v.loai,
        "status": v.status,
        "canonical_status": v.canonical_status,
        "slot": {"date": v.booking_date, "time": v.booking_time},
        "house": p["house"],
        "room": p["room"],
        "building": p["building"],
        "title": p["title"],
        "guest": user_brief(db, v.guest_id, cache),
        "attendee": {"name": v.ten_khach, "phone_masked": mask_phone(v.sdt_khach), "count": v.so_nguoi},
        "host": user_brief(db, host_id, cache),
        "sale": user_brief(db, sale_id, cache),
        "hinh_thuc": v.hinh_thuc,
        "journey_id": journey_id,
        "cancel_reason_code": v.cancel_reason_code,
        "created_at": iso(v.created_at),
        "confirmed_at": iso(v.confirmed_at),
        "completed_at": iso(v.completed_at),
        "cancelled_at": iso(v.cancelled_at),
    }


# ── Đặt phòng ngắn hạn ────────────────────────────────────────────────────────

RESERVATION_ACTIVE = ("pending", "approved", "checked_in")


def reservation_version(r: models.Reservation) -> str:
    return etag(r.id, r.status, iso(r.updated_at), r.refund_amount)


def reservation_label(status: str) -> str:
    from app.services.short_stay_service import STATUSES

    return STATUSES.get(status, status)


def reservation_row(db: Session, r: models.Reservation, cache: dict) -> dict:
    p = place(db, r.house_id, r.room_id)
    return {
        "id": r.id,
        "ref": ref("BK", r.id),
        "booking_code": r.booking_code,
        "status": r.status,
        "status_label": reservation_label(r.status),
        "room": p["room"],
        "building": p["building"],
        "house": p["house"],
        "host": user_brief(db, r.host_id, cache),
        "sale": user_brief(db, r.sale_id, cache),
        "guest": {
            "user": user_brief(db, r.guest_user_id, cache),
            "name": r.guest_name,
            "phone_masked": mask_phone(r.guest_phone),
            "email_masked": mask_email(r.guest_email),
            "count": r.so_khach,
        },
        "booking_mode": r.booking_mode,
        "check_in_date": r.check_in_date,
        "check_out_date": r.check_out_date,
        "check_in_at": iso(r.check_in_at),
        "check_out_at": iso(r.check_out_at),
        "nights": r.nights,
        "total_amount": vnd(r.total_amount),
        "deposit_paid": vnd(r.deposit_paid),
        "source": r.source,
        "created_at": iso(r.created_at),
        "updated_at": iso(r.updated_at),
        "version": reservation_version(r),
    }


def reservation_admin_actions(r: models.Reservation) -> list[str]:
    acts = []
    if r.status == "pending":
        acts += ["approve", "reject"]
    # Ngắn hạn kiểu mới: khách đang ở thì phải trả phòng, service không cho huỷ.
    if r.status in ("pending", "approved") or (r.status == "checked_in" and not r.booking_mode):
        acts.append("cancel")
    return acts


def reservation_conflicts(db: Session, r: models.Reservation) -> list[dict]:
    """Khoảng bận khác trên cùng phòng chồng lên đơn này (lịch chung + đơn khác)."""
    from sqlalchemy import and_, or_

    try:
        tu, den = date.fromisoformat(r.check_in_date), date.fromisoformat(r.check_out_date)
    except (TypeError, ValueError):
        return []
    C = models.RoomChiemDung
    out = []
    blocks = (
        db.query(C).filter(
            C.room_id == r.room_id, C.tu_ngay < den, C.den_ngay > tu,
            or_(C.nguon != C.RESERVATION, C.nguon_id.is_(None), C.nguon_id != r.id),
        ).order_by(C.tu_ngay).limit(50).all()
    )
    for b in blocks:
        out.append({"type": "occupancy", "id": b.id, "kenh": b.kenh, "nguon": b.nguon, "nguon_id": b.nguon_id,
                    "from": b.tu_ngay.isoformat(), "to": b.den_ngay.isoformat(), "note": b.ghi_chu})
    R = models.Reservation
    others = (
        db.query(R).filter(
            R.room_id == r.room_id, R.id != r.id, R.status.in_(RESERVATION_ACTIVE),
            and_(R.check_in_date < r.check_out_date, R.check_out_date > r.check_in_date),
        ).order_by(R.check_in_date).limit(50).all()
    )
    for o in others:
        out.append({"type": "reservation", "id": o.id, "ref": ref("BK", o.id), "status": o.status,
                    "from": o.check_in_date, "to": o.check_out_date})
    return out


def reservation_timeline(db: Session, r: models.Reservation) -> list[dict]:
    cache: dict = {}
    entries: list[tuple] = []
    role_of = {r.host_id: "owner", r.sale_id: "sale", r.guest_user_id: "customer"}
    if r.created_at:
        entries.append((r.created_at, 0, r.id, {
            "source": "reservation", "type": "CREATED", "label": "Tạo đơn",
            "actor": None, "actor_role": "customer" if r.guest_user_id else "owner",
            "from_status": None, "to_status": "pending", "payload": {"source": r.source},
        }))
    CL = models.ChangeLog
    for c in (db.query(CL).filter(CL.entity_type == "reservation", CL.entity_id == r.id)
              .order_by(CL.created_at.asc(), CL.id.asc()).limit(TIMELINE_CAP)):
        after = _json(c.after_json)
        entries.append((c.created_at, 1, c.id, {
            "source": "change_log", "type": c.action, "label": c.action,
            "actor": user_brief(db, c.actor_id, cache), "actor_role": role_of.get(c.actor_id, "admin"),
            "from_status": (_json(c.before_json) or {}).get("status"), "to_status": (after or {}).get("status"),
            "payload": after or {},
        }))
    req_ids = [x[0] for x in db.query(models.RoomTypeBookingRequest.id).filter(
        models.RoomTypeBookingRequest.reservation_id == r.id).limit(10)]
    if req_ids:
        W = models.ShortStayWorkflowEvent
        for e in (db.query(W).filter(W.request_id.in_(req_ids))
                  .order_by(W.created_at.asc(), W.id.asc()).limit(TIMELINE_CAP)):
            entries.append((e.created_at, 1, e.id, {
                "source": "short_stay_workflow", "type": e.event_type, "label": e.event_type,
                "actor": user_brief(db, e.actor_user_id, cache), "actor_role": _role(e.actor_role),
                "from_status": e.from_status, "to_status": e.to_status, "payload": e.payload or {},
            }))
    for log in admin_logs(db, [(RESERVATION_ENTITY, str(r.id))]):
        entries.append(_admin_entry(db, log, cache, order=2))
    return _sorted(entries)


def _json(raw: Any) -> Optional[dict]:
    if raw is None or isinstance(raw, dict):
        return raw
    try:
        val = json.loads(raw)
        return val if isinstance(val, dict) else None
    except (TypeError, ValueError):
        return None


def reservation_detail(db: Session, ctx: AdminContext, r: models.Reservation) -> dict:
    from app.services import ca_thue_service

    cache: dict = {}
    phu_thu = ca_thue_service._phu_thu(db, r.id)
    thanh_toan = ca_thue_service._thanh_toan(db, r.id)
    # Công thức "đã thu" sống ở MỘT chỗ (ca_thue_service._tien) — không tự cộng lại.
    tien = ca_thue_service._tien(r, phu_thu, thanh_toan)
    return {
        **reservation_row(db, r, cache),
        "money": {k: vnd(v) for k, v in tien.items()},
        "deposit_requirement": {
            "policy_version": r.activity_deposit_policy_version,
            "bps": r.activity_primary_deposit_bps,
            "amount": vnd(r.activity_primary_deposit_amount),
        },
        "refund_amount": vnd(r.refund_amount),
        "commission": {"rate": r.commission_rate, "amount": vnd(r.commission_amount)},
        "price_breakdown": _json(r.price_snapshot) or {},
        "cancel_policy": _json(r.cancel_policy_snapshot) or {},
        "rejection_reason": r.rejection_reason,
        "cancelled_at": iso(r.cancelled_at),
        "note": r.note,
        "checkout_inspection_note": r.ghi_chu_kiem_phong,
        "surcharges": [
            {"id": x.id, "loai": x.loai, "ten": x.ten, "don_gia": vnd(x.don_gia), "so_luong": x.so_luong,
             "thanh_tien": vnd(x.thanh_tien), "ghi_chu": x.ghi_chu, "by": user_brief(db, x.nguoi_ghi, cache),
             "created_at": iso(x.created_at)} for x in phu_thu
        ],
        "payments": [
            {"id": x.id, "loai": x.loai, "so_tien": vnd(x.so_tien), "hinh_thuc": x.hinh_thuc, "ghi_chu": x.ghi_chu,
             "by": user_brief(db, x.nguoi_ghi, cache), "created_at": iso(x.created_at)} for x in thanh_toan
        ],
        "conflicts": reservation_conflicts(db, r),
        "timeline": reservation_timeline(db, r),
        "available_admin_actions": reservation_admin_actions(r),
    }


# ── Hợp đồng ──────────────────────────────────────────────────────────────────


def contract_version(c: models.Contract) -> str:
    return etag(c.id, c.status, iso(c.updated_at))


def _primary_tenants(db: Session, contract_ids: list[int]) -> dict[int, models.Tenant]:
    if not contract_ids:
        return {}
    CT, T = models.ContractTenant, models.Tenant
    rows = (
        db.query(CT.contract_id, T).join(T, T.id == CT.tenant_id)
        .filter(CT.contract_id.in_(contract_ids)).order_by(CT.is_primary.desc()).all()
    )
    out: dict[int, models.Tenant] = {}
    for cid, t in rows:
        out.setdefault(cid, t)
    return out


def contract_row(db: Session, c: models.Contract, tenant: Optional[models.Tenant], cache: dict,
                 today: Optional[date] = None) -> dict:
    today = today or date.today()
    p = place(db, None, c.room_id)
    try:
        days_to_end = (date.fromisoformat(c.end_date) - today).days if c.end_date else None
    except ValueError:
        days_to_end = None
    return {
        "id": c.id,
        "ref": ref("HD", c.id),
        "status": c.status,
        "host": user_brief(db, c.host_id, cache),
        "room": p["room"],
        "building": p["building"],
        "start_date": c.start_date,
        "end_date": c.end_date,
        "days_to_end": days_to_end,
        "monthly_rent": vnd(c.monthly_rent),
        "deposit": vnd(c.deposit),
        "deposit_collected": vnd(c.coc_da_thu),
        "off_platform": bool(c.ngoai_luong),
        "source": c.source,
        "primary_tenant": None if tenant is None else {
            "name": tenant.full_name, "phone_masked": mask_phone(tenant.phone),
        },
        "created_at": iso(c.created_at),
        "updated_at": iso(c.updated_at),
        "version": contract_version(c),
    }


def contract_detail(db: Session, ctx: AdminContext, c: models.Contract) -> dict:
    cache: dict = {}
    allow_docs = ctx.has("rental_documents.read")
    CT, T = models.ContractTenant, models.Tenant
    links = (
        db.query(CT, T).join(T, T.id == CT.tenant_id).filter(CT.contract_id == c.id)
        .order_by(CT.is_primary.desc(), T.id.asc()).limit(20).all()
    )
    fees = (
        db.query(models.ContractServiceFee, models.ServiceFee)
        .join(models.ServiceFee, models.ServiceFee.id == models.ContractServiceFee.service_fee_id)
        .filter(models.ContractServiceFee.contract_id == c.id).limit(50).all()
    )
    I = models.Invoice
    inv_q = db.query(I).filter(I.contract_id == c.id)
    invoices = inv_q.order_by(I.period_start.desc(), I.id.desc()).limit(24).all()
    today = date.today().isoformat()
    journey = db.query(models.RentalJourney.id).filter(models.RentalJourney.contract_id == c.id).first()
    primary = links[0][1] if links else None
    return {
        **contract_row(db, c, primary, cache),
        "tenants": [
            {
                "id": t.id, "name": t.full_name, "phone_masked": mask_phone(t.phone), "email_masked": mask_email(t.email),
                "cccd_last3_masked": ("*********" + t.cccd_duoi) if t.cccd_duoi else None,
                "is_primary": bool(link.is_primary), "joined_at": link.joined_at, "left_at": link.left_at,
                "is_placeholder": bool(t.is_placeholder),
                "id_images": docs([t.cccd_front_path, t.cccd_back_path], allow_docs),
            }
            for link, t in links
        ],
        "fees": [
            {"service_fee_id": f.id, "name": f.name, "monthly_amount": vnd(cf.monthly_amount),
             "billing_cycle": f.billing_cycle, "cach_tinh": f.cach_tinh or "don_gia"}
            for cf, f in fees
        ],
        "invoices": [invoice_brief(i, today) for i in invoices],
        "invoices_total": inv_q.order_by(None).count(),
        "deposit_info": {
            "deposit": vnd(c.deposit), "collected": vnd(c.coc_da_thu), "refund_amount": vnd(c.deposit_refund_amount),
        },
        "payment_terms": {"day_of_month": c.ngay_thanh_toan, "method": c.hinh_thuc_thanh_toan},
        "occupants": c.so_nguoi_o,
        "note": c.ghi_chu,
        "terminated_at": c.terminated_at,
        "actual_end_date": c.actual_end_date,
        "damage_note": c.damage_note,
        "handover_photos": docs(c.handover_photos, allow_docs),
        "damage_photos": docs(c.damage_photos, allow_docs),
        "journey_id": journey[0] if journey else None,
        "documents_redacted": not allow_docs,
    }


INVOICE_OPEN_EXCLUDED = ("paid", "void", "cancelled", "draft")


def invoice_overdue(i: models.Invoice, today_iso: str) -> bool:
    # Cùng định nghĩa với dashboard (overview._finance): chưa đóng và quá hạn.
    return i.status not in INVOICE_OPEN_EXCLUDED and bool(i.due_date) and i.due_date < today_iso


def invoice_brief(i: models.Invoice, today_iso: str) -> dict:
    total, paid = vnd(i.total_amount) or 0, vnd(i.paid_amount) or 0
    overdue = invoice_overdue(i, today_iso)
    days = None
    if overdue:
        try:
            days = (date.fromisoformat(today_iso) - date.fromisoformat(i.due_date)).days
        except ValueError:
            days = None
    return {
        "id": i.id, "invoice_number": i.invoice_number, "status": i.status,
        "period_start": i.period_start, "period_end": i.period_end, "issued_date": i.issued_date,
        "due_date": i.due_date, "total_amount": total, "paid_amount": paid,
        "outstanding": max(0, total - paid), "overdue": overdue, "days_overdue": days,
        "paid_at": iso(i.paid_at),
    }
