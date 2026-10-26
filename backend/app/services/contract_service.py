"""Contract service — state machine + audit trail for all contract mutations.

Every status-changing operation:
1. Validates the state machine transition
2. Updates the contract (and room where applicable)
3. Writes a change_logs row via write_change_log()
4. Does NOT commit — caller (router) commits after success

State machine:
  draft → active          (activate_contract)
  active → expired        (auto — not implemented here; Phase 04 cron)
  active → terminated     (terminate_contract)
  terminated = terminal   (no further transitions)
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.repositories.audit import write_change_log
from app.repositories.contract_repository import ContractRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.tenant_repository import TenantRepository
from app.schemas.contract import (
    BatchRenewRequest,
    ContractCreate,
    TerminateContractRequest,
    TransferRoomRequest,
)
from app.services import chiem_dung_service, khai_thac_service
from app.services.room_state_service import set_occupied, set_vacant

# Valid forward transitions
_VALID_TRANSITIONS: dict[str, set[str]] = {
    "draft": {"active"},
    "active": {"expired", "terminated"},
    "expired": set(),
    "terminated": set(),
}


def _assert_transition(contract: models.Contract, to_status: str) -> None:
    """Raise 400 if the transition is not valid."""
    allowed = _VALID_TRANSITIONS.get(contract.status, set())
    if to_status not in allowed:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Không thể chuyển hợp đồng từ '{contract.status}' sang '{to_status}'. "
                f"Chỉ cho phép: {list(allowed)}"
            ),
        )


def _contract_snapshot(contract: models.Contract) -> dict:
    """Build a JSON-serialisable snapshot of a contract for audit log."""
    return {
        "id": contract.id,
        "room_id": contract.room_id,
        "status": contract.status,
        "start_date": contract.start_date,
        "end_date": contract.end_date,
        "monthly_rent": contract.monthly_rent,
        "deposit": contract.deposit,
        "terminated_at": contract.terminated_at,
        "actual_end_date": contract.actual_end_date,
        "deposit_refund_amount": contract.deposit_refund_amount,
        "damage_note": contract.damage_note,
    }


def create_contract(
    db: Session,
    payload: ContractCreate,
    host_id: int,
) -> models.Contract:
    """Create a Contract in draft status with Tenant rows + pivot rows.

    Flow:
    1. Verify room belongs to host and is vacant
    2. Create Tenant rows (or reuse existing via phone match — MVP: always create)
    3. Create Contract row (status=draft)
    4. Create ContractTenant pivot rows
    5. Write create audit log
    """
    # Verify room ownership + status
    room_repo = RoomRepository(db, host_id)
    room = room_repo.get(payload.room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại hoặc không thuộc host này")
    if room.status != "vacant":
        raise HTTPException(
            status_code=400,
            detail=f"Phòng đang ở trạng thái '{room.status}' — chỉ tạo hợp đồng khi phòng trống",
        )

    # Create Tenant rows
    tenant_repo = TenantRepository(db, host_id)
    now = datetime.utcnow()

    # Phase 04: dual-write FK source_id (manual = host-created contract).
    from app.services import source_service
    source_id = source_service.resolve_default_source_id(db, host_id, "manual")

    contract = models.Contract(
        host_id=host_id,
        room_id=payload.room_id,
        start_date=payload.start_date,
        end_date=payload.end_date,
        monthly_rent=payload.monthly_rent,
        deposit=payload.deposit,
        status="draft",
        handover_photos=payload.handover_photos,
        ngay_thanh_toan=payload.ngay_thanh_toan,
        hinh_thuc_thanh_toan=payload.hinh_thuc_thanh_toan,
        coc_da_thu=payload.coc_da_thu,
        source_id=source_id,
        created_at=now,
        updated_at=now,
    )
    db.add(contract)
    db.flush()  # get contract.id

    contract_repo = ContractRepository(db, host_id)

    for tenant_data in payload.tenants:
        tenant = tenant_repo.create(tenant_data)
        contract_repo.add_tenant_pivot(
            contract_id=contract.id,
            tenant_id=tenant.id,
            is_primary=tenant_data.is_primary,
            joined_at=payload.start_date,
        )

    write_change_log(
        db,
        entity_type="contract",
        entity_id=contract.id,
        actor_id=host_id,
        action="create",
        before=None,
        after=_contract_snapshot(contract),
    )

    # Phase 05 — auto-create khai báo tạm trú per tenant. Failures here must
    # NOT silently swallow but they also shouldn't roll back the contract —
    # caller (router) commits a single txn so any exception propagates naturally.
    from app.services import khai_bao_service

    khai_bao_service.auto_create_for_contract(db, contract)

    return contract



def _ngay(v) -> Optional[date]:
    """'YYYY-MM-DD' → date. None nếu ô trống hoặc sai định dạng.

    `contracts.start_date` là VARCHAR (di sản), nên dữ liệu cũ có cả chuỗi rỗng.
    """
    try:
        return datetime.strptime(str(v)[:10], "%Y-%m-%d").date()
    except (ValueError, TypeError):
        return None


def _giu_cho(db: Session, contract: models.Contract) -> None:
    """Hợp đồng chạy → chiếm chỗ trên dòng thời gian CHUNG của phòng (R4).

    Không có bước này thì kênh ngắn hạn vẫn nhận đặt đêm rơi vào giữa kỳ thuê:
    `reservations` không nhìn thấy `contracts`, hai bảng không biết nhau.

    `end_date` là ngày CUỐI CÙNG còn hiệu lực, còn `den_ngay` là ngày trả phòng
    (không tính) — nên cộng một ngày.
    """
    tu, den = _ngay(contract.start_date), _ngay(contract.end_date)
    if tu is None or den is None or den < tu:
        return
    try:
        chiem_dung_service.ghi(
            db,
            room_id=contract.room_id,
            tu_ngay=tu,
            den_ngay=den + timedelta(days=1),
            kenh="dai_han",
            nguon=models.RoomChiemDung.CONTRACT,
            nguon_id=contract.id,
        )
    except chiem_dung_service.TrungLich as e:
        raise HTTPException(status_code=409, detail=e.message) from e


def activate_contract(
    db: Session,
    contract_id: int,
    host_id: int,
) -> models.Contract:
    """Transition contract draft → active. Sets room to occupied."""
    contract_repo = ContractRepository(db, host_id)
    contract = contract_repo.get(contract_id)
    if not contract:
        raise HTTPException(status_code=404, detail="Hợp đồng không tồn tại")

    _assert_transition(contract, "active")
    before = _contract_snapshot(contract)

    room_repo = RoomRepository(db, host_id)
    room = room_repo.get(contract.room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")

    set_occupied(room)
    room.updated_at = datetime.utcnow()

    contract.status = "active"
    contract.updated_at = datetime.utcnow()
    _giu_cho(db, contract)

    # Có khách thuê → kênh thuê của phòng CHỐT, và mọi tin cho thuê đang rao
    # của phòng đó ngừng hiển thị — kể cả tin do sale khác đăng. Không có bước
    # này thì khách vẫn gọi vào tin đã chết.
    #
    # KHÔNG đụng kênh `ban`: phòng cho thuê xong vẫn bán được (bán kèm khách).
    for kenh in (models.RoomKenh.DAI_HAN, models.RoomKenh.MAT_BANG):
        khai_thac_service.chot_kenh(
            db,
            room=room,
            kenh=kenh,
            trang_thai=models.RoomKenh.DA_CHO_THUE,
            nguoi_chot=host_id,
        )
    db.flush()

    write_change_log(
        db,
        entity_type="contract",
        entity_id=contract.id,
        actor_id=host_id,
        action="status_change",
        before=before,
        after=_contract_snapshot(contract),
    )

    return contract


def terminate_contract(
    db: Session,
    contract_id: int,
    payload: TerminateContractRequest,
    host_id: int,
) -> models.Contract:
    """Transition contract active → terminated. Sets room back to vacant.

    Records actual_end_date, deposit_refund_amount, damage_note, damage_photos.
    Invoice prorate happens in Phase 04 — this method just records the event.
    """
    contract_repo = ContractRepository(db, host_id)
    contract = contract_repo.get(contract_id)
    if not contract:
        raise HTTPException(status_code=404, detail="Hợp đồng không tồn tại")

    _assert_transition(contract, "terminated")
    before = _contract_snapshot(contract)

    room_repo = RoomRepository(db, host_id)
    room = room_repo.get(contract.room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")

    set_vacant(room)
    room.updated_at = datetime.utcnow()
    # Trả phòng sớm → trả luôn phần lịch còn lại, không thì phòng "bận" tới hết
    # kỳ hạn cũ và chủ nhà không cho ai thuê tiếp được.
    chiem_dung_service.go(db, models.RoomChiemDung.CONTRACT, contract.id)
    # Kênh thuê mở lại để rao tiếp. Tin cũ KHÔNG bật lại — nó là quảng cáo của
    # lượt trước, có giá của lượt trước; rao lại là đăng tin MỚI.
    for kenh in (models.RoomKenh.DAI_HAN, models.RoomKenh.MAT_BANG):
        khai_thac_service.mo_lai_kenh(db, room_id=room.id, kenh=kenh)

    now_str = datetime.utcnow().date().isoformat()
    contract.status = "terminated"
    contract.terminated_at = now_str
    contract.actual_end_date = payload.actual_end_date
    contract.deposit_refund_amount = payload.deposit_refund_amount
    contract.damage_note = payload.damage_note
    contract.damage_photos = payload.damage_photos
    contract.updated_at = datetime.utcnow()
    db.flush()

    write_change_log(
        db,
        entity_type="contract",
        entity_id=contract.id,
        actor_id=host_id,
        action="status_change",
        before=before,
        after=_contract_snapshot(contract),
    )

    # Phase 04 C5 — generate move-out final invoice (prorate rent + final meter
    # + deposit refund + damage deduction). Errors here must NOT silently swallow,
    # but invoice failure shouldn't block contract termination integrity — so we
    # raise to caller (router commits/rolls back the whole transaction).
    from app.services.move_out_invoice_service import generate_final_invoice

    generate_final_invoice(
        db,
        contract=contract,
        actual_end_date=payload.actual_end_date,
        host_id=host_id,
        deposit_refund_amount=payload.deposit_refund_amount or 0,
        damage_deduction_amount=0,  # Captured via separate API in Phase 04 UI
    )

    return contract


def transfer_room(
    db: Session,
    contract_id: int,
    payload: TransferRoomRequest,
    host_id: int,
) -> models.Contract:
    """Transfer an active contract to a new room.

    Validates new room is vacant, updates room statuses, writes audit log.
    Prorate of utility meters is deferred to Phase 04.
    """
    contract_repo = ContractRepository(db, host_id)
    contract = contract_repo.get(contract_id)
    if not contract:
        raise HTTPException(status_code=404, detail="Hợp đồng không tồn tại")

    if contract.status != "active":
        raise HTTPException(
            status_code=400,
            detail="Chỉ có thể chuyển phòng cho hợp đồng đang hoạt động",
        )

    room_repo = RoomRepository(db, host_id)
    old_room = room_repo.get(contract.room_id)
    new_room = room_repo.get(payload.new_room_id)

    if not new_room:
        raise HTTPException(status_code=404, detail="Phòng mới không tồn tại hoặc không thuộc host này")
    if new_room.status != "vacant":
        raise HTTPException(
            status_code=400,
            detail=f"Phòng mới đang ở trạng thái '{new_room.status}' — chỉ chuyển được phòng trống",
        )

    before = _contract_snapshot(contract)

    # Free old room, occupy new room
    if old_room:
        # Direct status update — room might have been manually freed already
        old_room.status = "vacant"
        old_room.updated_at = datetime.utcnow()

    set_occupied(new_room)
    new_room.updated_at = datetime.utcnow()

    contract.room_id = payload.new_room_id
    contract.updated_at = datetime.utcnow()
    db.flush()

    write_change_log(
        db,
        entity_type="contract",
        entity_id=contract.id,
        actor_id=host_id,
        action="update",
        before=before,
        after=_contract_snapshot(contract),
    )

    return contract


def batch_renew(
    db: Session,
    payload: BatchRenewRequest,
    host_id: int,
) -> list[int]:
    """Bulk update end_date on multiple active contracts.

    Returns list of contract IDs that were actually updated.
    Only active contracts for this host are updated — others are silently skipped.
    """
    contract_repo = ContractRepository(db, host_id)
    renewed_ids: list[int] = []

    for contract_id in payload.contract_ids:
        contract = contract_repo.get(contract_id)
        if not contract or contract.status not in ("active", "draft"):
            continue  # skip silently — cross-host or wrong status
        before = _contract_snapshot(contract)
        contract.end_date = payload.new_end_date
        contract.updated_at = datetime.utcnow()
        db.flush()

        write_change_log(
            db,
            entity_type="contract",
            entity_id=contract.id,
            actor_id=host_id,
            action="update",
            before=before,
            after=_contract_snapshot(contract),
        )
        renewed_ids.append(contract.id)

    return renewed_ids
