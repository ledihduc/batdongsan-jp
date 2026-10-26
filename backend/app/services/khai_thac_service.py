"""Chốt một KÊNH khai thác — và đóng những tin không còn bán được nữa.

## Vấn đề đang chạy

Một phòng được nhiều sale cùng rao (`rooms.managed_by_sale_id` theo từng phòng,
tin thì mỗi sale một cái). Một người bán được → **hai người kia vẫn đang rao**.
Khách gọi vào tin đã chết, sale dẫn khách tới nơi mới biết.

Cột `houses.ket_thuc_luc` / `ly_do_ket_thuc` có từ mig 0092. Chúng chưa bao giờ
được ghi — cơ chế dựng xong rồi để đó, không ai bấm.

## Luật đóng tin

    kênh `ban` chốt      → đóng MỌI tin đang rao của phòng, MỌI kênh
    kênh thuê chốt       → chỉ đóng tin của CHÍNH kênh đó

Bán rồi thì không cho thuê được nữa — nên `ban` quét sạch. Ngược lại thì không:
phòng cho thuê xong vẫn có thể đang rao bán (bán kèm khách thuê), nên chốt kênh
thuê KHÔNG được đụng tin bán.

## Ai bị đóng tin thì phải được BÁO

Không báo thì họ chỉ phát hiện lúc dẫn khách tới nơi. Đây là lý do hàm này gửi
thông báo cho từng người đăng, không phải chỉ đổi `status` trong DB.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app import helpers, models
from app.services.notification import hang_doi_push

#: Kênh nào chốt thì đóng tin của kênh nào. `ban` quét sạch (None = mọi kênh).
_PHAM_VI_DONG: dict[str, Optional[tuple[str, ...]]] = {
    models.RoomKenh.BAN: None,
    models.RoomKenh.DAI_HAN: (models.RoomKenh.DAI_HAN,),
    models.RoomKenh.MAT_BANG: (models.RoomKenh.MAT_BANG,),
    models.RoomKenh.NGAN_HAN: (models.RoomKenh.NGAN_HAN,),
}

def kenh_cua_tin(house: models.House) -> str:
    """Pipeline của một TIN. Đọc cột, KHÔNG đoán.

    `transaction_type='sale'` vẫn thắng mọi thứ: đó là trục giao dịch, và một
    tin bán thì không thể thuộc pipeline thuê dù cột `kenh` ghi gì.

    Bản cũ đoán bằng cách khớp chuỗi con trên `product_type` ('homestay',
    'short'). Hai hậu quả: đổi tên danh mục là đổi nghiệp vụ một cách âm thầm,
    và **mặt bằng rơi hết vào `dai_han`** — nên chốt một mặt bằng sẽ đóng nhầm
    tin căn hộ cho thuê của cùng phòng.
    """
    if (getattr(house, "transaction_type", "") or "") == "sale":
        return models.RoomKenh.BAN
    kenh = getattr(house, "kenh", None)
    if kenh in models.RoomKenh.KENH and kenh != models.RoomKenh.BAN:
        return kenh
    return models.RoomKenh.DAI_HAN


def _ly_do(trang_thai: str) -> str:
    return "da_ban" if trang_thai == models.RoomKenh.DA_BAN else "da_cho_thue"


def chot_kenh(
    db: Session,
    *,
    room: models.Room,
    kenh: str,
    trang_thai: str,
    nguoi_chot: Optional[int] = None,
) -> int:
    """Chốt một kênh của phòng. Trả số TIN đã bị đóng theo.

    KHÔNG commit — người gọi quyết định ranh giới giao dịch, vì đường dẫn tới
    đây thường còn ghi thêm `Deal` hoặc `Contract` trong cùng một lần lưu.
    """
    if trang_thai not in models.RoomKenh.KET_THUC:
        # Trạng thái giữa chừng (giữ chỗ, đã cọc) KHÔNG đóng tin: thương vụ có
        # thể đổ, và lúc đó tin phải còn đó để bán tiếp.
        _dat_trang_thai(db, room.id, kenh, trang_thai, nguoi_chot, chot=False)
        return 0

    _dat_trang_thai(db, room.id, kenh, trang_thai, nguoi_chot, chot=True)

    # Bán xong thì mọi kênh khác của phòng cũng hết hiệu lực.
    if kenh == models.RoomKenh.BAN:
        (
            db.query(models.RoomKenh)
            .filter(
                models.RoomKenh.room_id == room.id,
                models.RoomKenh.kenh != models.RoomKenh.BAN,
            )
            .update({"dang_bat": False}, synchronize_session=False)
        )

    return _dong_tin(db, room, kenh, _ly_do(trang_thai))


def _dat_trang_thai(
    db: Session,
    room_id: int,
    kenh: str,
    trang_thai: str,
    nguoi_chot: Optional[int],
    *,
    chot: bool,
) -> None:
    dong = (
        db.query(models.RoomKenh)
        .filter(models.RoomKenh.room_id == room_id, models.RoomKenh.kenh == kenh)
        .first()
    )
    if dong is None:
        return
    dong.trang_thai = trang_thai
    if chot:
        dong.chot_luc = datetime.utcnow()
        dong.chot_boi = nguoi_chot


def _dong_tin(
    db: Session, room: models.Room, kenh: str, ly_do: str
) -> int:
    """Đóng các tin ĐANG RAO của phòng nằm trong phạm vi của kênh vừa chốt."""
    tins = (
        db.query(models.House)
        .filter(
            models.House.source_room_id == room.id,
            models.House.status == "published",
        )
        .all()
    )
    pham_vi = _PHAM_VI_DONG.get(kenh, (kenh,))
    now = datetime.utcnow()
    n = 0
    for h in tins:
        if pham_vi is not None and kenh_cua_tin(h) not in pham_vi:
            continue
        h.status = "closed"
        h.ket_thuc_luc = now
        h.ly_do_ket_thuc = ly_do
        n += 1
        _bao_nguoi_dang(db, h, ly_do, room)
    return n


def _bao_nguoi_dang(
    db: Session, house: models.House, ly_do: str, room: models.Room
) -> None:
    """Báo cho người ĐĂNG tin đó — có thể là sale khác, không phải người vừa chốt."""
    if not house.host_id:
        return
    viec = "đã bán" if ly_do == "da_ban" else "đã cho thuê"
    tieu_de = f"Tin của bạn đã đóng — phòng {viec}"
    than = (
        f'Phòng {room.code} {viec}, nên tin "{house.title}" đã ngừng hiển thị. '
        f"Bạn không cần gỡ tay."
    )
    # Trong app: MỘT dòng cho MỖI tin — người ta cần biết tin nào chết.
    helpers.push_notification(
        db, house.host_id, "tin_da_dong", tieu_de, than, house.id
    )
    # Ngoài app: MỘT push cho mỗi người mỗi phòng. Ba tin cùng đóng mà rung ba
    # lần thì lần thứ ba người ta tắt thông báo của cả ứng dụng.
    #
    # Xếp hàng, không gửi ngay: FCM lỗi không được kéo đổ việc chốt bán. Xem
    # `services/notification/hang_doi_push.py`.
    hang_doi_push.xep_hang(
        db,
        user_id=house.host_id,
        title=tieu_de,
        body=f"Phòng {room.code} {viec}. Tin của bạn đã ngừng hiển thị.",
        loai="tin_da_dong",
        khoa_gom=f"tin_da_dong:phong-{room.id}",
        related_id=house.id,
    )


def mo_lai_kenh(db: Session, *, room_id: int, kenh: str) -> None:
    """Rao lại một kênh đã chốt — hết hạn thuê, hoặc thương vụ đổ.

    Chỉ mở lại KÊNH. Tin cũ đã đóng thì để yên: nó là quảng cáo của lượt trước,
    có giá và mô tả của lượt trước. Rao lại là đăng tin MỚI — đúng mô hình
    một-phòng-nhiều-tin của mig 0092.
    """
    dong = (
        db.query(models.RoomKenh)
        .filter(models.RoomKenh.room_id == room_id, models.RoomKenh.kenh == kenh)
        .first()
    )
    if dong is None:
        return
    dong.trang_thai = models.RoomKenh.DANG_RAO
    dong.dang_bat = True
    dong.chot_luc = None
    dong.chot_boi = None
