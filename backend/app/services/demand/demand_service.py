"""Nghiệp vụ tin nhu cầu — router chỉ gọi xuống đây.

Ba quyết định đáng ghi lại:

1. **Hết hạn tính KHI ĐỌC.** `expires_at` là một cột thường; mọi truy vấn danh
   sách đều lọc `expires_at > now`. Không cron, không job dọn — cron là thứ hỏng
   âm thầm trên một hệ deploy thủ công, và nếu nó chết thì danh sách đầy nhu cầu
   chết mà không ai biết.

2. **Giới hạn số tin đang mở / người.** Không có trần thì một tài khoản đăng 200
   nhu cầu là chôn sạch danh sách của mọi người khác. 10 là con số rộng rãi cho
   người thật (ai đang tìm nhà thật cũng chỉ có 1–3 nhu cầu).

3. **Không trả SĐT.** `DemandAuthor` chỉ có id/tên/ảnh. Xem docstring
   `app/domain/demand_post.py`.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app import models
from app.domain.demand_post import DemandPost
from app.schemas.demand import DemandAuthor, DemandCreate, DemandResponse

# Nhu cầu NGUỘI nhanh: sau một tháng người ta hoặc đã tìm được, hoặc đã đổi ý.
DEMAND_TTL_DAYS = 30

# Trần tin đang mở của một người — xem docstring.
MAX_OPEN_PER_USER = 10


def _now() -> datetime:
    return datetime.utcnow()


def _con_han(q):
    return q.filter(DemandPost.status == "open", DemandPost.expires_at > _now())


def create_demand(db: Session, user_id: int, body: DemandCreate) -> DemandPost:
    dang_mo = _con_han(
        db.query(func.count(DemandPost.id)).filter(DemandPost.user_id == user_id)
    ).scalar()
    if (dang_mo or 0) >= MAX_OPEN_PER_USER:
        raise HTTPException(
            status_code=429,
            detail=(
                f"Bạn đang có {dang_mo} tin nhu cầu còn hiệu lực. "
                "Hãy đóng bớt tin cũ trước khi đăng tin mới."
            ),
        )

    # Loại hình: chỉ nhận id CÓ THẬT và đang bật. Client gửi id lạ (bản cũ,
    # danh mục đã tắt) thì bỏ qua id đó chứ không chặn cả tin — nhu cầu vẫn còn
    # nguyên giá trị khi thiếu một nhãn loại hình.
    cat_ids = _loc_category_hop_le(db, body.category_ids)

    item = DemandPost(
        user_id=user_id,
        kind=body.kind,
        province_code=body.province_code,
        province_name=body.province_name,
        ward_slugs=body.ward_slugs or None,
        area_label=body.area_label,
        category_ids=cat_ids or None,
        budget_min=body.budget_min,
        budget_max=body.budget_max,
        area_min=body.area_min,
        bedrooms_min=body.bedrooms_min,
        move_in_date=body.move_in_date,
        duration_months=body.duration_months,
        occupants=body.occupants,
        payment_method=body.payment_method,
        purpose=body.purpose,
        legal_ok=body.legal_ok or None,
        needs=body.needs or None,
        note=(body.note or "").strip() or None,
        status="open",
        expires_at=_now() + timedelta(days=DEMAND_TTL_DAYS),
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def _loc_category_hop_le(db: Session, ids: list[int]) -> list[int]:
    if not ids:
        return []
    rows = (
        db.query(models.Category.id)
        .filter(models.Category.id.in_(ids))
        .all()
    )
    hop_le = {r[0] for r in rows}
    return [i for i in ids if i in hop_le]


def list_demands(
    db: Session,
    *,
    kind: str | None = None,
    province_code: str | None = None,
    category_id: int | None = None,
    user_id: int | None = None,
    query: str | None = None,
    include_closed: bool = False,
    limit: int = 20,
    offset: int = 0,
) -> list[DemandPost]:
    q = db.query(DemandPost)
    if user_id is not None:
        q = q.filter(DemandPost.user_id == user_id)
    if not include_closed:
        q = _con_han(q)
    if kind:
        q = q.filter(DemandPost.kind == kind)
    if province_code:
        q = q.filter(DemandPost.province_code == province_code)
    if query and query.strip():
        # Tìm trên KHU VỰC và GHI CHÚ — tin nhu cầu không có tiêu đề, người
        # dùng gõ vào ô tìm là đang nhớ tên quận/tỉnh hoặc một chi tiết trong
        # lời nhắn ("gần trường", "nuôi mèo").
        like = f"%{query.strip()}%"
        q = q.filter(
            or_(
                DemandPost.area_label.ilike(like),
                DemandPost.province_name.ilike(like),
                DemandPost.note.ilike(like),
            )
        )
    rows = (
        q.order_by(DemandPost.created_at.desc())
        .limit(max(1, min(limit, 50)))
        .offset(max(0, offset))
        .all()
    )
    if category_id is not None:
        # Lọc theo loại hình làm ở Python: `category_ids` là JSON, toán tử chứa
        # của JSON khác nhau giữa Postgres và SQLite (test chạy SQLite) — viết
        # SQL riêng cho từng loại DB để tiết kiệm vài mili-giây trên danh sách
        # tối đa 50 dòng là đánh đổi tồi.
        rows = [r for r in rows if category_id in (r.category_ids or [])]
    return rows


def close_demand(db: Session, item: DemandPost) -> DemandPost:
    item.status = "closed"
    db.commit()
    db.refresh(item)
    return item


def extend_demand(db: Session, item: DemandPost) -> DemandPost:
    """Gia hạn = ĐẨY hạn tới 30 ngày KỂ TỪ BÂY GIỜ, không cộng dồn vào hạn cũ.

    Cộng dồn cho phép bấm gia hạn 10 lần để giữ tin nổi mãi — đúng cách một
    danh sách nhu cầu bị chiếm chỗ."""
    item.expires_at = _now() + timedelta(days=DEMAND_TTL_DAYS)
    if item.status == "closed":
        item.status = "open"
    db.commit()
    db.refresh(item)
    return item


def to_response(
    db: Session, item: DemandPost, *, ten_loai: dict[int, str] | None = None
) -> DemandResponse:
    cat_ids = list(item.category_ids or [])
    if ten_loai is None:
        ten_loai = ten_loai_hinh(db, cat_ids)
    user = db.get(models.User, item.user_id)
    return DemandResponse(
        id=item.id,
        kind=item.kind,
        province_code=item.province_code,
        province_name=item.province_name,
        ward_slugs=list(item.ward_slugs or []),
        area_label=item.area_label,
        category_ids=cat_ids,
        category_names=[ten_loai[i] for i in cat_ids if i in ten_loai],
        budget_min=item.budget_min,
        budget_max=item.budget_max,
        area_min=item.area_min,
        bedrooms_min=item.bedrooms_min,
        move_in_date=item.move_in_date,
        duration_months=item.duration_months,
        occupants=item.occupants,
        payment_method=item.payment_method,
        purpose=item.purpose,
        legal_ok=list(item.legal_ok or []),
        needs=list(item.needs or []),
        note=item.note,
        status=item.status,
        expires_at=item.expires_at,
        created_at=item.created_at,
        author=(
            DemandAuthor(
                id=user.id, name=user.name, avatar_path=user.avatar_path or None
            )
            if user is not None
            else None
        ),
    )


def ten_loai_hinh(db: Session, ids: list[int]) -> dict[int, str]:
    """Map id → tên loại hình cho CẢ danh sách — một truy vấn, tránh N+1 khi màn
    danh sách trả 20 tin."""
    if not ids:
        return {}
    rows = (
        db.query(models.Category.id, models.Category.name)
        .filter(models.Category.id.in_(list(set(ids))))
        .all()
    )
    return {i: n for i, n in rows}
