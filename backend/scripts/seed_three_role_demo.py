"""Seed ba tài khoản demo và dữ liệu phòng tối thiểu cho Chủ nhà.

Phạm vi cố ý hẹp:
  * Khách, Sale, Chủ nhà với đúng email/mật khẩu được yêu cầu;
  * một tòa của Chủ nhà, các hạng phòng và phòng đa kênh;
  * KHÔNG booking, lịch xem, khách thuê, hợp đồng, cọc hay hóa đơn.

Idempotent: chạy lại cập nhật đúng bộ dữ liệu mang MARKER, không nhân đôi.
Dry-run: ``python scripts/seed_three_role_demo.py --dry-run``.
"""

from __future__ import annotations

import argparse
from datetime import datetime

from sqlalchemy import func

from app import models
from app.auth import hash_password
from app.database import SessionLocal

PASSWORD = "7yhn8ujm"
MARKER = "[SEED-THREE-ROLE-DEMO]"
BUILDING_NAME = "Vua Nhà Demo Residence"

ACCOUNTS = (
    {
        "email": "khach@hotmail.com",
        "name": "Khách Demo",
        "role": "guest",
        "account_type": "customer",
        "bio": "Tài khoản Khách dùng kiểm thử hành trình tìm và thuê phòng.",
    },
    {
        "email": "sale@hotmail.com",
        "name": "Sale Demo",
        "role": "guest",
        "account_type": "sale",
        "bio": "Chuyên viên Sale demo của Vua Nhà.",
    },
    {
        "email": "chunha@hotmail.com",
        "name": "Chủ Nhà Demo",
        "role": "host",
        "account_type": "owner",
        "bio": "Chủ nhà demo quản lý phòng dài hạn, ngắn hạn và mặt bằng.",
    },
)

IMAGES = {
    "studio": [
        "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=80"
    ],
    "one_bed": [
        "https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=1200&q=80"
    ],
    "family": [
        "https://images.unsplash.com/photo-1566665797739-1674de7a421a?auto=format&fit=crop&w=1200&q=80"
    ],
    "commercial": [
        "https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1200&q=80"
    ],
}

ROOM_TYPES = (
    {
        "ten": "Studio tiêu chuẩn",
        "mo_ta": "Studio riêng tư, phù hợp 1–2 khách.",
        "suc_chua": 2,
        "dien_tich": 28,
        "giuong": "1 giường Queen",
        "anh": IMAGES["studio"],
        "tien_nghi": ["Wifi", "Điều hòa", "Nóng lạnh", "WC riêng"],
        "gia_theo_gio": 120_000,
        "gia_qua_dem": 650_000,
        "gia_theo_ngay": 780_000,
        "thu_tu": 1,
    },
    {
        "ten": "Căn hộ 1 phòng ngủ",
        "mo_ta": "Phòng khách và phòng ngủ tách biệt, có bếp.",
        "suc_chua": 3,
        "dien_tich": 38,
        "giuong": "1 giường King",
        "anh": IMAGES["one_bed"],
        "tien_nghi": ["Wifi", "Điều hòa", "Bếp", "Máy giặt", "WC riêng"],
        "gia_theo_gio": 160_000,
        "gia_qua_dem": 850_000,
        "gia_theo_ngay": 1_050_000,
        "thu_tu": 2,
    },
    {
        "ten": "Căn hộ gia đình 2 phòng ngủ",
        "mo_ta": "Không gian rộng cho gia đình hoặc nhóm nhỏ.",
        "suc_chua": 5,
        "dien_tich": 58,
        "giuong": "1 giường King + 1 giường Queen",
        "anh": IMAGES["family"],
        "tien_nghi": ["Wifi", "Điều hòa", "Bếp", "Máy giặt", "Ban công"],
        "gia_theo_gio": 220_000,
        "gia_qua_dem": 1_250_000,
        "gia_theo_ngay": 1_500_000,
        "thu_tu": 3,
    },
)

# code, hạng ngắn hạn (hoặc None), diện tích, sức chứa, giá nền, tầng, hướng,
# ảnh, [(kênh, giá, đơn vị, tối thiểu, cọc, miễn phí sửa)]
ROOMS = (
    ("DH-101", None, 28, 2, 5_000_000, "1", "east", "studio", [("dai_han", 5_000_000, "thang", 6, 1, None)]),
    ("DH-102", None, 38, 3, 6_500_000, "1", "south", "one_bed", [("dai_han", 6_500_000, "thang", 12, 2, None)]),
    ("DH-201", None, 58, 5, 9_500_000, "2", "southeast", "family", [("dai_han", 9_500_000, "thang", 12, 2, None)]),
    ("NH-301", "Studio tiêu chuẩn", 28, 2, 650_000, "3", "east", "studio", [("ngan_han", 650_000, "dem", 1, 0.3, None)]),
    ("NH-302", "Căn hộ 1 phòng ngủ", 38, 3, 850_000, "3", "south", "one_bed", [("ngan_han", 850_000, "dem", 1, 0.3, None)]),
    ("NH-401", "Căn hộ gia đình 2 phòng ngủ", 58, 5, 1_250_000, "4", "southeast", "family", [("ngan_han", 1_250_000, "dem", 1, 0.3, None)]),
    ("MB-01", None, 70, 8, 22_000_000, "Trệt", "south", "commercial", [("mat_bang", 22_000_000, "thang", 24, 3, 1)]),
    ("MB-02", None, 95, 12, 32_000_000, "Trệt", "east", "commercial", [("mat_bang", 32_000_000, "thang", 24, 3, 2)]),
)


def _user(db, spec: dict) -> models.User:
    user = (
        db.query(models.User)
        .filter(func.lower(models.User.email) == spec["email"])
        .first()
    )
    if user is None:
        user = models.User(
            name=spec["name"],
            email=spec["email"],
            phone="",
            password_hash=hash_password(PASSWORD),
            role=spec["role"],
            account_type=spec["account_type"],
            bio=spec["bio"],
            is_active=True,
            password_changed_at=datetime.utcnow(),
        )
        db.add(user)
        db.flush()
    user.name = spec["name"]
    user.password_hash = hash_password(PASSWORD)
    user.role = spec["role"]
    user.account_type = spec["account_type"]
    user.bio = spec["bio"]
    user.is_active = True
    user.password_changed_at = datetime.utcnow()
    return user


def _profile(db, user: models.User) -> None:
    profile = (
        db.query(models.HostProfile)
        .filter(models.HostProfile.user_id == user.id)
        .first()
    )
    if profile is None:
        db.add(models.HostProfile(user_id=user.id, verified=False))


def _sale_profile(db, user: models.User) -> None:
    profile = (
        db.query(models.SaleProfile)
        .filter(models.SaleProfile.user_id == user.id)
        .first()
    )
    if profile is None:
        code = f"SL-DEMO-{user.id}"
        profile = models.SaleProfile(
            user_id=user.id,
            sale_code=code,
            display_name=user.name,
            bio=user.bio,
            service_areas=["Ba Đình", "Cầu Giấy", "Thanh Xuân"],
        )
        db.add(profile)
    else:
        profile.display_name = user.name
        profile.bio = user.bio


def _room_type(db, building_id: int, spec: dict) -> models.LoaiPhong:
    row = (
        db.query(models.LoaiPhong)
        .filter(
            models.LoaiPhong.building_id == building_id,
            models.LoaiPhong.ten == spec["ten"],
        )
        .first()
    )
    if row is None:
        row = models.LoaiPhong(building_id=building_id, ten=spec["ten"])
        db.add(row)
        db.flush()
    for key, value in spec.items():
        setattr(row, key, value)
    row.dang_ban = True
    return row


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    db = SessionLocal()
    try:
        users = {spec["account_type"]: _user(db, spec) for spec in ACCOUNTS}
        _profile(db, users["sale"])
        _sale_profile(db, users["sale"])
        _profile(db, users["owner"])
        db.flush()

        owner = users["owner"]
        building = (
            db.query(models.Building)
            .filter(models.Building.name == BUILDING_NAME)
            .first()
        )
        if building is not None and building.host_id != owner.id:
            raise RuntimeError(f"Tên tòa '{BUILDING_NAME}' đã thuộc tài khoản khác")
        if building is None:
            building = models.Building(host_id=owner.id, name=BUILDING_NAME)
            db.add(building)
            db.flush()
        building.address = "25 Hoàng Văn Thụ"
        building.city = "Hà Nội"
        building.district = "Ba Đình"
        building.ward = "Quán Thánh"
        building.note = f"{MARKER} Dữ liệu phòng demo, không có giao dịch."
        building.gia_dien = 3_500
        building.gia_nuoc = 25_000
        building.phi_dich_vu = 200_000
        building.is_public = True

        types = {
            spec["ten"]: _room_type(db, building.id, spec) for spec in ROOM_TYPES
        }
        db.flush()

        room_count = 0
        channel_count = 0
        for code, type_name, area, capacity, price, floor, direction, image_key, channels in ROOMS:
            room = (
                db.query(models.Room)
                .filter(
                    models.Room.building_id == building.id,
                    models.Room.code == code,
                )
                .first()
            )
            if room is None:
                room = models.Room(building_id=building.id, code=code)
                db.add(room)
                db.flush()
            room.area_m2 = area
            room.capacity = capacity
            room.base_price = price
            room.status = "vacant"
            room.images = IMAGES[image_key]
            room.note = f"{MARKER} Phòng mẫu {code}"
            room.owner_id = owner.id
            room.managed_by_sale_id = None
            room.is_homestay = any(c[0] == "ngan_han" for c in channels)
            room.loai_phong_id = types[type_name].id if type_name else None
            room.tang = floor
            room.huong = direction
            room.dich_vu_gom = ["wifi", "rac", "ve_sinh_chung"]
            room.do_trong_phong = ["giuong", "tu_quan_ao", "dieu_hoa", "nong_lanh"]
            room_count += 1

            for channel, value, unit, minimum, deposit, free_months in channels:
                row = (
                    db.query(models.RoomKenh)
                    .filter(
                        models.RoomKenh.room_id == room.id,
                        models.RoomKenh.kenh == channel,
                    )
                    .first()
                )
                if row is None:
                    row = models.RoomKenh(room_id=room.id, kenh=channel)
                    db.add(row)
                row.gia = value
                row.don_vi = unit
                row.toi_thieu = minimum
                row.dat_coc = deposit
                row.mien_phi_thang = free_months
                row.loai_phong = type_name
                if type_name:
                    room_type = types[type_name]
                    row.gia_theo_gio = room_type.gia_theo_gio
                    row.gia_qua_dem = room_type.gia_qua_dem
                    row.gia_theo_ngay = room_type.gia_theo_ngay
                row.dang_bat = True
                row.trang_thai = models.RoomKenh.DANG_RAO
                channel_count += 1

        if args.dry_run:
            db.rollback()
            action = "DRY-RUN — đã rollback"
        else:
            db.commit()
            action = "ĐÃ GHI"

        print(action)
        for spec in ACCOUNTS:
            user = users[spec["account_type"]]
            print(
                f"ACCOUNT id={user.id} email={user.email} "
                f"role={user.role} account_type={user.account_type}"
            )
        print(
            f"BUILDING id={building.id} name={building.name!r} "
            f"room_types={len(types)} rooms={room_count} channels={channel_count}"
        )
        print("TRANSACTIONS bookings=0 contracts=0 invoices=0")
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
