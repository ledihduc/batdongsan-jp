import pytest

from app.services import rental_journey_policy as policy


def test_customer_can_confirm_before_documents_and_still_upload_proofs():
    """Thuê trước, bổ sung giấy tờ sau (14/10/2026): chưa có minh chứng cọc vẫn
    chốt được, và vẫn nộp minh chứng được."""
    before = policy.available_actions(
        actor="customer",
        status=policy.CONTRACT_READY,
        has_contract=True,
        has_app_proof=False,
        has_owner_proof=False,
    )
    assert policy.CONFIRM_RENTAL in before
    assert policy.SUBMIT_APP_DEPOSIT in before
    assert policy.SUBMIT_OWNER_DEPOSIT in before

    chua_hop_dong = policy.available_actions(
        actor="customer",
        status=policy.CUSTOMER_INTERESTED,
        has_contract=False,
        has_app_proof=False,
        has_owner_proof=False,
    )
    assert policy.CONFIRM_RENTAL in chua_hop_dong


def test_sale_never_gets_final_confirm():
    """SALE không bao giờ chốt thay — người trả tiền và người nhận tiền mới chốt."""
    actions = policy.available_actions(
        actor="sale",
        status=policy.CUSTOMER_CONFIRMATION_PENDING,
        has_contract=True,
        has_app_proof=True,
        has_owner_proof=True,
    )
    assert policy.CONFIRM_RENTAL not in actions


@pytest.mark.parametrize("actor", ["customer", "owner"])
def test_khach_va_chu_nha_deu_chot_duoc(actor):
    """Đủ hợp đồng + hai minh chứng cọc thì AI BẤM TRƯỚC CŨNG XONG (23/09/2026).

    Trước đây chỉ khách có nút này. Khách không mở app là hồ sơ nằm im: chủ
    nhà nhìn thấy đủ giấy mà không có cách nào nhận người vào ở, còn phòng thì
    vẫn hiện "trống" trên chợ.
    """
    actions = policy.available_actions(
        actor=actor,
        status=policy.CUSTOMER_CONFIRMATION_PENDING,
        has_contract=True,
        has_app_proof=True,
        has_owner_proof=True,
    )
    assert policy.CONFIRM_RENTAL in actions


@pytest.mark.parametrize("actor", ["customer", "owner"])
def test_thieu_giay_van_chot_duoc_chi_canh_bao(actor):
    """Luật cũ "thiếu giấy thì không ai chốt" đã bỏ theo chủ dự án 14/10/2026."""
    for thieu in ("has_contract", "has_app_proof", "has_owner_proof"):
        du = {
            "has_contract": True,
            "has_app_proof": True,
            "has_owner_proof": True,
            thieu: False,
        }
        actions = policy.available_actions(
            actor=actor, status=policy.DEPOSITS_PENDING, **du
        )
        assert policy.CONFIRM_RENTAL in actions, thieu


def test_ho_so_da_huy_hay_xong_thi_khong_chot_lai():
    for status in (policy.CANCELLED, policy.COMPLETED, policy.CUSTOMER_DECLINED):
        actions = policy.available_actions(
            actor="owner", status=status,
            has_contract=False, has_app_proof=False, has_owner_proof=False,
        )
        assert policy.CONFIRM_RENTAL not in actions, status


def test_sale_can_submit_contract_but_owner_cannot():
    sale_actions = policy.available_actions(
        actor="sale",
        status=policy.CUSTOMER_INTERESTED,
        has_contract=False,
        has_app_proof=False,
        has_owner_proof=False,
    )
    owner_actions = policy.available_actions(
        actor="owner",
        status=policy.CUSTOMER_INTERESTED,
        has_contract=False,
        has_app_proof=False,
        has_owner_proof=False,
    )
    assert policy.UPLOAD_CONTRACT in sale_actions
    assert policy.UPLOAD_CONTRACT not in owner_actions


def test_completed_and_cancelled_are_terminal():
    for status in (policy.COMPLETED, policy.CANCELLED):
        for actor in ("customer", "sale", "owner"):
            assert policy.available_actions(
                actor=actor,
                status=status,
                has_contract=True,
                has_app_proof=True,
                has_owner_proof=True,
            ) == []


@pytest.mark.parametrize(
    "path",
    [
        "https://evil.example/proof.jpg",
        "/uploads/../secret.txt",
        "/uploads/proof.exe",
        "uploads/no-leading-slash.jpg",
    ],
)
def test_rejects_untrusted_evidence_paths(path):
    with pytest.raises(ValueError):
        policy.validate_evidence_paths([path])


def test_accepts_server_issued_image_and_pdf_paths():
    assert policy.validate_evidence_paths(
        ["/uploads/20260920120000-a1b2c3.jpg", "/uploads/hop-dong.pdf"]
    ) == ["/uploads/20260920120000-a1b2c3.jpg", "/uploads/hop-dong.pdf"]


def test_next_status_after_each_payment_is_derived_from_evidence():
    assert policy.status_after_evidence(
        has_contract=True, has_app_proof=True, has_owner_proof=False
    ) == policy.DEPOSITS_PENDING
    assert policy.status_after_evidence(
        has_contract=True, has_app_proof=True, has_owner_proof=True
    ) == policy.CUSTOMER_CONFIRMATION_PENDING


def test_sale_nop_minh_chung_coc_ho_khach_nhung_khong_chot():
    """Khách gửi ảnh chuyển khoản qua Zalo → sale tải lên hộ (24/09/2026)."""
    actions = policy.available_actions(
        actor="sale",
        status=policy.CONTRACT_READY,
        has_contract=True,
        has_app_proof=False,
        has_owner_proof=False,
    )
    assert policy.SUBMIT_APP_DEPOSIT in actions
    assert policy.SUBMIT_OWNER_DEPOSIT in actions
    assert policy.CONFIRM_RENTAL not in actions


def test_sale_chua_co_hop_dong_thi_chua_nop_coc():
    actions = policy.available_actions(
        actor="sale",
        status=policy.CUSTOMER_INTERESTED,
        has_contract=False,
        has_app_proof=False,
        has_owner_proof=False,
    )
    assert policy.SUBMIT_APP_DEPOSIT not in actions
