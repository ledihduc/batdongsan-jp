"""Danh mục tiện ích của phòng — HAI danh sách, cố ý không gộp.

    dich_vu_gom      phí dịch vụ hàng tháng BAO GỒM gì
    do_trong_phong   phòng có sẵn ĐỒ gì, không tính tiền

Gộp làm một thì không trả lời được câu "trả tiền dịch vụ để lấy cái gì" — máy
giặt chung ở tầng trệt (nằm trong phí dịch vụ) khác hẳn máy giặt riêng trong
phòng (đồ của phòng), mà tên gọi thì y hệt nhau.

Lưu KEY chứ không lưu nhãn: nhãn tiếng Việt sẽ còn sửa, dữ liệu cũ không được
hỏng theo. Nhãn hiển thị nằm ở app (`lib/data/services/tien_ich_phong.dart`) —
cùng bộ key.
"""

from __future__ import annotations

from typing import Any, Iterable

#: Phí dịch vụ hàng tháng bao gồm những gì.
DICH_VU_GOM: dict[str, str] = {
    "gui_xe": "Gửi xe",
    "rac": "Rác",
    "internet": "Internet / wifi",
    "thang_may": "Thang máy",
    "ve_sinh": "Vệ sinh chung",
    "bao_ve": "Bảo vệ / an ninh",
    "nuoc_nong": "Nước nóng trung tâm",
}

#: Đồ có sẵn trong phòng, không tính tiền riêng.
DO_TRONG_PHONG: dict[str, str] = {
    "giuong": "Giường",
    "tu_quan_ao": "Tủ quần áo",
    "ban_ghe": "Bàn ghế",
    "dieu_hoa": "Điều hoà",
    "nong_lanh": "Bình nóng lạnh",
    "may_giat": "Máy giặt",
    "tu_lanh": "Tủ lạnh",
    "bep": "Bếp",
    "gac_xep": "Gác xép",
    "ban_cong": "Ban công",
    "wc_rieng": "Vệ sinh khép kín",
}


def _loc(gia_tri: Any, hop_le: dict[str, str]) -> list[str]:
    """Giữ lại key hợp lệ, bỏ trùng, GIỮ NGUYÊN thứ tự người dùng chọn.

    Key lạ bị **bỏ qua chứ không 400**: danh mục này còn dài ra, và app bản cũ
    nằm trong cache trình duyệt người dùng không được gãy chỉ vì gửi lên một key
    mà máy chủ chưa biết. Ngược lại cũng đúng — app mới gửi key cũ vẫn chạy.
    """
    if not isinstance(gia_tri, Iterable) or isinstance(gia_tri, (str, bytes)):
        return []
    ra: list[str] = []
    for k in gia_tri:
        if isinstance(k, str) and k in hop_le and k not in ra:
            ra.append(k)
    return ra


def loc_dich_vu(gia_tri: Any) -> list[str]:
    return _loc(gia_tri, DICH_VU_GOM)


def loc_do_dac(gia_tri: Any) -> list[str]:
    return _loc(gia_tri, DO_TRONG_PHONG)


def ten_dich_vu(keys: Iterable[str]) -> list[str]:
    """Key → nhãn tiếng Việt. Dùng cho mô tả dòng hoá đơn."""
    return [DICH_VU_GOM[k] for k in keys if k in DICH_VU_GOM]
