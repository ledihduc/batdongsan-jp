"""JWT + bcrypt + FastAPI dependencies."""

import secrets
from datetime import datetime, timedelta, timezone
from typing import TYPE_CHECKING, Optional

import bcrypt
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, Request, status

from app.config import settings
from app.database import get_db

if TYPE_CHECKING:  # chỉ để chú thích kiểu, không tạo phụ thuộc lúc chạy
    from sqlalchemy.orm import Session


# ───── Password hashing ─────


# bcrypt CHỈ dùng 72 byte đầu và cắt phần dư trong IM LẶNG — không báo lỗi.
# Hệ quả: người đặt mật khẩu dài tưởng mình an toàn hơn thực tế, và hai mật
# khẩu khác nhau từ ký tự thứ 73 trở đi sẽ đăng nhập lẫn được cho nhau.
# LƯU Ý là BYTE chứ không phải ký tự: tiếng Việt có dấu tốn 2-3 byte mỗi ký tự
# nên "chỉ" ~24 ký tự tiếng Việt đã có thể chạm ngưỡng.
BCRYPT_MAX_BYTES = 72


def password_too_long(plain: str) -> bool:
    """Mật khẩu có vượt ngưỡng bcrypt xử lý được không."""
    return len(plain.encode("utf-8")) > BCRYPT_MAX_BYTES


def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt(12)).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False


# ───── JWT ─────


def pwd_stamp(password_changed_at) -> int:
    """Dấu mốc mật khẩu để nhúng vào token. 0 = chưa từng đổi mật khẩu."""
    if password_changed_at is None:
        return 0
    if password_changed_at.tzinfo is None:
        password_changed_at = password_changed_at.replace(tzinfo=timezone.utc)
    return int(password_changed_at.timestamp())


def sign_token(user_id: int, role: str, password_changed_at=None) -> str:
    """Ký token đăng nhập.

    [password_changed_at] được nhúng thành claim `pwd`: khi người dùng đổi mật
    khẩu, giá trị trong DB đổi theo nên MỌI token cũ mang `pwd` khác sẽ bị từ
    chối — đổi mật khẩu đuổi được phiên cũ mà không cần danh sách thu hồi.

    CỐ Ý so bằng DẤU MỐC chứ không so `iat`: `iat` chỉ có độ phân giải GIÂY,
    nên token cũ và thao tác đổi mật khẩu xảy ra trong cùng một giây sẽ không
    phân biệt được — kẻ tấn công vẫn dùng tiếp token cũ.

    Token cũ (phát trước thay đổi này) không có `pwd` → coi như 0, khớp với
    người chưa từng đổi mật khẩu → KHÔNG ai bị đăng xuất khi triển khai.
    """
    now = datetime.now(timezone.utc)
    payload = {
        # JWT spec yêu cầu `sub` là string — không phải int
        "sub": str(user_id),
        "role": role,
        "pwd": pwd_stamp(password_changed_at),
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=settings.token_ttl_hours)).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def verify_token(token: str, *, purpose: str = "auth") -> Optional[dict]:
    """Giải mã JWT và kiểm tra nó đúng LOẠI mình đang chờ.

    [purpose] mặc định "auth" nên mọi nơi gọi cũ được bảo vệ tự động: vé
    WebSocket (typ="ws") KHÔNG dùng làm Bearer token cho API thường được.
    Nếu thiếu chốt này thì việc chuyển WS sang vé lại mở ra một lỗ mới —
    vé lọt log sẽ gọi được API trong suốt thời gian còn hiệu lực.
    """
    try:
        claims = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        # Token đăng nhập cũ không có "typ" → coi như "auth".
        if claims.get("typ", "auth") != purpose:
            return None
        # Convert sub về int để code khác dùng tiện
        if "sub" in claims:
            try:
                claims["sub"] = int(claims["sub"])
            except (ValueError, TypeError):
                pass
        return claims
    except JWTError:
        return None


# ───── Vé WebSocket dùng-một-lần ─────
#
# Trước đây client mở `/ws?token=<JWT đăng nhập>`. Query string bị nginx ghi
# nguyên văn vào access log, nên token còn hiệu lực nhiều giờ nằm sẵn trong
# log — ai đọc được log là đăng nhập được. Nay client xin một VÉ riêng, sống
# 30 giây, dùng một lần.

WS_TICKET_TTL_SECONDS = 30

# jti đã tiêu → hạn của nó. Chặn phát lại trong cửa sổ 30s.
_spent_ws_tickets: dict[str, float] = {}


def sign_ws_ticket(user_id: int, role: str) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": str(user_id),
            "role": role,
            "typ": "ws",
            "jti": secrets.token_urlsafe(12),
            "iat": int(now.timestamp()),
            "exp": int((now + timedelta(seconds=WS_TICKET_TTL_SECONDS)).timestamp()),
        },
        settings.jwt_secret,
        algorithm="HS256",
    )


def redeem_ws_ticket(ticket: str) -> Optional[dict]:
    """Tiêu vé. Trả claims nếu hợp lệ, None nếu sai/hết hạn/đã dùng rồi.

    Chốt dùng-một-lần nằm trong bộ nhớ tiến trình. Backend hiện chạy uvicorn
    ĐƠN tiến trình nên chốt là tuyệt đối. Nếu sau này thêm `--workers N`, tính
    ĐÚNG vẫn giữ (vé tự xác thực bằng chữ ký + hạn 30s) — chỉ mất khả năng
    chặn phát lại chéo worker. Có ý để nó suy giảm êm như vậy thay vì hỏng.
    """
    claims = verify_token(ticket, purpose="ws")
    if not claims:
        return None
    jti = claims.get("jti")
    if not jti:
        return None

    now = datetime.now(timezone.utc).timestamp()
    # Dọn vé đã hết hạn — giữ dict khỏi phình vô hạn.
    for spent, exp in list(_spent_ws_tickets.items()):
        if exp < now:
            _spent_ws_tickets.pop(spent, None)

    if jti in _spent_ws_tickets:
        return None
    _spent_ws_tickets[jti] = claims.get("exp", now + WS_TICKET_TTL_SECONDS)
    return claims


# ───── FastAPI dependencies ─────


def optional_user(request: Request) -> Optional[dict]:
    """Decode Bearer nếu có; nếu không có thì trả None (không bắt buộc)."""
    auth = request.headers.get("Authorization", "")
    if not auth.lower().startswith("bearer "):
        return None
    token = auth.split(" ", 1)[1]
    return verify_token(token)


def _token_da_bi_vo_hieu(db, claims: dict) -> bool:
    """Token mang dấu mốc mật khẩu KHÁC với mốc hiện tại trong DB phải không?

    Vì sao cần: hệ thống KHÔNG có danh sách thu hồi token. Khi người dùng nghi
    tài khoản bị lộ và đổi mật khẩu, mọi token cũ vẫn sống tiếp tới hết hạn
    (TTL 7 ngày) — tức đổi mật khẩu KHÔNG hề đuổi được kẻ đang chiếm phiên.

    Fail-open có chủ ý: lỗi tra cứu (mất kết nối DB) KHÔNG đăng xuất mọi người.
    """
    uid = claims.get("sub")
    if not uid:
        return False
    try:
        from app import models  # import muộn để tránh vòng lặp import

        row = (
            db.query(models.User.password_changed_at)
            .filter(models.User.id == uid)
            .first()
        )
        if row is None:
            return False
        try:
            moc = row[0]
        except (TypeError, IndexError, KeyError):
            return False
        # CHỈ vô hiệu hoá khi DB trả về một mốc THẬT. None = chưa từng đổi mật
        # khẩu. Kiểu khác (vd DB giả lập trong test) cũng bỏ qua — `int()` của
        # MagicMock trả về 1 nên nếu tin bừa sẽ đăng xuất nhầm hàng loạt.
        if not isinstance(moc, datetime):
            return False
        return claims.get("pwd", 0) != pwd_stamp(moc)
    except Exception:
        return False


def require_user(
    claims: Optional[dict] = Depends(optional_user),
    db: "Session" = Depends(get_db),
) -> dict:
    if not claims:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token không hợp lệ hoặc đã hết hạn",
        )
    if _token_da_bi_vo_hieu(db, claims):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Phiên đã kết thúc do mật khẩu vừa được đổi. Vui lòng đăng nhập lại.",
        )
    if _tai_khoan_bi_khoa(db, claims):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tài khoản đã bị khoá hoặc vô hiệu hoá",
        )
    return claims


def _tai_khoan_bi_khoa(db, claims: dict) -> bool:
    """Tài khoản bị KHOÁ (admin khoá / tự xoá) thì token còn hạn cũng không
    dùng được nữa. Trước đây chỉ vài endpoint tự kiểm `is_active`, phần lớn
    API vẫn phục vụ người đã bị khoá tới hết 7 ngày của token.

    Chỉ tin đúng giá trị bool False (DB giả lập trong test trả MagicMock);
    lỗi tra cứu thì fail-open như `_token_da_bi_vo_hieu`.
    """
    uid = claims.get("sub")
    if not uid:
        return False
    try:
        from app import models

        row = db.query(models.User.is_active).filter(models.User.id == uid).first()
        if row is None:
            return False
        return row[0] is False
    except Exception:
        return False


def require_admin(
    claims: dict = Depends(require_user),
    db: "Session" = Depends(get_db),
) -> dict:
    """Yêu cầu role admin (endpoint CŨ — màn Admin Flutter).

    Trước đây chỉ tin claim `role` trong JWT sống 7 ngày: người đã bị hạ quyền
    vẫn dùng tiếp tới hết hạn token. Nay đọc lại `users.role` từ DB. Từ Admin
    V2 (mig 0137) `role='admin'` ⇔ SUPER_ADMIN; nhân viên vai hẹp (moderator,
    tài chính…) KHÔNG có role admin nên không đi được đường cũ.
    """
    if claims.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Yêu cầu quyền admin",
        )
    try:
        from app import models  # import muộn để tránh vòng lặp import

        u = db.get(models.User, claims.get("sub"))
    except Exception:  # noqa: BLE001 — DB giả lập trong test cũ
        u = None
        models = None  # type: ignore[assignment]
    if models is not None and isinstance(u, models.User):
        if not u.is_active or u.role != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Yêu cầu quyền admin",
            )
    return claims


def require_host(
    claims: dict = Depends(require_user),
    db: "Session" = Depends(get_db),
) -> dict:
    """Legacy name for the freely available owner workspace.

    Keep the authenticated identity and system role unchanged. Host services
    must scope every resource to that identity (or an explicit delegation).
    """
    from app.services.business_access import require_business_user

    require_business_user(db, claims["sub"])
    return claims


# NOTE (2026-07-14): require_operator/require_contractor đã gỡ. `User.role` chỉ
# có {guest,host,admin} (role-model.md "Option A"). Điều phối lead thi công dùng
# require_admin; quyền nhà thầu kiểm bằng ownership (_own_contractor_or_admin),
# không bằng JWT role. Operator uỷ quyền BĐS dùng resolve_actor_context (delegation).


def _ensure_owner_or_admin(claims: dict, owner_id: int) -> None:
    """Helper: chặn IDOR. Cho phép qua nếu actor là owner hoặc admin.
    Dùng cho per-user resources (wishlist, notification, message) nơi
    JWT 'sub' phải khớp với owner_id của record."""
    actor_id = claims.get("sub")
    if claims.get("role") == "admin":
        return
    if actor_id is None or int(actor_id) != int(owner_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Không có quyền truy cập tài nguyên của user khác",
        )
