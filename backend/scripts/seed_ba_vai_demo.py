"""SEED BA VAI LIÊN KẾT — chủ nhà · sale · khách thuê cùng MỘT câu chuyện.

Vì sao: các seed trước dựng từng vai RỜI (`seed_sale_demo`: sale + chủ phòng;
`seed_ngan_han`: toà ngắn hạn gắn tài khoản thật của chủ dự án). Không có bộ ba
nào đăng nhập được mà nhìn thấy nhau — nên không thử được trọn một vòng: khách
đặt → sale xác nhận → chủ nhà thấy hợp đồng, điện nước, tiền.

Cách dựng: ĐI QUA API THẬT (TestClient chạy app trong tiến trình, ký token cho
từng vai) để mọi luật của app chạy y như người dùng bấm — mã mời sale, mã bàn
giao toà, cổng "đặt phòng phải qua sale", phạm vi của sale, hợp đồng chiếm chỗ,
hoá đơn chỉ tính số đã duyệt... Chỉ hai chỗ ghi thẳng DB, đều có lý do tại chỗ:
  * tin đăng gắn phòng (app chưa có đường "sale đăng tin từ phòng" — cùng cách
    `seed_ngan_han._tin` đã làm);
  * mốc QUÁ KHỨ mà API cố ý chặn (lịch xem đã xong từ tháng 6, ngày tạo hợp đồng).

Câu chuyện (ngày tính từ HÔM NAY mỗi lần chạy):
  Chủ nhà  Trần Văn Hùng   — 2 toà ở Hải Phòng.
  Sale     Nguyễn Thị Lan  — phụ trách cả hai toà: toà trọ nhận qua MÃ MỜI của
                              chủ nhà; homestay do sale dựng rồi BÀN GIAO cho chủ.
  Khách    Phạm Minh Tuấn  — đang thuê P101 từ 01/07, có đơn homestay đã xác nhận
                              + một đơn chờ, hẹn xem phòng lớn hơn (một đã xác
                              nhận, một chờ), gửi chỉ số điện tháng này chờ duyệt.
  Thêm hai người thuê KHÔNG có tài khoản (P102 sắp hết hạn, còn nợ hoá đơn; P201
  sắp vào ở) và một khách vãng lai đang ở homestay — để sổ phòng của chủ nhà
  không chỉ có Tuấn.

Chạy trong container backend (script KHÔNG nằm trong image → đọc từ stdin):
    docker exec -i ancu365-backend-staging python - < scripts/seed_ba_vai_demo.py
    docker exec -i ancu365-backend-staging python - --xoa < scripts/seed_ba_vai_demo.py

Chạy lại = DỌN SẠCH bộ ba cũ rồi dựng lại. `--xoa` chỉ dọn. Bộ ba nhận diện bằng
3 số điện thoại bên dưới — dọn là xoá mọi thứ treo trên 3 tài khoản đó.
"""

from __future__ import annotations

import json
import sys
from datetime import date, datetime, timedelta

from fastapi.testclient import TestClient
from sqlalchemy import func, or_

from app import auth, models
from app.database import SessionLocal
from app.services import lich_su_dat, provinces_service
from app.services import short_stay_service as stays
from main import app

MAT_KHAU = "demo123"

CHU = dict(
    name="Trần Văn Hùng", phone="0901111001", email="chunha.demo@ancu365.vn",
    role="host", account_type="owner",
    avatar_path="https://api.dicebear.com/9.x/avataaars/png?seed=chunha_hung&size=256",
)
SALE = dict(
    name="Nguyễn Thị Lan", phone="0901111002", email="sale.demo@ancu365.vn",
    role="guest", account_type="sale",
    avatar_path="https://api.dicebear.com/9.x/avataaars/png?seed=sale_lan&size=256",
    bio="4 năm cho thuê phòng trọ và homestay khu Ngô Quyền, Lê Chân. Dẫn xem trong ngày.",
)
KHACH = dict(
    name="Phạm Minh Tuấn", phone="0901111003", email="khach.demo@ancu365.vn",
    role="guest", account_type="customer",
    avatar_path="https://api.dicebear.com/9.x/avataaars/png?seed=khach_tuan&size=256",
)
SDT = (CHU["phone"], SALE["phone"], KHACH["phone"])

_U = "https://images.unsplash.com/photo-{}?auto=format&fit=crop&w=1200&q=80"
ANH_TRO = [_U.format(x) for x in (
    "1522708323590-d24dbb6b0267", "1502672260266-1c1ef2d93688",
    "1560448204-e02f11c3d0e2", "1545324418-cc1a3fa10c00",
    "1554995207-c18c203602cb", "1493809842364-78817add7ffb",
)]
ANH_HOMESTAY = [_U.format(x) for x in (
    "1611892440504-42a792e24d32", "1590490360182-c33d57733427",
    "1566665797739-1674de7a421a", "1582719478250-c89cae4dc85b",
    "1631049307264-da0ec9d70304", "1618773928121-c32242e63f39",
)]

TOA_TRO = dict(
    name="Nhà trọ An Cư Văn Cao", address="25 Văn Cao", district="Ngô Quyền",
    city="Tp Hải Phòng", note="Phòng khép kín, có gác xép, giờ giấc tự do, camera 24/7.",
)
# (mã, m², người, giá tháng)
PHONG_TRO = [
    ("P101", 20, 2, 3_200_000), ("P102", 22, 2, 3_500_000),
    ("P201", 25, 2, 3_800_000), ("P202", 25, 2, 4_000_000),
    ("P301", 30, 3, 4_500_000), ("P302", 30, 3, 4_500_000),
]
TOA_DO_TRO = (20.8561, 106.6918)

TOA_HOMESTAY = dict(
    name="An Cư Homestay Lạch Tray", address="88 Lạch Tray", district="Lê Chân",
    city="Tp Hải Phòng", note="Homestay theo giờ / qua đêm / theo ngày, gần sân Lạch Tray.",
)
# (mã, hạng, m², người, giờ, qua đêm, ngày)
PHONG_HOMESTAY = [
    ("H01", "Phòng đôi tiêu chuẩn", 20, 2, 60_000, 320_000, 420_000),
    ("H02", "Deluxe ban công", 28, 2, 80_000, 420_000, 550_000),
    ("H03", "Phòng gia đình", 36, 4, 110_000, 600_000, 780_000),
]
TOA_DO_HOMESTAY = (20.8497, 106.6811)
DM_PHONG_TRO, DM_HOMESTAY = 6, 10


# ── Tiện ích ────────────────────────────────────────────────────────────────
class Vai:
    """Một người dùng gọi API bằng token của chính họ."""

    def __init__(self, client: TestClient, u: models.User, ten: str):
        self.c, self.id, self.ten = client, u.id, ten
        self.h = {"Authorization": f"Bearer {auth.sign_token(u.id, u.role, u.password_changed_at)}"}

    def goi(self, method: str, url: str, **kw):
        r = self.c.request(method, url, headers=self.h, **kw)
        if r.status_code >= 400:
            raise SystemExit(f"✗ [{self.ten}] {method} {url} → {r.status_code}: {r.text[:500]}")
        return r.json() if r.content else None


def _vn(d: date, gio: int, phut: int = 0) -> str:
    return datetime(d.year, d.month, d.day, gio, phut).replace(tzinfo=stays.VN).isoformat()


def _cong_thang(d: date, n: int) -> date:
    y, m = divmod(d.month - 1 + n, 12)
    return date(d.year + y, m + 1, 1)


def _them_thang(d: date, n: int) -> date:
    """Cùng ngày, n tháng sau (31/01 + 1 → 28/02)."""
    dau = _cong_thang(d, n)
    cuoi = (_cong_thang(dau, 1) - timedelta(days=1)).day
    return dau.replace(day=min(d.day, cuoi))


def _k(n: float) -> str:
    return f"{int(n // 1000)}k" if n < 1_000_000 else f"{n / 1_000_000:.1f}tr".replace(".0tr", "tr")


# ── Dọn ─────────────────────────────────────────────────────────────────────
def don(db) -> int:
    """Xoá bộ ba cũ và MỌI thứ treo trên họ. Thứ tự theo khoá ngoại RESTRICT."""
    uids = [u.id for u in db.query(models.User).filter(models.User.phone.in_(SDT))]
    if not uids:
        return 0
    toa = [b.id for b in db.query(models.Building).filter(
        or_(models.Building.host_id.in_(uids), models.Building.created_by_user_id.in_(uids))
    )]
    phong = [r.id for r in db.query(models.Room).filter(models.Room.building_id.in_(toa or [-1]))]
    tin = [h.id for h in db.query(models.House).filter(
        or_(models.House.host_id.in_(uids), models.House.source_room_id.in_(phong or [-1]))
    )]
    hd = [c.id for c in db.query(models.Contract).filter(
        or_(models.Contract.room_id.in_(phong or [-1]), models.Contract.host_id.in_(uids))
    )]
    hoa_don = [i.id for i in db.query(models.Invoice).filter(
        or_(models.Invoice.contract_id.in_(hd or [-1]), models.Invoice.host_id.in_(uids))
    )]
    don_dat = [r.id for r in db.query(models.Reservation).filter(or_(
        models.Reservation.room_id.in_(phong or [-1]),
        models.Reservation.guest_user_id.in_(uids),
        models.Reservation.host_id.in_(uids),
    ))]
    hen = [a.id for a in db.query(models.ViewingAppointment).filter(or_(
        models.ViewingAppointment.guest_id.in_(uids),
        models.ViewingAppointment.house_id.in_(tin or [-1]),
        models.ViewingAppointment.room_id.in_(phong or [-1]),
    ))]

    def xoa(model, *dk):
        return db.query(model).filter(*dk).delete(synchronize_session=False)

    xoa(models.CreditNote, models.CreditNote.original_invoice_id.in_(hoa_don or [-1]))
    xoa(models.Invoice, models.Invoice.id.in_(hoa_don or [-1]))
    xoa(models.Contract, models.Contract.id.in_(hd or [-1]))
    xoa(models.Reservation, models.Reservation.id.in_(don_dat or [-1]))
    xoa(models.ViewingAppointment, models.ViewingAppointment.id.in_(hen or [-1]))
    # Nhật ký: CHỈ dòng do bộ ba ghi, hoặc ghi SAU khi toà demo ra đời. Khớp
    # thuần theo (loại, id) là xoá lố — DB này có id được dùng lại, nên còn nằm
    # đó log mồ côi của bản ghi cũ trùng id với bản ghi demo (chạy thử trên bản
    # sao DB đã bắt được 2 dòng như vậy).
    moc = db.query(func.min(models.Building.created_at)).filter(
        models.Building.id.in_(toa or [-1])).scalar()
    cua_bo_ba = models.ChangeLog.actor_id.in_(uids)
    for loai, ids in (
        ("contract", hd), ("invoice", hoa_don), (lich_su_dat.DON, don_dat),
        (lich_su_dat.HEN, hen), ("room", phong), ("building", toa),
    ):
        xoa(models.ChangeLog, models.ChangeLog.entity_type == loai,
            models.ChangeLog.entity_id.in_(ids or [-1]),
            or_(cua_bo_ba, models.ChangeLog.created_at >= moc) if moc else cua_bo_ba)
    xoa(models.ChangeLog, cua_bo_ba)
    xoa(models.Notification, models.Notification.user_id.in_(uids))
    db.query(models.Room).filter(models.Room.id.in_(phong or [-1])).update(
        {"marketplace_house_id": None}, synchronize_session=False)
    xoa(models.House, models.House.id.in_(tin or [-1]))
    xoa(models.Room, models.Room.id.in_(phong or [-1]))
    xoa(models.Building, models.Building.id.in_(toa or [-1]))
    xoa(models.User, models.User.id.in_(uids))
    db.commit()
    return len(uids)


# ── Dựng ────────────────────────────────────────────────────────────────────
def _nguoi(db, d: dict) -> models.User:
    now = datetime.utcnow()
    u = models.User(
        name=d["name"], email=d["email"], phone=d["phone"],
        password_hash=auth.hash_password(MAT_KHAU), role=d["role"],
        account_type=d["account_type"], avatar_path=d["avatar_path"],
        bio=d.get("bio"), is_active=True, created_at=now - timedelta(days=200),
    )
    db.add(u)
    db.flush()
    return u


def _tin(db, sale_id, toa, phong, *, kenh, tieu_de, mo_ta, gia, dm, product_type, toa_do, now):
    """Tin gắn phòng do SALE đứng tên — cùng khuôn `seed_ngan_han._tin`."""
    h = models.House(
        host_id=sale_id, source_room_id=phong.id, kenh=kenh, transaction_type="rent",
        product_type=product_type, listing_type="single", total_units=1, available_units=1,
        gender_pref="any", title=tieu_de, description=mo_ta, category_id=dm,
        price=float(gia), area=float(phong.area_m2 or 0),
        bedrooms=2 if (phong.capacity or 1) >= 4 else 1, bathrooms=1,
        address=toa.address, district=toa.district, city=toa.city,
        latitude=toa_do[0], longitude=toa_do[1],
        province_code=provinces_service.province_slug_for_city(toa.city),
        geocode_status="geocoded", images=list(phong.images or []),
        amenities=["Wifi", "Điều hoà", "Nóng lạnh", "WC riêng"],
        status="published", created_at=now, last_synced_at=now,
    )
    db.add(h)
    db.flush()
    phong.marketplace_house_id = h.id
    phong.is_listed_on_marketplace = True
    return h


def dung(db) -> dict:
    client = TestClient(app)
    now = datetime.utcnow()
    hom_nay = stays.local_now().date()

    chu, sale, khach = (_nguoi(db, d) for d in (CHU, SALE, KHACH))
    db.commit()
    C, S, K = Vai(client, chu, "chủ nhà"), Vai(client, sale, "sale"), Vai(client, khach, "khách")
    S.goi("GET", "/api/sales/me/code")  # sinh hồ sơ + mã sale như lần đầu mở app

    # 1. Toà trọ: CHỦ NHÀ dựng, mời sale bằng mã ─────────────────────────────
    tro = C.goi("POST", "/api/host/buildings", json=TOA_TRO)
    C.goi("PATCH", f"/api/host/buildings/{tro['id']}",
          json={"gia_dien": 3_500, "gia_nuoc": 25_000, "phi_dich_vu": 100_000})
    for i, (ma, m2, nguoi, gia) in enumerate(PHONG_TRO):
        C.goi("POST", f"/api/host/buildings/{tro['id']}/rooms", json={
            "code": ma, "area_m2": m2, "capacity": nguoi, "base_price": gia,
            "images": [ANH_TRO[i % 6], ANH_TRO[(i + 1) % 6], ANH_TRO[(i + 2) % 6]],
            "kenh": "dai_han", "dat_coc": gia, "toi_thieu": 6,
        })
    ma_moi = C.goi("POST", f"/api/host/buildings/{tro['id']}/ma-moi-sale")["ma"]
    S.goi("POST", "/api/buildings/moi-sale", json={"code": ma_moi})

    # 2. Homestay: SALE dựng, bàn giao cho chủ nhà bằng mã ────────────────────
    hs = S.goi("POST", "/api/host/buildings", json=TOA_HOMESTAY)
    for i, (ma, hang, m2, nguoi, gio, dem, ngay) in enumerate(PHONG_HOMESTAY):
        p = S.goi("POST", f"/api/host/buildings/{hs['id']}/rooms", json={
            "code": ma, "area_m2": m2, "capacity": nguoi, "base_price": dem,
            "images": [ANH_HOMESTAY[(2 * i + j) % 6] for j in range(3)],
            "kenh": "ngan_han",
        })
        S.goi("PUT", f"/api/host/short-stays/rooms/{p['id']}/rates", json={
            "loai_phong": hang, "gia_theo_gio": gio, "gia_qua_dem": dem, "gia_theo_ngay": ngay,
        })
    ma_bg = S.goi("POST", f"/api/host/buildings/{hs['id']}/ma-ban-giao")["ma"]
    C.goi("POST", "/api/buildings/claim", json={"code": ma_bg})

    # 3. Tin đăng của sale (ghi thẳng DB — xem docstring) ─────────────────────
    db.expire_all()
    toa_tro = db.get(models.Building, tro["id"])
    toa_hs = db.get(models.Building, hs["id"])
    phong = {r.code: r for r in db.query(models.Room).filter(
        models.Room.building_id.in_([tro["id"], hs["id"]]))}
    tin = {}
    for ma, m2, nguoi, gia in PHONG_TRO:
        p = phong[ma]
        tin[ma] = _tin(
            db, sale.id, toa_tro, p, kenh="dai_han", dm=DM_PHONG_TRO, product_type="apartment",
            tieu_de=f"Phòng trọ khép kín {m2}m² có gác · {ma} · Văn Cao, Ngô Quyền",
            mo_ta=(f"{toa_tro.name} — phòng {ma}, {m2}m², tối đa {nguoi} người.\n"
                   f"• Giá {_k(gia)}/tháng, cọc 1 tháng, hợp đồng từ 6 tháng.\n"
                   "• Điện 3.500đ/số, nước 25.000đ/khối, dịch vụ 100k/tháng.\n"
                   "(Dữ liệu mẫu để thử app.)"),
            gia=gia, toa_do=TOA_DO_TRO, now=now,
        )
    for ma, hang, m2, nguoi, gio, dem, ngay in PHONG_HOMESTAY:
        p = phong[ma]
        tin[ma] = _tin(
            db, sale.id, toa_hs, p, kenh="ngan_han", dm=DM_HOMESTAY, product_type="homestay",
            tieu_de=f"{hang} · {m2}m² · theo giờ từ {_k(gio)} · Lê Chân, Hải Phòng",
            mo_ta=(f"{toa_hs.name} — phòng {ma}, tối đa {nguoi} người.\n"
                   f"• Theo giờ: {_k(gio)}/giờ\n• Qua đêm: {_k(dem)}/đêm\n"
                   f"• Theo ngày: {_k(ngay)}/ngày\n(Dữ liệu mẫu để thử app.)"),
            gia=dem, toa_do=TOA_DO_HOMESTAY, now=now,
        )
    db.commit()
    tin_id = {ma: h.id for ma, h in tin.items()}
    phong_id = {ma: p.id for ma, p in phong.items()}

    # 4. Lịch xem nhà của khách ──────────────────────────────────────────────
    # Quá khứ: Tuấn xem P101 cuối tháng 6 rồi mới thuê. API không nhận ngày đã
    # qua (đúng), nên ghi thẳng — kèm dòng lịch sử cùng mốc thời gian.
    ngay_xem = date(hom_nay.year, 6, 27) if hom_nay.month > 7 else hom_nay - timedelta(days=80)
    tao_luc = datetime.combine(ngay_xem - timedelta(days=2), datetime.min.time()) + timedelta(hours=3)
    hen_cu = models.ViewingAppointment(
        house_id=tin_id["P101"], room_id=phong_id["P101"], guest_id=khach.id, loai="xem",
        hinh_thuc="truc_tiep", so_nguoi=1, ten_khach=KHACH["name"], sdt_khach=KHACH["phone"],
        booking_date=ngay_xem.isoformat(), booking_time="17:00-18:00",
        message="Em đi làm về muộn, hẹn chị 5h chiều được không ạ?", status="completed",
        created_at=tao_luc, responded_at=tao_luc + timedelta(minutes=25),
    )
    db.add(hen_cu)
    db.flush()
    lich_su_dat.ghi(db, lich_su_dat.HEN, hen_cu.id, "create", khach.id, None,
                    {"ngay": hen_cu.booking_date, "gio": hen_cu.booking_time, "loai": "xem"})
    lich_su_dat.ghi(db, lich_su_dat.HEN, hen_cu.id, "status_change", sale.id,
                    {"status": "pending"}, {"status": "completed"})
    db.query(models.ChangeLog).filter(
        models.ChangeLog.entity_type == lich_su_dat.HEN,
        models.ChangeLog.entity_id == hen_cu.id,
    ).update({"created_at": tao_luc + timedelta(minutes=25)}, synchronize_session=False)
    db.commit()

    # Sắp tới: Tuấn muốn chuyển lên phòng rộng hơn — xem P301 (sale đã xác
    # nhận) và P302 (chờ sale trả lời).
    def hen(ma, ngay, gio, loi_nhan):
        return K.goi("POST", "/api/viewing-appointments", json={
            "house_id": tin_id[ma], "booking_date": ngay.isoformat(), "booking_time": gio,
            "message": loi_nhan, "hinh_thuc": "truc_tiep", "so_nguoi": 2,
            "ten_khach": KHACH["name"], "sdt_khach": KHACH["phone"],
        })["booking"]["id"]

    h1 = hen("P301", hom_nay + timedelta(days=2), "09:00-10:00",
             "Em đang thuê P101, muốn chuyển lên phòng rộng hơn cho 2 người.")
    S.goi("PATCH", f"/api/viewing-appointments/{h1}/status", json={"status": "approved"})
    hen("P302", hom_nay + timedelta(days=4), "18:00-19:00", "Cho em xem thêm P302 để so sánh ạ.")

    # 5. Hợp đồng dài hạn — chủ nhà ký ───────────────────────────────────────
    def hop_dong(ma, tu: date, den: date, nguoi: dict, ngay_tao: datetime):
        gia = next(g for m, _, _, g in PHONG_TRO if m == ma)
        c = C.goi("POST", "/api/host/contracts", json={
            "room_id": phong_id[ma], "start_date": tu.isoformat(), "end_date": den.isoformat(),
            "monthly_rent": gia, "deposit": gia, "coc_da_thu": gia, "ngay_thanh_toan": 5,
            "tenants": [dict(nguoi, is_primary=True)],
        })
        C.goi("PATCH", f"/api/host/contracts/{c['id']}/activate")
        # Ngày TẠO hợp đồng lùi về trước ngày vào ở — thuần hiển thị.
        db.query(models.Contract).filter(models.Contract.id == c["id"]).update(
            {"created_at": ngay_tao, "updated_at": ngay_tao}, synchronize_session=False)
        db.commit()
        return c["id"]

    vao_tuan = _cong_thang(hom_nay, -2)  # mùng 1 hai tháng trước
    hd_tuan = hop_dong(
        "P101", vao_tuan, _them_thang(vao_tuan, 12) - timedelta(days=1),
        {"full_name": KHACH["name"], "phone": KHACH["phone"], "email": KHACH["email"],
         "birthday": "1998-04-12", "address_origin": "Kiến Thuỵ, Hải Phòng"},
        datetime.combine(ngay_xem + timedelta(days=1), datetime.min.time()) + timedelta(hours=10),
    )
    het_hoa = hom_nay + timedelta(days=20)
    vao_hoa = _them_thang(het_hoa, -12) + timedelta(days=1)
    hd_hoa = hop_dong(
        "P102", vao_hoa, het_hoa,
        {"full_name": "Lê Thị Hoa", "phone": "0977000111", "address_origin": "Thái Bình"},
        datetime.combine(vao_hoa - timedelta(days=3), datetime.min.time()) + timedelta(hours=9),
    )
    vao_huy = hom_nay + timedelta(days=5)
    hop_dong(
        "P201", vao_huy, _them_thang(vao_huy, 6) - timedelta(days=1),
        {"full_name": "Đỗ Quang Huy", "phone": "0977000222", "address_origin": "Nam Định"},
        now - timedelta(days=2),
    )

    # 6. Điện nước + hoá đơn ─────────────────────────────────────────────────
    # Chỉ số chủ nhà ghi (mặc định đã duyệt), chốt NGÀY 28 hằng tháng.
    #
    # Vì sao không ghi ngày cuối tháng: `invoice_service.dung_dong_tien` lọc
    # `reading_date < ngày CUỐI tháng` (khoảng đóng của `_period_range` đem dùng
    # như khoảng mở) — số ghi đúng ngày 31/07 bị loại khỏi hoá đơn tháng 7, và
    # hoá đơn ra 0đ tiền điện. Màn "Điện nước" thì tính cả ngày cuối. Lỗi thật
    # của app (18/09/2026, đã báo, chưa sửa) — seed né để hoá đơn mẫu đúng tiền.
    #
    # Số chốt lúc BÀN GIAO mang ngày trước tháng đầu tiên: hoá đơn tháng T lấy
    # "số tháng T − số đã duyệt gần nhất TRƯỚC mùng 1 tháng T".
    def chi_so(ma, ngay: date, dien, nuoc):
        C.goi("POST", "/api/host/meter-readings", json={
            "room_id": phong_id[ma], "reading_date": ngay.isoformat(),
            "electricity_kwh": dien, "water_m3": nuoc,
        })

    thang_1, thang_2 = vao_tuan, _cong_thang(vao_tuan, 1)  # 2 tháng Tuấn đã ở trọn
    chi_so("P101", thang_1 - timedelta(days=1), 1200, 50.0)  # bàn giao
    chi_so("P101", thang_1.replace(day=28), 1286, 54.0)
    chi_so("P101", thang_2.replace(day=28), 1379, 58.5)
    chi_so("P102", _cong_thang(thang_1, -1).replace(day=28), 2205, 84.0)
    chi_so("P102", thang_1.replace(day=28), 2318, 88.5)
    chi_so("P102", thang_2.replace(day=28), 2431, 93.0)

    def hoa_don(contract_id, thang: date, *, thu_ngay: date | None = None, cach="bank_transfer"):
        """Chốt + gửi hoá đơn tháng; có `thu_ngay` thì ghi luôn khoản đã thu.

        Ngày lập / hạn / ngày thu rồi được lùi về đúng kỳ (mùng 1 tháng sau, hạn
        mùng 5): API ghi "hôm nay" cho mọi thứ, nên để nguyên thì doanh thu dồn
        hết vào tháng này và hoá đơn tháng trước chưa bao giờ "quá hạn".
        """
        iid = C.goi("POST", "/api/host/hoa-don/chot",
                    json={"contract_id": contract_id, "thang": thang.strftime("%Y-%m"), "gui": True})
        tong = iid["tong"]
        iid = iid["invoice_id"]
        if thu_ngay is not None:
            C.goi("PATCH", f"/api/host/invoices/{iid}/pay",
                  json={"amount": tong, "method": cach, "paid_at": _vn(thu_ngay, 20, 15)})
        lap = _cong_thang(thang, 1)
        lap_luc = datetime.combine(lap, datetime.min.time()) + timedelta(hours=8)
        thu_luc = datetime.combine(thu_ngay, datetime.min.time()) + timedelta(hours=13) if thu_ngay else None
        doi = {"issued_date": lap.isoformat(), "due_date": lap.replace(day=5).isoformat(),
               "created_at": lap_luc, "updated_at": thu_luc or lap_luc}
        if thu_luc:
            doi["paid_at"] = thu_luc
            db.query(models.Payment).filter(models.Payment.invoice_id == iid).update(
                {"paid_at": thu_luc, "created_at": thu_luc}, synchronize_session=False)
        db.query(models.Invoice).filter(models.Invoice.id == iid).update(doi, synchronize_session=False)
        db.commit()

    for t in (thang_1, thang_2):
        hoa_don(hd_tuan, t, thu_ngay=_cong_thang(t, 1) + timedelta(days=3))
    hoa_don(hd_hoa, thang_1, thu_ngay=_cong_thang(thang_1, 1) + timedelta(days=4), cach="cash")
    hoa_don(hd_hoa, thang_2)  # Hoa: CHƯA thu — để trang công nợ có việc

    # Tuấn tự gửi chỉ số tháng này → chủ nhà thấy "chờ duyệt".
    K.goi("POST", "/api/guest/dien-nuoc", json={
        "contract_id": hd_tuan, "electricity_kwh": 1428, "water_m3": 60.5,
        "anh_dien": ANH_TRO[0], "anh_nuoc": ANH_TRO[1],
    })

    # 7. Homestay ─────────────────────────────────────────────────────────────
    def dat(ma, mode, vao: str, ra: str, so_khach=2):
        q = K.goi("POST", "/api/short-stays/quote", json={
            "room_id": phong_id[ma], "booking_mode": mode,
            "check_in_at": vao, "check_out_at": ra,
        })
        return K.goi("POST", "/api/guest/reservations", json={
            "room_id": phong_id[ma], "house_id": tin_id[ma], "booking_mode": mode,
            "check_in_at": vao, "check_out_at": ra, "quote_token": q["quote_token"],
            "guest_name": KHACH["name"], "guest_phone": KHACH["phone"], "so_khach": so_khach,
            "note": "Cho em phòng tầng cao nếu còn ạ.",
        })["id"]

    mai, tuan_sau = hom_nay + timedelta(days=1), hom_nay + timedelta(days=8)
    r1 = dat("H02", "qua_dem", _vn(mai, 21), _vn(mai + timedelta(days=1), 12))
    S.goi("POST", f"/api/host/short-stays/reservations/{r1}/actions", json={"action": "approve"})
    dat("H03", "theo_ngay", _vn(tuan_sau, 14), _vn(tuan_sau + timedelta(days=2), 12), so_khach=4)
    r3 = dat("H01", "theo_gio", _vn(hom_nay + timedelta(days=3), 14), _vn(hom_nay + timedelta(days=3), 17))
    K.goi("POST", f"/api/guest/reservations/{r3}/cancel", json={"reason": "Bận việc đột xuất"})

    # Khách vãng lai đang ở H01 — CHỦ NHÀ ghi tại quầy (luật: chỉ chủ phòng mở
    # được ca thuê; sale gọi là 403).
    ca = C.goi("POST", f"/api/host/rooms/{phong_id['H01']}/ca-thue", json={
        "ten": "Anh Dũng (vãng lai)", "sdt": "0977000333", "kieu": "theo_gio", "so_luong": 3,
    })["reservation_id"]
    # Ca vãng lai luôn bắt đầu ở PHÚT KẾ TIẾP, và nhận phòng chỉ được trong khung
    # giờ đã đặt — nên lùi cả ca về 1 tiếng trước (đơn + dòng chiếm chỗ) rồi mới
    # bấm "Nhận phòng": khách đã vào 1 tiếng, còn 2 tiếng.
    # Cột NGÀY giữ nguyên nghĩa của chúng (ngày trả là ngày LOẠI TRỪ — ca theo
    # giờ kết thúc 18/09 vẫn ghi 19/09), chỉ dời khi lùi giờ vắt qua nửa đêm.
    lui = timedelta(hours=1)
    r = db.get(models.Reservation, ca)
    lech = (r.check_in_at - lui).date() - r.check_in_at.date()  # 0 hoặc −1 ngày
    r.check_in_at, r.check_out_at = r.check_in_at - lui, r.check_out_at - lui
    if lech:
        r.check_in_date, r.check_out_date = (
            (date.fromisoformat(str(d)[:10]) + lech).isoformat()
            for d in (r.check_in_date, r.check_out_date)
        )
    for cd in db.query(models.RoomChiemDung).filter(
        models.RoomChiemDung.nguon == models.RoomChiemDung.RESERVATION,
        models.RoomChiemDung.nguon_id == ca,
    ):
        cd.tu_luc, cd.den_luc = cd.tu_luc - lui, cd.den_luc - lui
        cd.tu_ngay, cd.den_ngay = cd.tu_ngay + lech, cd.den_ngay + lech
    db.commit()
    C.goi("POST", f"/api/host/short-stays/reservations/{ca}/actions", json={"action": "check_in"})

    db.expire_all()
    return {"chu_nha": chu.id, "sale": sale.id, "khach": khach.id,
            "toa_tro": tro["id"], "homestay": hs["id"]}


def main() -> None:
    db = SessionLocal()
    try:
        so = don(db)
        if so:
            print(f"Đã dọn bộ ba cũ ({so} tài khoản).")
        if "--xoa" in sys.argv:
            return
        ids = dung(db)
        print(json.dumps(ids, ensure_ascii=False))
        print(f"Mật khẩu chung: {MAT_KHAU}")
        for d in (CHU, SALE, KHACH):
            print(f"  {d['name']:<16} {d['phone']}  {d['email']}")
    finally:
        db.close()


main()
