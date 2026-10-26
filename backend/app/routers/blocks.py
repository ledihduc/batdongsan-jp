"""Chặn người dùng (Apple Guideline 1.2 — UGC).

- POST   /api/social/blocks/{user_id}  — chặn (idempotent)
- DELETE /api/social/blocks/{user_id}  — bỏ chặn
- GET    /api/social/blocks            — danh sách người đã chặn (id + tên)

Helper `blocked_ids(db, viewer_id)` được social/reels import để LỌC nội dung của
người bị chặn khỏi feed/bình luận. Quan hệ một chiều: chặn ai thì không thấy nội
dung của người đó nữa.
"""

from __future__ import annotations

from typing import Optional, Set

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import auth, models
from app.database import get_db

router = APIRouter(prefix="/api/social/blocks", tags=["blocks"])


def blocked_ids(db: Session, viewer_id: Optional[int]) -> Set[int]:
    """Tập user_id mà `viewer_id` đã chặn. Rỗng nếu chưa đăng nhập."""
    if not viewer_id:
        return set()
    rows = (
        db.query(models.UserBlock.blocked_id)
        .filter(models.UserBlock.blocker_id == viewer_id)
        .all()
    )
    return {r[0] for r in rows}


@router.post("/{user_id}", status_code=201)
def block_user(
    user_id: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    me = int(claims["sub"])
    if user_id == me:
        raise HTTPException(400, "Không thể tự chặn chính mình")
    target = db.get(models.User, user_id)
    if not target:
        raise HTTPException(404, "Không tìm thấy người dùng")
    exists = (
        db.query(models.UserBlock)
        .filter(
            models.UserBlock.blocker_id == me,
            models.UserBlock.blocked_id == user_id,
        )
        .first()
    )
    if not exists:
        db.add(models.UserBlock(blocker_id=me, blocked_id=user_id))
        db.commit()
    return {"blocked": True}


@router.delete("/{user_id}")
def unblock_user(
    user_id: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    me = int(claims["sub"])
    row = (
        db.query(models.UserBlock)
        .filter(
            models.UserBlock.blocker_id == me,
            models.UserBlock.blocked_id == user_id,
        )
        .first()
    )
    if row:
        db.delete(row)
        db.commit()
    return {"blocked": False}


@router.get("")
def list_blocks(
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    me = int(claims["sub"])
    rows = (
        db.query(models.UserBlock)
        .filter(models.UserBlock.blocker_id == me)
        .order_by(models.UserBlock.created_at.desc())
        .all()
    )
    out = []
    for r in rows:
        u = db.get(models.User, r.blocked_id)
        out.append(
            {
                "user_id": r.blocked_id,
                "name": (u.name if u else "Người dùng"),
                "avatar_path": (u.avatar_path if u else ""),
            }
        )
    return {"blocked": out}
