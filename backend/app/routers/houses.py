from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query, Request
from sqlalchemy import String, cast, func, or_, select
from sqlalchemy.orm import Session

from app import auth, helpers, models
from app.house_status import HouseStatus
from app.config import settings
from app.database import get_db
from app.deps import require_geo_search, require_postgis
from app.middleware.rate_limit import limiter
from app.repositories.host_profile_repository import HostProfileRepository
from app.schemas.host_profile import HostProfileCreate
from app.schemas.house_search import HouseNearbyResponse, PlaceRef
from app.services import house_search_service, luot_xem_tin
from app.services import tin_ngan_han, nominatim_proxy, provinces_service

router = APIRouter(prefix="/api/houses", tags=["houses"])

# ── Tiền kiểm tin BÁN: HẬU KIỂM là mặc định, tiền kiểm chỉ cho ca dị thường ──
# Lịch sử: ngưỡng cũ 2 tỷ chặn ~100% tin bán thật (giá nhà VN 2–10 tỷ) → tin vào
# hàng chờ, không ai trực duyệt, chủ nhà tưởng app lỗi. Giai đoạn này nguồn cung
# tin quan trọng hơn kiểm duyệt → cho lên ngay, admin ẩn sau nếu sai.
SALE_REVIEW_THRESHOLD = 50_000_000_000  # 50 tỷ: chỉ chặn tin giá dị thường
_VALID_LEGAL = ("red_book", "pink_book", "sale_contract", "pending")


def _province_code_for(city: str | None) -> str | None:
    """Chuẩn hoá city free-text → slug tỉnh (province_code). None nếu không khớp."""
    return provinces_service.province_slug_for_city(city)


def _sale_needs_review(db: Session, *, user_id: int, price: float) -> bool:
    """Tin BÁN có cần admin duyệt trước khi công khai?

    Mặc định KHÔNG (hậu kiểm) — chỉ chặn 2 ca dị thường để không giết nguồn cung:
      1. Giá >= [SALE_REVIEW_THRESHOLD] → tin giá ảo / nhập sai đơn vị.
      2. Tài khoản đã từng có tin bị TỪ CHỐI → tái phạm, cần soi lại.

    CỐ Ý KHÔNG chặn "tài khoản mới": ca phổ biến nhất là người vừa đăng ký rồi
    đăng tin bán đầu tiên — chặn nhóm này chính là bug cũ ở hình thái khác.
    """
    if price >= SALE_REVIEW_THRESHOLD:
        return True

    has_rejected = (
        db.query(models.House.id)
        .filter(
            models.House.host_id == user_id,
            models.House.status == HouseStatus.REJECTED,
        )
        .first()
        is not None
    )
    return has_rejected


# 0075 — ai đăng tin (TỰ KHAI, không xác minh giấy tờ).
_VALID_SELLER_TYPES = ("owner", "broker")

# product_type hợp lệ. 'industrial' (BĐS công nghiệp, P3) chỉ nhận khi cờ bật.
_VALID_PRODUCT_TYPES = ("apartment", "boarding_house", "homestay", "industrial")

# Hướng nhà (phong thuỷ) — 8 hướng. Dùng chung cho filter + create/update.
_VALID_DIRECTIONS = (
    "east", "west", "south", "north",
    "northeast", "southeast", "northwest", "southwest",
)


def _csv(v: str | None) -> list[str]:
    """'a,b , c' -> ['a','b','c']; None/'' -> []."""
    if not v:
        return []
    return [s.strip() for s in v.split(",") if s.strip()]


def _clean_industrial_attrs(raw: object) -> dict | None:
    """Chuẩn hoá thuộc tính KCN từ body (không tin client). Bỏ field lạ, ép kiểu.

    Shape chuẩn: {area_ha: float, power_mva: float, fire_safety: bool, kcn_legal: str}.
    Trả None nếu không có gì hợp lệ (tin thường)."""
    if not isinstance(raw, dict):
        return None
    out: dict = {}
    for key in ("area_ha", "power_mva"):
        val = raw.get(key)
        if isinstance(val, (int, float)) and val >= 0:
            out[key] = float(val)
    if isinstance(raw.get("fire_safety"), bool):
        out["fire_safety"] = raw["fire_safety"]
    legal = raw.get("kcn_legal")
    if isinstance(legal, str) and legal.strip():
        out["kcn_legal"] = legal.strip()[:200]
    return out or None


def _nearby_category_ids(
    db, group: str, category_ids_csv: str | None
) -> list[int] | None:
    """Gộp `group` + `categoryIds` thành danh sách id cho nhánh tìm-gần-đây.

    Nhánh đó dùng SQL thô nên không dùng lại được các filter ORM phía trên; nếu
    không truyền xuống thì lọc theo nhóm sẽ im lặng không có tác dụng khi người
    dùng bật "quanh đây".

    Trả về:
      * None  → KHÔNG lọc theo loại (người dùng không chọn gì).
      * [ids] → lọc đúng các id đó.
      * [0]   → giao của group và categoryIds RỖNG (vd chọn nhóm Kinh doanh
                nhưng categoryIds còn sót loại thuộc nhóm khác). Phải trả sentinel
                không khớp gì, KHÔNG trả [] — list rỗng là falsy nên tầng dưới sẽ
                bỏ qua bộ lọc và trả về TOÀN BỘ nhà quanh đó, tức là âm thầm cho
                kết quả sai thay vì "không có kết quả".
    """
    ids: list[int] = [int(c) for c in _csv(category_ids_csv) if c.isdigit()]
    if not group:
        return ids or None
    grp = [
        r[0]
        for r in db.query(models.Category.id)
        .filter(models.Category.group_key == group)
        .all()
    ]
    if not ids:
        return grp or [0]
    giao = [i for i in ids if i in grp]
    return giao or [0]


@router.get("")
def list_houses(
    query: str = "",
    categoryId: int = 0,
    minPrice: float = 0,
    maxPrice: float = 0,
    minArea: float = 0,
    maxArea: float = 0,
    status: str = "",
    hostId: int = 0,
    showFull: bool = False,
    limit: int = 0,
    offset: int = 0,
    # ── Geo-search (optional; mặc định = hành vi cũ) ──────────────────────────
    province: str = "",
    district: str | None = None,
    near_lat: float | None = None,
    near_lng: float | None = None,
    radius_km: float = 5.0,
    sort: str = "",
    # ── Listing v2 filters (D1, D4, D10) ─────────────────────────────────────
    transaction_type: str | None = None,
    is_trusted: str | None = None,
    ward_slug: str | None = None,
    # ── BĐS công nghiệp P3 — lọc theo product_type ('industrial' để duyệt tin CN)
    product_type: str | None = None,
    # ── Tìm kiếm nâng cao (0071) — tất cả optional, null-safe với tin cũ ───────
    categoryIds: str | None = None,   # F1: nhiều loại hình, CSV id (vd "1,3,6")
    group: str = "",                  # 0074: nhóm master (stay_long|stay_short|business)
    direction: str | None = None,     # F2: hướng nhà, CSV slug (vd "east,south")
    minBedrooms: int = 0,             # số phòng ngủ tối thiểu (chip 1/2/3/4+)
    minRating: float = 0,             # F3: điểm đánh giá tối thiểu (rating_avg)
    minQualityStar: int = 0,          # F3: sao chất lượng tối thiểu (verified→self)
    amenities: str | None = None,     # F3: tiện ích BẮT BUỘC có đủ, CSV
    claims: Optional[dict] = Depends(auth.optional_user),
    db: Session = Depends(get_db),
):
    # D3: backward-compat alias — client gửi status=approved → map sang published.
    if status == HouseStatus.APPROVED_LEGACY:
        status = HouseStatus.PUBLISHED

    # AUTHZ: chỉ admin (hoặc host xem tin của chính mình) được xem non-published.
    # Ẩn danh/khách khác không liệt kê được pending/rejected → ép về published.
    _is_admin = bool(claims) and claims.get("role") == "admin"
    _own_scope = hostId > 0 and bool(claims) and claims.get("sub") == hostId
    if not _is_admin and not _own_scope and status not in ("", HouseStatus.PUBLISHED):
        status = HouseStatus.PUBLISHED

    # Nhánh nearby: chỉ khi có toạ độ + feature flag bật + DB là PostGIS.
    use_nearby = (
        near_lat is not None and near_lng is not None and settings.geo_search_enabled
    )
    if use_nearby:
        require_postgis()  # 503 GEO_DB_UNAVAILABLE nếu đang SQLite
        return house_search_service.query_nearby(
            db,
            near_lat=near_lat,
            near_lng=near_lng,
            radius_km=radius_km,
            status=status,
            show_full=showFull,
            host_id=hostId,
            category_id=categoryId,
            category_ids=_nearby_category_ids(db, group, categoryIds),
            short_stay_only=group == "stay_short",
            min_price=minPrice,
            max_price=maxPrice,
            min_area=minArea,
            max_area=maxArea,
            query=query,
            province=province,
            district=district,
            transaction_type=transaction_type,
            # Cùng bộ lọc nâng cao với nhánh thường bên dưới — thiếu ở đây thì
            # bật "quanh đây" là các tiêu chí này im lặng biến mất.
            min_bedrooms=minBedrooms,
            directions=[d for d in _csv(direction) if d in _VALID_DIRECTIONS],
            is_trusted=(
                None if is_trusted is None
                else is_trusted.lower() in ("true", "1", "yes")
            ),
            min_rating=minRating,
            min_quality_star=minQualityStar,
            sort=sort or "near_trust",
            limit=limit if limit > 0 else 50,
            offset=offset,
        )

    q = db.query(models.House)

    if status == "all":
        pass
    elif status:
        q = q.filter(models.House.status == status)
    else:
        q = q.filter(models.House.status == HouseStatus.PUBLISHED)

    if hostId > 0:
        q = q.filter(models.House.host_id == hostId)
    elif not showFull:
        q = q.filter(models.House.available_units > 0)

    if categoryId > 0:
        q = q.filter(models.House.category_id == categoryId)

    # 0074 — lọc theo NHÓM master. Dùng subquery id thay vì join để không đổi
    # hình dạng câu lệnh hiện có (các filter phía dưới đều đang giả định query
    # chỉ có bảng houses).
    if group:
        _grp_ids = [
            r[0]
            for r in db.query(models.Category.id)
            .filter(models.Category.group_key == group)
            .all()
        ]
        # Nhóm rỗng/không tồn tại → trả rỗng, KHÔNG âm thầm bỏ qua bộ lọc.
        q = q.filter(models.House.category_id.in_(_grp_ids or [0]))

    if group == "stay_short":
        q = q.filter(models.House.source_room_id.in_(
            db.query(models.RoomKenh.room_id)
            .join(models.Room, models.Room.id == models.RoomKenh.room_id)
            .join(models.Building, models.Building.id == models.Room.building_id)
            .filter(models.Building.is_public.is_(True), models.Room.status != "maintenance",
                models.RoomKenh.kenh == "ngan_han", models.RoomKenh.dang_bat.is_(True),
                models.RoomKenh.trang_thai.notin_(models.RoomKenh.KET_THUC),
                or_(models.RoomKenh.gia_theo_gio > 0, models.RoomKenh.gia_qua_dem > 0,
                    models.RoomKenh.gia_theo_ngay > 0))))

    if province:
        q = q.filter(models.House.province_code == province)
    if district:
        q = q.filter(
            or_(
                models.House.district_code == district,
                models.House.district.ilike(f"%{district}%"),
            )
        )

    # ── Listing v2 filters ────────────────────────────────────────────────────
    if transaction_type in ("rent", "sale"):
        q = q.filter(models.House.transaction_type == transaction_type)
    if is_trusted is not None:
        _trusted_val = is_trusted.lower() in ("true", "1", "yes")
        q = q.filter(models.House.is_trusted == _trusted_val)
    if ward_slug:
        q = q.filter(
            or_(
                models.House.ward_slug == ward_slug,
                models.House.ward_slug_legacy == ward_slug,
            )
        )
    # BĐS công nghiệp: lọc theo loại tin (cột product_type có index).
    if product_type in _VALID_PRODUCT_TYPES:
        q = q.filter(models.House.product_type == product_type)

    if query:
        like = f"%{query.lower()}%"
        q = q.filter(
            or_(
                models.House.title.ilike(like),
                models.House.description.ilike(like),
                models.House.city.ilike(like),
                models.House.district.ilike(like),
                models.House.address.ilike(like),
            )
        )

    if minPrice > 0:
        q = q.filter(models.House.price >= minPrice)
    if maxPrice > 0:
        q = q.filter(models.House.price <= maxPrice)
    if minArea > 0:
        q = q.filter(models.House.area >= minArea)
    if maxArea > 0:
        q = q.filter(models.House.area <= maxArea)
    # Lọc theo số phòng ngủ — CỘNG DỒN với loại hình/giá/diện tích, không thay
    # thế cái nào. Tin cũ có bedrooms=0 (mặc định cột) nên minBedrooms>0 sẽ loại
    # chúng ra: đúng ý người dùng, họ đang hỏi "nhà có ít nhất N phòng".
    if minBedrooms > 0:
        q = q.filter(models.House.bedrooms >= minBedrooms)

    # ── Tìm kiếm nâng cao (0071) — mọi filter chỉ áp KHI có tham số ───────────
    # F1: nhiều loại hình (ghi đè categoryId đơn nếu có).
    _cat_ids = [int(c) for c in _csv(categoryIds) if c.isdigit()]
    if _cat_ids:
        q = q.filter(models.House.category_id.in_(_cat_ids))
    # F2: hướng nhà (chỉ tin ĐÃ khai đúng hướng; tin cũ direction=null tự loại KHI lọc).
    _dirs = [d for d in _csv(direction) if d in _VALID_DIRECTIONS]
    if _dirs:
        q = q.filter(models.House.direction.in_(_dirs))
    # F3: điểm đánh giá tối thiểu = UY TÍN CỦA CHỦ (trung bình mọi review trên TẤT
    # CẢ tin của chủ đó — host_profiles.rating), KHÔNG phải rating riêng 1 tin.
    # Subquery tương quan theo host_id; null (chủ chưa có đánh giá) tự loại khi lọc.
    host_rating_sq = (
        select(models.HostProfile.rating)
        .where(models.HostProfile.user_id == models.House.host_id)
        .correlate(models.House)
        .scalar_subquery()
    )
    if minRating > 0:
        q = q.filter(host_rating_sq >= minRating)
    # F3: sao chất lượng tối thiểu — ưu tiên verified, fallback self, coi null=0.
    if minQualityStar > 0:
        q = q.filter(
            func.coalesce(
                models.House.quality_verified_star,
                models.House.quality_self_star,
                0,
            ) >= minQualityStar
        )
    # F3: tiện ích — nhà phải chứa ĐỦ các tiện ích chọn (khớp tên trong JSON text).
    for _am in _csv(amenities):
        q = q.filter(cast(models.House.amenities, String).ilike(f"%{_am}%"))

    total = q.count()

    # ── Sắp xếp ───────────────────────────────────────────────────────────────
    if sort == "rating":
        # Sắp theo UY TÍN CHỦ (rating tổng trên mọi tin), null xuống cuối.
        q = q.order_by(
            func.coalesce(host_rating_sq, 0).desc(),
            models.House.created_at.desc(),
        )
    elif sort == "trust":
        q = q.order_by(
            models.House.is_trusted.desc(),
            func.coalesce(models.House.quality_verified_star, 0).desc(),
            func.coalesce(host_rating_sq, 0).desc(),
            models.House.created_at.desc(),
        )
    elif sort == "price_asc":
        q = q.order_by(models.House.price.asc())
    elif sort == "price_desc":
        q = q.order_by(models.House.price.desc())
    else:
        q = q.order_by(models.House.created_at.desc())
    if limit > 0:
        q = q.limit(limit)
    if offset > 0:
        q = q.offset(offset)

    ds = q.all()
    # Nạp Category/User/HostProfile cho CẢ trang bằng 3 truy vấn — không có
    # dòng này thì mỗi tin tốn thêm 3 truy vấn (20 tin = 62 truy vấn / 82ms).
    tra_cuu = helpers.nap_san_cho_tin(db, ds)
    out = [helpers.house_to_dict(db, h, tra_cuu) for h in ds]

    return {"houses": out, "total": total}


@router.get("/search-nearby", response_model=HouseNearbyResponse)
@limiter.limit("120/hour")
async def search_houses_near_place(
    request: Request,
    place: str = Query(..., min_length=1, max_length=200, description="Địa danh / địa chỉ"),
    radius_km: float = Query(3.0, ge=0.1, le=50),
    categoryId: int = 0,
    group: str = "",
    minPrice: float = 0,
    maxPrice: float = 0,
    minArea: float = 0,
    maxArea: float = 0,
    transaction_type: str | None = None,
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    _flag: None = Depends(require_geo_search),
    _pg: None = Depends(require_postgis),
):
    """Geocode 'place' (Nominatim) → trả nhà 'approved' trong bán kính, sort khoảng cách.

    Nominatim không có kết quả → houses rỗng + place=None (không phải lỗi).
    """
    try:
        hits = await nominatim_proxy.search(place, limit=1)
    except Exception as exc:  # noqa: BLE001 — degrade, không để 5xx lan ra UI
        raise HTTPException(
            status_code=502,
            detail={"code": "NOMINATIM_ERROR", "message": f"Dịch vụ tìm kiếm lỗi: {exc}"},
        ) from exc

    if not hits:
        return HouseNearbyResponse(houses=[], total=0, place=None)

    lat, lng = float(hits[0]["lat"]), float(hits[0]["lon"])
    result = house_search_service.query_nearby(
        db,
        near_lat=lat,
        near_lng=lng,
        radius_km=radius_km,
        category_id=categoryId,
        category_ids=_nearby_category_ids(db, group, None),
        short_stay_only=group == "stay_short",
        min_price=minPrice,
        max_price=maxPrice,
        min_area=minArea,
        max_area=maxArea,
        transaction_type=transaction_type,
        sort="distance",
        limit=limit,
        offset=offset,
    )
    return HouseNearbyResponse(
        houses=result["houses"],
        total=result["total"],
        place=PlaceRef(display_name=hits[0].get("display_name", ""), lat=lat, lng=lng),
    )


@router.get("/{house_id}")
def get_house(
    house_id: int,
    db: Session = Depends(get_db),
    claims: Optional[dict] = Depends(auth.optional_user),
):
    h = db.get(models.House, house_id)
    if not h:
        raise HTTPException(404, "Không tìm thấy")

    # Đếm lượt xem THẬT (0090). Không tính lượt chủ tin tự mở — nếu tính thì
    # "42 lượt xem" phần lớn là chính họ bấm vào kiểm tra, và con số đó vô nghĩa.
    nguoi_xem = claims.get("sub") if claims else None
    if nguoi_xem != h.host_id:
        h.view_count = (h.view_count or 0) + 1
        # Theo ngày cho biểu đồ "Hiệu quả bài đăng" của sale (0135).
        luot_xem_tin.ghi_luot_xem(db, h.id)
        db.commit()

    d = helpers.house_to_dict(db, h)
    return {"house": d}


@router.post("", status_code=201)
def create_house(
    body: dict = Body(...),
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
):
    # Mọi tài khoản đã đăng nhập đều đăng tin được, và ĐĂNG TIN KHÔNG ĐỔI VAI.
    # Trước 07/09/2026 chỗ này tự nâng `role` lên 'host' + tạo HostProfile + trả
    # JWT mới ngay ở tin đầu tiên: người bán đăng một tin là thanh tab và trang
    # cá nhân đổi hẳn mà không hề yêu cầu. Nó trộn ĐĂNG TIN (việc của sale) với
    # VẬN HÀNH NHÀ (hợp đồng, khách thuê, hoá đơn, công tơ) — hai việc khác nhau.
    # Nay 'host' chỉ đến từ việc thật sự nhận quản lý nhà (host_profile,
    # building_claim, sale_links). Xem tests/test_dang_tin_khong_doi_vai.py.
    # Riêng admin vẫn bị chặn — tài khoản quản trị không sở hữu tin.
    if claims.get("role") == "admin":
        raise HTTPException(403, "Admin không thể đăng tin")

    # SECURITY: host_id is taken from JWT claims, not from client body.
    # Prevents a host from creating a house under another host's ID.
    listing_type = "multi_unit" if body.get("listing_type") == "multi_unit" else "single"
    total_units = 1
    available_units = 1
    if listing_type == "multi_unit":
        total_units = max(1, int(body.get("total_units") or 1))
        available_units = int(body.get("available_units") or total_units)
        available_units = max(0, min(total_units, available_units))

    gender = body.get("gender_pref") or "any"
    if gender not in ("male", "female"):
        gender = "any"

    # D1: transaction_type 'rent'|'sale', default 'rent'.
    tx_type = body.get("transaction_type") or "rent"
    if tx_type not in ("rent", "sale"):
        tx_type = "rent"

    price_val = float(body.get("price") or 0)

    # ── BĐS công nghiệp P3 — product_type + thuộc tính KCN (gated bởi cờ) ──────
    req_product_type = (body.get("product_type") or "").strip()
    product_type = "apartment"
    industrial_attrs = None
    if req_product_type == "industrial":
        if not getattr(settings, "industrial_re_enabled", False):
            raise HTTPException(403, "Đăng tin BĐS công nghiệp chưa mở")
        product_type = "industrial"
        industrial_attrs = _clean_industrial_attrs(body.get("industrial_attrs"))
        # Tin CN là tài sản đơn, giao dịch chốt ngoài luồng thuê phòng.
        listing_type = "single"
        total_units = 1
        available_units = 1
        gender = "any"

    # SALE: bỏ các field chỉ dành cho thuê (không tin form — nullify ở backend).
    legal_status = None
    if tx_type == "sale":
        listing_type = "single"
        total_units = 1
        available_units = 1
        gender = "any"
        _ls = (body.get("legal_status") or "").strip()
        legal_status = _ls if _ls in _VALID_LEGAL else None

    # D3: default status='published' (auto-publish). Client may override only if admin.
    _is_admin_poster = claims.get("role") == "admin"
    _requested_status = body.get("status") or HouseStatus.PUBLISHED
    # Non-admin cannot set arbitrary status — clamp to published.
    post_status = _requested_status if _is_admin_poster else "published"
    # Guardrail tin BÁN — HẬU KIỂM mặc định, chỉ tiền kiểm 2 ca dị thường:
    #   (1) giá vượt ngưỡng (tin giá ảo), (2) tài khoản từng bị từ chối (tái phạm).
    # CỐ Ý không chặn "tài khoản mới" — xem docstring _sale_needs_review.
    if tx_type == "sale" and not _is_admin_poster and _sale_needs_review(
        db, user_id=claims["sub"], price=price_val
    ):
        post_status = HouseStatus.PENDING_REVIEW

    # PIPELINE của tin + hạng phòng phải chốt TRƯỚC khi ghi: thiếu hạng mà đã
    # `db.add` rồi mới 422 là để lại một tin mồ côi trong cùng giao dịch.
    kenh_tin = tin_ngan_han.kenh_cua_danh_muc(db, body.get("category_id"), tx_type)
    hang_tin = None
    if kenh_tin == models.RoomKenh.NGAN_HAN:
        ma_hang = body.get("loai_phong_id")
        if not ma_hang:
            raise HTTPException(
                422,
                "Tin lưu trú ngắn hạn phải chọn hạng phòng của một toà. "
                "Tạo hạng ở Quản lí nhà → Hạng phòng rồi đăng lại.",
            )
        hang_tin = tin_ngan_han.hang_duoc_neo(db, claims["sub"], int(ma_hang))

    h = models.House(
        host_id=claims["sub"],  # always from verified JWT
        title=body.get("title") or "",
        description=body.get("description") or "",
        category_id=int(body.get("category_id") or 0),
        price=price_val,
        area=float(body.get("area") or 0),
        address=body.get("address") or "",
        city=body.get("city") or "",
        district=body.get("district") or "",
        latitude=body.get("latitude"),
        longitude=body.get("longitude"),
        # 0075 — tự khai; giá trị lạ → rỗng (không hiển thị nhãn) thay vì đoán.
        seller_type=(
            body.get("seller_type")
            if body.get("seller_type") in _VALID_SELLER_TYPES
            else ""
        ),
        bedrooms=int(body.get("bedrooms") or 0),
        bathrooms=int(body.get("bathrooms") or 0),
        status=post_status,
        images=list(body.get("images") or []),
        amenities=list(body.get("amenities") or []),
        listing_type=listing_type,
        total_units=total_units,
        available_units=available_units,
        gender_pref=gender,
        province_code=_province_code_for(body.get("city")),
        geocode_status="geocoded" if body.get("latitude") is not None else "pending",
        transaction_type=tx_type,
        legal_status=legal_status,
        ward_slug=body.get("ward_slug") or None,
        ward_slug_legacy=body.get("ward_slug_legacy") or None,
        product_type=product_type,
        industrial_attrs=industrial_attrs,
        direction=(body.get("direction") if body.get("direction") in _VALID_DIRECTIONS else None),
        # PIPELINE của tin suy từ NHÓM DANH MỤC (`categories.group_key`).
        #
        # Trước 23/09/2026 chỗ này không đụng cột `kenh`, nên mọi tin mới — kể
        # cả Hotel/Homestay — đều nằm pipeline `dai_han`: chốt một hợp đồng
        # thuê tháng là đóng nhầm luôn tin khách sạn của cùng phòng.
        kenh=kenh_tin,
    )
    # TIN NGẮN HẠN NEO VÀO HẠNG PHÒNG, không vào một phòng lẻ: khách sạn bán
    # "Deluxe", lễ tân gán số phòng lúc nhận. Neo theo phòng thì mười phòng
    # giống hệt nhau phải đăng mười tin trùng.
    if hang_tin is not None:
        tin_ngan_han.gan_hang(db, h, hang_tin)
    db.add(h)
    db.flush()  # get h.id without committing yet

    # ĐĂNG TIN KHÔNG LÀM AI THÀNH CHỦ NHÀ.
    #
    # Trước đây chỗ này tự nâng `role` lên 'host' ngay ở tin đầu tiên. Hệ quả:
    # đăng một tin xong thì tài khoản đổi vai, app đổi luôn bộ tab và trang cá
    # nhân — người dùng không hề yêu cầu và cũng không được báo. Nó còn trộn hai
    # việc khác hẳn nhau: ĐĂNG TIN là việc của người bán, còn CHỦ NHÀ là người
    # vận hành căn nhà (hợp đồng, khách thuê, hoá đơn, công tơ).
    #
    # Nay vai 'host' chỉ đến từ những lúc thật sự nhận việc quản lý nhà:
    # tạo hồ sơ chủ nhà (`host_profile`), nhận bàn giao toà nhà
    # (`building_claim`), hoặc liên kết sale ↔ chủ phòng (`sale_links`).
    #
    # Sửa/xoá tin KHÔNG còn đòi vai host nữa (xem `update_house`), nên bỏ nâng
    # vai ở đây không làm ai mất quyền với tin của chính mình.
    new_token: str | None = None
    user_id = claims["sub"]

    repo = HostProfileRepository(db)
    if not repo.get_by_user_id(user_id):
        repo.create(HostProfileCreate(user_id=user_id), actor_id=user_id)

    db.commit()
    db.refresh(h)

    payload: dict = {"house": helpers.house_to_dict(db, h)}
    if new_token:
        payload["token"] = new_token
    return payload


@router.put("/{house_id}")
def update_house(
    house_id: int,
    body: dict = Body(...),
    # `require_user` chứ KHÔNG phải `require_host`: người bán mang role='guest'
    # nhưng vẫn phải sửa được tin của chính mình. Chốt chặn thật là kiểm chủ sở
    # hữu ngay dưới — `require_host` ở đây chỉ là lớp thừa, và còn chặn nhầm
    # đúng những người cần dùng.
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
):
    # SECURITY: ownership check — chỉ chủ tin mới sửa được tin của mình.
    h = db.get(models.House, house_id)
    if not h:
        raise HTTPException(404, "Không tìm thấy")
    if h.host_id != claims["sub"]:
        raise HTTPException(403, "Không có quyền chỉnh sửa tin này")

    # SECURITY (H1): "status" intentionally excluded — status transitions must go
    # through admin moderation endpoints, not host-owned edit. Otherwise a host
    # could re-publish a listing an admin has rejected/hidden by sending
    # {"status": "published"} in a PUT body.
    for key in [
        "title",
        "description",
        "address",
        "city",
        "district",
    ]:
        if key in body and body[key] is not None:
            setattr(h, key, body[key])

    # City thay đổi → cập nhật province_code chuẩn hoá.
    if "city" in body and body["city"] is not None:
        h.province_code = _province_code_for(body["city"])

    # D1/E8: transaction_type can only be changed within 24h of created_at.
    if "transaction_type" in body and body["transaction_type"] is not None:
        from datetime import timedelta
        from app.models import now_utc as _now_utc
        _age = _now_utc() - h.created_at
        if _age <= timedelta(hours=24):
            tx = body["transaction_type"]
            if tx in ("rent", "sale"):
                h.transaction_type = tx
        # else: silently ignore per spec

    # 0075 — sửa được BẤT KỲ LÚC NÀO (khác transaction_type bị khoá sau 24h):
    # đây là lời tự khai về vai trò người đăng, khai sai thì phải cho sửa lại
    # ngay, không có lý do gì khoá.
    if "seller_type" in body and body["seller_type"] in _VALID_SELLER_TYPES:
        h.seller_type = body["seller_type"]

    if "unit_label" in body:
        h.unit_label = str(body["unit_label"] or "").strip()[:50]

    # ward_slug / ward_slug_legacy: allowed any time.
    if "ward_slug" in body:
        h.ward_slug = body["ward_slug"] or None
    if "ward_slug_legacy" in body:
        h.ward_slug_legacy = body["ward_slug_legacy"] or None

    if "category_id" in body and body["category_id"] is not None:
        h.category_id = int(body["category_id"])
    if "price" in body and body["price"] is not None:
        h.price = float(body["price"])
    if "area" in body and body["area"] is not None:
        h.area = float(body["area"])
    if "bedrooms" in body:
        h.bedrooms = int(body["bedrooms"] or 0)
    if "bathrooms" in body:
        h.bathrooms = int(body["bathrooms"] or 0)
    if "images" in body and body["images"] is not None:
        h.images = list(body["images"])
    if "amenities" in body and body["amenities"] is not None:
        h.amenities = list(body["amenities"])
    if "direction" in body:
        _d = body["direction"]
        h.direction = _d if _d in _VALID_DIRECTIONS else None

    # BĐS công nghiệp: chỉ sửa thuộc tính KCN cho tin đã là industrial (không đổi
    # loại tin qua PUT — tránh biến tin thường thành CN lách cờ).
    if "industrial_attrs" in body and getattr(h, "product_type", None) == "industrial":
        h.industrial_attrs = _clean_industrial_attrs(body["industrial_attrs"])

    if "listing_type" in body and body["listing_type"]:
        h.listing_type = body["listing_type"]

    if h.listing_type != "multi_unit":
        h.listing_type = "single"
        h.total_units = 1
        h.available_units = 1
        h.gender_pref = "any"
    else:
        if "total_units" in body and body["total_units"] is not None:
            h.total_units = max(1, int(body["total_units"]))
        if "available_units" in body and body["available_units"] is not None:
            h.available_units = int(body["available_units"])
        h.available_units = max(0, min(h.total_units, h.available_units))
        if "gender_pref" in body:
            g = body["gender_pref"]
            h.gender_pref = g if g in ("male", "female") else "any"

    db.commit()
    db.refresh(h)
    return {"house": helpers.house_to_dict(db, h)}


@router.delete("/{house_id}")
def delete_house(
    house_id: int,
    # `require_user` chứ KHÔNG phải `require_host`: người bán mang role='guest'
    # nhưng vẫn phải sửa được tin của chính mình. Chốt chặn thật là kiểm chủ sở
    # hữu ngay dưới — `require_host` ở đây chỉ là lớp thừa, và còn chặn nhầm
    # đúng những người cần dùng.
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
):
    # SECURITY: ownership check — chỉ chủ tin mới xoá được tin của mình.
    h = db.get(models.House, house_id)
    if not h:
        raise HTTPException(404, "Không tìm thấy")
    if h.host_id != claims["sub"]:
        raise HTTPException(403, "Không có quyền xoá tin này")
    db.delete(h)
    db.query(models.ViewingAppointment).filter(models.ViewingAppointment.house_id == house_id).delete()
    db.query(models.Wishlist).filter(models.Wishlist.house_id == house_id).delete()
    db.commit()
    return {"success": True}


@router.post("/{house_id}/close-unit")
def close_unit(
    house_id: int,
    # `require_user` chứ KHÔNG phải `require_host`: người bán mang role='guest'
    # nhưng vẫn phải sửa được tin của chính mình. Chốt chặn thật là kiểm chủ sở
    # hữu ngay dưới — `require_host` ở đây chỉ là lớp thừa, và còn chặn nhầm
    # đúng những người cần dùng.
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
):
    # SECURITY: ownership check — chỉ chủ tin mới đóng được căn.
    h = db.get(models.House, house_id)
    if not h:
        raise HTTPException(404, "Không tìm thấy")
    if h.host_id != claims["sub"]:
        raise HTTPException(403, "Không có quyền thực hiện thao tác này")
    if h.available_units <= 0:
        raise HTTPException(400, "Phòng đã đủ")
    h.available_units -= 1

    pending_states = ["pending", "approved", "completed"]
    bookings = (
        db.query(models.ViewingAppointment)
        .filter(models.ViewingAppointment.house_id == house_id, models.ViewingAppointment.status.in_(pending_states))
        .all()
    )
    for b in bookings:
        b.status = "lost"
        helpers.push_notification(
            db,
            b.guest_id,
            "viewing_appointment_lost",
            "Phòng đã có người khác chốt",
            f'Phòng "{h.title}" bạn đặt lịch xem đã được cho thuê. Bạn có thể tìm phòng khác.',
            h.id,
        )

    db.commit()
    db.refresh(h)
    return {"success": True, "house": helpers.house_to_dict(db, h)}
