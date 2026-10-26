"""Pure authorization and state policy for the long-term rental journey."""

from __future__ import annotations

import re

WAITING_VIEWING = "WAITING_VIEWING"
CUSTOMER_INTERESTED = "CUSTOMER_INTERESTED"
CUSTOMER_DECLINED = "CUSTOMER_DECLINED"
CONTRACT_READY = "CONTRACT_READY"
DEPOSITS_PENDING = "DEPOSITS_PENDING"
CUSTOMER_CONFIRMATION_PENDING = "CUSTOMER_CONFIRMATION_PENDING"
COMPLETED = "COMPLETED"
CANCELLED = "CANCELLED"
DISPUTED = "DISPUTED"

UPLOAD_CONTRACT = "UPLOAD_CONTRACT"
SUBMIT_APP_DEPOSIT = "SUBMIT_APP_DEPOSIT"
SUBMIT_OWNER_DEPOSIT = "SUBMIT_OWNER_DEPOSIT"
ACKNOWLEDGE_OWNER_DEPOSIT = "ACKNOWLEDGE_OWNER_DEPOSIT"
CONFIRM_RENTAL = "CONFIRM_RENTAL"
CANCEL_JOURNEY = "CANCEL_JOURNEY"
REPORT_PARTICIPANT = "REPORT_PARTICIPANT"

TERMINAL_STATUSES = {COMPLETED, CANCELLED}
ALL_STATUSES = {
    WAITING_VIEWING,
    CUSTOMER_INTERESTED,
    CUSTOMER_DECLINED,
    CONTRACT_READY,
    DEPOSITS_PENDING,
    CUSTOMER_CONFIRMATION_PENDING,
    COMPLETED,
    CANCELLED,
    DISPUTED,
}

_EVIDENCE_PATH = re.compile(
    r"^/uploads/[A-Za-z0-9][A-Za-z0-9._-]{0,199}\.(?:jpe?g|png|webp|pdf)$",
    re.IGNORECASE,
)


def validate_evidence_paths(paths: list[str]) -> list[str]:
    """Accept only paths issued by the existing authenticated upload endpoint."""
    if not 1 <= len(paths) <= 10:
        raise ValueError("Cần từ 1 đến 10 tệp minh chứng")
    cleaned: list[str] = []
    for raw in paths:
        path = (raw or "").strip()
        if not _EVIDENCE_PATH.fullmatch(path):
            raise ValueError("Đường dẫn minh chứng không hợp lệ")
        cleaned.append(path)
    return cleaned


def status_after_evidence(
    *, has_contract: bool, has_app_proof: bool, has_owner_proof: bool
) -> str:
    if not has_contract:
        return CUSTOMER_INTERESTED
    if has_app_proof and has_owner_proof:
        return CUSTOMER_CONFIRMATION_PENDING
    if has_app_proof or has_owner_proof:
        return DEPOSITS_PENDING
    return CONTRACT_READY


def available_actions(
    *,
    actor: str,
    status: str,
    has_contract: bool,
    has_app_proof: bool,
    has_owner_proof: bool,
    owner_proof_acknowledged: bool = False,
) -> list[str]:
    if actor not in {"customer", "sale", "owner", "admin"}:
        return []
    if status in TERMINAL_STATUSES:
        return []
    if status == CUSTOMER_DECLINED:
        return [REPORT_PARTICIPANT]

    actions: list[str] = []
    if actor in {"sale", "admin"} and status in {
        CUSTOMER_INTERESTED,
        CONTRACT_READY,
        DEPOSITS_PENDING,
        CUSTOMER_CONFIRMATION_PENDING,
    }:
        actions.append(UPLOAD_CONTRACT)

    # THUÊ TRƯỚC, BỔ SUNG GIẤY TỜ SAU (chủ dự án 14/10/2026): thiếu ảnh hợp
    # đồng hay minh chứng cọc KHÔNG còn chặn chốt — trước đây chặn nên khách
    # đã dọn vào mà app vẫn báo phòng trống. Phần còn thiếu hiện thành cảnh
    # báo và tải bổ sung được trên chính hợp đồng (`giay_to_hop_dong`).
    _du_dieu_kien_chot = status in {
        CUSTOMER_INTERESTED,
        CONTRACT_READY,
        DEPOSITS_PENDING,
        CUSTOMER_CONFIRMATION_PENDING,
    }

    if actor == "customer" and has_contract and status in {
        CONTRACT_READY,
        DEPOSITS_PENDING,
        CUSTOMER_CONFIRMATION_PENDING,
    }:
        actions.extend([SUBMIT_APP_DEPOSIT, SUBMIT_OWNER_DEPOSIT])
    if actor == "customer" and _du_dieu_kien_chot:
        actions.append(CONFIRM_RENTAL)

    # SALE nộp minh chứng cọc HỘ khách (24/09/2026): thực tế khách chuyển
    # khoản rồi gửi ảnh qua Zalo cho sale, không tự mở app tải lên — hồ sơ
    # kẹt ở "Chờ cọc" dù tiền đã chuyển. Sale vẫn KHÔNG được chốt (xem
    # test_sale_never_gets_final_confirm): người trả tiền / nhận tiền mới chốt.
    if actor == "sale" and has_contract and status in {
        CONTRACT_READY,
        DEPOSITS_PENDING,
        CUSTOMER_CONFIRMATION_PENDING,
    }:
        actions.extend([SUBMIT_APP_DEPOSIT, SUBMIT_OWNER_DEPOSIT])

    # CHỦ NHÀ cũng chốt được — ai bấm trước cũng xong (quyết định 23/09/2026).
    # Trước đây chỉ khách mới có nút này, nên hồ sơ đủ hợp đồng + hai minh
    # chứng cọc vẫn nằm im khi khách không mở app: chủ nhà nhìn thấy đủ mọi
    # thứ mà không có cách nào nhận người vào ở.
    if actor in {"owner", "admin"} and _du_dieu_kien_chot:
        actions.append(CONFIRM_RENTAL)

    if (
        actor in {"owner", "admin"}
        and has_owner_proof
        and not owner_proof_acknowledged
        and status in {DEPOSITS_PENDING, CUSTOMER_CONFIRMATION_PENDING}
    ):
        actions.append(ACKNOWLEDGE_OWNER_DEPOSIT)

    if status != DISPUTED:
        actions.append(REPORT_PARTICIPANT)
        if actor in {"customer", "owner", "admin"}:
            actions.append(CANCEL_JOURNEY)
    return actions
