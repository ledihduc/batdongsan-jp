"""seed_staging.py — bộ tài khoản gốc cho staging sau khi xoá sạch.

Dựng 8 tài khoản: 1 admin · 2 chủ nhà · 5 sale.

Nguyên tắc (giữ nguyên từ `seed_sale_demo.py`): **seed phải TỰ NHẤT QUÁN**.
Không bơm thẳng số đẹp vào cột tổng hợp — dựng SỰ KIỆN có thật rồi để
`helpers.recompute_host_reputation` tự tính ra điểm, cỡ mẫu, giờ phản hồi.
Bơm thẳng vào `avg_response_hours` là đúng cái sai mà migration 0087 đã dọn.

Năm sale cố ý KHÁC NHAU về độ chín, để thấy giao diện xử lý từng mức:
  1. Lê Quang Vinh  — đủ mọi thứ: huy hiệu, giao dịch, dự án, đánh giá
  2. Trần Mỹ Duyên  — có tin và đánh giá, CHƯA đủ 5 đánh giá đã kiểm → không huy hiệu
  3. Phạm Hoàng Nam — nhiều tin, KHÔNG đánh giá nào → trang chỉ có tin
  4. Vũ Thanh Hà    — có dự án cho thuê nhưng ít tin lẻ
  5. Đỗ Minh Khoa   — tài khoản MỚI: 1 tin, không gì khác

Chạy:
    DATABASE_URL=... python scripts/seed_staging.py

Idempotent: chạy lại không nhân đôi.
"""

from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

MAT_KHAU = "ancu2026"

A = [
    "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1493809842364-78817add7ffb?auto=format&fit=crop&w=1200&q=80",
]


def _avatar(seed: str) -> str:
    return f"https://api.dicebear.com/9.x/avataaars/png?seed={seed}&size=256"


# ── Định nghĩa tài khoản ─────────────────────────────────────────────────────

ADMIN = {
    "email": "admin@ancu365.vn",
    "ten": "Quản trị viên",
    "phone": "0900000001",
    "role": "admin",
    "account_type": "admin",
}

CHU_NHA = [
    {
        "email": "chunha1@ancu365.vn",
        "ten": "Bà Nguyễn Thị Mai",
        "phone": "0901111111",
        "nam": 3,
    },
    {
        "email": "chunha2@ancu365.vn",
        "ten": "Ông Trần Văn Bảy",
        "phone": "0902222222",
        "nam": 2,
    },
]

SALE = [
    {
        "email": "sale1@ancu365.vn",
        "ten": "Lê Quang Vinh",
        "phone": "0911111111",
        "nam": 6,
        "bio": "6 năm cho thuê căn hộ Thủ Đức, Quận 7. Nhận ký gửi, xem phòng "
               "trong ngày, hỗ trợ hợp đồng và thủ tục tạm trú.",
        "agency": "Vinhomes Grand Park · Him Lam Land",
        "khu": ["Thủ Đức", "Quận 7", "Bình Thạnh"],
        "so_danh_gia": 6,
        "cong_khai_sdt": True,
    },
    {
        "email": "sale2@ancu365.vn",
        "ten": "Trần Mỹ Duyên",
        "phone": "0912222222",
        "nam": 2,
        "bio": "Chuyên căn hộ dịch vụ và studio khu trung tâm. Ưu tiên khách "
               "thuê dài hạn, hỗ trợ xem nhà buổi tối.",
        "agency": None,
        "khu": ["Quận 1", "Quận 3"],
        # 3 đánh giá — DƯỚI ngưỡng 5, cố ý: để thấy trang không gắn huy hiệu.
        "so_danh_gia": 3,
        "cong_khai_sdt": True,
    },
    {
        "email": "sale3@ancu365.vn",
        "ten": "Phạm Hoàng Nam",
        "phone": "0913333333",
        "nam": 4,
        "bio": "Nhà phố và đất nền khu Đông. Đi xem thực địa cùng khách, kiểm "
               "tra quy hoạch trước khi đặt cọc.",
        "agency": "Đất Xanh Miền Nam",
        "khu": ["Thủ Đức", "Quận 9"],
        "so_danh_gia": 0,
        "cong_khai_sdt": False,
    },
    {
        "email": "sale4@ancu365.vn",
        "ten": "Vũ Thanh Hà",
        "phone": "0914444444",
        "nam": 3,
        "bio": "Quản lý nhà trọ và căn hộ mini. Nhận vận hành trọn gói cho chủ "
               "nhà ở xa.",
        "agency": None,
        "khu": ["Gò Vấp", "Bình Thạnh"],
        "so_danh_gia": 0,
        "cong_khai_sdt": True,
    },
    {
        "email": "sale5@ancu365.vn",
        "ten": "Đỗ Minh Khoa",
        "phone": "0915555555",
        "nam": 0,
        "bio": "Mới vào nghề, tập trung khu vực Tân Bình.",
        "agency": None,
        "khu": ["Tân Bình"],
        "so_danh_gia": 0,
        "cong_khai_sdt": False,
    },
]

# Tin đăng: (email sale, tiêu đề, giá, quận, m², PN, lat, lng, loại giao dịch)
TIN = [
    ("sale1@ancu365.vn", "Căn hộ 2PN 68m² Vinhomes Grand Park", 9_200_000, "Thủ Đức", 68, 2, 10.8443, 106.8390, "rent"),
    ("sale1@ancu365.vn", "Căn hộ 1PN 45m² Him Lam Riverside", 8_000_000, "Quận 7", 45, 1, 10.7395, 106.7020, "rent"),
    ("sale1@ancu365.vn", "Studio 32m² full nội thất Bình Thạnh", 6_500_000, "Bình Thạnh", 32, 1, 10.8039, 106.7100, "rent"),
    ("sale1@ancu365.vn", "Căn hộ 3PN 95m² view sông Quận 7", 15_000_000, "Quận 7", 95, 3, 10.7290, 106.7180, "rent"),
    ("sale1@ancu365.vn", "Officetel 40m² Thủ Đức", 7_200_000, "Thủ Đức", 40, 1, 10.8510, 106.7590, "rent"),
    ("sale2@ancu365.vn", "Căn hộ dịch vụ 35m² Quận 1", 11_000_000, "Quận 1", 35, 1, 10.7769, 106.7009, "rent"),
    ("sale2@ancu365.vn", "Studio ban công 28m² Quận 3", 8_500_000, "Quận 3", 28, 1, 10.7830, 106.6870, "rent"),
    ("sale2@ancu365.vn", "Căn hộ 2PN 60m² Quận 1", 18_000_000, "Quận 1", 60, 2, 10.7720, 106.6980, "rent"),
    ("sale3@ancu365.vn", "Nhà phố 1 trệt 2 lầu Thủ Đức", 5_800_000_000, "Thủ Đức", 90, 4, 10.8500, 106.7700, "sale"),
    ("sale3@ancu365.vn", "Đất nền 100m² sổ riêng Quận 9", 3_200_000_000, "Quận 9", 100, 0, 10.8420, 106.8100, "sale"),
    ("sale3@ancu365.vn", "Nhà cấp 4 hẻm xe hơi Thủ Đức", 4_100_000_000, "Thủ Đức", 72, 3, 10.8390, 106.7550, "sale"),
    ("sale3@ancu365.vn", "Nhà phố 3 tầng mặt tiền Quận 9", 7_500_000_000, "Quận 9", 120, 4, 10.8330, 106.8210, "sale"),
    ("sale4@ancu365.vn", "Phòng trọ 25m² có gác Gò Vấp", 3_500_000, "Gò Vấp", 25, 1, 10.8380, 106.6650, "rent"),
    ("sale5@ancu365.vn", "Căn hộ mini 30m² Tân Bình", 5_000_000, "Tân Bình", 30, 1, 10.8010, 106.6520, "rent"),
]

# Dự án cho thuê: (email sale, email chủ nhà, tên, địa chỉ, quận, ghi chú, phòng)
DU_AN = [
    (
        "sale1@ancu365.vn", "chunha1@ancu365.vn",
        "Vinhomes Grand Park — toà S1", "Nguyễn Xiển", "Thủ Đức",
        "Full nội thất, gần Vincom. Điện 3.500đ/số, nước 15k/khối.",
        [("S1-1201", 8_500_000, 45, True), ("S1-1202", 9_200_000, 52, True),
         ("S1-1508", 11_500_000, 68, True), ("S1-0903", 7_800_000, 38, False),
         ("S1-1707", 10_400_000, 60, False)],
    ),
    (
        "sale1@ancu365.vn", "chunha1@ancu365.vn",
        "Him Lam Riverside — toà A2", "D1, Him Lam", "Quận 7",
        "View sông, có hầm để xe. Miễn phí quản lý 3 tháng đầu.",
        [("A2-0501", 12_000_000, 70, True), ("A2-0502", 12_500_000, 72, True),
         ("A2-1103", 15_000_000, 95, False)],
    ),
    (
        "sale4@ancu365.vn", "chunha2@ancu365.vn",
        "Nhà trọ Gò Vấp — dãy B", "Lê Đức Thọ", "Gò Vấp",
        "Giờ giấc tự do, có chỗ để xe máy. Điện 3.000đ/số.",
        [("B01", 3_200_000, 22, True), ("B02", 3_500_000, 25, True),
         ("B03", 3_500_000, 25, True), ("B04", 3_800_000, 28, False)],
    ),
]

NHAN_XET = [
    (5, "Anh dẫn xem 3 căn trong một buổi, nói thẳng căn nào ẩm căn nào không."),
    (5, "Phản hồi rất nhanh, chốt hợp đồng trong ngày. Giá đúng như rao."),
    (5, "Hỗ trợ làm hợp đồng và đăng ký tạm trú, không phát sinh phí nào."),
    (4, "Tư vấn tốt, chỉ là hôm đầu tới trễ 15 phút."),
    (5, "Đã thuê qua anh hai lần, lần nào cũng rõ ràng."),
    (5, "Chủ động báo khi có căn mới hợp nhu cầu."),
]


def _nguoi(db, models, auth, *, email, ten, phone, role, account_type,
           nam=0, bio=None, seed_avatar=None):
    u = db.query(models.User).filter(models.User.email == email).first()
    if u:
        return u
    u = models.User(
        name=ten,
        email=email,
        password_hash=auth.hash_password(MAT_KHAU),
        phone=phone,
        role=role,
        account_type=account_type,
        avatar_path=_avatar(seed_avatar or email.split("@")[0]),
        bio=bio,
        is_active=True,
        created_at=datetime.utcnow() - timedelta(days=365 * max(nam, 0) + 30),
    )
    db.add(u)
    db.flush()
    return u


def run(db) -> None:
    from app import auth, helpers, models

    now = datetime.utcnow()
    loai = db.query(models.Category).first()
    if loai is None:
        raise RuntimeError("Bảng categories rỗng — chạy app.seed trước")

    # ── Tài khoản ────────────────────────────────────────────────────────────
    _nguoi(db, models, auth, **ADMIN)

    chu = {}
    for c in CHU_NHA:
        u = _nguoi(
            db, models, auth,
            email=c["email"], ten=c["ten"], phone=c["phone"],
            role="host", account_type="owner", nam=c["nam"],
        )
        chu[c["email"]] = u
        if (
            db.query(models.HostProfile)
            .filter(models.HostProfile.user_id == u.id)
            .first()
            is None
        ):
            db.add(
                models.HostProfile(
                    user_id=u.id, verified=True, created_at=now, updated_at=now
                )
            )

    sale = {}
    for s in SALE:
        u = _nguoi(
            db, models, auth,
            email=s["email"], ten=s["ten"], phone=s["phone"],
            # SALE CHÍNH LÀ HOST: trong mô hình này người đăng tin là môi
            # giới, còn `account_type='owner'` (chủ nhà) là vai khác — quản lý
            # điện nước/hoá đơn, đăng tin phải qua môi giới. Để `role='guest'`
            # thì PUT/DELETE /api/houses/{id} (gác bằng require_host) trả 403
            # ngay trên tin của chính họ.
            role="host", account_type="sale", nam=s["nam"], bio=s["bio"],
        )
        sale[s["email"]] = u

        hs = (
            db.query(models.SaleProfile)
            .filter(models.SaleProfile.user_id == u.id)
            .first()
        )
        if hs is None:
            from app.routers.sale_links import _sinh_ma

            db.add(
                models.SaleProfile(
                    user_id=u.id,
                    sale_code=_sinh_ma(db),
                    display_name=s["ten"],
                    bio=s["bio"],
                    service_areas=s["khu"],
                    created_at=now,
                    updated_at=now,
                )
            )
        hp = (
            db.query(models.HostProfile)
            .filter(models.HostProfile.user_id == u.id)
            .first()
        )
        if hp is None:
            hp = models.HostProfile(user_id=u.id, created_at=now, updated_at=now)
            db.add(hp)
        # `verified` là cờ do admin/KYC đặt — seed bật để xem giao diện. Khác
        # hẳn các cột SỐ ĐO bên dưới, những cột đó phải TỰ tính ra.
        hp.verified = True
        hp.show_phone = s["cong_khai_sdt"]
        hp.zalo = s["phone"] if s["cong_khai_sdt"] else None
        hp.agency = s["agency"]
        hp.updated_at = now
    db.flush()

    # ── Tin đăng ─────────────────────────────────────────────────────────────
    tin_theo_sale: dict[str, list] = {e: [] for e in sale}
    for i, (em, tieu_de, gia, quan, dt, pn, lat, lng, gd) in enumerate(TIN):
        h = (
            db.query(models.House)
            .filter(models.House.title == tieu_de)
            .first()
        )
        if h is None:
            h = models.House(
                host_id=sale[em].id,
                title=tieu_de,
                description="Nhà đã kiểm tra thực tế. Liên hệ để xem trong ngày.",
                price=gia,
                area=dt,
                bedrooms=pn,
                bathrooms=max(1, pn - 1),
                address="Số 1",
                district=quan,
                city="TP.HCM",
                category_id=loai.id,
                latitude=lat,
                longitude=lng,
                transaction_type=gd,
                status="published",
                images=[A[i % len(A)], A[(i + 2) % len(A)]],
                created_at=now - timedelta(days=i * 3),
            )
            db.add(h)
            db.flush()
        tin_theo_sale[em].append(h)

    # ── Dự án + phòng + liên kết sale ↔ chủ nhà ─────────────────────────────
    for em_sale, em_chu, ten, dia_chi, quan, ghi_chu, phong in DU_AN:
        s_u, c_u = sale[em_sale], chu[em_chu]

        if (
            db.query(models.SaleOwnerLink)
            .filter(
                models.SaleOwnerLink.sale_id == s_u.id,
                models.SaleOwnerLink.owner_id == c_u.id,
            )
            .first()
            is None
        ):
            db.add(
                models.SaleOwnerLink(
                    sale_id=s_u.id,
                    owner_id=c_u.id,
                    status="active",
                    linked_at=now - timedelta(days=120),
                    created_by=c_u.id,
                )
            )

        toa = (
            db.query(models.Building).filter(models.Building.name == ten).first()
        )
        if toa is None:
            # Chủ nhà ĐỨNG TÊN toà (đúng thực tế pháp lý), sale là người vận hành.
            toa = models.Building(
                host_id=c_u.id,
                name=ten,
                address=dia_chi,
                district=quan,
                city="TP.HCM",
                note=ghi_chu,
                is_public=True,
                created_by_user_id=s_u.id,
                created_at=now,
                updated_at=now,
            )
            db.add(toa)
            db.flush()

        for k, (ma, gia, dt, trong) in enumerate(phong):
            p = (
                db.query(models.Room)
                .filter(models.Room.building_id == toa.id, models.Room.code == ma)
                .first()
            )
            if p is None:
                p = models.Room(
                    building_id=toa.id,
                    code=ma,
                    base_price=gia,
                    area_m2=dt,
                    capacity=2,
                    status="vacant" if trong else "occupied",
                    images=[A[k % len(A)]],
                    owner_id=c_u.id,
                    managed_by_sale_id=s_u.id,
                    created_at=now,
                    updated_at=now,
                )
                db.add(p)
                db.flush()

            # Giao dịch CHỈ trên phòng đã thuê — chốt một phòng còn rao trống
            # là dữ liệu tự mâu thuẫn.
            if not trong:
                khach = _nguoi(
                    db, models, auth,
                    email=f"khach_{toa.id}_{ma}@ancu365.vn".lower(),
                    ten=f"Khách thuê {ma}",
                    phone="",
                    role="guest",
                    account_type="customer",
                )
                if (
                    db.query(models.Deal)
                    .filter(
                        models.Deal.room_id == p.id,
                        models.Deal.customer_id == khach.id,
                    )
                    .first()
                    is None
                ):
                    t = now - timedelta(days=30)
                    db.add(
                        models.Deal(
                            room_id=p.id,
                            owner_id=c_u.id,
                            sale_id=s_u.id,
                            customer_id=khach.id,
                            deal_type="rent",
                            amount=int(gia),
                            status="confirmed",
                            created_at=t,
                            confirmed_at=t + timedelta(hours=6),
                            confirmed_by=c_u.id,
                        )
                    )
    db.flush()

    # ── Lịch hẹn ĐÃ phản hồi + đánh giá gắn với chính lịch hẹn đó ───────────
    # KHÔNG bơm `avg_response_hours` hay `verified_review_count`. Dựng sự kiện
    # rồi để `recompute_host_reputation` tự tính.
    for s in SALE:
        n = s["so_danh_gia"]
        tin = tin_theo_sale[s["email"]]
        if n == 0 or not tin:
            continue
        for k in range(n):
            diem, chu_thich = NHAN_XET[k % len(NHAN_XET)]
            nguoi_xem = _nguoi(
                db, models, auth,
                email=f"khach_xem_{s['email'].split('@')[0]}_{k}@ancu365.vn",
                ten=f"Khách xem nhà {k + 1}",
                phone="",
                role="guest",
                account_type="customer",
            )
            h = tin[k % len(tin)]
            if (
                db.query(models.ViewingAppointment)
                .filter(
                    models.ViewingAppointment.house_id == h.id,
                    models.ViewingAppointment.guest_id == nguoi_xem.id,
                )
                .first()
                is None
            ):
                tao = now - timedelta(days=20 + k)
                db.add(
                    models.ViewingAppointment(
                        house_id=h.id,
                        guest_id=nguoi_xem.id,
                        booking_date=(tao + timedelta(days=1)).strftime("%Y-%m-%d"),
                        booking_time="09:00-10:00",
                        message="Em muốn xem căn này",
                        status="completed",
                        created_at=tao,
                        # Nguồn DUY NHẤT của chip "Phản hồi trong X".
                        responded_at=tao + timedelta(minutes=20 + k * 5),
                    )
                )
                db.flush()
            if (
                db.query(models.Review)
                .filter(
                    models.Review.house_id == h.id,
                    models.Review.user_id == nguoi_xem.id,
                )
                .first()
                is None
            ):
                db.add(
                    models.Review(
                        user_id=nguoi_xem.id,
                        house_id=h.id,
                        rating=diem,
                        comment=chu_thich,
                        # Hợp lệ vì người này CÓ lịch hẹn đã hoàn thành ở trên.
                        verified_relationship=True,
                        created_at=now - timedelta(days=18 + k),
                    )
                )
    db.flush()

    for u in sale.values():
        helpers.recompute_host_reputation(db, u.id)
    db.commit()

    # ── Báo cáo ──────────────────────────────────────────────────────────────
    print(f"mật khẩu chung: {MAT_KHAU}\n")
    print(f"  admin   {ADMIN['email']}")
    for c in CHU_NHA:
        print(f"  chủ nhà {c['email']:26} id={chu[c['email']].id}")
    print()
    for s in SALE:
        u = sale[s["email"]]
        p = (
            db.query(models.HostProfile)
            .filter(models.HostProfile.user_id == u.id)
            .first()
        )
        hs = (
            db.query(models.SaleProfile)
            .filter(models.SaleProfile.user_id == u.id)
            .first()
        )
        n_tin = (
            db.query(models.House)
            .filter(
                models.House.host_id == u.id,
                models.House.status == "published",
            )
            .count()
        )
        n_deal = (
            db.query(models.Deal)
            .filter(
                models.Deal.sale_id == u.id, models.Deal.status == "confirmed"
            )
            .count()
        )
        print(
            f"  sale    {s['email']:26} /sale/{u.id:<5} mã={hs.sale_code}  "
            f"tin={n_tin} deal={n_deal} đánh_giá_đã_kiểm={p.verified_review_count} "
            f"mẫu_phản_hồi={p.response_sample} uy_tín={helpers.is_trusted_host(p)}"
        )


def main() -> None:
    from app.database import SessionLocal

    with SessionLocal() as db:
        run(db)


if __name__ == "__main__":
    main()
