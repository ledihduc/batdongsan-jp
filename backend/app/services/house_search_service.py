"""Geo-search service — truy vấn nhà theo bán kính (PostGIS ST_DWithin/ST_Distance).

Chỉ chạy trên Postgres/PostGIS (nhánh nearby). Dùng raw SQL bound-param như module
planning: geom sống ở DB, không ở ORM. Tin `geom IS NULL` bị loại khỏi nearby
(không tính được khoảng cách) nhưng vẫn xuất hiện ở text/province search thường.

Chiến lược 2 bước để tái dùng helpers.house_to_dict:
  1. raw SQL → id + distance_km (đã sort + phân trang) + tổng số.
  2. load ORM House theo id, serialize bằng house_to_dict, gắn distance_km.
Giữ đúng thứ tự khoảng cách khi map lại.
"""

from __future__ import annotations

from typing import Any, Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app import helpers, models
from app.house_status import HouseStatus


def query_nearby(
    db: Session,
    *,
    near_lat: float,
    near_lng: float,
    radius_km: float,
    status: str = HouseStatus.PUBLISHED,
    show_full: bool = False,
    host_id: int = 0,
    category_id: int = 0,
    category_ids: Optional[list[int]] = None,  # 0074: nhiều loại / lọc theo nhóm
    short_stay_only: bool = False,
    min_price: float = 0,
    max_price: float = 0,
    min_area: float = 0,
    max_area: float = 0,
    query: str = "",
    province: str = "",
    district: Optional[str] = None,
    transaction_type: Optional[str] = None,
    # Nhóm nâng cao (mig 0071). Trước đây nhánh này KHÔNG nhận chúng, nên hễ
    # người dùng bật "quanh đây" là hướng nhà / uy tín / đánh giá / phòng ngủ
    # bị bỏ qua ÂM THẦM — danh sách dài ra mà không ai hiểu vì sao.
    min_bedrooms: int = 0,
    directions: Optional[list[str]] = None,
    is_trusted: Optional[bool] = None,
    min_rating: float = 0,
    min_quality_star: int = 0,
    sort: str = "distance",
    limit: int = 50,
    offset: int = 0,
) -> dict[str, Any]:
    """Trả {"houses": [...], "total": int}. Mỗi house kèm `distance_km` (km, 2 chữ số)."""
    # Điểm tâm dựng từ bind số (lng/lat) — tránh WKT string + tránh `:bind::cast`
    # (SQLAlchemy text() lỗi parse khi bind đứng ngay trước `::`). Dùng geography(...).
    pt_geom = "ST_SetSRID(ST_MakePoint(:near_lng, :near_lat), 4326)"
    where = [
        "h.geom IS NOT NULL",
        f"ST_DWithin(geography(h.geom), geography({pt_geom}), :radius_m)",
    ]
    params: dict[str, Any] = {
        "near_lng": near_lng,
        "near_lat": near_lat,
        "radius_m": radius_km * 1000.0,
    }

    # status: "" hoặc mặc định → approved; "all" → không lọc; khác → đúng status đó.
    if status == "all":
        pass
    elif status:
        where.append("h.status = :status")
        params["status"] = status
    else:
        where.append("h.status = :status")
        params["status"] = HouseStatus.PUBLISHED

    if short_stay_only:
        where.append("""EXISTS (SELECT 1 FROM room_kenh sk
            JOIN rooms sr ON sr.id = sk.room_id
            JOIN buildings sb ON sb.id = sr.building_id
            WHERE sb.is_public AND sr.status != 'maintenance' AND sk.room_id = h.source_room_id AND sk.kenh = 'ngan_han'
            AND sk.dang_bat AND sk.trang_thai NOT IN ('da_ban','da_cho_thue')
            AND (sk.gia_theo_gio > 0 OR sk.gia_qua_dem > 0 OR sk.gia_theo_ngay > 0))""")

    if host_id > 0:
        where.append("h.host_id = :host_id")
        params["host_id"] = host_id
    elif not show_full:
        where.append("h.available_units > 0")

    if category_id > 0:
        where.append("h.category_id = :category_id")
        params["category_id"] = category_id
    # 0074 — nhánh "gần đây/sort" trước đây CHỈ nhận 1 category_id, nên lọc
    # nhiều loại (categoryIds) hoặc lọc theo nhóm bị BỎ QUA ÂM THẦM ở đây trong
    # khi nhánh thường vẫn lọc. Nay nhận cả danh sách.
    # `is not None` chứ KHÔNG phải truthy: danh sách rỗng cũng là một BỘ LỌC
    # (giao rỗng → không có gì khớp). Dùng truthy thì [] bị coi như "không lọc"
    # và trả về tất cả — sai âm thầm.
    if category_ids is not None:
        keys = []
        for i, cid in enumerate(category_ids):
            key = f"cat_{i}"
            keys.append(f":{key}")
            params[key] = int(cid)
        # Danh sách rỗng → điều kiện luôn sai (không có id nào khớp).
        where.append(
            f"h.category_id IN ({', '.join(keys)})" if keys else "1 = 0"
        )
    if min_price > 0:
        where.append("h.price >= :min_price")
        params["min_price"] = min_price
    if max_price > 0:
        where.append("h.price <= :max_price")
        params["max_price"] = max_price
    if min_area > 0:
        where.append("h.area >= :min_area")
        params["min_area"] = min_area
    if max_area > 0:
        where.append("h.area <= :max_area")
        params["max_area"] = max_area

    if query:
        where.append(
            "(h.title ILIKE :like OR h.description ILIKE :like OR h.city ILIKE :like "
            "OR h.district ILIKE :like OR h.address ILIKE :like)"
        )
        params["like"] = f"%{query.lower()}%"

    if transaction_type in ("rent", "sale"):
        where.append("h.transaction_type = :transaction_type")
        params["transaction_type"] = transaction_type
    # Cùng ngữ nghĩa với nhánh thường ở routers/houses.py — hai nhánh lệch nhau
    # là lúc cùng một bộ lọc cho ra hai kết quả khác nhau tuỳ người dùng có bật
    # "quanh đây" hay không.
    if min_bedrooms > 0:
        where.append("h.bedrooms >= :min_bedrooms")
        params["min_bedrooms"] = min_bedrooms
    if directions:
        keys = []
        for i, d in enumerate(directions):
            key = f"dir_{i}"
            keys.append(f":{key}")
            params[key] = d
        where.append(f"h.direction IN ({', '.join(keys)})")
    if is_trusted is not None:
        where.append("h.is_trusted = :is_trusted")
        params["is_trusted"] = is_trusted
    # Đánh giá tối thiểu = uy tín CHỦ (host_profiles.rating), giống nhánh thường.
    # `hp` đã được LEFT JOIN sẵn cho phần sắp xếp.
    if min_rating > 0:
        where.append("COALESCE(hp.rating, 0) >= :min_rating")
        params["min_rating"] = min_rating
    if min_quality_star > 0:
        where.append(
            "COALESCE(h.quality_verified_star, h.quality_self_star, 0)"
            " >= :min_quality_star"
        )
        params["min_quality_star"] = min_quality_star

    if province:
        where.append("h.province_code = :province")
        params["province"] = province
    if district:
        where.append("(h.district_code = :district OR h.district ILIKE :district_like)")
        params["district"] = district
        params["district_like"] = f"%{district}%"

    # Sắp xếp:
    #  • "distance"    → KNN thuần (GIST <->), gần nhất trước.
    #  • "created"     → mới nhất trước.
    #  • mặc định ("", "near_trust") → GẦN + UY TÍN: lấy khoảng cách km rồi TRỪ
    #    thưởng uy tín (rating chủ ×1.5km/sao, rating tin ×0.4, tin tin-cậy −2km).
    #    → chủ/tin uy tín cao được "kéo gần lại" nổi lên đầu mà vẫn ưu tiên cự ly.
    _dist_km = f"ST_Distance(geography(h.geom), geography({pt_geom})) / 1000.0"
    if sort == "distance":
        order = f"h.geom <-> {pt_geom}, h.id"
    elif sort == "created":
        order = "h.created_at DESC, h.id DESC"
    else:
        order = (
            f"({_dist_km}"
            " - 1.5 * COALESCE(hp.rating, 0)"
            " - 0.4 * COALESCE(h.rating_avg, 0)"
            " - CASE WHEN h.is_trusted THEN 2.0 ELSE 0 END) ASC, h.id"
        )

    params["limit"] = limit if limit > 0 else 50
    params["offset"] = max(0, offset)

    sql = text(
        f"""
        SELECT h.id AS id,
               ST_Distance(geography(h.geom), geography({pt_geom})) / 1000.0 AS distance_km,
               COUNT(*) OVER() AS total_count
          FROM houses h
          LEFT JOIN host_profiles hp ON hp.user_id = h.host_id
         WHERE {' AND '.join(where)}
         ORDER BY {order}
         LIMIT :limit OFFSET :offset
        """
    )
    rows = db.execute(sql, params).mappings().all()
    total = int(rows[0]["total_count"]) if rows else 0

    ids = [r["id"] for r in rows]
    dist_by_id = {r["id"]: r["distance_km"] for r in rows}
    if not ids:
        return {"houses": [], "total": total}

    houses = db.query(models.House).filter(models.House.id.in_(ids)).all()
    by_id = {h.id: h for h in houses}
    out: list[dict] = []
    for hid in ids:  # giữ đúng thứ tự khoảng cách từ raw SQL
        h = by_id.get(hid)
        if h is None:
            continue
        d = helpers.house_to_dict(db, h)
        dist = dist_by_id.get(hid)
        d["distance_km"] = round(float(dist), 2) if dist is not None else None
        out.append(d)

    return {"houses": out, "total": total}
