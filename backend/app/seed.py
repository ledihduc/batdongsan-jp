"""Seed dev data — phong phú đủ test mọi màn hình Flutter.

Idempotent: chỉ seed khi DB rỗng (kiểm tra qua bảng users).
"""

from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app import auth, models


# ── Cấu hình ID cố định để liên kết giữa entity dễ kiểm tra ───────────────────
ADMIN_ID = 1
HOST_PRIMARY_ID = 2     # host@housebooking.com
GUEST_PRIMARY_ID = 3    # guest@housebooking.com
HOST_2_ID = 4           # Trần Hoài Phương
HOST_3_ID = 5           # Phạm Anh Tuấn
GUEST_2_ID = 6
GUEST_3_ID = 7
GUEST_4_ID = 8


def run(db: Session) -> None:
    if db.query(models.User).first():
        return

    print("[seed] Đang seed dữ liệu mock phong phú...")
    _seed_users(db)
    _seed_catalog(db)
    _seed_houses(db)
    _seed_host_profiles(db)
    _seed_reviews(db)
    _seed_wishlists(db)
    _seed_viewing_appointments(db)
    _seed_notifications(db)
    _seed_chat(db)
    _seed_buildings_rooms(db)
    _seed_tenants_contracts(db)
    _sync_sequences(db)
    print("[seed] Hoàn tất.")


def _sync_sequences(db: Session) -> None:
    """Sau khi seed bằng id tường minh, đẩy các sequence id lên max(id) để INSERT
    tiếp theo (đăng tin/đăng ký...) không đụng khoá chính. Chỉ chạy trên Postgres.
    (SQLite dùng rowid tự tăng, không có sequence.)"""
    if db.bind is None or db.bind.dialect.name != "postgresql":
        return
    from sqlalchemy import text

    db.execute(text("""
        DO $$
        DECLARE r RECORD; mx BIGINT; cur BIGINT;
        BEGIN
          FOR r IN
            SELECT s.relname AS seq, t.relname AS tbl
            FROM pg_class s
            JOIN pg_depend d ON d.objid=s.oid AND d.deptype='a'
            JOIN pg_class t ON t.oid=d.refobjid
            JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=d.refobjsubid
                                AND a.attname='id'
            WHERE s.relkind='S' AND t.relnamespace='public'::regnamespace
          LOOP
            EXECUTE format('SELECT COALESCE(MAX(id),0) FROM public.%I', r.tbl) INTO mx;
            EXECUTE format('SELECT last_value FROM public.%I', r.seq) INTO cur;
            IF mx > cur THEN
              PERFORM setval(format('public.%I', r.seq)::regclass, mx, true);
            END IF;
          END LOOP;
        END $$;
    """))
    db.commit()


# ─────────────────────────────────────────────────────────────────────────────
# Users
# ─────────────────────────────────────────────────────────────────────────────
def _seed_users(db: Session) -> None:
    users = [
        models.User(
            id=ADMIN_ID,
            name="Hệ thống Admin",
            email="admin@housebooking.com",
            password_hash=auth.hash_password("admin123"),
            phone="0901234567",
            avatar_path="https://i.pravatar.cc/300?img=1",
            role="admin",
            is_active=True,
        ),
        models.User(
            id=HOST_PRIMARY_ID,
            name="Nguyễn Minh Anh",
            email="host@housebooking.com",
            password_hash=auth.hash_password("host123"),
            phone="0988888888",
            avatar_path="https://i.pravatar.cc/300?img=12",
            role="host",
            is_active=True,
            bio="Chủ nhà tận tâm, phản hồi nhanh trong 1 giờ.",
        ),
        models.User(
            id=GUEST_PRIMARY_ID,
            name="Lê Văn Nam",
            email="guest@housebooking.com",
            password_hash=auth.hash_password("guest123"),
            phone="0977777777",
            avatar_path="https://i.pravatar.cc/300?img=20",
            role="guest",
            is_active=True,
        ),
        models.User(
            id=HOST_2_ID,
            name="Trần Hoài Phương",
            email="phuong.host@housebooking.com",
            password_hash=auth.hash_password("host123"),
            phone="0911223344",
            avatar_path="https://i.pravatar.cc/300?img=32",
            role="host",
            is_active=True,
        ),
        models.User(
            id=HOST_3_ID,
            name="Phạm Anh Tuấn",
            email="tuan.host@housebooking.com",
            password_hash=auth.hash_password("host123"),
            phone="0933445566",
            avatar_path="https://i.pravatar.cc/300?img=45",
            role="host",
            is_active=True,
        ),
        models.User(
            id=GUEST_2_ID,
            name="Đỗ Thu Hà",
            email="ha.guest@housebooking.com",
            password_hash=auth.hash_password("guest123"),
            phone="0966554433",
            avatar_path="https://i.pravatar.cc/300?img=47",
            role="guest",
            is_active=True,
        ),
        models.User(
            id=GUEST_3_ID,
            name="Hoàng Đức Mạnh",
            email="manh.guest@housebooking.com",
            password_hash=auth.hash_password("guest123"),
            phone="0944112233",
            avatar_path="https://i.pravatar.cc/300?img=53",
            role="guest",
            is_active=True,
        ),
        models.User(
            id=GUEST_4_ID,
            name="Vũ Khánh Linh",
            email="linh.guest@housebooking.com",
            password_hash=auth.hash_password("guest123"),
            phone="0922334455",
            avatar_path="https://i.pravatar.cc/300?img=49",
            role="guest",
            is_active=True,
        ),
    ]
    db.add_all(users)
    db.commit()


# ─────────────────────────────────────────────────────────────────────────────
# Categories + Amenities
# ─────────────────────────────────────────────────────────────────────────────
def _seed_catalog(db: Session) -> None:
    # 12 loại / 3 NHÓM master (chốt 24/08/2026, xem migration 0074). DB đang
    # chạy được migration đưa về đúng bộ này; seed cho DB mới phải khớp, nếu
    # không môi trường mới lại có danh mục cũ (Penthouse/Studio) đã bỏ.
    db.add_all([
        models.Category(id=1, name="Căn hộ", icon="apartment",
                        group_key="stay_long", sort_order=3),
        models.Category(id=2, name="Nhà nguyên căn", icon="home",
                        group_key="stay_long", sort_order=4),
        models.Category(id=3, name="Villa", icon="villa",
                        group_key="stay_short", sort_order=1),
        models.Category(id=4, name="Hotel", icon="hotel",
                        group_key="stay_short", sort_order=2),
        models.Category(id=5, name="Motel", icon="night_shelter",
                        group_key="stay_short", sort_order=3),
        models.Category(id=6, name="Phòng trọ", icon="bed",
                        group_key="stay_long", sort_order=1),
        models.Category(id=7, name="Kho xưởng", icon="warehouse",
                        group_key="business", sort_order=4),
        models.Category(id=8, name="Chung cư mini", icon="apartment",
                        group_key="stay_long", sort_order=2),
        models.Category(id=9, name="Home stay", icon="holiday_village",
                        group_key="stay_short", sort_order=4),
        models.Category(id=10, name="Mặt bằng cửa hàng", icon="storefront",
                        group_key="business", sort_order=1),
        models.Category(id=11, name="Shop house", icon="store",
                        group_key="business", sort_order=2),
        models.Category(id=12, name="Văn phòng", icon="corporate_fare",
                        group_key="business", sort_order=3),
    ])
    db.add_all([
        models.Amenity(id=1, name="Wifi 5G", icon="wifi"),
        models.Amenity(id=2, name="Hồ bơi", icon="pool"),
        models.Amenity(id=3, name="Phòng Gym", icon="fitness_center"),
        models.Amenity(id=4, name="Bãi đỗ xe", icon="local_parking"),
        models.Amenity(id=5, name="Điều hoà", icon="ac_unit"),
        models.Amenity(id=6, name="An ninh 24/7", icon="security"),
        models.Amenity(id=7, name="Máy giặt", icon="local_laundry_service"),
        models.Amenity(id=8, name="Bếp đầy đủ", icon="kitchen"),
        models.Amenity(id=9, name="Ban công", icon="balcony"),
        models.Amenity(id=10, name="Thú cưng OK", icon="pets"),
    ])
    db.commit()


# ─────────────────────────────────────────────────────────────────────────────
# Houses (10 căn) — đa dạng thành phố, giá, loại
# ─────────────────────────────────────────────────────────────────────────────
_UNSPLASH = "https://images.unsplash.com/photo-{id}?auto=format&fit=crop&w=1200&q=80"


def _img(*ids: str) -> list:
    return [_UNSPLASH.format(id=x) for x in ids]


def _seed_houses(db: Session) -> None:
    houses = [
        models.House(
            id=1,
            host_id=HOST_PRIMARY_ID,
            title="Skyline Serenity Penthouse",
            description="Penthouse cao cấp tại trung tâm Quận 1, view sông Sài Gòn, nội thất nhập khẩu.",
            category_id=4, price=25_000_000, area=120,
            address="15 Lê Thánh Tôn", city="TP. Hồ Chí Minh", district="Quận 1",
            latitude=10.7797, longitude=106.7042,
            bedrooms=3, bathrooms=2, status="approved",
            images=_img("1502672260266-1c1ef2d93688", "1560448204-e02f11c3d0e2"),
            amenities=["Wifi 5G", "Hồ bơi", "Phòng Gym", "Bãi đỗ xe", "Điều hoà", "An ninh 24/7"],
            listing_type="single", total_units=1, available_units=1, gender_pref="any",
        ),
        models.House(
            id=2,
            host_id=HOST_PRIMARY_ID,
            title="Urban Loft Studio",
            description="Studio nhỏ gọn, thiết kế tối giản, gần Lăng Bác, phù hợp cho người trẻ.",
            category_id=5, price=12_000_000, area=45,
            address="62 Đội Cấn", city="Hà Nội", district="Ba Đình",
            latitude=21.033, longitude=105.814,
            bedrooms=1, bathrooms=1, status="approved",
            images=_img("1494526585095-c41746248156", "1522708323590-d24dbb6b0267"),
            amenities=["Wifi 5G", "Điều hoà", "Bếp đầy đủ"],
            listing_type="single", total_units=1, available_units=1, gender_pref="any",
        ),
        models.House(
            id=3,
            host_id=HOST_2_ID,
            title="Sunny Garden Villa",
            description="Biệt thự sân vườn 200m², hồ bơi riêng, gần biển Mỹ Khê.",
            category_id=3, price=45_000_000, area=200,
            address="22 Võ Nguyên Giáp", city="Đà Nẵng", district="Sơn Trà",
            latitude=16.084, longitude=108.247,
            bedrooms=4, bathrooms=3, status="approved",
            images=_img("1613490493576-7fde63acd811", "1600585154340-be6161a56a0c"),
            amenities=["Wifi 5G", "Hồ bơi", "Bãi đỗ xe", "Điều hoà", "An ninh 24/7", "Thú cưng OK"],
            listing_type="single", total_units=1, available_units=1, gender_pref="any",
        ),
        models.House(
            id=4,
            host_id=HOST_2_ID,
            title="Riverside 2BR Apartment",
            description="Căn hộ 2 phòng ngủ view sông Hàn, đầy đủ nội thất, gần Cầu Rồng.",
            category_id=1, price=15_000_000, area=78,
            address="45 Trần Hưng Đạo", city="Đà Nẵng", district="Hải Châu",
            latitude=16.0668, longitude=108.224,
            bedrooms=2, bathrooms=2, status="approved",
            images=_img("1493809842364-78817add7ffb", "1568605114967-8130f3a36994"),
            amenities=["Wifi 5G", "Điều hoà", "Bếp đầy đủ", "Ban công", "An ninh 24/7"],
            listing_type="single", total_units=1, available_units=1, gender_pref="any",
        ),
        models.House(
            id=5,
            host_id=HOST_3_ID,
            title="Cozy Town House Q7",
            description="Nhà phố 3 tầng tại Phú Mỹ Hưng, gần trường học quốc tế, an ninh tốt.",
            category_id=2, price=22_000_000, area=110,
            address="78 Nguyễn Văn Linh", city="TP. Hồ Chí Minh", district="Quận 7",
            latitude=10.732, longitude=106.719,
            bedrooms=3, bathrooms=3, status="approved",
            images=_img("1572120360610-d971b9d7767c", "1583608205776-bfd35f0d9f83"),
            amenities=["Wifi 5G", "Bãi đỗ xe", "Điều hoà", "Bếp đầy đủ", "Ban công"],
            listing_type="single", total_units=1, available_units=1, gender_pref="any",
        ),
        models.House(
            id=6,
            host_id=HOST_3_ID,
            title="Phòng trọ cao cấp Thủ Đức",
            description="Phòng trọ mới xây, sạch sẽ, có máy giặt chung, gần ĐH Quốc Gia.",
            category_id=6, price=3_500_000, area=22,
            address="120 Võ Văn Ngân", city="TP. Hồ Chí Minh", district="Thủ Đức",
            latitude=10.851, longitude=106.771,
            bedrooms=1, bathrooms=1, status="approved",
            images=_img("1505691938895-1758d7feb511", "1556228720-195a672e8a03"),
            amenities=["Wifi 5G", "Điều hoà", "Máy giặt", "An ninh 24/7"],
            listing_type="multi", total_units=12, available_units=4, gender_pref="any",
        ),
        models.House(
            id=7,
            host_id=HOST_PRIMARY_ID,
            title="Phòng trọ nữ Cầu Giấy",
            description="Khu trọ nữ, an ninh, có camera, gần ĐH Sư Phạm Hà Nội.",
            category_id=6, price=2_800_000, area=18,
            address="55 Xuân Thuỷ", city="Hà Nội", district="Cầu Giấy",
            latitude=21.037, longitude=105.781,
            bedrooms=1, bathrooms=1, status="approved",
            images=_img("1522708323590-d24dbb6b0267", "1556909114-f6e7ad7d3136"),
            amenities=["Wifi 5G", "Điều hoà", "Máy giặt", "An ninh 24/7"],
            listing_type="multi", total_units=8, available_units=2, gender_pref="female",
        ),
        models.House(
            id=8,
            host_id=HOST_2_ID,
            title="Hai Bà Trưng 1BR Apartment",
            description="Căn 1 phòng ngủ, full nội thất, gần Vincom Bà Triệu.",
            category_id=1, price=10_500_000, area=42,
            address="84 Bà Triệu", city="Hà Nội", district="Hai Bà Trưng",
            latitude=21.013, longitude=105.847,
            bedrooms=1, bathrooms=1, status="approved",
            images=_img("1502672023488-70e25813eb80", "1560448204-603b3fc33ddc"),
            amenities=["Wifi 5G", "Điều hoà", "Bếp đầy đủ", "An ninh 24/7"],
            listing_type="single", total_units=1, available_units=1, gender_pref="any",
        ),
        models.House(
            id=9,
            host_id=HOST_3_ID,
            title="Studio biển Nha Trang",
            description="Studio view biển, ban công lớn, gần chợ Đầm.",
            category_id=5, price=8_500_000, area=38,
            address="10 Trần Phú", city="Khánh Hoà", district="Nha Trang",
            latitude=12.243, longitude=109.197,
            bedrooms=1, bathrooms=1, status="approved",
            images=_img("1551776235-dde6d4829808", "1493809842364-78817add7ffb"),
            amenities=["Wifi 5G", "Điều hoà", "Bếp đầy đủ", "Ban công"],
            listing_type="single", total_units=1, available_units=1, gender_pref="any",
        ),
        models.House(
            id=10,
            host_id=HOST_PRIMARY_ID,
            title="Penthouse The Manor",
            description="Penthouse 2 tầng, sân thượng 50m², phù hợp gia đình hoặc chuyên gia.",
            category_id=4, price=38_000_000, area=180,
            address="91 Nguyễn Hữu Cảnh", city="TP. Hồ Chí Minh", district="Bình Thạnh",
            latitude=10.789, longitude=106.719,
            bedrooms=3, bathrooms=3, status="approved",
            images=_img("1600585154526-990dced4db0d", "1600607687939-ce8a6c25118c"),
            amenities=["Wifi 5G", "Hồ bơi", "Phòng Gym", "Bãi đỗ xe", "Điều hoà", "An ninh 24/7", "Bếp đầy đủ"],
            listing_type="single", total_units=1, available_units=1, gender_pref="any",
        ),
    ]
    db.add_all(houses)
    db.commit()


# ─────────────────────────────────────────────────────────────────────────────
# Host profiles (cho 3 host → marketplace hiển thị trust signals)
# ─────────────────────────────────────────────────────────────────────────────
def _seed_host_profiles(db: Session) -> None:
    db.add_all([
        models.HostProfile(
            user_id=HOST_PRIMARY_ID, verified=True,
            bank_account_number="0123456789", bank_name="Vietcombank",
            bank_account_holder="NGUYEN MINH ANH",
            avg_response_hours=1.2, rating=4.8, payout_schedule="monthly",
        ),
        models.HostProfile(
            user_id=HOST_2_ID, verified=True,
            bank_account_number="9876543210", bank_name="Techcombank",
            bank_account_holder="TRAN HOAI PHUONG",
            avg_response_hours=2.5, rating=4.6, payout_schedule="monthly",
        ),
        models.HostProfile(
            user_id=HOST_3_ID, verified=False,
            avg_response_hours=4.0, rating=4.2, payout_schedule="monthly",
        ),
    ])
    db.commit()


# ─────────────────────────────────────────────────────────────────────────────
# Reviews (cho các căn hot)
# ─────────────────────────────────────────────────────────────────────────────
def _seed_reviews(db: Session) -> None:
    reviews = [
        # House 1 — Skyline Penthouse
        models.Review(user_id=GUEST_PRIMARY_ID, house_id=1, rating=5,
                      comment="View đỉnh, chủ nhà thân thiện, sẽ quay lại."),
        models.Review(user_id=GUEST_2_ID, house_id=1, rating=5,
                      comment="Không gian sang trọng, an ninh tốt."),
        models.Review(user_id=GUEST_3_ID, house_id=1, rating=4,
                      comment="Tốt nhưng thang máy hơi chậm giờ cao điểm."),
        # House 3 — Sunny Villa
        models.Review(user_id=GUEST_2_ID, house_id=3, rating=5,
                      comment="Biệt thự đẹp như mơ, hồ bơi sạch."),
        models.Review(user_id=GUEST_4_ID, house_id=3, rating=4,
                      comment="Vị trí gần biển, di chuyển tiện."),
        # House 4 — Riverside Apt
        models.Review(user_id=GUEST_PRIMARY_ID, house_id=4, rating=5,
                      comment="View sông Hàn lung linh về đêm."),
        models.Review(user_id=GUEST_3_ID, house_id=4, rating=4,
                      comment="Nội thất mới, sạch sẽ."),
        # House 6 — Phòng trọ Thủ Đức
        models.Review(user_id=GUEST_4_ID, house_id=6, rating=4,
                      comment="Phòng nhỏ nhưng đầy đủ tiện nghi, hợp sinh viên."),
        # House 10
        models.Review(user_id=GUEST_2_ID, house_id=10, rating=5,
                      comment="Penthouse rộng rãi, ban công lớn."),
    ]
    db.add_all(reviews)
    db.commit()


# ─────────────────────────────────────────────────────────────────────────────
# Wishlists — guest@ đã save 4 căn
# ─────────────────────────────────────────────────────────────────────────────
def _seed_wishlists(db: Session) -> None:
    db.add_all([
        models.Wishlist(user_id=GUEST_PRIMARY_ID, house_id=1),
        models.Wishlist(user_id=GUEST_PRIMARY_ID, house_id=3),
        models.Wishlist(user_id=GUEST_PRIMARY_ID, house_id=9),
        models.Wishlist(user_id=GUEST_PRIMARY_ID, house_id=10),
        models.Wishlist(user_id=GUEST_2_ID, house_id=4),
        models.Wishlist(user_id=GUEST_2_ID, house_id=10),
    ])
    db.commit()


# ─────────────────────────────────────────────────────────────────────────────
# Viewing appointments — mix các trạng thái cho cả guest & host xem
# ─────────────────────────────────────────────────────────────────────────────
def _seed_viewing_appointments(db: Session) -> None:
    today = datetime.utcnow().date()

    def d(offset: int) -> str:
        return (today + timedelta(days=offset)).isoformat()

    db.add_all([
        # Sắp tới — guest@ xem nhà host@
        models.ViewingAppointment(
            house_id=1, guest_id=GUEST_PRIMARY_ID,
            booking_date=d(2), booking_time="09:00-10:00",
            message="Muốn xem trực tiếp căn penthouse vào sáng cuối tuần.",
            status="pending",
        ),
        models.ViewingAppointment(
            house_id=10, guest_id=GUEST_PRIMARY_ID,
            booking_date=d(5), booking_time="14:00-15:00",
            message="Có thể xem cùng người nhà không?",
            status="confirmed",
        ),
        # Đã xong
        models.ViewingAppointment(
            house_id=4, guest_id=GUEST_PRIMARY_ID,
            booking_date=d(-7), booking_time="10:00-11:00",
            message="", status="completed",
        ),
        # Khách khác xem
        models.ViewingAppointment(
            house_id=3, guest_id=GUEST_2_ID,
            booking_date=d(3), booking_time="15:00-16:00",
            message="Cần biết thêm về điều khoản thuê dài hạn.",
            status="pending",
        ),
        models.ViewingAppointment(
            house_id=2, guest_id=GUEST_3_ID,
            booking_date=d(-2), booking_time="16:00-17:00",
            message="", status="cancelled",
        ),
        models.ViewingAppointment(
            house_id=6, guest_id=GUEST_4_ID,
            booking_date=d(1), booking_time="08:00-09:00",
            message="Phòng còn trống không ạ?", status="pending",
        ),
    ])
    db.commit()


# ─────────────────────────────────────────────────────────────────────────────
# Notifications — cho guest@ và host@
# ─────────────────────────────────────────────────────────────────────────────
def _seed_notifications(db: Session) -> None:
    db.add_all([
        models.Notification(
            user_id=GUEST_PRIMARY_ID, type="booking",
            title="Lịch xem nhà đã được xác nhận",
            body="Penthouse The Manor — 14:00 thứ Bảy.",
            related_id=2, read=False,
        ),
        models.Notification(
            user_id=GUEST_PRIMARY_ID, type="chat",
            title="Tin nhắn mới từ Nguyễn Minh Anh",
            body="Em chào anh, căn còn trống ạ.",
            related_id=HOST_PRIMARY_ID, read=False,
        ),
        models.Notification(
            user_id=GUEST_PRIMARY_ID, type="promo",
            title="Ưu đãi -10% phí đặt cọc",
            body="Áp dụng cho 5 booking đầu tiên trong tháng.",
            related_id=None, read=True,
        ),
        models.Notification(
            user_id=HOST_PRIMARY_ID, type="booking",
            title="Có lịch xem mới",
            body="Lê Văn Nam muốn xem Skyline Serenity Penthouse.",
            related_id=1, read=False,
        ),
        models.Notification(
            user_id=HOST_PRIMARY_ID, type="review",
            title="Đánh giá 5 sao mới",
            body="Khách đã đánh giá 5⭐ cho Skyline Serenity Penthouse.",
            related_id=1, read=True,
        ),
        models.Notification(
            user_id=HOST_PRIMARY_ID, type="system",
            title="Hồ sơ host đã xác minh",
            body="Tài khoản của bạn đã được duyệt KYC.",
            related_id=None, read=True,
        ),
    ])
    db.commit()


# ─────────────────────────────────────────────────────────────────────────────
# Chat — guest@ ↔ host@ về House 1
# ─────────────────────────────────────────────────────────────────────────────
def _seed_chat(db: Session) -> None:
    db.add_all([
        models.ChatMessage(
            sender_id=GUEST_PRIMARY_ID, receiver_id=HOST_PRIMARY_ID,
            house_id=1, body="Chào anh, căn penthouse còn trống không ạ?", read=True,
        ),
        models.ChatMessage(
            sender_id=HOST_PRIMARY_ID, receiver_id=GUEST_PRIMARY_ID,
            house_id=1, body="Chào em, còn nhé. Em qua xem được không?", read=True,
        ),
        models.ChatMessage(
            sender_id=GUEST_PRIMARY_ID, receiver_id=HOST_PRIMARY_ID,
            house_id=1, body="Dạ cuối tuần em qua được không anh?", read=True,
        ),
        models.ChatMessage(
            sender_id=HOST_PRIMARY_ID, receiver_id=GUEST_PRIMARY_ID,
            house_id=1, body="Ok em, sáng thứ Bảy 9h nhé.", read=False,
        ),
        # Conversation thứ 2: guest@ ↔ host_2
        models.ChatMessage(
            sender_id=GUEST_PRIMARY_ID, receiver_id=HOST_2_ID,
            house_id=4, body="Anh ơi căn Riverside còn không ạ?", read=True,
        ),
        models.ChatMessage(
            sender_id=HOST_2_ID, receiver_id=GUEST_PRIMARY_ID,
            house_id=4, body="Còn em nhé, giá 15tr/tháng.", read=False,
        ),
    ])
    db.commit()


# ─────────────────────────────────────────────────────────────────────────────
# Buildings + Rooms — cho host dashboard "Nhà trọ"
# ─────────────────────────────────────────────────────────────────────────────
def _seed_buildings_rooms(db: Session) -> None:
    # 2 building cho host_primary
    db.add_all([
        models.Building(
            id=1, host_id=HOST_PRIMARY_ID,
            name="Nhà trọ Cầu Giấy",
            address="55 Xuân Thuỷ", city="Hà Nội",
            district="Cầu Giấy", ward="Dịch Vọng",
            note="8 phòng nữ, an ninh có camera",
        ),
        models.Building(
            id=2, host_id=HOST_PRIMARY_ID,
            name="Nhà trọ Thủ Đức",
            address="120 Võ Văn Ngân", city="TP. Hồ Chí Minh",
            district="Thủ Đức", ward="Linh Chiểu",
            note="12 phòng, gần ĐH Quốc Gia",
        ),
    ])
    db.commit()

    # Rooms cho building 1 (4 phòng) + building 2 (5 phòng)
    rooms = []
    for i, code in enumerate(["P101", "P102", "P201", "P202"], start=1):
        rooms.append(models.Room(
            id=i, building_id=1, code=code,
            area_m2=18.0, capacity=1, base_price=2_800_000,
            status="occupied" if i <= 2 else "vacant",
            images=_img("1522708323590-d24dbb6b0267"),
        ))
    for i, code in enumerate(["A101", "A102", "A201", "A202", "A301"], start=5):
        rooms.append(models.Room(
            id=i, building_id=2, code=code,
            area_m2=22.0, capacity=2, base_price=3_500_000,
            status="occupied" if i <= 6 else ("maintenance" if i == 9 else "vacant"),
            maintenance_start="2026-06-20" if i == 9 else None,
            maintenance_end="2026-07-05" if i == 9 else None,
            images=_img("1505691938895-1758d7feb511"),
        ))
    db.add_all(rooms)
    db.commit()


# ─────────────────────────────────────────────────────────────────────────────
# Tenants + Contracts
# ─────────────────────────────────────────────────────────────────────────────
def _seed_tenants_contracts(db: Session) -> None:
    db.add_all([
        models.Tenant(
            id=1, host_id=HOST_PRIMARY_ID,
            full_name="Phạm Thị Mai", phone="0911000001",
            email="mai.tenant@example.com", birthday="2001-03-12",
            address_origin="Nam Định",
        ),
        models.Tenant(
            id=2, host_id=HOST_PRIMARY_ID,
            full_name="Trần Văn Khoa", phone="0911000002",
            email="khoa.tenant@example.com", birthday="2000-07-08",
            address_origin="Hải Phòng",
        ),
        models.Tenant(
            id=3, host_id=HOST_PRIMARY_ID,
            full_name="Nguyễn Thị Lan", phone="0911000003",
            email="lan.tenant@example.com", birthday="2002-11-22",
            address_origin="Thanh Hoá",
        ),
        models.Tenant(
            id=4, host_id=HOST_PRIMARY_ID,
            full_name="Đỗ Quang Hưng", phone="0911000004",
            email="hung.tenant@example.com", birthday="1999-05-30",
            address_origin="Hà Nam",
        ),
    ])
    db.commit()

    # Phase 04: dual-write FK source_id. Seed sources cho HOST_PRIMARY_ID
    # (host_id này có thể chưa tồn tại khi 0012 chạy → helper auto-create).
    from app.services import source_service
    _src_manual = source_service.resolve_default_source_id(db, HOST_PRIMARY_ID, "manual")
    db.commit()

    db.add_all([
        # Active contract cho phòng P101 (room id=1), tenant Mai
        models.Contract(
            id=1, host_id=HOST_PRIMARY_ID, room_id=1,
            start_date="2026-04-01", end_date="2027-03-31",
            monthly_rent=2_800_000, deposit=2_800_000, status="active",
            source_id=_src_manual,
        ),
        # Active contract cho phòng P102 (room id=2), tenant Khoa
        models.Contract(
            id=2, host_id=HOST_PRIMARY_ID, room_id=2,
            start_date="2026-05-15", end_date="2027-05-14",
            monthly_rent=2_800_000, deposit=2_800_000, status="active",
            source_id=_src_manual,
        ),
        # Active contract cho phòng A101 (room id=5), tenant Lan + Hưng (ở ghép)
        models.Contract(
            id=3, host_id=HOST_PRIMARY_ID, room_id=5,
            start_date="2026-03-01", end_date="2027-02-28",
            monthly_rent=3_500_000, deposit=3_500_000, status="active",
            source_id=_src_manual,
        ),
        # Draft contract chờ ký
        models.Contract(
            id=4, host_id=HOST_PRIMARY_ID, room_id=6,
            start_date="2026-07-01", end_date="2027-06-30",
            monthly_rent=3_500_000, deposit=3_500_000, status="draft",
            source_id=_src_manual,
        ),
    ])
    db.commit()

    db.add_all([
        models.ContractTenant(contract_id=1, tenant_id=1, is_primary=True, joined_at="2026-04-01"),
        models.ContractTenant(contract_id=2, tenant_id=2, is_primary=True, joined_at="2026-05-15"),
        models.ContractTenant(contract_id=3, tenant_id=3, is_primary=True, joined_at="2026-03-01"),
        models.ContractTenant(contract_id=3, tenant_id=4, is_primary=False, joined_at="2026-03-01"),
    ])
    db.commit()
