"""SEED LƯU TRÚ NGẮN HẠN — để vào app đặt thử theo giờ / qua đêm / theo ngày.

Chạy trong container backend (idempotent — chạy lại chỉ cập nhật, không nhân đôi):

    docker exec -i ancu365-backend-staging python - < scripts/seed_ngan_han.py

Chạy thử không ghi gì: thêm `-e DRY=1` vào `docker exec`.

Làm gì:
  * 2 toà MỚI ở Hải Phòng + giữ 3 toà mẫu cũ (Đà Nẵng, TP.HCM, Hà Nội);
  * mọi phòng: ảnh, diện tích, sức chứa, đồ trong phòng, giá theo giờ / qua đêm /
    theo ngày trên kênh `ngan_han`;
  * mỗi phòng MỘT tin đăng `kenh='ngan_han'` do SALE đăng — khách thấy ở trang
    chủ, bấm vào là đặt được (luật: đặt ngắn hạn phải qua sale);
  * vài đơn của khách mẫu để lịch phòng không trống trơn (phần lớn giờ vẫn trống).

Toà mẫu nhận diện bằng tiền tố tên `[MẪU NGẮN HẠN]`. Dọn: xoá theo tiền tố đó.
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timedelta

from app import models
from app.database import SessionLocal
from app.services import provinces_service
from app.services import short_stay_service as stays

TIEN_TO = "[MẪU NGẮN HẠN]"
SALE = 58  # Vũ Đình Văn — sale phụ trách
CHU = 62  # Vũ Đình Văn (chủ nhà)
KHACH_MAU = (13, 14, 15)  # "Khách xem nhà 1..3" — chỉ để lịch có vài ca bận

DM_HOMESTAY, DM_HOTEL, DM_STUDIO = 10, 8, 5

_U = "https://images.unsplash.com/photo-{}?auto=format&fit=crop&w=1200&q=80"
ANH = [
    _U.format(x)
    for x in (
        "1611892440504-42a792e24d32",
        "1590490360182-c33d57733427",
        "1566665797739-1674de7a421a",
        "1582719478250-c89cae4dc85b",
        "1631049307264-da0ec9d70304",
        "1618773928121-c32242e63f39",
        "1595576508898-0ad5c879a061",
        "1522771739844-6a9f6d5f14af",
        "1540518614846-7eded433c457",
        "1505693416388-ac5ce068fe85",
        "1560448204-e02f11c3d0e2",
        "1502672260266-1c1ef2d93688",
        "1584132967334-10e028bd69f7",
        "1596394516093-501ba68a0ba6",
        "1578683010236-d716f9a3f461",
        "1560185007-cde436f6a4d0",
    )
]

# (tên, địa chỉ, quận, tỉnh, lat, lng, danh mục, [phòng])
# phòng: (mã, hạng, m², người, giờ, qua đêm, ngày, đồ trong phòng, tiện ích tin)
TOA = [
    (
        f"{TIEN_TO} Vua Nhà Homestay Lạch Tray",
        "12 Lạch Tray",
        "Ngô Quyền",
        "Tp Hải Phòng",
        20.8465,
        106.6885,
        DM_HOMESTAY,
        [
            ("LT-101", "Phòng đơn tiêu chuẩn", 18, 1, 50_000, 280_000, 350_000,
             ["giuong", "dieu_hoa", "nong_lanh", "wc_rieng"], ["Wifi 5G", "Điều hoà"]),
            ("LT-102", "Deluxe giường đôi", 25, 2, 70_000, 380_000, 480_000,
             ["giuong", "dieu_hoa", "nong_lanh", "tu_lanh", "wc_rieng"],
             ["Wifi 5G", "Điều hoà", "Bãi đỗ xe"]),
            ("LT-201", "Phòng gia đình", 35, 4, 100_000, 550_000, 700_000,
             ["giuong", "tu_quan_ao", "dieu_hoa", "nong_lanh", "tu_lanh", "ban_ghe", "wc_rieng"],
             ["Wifi 5G", "Điều hoà", "Bãi đỗ xe", "Máy giặt"]),
            ("LT-202", "Studio ban công", 30, 2, 80_000, 450_000, 560_000,
             ["giuong", "dieu_hoa", "nong_lanh", "bep", "ban_cong", "wc_rieng"],
             ["Wifi 5G", "Điều hoà", "Ban công", "Bếp đầy đủ"]),
        ],
    ),
    (
        f"{TIEN_TO} Vua Nhà Hotel Cát Bi",
        "168 Lê Hồng Phong",
        "Hải An",
        "Tp Hải Phòng",
        20.8339,
        106.7134,
        DM_HOTEL,
        [
            ("CB-301", "Superior giường đôi", 22, 2, 60_000, 350_000, 450_000,
             ["giuong", "dieu_hoa", "nong_lanh", "tu_lanh", "wc_rieng"],
             ["Wifi 5G", "Điều hoà", "An ninh 24/7"]),
            ("CB-302", "Twin hai giường", 26, 2, 70_000, 400_000, 520_000,
             ["giuong", "dieu_hoa", "nong_lanh", "tu_lanh", "ban_ghe", "wc_rieng"],
             ["Wifi 5G", "Điều hoà", "An ninh 24/7", "Bãi đỗ xe"]),
            ("CB-501", "Suite hướng sân bay", 40, 3, 150_000, 850_000, 1_100_000,
             ["giuong", "tu_quan_ao", "dieu_hoa", "nong_lanh", "tu_lanh", "ban_ghe", "ban_cong", "wc_rieng"],
             ["Wifi 5G", "Điều hoà", "Ban công", "Phòng Gym", "An ninh 24/7"]),
            ("CB-502", "Couple bồn tắm", 32, 2, 120_000, 650_000, 850_000,
             ["giuong", "dieu_hoa", "nong_lanh", "tu_lanh", "wc_rieng"],
             ["Wifi 5G", "Điều hoà", "An ninh 24/7"]),
        ],
    ),
]

# Toà mẫu cũ: chỉ bổ sung ảnh/đồ/tin, giữ nguyên giá đã có.
TOA_CU_TOA_DO = {
    "Đà Nẵng": (16.0678, 108.2208, DM_HOMESTAY),
    "TP.HCM": (10.7743, 106.7038, DM_HOTEL),
    "Hà Nội": (21.0341, 105.8372, DM_STUDIO),
}
#: Hạng phòng của toà cũ — trước đây mọi phòng đều "Phòng tiêu chuẩn", kể cả
#: penthouse 90m², nên tên tin đọc sai.
HANG_CU = {
    "P-SINGLE": "Phòng đơn",
    "P-DOUBLE": "Phòng đôi",
    "P-FAMILY": "Phòng gia đình",
    "STUDIO": "Studio",
    "VIP": "Phòng VIP",
    "FAMILY-VIP": "Gia đình VIP",
    "GARDEN-01": "Phòng sân vườn",
    "GARDEN-02": "Phòng sân vườn",
    "PENTHOUSE": "Penthouse",
}
DO_MAC_DINH = ["giuong", "dieu_hoa", "nong_lanh", "wc_rieng"]
TIEN_ICH_MAC_DINH = ["Wifi 5G", "Điều hoà"]


def _k(n: float) -> str:
    return f"{int(n // 1000)}k" if n < 1_000_000 else f"{n / 1_000_000:.1f}tr".replace(".0tr", "tr")


def _tin(db, toa, phong, kenh, lat, lng, dm, tien_ich, anh, now):
    tieu_de = (
        f"{kenh.loai_phong or 'Phòng'} · {phong.area_m2:g}m² · theo giờ từ "
        f"{_k(kenh.gia_theo_gio)} · {toa.district}, {toa.city.replace('Tp ', '')}"
    )
    mo_ta = (
        f"{toa.name.replace(TIEN_TO, '').strip()} — phòng {phong.code}, tối đa "
        f"{phong.capacity} người.\n"
        f"• Theo giờ: {_k(kenh.gia_theo_gio)}/giờ\n"
        f"• Qua đêm: {_k(kenh.gia_qua_dem)}/đêm\n"
        f"• Theo ngày: {_k(kenh.gia_theo_ngay)}/ngày\n"
        "Nhận phòng tự do theo giờ đã đặt, trả phòng qua đêm/theo ngày trước 12:00. "
        "Thanh toán tại quầy khi nhận phòng. (Dữ liệu mẫu để đặt thử.)"
    )
    h = (
        db.query(models.House)
        .filter(models.House.source_room_id == phong.id, models.House.kenh == "ngan_han")
        .order_by(models.House.id.desc())
        .first()
    )
    if h is None:
        h = models.House(
            host_id=SALE,
            source_room_id=phong.id,
            kenh="ngan_han",
            transaction_type="rent",
            product_type="homestay",
            listing_type="single",
            total_units=1,
            available_units=1,
            gender_pref="any",
            created_at=now,
        )
        db.add(h)
    h.title = tieu_de
    h.description = mo_ta
    h.category_id = dm
    h.price = float(kenh.gia_qua_dem)
    h.area = float(phong.area_m2 or 0)
    h.bedrooms = 2 if (phong.capacity or 1) >= 4 else 1
    h.bathrooms = 1
    h.address = toa.address
    h.district = toa.district
    h.city = toa.city
    h.latitude, h.longitude = lat, lng
    h.province_code = provinces_service.province_slug_for_city(toa.city)
    h.geocode_status = "geocoded"
    h.images = anh
    h.amenities = tien_ich
    h.status = "published"
    h.ket_thuc_luc = None
    h.ly_do_ket_thuc = None
    h.last_synced_at = now
    db.flush()
    phong.marketplace_house_id = h.id
    phong.is_listed_on_marketplace = True
    return h


def _phong(db, toa, ma, hang, m2, nguoi, gio, dem, ngay, do, now):
    p = db.query(models.Room).filter_by(building_id=toa.id, code=ma).first()
    if p is None:
        p = models.Room(building_id=toa.id, code=ma, status="vacant",
                        created_at=now, updated_at=now)
        db.add(p)
    p.area_m2, p.capacity, p.base_price = float(m2), nguoi, float(dem)
    p.owner_id, p.managed_by_sale_id, p.is_homestay = CHU, SALE, True
    p.do_trong_phong = do
    p.note = f"{hang} — dữ liệu mẫu ngắn hạn"
    db.flush()
    k = db.query(models.RoomKenh).filter_by(room_id=p.id, kenh="ngan_han").first()
    if k is None:
        k = models.RoomKenh(room_id=p.id, kenh="ngan_han", created_at=now)
        db.add(k)
    k.loai_phong = hang
    k.gia, k.don_vi = float(dem), "dem"
    k.gia_theo_gio, k.gia_qua_dem, k.gia_theo_ngay = float(gio), float(dem), float(ngay)
    k.huy_truoc_gio, k.huy_truoc_dem, k.huy_truoc_ngay = 1, 2, 12
    k.toi_thieu, k.dat_coc, k.dang_bat, k.trang_thai = 1, 0.0, True, "dang_rao"
    k.updated_at = now
    db.flush()
    return p, k


def _don_mau(db, phong, khach_id, mode, ci, co, trang_thai):
    """Một đơn của khách mẫu — đi đúng đường tạo đơn thật (quote → create)."""
    if db.query(models.Reservation).filter(
        models.Reservation.room_id == phong.id,
        models.Reservation.guest_user_id == khach_id,
        models.Reservation.status.in_(("pending", "approved", "checked_in")),
    ).first():
        return None
    khach = db.get(models.User, khach_id)
    try:
        q = stays.quote(db, phong.id, mode, ci.isoformat(), co.isoformat())
        res = stays.create(
            db,
            CHU,
            {
                "room_id": phong.id,
                "booking_mode": mode,
                "check_in_at": ci.isoformat(),
                "check_out_at": co.isoformat(),
                "quote_token": q["quote_token"],
                "guest_user_id": khach_id,
                "guest_name": khach.name if khach else "Khách mẫu",
                "guest_phone": "0900000000",
                "sale_id": SALE,
                "house_id": phong.marketplace_house_id,
                "note": "Đơn mẫu",
            },
            CHU,
            "direct",
        )
    except Exception as e:  # giờ đã bận / quá khứ — bỏ qua, không chặn seed
        print("  bỏ qua đơn mẫu", phong.code, mode, getattr(e, "detail", e))
        return None
    res.status = trang_thai
    db.flush()
    # Đơn mẫu không cần chuông báo — chủ nhà/sale mở app sẽ thấy trong lịch.
    db.query(models.Notification).filter(
        models.Notification.body.contains(res.booking_code)
    ).delete(synchronize_session=False)
    return res


DRY = os.environ.get("DRY") == "1"


def main():
    db = SessionLocal()
    if DRY:
        db.commit = db.flush  # type: ignore[method-assign]
    now = datetime.utcnow()
    so_tin = 0
    phong_moi = []
    i_anh = 0

    def lay_anh():
        nonlocal i_anh
        chon = [ANH[(i_anh + j) % len(ANH)] for j in range(4)]
        i_anh += 3
        return chon

    for ten, dc, quan, tinh, lat, lng, dm, ds in TOA:
        toa = db.query(models.Building).filter_by(name=ten).first()
        if toa is None:
            toa = models.Building(name=ten, created_at=now)
            db.add(toa)
        toa.host_id, toa.sale_id, toa.is_public = CHU, SALE, True
        toa.address, toa.district, toa.city = dc, quan, tinh
        toa.claimed_at = toa.claimed_at or now
        toa.note = "Dữ liệu mẫu ngắn hạn: theo giờ, qua đêm, theo ngày."
        db.flush()
        for j, (ma, hang, m2, nguoi, gio, dem, ngay, do, ti) in enumerate(ds):
            p, k = _phong(db, toa, ma, hang, m2, nguoi, gio, dem, ngay, do, now)
            p.images = lay_anh()
            _tin(db, toa, p, k, lat + 0.0006 * j, lng + 0.0005 * j, dm, ti, p.images, now)
            so_tin += 1
            phong_moi.append(p)
        print("TOÀ", toa.id, ten, "·", len(ds), "phòng")

    # Toà mẫu cũ: bổ sung ảnh, đồ trong phòng, tin đăng.
    for toa in db.query(models.Building).filter(
        models.Building.name.like(f"{TIEN_TO}%"),
        models.Building.city.in_(list(TOA_CU_TOA_DO)),
    ):
        lat, lng, dm = TOA_CU_TOA_DO[toa.city]
        toa.sale_id, toa.is_public = SALE, True
        for j, p in enumerate(
            db.query(models.Room).filter_by(building_id=toa.id).order_by(models.Room.id)
        ):
            k = db.query(models.RoomKenh).filter_by(room_id=p.id, kenh="ngan_han").first()
            if k is None or not stays.products(k):
                continue
            k.loai_phong = HANG_CU.get(p.code, k.loai_phong)
            p.images = p.images or lay_anh()
            p.do_trong_phong = p.do_trong_phong or DO_MAC_DINH
            p.managed_by_sale_id = p.managed_by_sale_id or SALE
            p.is_homestay = True
            _tin(db, toa, p, k, lat + 0.0006 * j, lng + 0.0005 * j, dm,
                 TIEN_ICH_MAC_DINH, p.images, now)
            so_tin += 1
        print("TOÀ CŨ", toa.id, toa.name)
    db.commit()

    # Vài ca bận để lịch phòng có hình (giờ VN).
    vn = stays.local_now().replace(minute=0, second=0, microsecond=0)
    mai = (vn + timedelta(days=1)).replace(hour=0)
    tz = "+07:00"

    def t(dt):
        return datetime.fromisoformat(dt.strftime("%Y-%m-%dT%H:%M:00") + tz)

    theo_ma = {p.code: p for p in phong_moi}
    don = [
        ("LT-102", KHACH_MAU[0], "qua_dem", t(mai.replace(hour=21)), t(mai + timedelta(days=1, hours=12)), "approved"),
        ("LT-201", KHACH_MAU[1], "theo_ngay", t(mai + timedelta(days=1, hours=14)), t(mai + timedelta(days=3, hours=12)), "approved"),
        ("CB-501", KHACH_MAU[2], "theo_gio", t(mai.replace(hour=15)), t(mai.replace(hour=18)), "approved"),
        ("CB-302", KHACH_MAU[0], "qua_dem", t(mai + timedelta(days=2, hours=21)), t(mai + timedelta(days=3, hours=12)), "pending"),
    ]
    so_don = 0
    for ma, khach, mode, ci, co, tt in don:
        if ma in theo_ma and _don_mau(db, theo_ma[ma], khach, mode, ci, co, tt):
            so_don += 1
    db.commit()

    print(f"\nXONG: {so_tin} tin ngắn hạn đang rao · {so_don} đơn mẫu mới")
    if DRY:
        print("đơn:", [
            (r.room_id, r.booking_mode, str(r.check_in_at), r.status)
            for r in db.query(models.Reservation).filter(models.Reservation.note == "Đơn mẫu")
        ])
        db.rollback()
        print("DRY — đã rollback, không ghi gì")
    print(json.dumps({"sale": SALE, "chu_nha": CHU}, ensure_ascii=False))


main()
