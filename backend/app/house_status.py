"""Hằng số trạng thái tin đăng (House.status) — 1 nguồn sự thật.

Tránh drift literal đã gây bug ('approved' vs 'published' làm tin biến mất khỏi
public; query_nearby default 'approved' làm /search-nearby trả rỗng). Dùng ở
routers/houses, admin_houses, services/house_search_service.
"""


class HouseStatus:
    PUBLISHED = "published"            # công khai, hiển thị
    PENDING_REVIEW = "pending_review"  # chờ admin duyệt (sale >= ngưỡng giá)
    REJECTED = "rejected"              # admin từ chối
    HIDDEN = "hidden"                  # admin ẩn

    # Trạng thái công khai duy nhất (alias ngữ nghĩa).
    PUBLIC = PUBLISHED

    # Legacy — chỉ để map tương thích client cũ, KHÔNG set cho tin mới.
    APPROVED_LEGACY = "approved"
    PENDING_LEGACY = "pending"
