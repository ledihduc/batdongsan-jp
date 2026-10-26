"""Sở thích người dùng (khảo sát phân loại — redesign v2 P1).

  GET /api/me/preferences  — đọc prefs (mặc định rỗng nếu chưa có).
  PUT /api/me/preferences  — upsert; `merge=true` → hợp nhất (union) list với prefs
                             hiện có (dùng khi đồng bộ prefs khách → tài khoản lúc login).

KHÔNG dùng `from __future__ import annotations` (pydantic body).
"""

from fastapi import APIRouter, Body, Depends
from sqlalchemy.orm import Session

from app import auth, models
from app.database import get_db

router = APIRouter(prefix="/api/me", tags=["preferences"])

_VALID_WORLDS = {"realestate", "construction"}


def _prefs_dict(p) -> dict:
    return {
        "interests": (p.interests or []) if p else [],
        "provinces": (p.provinces or []) if p else [],
        "service_slugs": (p.service_slugs or []) if p else [],
        "default_world": (p.default_world if p else "realestate"),
    }


@router.get("/preferences")
def get_preferences(
    db: Session = Depends(get_db), claims: dict = Depends(auth.require_user)
):
    p = (
        db.query(models.UserPreferences)
        .filter(models.UserPreferences.user_id == int(claims["sub"]))
        .first()
    )
    return {"preferences": _prefs_dict(p)}


def _union(a, b):
    out = list(a or [])
    for x in (b or []):
        if x not in out:
            out.append(x)
    return out


@router.put("/preferences")
def put_preferences(
    body: dict = Body(...),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    uid = int(claims["sub"])
    merge = bool(body.get("merge"))
    interests = [str(x) for x in (body.get("interests") or [])][:20]
    provinces = [str(x) for x in (body.get("provinces") or [])][:20]
    service_slugs = [str(x) for x in (body.get("service_slugs") or [])][:10]
    world = body.get("default_world")
    if world not in _VALID_WORLDS:
        world = None  # giữ nguyên/để mặc định

    p = (
        db.query(models.UserPreferences)
        .filter(models.UserPreferences.user_id == uid)
        .first()
    )
    if p is None:
        p = models.UserPreferences(
            user_id=uid,
            interests=interests,
            provinces=provinces,
            service_slugs=service_slugs,
            default_world=world or "realestate",
        )
        db.add(p)
    else:
        if merge:
            p.interests = _union(p.interests, interests)
            p.provinces = _union(p.provinces, provinces)
            p.service_slugs = _union(p.service_slugs, service_slugs)
            if world:
                p.default_world = world
        else:
            p.interests = interests
            p.provinces = provinces
            p.service_slugs = service_slugs
            if world:
                p.default_world = world
        p.updated_at = models.now_utc()
    db.commit()
    db.refresh(p)
    return {"preferences": _prefs_dict(p)}
