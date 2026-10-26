#!/usr/bin/env python3
"""Sinh bộ ảnh thương hiệu từ MỘT nguồn duy nhất: tools/icon_src/logo_master.png.

Vì sao cần script này thay vì thu nhỏ thẳng logo gốc: logo gốc là logo ĐẦY ĐỦ —
thẻ bo góc + ghim + chữ "VUA NHÀ" + dòng "THUÊ • Ở • MUA • BÁN". Thu nhỏ nguyên
khối xuống 32px (favicon) hay ~48dp (icon launcher) thì phần chữ biến thành một
vệt nâu không đọc được, và mặt nạ tròn của Android còn cắt cụt chữ ("'UA NH`").

Nên tách làm hai bản dẫn xuất:
  logo_mark.png  — CHỈ ghim, nền trong suốt. Dùng cho chỗ nhỏ/hẹp (AppBar, drawer).
  app_icon.png   — thẻ bo góc + viền vàng gốc, BỎ chữ, ghim căn giữa. Dùng cho
                   favicon + icon PWA + icon launcher Android/iOS.
Bản logo ĐẦY ĐỦ vẫn giữ nguyên cho các màn lớn (splash / đăng nhập / đăng ký).

Chạy:  python3 tools/gen_brand_icons.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools/icon_src/logo_master.png"

# Màu nền thẻ, lấy mẫu từ chính logo gốc (vùng cream sạch ở cột 150).
CREAM = (250, 245, 241)

# Toạ độ đo trên bản gốc 1024×1024 (xem docstring — dò bằng ngưỡng "khác cream").
PIN_BOX = (325, 137, 698, 676)   # bbox phần ghim, không dính chữ
TEXT_TOP = 678                   # từ hàng này trở xuống là chữ + gạch trang trí
PIN_FILL = 0.74                  # ghim chiếm bao nhiêu chiều cao thẻ sau khi bỏ chữ


def load_src() -> Image.Image:
    im = Image.open(SRC).convert("RGBA")
    if im.size != (1024, 1024):
        im = im.resize((1024, 1024), Image.LANCZOS)
    return im


def ink_mask(arr: np.ndarray) -> np.ndarray:
    """Pixel 'có mực' = đục và khác màu nền cream."""
    rgb = arr[:, :, :3].astype(int)
    alpha = arr[:, :, 3]
    dist = np.abs(rgb - np.array(CREAM)).sum(axis=2)
    return (alpha > 128) & (dist > 90)


def make_mark(src: Image.Image, pad: float = 0.10) -> Image.Image:
    """Cắt riêng ghim, đặt vào khung vuông trong suốt."""
    mark = src.crop(PIN_BOX)
    w, h = mark.size
    side = int(max(w, h) * (1 + pad))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(mark, ((side - w) // 2, (side - h) // 2))
    return canvas.resize((1024, 1024), Image.LANCZOS)


def make_app_icon(src: Image.Image) -> Image.Image:
    """Thẻ + viền vàng GỐC, xoá chữ, ghim căn giữa lại theo chiều dọc.

    Xoá chữ theo TỪNG HÀNG: dò vệt mực ngoài cùng trái/phải của hàng đó (chính
    là viền vàng) rồi tô cream cho khoảng giữa. Làm vậy để viền bo góc giữ
    nguyên đúng hình dáng designer vẽ, thay vì tự vẽ lại một hình chữ nhật bo
    góc gần giống.
    """
    arr = np.array(src).copy()
    ink = ink_mask(arr)
    alpha = arr[:, :, 3]

    for r in range(TEXT_TOP, 1024):
        cols = np.where(ink[r])[0]
        if len(cols) == 0:
            continue
        runs, start, prev = [], cols[0], cols[0]
        for c in cols[1:]:
            if c != prev + 1:
                runs.append((start, prev))
                start = c
            prev = c
        runs.append((start, prev))
        if len(runs) < 2:
            continue  # chỉ còn viền dính liền nhau -> đã tới đáy thẻ
        left, right = runs[0][1] + 6, runs[-1][0] - 6
        if right <= left:
            continue
        span = slice(left, right)
        inside = alpha[r, span] > 128
        arr[r, span, :3] = np.where(inside[:, None], np.array(CREAM), arr[r, span, :3])

    carded = Image.fromarray(arr)

    # Ghim đang nằm lệch lên trên (chỗ cũ dành cho chữ) và chỉ chiếm 61% chiều
    # cao thẻ. Bỏ chữ rồi thì phải PHÓNG TO + căn giữa lại, nếu không icon
    # trông hụt chân và ở cỡ favicon 32px thì ghim bé tí giữa một mảng cream.
    top, bottom = 68, 952  # bbox thẻ theo alpha
    card_h = bottom - top
    pin = src.crop(PIN_BOX)
    scale = (card_h * PIN_FILL) / pin.height
    pin = pin.resize((round(pin.width * scale), round(pin.height * scale)), Image.LANCZOS)

    # Xoá ghim ở chỗ cũ trước khi dán chỗ mới.
    patch = Image.new("RGBA", (PIN_BOX[2] - PIN_BOX[0], PIN_BOX[3] - PIN_BOX[1]),
                      CREAM + (255,))
    carded.paste(patch, (PIN_BOX[0], PIN_BOX[1]))
    carded.alpha_composite(pin, ((1024 - pin.width) // 2,
                                 top + (card_h - pin.height) // 2))
    return carded


def make_maskable(mark: Image.Image, size: int) -> Image.Image:
    """Icon maskable cho PWA: nền cream TRÀN VIỀN, ghim gói trong vùng an toàn.

    Chuẩn maskable chỉ bảo đảm hiển thị hình tròn đường kính 80% cạnh; icon
    maskable cũ ở đây là logo tràn viền nên góc thẻ và dòng tagline bị cắt.
    """
    canvas = Image.new("RGBA", (size, size), CREAM + (255,))
    inner = int(size * 0.56)
    canvas.alpha_composite(mark.resize((inner, inner), Image.LANCZOS),
                           ((size - inner) // 2, (size - inner) // 2))
    return canvas


def main() -> None:
    src = load_src()
    mark = make_mark(src)
    app_icon = make_app_icon(src)

    branding = ROOT / "assets/branding"
    icon_src = ROOT / "tools/icon_src"
    icon_src.mkdir(exist_ok=True)

    # ẢNH DÙNG TRONG APP — vào assets/branding/, và pubspec khai báo CẢ THƯ MỤC
    # nên mọi tệp ở đây đi thẳng vào gói web tải về. Đo được: nửa số khách rời
    # trang trong lúc chờ tải gói ~1,5MB. Vì vậy ảnh runtime để cỡ vừa đủ dùng,
    # KHÔNG để bản 1024px.
    #   logo_full 512 — đủ nét cho splash/đăng nhập (hiển thị ~120-160px @3x).
    #   logo_mark  256 — đủ nét cho AppBar/drawer (hiển thị ~20-28px @3x).
    src.resize((512, 512), Image.LANCZOS).save(branding / "logo_full.png")
    mark.resize((256, 256), Image.LANCZOS).save(branding / "logo_mark.png")

    # ẢNH NGUỒN SINH ICON — chỉ flutter_launcher_icons đọc lúc build, KHÔNG
    # được nằm trong assets/branding/ nếu không mỗi bản web gánh thêm ~940KB
    # chết. Thư mục con không được Flutter gộp đệ quy nên để đây là an toàn.
    app_icon.save(icon_src / "app_icon.png")
    make_mark(src, pad=0.30).save(icon_src / "app_icon_foreground.png")

    web = ROOT / "web"
    app_icon.resize((32, 32), Image.LANCZOS).save(web / "favicon.png")
    for n in (192, 512):
        app_icon.resize((n, n), Image.LANCZOS).save(web / f"icons/Icon-{n}.png")
        make_maskable(mark, n).save(web / f"icons/Icon-maskable-{n}.png")

    print("đã sinh:")
    for p in ["assets/branding/logo_full.png", "assets/branding/logo_mark.png",
              "tools/icon_src/app_icon.png", "tools/icon_src/app_icon_foreground.png",
              "web/favicon.png", "web/icons/Icon-192.png", "web/icons/Icon-512.png",
              "web/icons/Icon-maskable-192.png", "web/icons/Icon-maskable-512.png"]:
        f = ROOT / p
        print(f"  {p}  {Image.open(f).size}  {f.stat().st_size // 1024}KB")


if __name__ == "__main__":
    main()
