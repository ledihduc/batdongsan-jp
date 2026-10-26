"""seed_staging_noi_dung.py — nội dung xoay quanh 8 tài khoản gốc.

Chạy SAU `seed_staging.py`. Dựng những thứ làm app trông có người dùng thật:

  · bài viết cộng đồng + like + bình luận (đếm khớp bản ghi thật)
  · album tin đăng của sale
  · tin "cần thuê / cần mua" của khách
  · tin đã lưu (yêu thích)
  · lịch hẹn xem nhà ĐANG CHỜ — để hộp việc của sale không rỗng
  · hợp đồng thuê + khách thuê + chỉ số điện nước + hoá đơn cho 2 chủ nhà
  · thông báo

Nguyên tắc giữ nguyên: **không bơm số vào cột tổng hợp**. `like_count` và
`comment_count` được đếm lại từ bảng like/comment thật, không gán bừa — nếu gán
thì bấm vào bài sẽ thấy 12 lượt thích mà danh sách trống.

Chạy:
    DATABASE_URL=... python scripts/seed_staging_noi_dung.py

Idempotent: chạy lại không nhân đôi.
"""

from __future__ import annotations

import os
import sys
from datetime import date, datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

MAT_KHAU = "ancu2026"

ANH = [
    "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1493809842364-78817add7ffb?auto=format&fit=crop&w=1200&q=80",
]

# (email tác giả, nội dung, số ảnh, số ngày trước)
BAI_VIET = [
    ("sale1@ancu365.vn",
     "Vừa nhận ký gửi 3 căn 2PN toà S1 Vinhomes Grand Park, view nội khu, "
     "full nội thất. Giá 8.5–9.2tr, có thể xem nhà trong ngày. Ai cần inbox "
     "em gửi clip thực tế.", 2, 1),
    ("sale1@ancu365.vn",
     "Kinh nghiệm cho người thuê lần đầu: luôn hỏi rõ tiền điện nước tính "
     "theo giá nào TRƯỚC khi đặt cọc. Nhiều nơi báo giá phòng rẻ nhưng điện "
     "5k/số, ở 4 người là chênh cả triệu mỗi tháng.", 0, 4),
    ("sale1@ancu365.vn",
     "Đã bàn giao căn A2-0502 Him Lam Riverside cho anh chị khách hôm nay. "
     "Cảm ơn anh chị đã tin tưởng. Toà A2 còn đúng 1 căn 3PN.", 1, 9),
    ("sale2@ancu365.vn",
     "Căn hộ dịch vụ Quận 1 tháng này khá nhiều hàng, giá mềm hơn quý trước "
     "khoảng 8%. Anh chị nào đang tìm chỗ gần trung tâm thì đây là lúc hợp lý.",
     1, 2),
    ("sale2@ancu365.vn",
     "Studio 28m² Quận 3 có ban công, bếp riêng, giờ giấc tự do. Em ưu tiên "
     "khách thuê từ 6 tháng.", 2, 6),
    ("sale3@ancu365.vn",
     "Lưu ý khi mua đất nền khu Đông: kiểm tra quy hoạch lộ giới TRƯỚC khi "
     "đặt cọc. Em đã gặp 2 trường hợp đất dính hành lang đường mà sổ vẫn đẹp.",
     0, 3),
    ("sale3@ancu365.vn",
     "Nhà phố 1 trệt 2 lầu Thủ Đức, hẻm xe hơi 5m, sổ hồng riêng hoàn công "
     "đầy đủ. Chính chủ gửi bán, thương lượng được.", 2, 7),
    ("sale4@ancu365.vn",
     "Nhận quản lý nhà trọ trọn gói cho chủ nhà ở xa: thu tiền, chốt điện "
     "nước, xử lý sự cố, báo cáo hàng tháng. Đang vận hành 4 dãy khu Gò Vấp.",
     1, 5),
    ("chunha1@ancu365.vn",
     "Toà S1 nhà mình vừa thay toàn bộ máy nước nóng và sơn lại hành lang. "
     "Cảm ơn các bạn thuê đã kiên nhẫn mấy hôm thi công.", 1, 8),
]

BINH_LUAN = [
    "Căn này còn không anh?",
    "Cho em xin giá cuối ạ.",
    "Thông tin hữu ích, cảm ơn anh.",
    "Em nhắn tin rồi nhé.",
    "Khu này đi trung tâm có xa không ạ?",
]

# Tin cần thuê / cần mua của khách
NHU_CAU = [
    ("rent", "Cần thuê căn 2PN Thủ Đức", 7_000_000, 10_000_000, 2, "Thủ Đức"),
    ("rent", "Tìm studio gần trung tâm Q1", 6_000_000, 9_000_000, 1, "Quận 1"),
    ("buy", "Cần mua nhà phố Thủ Đức dưới 6 tỷ", 4_000_000_000, 6_000_000_000, 3, "Thủ Đức"),
]


def _lay(db, models, email):
    return db.query(models.User).filter(models.User.email == email).first()


def _khach(db, models, auth, so: int, ten: str):
    email = f"khach{so}@ancu365.vn"
    u = db.query(models.User).filter(models.User.email == email).first()
    if u:
        return u
    u = models.User(
        name=ten,
        email=email,
        password_hash=auth.hash_password(MAT_KHAU),
        phone=f"0938{so:06d}",
        role="guest",
        account_type="customer",
        avatar_path=f"https://api.dicebear.com/9.x/avataaars/png?seed=khach{so}&size=256",
        is_active=True,
        created_at=datetime.utcnow() - timedelta(days=120),
    )
    db.add(u)
    db.flush()
    return u


def run(db) -> None:
    from app import auth, models
    from app.domain.demand_post import DemandPost

    now = datetime.utcnow()

    # 6 khách để có người like, bình luận, lưu tin, gửi nhu cầu.
    khach = [
        _khach(db, models, auth, i, ten)
        for i, ten in enumerate(
            ["Ngô Bảo Anh", "Lý Thu Hằng", "Bùi Đức Trung",
             "Hoàng Kim Chi", "Đặng Quốc Huy", "Mai Phương Thảo"],
            start=1,
        )
    ]
    db.flush()

    # ── Bài viết + like + bình luận ─────────────────────────────────────────
    for i, (em, chu, so_anh, ngay) in enumerate(BAI_VIET):
        tg = _lay(db, models, em)
        if tg is None:
            continue
        bai = (
            db.query(models.SocialPost)
            .filter(models.SocialPost.content == chu)
            .first()
        )
        if bai is None:
            bai = models.SocialPost(
                user_id=tg.id,
                content=chu,
                images=[ANH[(i + k) % len(ANH)] for k in range(so_anh)],
                category="lease",
                location_text="TP.HCM",
                status="published",
                created_at=now - timedelta(days=ngay, hours=i),
            )
            db.add(bai)
            db.flush()

        # Like THẬT rồi mới đếm lại — gán thẳng like_count thì bấm vào bài sẽ
        # thấy 12 lượt thích mà danh sách trống.
        for k in range((i % 4) + 2):
            u = khach[(i + k) % len(khach)]
            if (
                db.query(models.SocialPostLike)
                .filter(
                    models.SocialPostLike.post_id == bai.id,
                    models.SocialPostLike.user_id == u.id,
                )
                .first()
                is None
            ):
                db.add(
                    models.SocialPostLike(
                        post_id=bai.id, user_id=u.id, created_at=now
                    )
                )
        for k in range(i % 3):
            u = khach[(i + k + 2) % len(khach)]
            noi_dung = BINH_LUAN[(i + k) % len(BINH_LUAN)]
            if (
                db.query(models.SocialComment)
                .filter(
                    models.SocialComment.post_id == bai.id,
                    models.SocialComment.user_id == u.id,
                    models.SocialComment.content == noi_dung,
                )
                .first()
                is None
            ):
                db.add(
                    models.SocialComment(
                        target_type="post",
                        post_id=bai.id,
                        user_id=u.id,
                        content=noi_dung,
                        created_at=now - timedelta(days=ngay) + timedelta(hours=k + 1),
                    )
                )
        db.flush()
        bai.like_count = (
            db.query(models.SocialPostLike)
            .filter(models.SocialPostLike.post_id == bai.id)
            .count()
        )
        bai.comment_count = (
            db.query(models.SocialComment)
            .filter(
                models.SocialComment.target_type == "post",
                models.SocialComment.post_id == bai.id,
            )
            .count()
        )
    db.flush()

    # ── Tin nhu cầu + tin đã lưu ────────────────────────────────────────────
    moi_tin = (
        db.query(models.House)
        .filter(models.House.status == "published")
        .order_by(models.House.id)
        .all()
    )
    for i, (loai, tieu_de, tu, den, pn, quan) in enumerate(NHU_CAU):
        u = khach[i % len(khach)]
        # `DemandPost` không có cột tiêu đề — nội dung nằm ở `note`, nên dùng
        # chính nó làm khoá chống trùng.
        if (
            db.query(DemandPost)
            .filter(DemandPost.user_id == u.id, DemandPost.note == tieu_de)
            .first()
            is None
        ):
            db.add(
                DemandPost(
                    user_id=u.id,
                    kind=loai,
                    province_name="TP.HCM",
                    area_label=quan,
                    budget_min=tu,
                    budget_max=den,
                    bedrooms_min=pn,
                    move_in_date=date.today() + timedelta(days=20),
                    note=tieu_de,
                    status="open",
                    # NOT NULL ở DB — tin nhu cầu luôn có hạn, hết hạn thì rơi
                    # khỏi feed thay vì nằm lại mãi.
                    expires_at=now + timedelta(days=30),
                    created_at=now - timedelta(days=i + 1),
                )
            )
    for i, u in enumerate(khach):
        for h in moi_tin[i : i + 2]:
            if (
                db.query(models.Wishlist)
                .filter(
                    models.Wishlist.user_id == u.id,
                    models.Wishlist.house_id == h.id,
                )
                .first()
                is None
            ):
                db.add(
                    models.Wishlist(user_id=u.id, house_id=h.id, created_at=now)
                )
    db.flush()

    # ── Lịch hẹn ĐANG CHỜ — việc cần xử lý của sale ─────────────────────────
    for i, h in enumerate(moi_tin[:4]):
        u = khach[(i + 3) % len(khach)]
        if (
            db.query(models.ViewingAppointment)
            .filter(
                models.ViewingAppointment.house_id == h.id,
                models.ViewingAppointment.guest_id == u.id,
            )
            .first()
            is None
        ):
            db.add(
                models.ViewingAppointment(
                    house_id=h.id,
                    guest_id=u.id,
                    booking_date=(now + timedelta(days=i + 1)).strftime("%Y-%m-%d"),
                    booking_time="14:00-15:00",
                    message="Em muốn xem căn này cuối tuần được không ạ?",
                    status="pending",
                    created_at=now - timedelta(hours=i + 2),
                )
            )
            db.add(
                models.Notification(
                    user_id=h.host_id,
                    title="Có khách xin xem nhà",
                    body=f"{u.name} muốn xem “{h.title}”.",
                    type="viewing_requested",
                    related_id=h.id,
                    created_at=now - timedelta(hours=i + 2),
                )
            )
    db.flush()

    # ── Hợp đồng + khách thuê + chỉ số + hoá đơn cho chủ nhà ────────────────
    # Chỉ trên phòng ĐANG occupied. Phòng còn trống mà có hợp đồng đang chạy là
    # dữ liệu tự mâu thuẫn.
    phong_thue = (
        db.query(models.Room).filter(models.Room.status == "occupied").all()
    )
    for i, p in enumerate(phong_thue):
        toa = db.get(models.Building, p.building_id)
        if toa is None:
            continue
        chu_id = p.owner_id or toa.host_id

        nguon = (
            db.query(models.RevenueSource)
            .filter(models.RevenueSource.host_id == chu_id)
            .first()
        )
        if nguon is None:
            nguon = models.RevenueSource(
                host_id=chu_id, name="Trực tiếp", created_at=now, updated_at=now
            )
            db.add(nguon)
            db.flush()

        hd = (
            db.query(models.Contract)
            .filter(models.Contract.room_id == p.id)
            .first()
        )
        if hd is None:
            bat_dau = now - timedelta(days=90)
            hd = models.Contract(
                host_id=chu_id,
                source_id=nguon.id,
                room_id=p.id,
                start_date=bat_dau.strftime("%Y-%m-%d"),
                end_date=(bat_dau + timedelta(days=365)).strftime("%Y-%m-%d"),
                monthly_rent=float(p.base_price or 0),
                deposit=float(p.base_price or 0),
                status="active",
                created_at=bat_dau,
                updated_at=now,
            )
            db.add(hd)
            db.flush()

            kt = models.Tenant(
                host_id=chu_id,
                full_name=f"Khách thuê {p.code}",
                phone=f"0977{i:06d}",
                created_at=now,
            )
            db.add(kt)
            db.flush()
            db.add(
                models.ContractTenant(
                    contract_id=hd.id,
                    tenant_id=kt.id,
                    is_primary=True,
                    joined_at=hd.start_date,
                )
            )

        # Chỉ số điện nước 2 kỳ gần nhất.
        for k in (2, 1):
            ngay = (now - timedelta(days=30 * k)).strftime("%Y-%m-%d")
            if (
                db.query(models.MeterReading)
                .filter(
                    models.MeterReading.room_id == p.id,
                    models.MeterReading.reading_date == ngay,
                )
                .first()
                is None
            ):
                db.add(
                    models.MeterReading(
                        host_id=chu_id,
                        room_id=p.id,
                        reading_date=ngay,
                        electricity_kwh=120 + k * 35 + i * 5,
                        water_m3=6 + k + i,
                        created_at=now,
                    )
                )

        # Hoá đơn kỳ trước (đã thu) + kỳ này (chưa thu).
        #
        # `ck_invoices_status` chỉ cho draft|sent|paid|overdue|cancelled — KHÔNG
        # có 'issued'. Trạng thái hợp lệ cho hoá đơn đã phát hành chưa thu là
        # 'sent'.
        for k, (tt, da_thu) in enumerate((("paid", True), ("sent", False))):
            dau = (now - timedelta(days=30 * (2 - k))).replace(day=1)
            so = f"HD{p.id:04d}{dau.strftime('%m%y')}"
            if (
                db.query(models.Invoice)
                .filter(models.Invoice.invoice_number == so)
                .first()
                is not None
            ):
                continue
            tien_phong = float(p.base_price or 0)
            tien_dien = 35 * 3500
            tien_nuoc = 6 * 15000
            tong = tien_phong + tien_dien + tien_nuoc
            hoa_don = models.Invoice(
                host_id=chu_id,
                contract_id=hd.id,
                invoice_number=so,
                period_start=dau.strftime("%Y-%m-%d"),
                period_end=(dau + timedelta(days=29)).strftime("%Y-%m-%d"),
                issued_date=(dau + timedelta(days=30)).strftime("%Y-%m-%d"),
                # Kỳ chưa thu phải còn hạn, nếu không nó là công nợ quá hạn
                # chứ không phải hoá đơn bình thường.
                due_date=(
                    (dau + timedelta(days=35))
                    if da_thu
                    else (now + timedelta(days=5))
                ).strftime("%Y-%m-%d"),
                status=tt,
                total_amount=tong,
                paid_amount=tong if da_thu else 0,
                paid_at=now - timedelta(days=25) if da_thu else None,
                created_at=dau,
                updated_at=now,
            )
            db.add(hoa_don)
            db.flush()
            for so_tt, (loai_kh, mo_ta, sl, don_gia) in enumerate(
                (
                    ("rent", "Tiền phòng", 1, tien_phong),
                    ("electricity", "Điện (35 số × 3.500đ)", 35, 3500),
                    ("water", "Nước (6 khối × 15.000đ)", 6, 15000),
                )
            ):
                db.add(
                    models.InvoiceLineItem(
                        invoice_id=hoa_don.id,
                        category=loai_kh,
                        description=mo_ta,
                        quantity=sl,
                        unit_price=don_gia,
                        amount=sl * don_gia,
                        sort_order=so_tt,
                    )
                )
            if da_thu:
                db.add(
                    models.Payment(
                        host_id=chu_id,
                        invoice_id=hoa_don.id,
                        amount=tong,
                        method="cash",
                        paid_at=now - timedelta(days=25),
                        created_at=now - timedelta(days=25),
                    )
                )
    db.commit()

    # ── Báo cáo ──────────────────────────────────────────────────────────────
    def dem(m):
        return db.query(m).count()

    print("Đã dựng:")
    print(f"  bài viết        {dem(models.SocialPost)}")
    print(f"  lượt thích      {dem(models.SocialPostLike)}")
    print(f"  bình luận       {dem(models.SocialComment)}")
    print(f"  tin nhu cầu     {dem(DemandPost)}")
    print(f"  tin đã lưu      {dem(models.Wishlist)}")
    print(f"  lịch hẹn        {dem(models.ViewingAppointment)}")
    print(f"  hợp đồng        {dem(models.Contract)}")
    print(f"  khách thuê      {dem(models.Tenant)}")
    print(f"  chỉ số điện nước{dem(models.MeterReading):>3}")
    print(f"  hoá đơn         {dem(models.Invoice)}")
    print(f"  thanh toán      {dem(models.Payment)}")
    print(f"  tổng tài khoản  {dem(models.User)}")


def main() -> None:
    from app.database import SessionLocal

    with SessionLocal() as db:
        run(db)


if __name__ == "__main__":
    main()
