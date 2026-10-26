"""Hồ sơ CÔNG KHAI của chủ nhà / môi giới.

Trước đây app không có cách nào xem hồ sơ một người bán ngoài thẻ host nhỏ nằm
trong trang chi tiết tin — muốn có mục "Môi giới tiêu biểu" ở trang chủ thì phải
có danh sách công khai + trang hồ sơ để bấm vào.

Endpoints:
    GET /api/hosts/featured           — danh sách môi giới/chủ nhà tiêu biểu
    GET /api/hosts/sales              — danh bạ tài khoản đã khởi tạo hồ sơ Sale
    GET /api/hosts/{user_id}          — hồ sơ công khai 1 người
    GET /api/hosts/{user_id}/reviews  — nhận xét khách trên các tin của người đó

AN TOÀN: chỉ trả trường CÔNG KHAI (tên, ảnh, điểm, số tin). TUYỆT ĐỐI không trả
email/SĐT/CCCD/ngân hàng — khác hẳn `GET /api/users` (admin-only, PII đầy đủ).
Xếp hạng tính từ dữ liệu THẬT (HostProfile.rating/review_count + số tin đã đăng),
không có cột "nổi bật" mua được.
"""

import time
from datetime import datetime, timezone

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import and_, case, desc, distinct, exists, func, or_
from sqlalchemy.orm import Session

from app import auth, helpers, models
from app.database import get_db

router = APIRouter(prefix="/api/hosts", tags=["hosts"])

# Vai được coi là "người bán" — admin gom vào vì tài khoản vận hành cũng đăng tin.
_SELLER_ROLES = ("host", "admin")


def _la_nguoi_ban(User):
    """Điều kiện SQL: tài khoản này có trang bán hàng công khai hay không.

    KHÔNG chỉ dựa vào `role`. Sale là tài khoản THƯỜNG (`role='guest'`) theo
    thiết kế — chặn bằng role thì trang `/sale/:id` của chính họ trả 404, đúng
    lỗi gặp khi seed tài khoản sale đầu tiên (05/09/2026).

    CHỦ NHÀ bị loại (R2): họ không phải người bán, họ là người sale tìm ra. Đưa
    họ vào "môi giới tiêu biểu" là công bố đúng thứ cổng `_duoc_xem_chu_nha`
    dựng lên để giấu.
    """
    return and_(
        or_(
            User.role.in_(_SELLER_ROLES),
            User.account_type == "sale",
            exists().where(models.SaleProfile.user_id == User.id),
        ),
        ~_dieu_kien_chu_nha(User),
    )


def _house_count_map(db: Session, user_ids: list[int]) -> dict[int, int]:
    """Số tin ĐANG hiển thị của từng host. Một truy vấn cho cả danh sách —
    tránh N+1 khi trang chủ hiện 12 người."""
    if not user_ids:
        return {}
    rows = (
        db.query(models.House.host_id, func.count(models.House.id))
        .filter(
            models.House.host_id.in_(user_ids),
            models.House.status == "published",
        )
        .group_by(models.House.host_id)
        .all()
    )
    return {host_id: count for host_id, count in rows}


def _seller_kind_map(db: Session, user_ids: list[int]) -> dict[int, str]:
    """Nhãn vai trò SUY RA TỪ TIN (0075) cho CẢ DANH SÁCH — một truy vấn.

    'broker' nếu có ít nhất một tin họ TỰ KHAI là đăng hộ/môi giới; 'owner' nếu
    mọi tin đã khai đều là chủ nhà tự đăng; '' nếu chưa tin nào được khai (toàn
    bộ tin cũ trước 0075) — lúc đó app KHÔNG hiển thị nhãn gì.

    Vì sao "có một tin broker là broker": một người đăng hộ dù chỉ một căn thì
    với khách, họ vẫn là người trung gian ở căn đó. Nói ngược lại (gọi họ là
    chủ nhà) mới là điều nguy hiểm.

    Gộp cả danh sách vào một GROUP BY: trang chủ hỏi nhãn của 12 người một lúc,
    hỏi lẻ từng người là 12 lượt đi DB cho một thứ chỉ để in cái chip.
    """
    if not user_ids:
        return {}
    rows = (
        db.query(
            models.House.host_id,
            models.House.seller_type,
            func.count(models.House.id),
        )
        .filter(
            models.House.host_id.in_(user_ids),
            models.House.status == "published",
        )
        .group_by(models.House.host_id, models.House.seller_type)
        .all()
    )
    theo_nguoi: dict[int, set[str]] = {}
    for host_id, kind, n in rows:
        if kind and n:
            theo_nguoi.setdefault(host_id, set()).add(kind)
    out: dict[int, str] = {}
    for host_id in user_ids:
        kinds = theo_nguoi.get(host_id, set())
        out[host_id] = "broker" if "broker" in kinds else (
            "owner" if "owner" in kinds else ""
        )
    return out


def _seller_kind(db: Session, user_id: int, user=None) -> str:
    """Nhãn vai trò của MỘT người — xem [_seller_kind_map].

    Tài khoản `account_type='sale'` luôn là 'broker' bất kể tin đã khai gì:
    nhãn suy từ tin chỉ có tác dụng với tài khoản chưa khai vai trò, còn đây là
    khai báo tường minh ở tầng tài khoản.
    """
    if user is not None and getattr(user, "account_type", "") == "sale":
        return "broker"
    return _seller_kind_map(db, [user_id]).get(user_id, "")


def _area_count(db: Session, user_id: int) -> int:
    """Số KHU VỰC (quận/huyện) người này có tin — "địa bàn" của môi giới."""
    return (
        db.query(func.count(distinct(models.House.district)))
        .filter(
            models.House.host_id == user_id,
            models.House.status == "published",
            models.House.district != "",
        )
        .scalar()
    ) or 0


def _deal_count(db: Session, user_id: int) -> int:
    """Số giao dịch ĐÃ ĐƯỢC CHỦ NHÀ XÁC NHẬN.

    Chỉ đếm `confirmed`. Sale không tạo được bản ghi này (khách tạo, chủ nhà
    duyệt) nên con số không tự thổi lên được — đó là toàn bộ giá trị của nó.
    """
    return (
        db.query(func.count(models.Deal.id))
        .filter(models.Deal.sale_id == user_id, models.Deal.status == "confirmed")
        .scalar()
    ) or 0


def _chuyen_mon(db: Session, user_id: int, limit: int = 5) -> list[str]:
    """Loại BĐS người này hay đăng — suy từ tin đang đăng, không tự khai.

    Tự khai thì ai cũng chọn hết mọi loại; suy từ tin thì nó phản ánh việc họ
    thật sự làm.
    """
    rows = (
        db.query(models.Category.name, func.count(models.House.id).label("n"))
        .join(models.House, models.House.category_id == models.Category.id)
        .filter(
            models.House.host_id == user_id,
            models.House.status == "published",
        )
        .group_by(models.Category.name)
        .order_by(desc("n"))
        .limit(limit)
        .all()
    )
    return [r[0] for r in rows if r[0]]


def _du_an_phan_phoi(db: Session, user_id: int, limit: int = 3) -> list[str]:
    """Dự án người này đang phân phối — suy từ phòng họ được giao quản lý.

    Chỉ tính dự án đang CÔNG KHAI: dự án tắt công khai là việc nội bộ giữa sale
    và chủ nhà, không phải thành tích để trưng.
    """
    rows = (
        db.query(models.Building.name)
        .join(models.Room, models.Room.building_id == models.Building.id)
        .filter(
            models.Room.managed_by_sale_id == user_id,
            models.Building.is_public.is_(True),
        )
        .group_by(models.Building.id, models.Building.name)
        .order_by(models.Building.id)
        .limit(limit)
        .all()
    )
    return [r[0] for r in rows if r[0]]


def _khu_vuc(db: Session, user_id: int, limit: int = 3) -> list[str]:
    """Địa bàn chính — quận/huyện có nhiều tin nhất."""
    rows = (
        db.query(models.House.district, func.count(models.House.id).label("n"))
        .filter(
            models.House.host_id == user_id,
            models.House.status == "published",
            models.House.district != "",
        )
        .group_by(models.House.district)
        .order_by(desc("n"))
        .limit(limit)
        .all()
    )
    return [r[0] for r in rows if r[0]]


def _years_active(user) -> int:
    """Số năm đã tham gia nền tảng. KHÔNG phải "năm kinh nghiệm nghề" — cái đó
    là tự khai, không kiểm chứng được, nên không bịa ra."""
    created = getattr(user, "created_at", None)
    if created is None:
        return 0
    now = datetime.now(timezone.utc)
    if created.tzinfo is None:
        created = created.replace(tzinfo=timezone.utc)
    return max(0, int((now - created).days // 365))


def _host_public(user, prof, listing_count: int) -> dict:
    """Hồ sơ công khai — KHÔNG kèm email/SĐT."""
    return {
        "id": user.id,
        "name": user.name,
        "avatar_path": user.avatar_path,
        "bio": user.bio,
        "cover_path": getattr(prof, "cover_path", None) if prof else None,
        "rating": (prof.rating if prof else None),
        "review_count": (getattr(prof, "review_count", 0) if prof else 0),
        "verified": bool(getattr(prof, "verified", False)) if prof else False,
        "trusted": helpers.is_trusted_host(prof),
        "listing_count": listing_count,
        "years_active": _years_active(user),
    }


# Cache danh sách tiêu biểu: nội dung GIỐNG NHAU cho mọi khách (không cá nhân
# hoá) và đổi rất chậm (thứ hạng chỉ nhúc nhích khi có tin/đánh giá mới), trong
# khi đây là truy vấn nặng nhất của trang chủ. TTL ngắn để admin duyệt tin xong
# không phải chờ lâu mới thấy đổi.
_FEATURED_TTL_SECONDS = 300
_featured_cache: dict[int, tuple[float, list[dict]]] = {}


def _featured_query(db: Session, limit: int) -> list[dict]:
    """Xếp hạng NGAY TRONG SQL rồi mới lấy `limit` dòng.

    Bản đầu nạp TOÀN BỘ user host/admin (đo thật: 1.059 tài khoản) vào Python
    rồi sort — chạy được nhưng phí, và phình tuyến tính theo số tài khoản. Nay
    join sẵn số tin + hồ sơ host, ORDER BY dưới DB, LIMIT trước khi serialize.
    """
    listing_count = (
        db.query(
            models.House.host_id.label("host_id"),
            func.count(models.House.id).label("n"),
        )
        .filter(models.House.status == "published")
        .group_by(models.House.host_id)
        .subquery()
    )
    P = models.HostProfile
    rows = (
        db.query(models.User, P, listing_count.c.n)
        # INNER JOIN: không có tin đang hiển thị thì không lọt danh sách.
        .join(listing_count, listing_count.c.host_id == models.User.id)
        .outerjoin(P, P.user_id == models.User.id)
        .filter(
            _la_nguoi_ban(models.User),
            models.User.is_active == True,  # noqa: E712
        )
        .order_by(
            # "Chủ nhà tin cậy" (helpers.is_trusted_host) lên đầu — diễn lại
            # ĐÚNG ngưỡng đó bằng SQL: đã xác minh + ≥4.8 điểm + ≥5 đánh giá.
            desc(
                case(
                    (
                        and_(
                            P.verified == True,  # noqa: E712
                            func.coalesce(P.rating, 0) >= 4.8,
                            # Cỡ mẫu ĐÃ KIỂM — khớp đúng `is_trusted_host`,
                            # nếu hai chỗ lệch thì thứ hạng trang chủ nói một
                            # đằng, huy hiệu trang cá nhân nói một nẻo.
                            func.coalesce(P.verified_review_count, 0) >= 5,
                        ),
                        1,
                    ),
                    else_=0,
                )
            ),
            desc(func.coalesce(P.rating, 0)),
            desc(func.coalesce(P.review_count, 0)),
            desc(listing_count.c.n),
            models.User.id.asc(),  # chốt thứ tự để phân trang/cache ổn định
        )
        .limit(limit)
        .all()
    )
    kinds = _seller_kind_map(db, [u.id for u, _p, _n in rows])
    out = []
    for u, prof, n in rows:
        body = _host_public(u, prof, n)
        # TỰ KHAI — client hiển thị kèm "(tự khai)", KHÔNG phải "đã xác minh".
        body["seller_kind"] = (
            "broker"
            if getattr(u, "account_type", "") == "sale"
            else kinds.get(u.id, "")
        )
        out.append(body)
    return out



def _dieu_kien_chu_nha(User):
    """Điều kiện SQL: tài khoản này là CHỦ NHÀ do một sale tìm ra.

    Nhận diện bằng BẰNG CHỨNG, không bằng `role`. Cột `role='host'` mang nghĩa
    "được vào khu quản lý" và có lịch sử lẫn lộn — nhiều tài khoản bán hàng
    thường mang nó chỉ vì từng bấm nhầm một nút. Chặn theo role thì trang bán
    hàng hợp lệ của họ tắt ngóm, mà đó không phải người R2 bảo vệ.

    Hai bằng chứng, đều là bản ghi thật:
      1. đã NHẬN BÀN GIAO một toà (`buildings.claimed_at`)
      2. đã từng LIÊN KẾT với một sale (`sale_owner_links`), kể cả đã ngắt
    """
    return or_(
        exists().where(
            and_(
                models.Building.host_id == User.id,
                models.Building.claimed_at.isnot(None),
            )
        ),
        exists().where(
            and_(
                models.SaleOwnerLink.owner_id == User.id,
            )
        ),
    )


def _la_chu_nha(db: Session, user) -> bool:
    co = (
        db.query(models.Building.id)
        .filter(
            models.Building.host_id == user.id,
            models.Building.claimed_at.isnot(None),
        )
        .first()
    )
    if co:
        return True
    return (
        db.query(models.SaleOwnerLink.id)
        .filter(
            models.SaleOwnerLink.owner_id == user.id,
        )
        .first()
        is not None
    )


def _duoc_xem_chu_nha(db: Session, chu_id: int, claims: Optional[dict]) -> bool:
    """Luật R2 — thông tin chủ nhà là TÀI SẢN RIÊNG của sale tìm ra họ.

    Ba nhóm được xem: chính chủ · sale đang phụ trách · admin. Người khác không
    được, kể cả sale khác: mở ra là ai cũng đọc danh sách chủ nhà rồi gọi thẳng,
    và sale không còn lý do đưa chủ nhà lên nền tảng.
    """
    if not claims:
        return False
    if claims.get("role") == "admin":
        return True
    uid = claims.get("sub")
    if uid == chu_id:
        return True
    # Chỉ liên kết scoped trên toà đang thuộc chủ này mới cấp quyền.
    co_lk = (
        db.query(models.SaleOwnerLink.id)
        .join(models.Building, models.Building.id == models.SaleOwnerLink.building_id)
        .filter(
            models.Building.host_id == chu_id,
            models.SaleOwnerLink.sale_id == uid,
            models.SaleOwnerLink.owner_id == chu_id,
            models.SaleOwnerLink.status == "active",
        )
        .first()
    )
    if co_lk:
        return True
    # Quan hệ SALE–TOÀ (sale bàn giao toà cho chủ nhà này). Hai thứ khác nhau:
    # liên kết người có thể chưa lập, mà toà thì đã bàn giao rồi.
    co_toa = (
        db.query(models.Building.id)
        .filter(
            models.Building.host_id == chu_id,
            models.Building.sale_id == uid,
            ~exists().where(
                models.SaleOwnerLink.building_id == models.Building.id,
                models.SaleOwnerLink.status == "active",
            ),
        )
        .first()
    )
    return co_toa is not None


def _chan_neu_la_chu_nha(db: Session, user, claims: Optional[dict]) -> None:
    """404 chứ không 403 — 403 xác nhận tài khoản này tồn tại và là chủ nhà,
    đủ để quét id mà dựng danh sách chủ nhà."""
    if _la_chu_nha(db, user) and not _duoc_xem_chu_nha(db, user.id, claims):
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")


@router.get("/featured")
def featured_hosts(limit: int = 12, db: Session = Depends(get_db)):
    """Môi giới/chủ nhà tiêu biểu — public.

    Điều kiện lọt danh sách: đang hoạt động, vai host/admin và CÓ ÍT NHẤT 1 tin
    đang hiển thị (người chưa đăng tin nào thì trưng ra là rỗng, vô nghĩa).
    Xếp hạng: tin cậy → điểm → số đánh giá → số tin.
    """
    limit = max(1, min(limit, 50))
    now = time.monotonic()
    hit = _featured_cache.get(limit)
    if hit is not None and now - hit[0] < _FEATURED_TTL_SECONDS:
        return {"hosts": hit[1]}
    items = _featured_query(db, limit)
    _featured_cache[limit] = (now, items)
    return {"hosts": items}


@router.get("/sales")
def public_sales(
    q: str = "",
    limit: int = 20,
    offset: int = 0,
    db: Session = Depends(get_db),
):
    """Danh bạ Sale công khai, độc lập với việc Sale đã đăng nhà hay chưa.

    Tìm theo tên là gần đúng; tìm theo email chỉ khớp chính xác. Email được
    dùng để định danh trong truy vấn nhưng tuyệt đối không xuất hiện trong
    response, tránh biến danh bạ thành nguồn thu thập địa chỉ email.
    """
    term = q.strip()
    limit = max(1, min(limit, 50))
    offset = max(0, offset)
    U, S, P = models.User, models.SaleProfile, models.HostProfile
    query = (
        db.query(U, S, P)
        .join(S, S.user_id == U.id)
        .outerjoin(P, P.user_id == U.id)
        .filter(U.is_active == True, ~_dieu_kien_chu_nha(U))  # noqa: E712
    )
    if term:
        normalized = term.lower()
        if "@" in normalized:
            query = query.filter(func.lower(U.email) == normalized)
        else:
            pattern = f"%{normalized}%"
            query = query.filter(
                or_(
                    func.lower(U.name).like(pattern),
                    func.lower(func.coalesce(S.display_name, "")).like(pattern),
                )
            )

    total = query.count()
    rows = (
        query.order_by(
            desc(func.coalesce(S.verified, False)),
            desc(func.coalesce(P.rating, 0)),
            U.name.asc(),
            U.id.asc(),
        )
        .offset(offset)
        .limit(limit)
        .all()
    )
    counts = _house_count_map(db, [u.id for u, _s, _p in rows])
    sales = []
    for user, sale, profile in rows:
        body = _host_public(user, profile, counts.get(user.id, 0))
        body.update(
            {
                "name": sale.display_name or user.name,
                "avatar_path": sale.avatar_path or user.avatar_path,
                "bio": sale.bio or user.bio,
                "verified": bool(sale.verified or getattr(profile, "verified", False)),
                "trusted": bool(sale.trusted or helpers.is_trusted_host(profile)),
                "seller_kind": "broker",
                "service_areas": list(sale.service_areas or []),
            }
        )
        sales.append(body)
    return {"sales": sales, "total": total, "limit": limit, "offset": offset}


@router.get("/{user_id}")
def host_public_profile(
    user_id: int,
    db: Session = Depends(get_db),
    claims: Optional[dict] = Depends(auth.optional_user),
):
    """Hồ sơ công khai 1 chủ nhà/môi giới — public, không PII.

    "Công khai" ở đây là với NGƯỜI BÁN. Hồ sơ CHỦ NHÀ bị khoá theo R2 —
    xem `_duoc_xem_chu_nha`.
    """
    user = db.get(models.User, user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    _chan_neu_la_chu_nha(db, user, claims)
    prof = (
        db.query(models.HostProfile)
        .filter(models.HostProfile.user_id == user_id)
        .first()
    )
    counts = _house_count_map(db, [user_id])
    body = _host_public(user, prof, counts.get(user_id, 0))
    body["area_count"] = _area_count(db, user_id)
    body["deal_count"] = _deal_count(db, user_id)
    body["specialties"] = _chuyen_mon(db, user_id)
    body["main_areas"] = _khu_vuc(db, user_id)
    # Giờ phản hồi trung bình — có sẵn ở 1.053/1.054 hồ sơ nhưng chưa ai trả ra.
    body["avg_response_hours"] = (
        getattr(prof, "avg_response_hours", None) if prof else None
    )
    # Cỡ mẫu đi kèm MỌI con số uy tín. Client dùng nó để quyết định có hiện huy
    # hiệu hay không — số trung bình trên 0 lần đo thì không phải là số đo.
    body["response_sample"] = getattr(prof, "response_sample", 0) if prof else 0
    body["verified_review_count"] = (
        getattr(prof, "verified_review_count", 0) if prof else 0
    )
    # TỰ KHAI — client phải hiển thị kèm chữ "(tự khai)", KHÔNG phải "đã xác minh".
    body["seller_kind"] = _seller_kind(db, user_id, user)

    # Liên hệ trực tiếp (migration 0088). Lọc Ở ĐÂY chứ không trả số rồi để
    # client tự giấu: client giấu thì `curl` vẫn đọc được.
    #
    # KHÔNG trả khoá `phone: null` khi tắt — bỏ HẲN khoá. `TestKhongRoPII` canh
    # đúng sự CÓ MẶT của khoá, và một khoá vắng mặt thì không có cách nào rò.
    cho_goi = bool(getattr(prof, "show_phone", False)) if prof else False
    if cho_goi and user.phone:
        body["phone"] = user.phone
    zalo = (getattr(prof, "zalo", None) or "").strip() if prof else ""
    if zalo:
        body["zalo"] = zalo
    facebook = (getattr(prof, "facebook", None) or "").strip() if prof else ""
    if facebook:
        body["facebook"] = facebook
    # "Đang phân phối" — SUY TỪ dự án người này đang quản lý, không tự khai.
    #
    # Cột `host_profiles.agency` (mig 0089) vẫn còn nhưng KHÔNG dùng để hiển
    # thị nữa: nó là ô chữ tự do 200 ký tự, ai cũng gõ được "CBRE" hay
    # "Vinhomes", mà dòng đó lại nằm ngay cạnh tick xanh nên khách đọc thành
    # "đã xác minh". Dự án đang quản lý thì kiểm được — nó là bản ghi thật
    # trong `rooms.managed_by_sale_id`.
    du_an = _du_an_phan_phoi(db, user_id)
    if du_an:
        body["distributing"] = du_an
    return body


@router.get("/{user_id}/reviews")
def host_reviews(
    user_id: int,
    limit: int = 10,
    db: Session = Depends(get_db),
    claims: Optional[dict] = Depends(auth.optional_user),
):
    """Nhận xét khách hàng — gộp review của MỌI tin người này đang đăng.

    Review vốn gắn theo từng tin (`/api/houses/{id}/reviews`); trang hồ sơ cần
    nhìn cả người nên phải gộp ở đây. Public, chỉ tên + ảnh người đánh giá.
    """
    # Cùng cổng R2 với hồ sơ: bỏ sót ở đây thì vẫn dò ra chủ nhà qua nhận xét
    # trên tin của họ (có tiêu đề tin, đủ để lần ra người).
    nguoi = db.get(models.User, user_id)
    if nguoi is not None:
        _chan_neu_la_chu_nha(db, nguoi, claims)
    limit = max(1, min(limit, 50))
    rows = (
        db.query(models.Review, models.House.title, models.User)
        .join(models.House, models.Review.house_id == models.House.id)
        .outerjoin(models.User, models.Review.user_id == models.User.id)
        .filter(models.House.host_id == user_id)
        .order_by(models.Review.created_at.desc())
        .limit(limit)
        .all()
    )
    return {
        "reviews": [
            {
                "id": r.id,
                "rating": r.rating,
                "comment": r.comment,
                "created_at": r.created_at.isoformat(),
                "house_id": r.house_id,
                "house_title": house_title,
                "user_name": u.name if u else None,
                "user_avatar": u.avatar_path if u else None,
            }
            for r, house_title, u in rows
        ]
    }
