"""Tiền cọc hợp đồng sinh khi chốt thuê: dat_coc là số tháng HOẶC số tiền."""

from app.services.marketplace_sync_service import tien_coc_hop_dong


def test_dat_coc_la_so_tien_khong_nhan_voi_tien_thue():
    # Bug thật (HD-00026): 4.500.000 × 4.500.000 = 20.250 tỷ ₫.
    assert tien_coc_hop_dong(4_500_000, 4_500_000) == 4_500_000


def test_dat_coc_la_so_thang():
    assert tien_coc_hop_dong(4_500_000, 2) == 9_000_000
    assert tien_coc_hop_dong(4_500_000, 1.5) == 6_750_000


def test_khong_khai_coc_mac_dinh_mot_thang_va_khong_coc():
    assert tien_coc_hop_dong(4_500_000, None) == 4_500_000
    assert tien_coc_hop_dong(4_500_000, 0) == 0
