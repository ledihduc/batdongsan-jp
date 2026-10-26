"""Login contexts derived from the same capabilities as the Activity hub."""

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import helpers, models
from app.services.manage_read_model import available_modes


def available_login_account_types(db: Session, user: models.User) -> list[str]:
    if not user.is_active:
        return []
    modes = available_modes(db, user)
    if user.role == "admin":
        modes.append("admin")
    return modes


def login_user_dict(db: Session, user: models.User) -> dict:
    """Self-only payload; do not add capabilities to public profile responses."""
    return {
        **helpers.user_to_dict(user),
        "login_account_types": available_login_account_types(db, user),
    }


def require_login_account_type(selected: str | None, allowed: list[str]) -> None:
    if selected is not None and selected not in allowed:
        raise HTTPException(
            403,
            "Tài khoản chưa có quyền đăng nhập với loại tài khoản đã chọn. "
            "Vui lòng chọn lại loại tài khoản hoặc liên hệ quản trị viên.",
        )
