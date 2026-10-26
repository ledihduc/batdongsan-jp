"""LUẬT GIỜ TRẢ PHÒNG của lưu trú ngắn hạn (chốt 12/09/2026).

  * Theo giờ: trả phòng **chẵn tiếng**, làm tròn LÊN. Nhận 14:46 đặt 4 giờ thì
    trả 19:00 — phần lẻ là của khách, và lịch phòng không có ô lửng giữa lưới.
  * Qua đêm / theo ngày: trả **12:00 trưa**, như mọi khách sạn.
  * Phần dư do làm tròn KHÔNG tính tiền: 4 giờ đặt vẫn là 4 giờ tiền.

Một chỗ duy nhất quyết định giờ trả (`short_stay_service.gio_tra`) để quầy lễ
tân, app khách và bảng giá không ra ba con số.
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import HTTPException

from app.services import short_stay_service as stays


def _t(chuoi: str) -> datetime:
    """Giờ VN. `validate_stay` đòi có múi giờ (cố ý — giờ không múi là nguồn
    của những ca lệch 7 tiếng), còn `gio_tra` chỉ làm số học nên nhận cả hai."""
    return datetime.fromisoformat(chuoi)


def _vn(chuoi: str) -> str:
    return f"{chuoi}+07:00"


@pytest.mark.parametrize(
    "vao,so_gio,mong_doi",
    [
        ("2030-01-01T14:46", 4, "2030-01-01T19:00"),   # lẻ phút → làm tròn lên
        ("2030-01-01T14:00", 4, "2030-01-01T18:00"),   # đã chẵn → giữ nguyên
        ("2030-01-01T23:10", 2, "2030-01-02T02:00"),   # qua nửa đêm
        ("2030-01-01T14:01", 1, "2030-01-01T16:00"),   # lẻ 1 phút vẫn lên tròn
    ],
)
def test_theo_gio_tra_chan_tieng(vao, so_gio, mong_doi):
    assert stays.gio_tra("theo_gio", _t(vao), so_gio) == _t(mong_doi)


@pytest.mark.parametrize(
    "vao,mong_doi",
    [
        ("2030-01-01T21:00", "2030-01-02T12:00"),  # vào tối → trả trưa mai
        ("2030-01-01T23:30", "2030-01-02T12:00"),
        ("2030-01-02T01:00", "2030-01-02T12:00"),  # vào 1h sáng → trưa CÙNG ngày
    ],
)
def test_qua_dem_luon_tra_12h_trua(vao, mong_doi):
    assert stays.gio_tra("qua_dem", _t(vao), 1) == _t(mong_doi)


@pytest.mark.parametrize(
    "vao,so_ngay,mong_doi",
    [
        ("2030-01-01T14:00", 1, "2030-01-02T12:00"),
        ("2030-01-01T08:00", 1, "2030-01-02T12:00"),  # nhận sớm vẫn đủ một đêm
        ("2030-01-01T14:00", 3, "2030-01-04T12:00"),
    ],
)
def test_theo_ngay_luon_tra_12h_trua(vao, so_ngay, mong_doi):
    assert stays.gio_tra("theo_ngay", _t(vao), so_ngay) == _t(mong_doi)


def test_phan_du_lam_tron_khong_bi_tinh_tien():
    """Đặt 4 giờ lúc 14:46 thì trả 19:00 nhưng vẫn chỉ trả tiền 4 giờ."""
    now = stays.local_time(_vn("2030-01-01T14:00"))
    ci, co, units = stays.validate_stay(
        "theo_gio", _vn("2030-01-01T14:46"), _vn("2030-01-01T18:46"), now
    )
    assert (co.hour, co.minute, units) == (19, 0, 4)

    # Gửi lại chính giờ trả đã chuẩn hoá cũng phải ra đúng 4 giờ, không thành 5:
    # nếu không, bấm "xem lại" một lần là tiền tự tăng.
    assert stays.validate_stay(
        "theo_gio", _vn("2030-01-01T14:46"), stays.iso(co), now
    )[2] == 4


def test_client_cu_gui_boi_24_gio_van_ra_dung_so_dem():
    now = stays.local_time(_vn("2030-01-01T10:00"))
    ci, co, units = stays.validate_stay(
        "theo_ngay", _vn("2030-01-01T14:00"), _vn("2030-01-03T14:00"), now
    )
    assert (co.day, co.hour, units) == (3, 12, 2)


def test_van_chan_khoang_vo_ly():
    now = stays.local_time(_vn("2030-01-01T10:00"))
    vao = _vn("2030-01-01T14:00")
    for mode, den in (
        ("theo_gio", _vn("2030-01-01T13:00")),      # trả trước giờ nhận
        ("theo_gio", _vn("2030-01-03T14:00")),      # quá 24 giờ
        ("theo_ngay", _vn("2030-02-10T14:00")),     # quá 30 ngày
        ("nam_ngay", _vn("2030-01-02T14:00")),      # hình thức lạ
    ):
        with pytest.raises(HTTPException):
            stays.validate_stay(mode, vao, den, now)
