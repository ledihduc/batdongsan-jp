"""Admin V2 — Giao dịch thuê: lịch xem, yêu cầu của sale, hành trình thuê dài
hạn, đặt phòng ngắn hạn, lịch chiếm dụng, hợp đồng.

Router MỎNG: đọc qua `rentals_ops`, lệnh đi qua service miền (không gán
`.status` ở đây) và qua `run_command` (quyền + Idempotency-Key + If-Match + lý
do + nhật ký cùng transaction). Realtime chỉ publish SAU commit.
"""

from __future__ import annotations

from datetime import date, timedelta
from typing import Literal, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app import models
from app.database import get_db
from app.services import rental_journey_policy as policy
from app.services import rental_journey_service as rjs
from app.services import reservation_service
from app.services.admin_v2 import rentals_ops as ro
from app.services.admin_v2.core import (
    AdminContext, CommandResult, PageParams, fail, idempotency_key, if_match, iso, one, page_params, paged,
    paginate, require_permission, run_command, utcnow,
)
from app.status_realtime import publish_status_change

router = APIRouter(prefix="/api/v2/admin", tags=["admin-v2-rentals"])

READ = "rental_journeys.read"
OVERRIDE = "rental_journeys.override"


class OverrideBody(BaseModel):
    #: Lý do NỘI BỘ (nhật ký quản trị) — bắt buộc.
    reason: str = Field("", max_length=500)
    #: Câu hiển thị cho các bên (khách/sale/chủ nhà). Bỏ trống → câu mặc định,
    #: để lý do nội bộ ("nghi gian lận") không lộ ra app.
    public_reason: str = Field("", max_length=300)


class ReportDecisionBody(BaseModel):
    decision: Literal["valid", "invalid"]
    reason: str = Field("", max_length=500)


def _id_term(term: str, prefix: str) -> Optional[int]:
    t = term.strip().upper()
    if t.startswith(prefix + "-"):
        t = t[len(prefix) + 1:]
    return int(t) if t.isdigit() else None


def _users_named(db: Session, term: str):
    return db.query(models.User.id).filter(func.lower(models.User.name).like(f"%{term.lower()}%"))


# ── Lịch xem ──────────────────────────────────────────────────────────────────


@router.get("/rentals/viewings")
def list_viewings(
    status: str = Query("", max_length=20),
    canonical_status: str = Query("", max_length=32),
    loai: str = Query("", pattern="^(|xem|chot)$"),
    date_from: Optional[str] = Query(None, max_length=10),
    date_to: Optional[str] = Query(None, max_length=10),
    house_id: Optional[int] = None,
    room_id: Optional[int] = None,
    guest_id: Optional[int] = None,
    q: str = Query("", max_length=100),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    V = models.ViewingAppointment
    query = db.query(V)
    if status:
        query = query.filter(V.status == status)
    if canonical_status:
        query = query.filter(V.canonical_status == canonical_status)
    if loai:
        query = query.filter(V.loai == loai)
    d1, d2 = ro.parse_day(date_from, "date_from"), ro.parse_day(date_to, "date_to")
    if d1:
        query = query.filter(V.booking_date >= d1.isoformat())
    if d2:
        query = query.filter(V.booking_date <= d2.isoformat())
    if house_id:
        query = query.filter(V.house_id == house_id)
    if room_id:
        query = query.filter(V.room_id == room_id)
    if guest_id:
        query = query.filter(V.guest_id == guest_id)
    term = q.strip()
    if term:
        vid = _id_term(term, "LX")
        like = f"%{term.lower()}%"
        conds = [
            V.guest_id.in_(_users_named(db, term)),
            func.lower(V.ten_khach).like(like),
            V.house_id.in_(db.query(models.House.id).filter(func.lower(models.House.title).like(like))),
        ]
        if vid is not None:
            conds.append(V.id == vid)
        query = query.filter(or_(*conds))
    rows, total = paginate(query.order_by(V.id.desc()), page)
    ids = [v.id for v in rows]
    journeys = dict(
        db.query(models.RentalJourney.appointment_id, models.RentalJourney.id)
        .filter(models.RentalJourney.appointment_id.in_(ids)).all()
    ) if ids else {}
    cache: dict = {}
    return paged([ro.viewing_row(db, v, journeys.get(v.id), cache) for v in rows], total=total, page=page)


# ── Hành trình thuê dài hạn ───────────────────────────────────────────────────


def _journey(db: Session, journey_id: int) -> models.RentalJourney:
    j = db.get(models.RentalJourney, journey_id)
    if j is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy hành trình thuê")
    return j


@router.get("/rentals/journeys")
def list_journeys(
    status: str = Query("", max_length=40),
    sale_id: Optional[int] = None,
    owner_id: Optional[int] = None,
    customer_id: Optional[int] = None,
    has_dispute: Optional[bool] = None,
    q: str = Query("", max_length=100),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    J, R = models.RentalJourney, models.RentalJourneyReport
    query = db.query(J)
    if status == "stalled":
        query = query.filter(J.status.notin_(ro.CLOSED_JOURNEY),
                             J.updated_at < utcnow() - timedelta(hours=ro.STALLED_HOURS))
    elif status == "open":
        query = query.filter(J.status.notin_(ro.CLOSED_JOURNEY))
    elif status:
        if status not in policy.ALL_STATUSES:
            raise fail(422, "ADMIN_BAD_FILTER", "Trạng thái không hợp lệ")
        query = query.filter(J.status == status)
    if sale_id:
        query = query.filter(J.sale_id == sale_id)
    if owner_id:
        query = query.filter(J.owner_id == owner_id)
    if customer_id:
        query = query.filter(J.customer_id == customer_id)
    disputed = or_(J.status == policy.DISPUTED, J.id.in_(db.query(R.journey_id).filter(R.status == "PENDING")))
    if has_dispute is True:
        query = query.filter(disputed)
    elif has_dispute is False:
        query = query.filter(~disputed)
    term = q.strip()
    if term:
        like = f"%{term.lower()}%"
        conds = [
            J.house_id.in_(db.query(models.House.id).filter(func.lower(models.House.title).like(like))),
            J.room_id.in_(db.query(models.Room.id).filter(func.lower(models.Room.code).like(like))),
        ]
        jid = _id_term(term, "HT")
        if jid is not None:
            conds.append(J.id == jid)
        query = query.filter(or_(*conds))
    rows, total = paginate(query.order_by(J.updated_at.desc(), J.id.desc()), page)
    ids = [j.id for j in rows]
    pays = ro.payments_of(db, ids)
    reports = ro.open_report_counts(db, ids)
    cache: dict = {}
    return paged(
        [ro.journey_row(db, j, pays.get(j.id, {}), reports.get(j.id, 0), cache) for j in rows],
        total=total, page=page,
    )


@router.get("/rentals/journeys/{journey_id}")
def get_journey(
    journey_id: int,
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    return one(ro.journey_detail(db, ctx, _journey(db, journey_id)))


@router.get("/rentals/journeys/{journey_id}/timeline")
def journey_timeline(
    journey_id: int,
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    items, truncated = ro.journey_timeline(db, _journey(db, journey_id))
    return one(items, count=len(items), truncated=truncated)


@router.post("/rentals/journeys/{journey_id}/cancel")
def cancel_journey(
    journey_id: int,
    body: OverrideBody,
    ctx: AdminContext = Depends(require_permission(OVERRIDE)),
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    db: Session = Depends(get_db),
):
    j = _journey(db, journey_id)
    state: dict = {}

    def do() -> CommandResult:
        public = body.public_reason.strip() or "Bộ phận vận hành ancu365 đã huỷ hồ sơ"
        journey, old = ro.domain(rjs.cancel_staged, db, ctx.legacy_claims(), journey_id=journey_id, reason=public)
        db.flush()
        state["from"] = old
        return CommandResult(
            data=ro.journey_detail(db, ctx, journey),
            before={"status": old}, after={"status": journey.status, "public_reason": public},
            event_status=journey.status,
        )

    out = run_command(
        db, ctx, action="rental_journey.cancel", permission=OVERRIDE, entity_type=ro.JOURNEY_ENTITY,
        entity_id=journey_id, key=key, fn=do, reason=body.reason, reason_required=True,
        expected_version=expected,
        current_version=lambda: ro.journey_version(j, ro.payments_of(db, [j.id]).get(j.id, {})),
        event_type="admin.rental_journey.updated",
    )
    if "from" in state:
        ro.publish_safely(rjs.publish_journey_status, j, from_status=state["from"], actor_id=ctx.user_id,
                          action="JOURNEY_CANCELLED")
    return out


@router.post("/rentals/journey-reports/{report_id}/decisions")
def decide_journey_report(
    report_id: int,
    body: ReportDecisionBody,
    ctx: AdminContext = Depends(require_permission(OVERRIDE)),
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    db: Session = Depends(get_db),
):
    r = db.get(models.RentalJourneyReport, report_id)
    if r is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy báo cáo")

    def do() -> CommandResult:
        before = r.status
        row = ro.domain(rjs.decide_report_staged, db, report_id=report_id, decision=body.decision,
                        actor_id=ctx.user_id)
        db.flush()
        j = db.get(models.RentalJourney, row.journey_id)
        return CommandResult(
            data={
                **ro.report_dto(db, row, {}, ctx.has("rental_documents.read")),
                "journey": None if j is None else {
                    "id": j.id, "ref": ro.ref("HT", j.id), "status": j.status,
                    "status_label": ro.JOURNEY_STATUS_LABELS.get(j.status, j.status),
                },
            },
            before={"status": before}, after={"status": row.status, "decision": body.decision},
            event_status=row.status,
        )

    return run_command(
        db, ctx, action="rental_journey_report.decide", permission=OVERRIDE, entity_type=ro.REPORT_ENTITY,
        entity_id=report_id, key=key, fn=do, reason=body.reason, reason_required=True,
        expected_version=expected, current_version=lambda: ro.report_version(r),
        event_type="admin.rental_journey.updated",
    )


# ── Đặt phòng ngắn hạn ────────────────────────────────────────────────────────

RESERVATION_STATUSES = ("pending", "approved", "checked_in", "checked_out", "cancelled", "no_show", "rejected")


def _reservation(db: Session, reservation_id: int) -> models.Reservation:
    r = db.get(models.Reservation, reservation_id)
    if r is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy đơn đặt phòng")
    return r


@router.get("/rentals/reservations")
def list_reservations(
    status: str = Query("", max_length=20),
    date_from: Optional[str] = Query(None, max_length=10),
    date_to: Optional[str] = Query(None, max_length=10),
    host_id: Optional[int] = None,
    room_id: Optional[int] = None,
    guest_user_id: Optional[int] = None,
    sale_id: Optional[int] = None,
    mode: str = Query("", pattern="^(|nightly|theo_gio|qua_dem|theo_ngay)$"),
    q: str = Query("", max_length=100),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    R = models.Reservation
    query = db.query(R)
    if status:
        if status not in RESERVATION_STATUSES:
            raise fail(422, "ADMIN_BAD_FILTER", "Trạng thái không hợp lệ")
        query = query.filter(R.status == status)
    d1, d2 = ro.parse_day(date_from, "date_from"), ro.parse_day(date_to, "date_to")
    # Khoảng ở [check_in, check_out) GIAO với khoảng lọc [date_from, date_to].
    if d1:
        query = query.filter(R.check_out_date > d1.isoformat())
    if d2:
        query = query.filter(R.check_in_date <= d2.isoformat())
    if host_id:
        query = query.filter(R.host_id == host_id)
    if room_id:
        query = query.filter(R.room_id == room_id)
    if guest_user_id:
        query = query.filter(R.guest_user_id == guest_user_id)
    if sale_id:
        query = query.filter(R.sale_id == sale_id)
    if mode == "nightly":
        query = query.filter(R.booking_mode.is_(None))
    elif mode:
        query = query.filter(R.booking_mode == mode)
    term = q.strip()
    if term:
        conds = [func.lower(R.guest_name).like(f"%{term.lower()}%"), R.booking_code == term.upper(),
                 R.booking_code == term]
        rid = _id_term(term, "BK")
        if rid is not None:
            conds.append(R.id == rid)
        query = query.filter(or_(*conds))
    rows, total = paginate(query.order_by(R.id.desc()), page)
    cache: dict = {}
    return paged([ro.reservation_row(db, r, cache) for r in rows], total=total, page=page)


@router.get("/rentals/reservations/{reservation_id}")
def get_reservation(
    reservation_id: int,
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    return one(ro.reservation_detail(db, ctx, _reservation(db, reservation_id)))


def _reservation_command(db: Session, ctx: AdminContext, reservation_id: int, *, action: str, body: OverrideBody,
                         key: str, expected: Optional[str], call) -> dict:
    r = _reservation(db, reservation_id)
    state: dict = {}

    def do() -> CommandResult:
        old = r.status
        res = ro.domain(call, r)
        db.flush()
        state["from"] = old
        return CommandResult(
            data=ro.reservation_detail(db, ctx, res), before={"status": old},
            after={"status": res.status, "refund_amount": ro.vnd(res.refund_amount)}, event_status=res.status,
        )

    out = run_command(
        db, ctx, action=f"reservation.{action}", permission=OVERRIDE, entity_type=ro.RESERVATION_ENTITY,
        entity_id=reservation_id, key=key, fn=do, reason=body.reason, reason_required=True,
        expected_version=expected, current_version=lambda: ro.reservation_version(r),
        event_type="admin.reservation.updated",
    )
    if "from" in state:
        ro.publish_safely(
            publish_status_change, entity="reservation", entity_id=r.id, from_status=state["from"],
            to_status=r.status, participant_ids=(r.guest_user_id, r.host_id, r.sale_id),
            actor_id=ctx.user_id, action=action,
        )
    return out


@router.post("/rentals/reservations/{reservation_id}/approve")
def approve_reservation(
    reservation_id: int,
    body: OverrideBody,
    ctx: AdminContext = Depends(require_permission(OVERRIDE)),
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    db: Session = Depends(get_db),
):
    return _reservation_command(
        db, ctx, reservation_id, action="approve", body=body, key=key, expected=expected,
        call=lambda r: reservation_service.approve(db, r.host_id, r.id, actor_id=ctx.user_id),
    )


@router.post("/rentals/reservations/{reservation_id}/reject")
def reject_reservation(
    reservation_id: int,
    body: OverrideBody,
    ctx: AdminContext = Depends(require_permission(OVERRIDE)),
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    db: Session = Depends(get_db),
):
    public = body.public_reason.strip() or "Đơn bị từ chối bởi bộ phận vận hành ancu365"
    return _reservation_command(
        db, ctx, reservation_id, action="reject", body=body, key=key, expected=expected,
        call=lambda r: reservation_service.reject(db, r.host_id, r.id, reason=public, actor_id=ctx.user_id),
    )


@router.post("/rentals/reservations/{reservation_id}/cancel")
def cancel_reservation(
    reservation_id: int,
    body: OverrideBody,
    ctx: AdminContext = Depends(require_permission(OVERRIDE)),
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    db: Session = Depends(get_db),
):
    public = body.public_reason.strip() or "Đơn bị huỷ bởi bộ phận vận hành ancu365"
    return _reservation_command(
        db, ctx, reservation_id, action="cancel", body=body, key=key, expected=expected,
        call=lambda r: reservation_service.cancel(db, r.host_id, r.id, actor_id=ctx.user_id, reason=public),
    )


# ── Lịch chiếm dụng một phòng ─────────────────────────────────────────────────

OCCUPANCY_MAX_DAYS = 120


@router.get("/rentals/occupancy")
def room_occupancy(
    room_id: int,
    from_: Optional[str] = Query(None, alias="from", max_length=10),
    to: Optional[str] = Query(None, max_length=10),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    from app.services import chiem_dung_service

    room = db.get(models.Room, room_id)
    if room is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy phòng")
    tu = ro.parse_day(from_, "from") or date.today()
    den = ro.parse_day(to, "to") or tu + timedelta(days=30)
    if den <= tu or (den - tu).days > OCCUPANCY_MAX_DAYS:
        raise fail(422, "ADMIN_BAD_FILTER", f"Khoảng ngày phải dương và tối đa {OCCUPANCY_MAX_DAYS} ngày")
    blocks = chiem_dung_service.lich(db, room.id, tu, den)
    R = models.Reservation
    res = (
        db.query(R).filter(R.room_id == room.id, R.check_in_date < den.isoformat(),
                           R.check_out_date > tu.isoformat(), R.status.in_(ro.RESERVATION_ACTIVE))
        .order_by(R.check_in_date).limit(200).all()
    )
    # Đơn còn hiệu lực mà KHÔNG có dòng chiếm dụng tương ứng = lịch chung lệch.
    covered = {b.nguon_id for b in blocks if b.nguon == models.RoomChiemDung.RESERVATION}
    building = db.get(models.Building, room.building_id)
    return one({
        "room": {"id": room.id, "code": room.code, "status": room.status,
                 "building": None if building is None else {"id": building.id, "name": building.name}},
        "from": tu.isoformat(),
        "to": den.isoformat(),
        "blocks": [
            {"id": b.id, "from": b.tu_ngay.isoformat(), "to": b.den_ngay.isoformat(),
             "from_at": iso(b.tu_luc), "to_at": iso(b.den_luc), "kenh": b.kenh, "nguon": b.nguon,
             "nguon_id": b.nguon_id, "note": b.ghi_chu} for b in blocks
        ],
        "reservations": [
            {"id": r.id, "ref": ro.ref("BK", r.id), "status": r.status, "from": r.check_in_date,
             "to": r.check_out_date, "booking_mode": r.booking_mode, "guest_name": r.guest_name,
             "has_occupancy_block": r.id in covered} for r in res
        ],
    })


# ── Hợp đồng ──────────────────────────────────────────────────────────────────

CONTRACT_STATUSES = ("draft", "active", "expired", "terminated")


@router.get("/rentals/contracts")
def list_contracts(
    status: str = Query("", max_length=20),
    host_id: Optional[int] = None,
    room_id: Optional[int] = None,
    building_id: Optional[int] = None,
    expiring_within_days: Optional[int] = Query(None, ge=1, le=365),
    q: str = Query("", max_length=100),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    C = models.Contract
    query = db.query(C)
    if status:
        if status not in CONTRACT_STATUSES:
            raise fail(422, "ADMIN_BAD_FILTER", "Trạng thái không hợp lệ")
        query = query.filter(C.status == status)
    if host_id:
        query = query.filter(C.host_id == host_id)
    if room_id:
        query = query.filter(C.room_id == room_id)
    if building_id:
        query = query.filter(C.room_id.in_(db.query(models.Room.id).filter(models.Room.building_id == building_id)))
    order = (C.id.desc(),)
    if expiring_within_days:
        today = date.today()
        query = query.filter(
            C.status == "active", C.end_date >= today.isoformat(),
            C.end_date <= (today + timedelta(days=expiring_within_days)).isoformat(),
        )
        order = (C.end_date.asc(), C.id.asc())
    term = q.strip()
    if term:
        like = f"%{term.lower()}%"
        T, CT = models.Tenant, models.ContractTenant
        conds = [
            C.room_id.in_(db.query(models.Room.id).filter(func.lower(models.Room.code).like(like))),
            C.id.in_(db.query(CT.contract_id).join(T, T.id == CT.tenant_id).filter(func.lower(T.full_name).like(like))),
        ]
        cid = _id_term(term, "HD")
        if cid is not None:
            conds.append(C.id == cid)
        query = query.filter(or_(*conds))
    rows, total = paginate(query.order_by(*order), page)
    tenants = ro._primary_tenants(db, [c.id for c in rows])
    cache: dict = {}
    today = date.today()
    return paged([ro.contract_row(db, c, tenants.get(c.id), cache, today) for c in rows], total=total, page=page)


@router.get("/rentals/contracts/{contract_id}")
def get_contract(
    contract_id: int,
    ctx: AdminContext = Depends(require_permission(READ)),
    db: Session = Depends(get_db),
):
    c = db.get(models.Contract, contract_id)
    if c is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy hợp đồng")
    return one(ro.contract_detail(db, ctx, c))
