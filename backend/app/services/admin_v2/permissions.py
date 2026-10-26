"""Danh mục quyền + vai quản trị — NGUỒN SỰ THẬT (bảng DB chỉ là bản đồng bộ).

Quyền nhỏ theo HÀNH ĐỘNG, không theo màn: một màn có thể cần `*.read` để xem
và quyền khác để bấm nút. Thêm quyền mới: thêm vào PERMISSIONS + gán vào vai,
`ensure_catalog()` tự chèn khi khởi động (không cần migration).
"""

from __future__ import annotations

# code → (module, mô tả)
PERMISSIONS: dict[str, tuple[str, str]] = {
    # Tổng quan / công việc
    "dashboard.read": ("overview", "Xem tổng quan vận hành"),
    "work_items.read": ("overview", "Xem hộp việc cần xử lý"),
    "work_items.assign": ("overview", "Phân công, đổi ưu tiên, ghi chú việc"),
    # Người dùng
    "users.read": ("users", "Tra cứu người dùng: SĐT, nơi ở & tình trạng thuê (email/CCCD che)"),
    "users.reveal_pii": ("users", "Xem PII đầy đủ (bắt buộc lý do, có nhật ký)"),
    "users.suspend": ("users", "Khoá / mở khoá tài khoản, thu hồi phiên"),
    "users.manage_admin_roles": ("users", "Quản lý nhân viên và vai quản trị"),
    # Nội dung
    "listings.read": ("content", "Xem tin đăng"),
    "listings.moderate": ("content", "Duyệt / từ chối / gỡ tin"),
    "listings.mark_trusted": ("content", "Gắn / gỡ nhãn tin cậy"),
    "content.read": ("content", "Xem báo cáo nội dung, Reel, review"),
    "content.moderate": ("content", "Xử lý báo cáo, duyệt / ẩn Reel"),
    "verification.review": ("content", "Thẩm định sao chất lượng"),
    # Giao dịch thuê
    "rental_journeys.read": ("rentals", "Xem lịch xem, hành trình thuê, booking, hợp đồng"),
    "rental_journeys.override": ("rentals", "Lệnh ngoại lệ trên hành trình / booking"),
    "rental_documents.read": ("rentals", "Mở chứng từ thuê (hợp đồng, ảnh cọc)"),
    # Tài chính
    "payments.read": ("finance", "Xem sổ tiền, hoá đơn, hoa hồng, đối soát"),
    "payments.record": ("finance", "Ghi nhận thanh toán"),
    "payments.refund": ("finance", "Ghi nhận hoàn tiền"),
    "payments.reconcile": ("finance", "Đánh dấu đã đối soát / xác minh cọc"),
    "policies.manage": ("finance", "Thay chính sách cọc"),
    # Đối tác
    "partners.read": ("partners", "Xem Sale, nhà thầu, lead, yêu cầu dịch vụ"),
    "partners.review": ("partners", "Duyệt hồ sơ Sale / nhà thầu, xử lý lead"),
    # Tin cậy & pháp lý
    "kyc.review": ("compliance", "Duyệt KYC doanh nghiệp"),
    "compliance.read": ("compliance", "Xem uỷ quyền, tranh chấp, hồ sơ pháp lý"),
    "disputes.manage": ("compliance", "Xử lý tranh chấp, chủ sở hữu mất"),
    "delegations.force_revoke": ("compliance", "Thu hồi cưỡng bức uỷ quyền, đình chỉ operator"),
    "retention.manage": ("compliance", "Chạy retention / archive, legal hold"),
    # Hệ thống
    "audit.read": ("system", "Xem nhật ký quản trị hợp nhất"),
    "system.read": ("system", "Xem sức khoẻ hệ thống, push, job, cờ"),
    "settings.manage": ("system", "Danh mục, cấu hình tỉnh / quy hoạch"),
}

_ALL = tuple(PERMISSIONS)
_READ_CORE = ("dashboard.read", "work_items.read")

# code → (tên, mô tả, quyền)
ROLES: dict[str, tuple[str, str, tuple[str, ...]]] = {
    "SUPER_ADMIN": ("Quản trị cấp cao", "Mọi module, quản trị nhân viên & cấu hình nhạy cảm", _ALL),
    "OPS_ADMIN": (
        "Vận hành",
        "Lịch xem, hành trình thuê, booking, hợp đồng",
        _READ_CORE + (
            "work_items.assign", "users.read", "listings.read",
            "rental_journeys.read", "rental_journeys.override", "rental_documents.read",
            "partners.read", "payments.read",
        ),
    ),
    "MODERATOR": (
        "Kiểm duyệt nội dung",
        "Tin đăng, bài viết, Reel, review, báo cáo nội dung",
        _READ_CORE + (
            "work_items.assign", "users.read", "listings.read", "listings.moderate",
            "listings.mark_trusted", "content.read", "content.moderate", "verification.review",
        ),
    ),
    "SUPPORT": (
        "Hỗ trợ khách hàng",
        "Tra cứu người dùng (SĐT, nơi đang thuê), đơn thuê, case hỗ trợ; email/CCCD che",
        _READ_CORE + (
            "work_items.assign", "users.read", "listings.read", "rental_journeys.read",
            "partners.read",
        ),
    ),
    "FINANCE": (
        "Tài chính",
        "Cọc, hoá đơn, ghi nhận thanh toán / hoàn tiền, hoa hồng, đối soát",
        _READ_CORE + (
            "work_items.assign", "users.read", "rental_journeys.read", "rental_documents.read",
            "payments.read", "payments.record", "payments.refund", "payments.reconcile",
            "policies.manage",
        ),
    ),
    "COMPLIANCE": (
        "Tuân thủ & pháp lý",
        "KYC, tranh chấp, uỷ quyền, hồ sơ pháp lý, retention",
        _READ_CORE + (
            "work_items.assign", "users.read", "users.reveal_pii", "users.suspend",
            "kyc.review", "compliance.read", "disputes.manage", "delegations.force_revoke",
            "retention.manage", "rental_documents.read", "partners.read", "partners.review",
            "audit.read",
        ),
    ),
    "ANALYST": (
        "Phân tích",
        "Chỉ đọc tổng quan và báo cáo tổng hợp",
        ("dashboard.read",),
    ),
    "AUDITOR": (
        "Kiểm toán",
        "Chỉ đọc nhật ký quản trị, không sửa dữ liệu",
        ("dashboard.read", "audit.read"),
    ),
}

ROLE_CODES = tuple(ROLES)

# Vai chỉ được cấp qua maker-checker (một người khác phải duyệt).
MAKER_CHECKER_ROLES = frozenset({"SUPER_ADMIN"})

# Ngưỡng hoàn tiền phải có người thứ hai duyệt (VND).
REFUND_DUAL_APPROVAL_THRESHOLD = 5_000_000

# Thao tác cực nhạy: phiên admin phải xác thực lại trong cửa sổ này (giây).
REAUTH_WINDOW_SECONDS = 600


def permissions_for_roles(role_codes) -> set[str]:
    out: set[str] = set()
    for code in role_codes:
        spec = ROLES.get(code)
        if spec:
            out.update(spec[2])
    return out
