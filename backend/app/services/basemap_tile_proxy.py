"""Proxy tile NỀN (OpenStreetMap) — vì `tile.openstreetmap.org` KHÔNG phân giải
được DNS từ mạng đang chạy dịch vụ (đo 24/08/2026: `ERR_NAME_NOT_RESOLVED` trên
trình duyệt, `Name or service not known` trong container). Hậu quả: MỌI bản đồ
trong app — bản đồ tin đăng, quy hoạch, form đăng tin, "bản đồ điểm chốt" ở hồ
sơ môi giới — chỉ hiện khung xám + ghim, không có nền.

Cách chữa: client gọi thẳng backend, backend lấy tile từ máy chủ mirror còn
truy cập được rồi cache lại. Nhờ đó bản đồ hết phụ thuộc vào DNS/ISP của TỪNG
người dùng — ai chặn OSM vẫn xem được.

## Ba tầng cache (đo 07/09/2026, staging)

    RAM (LRU)  ~4 ms   ·  ĐĨA  ~3 ms   ·  đi mạng  600–1200 ms

Tầng ĐĨA là thứ quyết định. Trước đây chỉ có RAM 4000 ô, mất sạch mỗi lần
restart container, nên sau mỗi lần deploy người dùng lại trả 600ms/ô cho đúng
những ô vừa xem hôm qua. Một khung bản đồ cần 12–20 ô, kéo một vòng quanh thành
phố là hàng trăm ô — đó chính là cảm giác "kéo tới đâu xám tới đó".

Cùng pattern với `guland_tile_proxy.py` (tile quy hoạch), thứ đã chạy 2.5ms/ô
nhờ có kho trên đĩa. Basemap chỉ đang thiếu đúng tầng đó.

## Vì sao không đổi sang nguồn tile khác cho nhanh

Đo 07/09/2026 từ chính container, mỗi nguồn 8 ô qua một kết nối:
osm.fr 424ms/ô · carto voyager 442 · carto light 433 · esri 286 · opentopo 1400
· wikimedia 403(chặn) · osm.org chết DNS. Mọi nguồn đều 300–450ms → nút thắt là
đường mạng quốc tế của máy chủ, KHÔNG phải mirror nào. Đổi nguồn không cứu
được; chỉ cache mới cứu được.

Tôn trọng chính sách của OSM: gửi User-Agent định danh thật, cache mạnh (30
ngày) để không bắn lặp, và chỉ phục vụ zoom hợp lệ.
"""

from __future__ import annotations

import asyncio
import logging
import os
import time
from collections import OrderedDict
from pathlib import Path

import httpx

logger = logging.getLogger(__name__)

# Đã kêu về chuyện không ghi được đĩa chưa. Chỉ kêu MỘT lần cho mỗi loại lỗi:
# kho hỏng thì mọi ô đều lỗi, log mỗi ô một dòng sẽ chôn vùi mọi thứ khác.
_da_bao_loi_ghi: set[str] = set()


def _upstreams() -> tuple[str, ...]:
    """Danh sách nguồn, thử lần lượt. Đổi được bằng biến môi trường
    `BASEMAP_UPSTREAMS` (ngăn cách bởi dấu phẩy) để khi tìm ra nguồn nhanh hơn
    thì chỉ cần restart, không phải build lại image."""
    raw = (os.environ.get("BASEMAP_UPSTREAMS") or "").strip()
    if raw:
        parts = tuple(p.strip() for p in raw.split(",") if p.strip())
        if parts:
            return parts
    return (
        # Mirror cộng đồng, đã kiểm truy cập được từ máy chủ.
        "https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png",
        # Nguồn gốc; giữ để khi DNS thông trở lại thì tự dùng lại.
        "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    )


# Định danh thật theo yêu cầu của OSM tile usage policy.
_UA = "ancu365/1.0 (+https://ancu365.ddns.net; ops@ancu365.vn)"

_LRU_MAX = 4000
_lru: "OrderedDict[str, bytes]" = OrderedDict()
_lru_lock = asyncio.Lock()

# Khoá theo từng ô: nhiều người xem cùng một vùng thì chỉ MỘT request đi mạng.
_fetch_locks: dict[str, asyncio.Lock] = {}
_FETCH_LOCKS_MAX = 4096

# Nguồn nào vừa chạy được thì dùng lại luôn cho tile sau — tránh mỗi tile lại
# thử-lỗi qua nguồn chết (một khung bản đồ gọi ~12 tile cùng lúc).
_preferred_index = 0

# Ô mà mọi nguồn đều trả 404 (biển khơi, ngoài vùng phủ của mirror). Không nhớ
# thì mỗi lần kéo qua vùng đó lại trả 600ms để nhận lại đúng câu "không có".
# CHỈ nhớ khi upstream trả 404 dứt khoát — lỗi mạng thì phải cho thử lại, nếu
# không một sự cố 5 phút sẽ đóng băng thành lỗ hổng 10 phút trên bản đồ.
_MISS_TTL_S = 600.0
_MISS_MAX = 20000
_misses: dict[str, float] = {}


# ── Cache đĩa ────────────────────────────────────────────────────────────────
def _disk_root() -> Path:
    base = os.environ.get("BASEMAP_TILES_DIR") or str(
        Path(__file__).resolve().parents[2] / "data" / "basemap-tiles"
    )
    return Path(base)


def _disk_path(z: int, x: int, y: int) -> Path:
    return _disk_root() / str(z) / str(x) / f"{y}.png"


async def _disk_get(z: int, x: int, y: int) -> bytes | None:
    try:
        return await asyncio.to_thread(_disk_path(z, x, y).read_bytes)
    except OSError:
        # Thiếu tệp / thiếu thư mục / không có quyền — đều nghĩa là "chưa có".
        return None


async def _disk_set(z: int, x: int, y: int, data: bytes) -> None:
    """Ghi ô xuống đĩa. Ghi qua tệp tạm rồi `os.replace` — nếu tiến trình chết
    giữa chừng, cái còn lại là tệp .tmp bị bỏ quên chứ KHÔNG phải một tile PNG
    cụt nằm vĩnh viễn trong kho (cache hỏng thì không có gì tự phát hiện ra).

    Ghi hỏng thì VẪN trả tile cho người dùng — nhưng PHẢI kêu lên. Đã trả giá
    một lần (07/09/2026): thư mục z14–17 do container tạo nên thuộc root, còn
    script nạp chạy bằng `sysadmin` → `PermissionError` ở MỌI ô. Vì chỗ này
    nuốt lỗi không nói gì, 9,5 giờ tải 493.000 ô bị vứt sạch mà log vẫn báo
    "ok" đều đặn. Im lặng ở đây đắt hơn nhiều so với một dòng cảnh báo.
    """
    path = _disk_path(z, x, y)
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    try:
        await asyncio.to_thread(path.parent.mkdir, parents=True, exist_ok=True)
        await asyncio.to_thread(tmp.write_bytes, data)
        await asyncio.to_thread(os.replace, tmp, path)
    except OSError as e:
        khoa = type(e).__name__
        if khoa not in _da_bao_loi_ghi:
            _da_bao_loi_ghi.add(khoa)
            logger.warning(
                "khong ghi duoc tile xuong kho dia (%s: %s) — cache khong hoat "
                "dong, moi o se phai di mang lai. Kiem quyen ghi cua %s",
                khoa,
                e,
                _disk_root(),
            )
        try:
            await asyncio.to_thread(tmp.unlink, True)
        except OSError:
            pass


def kho_ghi_duoc() -> str | None:
    """None nếu kho ghi được; ngược lại trả câu mô tả lỗi.

    Dùng cho script nạp sẵn: nạp hàng trăm nghìn ô vào một kho không ghi được
    là tải về rồi vứt đi — phải chặn NGAY từ đầu, đừng để phát hiện sau 9 giờ.
    """
    root = _disk_root()
    thu = root / ".kiem-ghi"
    try:
        root.mkdir(parents=True, exist_ok=True)
        thu.write_bytes(b"x")
        thu.unlink()
    except OSError as e:
        return f"{type(e).__name__}: {e}"
    return None


# ── Cache RAM ────────────────────────────────────────────────────────────────
async def _lru_get(key: str) -> bytes | None:
    async with _lru_lock:
        if key in _lru:
            _lru.move_to_end(key)
            return _lru[key]
    return None


async def _lru_set(key: str, value: bytes) -> None:
    async with _lru_lock:
        _lru[key] = value
        _lru.move_to_end(key)
        while len(_lru) > _LRU_MAX:
            _lru.popitem(last=False)


# ── Client dùng chung ────────────────────────────────────────────────────────
# Trước đây mỗi ô mở một `AsyncClient` mới → mỗi ô trả 415ms tiền bắt tay
# TCP+TLS trên tổng 620ms (67%). Đo 07/09/2026: 12 ô kết nối mới = 15.0s, 12 ô
# dùng chung kết nối = 9.5s.
_client: httpx.AsyncClient | None = None
_client_loop: asyncio.AbstractEventLoop | None = None


def _new_client() -> httpx.AsyncClient:
    return httpx.AsyncClient(
        timeout=httpx.Timeout(8.0),
        follow_redirects=True,
        headers={"User-Agent": _UA},
        # Một khung bản đồ bắn ~20 ô cùng lúc; giữ đủ kết nối sống để đợt sau
        # không phải bắt tay lại. `keepalive_expiry` dài vì người dùng kéo bản
        # đồ theo từng đợt cách nhau vài giây.
        limits=httpx.Limits(
            max_connections=64,
            max_keepalive_connections=32,
            keepalive_expiry=300.0,
        ),
    )


def _get_client() -> httpx.AsyncClient:
    global _client, _client_loop
    loop = asyncio.get_running_loop()
    if _client is not None and not _client.is_closed and _client_loop is loop:
        return _client
    # Vòng lặp sự kiện đổi — thực tế chỉ xảy ra trong test (mỗi test một loop).
    # KHÔNG đóng client cũ ở đây: pool của nó gắn với loop đã chết, đóng bằng
    # loop mới thì httpx ném lỗi. Cứ bỏ tham chiếu, GC lo phần còn lại.
    _client = _new_client()
    _client_loop = loop
    return _client


async def aclose() -> None:
    """Đóng client dùng chung. Gọi khi tắt app để không rò socket."""
    global _client, _client_loop
    c, _client, _client_loop = _client, None, None
    if c is not None and not c.is_closed:
        try:
            await c.aclose()
        except Exception:
            pass


# ── Lấy tile ─────────────────────────────────────────────────────────────────
async def _fetch(z: int, x: int, y: int) -> tuple[bytes | None, bool]:
    """Trả `(nội dung, chắc chắn không tồn tại)`.

    Cờ thứ hai chỉ bật khi MỌI nguồn đều trả 404 — phân biệt "ô này không có"
    với "mạng đang hỏng", vì chỉ trường hợp đầu mới được phép nhớ vào
    `_misses`."""
    global _preferred_index
    upstreams = _upstreams()
    order = sorted(range(len(upstreams)), key=lambda i: 0 if i == _preferred_index else 1)
    client = _get_client()
    het_sach_404 = True
    for i in order:
        url = upstreams[i].format(z=z, x=x, y=y)
        try:
            r = await client.get(url)
        except Exception:
            het_sach_404 = False  # lỗi mạng, không phải "không có ô"
            continue
        if r.status_code == 200 and r.content:
            _preferred_index = i
            return r.content, False
        if r.status_code != 404:
            het_sach_404 = False
    return None, het_sach_404


def _mien_nho_thieu(key: str) -> bool:
    """Ô này vừa được xác nhận là không tồn tại và chưa hết hạn nhớ?"""
    han = _misses.get(key)
    if han is None:
        return False
    if han > time.monotonic():
        return True
    _misses.pop(key, None)
    return False


def _nho_thieu(key: str) -> None:
    if len(_misses) >= _MISS_MAX:
        now = time.monotonic()
        for k, han in list(_misses.items()):
            if han <= now:
                del _misses[k]
        if len(_misses) >= _MISS_MAX:
            _misses.clear()
    _misses[key] = time.monotonic() + _MISS_TTL_S


def _lay_khoa(key: str) -> asyncio.Lock:
    lock = _fetch_locks.get(key)
    if lock is None:
        if len(_fetch_locks) >= _FETCH_LOCKS_MAX:
            # Dọn những khoá đang RẢNH. Bỏ nhầm một khoá đang giữ thì cùng lắm
            # có hai request cùng đi lấy một ô — phí, chứ không sai.
            for k, lk in list(_fetch_locks.items()):
                if not lk.locked():
                    del _fetch_locks[k]
        lock = _fetch_locks[key] = asyncio.Lock()
    return lock


async def get_tile(z: int, x: int, y: int) -> bytes | None:
    """Tile nền theo z/x/y. None nếu mọi nguồn đều hỏng (client sẽ thấy 404 và
    flutter_map bỏ qua ô đó — không làm vỡ màn)."""
    # Chặn tham số vô lý trước khi đi mạng: zoom OSM tối đa 19, x/y phải nằm
    # trong lưới 2^z.
    if not (0 <= z <= 19):
        return None
    limit = 1 << z
    if not (0 <= x < limit and 0 <= y < limit):
        return None

    key = f"{z}/{x}/{y}"
    cached = await _lru_get(key)
    if cached is not None:
        return cached

    tren_dia = await _disk_get(z, x, y)
    if tren_dia:
        await _lru_set(key, tren_dia)
        return tren_dia

    if _mien_nho_thieu(key):
        return None

    lock = _lay_khoa(key)
    async with lock:
        # Có thể một request khác vừa nạp xong trong lúc chờ khoá.
        cached = await _lru_get(key)
        if cached is not None:
            return cached
        if _mien_nho_thieu(key):
            return None

        data, chac_chan_thieu = await _fetch(z, x, y)
        if data is not None:
            await _lru_set(key, data)
            await _disk_set(z, x, y, data)
        elif chac_chan_thieu:
            _nho_thieu(key)
        return data
