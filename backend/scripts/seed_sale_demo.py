"""seed_sale_demo.py — dựng MỘT tài khoản sale hoàn chỉnh để xem trang /sale/:id.

Vì sao cần: dữ liệu seed hiện có toàn chủ nhà. Trang sale vì thế trống một nửa
— không dự án cho thuê, không giao dịch, không huy hiệu nào đứng được.

Nguyên tắc: **seed phải TỰ NHẤT QUÁN**, không bơm thẳng số đẹp vào cột tổng
hợp. Cụ thể:
  - Muốn có huy hiệu "Phản hồi nhanh" thì phải có lịch hẹn thật kèm
    `responded_at`, rồi để `recompute_host_reputation` tự tính.
  - Muốn có "Người bán uy tín" thì đánh giá phải gắn với lịch hẹn đã hoàn thành
    của chính người viết (`verified_relationship=True` mới hợp lệ).
  - Muốn có "N giao dịch" thì phải có `deals` ở trạng thái `confirmed`.
Bơm thẳng vào `avg_response_hours` là đúng cái sai mà migration 0087 vừa dọn.

Chạy:
    DATABASE_URL=... python scripts/seed_sale_demo.py

Idempotent: chạy lại không nhân đôi dữ liệu.
"""

from __future__ import annotations

import os
import secrets
import sys
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

SALE_EMAIL = "sale_demo@seed.local"
OWNER_EMAIL = "chuphong_demo@seed.local"
MAT_KHAU = "seed123"
MA_SALE = "SL-VN2K7X"  # cố định để tài liệu/ảnh chụp không lệch

ANH = [
    "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=1200&q=80",
]

DU_AN = [
    {
        "ten": "Vinhomes Grand Park — toà S1",
        "dia_chi": "Nguyễn Xiển",
        "quan": "Thủ Đức",
        "tinh": "TP.HCM",
        "ghi_chu": "Full nội thất, gần Vincom. Điện 3.500đ/số, nước 15k/khối.",
        "phong": [
            ("S1-1201", 8_500_000, 45, True),
            ("S1-1202", 9_200_000, 52, True),
            ("S1-1508", 11_500_000, 68, True),
            ("S1-0903", 7_800_000, 38, False),
            ("S1-1707", 10_400_000, 60, False),
        ],
    },
    {
        "ten": "Him Lam Riverside — toà A2",
        "dia_chi": "D1, Him Lam",
        "quan": "Quận 7",
        "tinh": "TP.HCM",
        "ghi_chu": "View sông, có hầm để xe. Miễn phí quản lý 3 tháng đầu.",
        "phong": [
            ("A2-0501", 12_000_000, 70, True),
            ("A2-0502", 12_500_000, 72, True),
            ("A2-1103", 15_000_000, 95, False),
        ],
    },
]


def _nguoi(db, models, auth, email, ten, role, account_type, **kw):
    u = db.query(models.User).filter(models.User.email == email).first()
    if u:
        return u
    u = models.User(
        name=ten,
        email=email,
        password_hash=auth.hash_password(MAT_KHAU),
        role=role,
        account_type=account_type,
        is_active=True,
        created_at=datetime.utcnow() - timedelta(days=365 * 4),
        **kw,
    )
    db.add(u)
    db.flush()
    return u


def run(db) -> None:
    from app import auth, helpers, models

    now = datetime.utcnow()

    # ── 1. Sale + chủ phòng ──────────────────────────────────────────────────
    sale = _nguoi(
        db, models, auth, SALE_EMAIL, "Lê Quang Vinh", "guest", "sale",
        phone="0912345678",
        avatar_path="https://api.dicebear.com/9.x/avataaars/png?seed=salevinh&size=256",
        bio="6 năm cho thuê căn hộ Thủ Đức, Quận 7. Nhận ký gửi, xem phòng "
            "trong ngày, hỗ trợ hợp đồng.",
    )
    chu = _nguoi(
        db, models, auth, OWNER_EMAIL, "Bà Nguyễn Thị Mai", "host", "owner",
        phone="0987654321",
    )

    hs = (
        db.query(models.SaleProfile)
        .filter(models.SaleProfile.user_id == sale.id)
        .first()
    )
    if hs is None:
        hs = models.SaleProfile(
            user_id=sale.id,
            sale_code=MA_SALE,
            display_name="Lê Quang Vinh",
            bio=sale.bio,
            service_areas=["Thủ Đức", "Quận 7", "Bình Thạnh"],
            created_at=now,
            updated_at=now,
        )
        db.add(hs)
        db.flush()

    # Hồ sơ host cho CẢ HAI: `verified` là cờ do admin/KYC đặt, seed đặt để
    # xem giao diện — khác hẳn các cột SỐ ĐO bên dưới, những cột đó phải tự
    # tính ra từ dữ liệu thật.
    for uid in (sale.id, chu.id):
        hp = (
            db.query(models.HostProfile)
            .filter(models.HostProfile.user_id == uid)
            .first()
        )
        if hp is None:
            hp = models.HostProfile(user_id=uid, created_at=now, updated_at=now)
            db.add(hp)
        # Đặt lại MỖI LẦN chạy, không chỉ khi tạo mới: hồ sơ có thể đã tồn tại
        # từ đợt seed trước cột `show_phone` ra đời.
        hp.verified = True
        # Bật liên hệ trực tiếp cho tài khoản demo, nếu không thanh CTA sẽ
        # trống đúng chỗ vừa xây. Mặc định của HỆ THỐNG vẫn là TẮT (mig 0088).
        hp.show_phone = True
        hp.zalo = "0912345678"
        hp.agency = "Vinhomes Grand Park · Him Lam Land"
        hp.updated_at = now
    db.flush()

    # ── 2. Liên kết sale ↔ chủ phòng ────────────────────────────────────────
    lk = (
        db.query(models.SaleOwnerLink)
        .filter(
            models.SaleOwnerLink.sale_id == sale.id,
            models.SaleOwnerLink.owner_id == chu.id,
        )
        .first()
    )
    if lk is None:
        db.add(
            models.SaleOwnerLink(
                sale_id=sale.id,
                owner_id=chu.id,
                status="active",
                linked_at=now - timedelta(days=120),
                created_by=chu.id,
            )
        )
        db.flush()

    # ── 3. Dự án + phòng ────────────────────────────────────────────────────
    # Chủ phòng ĐỨNG TÊN toà (đúng thực tế pháp lý), sale là người vận hành.
    phong_trong: list[models.Room] = []
    phong_da_thue: list[models.Room] = []
    for i, d in enumerate(DU_AN):
        toa = (
            db.query(models.Building)
            .filter(
                models.Building.host_id == chu.id, models.Building.name == d["ten"]
            )
            .first()
        )
        if toa is None:
            toa = models.Building(
                host_id=chu.id,
                name=d["ten"],
                address=d["dia_chi"],
                district=d["quan"],
                city=d["tinh"],
                note=d["ghi_chu"],
                is_public=True,
                created_by_user_id=sale.id,
                created_at=now,
                updated_at=now,
            )
            db.add(toa)
            db.flush()

        for j, (ma, gia, dt, con_trong) in enumerate(d["phong"]):
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
                    status="vacant" if con_trong else "occupied",
                    images=[ANH[(i + j) % len(ANH)]],
                    owner_id=chu.id,
                    managed_by_sale_id=sale.id,
                    created_at=now,
                    updated_at=now,
                )
                db.add(p)
                db.flush()
            (phong_trong if con_trong else phong_da_thue).append(p)

    # ── 4. Giao dịch đã chốt ────────────────────────────────────────────────
    # Chỉ chốt trên phòng ĐÃ THUÊ — chốt một phòng còn trống là dữ liệu tự mâu
    # thuẫn (đã có khách mà vẫn rao trống).
    for k, p in enumerate(phong_da_thue):
        khach = _nguoi(
            db, models, auth,
            f"khach_deal_{k}@seed.local", f"Khách thuê {k + 1}", "guest", "customer",
        )
        co = (
            db.query(models.Deal)
            .filter(models.Deal.room_id == p.id, models.Deal.customer_id == khach.id)
            .first()
        )
        if co is None:
            t = now - timedelta(days=30 * (k + 1))
            db.add(
                models.Deal(
                    room_id=p.id,
                    owner_id=chu.id,
                    sale_id=sale.id,
                    customer_id=khach.id,
                    deal_type="rent",
                    amount=int(p.base_price or 0),
                    status="confirmed",
                    created_at=t,
                    confirmed_at=t + timedelta(hours=6),
                    confirmed_by=chu.id,
                )
            )
    db.flush()

    # ── 5. Tin đăng của sale ────────────────────────────────────────────────
    loai = db.query(models.Category).first()
    tin: list[models.House] = []
    # Toạ độ THẬT của từng khu — bìa hồ sơ là bản đồ ghim tin, thiếu toạ độ thì
    # nó rơi về nền đỏ trơn và mất hẳn khối thông tin lớn nhất trang.
    mau_tin = [
        ("Căn hộ 2PN 68m² Vinhomes Grand Park", 9_200_000, "Thủ Đức", "TP.HCM", 68, 2, 10.8443, 106.8390),
        ("Căn hộ 1PN 45m² Him Lam Riverside", 8_000_000, "Quận 7", "TP.HCM", 45, 1, 10.7395, 106.7020),
        ("Studio 32m² full nội thất Bình Thạnh", 6_500_000, "Bình Thạnh", "TP.HCM", 32, 1, 10.8039, 106.7100),
        ("Căn hộ 3PN 95m² view sông Quận 7", 15_000_000, "Quận 7", "TP.HCM", 95, 3, 10.7290, 106.7180),
        ("Officetel 40m² Thủ Đức", 7_200_000, "Thủ Đức", "TP.HCM", 40, 1, 10.8510, 106.7590),
    ]
    for k, (tieu_de, gia, quan, tinh, dt, pn, lat, lng) in enumerate(mau_tin):
        h = (
            db.query(models.House)
            .filter(models.House.host_id == sale.id, models.House.title == tieu_de)
            .first()
        )
        if h is None:
            h = models.House(
                host_id=sale.id,
                title=tieu_de,
                description="Nhà đã kiểm tra thực tế, có sẵn nội thất, dọn vào ở ngay.",
                price=gia,
                area=dt,
                bedrooms=pn,
                bathrooms=1,
                address="Số 1",
                district=quan,
                city=tinh,
                category_id=loai.id if loai else 1,
                latitude=lat,
                longitude=lng,
                status="published",
                images=[ANH[k % len(ANH)]],
                created_at=now - timedelta(days=k * 7),
            )
            db.add(h)
            db.flush()
        tin.append(h)

    # ── 6. Lịch hẹn ĐÃ phản hồi + đánh giá gắn với lịch hẹn đó ──────────────
    # Đây là phần quan trọng nhất: KHÔNG bơm `avg_response_hours` hay
    # `verified_review_count`. Dựng sự kiện có thật rồi để
    # `recompute_host_reputation` tự tính ra chúng.
    nhan_xet = [
        (5, "Anh Vinh dẫn xem 3 căn trong một buổi, nói thẳng căn nào ẩm căn nào không."),
        (5, "Phản hồi rất nhanh, chốt hợp đồng trong ngày. Giá đúng như rao."),
        (5, "Hỗ trợ làm hợp đồng và đăng ký tạm trú, không phát sinh phí nào."),
        (4, "Tư vấn tốt, chỉ là hôm đầu tới trễ 15 phút."),
        (5, "Đã thuê qua anh hai lần, lần nào cũng rõ ràng."),
        (5, "Chủ động báo khi có căn mới hợp nhu cầu."),
    ]
    for k, (diem, chu_thich) in enumerate(nhan_xet):
        nguoi_xem = _nguoi(
            db, models, auth,
            f"khach_review_{k}@seed.local", f"Khách xem nhà {k + 1}", "guest", "customer",
        )
        h = tin[k % len(tin)]

        lh = (
            db.query(models.ViewingAppointment)
            .filter(
                models.ViewingAppointment.house_id == h.id,
                models.ViewingAppointment.guest_id == nguoi_xem.id,
            )
            .first()
        )
        if lh is None:
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
                    # 20–50 phút: đây là nguồn DUY NHẤT của "Phản hồi nhanh".
                    responded_at=tao + timedelta(minutes=20 + k * 5),
                )
            )
            db.flush()

        rv = (
            db.query(models.Review)
            .filter(
                models.Review.house_id == h.id,
                models.Review.user_id == nguoi_xem.id,
            )
            .first()
        )
        if rv is None:
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

    # ── 7. Tính lại uy tín từ dữ liệu vừa dựng ──────────────────────────────
    helpers.recompute_host_reputation(db, sale.id)
    db.commit()

    prof = (
        db.query(models.HostProfile)
        .filter(models.HostProfile.user_id == sale.id)
        .first()
    )
    print(f"[seed_sale] sale id={sale.id} email={SALE_EMAIL} mã={MA_SALE}")
    print(f"[seed_sale] chủ phòng id={chu.id} email={OWNER_EMAIL}")
    print(
        f"[seed_sale] rating={prof.rating} đánh giá đã kiểm={prof.verified_review_count} "
        f"mẫu phản hồi={prof.response_sample} giờ={prof.avg_response_hours}"
    )
    print(f"[seed_sale] trusted={helpers.is_trusted_host(prof)}")
    print(f"[seed_sale] xem tại /sale/{sale.id}")


def main() -> None:
    from app.database import SessionLocal

    with SessionLocal() as db:
        run(db)


if __name__ == "__main__":
    main()
