"""Nội dung — tin đăng, báo cáo nội dung, Reel, thẩm định sao, đánh giá.

Thay các màn admin cũ (`/api/admin/houses`, `/api/reports/queue`,
`/api/reels/moderation/queue`, `/api/verification/queue`) — vốn tải tối đa vài
trăm dòng không phân trang và không có nhật ký — bằng danh sách phân trang ở
server + lệnh tường minh qua `run_command`. Endpoint cũ GIỮ NGUYÊN cho Flutter;
logic đổi trạng thái dùng chung ở `services/admin_v2/content_ops.py`.
"""

from __future__ import annotations

import json
from datetime import timedelta
from typing import Any, Literal, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from app import helpers, models
from app.database import get_db
from app.house_status import HouseStatus
from app.services.admin_v2 import content_ops
from app.services.admin_v2.content_ops import OpsError
from app.services.admin_v2.core import (
    AdminContext, CommandResult, PageParams, etag, fail, idempotency_key, if_match, iso, one,
    page_params, paged, paginate, require_any_permission, require_permission, run_command,
    user_brief, utcnow,
)

router = APIRouter(prefix="/api/v2/admin", tags=["admin-v2-content"])

LISTING_STATUSES = ("pending_review", "published", "rejected", "hidden", "deleted", "pending", "approved")
REPORT_TARGETS = ("house", "post", "comment")
# Bán kính "cùng vị trí" ~30m: 0.0003° vĩ độ ≈ 33m. Hộp vuông đủ cho gợi ý trùng.
_DUP_DEG = 0.0003
_DUP_LIMIT = 10
_TIMELINE_LIMIT = 60


def _ops_fail(exc: OpsError):
    return fail(exc.status, exc.code if exc.code.startswith("ADMIN_") else f"ADMIN_{exc.code}", exc.message)


def _like(term: str) -> str:
    esc = term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{esc.lower()}%"


# ══ Tin đăng ═════════════════════════════════════════════════════════════════


def _listing_version(h: models.House) -> str:
    # Gồm cả nội dung: chủ tin sửa tin giữa lúc đang duyệt → lệnh duyệt cũ bị 409.
    return etag(
        h.id, h.status, h.rejection_reason, bool(h.is_trusted), h.title, h.price, h.area,
        h.address, h.description, h.images, h.latitude, h.longitude,
    )


def _cover(h: models.House) -> Optional[str]:
    imgs = h.images or []
    return helpers._rel_upload_url(imgs[0]) if imgs else None


def _categories(db: Session, ids) -> dict[int, str]:
    ids = {i for i in ids if i is not None}
    if not ids:
        return {}
    return {c.id: c.name for c in db.query(models.Category).filter(models.Category.id.in_(ids)).all()}


def _open_report_counts(db: Session, target_type: str, ids: list[int]) -> dict[int, int]:
    if not ids:
        return {}
    R = models.ContentReport
    rows = (
        db.query(R.target_id, func.count(R.id))
        .filter(R.target_type == target_type, R.target_id.in_(ids), R.status == "pending", R.kind == "violation")
        .group_by(R.target_id)
        .all()
    )
    return {tid: int(n) for tid, n in rows}


def _listing_row(h: models.House, *, cats: dict, cache: dict, db: Session, open_reports: int = 0) -> dict:
    return {
        "id": h.id,
        "ref": f"TIN-{h.id:05d}",
        "title": h.title,
        "status": h.status,
        "rejection_reason": h.rejection_reason,
        "price": h.price,
        "area": h.area,
        "address": h.address,
        "city": h.city,
        "district": h.district,
        "province_code": h.province_code,
        "category": {"id": h.category_id, "name": cats.get(h.category_id)},
        "transaction_type": h.transaction_type,
        "product_type": h.product_type,
        "is_trusted": bool(h.is_trusted),
        "cover_image": _cover(h),
        "image_count": len(h.images or []),
        "host": user_brief(db, h.host_id, cache),
        "open_reports": open_reports,
        "created_at": iso(h.created_at),
        "version": _listing_version(h),
    }


@router.get("/listings")
def list_listings(
    status: str = Query("pending_review", max_length=20),
    q: str = Query("", max_length=200),
    province: str = Query("", max_length=32),
    city: str = Query("", max_length=100),
    category_id: Optional[int] = None,
    is_trusted: Optional[bool] = None,
    host_id: Optional[int] = None,
    transaction_type: str = Query("", pattern="^(|rent|sale)$"),
    sort: str = Query("newest", pattern="^(newest|oldest)$"),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("listings.read")),
    db: Session = Depends(get_db),
):
    H = models.House
    query = db.query(H)
    if status != "all":
        if status not in LISTING_STATUSES:
            raise fail(422, "ADMIN_BAD_FILTER", "Trạng thái tin không hợp lệ")
        query = query.filter(H.status == status)
    term = q.strip()
    if term:
        conds = [func.lower(H.title).like(_like(term), escape="\\")]
        digits = term.upper().removeprefix("TIN-")
        if digits.isdigit():
            conds.append(H.id == int(digits))
        query = query.filter(or_(*conds))
    if province:
        query = query.filter(H.province_code == province)
    if city.strip():
        query = query.filter(func.lower(H.city).like(_like(city.strip()), escape="\\"))
    if category_id is not None:
        query = query.filter(H.category_id == category_id)
    if is_trusted is not None:
        query = query.filter(H.is_trusted == is_trusted)
    if host_id is not None:
        query = query.filter(H.host_id == host_id)
    if transaction_type:
        query = query.filter(H.transaction_type == transaction_type)
    order = (H.created_at.desc(), H.id.desc()) if sort == "newest" else (H.created_at.asc(), H.id.asc())
    rows, total = paginate(query.order_by(*order), page)
    cats = _categories(db, [h.category_id for h in rows])
    reports = _open_report_counts(db, "house", [h.id for h in rows])
    cache: dict = {}
    data = [_listing_row(h, cats=cats, cache=cache, db=db, open_reports=reports.get(h.id, 0)) for h in rows]
    return paged(data, total=total, page=page)


def _load_listing(db: Session, house_id: int) -> models.House:
    h = db.get(models.House, house_id)
    if h is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy tin đăng")
    return h


def _count(db: Session, model, *conds) -> int:
    return int(db.query(func.count()).select_from(model).filter(*conds).scalar() or 0)


def _owner_card(db: Session, h: models.House, cache: dict) -> dict:
    H, R = models.House, models.ContentReport
    host_houses = db.query(H.id).filter(H.host_id == h.host_id)
    against_content = and_(R.target_type == "house", R.target_id.in_(host_houses))
    prof = db.query(models.HostProfile).filter_by(user_id=h.host_id).first()
    sale = db.query(models.SaleProfile).filter_by(user_id=h.host_id).first()
    owner = db.get(models.User, h.host_id)
    return {
        "user": user_brief(db, h.host_id, cache),
        "account_type": getattr(owner, "account_type", None) if owner else None,
        "joined_at": iso(owner.created_at) if owner else None,
        "host_profile": None if prof is None else {
            "verified": bool(prof.verified), "rating": prof.rating, "review_count": prof.review_count or 0,
        },
        "sale_profile": None if sale is None else {
            "sale_code": sale.sale_code, "verified": bool(sale.verified), "trusted": bool(sale.trusted),
        },
        "listings_total": _count(db, H, H.host_id == h.host_id),
        "listings_published": _count(db, H, H.host_id == h.host_id, H.status == HouseStatus.PUBLISHED),
        "violations": {
            "rejected_listings": _count(db, H, H.host_id == h.host_id, H.status == HouseStatus.REJECTED),
            "hidden_listings": _count(db, H, H.host_id == h.host_id, H.status == HouseStatus.HIDDEN),
            "content_reports_against": _count(db, R, R.kind == "violation", against_content),
            "content_reports_upheld": _count(db, R, R.kind == "violation", R.status == "reviewed", against_content),
            "journey_reports_against": _count(
                db, models.RentalJourneyReport, models.RentalJourneyReport.reported_user_id == h.host_id),
        },
    }


def _duplicates(db: Session, h: models.House, cats: dict, cache: dict) -> list[dict]:
    """Gợi ý tin trùng — đơn giản và có giới hạn: cùng chủ + tiêu đề gần giống,
    cùng địa chỉ + giá, hoặc cùng toạ độ trong ~30m."""
    H = models.House
    conds = []
    title = (h.title or "").strip()
    if title:
        conds.append(and_(H.host_id == h.host_id, func.lower(H.title).like(
            _like(title[:24]).lstrip("%"), escape="\\")))
    addr = (h.address or "").strip()
    if addr and h.price:
        conds.append(and_(func.lower(H.address) == addr.lower(), H.price == h.price))
    if h.latitude is not None and h.longitude is not None:
        conds.append(and_(
            H.latitude.between(h.latitude - _DUP_DEG, h.latitude + _DUP_DEG),
            H.longitude.between(h.longitude - _DUP_DEG, h.longitude + _DUP_DEG),
        ))
    if not conds:
        return []
    rows = (
        db.query(H).filter(H.id != h.id, H.status != "deleted", or_(*conds))
        .order_by(H.created_at.desc()).limit(_DUP_LIMIT).all()
    )
    out = []
    for d in rows:
        why = []
        if d.host_id == h.host_id and title and (d.title or "").lower().startswith(title[:24].lower()):
            why.append("same_host_similar_title")
        if addr and (d.address or "").strip().lower() == addr.lower() and d.price == h.price:
            why.append("same_address_price")
        if (h.latitude is not None and d.latitude is not None and d.longitude is not None
                and abs(d.latitude - h.latitude) <= _DUP_DEG and abs(d.longitude - h.longitude) <= _DUP_DEG):
            why.append("same_location")
        out.append({
            "id": d.id, "title": d.title, "status": d.status, "price": d.price, "address": d.address,
            "cover_image": _cover(d), "host": user_brief(db, d.host_id, cache),
            "created_at": iso(d.created_at), "match": why,
        })
    return out


def _quality(h: models.House) -> list[dict]:
    desc_len = len((h.description or "").strip())
    n_img = len(h.images or [])
    return [
        {"code": "images", "label": "Có ít nhất 3 ảnh", "ok": n_img >= 3, "detail": f"{n_img} ảnh"},
        {"code": "coordinates", "label": "Có toạ độ bản đồ", "ok": h.latitude is not None and h.longitude is not None,
         "detail": None},
        {"code": "description", "label": "Mô tả từ 50 ký tự", "ok": desc_len >= 50, "detail": f"{desc_len} ký tự"},
        {"code": "price", "label": "Giá lớn hơn 0", "ok": (h.price or 0) > 0, "detail": None},
        {"code": "area", "label": "Diện tích lớn hơn 0", "ok": (h.area or 0) > 0, "detail": None},
        {"code": "address", "label": "Có địa chỉ", "ok": bool((h.address or "").strip()), "detail": None},
        {"code": "province", "label": "Đã chuẩn hoá tỉnh/thành", "ok": bool(h.province_code), "detail": h.province_code},
        {"code": "title", "label": "Tiêu đề từ 10 ký tự", "ok": len((h.title or "").strip()) >= 10, "detail": None},
    ]


def _report_row(db: Session, r: models.ContentReport, cache: dict) -> dict:
    return {
        "id": r.id, "target_type": r.target_type, "target_id": r.target_id, "kind": r.kind,
        "reason": r.reason, "detail": r.detail or "", "status": r.status,
        "reporter": user_brief(db, r.reporter_id, cache),
        "reviewed_by": user_brief(db, r.reviewed_by, cache), "reviewed_at": iso(r.reviewed_at),
        "created_at": iso(r.created_at),
    }


def _log_entry(db: Session, row: models.AdminActionLog, cache: dict) -> dict:
    return {
        "source": "admin_v2", "action": row.action, "actor": user_brief(db, row.actor_user_id, cache),
        "reason": row.reason, "before": row.before_json, "after": row.after_json, "at": iso(row.created_at),
    }


def _listing_timeline(db: Session, h: models.House, cache: dict) -> list[dict]:
    L = models.AdminActionLog
    out: list[dict] = [
        _log_entry(db, row, cache)
        for row in db.query(L).filter(L.entity_type == "listing", L.entity_id == str(h.id))
        .order_by(L.id.desc()).limit(_TIMELINE_LIMIT).all()
    ]
    # Nhật ký cũ (`/api/admin/houses/*`) ghi `extra` dạng JSON text {"house_id": N, ...}.
    A = models.AuditLog
    pat = f'"house_id": {h.id}'
    for row in (
        db.query(A).filter(
            A.host_id == h.host_id, A.action.like("house\\_%", escape="\\"),
            or_(A.extra.like(f"%{pat},%"), A.extra.like(f"%{pat}}}%")),
        ).order_by(A.id.desc()).limit(_TIMELINE_LIMIT).all()
    ):
        try:
            extra = json.loads(row.extra or "{}")
        except ValueError:
            extra = {}
        out.append({
            "source": "legacy_audit", "action": row.action,
            "actor": user_brief(db, extra.get("admin_id") or row.actor_user_id, cache),
            "reason": extra.get("reason"), "before": None,
            "after": {k: v for k, v in extra.items() if k not in ("house_id", "admin_id", "reason")} or None,
            "at": iso(row.created_at),
        })
    C = models.ChangeLog
    for row in (
        db.query(C).filter(C.entity_type.in_(("house", "listing")), C.entity_id == h.id)
        .order_by(C.id.desc()).limit(_TIMELINE_LIMIT).all()
    ):
        out.append({
            "source": "change_log", "action": row.action, "actor": user_brief(db, row.actor_id, cache),
            "reason": None, "before": row.before_json, "after": row.after_json, "at": iso(row.created_at),
        })
    out.append({"source": "system", "action": "listing.created", "actor": user_brief(db, h.host_id, cache),
                "reason": None, "before": None, "after": None, "at": iso(h.created_at)})
    out.sort(key=lambda e: e["at"] or "", reverse=True)
    return out[:_TIMELINE_LIMIT]


@router.get("/listings/{house_id}")
def get_listing(
    house_id: int,
    ctx: AdminContext = Depends(require_permission("listings.read")),
    db: Session = Depends(get_db),
):
    h = _load_listing(db, house_id)
    cache: dict = {}
    cats = _categories(db, [h.category_id])
    reports = None
    if ctx.has("content.read"):
        R = models.ContentReport
        reports = [
            _report_row(db, r, cache)
            for r in db.query(R).filter(R.target_type == "house", R.target_id == h.id)
            .order_by(R.created_at.desc()).limit(20).all()
        ]
    V = models.VerificationRequest
    verif = db.query(V).filter(V.house_id == h.id).order_by(V.id.desc()).first()
    open_reports = _open_report_counts(db, "house", [h.id]).get(h.id, 0)
    return one({
        **_listing_row(h, cats=cats, cache=cache, db=db, open_reports=open_reports),
        "description": h.description or "",
        "images": helpers._rel_upload_urls(h.images),
        "amenities": h.amenities or [],
        "bedrooms": h.bedrooms,
        "bathrooms": h.bathrooms,
        "ward_slug": h.ward_slug,
        "direction": h.direction,
        "legal_status": h.legal_status,
        "seller_type": h.seller_type,
        "kenh": h.kenh,
        "source_room_id": h.source_room_id,
        "map": {"lat": h.latitude, "lng": h.longitude, "geocode_status": h.geocode_status},
        "quality": {
            "self_star": h.quality_self_star, "verified_star": h.quality_verified_star,
            "verified_at": iso(h.quality_verified_at), "criteria": h.quality_criteria,
            "open_verification": None if verif is None else {"id": verif.id, "status": verif.status},
        },
        "trusted_at": iso(h.trusted_at),
        "trusted_by": user_brief(db, h.trusted_by_admin_id, cache),
        "stats": {"views": h.view_count or 0, "likes": h.like_count or 0, "comments": h.comment_count or 0,
                  "rating_avg": h.rating_avg, "rating_count": h.rating_count or 0},
        "owner": _owner_card(db, h, cache),
        "duplicates": _duplicates(db, h, cats, cache),
        "checklist": _quality(h),
        "reports": reports,
        "timeline": _listing_timeline(db, h, cache),
        "allowed_decisions": _allowed_listing_decisions(h),
    })


def _allowed_listing_decisions(h: models.House) -> list[str]:
    s = h.status
    if s == "deleted":
        return []
    if s in (HouseStatus.PUBLISHED, HouseStatus.APPROVED_LEGACY):
        return ["unpublish"]
    if s == HouseStatus.REJECTED:
        return ["approve"]
    return ["approve", "reject"]  # pending_review | pending | hidden


class ListingDecisionBody(BaseModel):
    decision: Literal["approve", "reject", "unpublish"]
    reason: str = Field("", max_length=1000)


@router.post("/listings/{house_id}/moderation-decisions")
def decide_listing(
    house_id: int,
    body: ListingDecisionBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("listings.moderate")),
    db: Session = Depends(get_db),
):
    h = _load_listing(db, house_id)

    def do() -> CommandResult:
        if body.decision not in _allowed_listing_decisions(h):
            raise fail(409, "ADMIN_INVALID_TRANSITION",
                       f"Không thể '{body.decision}' tin đang ở trạng thái '{h.status}'")
        if body.decision == "approve" and content_ops.published_conflict(db, h) is not None:
            raise fail(409, "ADMIN_LISTING_ROOM_CONFLICT",
                       "Phòng này đang có một tin khác cùng kênh đang rao. Gỡ tin kia trước.")
        res = content_ops.moderate_listing(db, h, decision=body.decision, reason=body.reason, actor_id=ctx.user_id)
        db.flush()
        cats = _categories(db, [h.category_id])
        return CommandResult(
            data=_listing_row(h, cats=cats, cache={}, db=db,
                              open_reports=_open_report_counts(db, "house", [h.id]).get(h.id, 0)),
            before=res["before"], after=res["after"], event_status=h.status,
        )

    return run_command(
        db, ctx, action=f"listing.{body.decision}", permission="listings.moderate", entity_type="listing",
        entity_id=house_id, key=key, fn=do, reason=body.reason,
        reason_required=body.decision in ("reject", "unpublish"),
        expected_version=expected, current_version=lambda: _listing_version(h),
        event_type="listing.moderated",
    )


class TrustedBody(BaseModel):
    is_trusted: bool
    reason: str = Field("", max_length=500)


@router.post("/listings/{house_id}/trusted")
def set_listing_trusted(
    house_id: int,
    body: TrustedBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("listings.mark_trusted")),
    db: Session = Depends(get_db),
):
    h = _load_listing(db, house_id)

    def do() -> CommandResult:
        if bool(h.is_trusted) == body.is_trusted:
            raise fail(409, "ADMIN_CONFLICT", "Tin đã ở đúng trạng thái này")
        res = content_ops.set_listing_trusted(db, h, is_trusted=body.is_trusted, actor_id=ctx.user_id)
        cats = _categories(db, [h.category_id])
        return CommandResult(
            data={**_listing_row(h, cats=cats, cache={}, db=db), "trusted_at": iso(h.trusted_at)},
            before=res["before"], after=res["after"],
        )

    return run_command(
        db, ctx, action="listing.trusted_set" if body.is_trusted else "listing.trusted_unset",
        permission="listings.mark_trusted", entity_type="listing", entity_id=house_id, key=key, fn=do,
        reason=body.reason, reason_required=not body.is_trusted,
        expected_version=expected, current_version=lambda: _listing_version(h),
    )


# ══ Báo cáo nội dung ═════════════════════════════════════════════════════════


def _report_version(r: models.ContentReport) -> str:
    return etag(r.id, r.status, iso(r.reviewed_at))


def _target_preview(db: Session, target_type: str, target_id: int, cache: dict) -> dict:
    obj = content_ops.load_report_target(db, target_type, target_id)
    if obj is None:
        return {"exists": False, "title": None, "snippet": None, "status": None, "link": None,
                "author": None, "image": None}
    if target_type == "house":
        return {"exists": True, "title": obj.title, "snippet": (obj.description or "")[:160],
                "status": obj.status, "link": f"/admin/content/listings/{obj.id}",
                "author": user_brief(db, obj.host_id, cache), "image": _cover(obj)}
    if target_type == "post":
        imgs = obj.images or []
        return {"exists": True, "title": None, "snippet": (obj.content or "")[:160], "status": obj.status,
                "link": None, "author": user_brief(db, obj.user_id, cache),
                "image": helpers._rel_upload_url(imgs[0]) if imgs else None}
    return {"exists": True, "title": None, "snippet": (obj.content or "")[:160], "status": obj.status,
            "link": None, "author": user_brief(db, obj.user_id, cache), "image": None,
            "parent": {"type": obj.target_type, "id": obj.post_id}}


def _pending_on_target(db: Session, r: models.ContentReport) -> int:
    R = models.ContentReport
    return _count(db, R, R.target_type == r.target_type, R.target_id == r.target_id,
                  R.status == "pending", R.kind == "violation", R.id != r.id)


def _report_dto(db: Session, r: models.ContentReport, cache: dict) -> dict:
    return {
        **_report_row(db, r, cache),
        "ref": f"BC-{r.id:05d}",
        "target": _target_preview(db, r.target_type, r.target_id, cache),
        "other_pending_on_target": _pending_on_target(db, r),
        "version": _report_version(r),
    }


@router.get("/content-reports")
def list_content_reports(
    status: str = Query("pending", pattern="^(pending|reviewed|dismissed|all)$"),
    target_type: str = Query("", pattern="^(|house|post|comment)$"),
    kind: str = Query("violation", pattern="^(violation|feedback|all)$"),
    q: str = Query("", max_length=200),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("content.read")),
    db: Session = Depends(get_db),
):
    R = models.ContentReport
    query = db.query(R)
    if status != "all":
        query = query.filter(R.status == status)
    if target_type:
        query = query.filter(R.target_type == target_type)
    if kind != "all":
        query = query.filter(R.kind == kind)
    term = q.strip()
    if term:
        conds = [func.lower(R.detail).like(_like(term), escape="\\"), R.reason == term]
        digits = term.upper().removeprefix("BC-")
        if digits.isdigit():
            conds += [R.id == int(digits), R.target_id == int(digits)]
        query = query.filter(or_(*conds))
    rows, total = paginate(query.order_by(R.created_at.desc(), R.id.desc()), page)
    cache: dict = {}
    return paged([_report_dto(db, r, cache) for r in rows], total=total, page=page)


def _load_report(db: Session, report_id: int) -> models.ContentReport:
    r = db.get(models.ContentReport, report_id)
    if r is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy báo cáo")
    return r


@router.get("/content-reports/{report_id}")
def get_content_report(
    report_id: int,
    ctx: AdminContext = Depends(require_permission("content.read")),
    db: Session = Depends(get_db),
):
    r = _load_report(db, report_id)
    cache: dict = {}
    R = models.ContentReport
    others = (
        db.query(R).filter(R.target_type == r.target_type, R.target_id == r.target_id, R.id != r.id)
        .order_by(R.created_at.desc()).limit(20).all()
    )
    return one({**_report_dto(db, r, cache), "other_reports": [_report_row(db, o, cache) for o in others]})


class ReportDecisionBody(BaseModel):
    decision: Literal["dismiss", "resolve", "resolve_and_hide"]
    reason: str = Field("", max_length=1000)


@router.post("/content-reports/{report_id}/decisions")
def decide_content_report(
    report_id: int,
    body: ReportDecisionBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("content.moderate")),
    db: Session = Depends(get_db),
):
    r = _load_report(db, report_id)
    # Ẩn TIN ĐĂNG là gỡ tin — cần thêm quyền kiểm duyệt tin.
    if body.decision == "resolve_and_hide" and r.target_type == "house" and not ctx.has("listings.moderate"):
        raise fail(403, "ADMIN_PERMISSION_DENIED", "Bạn không có quyền gỡ tin đăng",
                   {"permission": "listings.moderate"})

    def do() -> CommandResult:
        if r.status != "pending":
            raise fail(409, "ADMIN_INVALID_TRANSITION", "Báo cáo đã được xử lý")
        hidden = None
        also = 0
        if body.decision == "resolve_and_hide":
            try:
                hidden = content_ops.hide_report_target(db, r, reason=body.reason.strip(), actor_id=ctx.user_id)
            except OpsError as exc:
                raise _ops_fail(exc)
            # Nội dung đã ẩn → các báo cáo đang chờ khác về CÙNG nội dung cũng xong.
            R = models.ContentReport
            for o in db.query(R).filter(
                R.target_type == r.target_type, R.target_id == r.target_id, R.id != r.id,
                R.status == "pending", R.kind == "violation",
            ).all():
                content_ops.close_report(o, status="reviewed", actor_id=ctx.user_id)
                also += 1
        content_ops.close_report(r, status="dismissed" if body.decision == "dismiss" else "reviewed",
                                 actor_id=ctx.user_id)
        db.flush()
        return CommandResult(
            data={**_report_dto(db, r, {}), "target_hidden": hidden, "also_resolved": also},
            before={"status": "pending"},
            after={"status": r.status, "target": hidden, "also_resolved": also},
            event_status=r.status,
        )

    return run_command(
        db, ctx, action=f"content_report.{body.decision}", permission="content.moderate",
        entity_type="content_report", entity_id=report_id, key=key, fn=do, reason=body.reason,
        reason_required=body.decision in ("dismiss", "resolve_and_hide"),
        expected_version=expected, current_version=lambda: _report_version(r),
        event_type="content_report.decided",
    )


# ══ Thẩm định sao ════════════════════════════════════════════════════════════


def _verif_version(v: models.VerificationRequest) -> str:
    return etag(v.id, v.status, v.verified_star, iso(v.completed_at))


def _verif_row(db: Session, v: models.VerificationRequest, cache: dict) -> dict:
    h = db.get(models.House, v.house_id)
    return {
        "id": v.id, "ref": f"TD-{v.id:05d}", "status": v.status,
        "house": None if h is None else {
            "id": h.id, "title": h.title, "status": h.status, "address": h.address, "cover_image": _cover(h),
            "quality_self_star": h.quality_self_star, "quality_verified_star": h.quality_verified_star,
            "quality_criteria": h.quality_criteria,
        },
        "host": user_brief(db, v.host_id, cache),
        "fee_amount": v.fee_amount, "payment_status": v.payment_status,
        "verified_star": v.verified_star, "criteria": v.criteria_json, "note": v.note,
        "assignee": user_brief(db, v.assignee_id, cache),
        "created_at": iso(v.created_at), "completed_at": iso(v.completed_at),
        "version": _verif_version(v),
    }


@router.get("/verifications")
def list_verifications(
    status: str = Query("open", pattern="^(open|requested|inspecting|done|rejected|all)$"),
    house_id: Optional[int] = None,
    q: str = Query("", max_length=40),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_any_permission("content.read", "verification.review")),
    db: Session = Depends(get_db),
):
    V = models.VerificationRequest
    query = db.query(V)
    if status == "open":
        query = query.filter(V.status.in_(content_ops.VERIFICATION_OPEN))
    elif status != "all":
        query = query.filter(V.status == status)
    if house_id is not None:
        query = query.filter(V.house_id == house_id)
    digits = q.strip().upper().removeprefix("TD-")
    if digits.isdigit():  # mã yêu cầu (link `?focus=` từ hộp việc)
        query = query.filter(V.id == int(digits))
    # Hàng chờ: cũ nhất trước (FIFO); lịch sử: mới nhất trước.
    order = (V.created_at.asc(), V.id.asc()) if status in ("open", "requested", "inspecting") else (V.id.desc(),)
    rows, total = paginate(query.order_by(*order), page)
    cache: dict = {}
    return paged([_verif_row(db, v, cache) for v in rows], total=total, page=page)


def _load_verif(db: Session, req_id: int) -> models.VerificationRequest:
    v = db.get(models.VerificationRequest, req_id)
    if v is None:
        raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy yêu cầu thẩm định")
    return v


class VerificationCompleteBody(BaseModel):
    verified_star: int = Field(..., ge=1, le=5)
    note: Optional[str] = Field(None, max_length=1000)
    criteria: Optional[dict[str, Any]] = None


@router.post("/verifications/{req_id}/complete")
def complete_verification(
    req_id: int,
    body: VerificationCompleteBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("verification.review")),
    db: Session = Depends(get_db),
):
    v = _load_verif(db, req_id)

    def do() -> CommandResult:
        if v.status not in content_ops.VERIFICATION_OPEN:
            raise fail(409, "ADMIN_INVALID_TRANSITION", "Yêu cầu thẩm định đã đóng")
        h = db.get(models.House, v.house_id)
        if h is None:
            raise fail(404, "ADMIN_NOT_FOUND", "Không tìm thấy tin của yêu cầu này")
        before = {"status": v.status, "house_verified_star": h.quality_verified_star}
        content_ops.complete_verification(
            v, h, verified_star=body.verified_star, note=body.note, criteria=body.criteria, actor_id=ctx.user_id)
        helpers.push_notification(
            db, h.host_id, "verification_done", "Tin đã được thẩm định",
            f'Tin "{h.title}" đạt {body.verified_star} sao chất lượng sau thẩm định.', h.id,
        )
        return CommandResult(data=_verif_row(db, v, {}), before=before,
                             after={"status": "done", "verified_star": body.verified_star}, event_status="done")

    return run_command(
        db, ctx, action="verification.complete", permission="verification.review", entity_type="verification",
        entity_id=req_id, key=key, fn=do, reason=body.note,
        expected_version=expected, current_version=lambda: _verif_version(v),
    )


class ReasonBody(BaseModel):
    reason: str = Field("", max_length=1000)


@router.post("/verifications/{req_id}/reject")
def reject_verification(
    req_id: int,
    body: ReasonBody,
    key: str = Depends(idempotency_key),
    expected: Optional[str] = Depends(if_match),
    ctx: AdminContext = Depends(require_permission("verification.review")),
    db: Session = Depends(get_db),
):
    v = _load_verif(db, req_id)

    def do() -> CommandResult:
        if v.status not in content_ops.VERIFICATION_OPEN:
            raise fail(409, "ADMIN_INVALID_TRANSITION", "Yêu cầu thẩm định đã đóng")
        before = {"status": v.status}
        content_ops.reject_verification(v, actor_id=ctx.user_id, note=body.reason.strip())
        h = db.get(models.House, v.house_id)
        if h is not None:
            helpers.push_notification(
                db, h.host_id, "verification_rejected", "Yêu cầu thẩm định chưa đạt",
                f'Tin "{h.title}" chưa đạt thẩm định. Lý do: {body.reason.strip()}', h.id,
            )
        return CommandResult(data=_verif_row(db, v, {}), before=before, after={"status": "rejected"},
                             event_status="rejected")

    return run_command(
        db, ctx, action="verification.reject", permission="verification.review", entity_type="verification",
        entity_id=req_id, key=key, fn=do, reason=body.reason, reason_required=True,
        expected_version=expected, current_version=lambda: _verif_version(v),
    )


# ══ Đánh giá ═════════════════════════════════════════════════════════════════


@router.get("/reviews")
def list_reviews(
    house_id: Optional[int] = None,
    max_rating: Optional[int] = Query(None, ge=1, le=5),
    verified: Optional[bool] = None,
    q: str = Query("", max_length=200),
    page: PageParams = Depends(page_params),
    ctx: AdminContext = Depends(require_permission("content.read")),
    db: Session = Depends(get_db),
):
    RV = models.Review
    query = db.query(RV)
    if house_id is not None:
        query = query.filter(RV.house_id == house_id)
    if max_rating is not None:
        query = query.filter(RV.rating <= max_rating)
    if verified is not None:
        query = query.filter(RV.verified_relationship == verified)
    if q.strip():
        query = query.filter(func.lower(RV.comment).like(_like(q.strip()), escape="\\"))
    rows, total = paginate(query.order_by(RV.created_at.desc(), RV.id.desc()), page)
    houses = {h.id: h for h in db.query(models.House).filter(models.House.id.in_({r.house_id for r in rows})).all()} \
        if rows else {}
    cache: dict = {}
    data = []
    for r in rows:
        h = houses.get(r.house_id)
        data.append({
            "id": r.id, "rating": r.rating, "comment": r.comment or "",
            "verified_relationship": bool(r.verified_relationship),
            "scores": {k: getattr(r, k) for k in
                       ("cleanliness", "accuracy", "checkin", "communication", "location", "value")},
            "house": None if h is None else {"id": h.id, "title": h.title, "status": h.status,
                                             "host": user_brief(db, h.host_id, cache)},
            "author": user_brief(db, r.user_id, cache),
            "created_at": iso(r.created_at),
        })
    return paged(data, total=total, page=page)
