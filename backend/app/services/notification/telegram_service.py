"""Báo tin cho admin qua Telegram.

Vì sao Telegram chứ không phải thông báo trong app: yêu cầu dịch vụ chỉ có giá
trị nếu được gọi lại trong vài phút. Thông báo in-app nằm im cho tới khi admin
mở app — mà admin ở đây là một người, không ngồi trong app cả ngày. SMS thì
provider (`notification_sms_provider`) đang là `"stub"` và eSMS cần đăng ký
brand DLT mới gửi được, tức là hôm nay gửi đi không tới đâu cả.

Telegram: miễn phí, tới thẳng điện thoại, cấu hình bằng 2 biến môi trường.

Không cấu hình gì thì hàm ở đây lặng lẽ không làm gì — tính năng đặt dịch vụ
vẫn chạy đủ, chỉ mất lớp báo tin. Và mọi lỗi mạng đều bị nuốt: khách đã bấm gửi
xong rồi, không có lý do gì để họ thấy lỗi 500 chỉ vì Telegram trục trặc.
"""

from __future__ import annotations

import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

_TIMEOUT_S = 5.0


def da_cau_hinh() -> bool:
    return bool(
        getattr(settings, "telegram_bot_token", "")
        and getattr(settings, "telegram_admin_chat_id", "")
    )


def gui_admin(text: str) -> bool:
    """Gửi một tin nhắn cho admin. Trả True nếu Telegram nhận.

    KHÔNG raise trong mọi trường hợp — phía gọi là đường xử lý request của
    khách.
    """
    if not da_cau_hinh():
        return False
    try:
        r = httpx.post(
            f"https://api.telegram.org/bot{settings.telegram_bot_token}/sendMessage",
            json={
                "chat_id": settings.telegram_admin_chat_id,
                "text": text[:4000],
                "disable_web_page_preview": True,
            },
            timeout=_TIMEOUT_S,
        )
        if r.status_code >= 400:
            # KHÔNG log body: phản hồi lỗi của Telegram có lặp lại URL kèm token.
            logger.warning("telegram gửi thất bại: HTTP %s", r.status_code)
            return False
        return True
    except Exception as e:  # noqa: BLE001 — đường báo tin không được phép chết
        logger.warning("telegram lỗi: %s", type(e).__name__)
        return False
