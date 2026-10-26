"""Lịch chiếm dụng phòng — đọc/ghi `room_chiem_dung` (R4 · D1).

Mọi kênh bán đi qua đây, nên "phòng có trống khoảng này không" chỉ còn MỘT câu
trả lời. Trước đây kênh đêm hỏi `reservations`, kênh tháng hỏi cờ
`rooms.status`, và hai bên không biết nhau — hợp đồng dài hạn không chặn nổi
một đơn đặt đêm rơi vào giữa kỳ.

Hai lớp bảo vệ, cố ý trùng nhau:

  1. Truy vấn chồng lấn ở đây — cho câu lỗi ĐỌC ĐƯỢC ("phòng đã có người giữ
     15/10–20/10") và cho SQLite trong test, nơi không có gist.
  2. `EXCLUDE USING gist` ở DB — chặn được cả đua nhau (hai request cùng lúc
     đều thấy trống rồi cùng ghi). Lớp 1 một mình không chặn được điều đó.
"""

from __future__ import annotations

from datetime import date, datetime, time
from typing import Iterable, Optional

from sqlalchemy import and_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import models


class TrungLich(Exception):
    """Khoảng ngày đụng một khoảng đã có. Router dịch thành HTTP 409."""

    def __init__(self, message: str = "Phòng đã có lịch trong khoảng ngày này"):
        super().__init__(message)
        self.message = message


def _chong_lan(room_id: int, tu: date, den: date):
    """Điều kiện SQL "đụng nhau" của hai nửa khoảng [tu, den).

    Hai khoảng chồng nhau khi và chỉ khi mỗi cái bắt đầu trước khi cái kia kết
    thúc. Viết thẳng như vậy thay vì liệt kê bốn tư thế chồng lấn — liệt kê thì
    lần nào cũng sót đúng một tư thế.
    """
    return and_(
        models.RoomChiemDung.room_id == room_id,
        models.RoomChiemDung.tu_ngay < den,
        models.RoomChiemDung.den_ngay > tu,
    )


def dang_ban(
    db: Session, room_id: int, tu: date, den: date, bo_qua_id: Optional[int] = None
) -> Optional[models.RoomChiemDung]:
    """Khoảng đang chắn, hoặc None nếu trống. `bo_qua_id` để tự sửa dòng của mình."""
    q = db.query(models.RoomChiemDung).filter(_chong_lan(room_id, tu, den))
    if bo_qua_id is not None:
        q = q.filter(models.RoomChiemDung.id != bo_qua_id)
    return q.first()


def ghi(
    db: Session,
    *,
    room_id: int,
    tu_ngay: date,
    den_ngay: date,
    kenh: str = "dai_han",
    nguon: str = models.RoomChiemDung.THU_CONG,
    nguon_id: Optional[int] = None,
    ghi_chu: Optional[str] = None,
    tu_luc: Optional[datetime] = None,
    den_luc: Optional[datetime] = None,
) -> models.RoomChiemDung:
    """Đặt một khoảng bận. Ném `TrungLich` nếu đụng khoảng khác.

    KHÔNG commit — người gọi quyết định ranh giới giao dịch, vì hầu hết đường
    dẫn tới đây còn ghi thêm đơn/hợp đồng trong cùng một lần lưu.
    """
    if den_ngay <= tu_ngay:
        raise TrungLich("Ngày trả phải sau ngày nhận")

    # Ghi lại cho cùng một nguồn = cập nhật, không phải thêm dòng thứ hai.
    cu = (
        db.query(models.RoomChiemDung)
        .filter(
            models.RoomChiemDung.nguon == nguon,
            models.RoomChiemDung.nguon_id == nguon_id,
        )
        .first()
        if nguon_id is not None
        else None
    )

    if (tu_luc is None) != (den_luc is None) or (tu_luc and den_luc <= tu_luc):
        raise TrungLich("Giờ trả phải sau giờ nhận")
    vuong = dang_ban(db, room_id, tu_ngay, den_ngay, bo_qua_id=cu.id if cu else None)
    if tu_luc is not None:
        vuong = next((r for r in lich(db, room_id, tu_ngay, den_ngay)
                      if (cu is None or r.id != cu.id)
                      and (r.tu_luc or datetime.combine(r.tu_ngay, time())) < den_luc
                      and tu_luc < (r.den_luc or datetime.combine(r.den_ngay, time()))), None)
    if vuong is not None:
        raise TrungLich(
            f"Phòng đã có lịch {vuong.tu_ngay:%d/%m} – {vuong.den_ngay:%d/%m}"
        )

    if cu is not None:
        cu.room_id, cu.tu_ngay, cu.den_ngay = room_id, tu_ngay, den_ngay
        cu.kenh, cu.ghi_chu = kenh, ghi_chu
        muc = cu
    else:
        muc = models.RoomChiemDung(
            room_id=room_id,
            tu_ngay=tu_ngay,
            den_ngay=den_ngay,
            kenh=kenh,
            nguon=nguon,
            nguon_id=nguon_id,
            ghi_chu=ghi_chu,
        )
        db.add(muc)

    muc.tu_luc, muc.den_luc = tu_luc, den_luc
    try:
        db.flush()
    except IntegrityError as e:
        # Lớp 2: hai request cùng thấy trống rồi cùng ghi. Chỉ DB bắt được.
        db.rollback()
        raise TrungLich() from e
    return muc


def go(db: Session, nguon: str, nguon_id: int) -> int:
    """Trả phòng: gỡ khoảng do một nguồn cụ thể đặt. Trả số dòng đã gỡ.

    Gỡ theo NGUỒN chứ không theo ngày — gỡ theo ngày thì một đơn bị huỷ sẽ xoá
    trúng khoảng của hợp đồng nằm sát cạnh.
    """
    n = (
        db.query(models.RoomChiemDung)
        .filter(
            models.RoomChiemDung.nguon == nguon,
            models.RoomChiemDung.nguon_id == nguon_id,
        )
        .delete(synchronize_session=False)
    )
    return int(n or 0)


def lich(
    db: Session, room_id: int, tu: date, den: date
) -> list[models.RoomChiemDung]:
    """Các khoảng bận của một phòng, giao với [tu, den). Dùng cho màn lịch."""
    return (
        db.query(models.RoomChiemDung)
        .filter(_chong_lan(room_id, tu, den))
        .order_by(models.RoomChiemDung.tu_ngay)
        .all()
    )


def phong_ban(
    db: Session, room_ids: Iterable[int], tu: date, den: date
) -> set[int]:
    """Trong các phòng này, phòng nào BẬN ở khoảng [tu, den)?

    Một truy vấn cho cả danh sách — màn dự án hiện 20 phòng cùng lúc.
    """
    ids = [int(i) for i in room_ids]
    if not ids:
        return set()
    rows = (
        db.query(models.RoomChiemDung.room_id)
        .filter(
            models.RoomChiemDung.room_id.in_(ids),
            models.RoomChiemDung.tu_ngay < den,
            models.RoomChiemDung.den_ngay > tu,
        )
        .distinct()
        .all()
    )
    return {r[0] for r in rows}
