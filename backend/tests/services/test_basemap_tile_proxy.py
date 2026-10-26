"""Unit test — `app/services/basemap_tile_proxy.py` (proxy tile nền bản đồ).

Trọng tâm là TẦNG CACHE ĐĨA, thứ vừa thêm để chữa lag bản đồ: ô đã xem một lần
phải không bao giờ đi mạng lại, kể cả sau khi restart container (RAM mất, đĩa
còn). Đo 07/09/2026: đi mạng 600–1200ms/ô, đọc đĩa ~3ms.

Mọi test đều CẤM đi mạng thật — `_fetch` luôn bị thay bằng hàm giả đếm số lần
gọi, nên "có đi mạng hay không" là thứ khẳng định được chứ không phải suy đoán.
"""

from __future__ import annotations

import asyncio
import os

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from app.services import basemap_tile_proxy as proxy  # noqa: E402

PNG = b"\x89PNG\r\n\x1a\nfake-tile-bytes"


@pytest.fixture(autouse=True)
def kho_tam(tmp_path, monkeypatch):
    """Mỗi test một kho đĩa riêng + trạng thái module sạch.

    Không cô lập thì test sau ăn cache của test trước và mọi khẳng định về "có
    đi mạng không" thành vô nghĩa.
    """
    monkeypatch.setenv("BASEMAP_TILES_DIR", str(tmp_path))
    monkeypatch.delenv("BASEMAP_UPSTREAMS", raising=False)
    proxy._lru.clear()
    proxy._misses.clear()
    proxy._fetch_locks.clear()
    proxy._preferred_index = 0
    yield tmp_path


def gia_lap_fetch(monkeypatch, ket_qua, *, dem=None):
    """Thay `_fetch` bằng hàm giả trả `ket_qua` và đếm số lần bị gọi."""
    so_lan = dem if dem is not None else []

    async def _gia(z, x, y):
        so_lan.append((z, x, y))
        return ket_qua

    monkeypatch.setattr(proxy, "_fetch", _gia)
    return so_lan


# ── Cache đĩa ────────────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_ghi_xuong_dia_sau_khi_lay_ve(monkeypatch, kho_tam):
    gia_lap_fetch(monkeypatch, (PNG, False))

    assert await proxy.get_tile(12, 3253, 1926) == PNG
    assert (kho_tam / "12" / "3253" / "1926.png").read_bytes() == PNG


@pytest.mark.asyncio
async def test_mat_ram_van_doc_duoc_tu_dia(monkeypatch, kho_tam):
    """Đúng kịch bản restart container: RAM trắng, đĩa còn → KHÔNG đi mạng."""
    gia_lap_fetch(monkeypatch, (PNG, False))
    await proxy.get_tile(12, 3253, 1926)

    proxy._lru.clear()  # giả lập tiến trình vừa khởi động lại
    so_lan = gia_lap_fetch(monkeypatch, (None, False))

    assert await proxy.get_tile(12, 3253, 1926) == PNG
    assert so_lan == [], "đã có trên đĩa mà vẫn đi mạng"


@pytest.mark.asyncio
async def test_doc_dia_thi_nap_lai_vao_ram(monkeypatch, kho_tam):
    p = kho_tam / "9" / "404" / "233.png"
    p.parent.mkdir(parents=True)
    p.write_bytes(PNG)
    so_lan = gia_lap_fetch(monkeypatch, (None, False))

    assert await proxy.get_tile(9, 404, 233) == PNG
    assert proxy._lru.get("9/404/233") == PNG
    assert so_lan == []


@pytest.mark.asyncio
async def test_ghi_dia_khong_de_lai_tep_tam(monkeypatch, kho_tam):
    """Ghi qua .tmp rồi replace — xong việc không được còn rác, vì tệp cụt nằm
    trong kho sẽ là một ô hỏng vĩnh viễn mà không gì tự phát hiện ra."""
    gia_lap_fetch(monkeypatch, (PNG, False))
    await proxy.get_tile(10, 1, 2)

    con_lai = [p.name for p in kho_tam.rglob("*") if p.is_file()]
    assert con_lai == ["2.png"]


@pytest.mark.asyncio
async def test_dia_khong_ghi_duoc_van_tra_tile(monkeypatch, kho_tam):
    """Đĩa đầy / chỉ-đọc là sự cố vận hành, không được biến thành bản đồ trắng."""
    chan = kho_tam / "chan.txt"
    chan.write_text("day la mot TEP chu khong phai thu muc")
    # mkdir dưới một tệp → OSError, đúng hình dạng lỗi của đĩa hỏng.
    monkeypatch.setattr(proxy, "_disk_root", lambda: chan)
    gia_lap_fetch(monkeypatch, (PNG, False))

    assert await proxy.get_tile(10, 5, 6) == PNG


# ── Nhớ ô không tồn tại ──────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_404_dut_khoat_thi_nho_va_khong_hoi_lai(monkeypatch, kho_tam):
    so_lan = gia_lap_fetch(monkeypatch, (None, True))

    assert await proxy.get_tile(14, 100, 200) is None
    assert await proxy.get_tile(14, 100, 200) is None
    assert len(so_lan) == 1, "ô đã biết là không có mà vẫn hỏi lại"


@pytest.mark.asyncio
async def test_loi_mang_thi_KHONG_nho(monkeypatch, kho_tam):
    """Phân biệt 'ô này không có' với 'mạng đang hỏng'. Nhớ nhầm cái sau sẽ
    biến một sự cố 5 phút thành lỗ hổng 10 phút trên bản đồ."""
    so_lan = gia_lap_fetch(monkeypatch, (None, False))

    assert await proxy.get_tile(14, 100, 200) is None
    assert await proxy.get_tile(14, 100, 200) is None
    assert len(so_lan) == 2, "lỗi mạng mà lại nhớ thành 'không có ô'"


@pytest.mark.asyncio
async def test_nho_thieu_het_han_thi_thu_lai(monkeypatch, kho_tam):
    so_lan = gia_lap_fetch(monkeypatch, (None, True))
    await proxy.get_tile(14, 1, 1)
    proxy._misses["14/1/1"] = 0.0  # đẩy về quá khứ = hết hạn

    await proxy.get_tile(14, 1, 1)
    assert len(so_lan) == 2


@pytest.mark.asyncio
async def test_bang_nho_thieu_co_tran(monkeypatch, kho_tam):
    for i in range(proxy._MISS_MAX + 5):
        proxy._nho_thieu(f"k{i}")
    assert len(proxy._misses) <= proxy._MISS_MAX


# ── Chặn tham số ─────────────────────────────────────────────────────────────
@pytest.mark.asyncio
@pytest.mark.parametrize(
    "z,x,y",
    [(-1, 0, 0), (20, 0, 0), (2, 4, 0), (2, 0, 4), (2, -1, 0), (2, 0, -1)],
)
async def test_toa_do_vo_ly_bi_chan_truoc_khi_di_mang(monkeypatch, z, x, y):
    so_lan = gia_lap_fetch(monkeypatch, (PNG, False))
    assert await proxy.get_tile(z, x, y) is None
    assert so_lan == []


# ── Gộp request trùng ────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_nhieu_nguoi_cung_mot_o_chi_di_mang_mot_lan(monkeypatch, kho_tam):
    so_lan: list = []

    async def _cham(z, x, y):
        so_lan.append((z, x, y))
        await asyncio.sleep(0.05)
        return PNG, False

    monkeypatch.setattr(proxy, "_fetch", _cham)
    ket_qua = await asyncio.gather(*(proxy.get_tile(13, 7, 7) for _ in range(8)))

    assert ket_qua == [PNG] * 8
    assert len(so_lan) == 1


@pytest.mark.asyncio
async def test_bang_khoa_co_tran(kho_tam):
    for i in range(proxy._FETCH_LOCKS_MAX + 10):
        proxy._lay_khoa(f"k{i}")
    assert len(proxy._fetch_locks) <= proxy._FETCH_LOCKS_MAX + 1


# ── Client dùng chung ────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_client_dung_lai_trong_cung_vong_lap():
    """Trước đây mỗi ô mở một client mới → 415ms bắt tay TCP+TLS trên tổng
    620ms. Dùng lại client là chỗ tiết kiệm đó."""
    a = proxy._get_client()
    b = proxy._get_client()
    assert a is b
    await proxy.aclose()


@pytest.mark.asyncio
async def test_aclose_don_sach():
    proxy._get_client()
    await proxy.aclose()
    assert proxy._client is None
    await proxy.aclose()  # gọi hai lần không được nổ


def test_client_moi_khi_doi_vong_lap():
    """Mỗi test pytest-asyncio chạy trên một loop riêng. Client gắn với loop
    cũ mà đem dùng ở loop mới thì httpx ném lỗi — phải tự dựng lại."""

    async def lay():
        return proxy._get_client()

    a = asyncio.run(lay())
    b = asyncio.run(lay())
    assert a is not b


# ── Nguồn tile ───────────────────────────────────────────────────────────────
def test_nguon_mac_dinh():
    assert proxy._upstreams()[0].startswith("https://a.tile.openstreetmap.fr/")


def test_doi_nguon_bang_bien_moi_truong(monkeypatch):
    monkeypatch.setenv("BASEMAP_UPSTREAMS", " https://a/{z}/{x}/{y}.png , https://b/{z}/{x}/{y}.png ")
    assert proxy._upstreams() == (
        "https://a/{z}/{x}/{y}.png",
        "https://b/{z}/{x}/{y}.png",
    )


def test_bien_moi_truong_rong_thi_dung_mac_dinh(monkeypatch):
    monkeypatch.setenv("BASEMAP_UPSTREAMS", "   ,  ")
    assert proxy._upstreams()[0].startswith("https://a.tile.openstreetmap.fr/")
