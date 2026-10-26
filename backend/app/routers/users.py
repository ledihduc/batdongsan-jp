from datetime import datetime

from fastapi import APIRouter, Body, Depends, HTTPException
from sqlalchemy.orm import Session

from app import auth, helpers, models
from app.database import get_db
from app.services import dinh_danh

router = APIRouter(prefix="/api/users", tags=["users"])


@router.get("")
def list_users(
    db: Session = Depends(get_db),
    _claims: dict = Depends(auth.require_admin),
):
    """Admin-only: liệt kê toàn bộ user (PII). KHÔNG để guest/host xem."""
    users = db.query(models.User).all()
    return {"users": [helpers.user_to_dict(u) for u in users]}


# Field user tự được sửa. KHÔNG cho client tự đổi role / id / email_verified /
# password (đổi password đã có endpoint riêng). Admin được sửa thêm role.
# `phone` KHÔNG nằm ở đây: từ mig 0097 nó là KHOÁ ĐĂNG NHẬP, phải chuẩn hoá và
# kiểm trùng như email. Gán thẳng qua `setattr` sẽ lưu số lệch chuẩn (chủ tài
# khoản mất đường đăng nhập) hoặc số trùng người khác (unique một phần ném
# IntegrityError → 500).
_SELF_EDITABLE = {"name", "avatar_path", "bio", "id_number"}


def _require_short_str(body: dict, key: str, max_len: int) -> str:
    value = str(body.get(key) or "").strip()
    if not value or len(value) > max_len:
        raise HTTPException(400, f"{key} không hợp lệ")
    return value


@router.patch("/{user_id}")
def update_user(
    user_id: int,
    body: dict = Body(...),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Chỉ chính chủ hoặc admin được sửa profile. Chặn IDOR + privilege
    escalation (client không thể tự promote thành host/admin)."""
    auth._ensure_owner_or_admin(claims, user_id)

    u = db.get(models.User, user_id)
    if not u:
        raise HTTPException(404, "Không tìm thấy user")

    is_admin = claims.get("role") == "admin"

    if "email" in body and body["email"] is not None:
        email = (body["email"] or "").strip().lower()
        # Xoá email được — miễn là còn số điện thoại để đăng nhập.
        if email == "":
            if not (u.phone or "").strip():
                raise HTTPException(400, "Cần giữ lại email hoặc số điện thoại")
            u.email = ""
        else:
            if not helpers.email_valid(email):
                raise HTTPException(400, "Email không hợp lệ")
            if (
                db.query(models.User)
                .filter(models.User.id != u.id, models.User.email == email)
                .first()
            ):
                raise HTTPException(409, "Email đã được sử dụng")
            u.email = email

    if "phone" in body and body["phone"] is not None:
        raw = str(body["phone"]).strip()
        if raw == "":
            if not (u.email or "").strip():
                raise HTTPException(400, "Cần giữ lại email hoặc số điện thoại")
            u.phone = ""
        else:
            sdt = dinh_danh.chuan_hoa_sdt(raw)
            if not sdt:
                raise HTTPException(
                    400, "Số điện thoại không hợp lệ (VD: 0912345678)"
                )
            if (
                db.query(models.User)
                .filter(models.User.id != u.id, models.User.phone == sdt)
                .first()
            ):
                raise HTTPException(409, "Số điện thoại đã được sử dụng")
            u.phone = sdt

    if "birthday" in body and body["birthday"] is not None:
        b = (body["birthday"] or "").strip()
        if b == "":
            u.birthday = None
        elif len(b) == 10 and b[4] == "-" and b[7] == "-":
            u.birthday = b
        else:
            raise HTTPException(400, "Ngày sinh không hợp lệ")

    for key in _SELF_EDITABLE:
        if key in body and body[key] is not None:
            setattr(u, key, body[key])

    # role chỉ admin được sửa — chặn guest tự upgrade thành host bằng PATCH.
    # Host onboarding flow sẽ đổi role qua endpoint riêng (host_profile).
    if "role" in body and body["role"] is not None:
        if not is_admin:
            raise HTTPException(403, "Không có quyền đổi role")
        new_role = str(body["role"]).strip()
        # Cấp/thu quyền quản trị CHỈ qua backoffice V2 (vai + lý do + maker-
        # checker + nhật ký). Một dropdown đổi thẳng thành admin là đường leo
        # thang quyền không dấu vết.
        if new_role == "admin" or (u.role == "admin" and new_role != "admin"):
            raise HTTPException(
                403,
                detail={
                    "code": "ADMIN_ROLE_VIA_BACKOFFICE",
                    "message": "Quyền quản trị chỉ được cấp/thu hồi trong trang Quản trị (mục Nhân viên).",
                },
            )
        if new_role in ("guest", "host"):
            u.role = new_role

    db.commit()
    db.refresh(u)
    return {"user": helpers.user_to_dict(u)}


@router.post("/me/push-token")
def register_push_token(
    body: dict = Body(...),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Register/update the current device FCM token for the authenticated user."""
    user_id = int(claims["sub"])
    token = _require_short_str(body, "token", 500)
    device_id = _require_short_str(body, "deviceId", 120)
    platform = str(body.get("platform") or "unknown").strip().lower()
    if platform not in {"ios", "android", "web", "unknown"}:
        platform = "unknown"

    now = datetime.utcnow()
    existing = (
        db.query(models.UserPushToken)
        .filter(
            models.UserPushToken.user_id == user_id,
            models.UserPushToken.device_id == device_id,
        )
        .first()
    )

    if existing:
        existing.token = token
        existing.platform = platform
        existing.is_active = True
        existing.updated_at = now
        existing.last_seen_at = now
        row = existing
    else:
        row = models.UserPushToken(
            user_id=user_id,
            device_id=device_id,
            token=token,
            platform=platform,
            is_active=True,
            created_at=now,
            updated_at=now,
            last_seen_at=now,
        )
        db.add(row)

    db.commit()
    return {"success": True, "id": row.id}


@router.delete("/me/push-token")
def unregister_push_token(
    body: dict = Body(...),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Deactivate this device's push token. Idempotent for logout flows."""
    user_id = int(claims["sub"])
    device_id = _require_short_str(body, "deviceId", 120)

    row = (
        db.query(models.UserPushToken)
        .filter(
            models.UserPushToken.user_id == user_id,
            models.UserPushToken.device_id == device_id,
        )
        .first()
    )
    if not row:
        return {"success": True}

    row.is_active = False
    row.updated_at = datetime.utcnow()
    db.commit()
    return {"success": True}
