#!/usr/bin/env python3
"""Nạp sẵn tile NỀN cho vùng Việt Nam vào kho đĩa của `basemap_tile_proxy`.

## Vì sao

Đo 07/09/2026 trên staging: một ô tile chưa có trong kho tốn 600–1200ms (đường
mạng quốc tế của máy chủ, mọi mirror đều 300–450ms nên đổi nguồn không cứu
được); ô đã có trong kho tốn ~3ms. Một khung bản đồ cần 12–20 ô. Nạp trước
nghĩa là người dùng đầu tiên mở bản đồ đã thấy nền ngay thay vì làm con chuột
bạch tải hộ.

## Khối lượng (bbox Việt Nam, ~9KB/ô)

    z0–10 →     1.392 ô ≈  12 MB      z0–12 →  21.361 ô ≈ 188 MB
    z0–11 →     5.440 ô ≈  48 MB      z0–13 →  83.969 ô ≈ 738 MB

z14 trở lên (250k ô, ~3GB) KHÔNG nên nạp toàn quốc — để kho tự đầy theo chỗ
người dùng thật sự xem. Muốn nạp riêng vài thành phố thì truyền --bbox.

## Chính sách dùng tile

Tải hàng loạt từ mirror OSM cộng đồng là thứ họ không muốn. Mặc định ở đây cố
ý dè dặt: 4 kết nối song song và dừng ở z12 — tương đương vài người dùng mở
bản đồ cùng lúc, không phải một con bot. Đừng nâng --workers lên hàng chục.
Cần nhiều hơn thì hướng đi đúng là tự dựng tile (máy này đã chạy martin).

## PHẢI chạy BÊN TRONG container

Backend chạy bằng root nên mọi thư mục nó tạo trong kho đều thuộc root. Chạy
script này từ host bằng `sysadmin` sẽ bị `PermissionError` ở mọi lệnh ghi —
đã trả giá 07/09/2026: 9,5 giờ tải 493.000 ô bị vứt sạch trong im lặng. Giờ
script tự dừng ngay ô đầu tiên nếu gặp lại, nhưng cách chạy đúng là:

    docker run --rm --network faceconst_default \
      -e PYTHONPATH=/app -e BASEMAP_TILES_DIR=/app/data/basemap-tiles \
      -v "$PWD":/app -w /app \
      -v /home/sysadmin/deploy/ancu365/basemap-tiles:/app/data/basemap-tiles \
      ancu365-backend:local python scripts/prewarm_basemap.py <tham số>

## Dùng

    python3 scripts/prewarm_basemap.py                     # z0–12, VN
    python3 scripts/prewarm_basemap.py --max-zoom 13
    python3 scripts/prewarm_basemap.py --bbox 106.5,10.6,106.9,10.95 \
            --min-zoom 13 --max-zoom 15          # riêng TP.HCM
    python3 scripts/prewarm_basemap.py --dry-run           # chỉ đếm

Chạy lại được nhiều lần: ô đã có trên đĩa thì bỏ qua, nên ngắt giữa chừng rồi
chạy tiếp là an toàn.
"""

from __future__ import annotations

import argparse
import asyncio
import math
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services import basemap_tile_proxy as proxy  # noqa: E402

# Đất liền + đảo gần bờ. Trường Sa/Hoàng Sa nằm ngoài — thêm bằng --bbox nếu cần.
BBOX_VN = (102.1, 8.2, 109.6, 23.5)  # tây, nam, đông, bắc

# Đô thị mà người dùng THẬT SỰ zoom sâu vào (z15+). Nạp sẵn cả nước ở mức này
# là 21 triệu ô / 180 GB / 340 giờ, trong khi 20 vùng dưới đây chỉ tốn 210k ô /
# 1,8 GB / 3,4 giờ mà phủ gần hết chỗ có tin đăng — chênh 100 lần.
DO_THI: dict[str, tuple[float, float, float, float]] = {
    "TP.HCM": (106.45, 10.35, 107.05, 11.00),
    "Ha Noi": (105.60, 20.85, 106.05, 21.20),
    "Da Nang": (108.10, 15.95, 108.35, 16.15),
    "Hai Phong": (106.55, 20.75, 106.80, 20.95),
    "Can Tho": (105.65, 9.95, 105.85, 10.15),
    "Bien Hoa": (106.75, 10.85, 107.00, 11.05),
    "Binh Duong": (106.60, 10.90, 106.80, 11.20),
    "Nha Trang": (109.13, 12.15, 109.25, 12.35),
    "Hue": (107.53, 16.40, 107.68, 16.52),
    "Vung Tau": (107.05, 10.30, 107.20, 10.45),
    "Ha Long": (106.95, 20.90, 107.15, 21.05),
    "Vinh": (105.63, 18.62, 105.75, 18.75),
    "Buon Ma Thuot": (108.00, 12.62, 108.15, 12.75),
    "Quy Nhon": (109.15, 13.72, 109.28, 13.85),
    "Thanh Hoa": (105.70, 19.75, 105.87, 19.88),
    "Da Lat": (108.40, 11.88, 108.50, 11.98),
    "Phu Quoc": (103.85, 10.00, 104.10, 10.45),
    "Long Xuyen": (105.38, 10.32, 105.52, 10.45),
    "Thai Nguyen": (105.75, 21.52, 105.90, 21.65),
    "Rach Gia": (105.05, 9.95, 105.15, 10.05),
}


def _x_tile(lon: float, z: int) -> int:
    return int((lon + 180.0) / 360.0 * (1 << z))


def _y_tile(lat: float, z: int) -> int:
    r = math.radians(lat)
    return int((1.0 - math.log(math.tan(r) + 1.0 / math.cos(r)) / math.pi) / 2.0 * (1 << z))


def liet_ke_o(bbox, z_min: int, z_max: int):
    tay, nam, dong, bac = bbox
    for z in range(z_min, z_max + 1):
        canh = 1 << z
        x0, x1 = sorted((_x_tile(tay, z), _x_tile(dong, z)))
        y0, y1 = sorted((_y_tile(bac, z), _y_tile(nam, z)))
        for x in range(max(0, x0), min(canh - 1, x1) + 1):
            for y in range(max(0, y0), min(canh - 1, y1) + 1):
                yield z, x, y


async def _nap_mot_zoom(args, z: int, con_thieu: list) -> tuple[int, int]:
    """Tải hết ô của MỘT mức zoom. Trả (số ô ok, số ô lỗi)."""
    xong = loi = 0
    bat_dau = time.monotonic()
    hang = asyncio.Semaphore(args.workers)
    khoa_in = asyncio.Lock()

    async def mot_o(t):
        nonlocal xong, loi
        async with hang:
            try:
                data = await proxy.get_tile(*t)
            except Exception:
                data = None
            # LRU chỉ giữ 4000 ô và ở đây không đọc lại — xả để tiến trình nạp
            # hàng trăm nghìn ô không phình bộ nhớ.
            proxy._lru.clear()
        async with khoa_in:
            if data:
                xong += 1
                # Ô đầu tiên tải được PHẢI nằm trên đĩa. Không thì đang tải về
                # rồi vứt đi — dừng ngay thay vì chạy 9 giờ vô ích (đã trả giá
                # 07/09/2026: thư mục z14+ thuộc root, script chạy bằng
                # sysadmin nên mọi lệnh ghi đều bị từ chối trong im lặng).
                if xong == 1 and not proxy._disk_path(*t).exists():
                    raise SystemExit(
                        f"\n!! Tải được ô {t} nhưng nó KHÔNG nằm trên đĩa.\n"
                        f"   Kho: {proxy._disk_root()}\n"
                        f"   Gần như chắc chắn là quyền ghi: thư mục z{t[0]}/ do "
                        f"container (root) tạo,\n"
                        f"   còn script này chạy bằng {os.environ.get('USER', '?')}. "
                        f"Chạy script BÊN TRONG container:\n"
                        f"   docker exec -e BASEMAP_TILES_DIR=/app/data/basemap-tiles "
                        f"ancu365-backend-staging \\\n"
                        f"     python scripts/prewarm_basemap.py ...\n"
                    )
            else:
                loi += 1
            n = xong + loi
            if n % 500 == 0 or n == len(con_thieu):
                giay = time.monotonic() - bat_dau
                toc = n / giay if giay else 0
                con = (len(con_thieu) - n) / toc if toc else 0
                print(
                    f"  z{z}  {n:,}/{len(con_thieu):,}  ok={xong:,} lỗi={loi:,}  "
                    f"{toc:.1f} ô/s  còn ~{con / 60:.0f} phút",
                    flush=True,
                )

    await asyncio.gather(*(mot_o(t) for t in con_thieu))
    return xong, loi


def _cha_rong(z: int, x: int, y: int, nguong: int) -> bool:
    """Ô CHA (ở zoom z-1) đã tải về và RỖNG?

    Ô biển khơi / giữa rừng chỉ nặng ~103 byte (một màu nền, không nét vẽ nào).
    Cả 4 ô con của nó cũng rỗng y hệt — tải xuống là phí thời gian, phí đĩa, và
    phí lượt gọi tới mirror của người ta. Cha CHƯA tải thì không kết luận gì,
    cứ tải bình thường.
    """
    cha = proxy._disk_path(z - 1, x // 2, y // 2)
    try:
        return cha.stat().st_size < nguong
    except OSError:
        return False


async def chay(args) -> int:
    print(f"Kho: {proxy._disk_root()}  ·  zoom {args.min_zoom}–{args.max_zoom}")
    loi_ghi = proxy.kho_ghi_duoc()
    if loi_ghi and not args.dry_run:
        print(f"!! Kho KHÔNG ghi được — {loi_ghi}")
        print("   Nạp vào kho không ghi được = tải về rồi vứt. Dừng.")
        return 2
    if args.bo_qua_rong:
        print(f"Bỏ qua ô có CHA rỗng (< {args.bo_qua_rong} byte)")

    tong_xong = tong_loi = tong_bo = 0
    bat_dau = time.monotonic()

    for ten, bbox in args.vung:
        print(f"\n═══ {ten} {bbox} ═══", flush=True)
        # Đi TỪNG MỨC ZOOM một, từ thấp lên cao: mức trên phải xong thì mới
        # biết ô nào rỗng để khỏi đào sâu vào nó.
        for z in range(args.min_zoom, args.max_zoom + 1):
            o = list(liet_ke_o(bbox, z, z))
            con_thieu = []
            bo = 0
            for t in o:
                if proxy._disk_path(*t).exists():
                    continue
                if args.bo_qua_rong and z > 0 and _cha_rong(*t, args.bo_qua_rong):
                    bo += 1
                    continue
                con_thieu.append(t)
            tong_bo += bo
            print(
                f"z{z}: {len(o):,} ô · đã có {len(o) - len(con_thieu) - bo:,} · "
                f"bỏ vì rỗng {bo:,} · cần tải {len(con_thieu):,}",
                flush=True,
            )
            if args.dry_run or not con_thieu:
                continue
            xong, loi = await _nap_mot_zoom(args, z, con_thieu)
            tong_xong += xong
            tong_loi += loi

    if not args.dry_run:
        await proxy.aclose()
    giay = time.monotonic() - bat_dau
    print(
        f"\nXONG: {tong_xong:,} ô tải mới · {tong_loi:,} lỗi · "
        f"{tong_bo:,} ô bỏ vì rỗng · {giay / 60:.1f} phút"
    )
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--min-zoom", type=int, default=0)
    p.add_argument("--max-zoom", type=int, default=12)
    p.add_argument(
        "--bbox",
        default=None,
        help="tây,nam,đông,bắc (kinh/vĩ độ). Mặc định: Việt Nam",
    )
    p.add_argument(
        "--workers",
        type=int,
        default=4,
        help="số ô tải song song. Giữ nhỏ — xem phần chính sách ở đầu tệp.",
    )
    p.add_argument(
        "--do-thi",
        action="store_true",
        help=f"nạp {len(DO_THI)} đô thị lớn thay vì cả nước (dùng cho z15+)",
    )
    p.add_argument("--dry-run", action="store_true", help="chỉ đếm, không tải")
    p.add_argument(
        "--bo-qua-rong",
        type=int,
        default=0,
        metavar="BYTE",
        help="không đào sâu vào ô có CHA nhỏ hơn BYTE này (biển/rừng). "
             "300 là ngưỡng hợp lý: ô rỗng ~103 B, ô có nét vẽ > 1 KB.",
    )
    args = p.parse_args()

    if args.do_thi and args.bbox:
        p.error("--do-thi và --bbox loại trừ nhau")
    if args.do_thi:
        args.vung = list(DO_THI.items())
    elif args.bbox:
        phan = [float(v) for v in args.bbox.split(",")]
        if len(phan) != 4:
            p.error("--bbox cần đúng 4 số: tây,nam,đông,bắc")
        args.vung = [("bbox tự chọn", tuple(phan))]
    else:
        args.vung = [("Việt Nam", BBOX_VN)]

    if not 0 <= args.min_zoom <= args.max_zoom <= 19:
        p.error("zoom phải nằm trong 0..19 và min <= max")
    if args.workers > 8 and not os.environ.get("BASEMAP_PREWARM_FORCE"):
        p.error(
            "--workers > 8 là tải hàng loạt, trái chính sách dùng tile của OSM.\n"
            "Nếu đang trỏ vào nguồn TỰ DỰNG (BASEMAP_UPSTREAMS), đặt "
            "BASEMAP_PREWARM_FORCE=1 để bỏ chặn."
        )

    return asyncio.run(chay(args))


if __name__ == "__main__":
    raise SystemExit(main())
