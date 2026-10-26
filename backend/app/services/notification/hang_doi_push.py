"""Hàng đợi push — xếp hàng trong giao dịch, gửi ở ngoài.

Xem docstring `models.PushOutbox` cho lý do dùng mẫu outbox. Tệp này chỉ có hai
việc: **xếp hàng** (an toàn để gọi giữa transaction nghiệp vụ) và **rút hàng**
(gọi từ tiến trình gửi, không bao giờ nằm trong đường xử lý request nghiệp vụ).
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import models

#: Thử lại tối đa bao nhiêu lần trước khi bỏ. Một thiết bị gỡ app rồi thì token
#: hỏng vĩnh viễn — thử mãi là đốt hạn mức cho một người không còn ở đó.
SO_LAN_TOI_DA = 5


def xep_hang(
    db: Session,
    *,
    user_id: Optional[int],
    title: str,
    body: str,
    loai: str,
    khoa_gom: str,
    related_id: Optional[int] = None,
) -> bool:
    """Xếp một push vào hàng đợi. Trả True nếu thật sự thêm mới.

    KHÔNG commit — người gọi đang ở giữa một giao dịch nghiệp vụ, và đó chính
    là điểm của mẫu này: hai thứ cùng sống hoặc cùng chết.

    Trùng `(user_id, khoa_gom)` khi còn CHỜ GỬI thì bỏ qua: một người bị đóng
    ba tin trong cùng một hành động chỉ nhận MỘT push.
    """
    if not user_id:
        return False

    # Kiểm ở tầng ứng dụng cho SQLite (không có unique một phần) và để tránh
    # ném IntegrityError làm hỏng transaction đang mở của người gọi.
    da_co = (
        db.query(models.PushOutbox.id)
        .filter(
            models.PushOutbox.user_id == user_id,
            models.PushOutbox.khoa_gom == khoa_gom,
            models.PushOutbox.gui_luc.is_(None),
        )
        .first()
    )
    if da_co:
        return False

    db.add(
        models.PushOutbox(
            user_id=user_id,
            title=title[:200],
            body=body,
            loai=loai,
            khoa_gom=khoa_gom[:100],
            related_id=related_id,
        )
    )
    try:
        db.flush()
    except IntegrityError:
        # Đua nhau: hai tiến trình cùng xếp hàng cho một người. Unique một phần
        # chặn bản sau — đúng ý, và không được để nó thành lỗi nghiệp vụ.
        db.rollback()
        return False
    return True


def cho_gui(db: Session, gioi_han: int = 100) -> list[models.PushOutbox]:
    """Các mục còn chờ, cũ trước. Đã thử quá số lần thì thôi."""
    return (
        db.query(models.PushOutbox)
        .filter(
            models.PushOutbox.gui_luc.is_(None),
            models.PushOutbox.so_lan_thu < SO_LAN_TOI_DA,
        )
        .order_by(models.PushOutbox.tao_luc)
        .limit(gioi_han)
        .all()
    )


def danh_dau_da_gui(db: Session, muc: models.PushOutbox) -> None:
    muc.gui_luc = datetime.utcnow()
    muc.loi_cuoi = None


def danh_dau_hong(db: Session, muc: models.PushOutbox, loi: str) -> None:
    """Gửi hỏng → giữ lại để thử lần sau. KHÔNG xoá.

    Xoá là mất luôn thông tin "người này lẽ ra phải được báo" — và đó thường là
    thứ duy nhất giải thích được vì sao khách không biết tin.
    """
    muc.so_lan_thu = (muc.so_lan_thu or 0) + 1
    muc.loi_cuoi = str(loi)[:300]
