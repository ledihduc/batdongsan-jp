"""
Rate limiter dùng slowapi — keyed by user_id khi JWT hợp lệ, fallback về IP.
Giải mã JWT không raise — lỗi decode trả về IP key (fail-open, không block).

Bộ đếm nằm ở REDIS khi có `RATE_LIMIT_REDIS_URL`, còn không thì trong bộ nhớ
tiến trình. Vì sao quan trọng: bộ đếm trong bộ nhớ MẤT SẠCH mỗi lần restart
backend, nên cái chốt chống dò mật khẩu / chiếm tài khoản được reset mỗi lần
deploy. Nó cũng đếm riêng theo từng tiến trình, nên nếu sau này chạy nhiều
uvicorn worker thì mọi giới hạn tự động nới gấp N lần.
"""

from __future__ import annotations

import logging
import os

from fastapi import Request
from jose import JWTError, jwt
from slowapi import Limiter
from slowapi.util import get_remote_address


def _key_func(request: Request) -> str:
    """
    Key function cho slowapi:
    - JWT hợp lệ → "user:{sub}" (rate limit per user_id)
    - Không có hoặc invalid JWT → IP address
    Không raise exception — lỗi decode trả về IP để tránh false-positive.
    """
    auth = request.headers.get("Authorization", "")
    if auth.lower().startswith("bearer "):
        token = auth.split(" ", 1)[1]
        try:
            from app.config import settings  # import late để tránh circular
            # decode_no_verify_exp=False → vẫn validate exp
            payload = jwt.decode(
                token,
                settings.jwt_secret,
                algorithms=["HS256"],
            )
            sub = payload.get("sub")
            if sub:
                return f"user:{sub}"
        except (JWTError, Exception):
            # Decode thất bại → fallback về IP, không block request
            pass
    return get_remote_address(request)


logger = logging.getLogger(__name__)


def _storage_uri() -> str | None:
    """URI kho đếm. None = dùng bộ nhớ tiến trình (mặc định của slowapi).

    Kiểm kết nối NGAY tại đây thay vì để slowapi phát hiện lúc có request:
    nếu Redis chết mà vẫn cấu hình trỏ vào nó, mọi request đi qua limiter sẽ
    lỗi — tức là một sự cố Redis biến thành sập API. Thà tụt về bộ nhớ và ghi
    một dòng cảnh báo.
    """
    uri = (os.environ.get("RATE_LIMIT_REDIS_URL") or "").strip()
    if not uri:
        return None
    try:
        from limits.storage import storage_from_string  # noqa: PLC0415

        kho = storage_from_string(uri)
        if kho.check():
            return uri
        logger.warning("RATE_LIMIT_REDIS_URL khong phan hoi — dung bo nho tien trinh")
    except Exception as e:
        logger.warning(
            "khong dung duoc Redis cho rate limit (%s: %s) — dung bo nho tien trinh",
            type(e).__name__,
            e,
        )
    return None


_uri = _storage_uri()
limiter = (
    Limiter(key_func=_key_func, default_limits=[], storage_uri=_uri)
    if _uri
    else Limiter(key_func=_key_func, default_limits=[])
)
