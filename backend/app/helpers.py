"""Helpers convert model → dict response giống Go backend."""

from __future__ import annotations

import re
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import (
    ViewingAppointment,
    Building,
    Category,
    House,
    HostProfile,
    User,
    Notification,
    ChatMessage,
    Review,
    Room,
    RoomKenh,
)
from app.services.privacy.phone_mask import mask as _mask_phone_impl


def _mask_phone(p: str) -> str:
    return _mask_phone_impl(p or "", region="vn")

# URL upload cũ được lưu tuyệt đối theo origin lúc upload (vd http://host/uploads/..).
# Trên trang HTTPS, ảnh http:// bị chặn (mixed content) → ảnh vỡ. Chuẩn hoá về
# tương đối '/uploads/..' để trình duyệt tự resolve theo origin hiện tại (đúng scheme).
# URL ngoài (unsplash/pravatar…) không chứa '/uploads/' nên giữ nguyên.
_UPLOAD_ABS_RE = re.compile(r"^https?://[^/]+(/uploads/)", re.IGNORECASE)


def _rel_upload_url(url: Optional[str]) -> Optional[str]:
    if not url or not isinstance(url, str):
        return url
    return _UPLOAD_ABS_RE.sub(r"\1", url)


def _rel_upload_urls(urls) -> list:
    return [_rel_upload_url(u) for u in (urls or [])]


class TraCuuTin:
    """Bộ tra cứu nạp SẴN cho một trang tin — thay N+1 bằng 3 truy vấn.

    Vì sao cần: [house_to_dict] gọi DB ba lần cho MỖI tin (Category, User,
    HostProfile). Với trang 20 tin đó là 60 truy vấn thừa — đo 08/09/2026:
    `/api/houses?limit=20` tốn 62 truy vấn / 82ms, trong khi mọi endpoint khác
    chỉ 1–3 truy vấn.

    CẠM BẪY đã dính: cách "nạp sẵn" tưởng như đủ là chạy
    `db.query(Category).filter(Category.id.in_(ids)).all()` rồi để `db.get()`
    tự ăn identity map của Session. KHÔNG chạy. Identity map giữ đối tượng
    bằng WEAK REFERENCE, nên vứt kết quả đi là chúng bị thu gom ngay lập tức
    (đo được: map còn đúng 0 đối tượng) và mọi `db.get()` lại đi DB. Vì vậy
    lớp này GIỮ THẬT các đối tượng trong dict và tra thẳng vào dict.
    """

    __slots__ = ("_cat", "_user", "_ho_so")

    def __init__(self, cat: dict, user: dict, ho_so: dict):
        self._cat = cat
        self._user = user
        self._ho_so = ho_so

    def danh_muc(self, cid) -> Optional[Category]:
        return self._cat.get(cid) if cid else None

    def chu_nha(self, uid) -> Optional[User]:
        return self._user.get(uid) if uid else None

    def ho_so_chu(self, uid) -> Optional[HostProfile]:
        return self._ho_so.get(uid) if uid else None


def nap_san_cho_tin(db: Session, houses) -> TraCuuTin:
    """Nạp Category + User + HostProfile cho CẢ trang bằng 3 truy vấn.

    Gọi NGAY TRƯỚC vòng lặp `house_to_dict` (đừng gọi bên trong — thành ra mỗi
    dòng một lần), rồi truyền kết quả vào tham số `tra_cuu`. Không gọi cũng
    không sai: `house_to_dict` vẫn chạy đường cũ, chỉ chậm hơn.
    """
    cat_ids = {h.category_id for h in houses if h.category_id}
    host_ids = {h.host_id for h in houses if h.host_id}

    cat = (
        {c.id: c for c in db.query(Category).filter(Category.id.in_(cat_ids)).all()}
        if cat_ids
        else {}
    )
    user = (
        {u.id: u for u in db.query(User).filter(User.id.in_(host_ids)).all()}
        if host_ids
        else {}
    )
    ho_so = (
        {
            hp.user_id: hp
            for hp in db.query(HostProfile)
            .filter(HostProfile.user_id.in_(host_ids))
            .all()
        }
        if host_ids
        else {}
    )
    return TraCuuTin(cat, user, ho_so)


def house_to_dict(
    db: Session, h: House, tra_cuu: Optional[TraCuuTin] = None
) -> dict:
    # AC8: marketplace listing includes host trust signals (avg response, rating)
    if tra_cuu is not None:
        cat = tra_cuu.danh_muc(h.category_id)
        host = tra_cuu.chu_nha(h.host_id)
        host_profile = tra_cuu.ho_so_chu(h.host_id)
    else:
        cat = db.get(Category, h.category_id)
        host = db.get(User, h.host_id)
        host_profile = (
            db.query(HostProfile).filter(HostProfile.user_id == h.host_id).first()
            if h.host_id
            else None
        )
    short_stay = None
    private_short_owner = bool(getattr(h, "source_room_id", None)) and getattr(h, "kenh", None) == "ngan_han"
    if getattr(h, "source_room_id", None):
        from app import models
        from app.services import short_stay_service
        channel = short_stay_service.channel(db, h.source_room_id)
        room = db.get(models.Room, h.source_room_id)
        if short_stay_service.products(channel):
            short_stay = short_stay_service.room_public(db, room, channel)
            private_short_owner = True
        if private_short_owner and room:
            # A linked short-stay listing never exposes the financial owner.
            from app.services import sale_phu_trach
            sale_id = sale_phu_trach.sale_cua_phong(db, room)
            owner_id = sale_phu_trach.chu_cua_phong(db, room)
            host = db.get(User, sale_id) if sale_id and sale_id != owner_id else None
            host_profile = (db.query(HostProfile).filter_by(user_id=host.id).first()
                            if host else None)
    # TIN NGẮN HẠN NEO HẠNG (migration 0130): không có phòng nguồn, thông tin
    # bán hàng nằm ở hạng — tên hạng, sức chứa, giường, giá ba kiểu, còn mấy
    # phòng. App đọc khối này thay cho `short_stay` của tin neo-theo-phòng.
    hang_phong = None
    if getattr(h, "loai_phong_id", None):
        from app.services import tin_ngan_han

        hang_phong = tin_ngan_han.thong_tin_hang(db, h)

    return {
        "short_stay": short_stay,
        "hang_phong": hang_phong,
        "id": h.id,
        "host_id": (host.id if host else 0) if private_short_owner else h.host_id,
        "title": h.title,
        "description": h.description,
        "category_id": h.category_id,
        "category_name": cat.name if cat else None,
        # Nhóm master (stay_long|stay_short|business) — app tô MÀU PIN theo đây.
        "category_group": getattr(cat, "group_key", "") if cat else "",
        # 0075 — TỰ KHAI, chưa xác minh. '' = tin cũ chưa từng được hỏi; client
        # KHÔNG được suy diễn rỗng thành "chính chủ".
        "seller_type": "" if private_short_owner else (getattr(h, "seller_type", "") or ""),
        "unit_label": getattr(h, "unit_label", "") or "",
        "price": h.price,
        "area": h.area,
        "address": h.address,
        "city": h.city,
        "district": h.district,
        "latitude": h.latitude,
        "longitude": h.longitude,
        "bedrooms": h.bedrooms,
        "bathrooms": h.bathrooms,
        "status": h.status,
        # Tin đăng cư xử như bài viết (0090). `pinned` là bool cho app; cột thật
        # là mốc thời gian để nhiều tin ghim còn xếp được với nhau.
        "pinned": getattr(h, "pinned_at", None) is not None,
        "view_count": getattr(h, "view_count", 0) or 0,
        "like_count": getattr(h, "like_count", 0) or 0,
        "comment_count": getattr(h, "comment_count", 0) or 0,
        "rejection_reason": h.rejection_reason,
        "legal_status": h.legal_status,
        "created_at": h.created_at.isoformat(),
        "images": _rel_upload_urls(h.images),
        "amenities": h.amenities or [],
        "listing_type": (
            "multi_unit"
            if hang_phong and hang_phong["so_phong"] > 1
            else h.listing_type
        ),
        # Tin neo hạng KHÔNG giữ tồn kho riêng: chủ nhà thêm/bớt phòng trong
        # hạng là chợ phải đổi theo ngay. Chép một lần lúc đăng thì hạng có 3
        # phòng mà tin vẫn rao "còn 1" — hai con số cho cùng một hạng.
        "total_units": hang_phong["so_phong"] if hang_phong else h.total_units,
        "available_units": (
            hang_phong["con_trong"] if hang_phong else h.available_units
        ),
        "gender_pref": h.gender_pref,
        "host_name": host.name if host else None,
        "host_avatar": _rel_upload_url(host.avatar_path) if host else None,
        "host_phone": host.phone if host else None,
        "host_avg_response_hours": host_profile.avg_response_hours if host_profile else None,
        "host_rating": host_profile.rating if host_profile else None,
        # Badge "đã xác minh CCCD" cho khách xem ở card chủ nhà (Đợt 1 uy tín).
        "host_verified": host_profile.verified if host_profile else False,
        # Badge "Chủ nhà tin cậy" kiểu Superhost (Đợt 3) — ngưỡng minh bạch.
        "host_trusted": is_trusted_host(host_profile),
        # Cỡ mẫu đi kèm để client biết con số giờ phản hồi đáng tin tới đâu.
        "host_response_sample": (
            getattr(host_profile, "response_sample", 0) if host_profile else 0
        ),
        # Listing v2 fields (migration 0039)
        "transaction_type": getattr(h, "transaction_type", "rent"),
        "is_trusted": getattr(h, "is_trusted", False),
        "trusted_at": h.trusted_at.isoformat() if getattr(h, "trusted_at", None) else None,
        "trusted_by_admin_id": getattr(h, "trusted_by_admin_id", None),
        "ward_slug": getattr(h, "ward_slug", None),
        "ward_slug_legacy": getattr(h, "ward_slug_legacy", None),
        # BĐS công nghiệp P3 (migration 0046) — product_type='industrial' + attrs KCN.
        "product_type": getattr(h, "product_type", "apartment"),
        # Tin này đã thuộc dự án nào chưa. Client cần biết để KHÔNG mời gán lại
        # một tin đã gắn — `source_room_id` là UNIQUE nên gán lần hai sẽ vỡ ở
        # tầng DB thay vì báo lỗi tử tế.
        "source_room_id": getattr(h, "source_room_id", None),
        "loai_phong_id": getattr(h, "loai_phong_id", None),
        "industrial_attrs": getattr(h, "industrial_attrs", None),
        # Tìm kiếm nâng cao (migration 0071)
        "direction": getattr(h, "direction", None),
        "rating_avg": getattr(h, "rating_avg", 0) or 0,
        "rating_count": getattr(h, "rating_count", 0) or 0,
    }


def user_to_dict(u: User) -> dict:
    return {
        "id": u.id,
        "name": u.name,
        "email": u.email,
        "phone": u.phone,
        "avatar_path": _rel_upload_url(u.avatar_path),
        "role": u.role,
        # `role` là quyền hệ thống (guest/host/admin), `account_type` là VAI TRÒ
        # NGHỀ (customer/sale/owner/admin). Sale hiện vẫn mang role='guest' nên
        # nếu không trả cột này thì app không có cách nào biết ai là sale để
        # dựng đúng trang cá nhân.
        "account_type": getattr(u, "account_type", None) or "customer",
        "is_active": u.is_active,
        "created_at": u.created_at.isoformat(),
        "birthday": u.birthday,
        "bio": u.bio,
        "id_number": u.id_number,
    }


def _ten_phong(db: Session, b: ViewingAppointment) -> Optional[str]:
    """Tên hiển thị cho lịch neo vào phòng: "Phòng P01 · Toà Hoa Sữa"."""
    room_id = getattr(b, "room_id", None)
    if not room_id:
        return None
    room = db.get(Room, room_id)
    if room is None:
        return None
    toa = db.get(Building, room.building_id)
    return f"Phòng {room.code} · {toa.name}" if toa else f"Phòng {room.code}"


def viewing_appointment_to_dict(
    db: Session,
    b: ViewingAppointment,
    with_guest_trust: bool = False,
    viewer_id: Optional[int] = None,
    viewer_is_admin: bool = False,
) -> dict:
    """Serialize một lịch hẹn.

    `with_guest_trust`: chỉ CHỦ NHÀ mới cần uy tín khách để cân nhắc duyệt lịch.
    Mặc định TẮT vì mỗi lần bật là +2 query (reviews + count) → N+1 trên list;
    khách/admin không cần nên đường mặc định giữ nguyên chi phí cũ.

    Sale vẫn có thông tin liên lạc để điều phối lịch.  Riêng SĐT giữa Khách và
    Chủ nhà được che cho đến khi có hợp đồng qua Sale, đủ tệp hợp đồng và giao
    dịch đã hoàn tất.  Tên/lịch vẫn hiện để lịch xem cũ không mất khả dụng.
    """
    house = db.get(House, b.house_id) if b.house_id else None
    guest = db.get(User, b.guest_id)
    host = db.get(User, house.host_id) if house else None
    # Tin dài hạn có thể do Sale đăng, vì vậy owner thật phải lấy từ neo lịch
    # thay vì suy diễn từ ``houses.host_id``.
    from app.services import contact_privacy_service, lich_xem_service

    # A few internal/offline serializers call this helper without a viewer.
    # They must not trigger a second policy query per row and, importantly,
    # they must never accidentally receive raw counterparty contact.
    neo = None
    can_reveal_counterparty = False
    if viewer_id is not None:
        neo = lich_xem_service.neo_cua(db, b)
        can_reveal_counterparty = contact_privacy_service.can_reveal_for_appointment(
            db,
            appointment_id=b.id,
            viewer_id=viewer_id,
            customer_id=b.guest_id,
            owner_id=neo.chu_nha_id,
            sale_id=neo.sale_id,
            is_admin=viewer_is_admin,
        )
    guest_phone_visible = viewer_id == b.guest_id or can_reveal_counterparty
    # ``host`` can be the Sale on a Sale-created listing.  A Customer may
    # contact that assigned Sale; only an actual Owner contact is gated.
    host_phone_visible = bool(
        viewer_id == (host.id if host else None)
        or (host is not None and neo is not None and host.id == neo.sale_id)
        or can_reveal_counterparty
        or viewer_is_admin
    )
    room_kenh = (
        db.query(RoomKenh)
        .filter(RoomKenh.room_id == getattr(b, "room_id", None), RoomKenh.dang_bat.is_(True))
        .order_by((RoomKenh.kenh == RoomKenh.DAI_HAN).desc())
        .first()
        if getattr(b, "room_id", None) else None
    )

    # has_reviewed: chỉ truy vấn Review khi appointment đã hoàn thành để
    # tránh N+1 query trên list pending/approved (case phổ biến).
    has_reviewed = False
    if b.status == "completed" and house:
        has_reviewed = db.query(Review).filter(
            Review.user_id == b.guest_id,
            Review.house_id == b.house_id,
        ).first() is not None

    return {
        "id": b.id,
        "house_id": b.house_id,
        "room_id": getattr(b, "room_id", None),
        "kenh": room_kenh.kenh if room_kenh else None,
        "loai": getattr(b, "loai", "xem") or "xem",
        "host_id": house.host_id if house else None,
        "guest_id": b.guest_id,
        "booking_date": b.booking_date,
        "booking_time": b.booking_time,
        "message": b.message,
        "status": b.status,
        "created_at": b.created_at.isoformat(),
        # Lịch neo thẳng vào PHÒNG (dự án chưa gắn tin) thì không có tin nào để
        # lấy tiêu đề. Trả None là màn lịch hiện một dòng trống, người dùng
        # không biết mình đã hẹn xem cái gì.
        "house_title": house.title if house else _ten_phong(db, b),
        "house_address": house.address if house else None,
        "house_price": house.price if house else None,
        "house_transaction_type": getattr(house, "transaction_type", "rent") if house else None,
        "house_image": _rel_upload_url(house.images[0]) if house and house.images else None,
        "guest_name": guest.name if guest else None,
        "guest_phone": (
            guest.phone if guest and guest_phone_visible else _mask_phone(guest.phone if guest else "")
        ),
        # Uy tín KHÁCH cho chủ nhà xem khi nhận lịch hẹn (Đợt 3) — sao + số
        # giao dịch đã hoàn tất. Giúp chủ nhà yên tâm duyệt lịch. Opt-in để
        # tránh N+1 ở các đường không cần (khách/admin, chi tiết 1 lịch).
        **(_guest_trust_fields(db, b.guest_id) if with_guest_trust else {}),
        "host_name": host.name if host else None,
        "host_phone": (
            host.phone if host and host_phone_visible else _mask_phone(host.phone if host else "")
        ),
        "has_reviewed": has_reviewed,
        # Bên bán bận xin đổi giờ (mig 0115) — chip "chờ khách chọn giờ mới".
        "gio_cu": getattr(b, "gio_cu", None),
        "ly_do_doi": getattr(b, "ly_do_doi", None),
    }


def _guest_trust_fields(db: Session, guest_id: int) -> dict:
    from app.models import GuestReview  # noqa: PLC0415
    revs = list(
        db.query(GuestReview.rating)
        .filter(GuestReview.guest_id == guest_id)
        .all()
    )
    n = len(revs)
    deals = (
        db.query(ViewingAppointment)
        .filter(
            ViewingAppointment.guest_id == guest_id,
            ViewingAppointment.status.in_(["locked", "completed"]),
        )
        .count()
    )
    return {
        # Guard theo SỐ LƯỢNG (không phải truthiness) — chia cho 0 tuyệt đối
        # không xảy ra dù nguồn dữ liệu bất thường.
        "guest_rating": round(sum(r.rating for r in revs) / n, 2) if n else None,
        "guest_review_count": n,
        "guest_completed_deals": deals,
    }


def notification_to_dict(n: Notification) -> dict:
    return {
        "id": n.id,
        "user_id": n.user_id,
        "type": n.type,
        "title": n.title,
        "body": n.body,
        "related_id": n.related_id,
        "read": n.read,
        "created_at": n.created_at.isoformat(),
    }


def chat_message_to_dict(m: ChatMessage) -> dict:
    return {
        "id": m.id,
        "sender_id": m.sender_id,
        "receiver_id": m.receiver_id,
        "house_id": m.house_id,
        "body": m.body,
        "read": m.read,
        "created_at": m.created_at.isoformat(),
    }


def push_notification(
    db: Session,
    user_id: int,
    type_: str,
    title: str,
    body: str,
    related_id: int | None = None,
) -> Notification:
    n = Notification(
        user_id=user_id,
        type=type_,
        title=title,
        body=body,
        related_id=related_id,
        read=False,
    )
    db.add(n)
    db.flush()
    return n


def is_trusted_host(prof) -> bool:
    """Badge "Chủ nhà tin cậy" kiểu Superhost — ngưỡng MINH BẠCH:
    đã xác minh danh tính + rating ≥4.8 + ≥5 đánh giá ĐÃ KIỂM.

    Đếm `verified_review_count` chứ không phải `review_count`: 1.025 đánh giá
    hiện có đều vào từ thời cổng `review_requires_stay` còn tắt, tức bất kỳ ai
    đăng nhập cũng chấm được bất kỳ tin nào. Đếm chúng là trao huy hiệu uy tín
    cho một mẫu không chứng minh được gì.

    Vẫn là hàm THUẦN (không truy vấn): nó được gọi trong vòng lặp dựng danh
    sách tin, nên cỡ mẫu phải được đếm sẵn vào cột.
    """
    if prof is None:
        return False
    return bool(
        getattr(prof, "verified", False)
        and (prof.rating or 0) >= 4.8
        and getattr(prof, "verified_review_count", 0) >= 5
    )


def recompute_host_reputation(db: Session, host_id: int) -> None:
    """Tính lại `rating` + `avg_response_hours` của host từ dữ liệu THẬT.

    Trước đây hai cột này CHẾT: có schema mà không nguồn ghi. Nay:
      - rating = trung bình mọi review trên các nhà host này sở hữu.
      - avg_response_hours = trung bình (responded_at − created_at) của các lịch
        hẹn host ĐÃ phản hồi.

    Nuốt lỗi: cập nhật uy tín hỏng không được làm hỏng hành động chính (tạo
    review / duyệt lịch hẹn)."""
    try:
        prof = (
            db.query(HostProfile)
            .filter(HostProfile.user_id == host_id)
            .first()
        )
        if prof is None:
            return  # host chưa có hồ sơ → không có chỗ ghi

        # rating: mọi review trên nhà của host này.
        house_ids = [
            h.id for h in db.query(House.id).filter(House.host_id == host_id).all()
        ]
        if house_ids:
            revs = (
                db.query(Review.rating)
                .filter(Review.house_id.in_(house_ids))
                .all()
            )
            if revs:
                prof.rating = round(sum(r.rating for r in revs) / len(revs), 2)
                prof.review_count = len(revs)
            # Cỡ mẫu ĐÃ KIỂM — nguồn của huy hiệu uy tín. Đếm riêng, không suy
            # từ `review_count`.
            prof.verified_review_count = (
                db.query(func.count(Review.id))
                .filter(
                    Review.house_id.in_(house_ids),
                    Review.verified_relationship.is_(True),
                )
                .scalar()
            ) or 0

        # avg_response_hours: các lịch hẹn đã phản hồi.
        appts = (
            db.query(ViewingAppointment)
            .filter(
                ViewingAppointment.house_id.in_(house_ids or [-1]),
                ViewingAppointment.responded_at.isnot(None),
            )
            .all()
        )
        durations = [
            (a.responded_at - a.created_at).total_seconds() / 3600.0
            for a in appts
            if a.responded_at and a.created_at
        ]
        # Ghi cả CỠ MẪU. Không có nó thì `avg_response_hours` là một con số
        # không ai biết dựa trên mấy lần đo — và trước 05/09/2026 nó dựa trên
        # 0 lần.
        prof.response_sample = len(durations)
        if durations:
            prof.avg_response_hours = round(sum(durations) / len(durations), 1)

        db.flush()
    except Exception:  # noqa: BLE001 — uy tín không được chặn hành động chính
        pass


def email_valid(email: str) -> bool:
    email = (email or "").strip()
    if not email or "@" not in email:
        return False
    at = email.index("@")
    dot = email.rfind(".")
    return at > 0 and dot > at + 1 and dot < len(email) - 1
