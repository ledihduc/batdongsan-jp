"""Đồng bộ danh mục quyền vào DB + tra quyền thật của một nhân viên."""

from __future__ import annotations

import logging
from datetime import datetime

from sqlalchemy.orm import Session

from app import models
from app.services.admin_v2.permissions import PERMISSIONS, ROLES

logger = logging.getLogger(__name__)


def ensure_catalog(db: Session) -> None:
    """Đưa bảng quyền/vai về ĐÚNG như code (thêm thiếu, gỡ thừa). Idempotent.

    Gỡ thừa là cố ý: bỏ một quyền khỏi vai trong code thì nhân viên phải mất
    quyền đó ngay, không được sống tiếp nhờ bản DB cũ.
    """
    have_perm = {p.code: p for p in db.query(models.AdminPermission).all()}
    for code, (module, desc) in PERMISSIONS.items():
        row = have_perm.get(code)
        if row is None:
            db.add(models.AdminPermission(code=code, module=module, description=desc))
        elif row.module != module or row.description != desc:
            row.module, row.description = module, desc
    have_role = {r.code: r for r in db.query(models.AdminRole).all()}
    for code, (name, desc, _perms) in ROLES.items():
        row = have_role.get(code)
        if row is None:
            db.add(models.AdminRole(code=code, name=name, description=desc))
        elif row.name != name or row.description != desc:
            row.name, row.description = name, desc
    db.flush()

    current = {
        (rp.role_code, rp.permission_code)
        for rp in db.query(models.AdminRolePermission).all()
    }
    wanted = {(code, p) for code, spec in ROLES.items() for p in spec[2]}
    for role_code, perm in wanted - current:
        db.add(models.AdminRolePermission(role_code=role_code, permission_code=perm))
    for role_code, perm in current - wanted:
        if role_code in ROLES:
            db.query(models.AdminRolePermission).filter_by(
                role_code=role_code, permission_code=perm
            ).delete()
    db.flush()


def active_roles(db: Session, user_id: int) -> list[str]:
    rows = (
        db.query(models.AdminUserRole.role_code)
        .filter(
            models.AdminUserRole.user_id == user_id,
            models.AdminUserRole.revoked_at.is_(None),
        )
        .all()
    )
    return sorted({r[0] for r in rows})


def permissions_of(db: Session, user_id: int) -> set[str]:
    """Quyền đọc từ DB (bảng vai ↔ quyền), không tin claim trong token."""
    rows = (
        db.query(models.AdminRolePermission.permission_code)
        .join(
            models.AdminUserRole,
            models.AdminUserRole.role_code == models.AdminRolePermission.role_code,
        )
        .filter(
            models.AdminUserRole.user_id == user_id,
            models.AdminUserRole.revoked_at.is_(None),
        )
        .all()
    )
    return {r[0] for r in rows}


def grant_role(db: Session, *, user_id: int, role_code: str, granted_by: int | None, reason: str) -> models.AdminUserRole:
    existing = (
        db.query(models.AdminUserRole)
        .filter_by(user_id=user_id, role_code=role_code, revoked_at=None)
        .first()
    )
    if existing:
        return existing
    row = models.AdminUserRole(
        user_id=user_id, role_code=role_code, granted_by=granted_by,
        granted_at=datetime.utcnow(), grant_reason=reason[:500],
    )
    db.add(row)
    db.flush()
    _sync_legacy_role(db, user_id)
    return row


def revoke_role(db: Session, *, user_id: int, role_code: str, revoked_by: int, reason: str) -> bool:
    row = (
        db.query(models.AdminUserRole)
        .filter_by(user_id=user_id, role_code=role_code, revoked_at=None)
        .first()
    )
    if row is None:
        return False
    row.revoked_at = datetime.utcnow()
    row.revoked_by = revoked_by
    row.revoke_reason = reason[:500]
    db.flush()
    _sync_legacy_role(db, user_id)
    return True


def _sync_legacy_role(db: Session, user_id: int) -> None:
    """`users.role='admin'` ⇔ có SUPER_ADMIN đang hiệu lực.

    Giữ màn Admin Flutter (dùng endpoint cũ require_admin) làm lối tắt khẩn cho
    đúng nhóm toàn quyền. Nhân viên vai hẹp KHÔNG được role admin cũ — nếu được
    thì moderator gọi thẳng URL tài chính kiểu cũ là qua.
    """
    user = db.get(models.User, user_id)
    if user is None:
        return
    is_super = "SUPER_ADMIN" in active_roles(db, user_id)
    if is_super and user.role != "admin":
        user.role = "admin"
    elif not is_super and user.role == "admin":
        user.role = "guest"
    db.flush()
