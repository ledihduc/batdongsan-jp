"""Bổ sung dữ liệu THẬT cho luồng Yêu cầu thuê của ba tài khoản demo.

Script này là phần mở rộng của ``seed_ba_vai_demo.py``. Nó không tạo tài
khoản mới và không xoá dữ liệu đang có. Thay vào đó, nó nối các lịch xem,
hành trình thuê, hợp đồng và yêu cầu Sale đã tồn tại của đúng ba tài khoản:

* ``khach.demo@ancu365.vn``
* ``sale.demo@ancu365.vn``
* ``chunha.demo@ancu365.vn``

Sau khi chạy, màn Yêu cầu của Sale có dữ liệu ở các bước đang xử lý; Khách và
Chủ nhà cùng nhìn thấy hai hồ sơ chung quan trọng:

* Muốn thuê: chưa có hợp đồng, Sale có thể gửi hợp đồng và ảnh cọc;
* Chờ cọc: đã có hợp đồng + hai minh chứng, Khách/Chủ nhà có thể xác nhận;
* Đã chốt: nối với hợp đồng đang ở thật của Khách demo.

Idempotent: chạy lại chỉ làm mới ngày tương đối theo hôm nay và dùng lại các
bản ghi đã seed. Cần chạy sau ``seed_ba_vai_demo.py``.

Chạy trong container production (script không cần nằm trong image):

    docker exec -i ancu365-backend python - \
      < scripts/seed_sale_request_three_role_demo.py
"""

from __future__ import annotations

from datetime import date, datetime, time, timedelta

from sqlalchemy import func

from app import models
from app.database import SessionLocal
from app.services import rental_journey_service
from app.services import sale_yeu_cau_lich


CUSTOMER_EMAIL = "khach.demo@ancu365.vn"
SALE_EMAIL = "sale.demo@ancu365.vn"
OWNER_EMAIL = "chunha.demo@ancu365.vn"
MARKER = "[SEED-SALE-REQUEST-THREE-ROLE]"


def _user(db, email: str, account_type: str) -> models.User:
    user = db.query(models.User).filter(func.lower(models.User.email) == email.lower()).first()
    if user is None or user.account_type != account_type:
        raise RuntimeError(
            f"Thiếu tài khoản {email} ({account_type}); hãy chạy scripts/seed_ba_vai_demo.py trước."
        )
    return user


def _room(db, owner_id: int, code: str) -> models.Room:
    room = (
        db.query(models.Room)
        .join(models.Building, models.Building.id == models.Room.building_id)
        .filter(models.Building.host_id == owner_id, models.Room.code == code)
        .order_by(models.Room.id.desc())
        .first()
    )
    if room is None:
        raise RuntimeError(f"Không tìm thấy phòng demo {code}")
    return room


def _appointment(
    db, customer_id: int, room_id: int, *, status: str | None = None
) -> models.ViewingAppointment:
    query = db.query(models.ViewingAppointment).filter(
        models.ViewingAppointment.guest_id == customer_id,
        models.ViewingAppointment.room_id == room_id,
        models.ViewingAppointment.loai == "xem",
    )
    if status is not None:
        query = query.filter(models.ViewingAppointment.status == status)
    row = query.order_by(models.ViewingAppointment.id.asc()).first()
    if row is None:
        suffix = f" trạng thái {status}" if status else ""
        raise RuntimeError(f"Không tìm thấy lịch xem phòng #{room_id}{suffix}")
    return row


def _at(day: date, hour: int = 9) -> datetime:
    return datetime.combine(day, time(hour=hour))


def _move_appointment(
    appointment: models.ViewingAppointment,
    *,
    day: date,
    status: str,
    responded_at: datetime | None,
) -> None:
    appointment.booking_date = day.isoformat()
    appointment.status = status
    appointment.responded_at = responded_at


def _ensure_interested_journey(
    db,
    *,
    appointment: models.ViewingAppointment,
    customer: models.User,
    now: datetime,
) -> models.RentalJourney:
    journey = (
        db.query(models.RentalJourney)
        .filter(models.RentalJourney.appointment_id == appointment.id)
        .first()
    )
    if journey is None:
        journey = rental_journey_service.create_from_viewing_result(
            db,
            {"sub": customer.id, "role": customer.role},
            appointment_id=appointment.id,
            outcome="INTERESTED",
            reason=f"{MARKER} Khách muốn thuê sau buổi xem.",
        )
    # Giữ đây là hồ sơ Sale còn phải gửi hợp đồng, không ghi đè hồ sơ nếu
    # người kiểm thử đã thao tác tiếp sau lần seed trước.
    if not journey.contract_urls and journey.status != "COMPLETED":
        journey.status = "CUSTOMER_INTERESTED"
        journey.total_deposit = 0
        journey.updated_at = now - timedelta(hours=4)
        for payment in db.query(models.RentalJourneyPayment).filter(
            models.RentalJourneyPayment.journey_id == journey.id
        ):
            payment.amount = 0
            payment.status = "PENDING"
            payment.proof_urls = []
            payment.submitted_by = None
            payment.submitted_at = None
    return journey


def _sale_customer(
    db,
    *,
    sale: models.User,
    customer: models.User,
) -> models.SaleKhach:
    row = (
        db.query(models.SaleKhach)
        .filter(
            models.SaleKhach.sale_id == sale.id,
            models.SaleKhach.user_id == customer.id,
        )
        .first()
    )
    if row is None:
        row = models.SaleKhach(
            sale_id=sale.id,
            user_id=customer.id,
            ho_ten=customer.name,
            sdt=customer.phone or "",
            khu_vuc="Văn Cao, Ngô Quyền, Hải Phòng",
            trang_thai="dang_tu_van",
        )
        db.add(row)
        db.flush()
    return row


def _ensure_manual_request(
    db,
    *,
    sale: models.User,
    customer: models.User,
    room: models.Room,
    stage: str,
    now: datetime,
) -> models.SaleYeuCau:
    if stage not in models.SaleYeuCau.BUOC:
        raise ValueError(f"Bước không hợp lệ: {stage}")
    sale_customer = _sale_customer(db, sale=sale, customer=customer)
    tag = f"{MARKER}:{stage}"
    request = (
        db.query(models.SaleYeuCau)
        .filter(
            models.SaleYeuCau.sale_id == sale.id,
            models.SaleYeuCau.appointment_id.is_(None),
            models.SaleYeuCau.ghi_chu.ilike(f"%{tag}%"),
        )
        .first()
    )
    created_at = now - timedelta(hours=8)
    if request is None:
        request = models.SaleYeuCau(
            sale_id=sale.id,
            khach_id=sale_customer.id,
            loai_can=f"Phòng {room.code}",
            khu_vuc="Văn Cao, Ngô Quyền, Hải Phòng",
            ngan_sach_min=int(room.base_price or 0),
            ngan_sach_max=int(room.base_price or 0) + 1_000_000,
            vao_o_tu=now + timedelta(days=20),
            ghi_chu=f"{tag} Yêu cầu thật để kiểm thử màn quản lý Sale.",
            trang_thai=stage,
            created_at=created_at,
            updated_at=now - timedelta(hours=1),
        )
        db.add(request)
        db.flush()
    else:
        request.trang_thai = stage
        request.dong_ly_do = None
        request.dong_luc = None

    link = (
        db.query(models.SaleYeuCauCan)
        .filter(
            models.SaleYeuCauCan.yeu_cau_id == request.id,
            models.SaleYeuCauCan.room_id == room.id,
        )
        .first()
    )
    if link is None:
        db.add(
            models.SaleYeuCauCan(
                yeu_cau_id=request.id,
                room_id=room.id,
                khach_thich=True,
            )
        )
    else:
        link.khach_thich = True

    existing = {
        milestone.moc
        for milestone in db.query(models.SaleYeuCauMoc).filter(
            models.SaleYeuCauMoc.yeu_cau_id == request.id
        )
    }
    current_index = list(models.SaleYeuCau.BUOC).index(stage)
    for index, milestone_stage in enumerate(models.SaleYeuCau.BUOC):
        if index <= current_index and milestone_stage not in existing:
            db.add(
                models.SaleYeuCauMoc(
                    yeu_cau_id=request.id,
                    moc=milestone_stage,
                    boi_ai=sale.id,
                    ghi_chu="Dữ liệu demo ba vai",
                    luc=created_at + timedelta(hours=index),
                )
            )
    return request


def _ensure_completed_journey(
    db,
    *,
    appointment: models.ViewingAppointment,
    customer: models.User,
    sale: models.User,
    owner: models.User,
    contract: models.Contract,
    evidence_source: models.RentalJourney,
    now: datetime,
) -> models.RentalJourney:
    journey = (
        db.query(models.RentalJourney)
        .filter(models.RentalJourney.appointment_id == appointment.id)
        .first()
    )
    completed_at = now - timedelta(days=60)
    if journey is None:
        journey = models.RentalJourney(
            appointment_id=appointment.id,
            room_id=appointment.room_id,
            house_id=appointment.house_id,
            customer_id=customer.id,
            sale_id=sale.id,
            owner_id=owner.id,
            status="COMPLETED",
            created_at=completed_at - timedelta(days=2),
            updated_at=completed_at,
        )
        db.add(journey)
        db.flush()
    journey.customer_id = customer.id
    journey.sale_id = sale.id
    journey.owner_id = owner.id
    journey.status = "COMPLETED"
    journey.contract_id = contract.id
    journey.contract_urls = list(evidence_source.contract_urls or [])
    journey.contract_note = f"{MARKER} Hợp đồng đang ở của Khách demo."
    journey.contract_submitted_by = sale.id
    journey.contract_submitted_at = completed_at - timedelta(days=1)
    journey.total_deposit = int(contract.deposit or contract.monthly_rent or 0)
    journey.deposit_policy_version = evidence_source.deposit_policy_version
    journey.platform_deposit_bps = evidence_source.platform_deposit_bps
    journey.completed_at = completed_at
    journey.cancel_reason = None
    journey.cancelled_at = None
    journey.updated_at = completed_at
    appointment.status = "locked"

    source_payments = {
        payment.kind: payment
        for payment in db.query(models.RentalJourneyPayment).filter(
            models.RentalJourneyPayment.journey_id == evidence_source.id
        )
    }
    split_app = journey.total_deposit * int(journey.platform_deposit_bps or 5000) // 10_000
    amounts = {
        "APP_DEPOSIT": split_app,
        "OWNER_DEPOSIT": journey.total_deposit - split_app,
    }
    for kind, amount in amounts.items():
        payment = (
            db.query(models.RentalJourneyPayment)
            .filter(
                models.RentalJourneyPayment.journey_id == journey.id,
                models.RentalJourneyPayment.kind == kind,
            )
            .first()
        )
        if payment is None:
            payment = models.RentalJourneyPayment(journey_id=journey.id, kind=kind)
            db.add(payment)
        source = source_payments.get(kind)
        payment.amount = amount
        payment.status = "SUBMITTED"
        payment.proof_urls = list(source.proof_urls or []) if source else []
        payment.submitted_by = customer.id
        payment.submitted_at = completed_at - timedelta(hours=12)

    event = (
        db.query(models.RentalJourneyEvent)
        .filter(
            models.RentalJourneyEvent.journey_id == journey.id,
            models.RentalJourneyEvent.event_type == "SEED_RENTAL_COMPLETED",
        )
        .first()
    )
    if event is None:
        db.add(
            models.RentalJourneyEvent(
                journey_id=journey.id,
                actor_id=customer.id,
                actor_role="customer",
                event_type="SEED_RENTAL_COMPLETED",
                from_status="CUSTOMER_CONFIRMATION_PENDING",
                to_status="COMPLETED",
                payload={"marker": MARKER},
                created_at=completed_at,
            )
        )
    return journey


def main() -> None:
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        today = date.today()
        customer = _user(db, CUSTOMER_EMAIL, "customer")
        sale = _user(db, SALE_EMAIL, "sale")
        owner = _user(db, OWNER_EMAIL, "owner")

        p101 = _room(db, owner.id, "P101")
        p202 = _room(db, owner.id, "P202")
        p301 = _room(db, owner.id, "P301")
        p302 = _room(db, owner.id, "P302")

        # Một lịch đổi giờ, một lịch sắp xem và một hồ sơ khách muốn thuê.
        p202_rows = (
            db.query(models.ViewingAppointment)
            .filter(
                models.ViewingAppointment.guest_id == customer.id,
                models.ViewingAppointment.room_id == p202.id,
                models.ViewingAppointment.loai == "xem",
            )
            .order_by(models.ViewingAppointment.id.asc())
            .all()
        )
        if len(p202_rows) < 2:
            raise RuntimeError("Cần hai lịch xem P202 từ seed ba vai nền")
        interested_appointment, reschedule = p202_rows[0], p202_rows[1]
        _move_appointment(
            interested_appointment,
            day=today - timedelta(days=2),
            status="completed",
            responded_at=now - timedelta(days=3),
        )
        _move_appointment(
            reschedule,
            day=today + timedelta(days=1),
            status="doi_gio",
            responded_at=now - timedelta(hours=2),
        )

        upcoming = _appointment(db, customer.id, p302.id)
        _move_appointment(
            upcoming,
            day=today + timedelta(days=2),
            status="locked",
            responded_at=now - timedelta(hours=1),
        )

        # P101 nối với hợp đồng đang ở thật và trở thành hồ sơ đã chốt chung
        # của cả ba vai.
        completed_appointment = _appointment(db, customer.id, p101.id)
        _move_appointment(
            completed_appointment,
            day=today - timedelta(days=65),
            status="completed",
            responded_at=now - timedelta(days=66),
        )

        # P301 đã có hợp đồng + hai ảnh cọc thật trong uploads; giữ ở bước chờ
        # xác nhận để cả Khách và Chủ nhà đều có nút xử lý.
        deposit_appointment = _appointment(db, customer.id, p301.id)
        _move_appointment(
            deposit_appointment,
            day=today - timedelta(days=5),
            status="completed",
            responded_at=now - timedelta(days=6),
        )
        db.commit()

        deposit = (
            db.query(models.RentalJourney)
            .filter(models.RentalJourney.appointment_id == deposit_appointment.id)
            .first()
        )
        if deposit is None or not deposit.contract_urls:
            raise RuntimeError("Hồ sơ P301 chưa có hợp đồng thật")
        proofs = {
            payment.kind: len(payment.proof_urls or [])
            for payment in db.query(models.RentalJourneyPayment).filter(
                models.RentalJourneyPayment.journey_id == deposit.id
            )
        }
        if not proofs.get("APP_DEPOSIT") or not proofs.get("OWNER_DEPOSIT"):
            raise RuntimeError("Hồ sơ P301 chưa đủ hai ảnh cọc thật")

        interested = _ensure_interested_journey(
            db,
            appointment=interested_appointment,
            customer=customer,
            now=now,
        )

        active_contract = (
            db.query(models.Contract)
            .filter(
                models.Contract.host_id == owner.id,
                models.Contract.room_id == p101.id,
                models.Contract.status == "active",
            )
            .order_by(models.Contract.id.desc())
            .first()
        )
        if active_contract is None:
            raise RuntimeError("Không tìm thấy hợp đồng đang ở của Khách demo")
        completed = _ensure_completed_journey(
            db,
            appointment=completed_appointment,
            sale=sale,
            customer=customer,
            owner=owner,
            contract=active_contract,
            evidence_source=deposit,
            now=now,
        )

        # Hai đơn Sale lập trực tiếp giúp danh sách luôn có Lead mới và Sau
        # xem, kể cả khi các lịch thật đã được người kiểm thử xử lý tiếp.
        _ensure_manual_request(
            db,
            sale=sale,
            customer=customer,
            room=p302,
            stage="lead_moi",
            now=now,
        )
        _ensure_manual_request(
            db,
            sale=sale,
            customer=customer,
            room=p301,
            stage="sau_xem",
            now=now,
        )
        db.commit()

        # Tạo/cập nhật các YC từ lịch xem và hành trình thật.
        sale_yeu_cau_lich.dong_bo(db, sale.id)
        requests = (
            db.query(models.SaleYeuCau)
            .filter(models.SaleYeuCau.sale_id == sale.id)
            .order_by(models.SaleYeuCau.updated_at.desc())
            .all()
        )

        counts = {stage: 0 for stage in models.SaleYeuCau.BUOC}
        for request in requests:
            if request.trang_thai in counts:
                counts[request.trang_thai] += 1

        print("ĐÃ SEED DỮ LIỆU YÊU CẦU BA VAI")
        print(f"accounts customer={customer.id} sale={sale.id} owner={owner.id}")
        print(
            f"journey_muon_thue={interested.id} "
            f"journey_cho_coc={deposit.id} journey_da_chot={completed.id}"
        )
        print("pipeline " + " ".join(f"{key}={value}" for key, value in counts.items()))
        print(
            f"evidence contract={len(deposit.contract_urls or [])} "
            f"app_deposit={proofs['APP_DEPOSIT']} "
            f"owner_deposit={proofs['OWNER_DEPOSIT']}"
        )
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
