"""Trang HTML dựng sẵn ở máy chủ cho công cụ tìm kiếm.

VÌ SAO CẦN: app viết bằng Flutter web dựng bằng CanvasKit — toàn bộ giao diện
vẽ lên <canvas>. Bot tìm kiếm nạp trang chỉ thấy một tài liệu HTML rỗng, không
có tiêu đề tin, giá, hay địa chỉ nào. Với sản phẩm mà kênh phân phối tự nhiên
là tìm kiếm ("thuê nhà quận X"), đó là rào cản cấu trúc chứ không phải tiểu tiết.

NGUYÊN TẮC: phục vụ ĐÚNG MỘT nội dung cho cả người lẫn bot. Trả trang khác nhau
tuỳ User-Agent (cloaking) là vi phạm hướng dẫn của Google và có thể bị loại khỏi
kết quả. Vì vậy trang này là trang thật, đọc được, có đường dẫn mở trong ứng dụng.
"""

import html
import re
import unicodedata
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request, Response
from fastapi.responses import HTMLResponse, PlainTextResponse
from sqlalchemy.orm import Session

from app import models
from app.config import settings
from app.database import get_db

router = APIRouter(tags=["seo"])

# Chỉ tin đã đăng mới được đưa ra ngoài. Tin nháp/chờ duyệt/bị từ chối lọt ra
# là vừa lộ dữ liệu vừa làm bẩn chỉ mục tìm kiếm bằng trang sẽ chết.
_PUBLIC_STATUS = "published"

_KHONG_DAU = str.maketrans("đĐ", "dD")


def slugify(text: str) -> str:
    """'Nhà 2PN Quận 7' → 'nha-2pn-quan-7'. Bỏ dấu để URL sạch và ổn định."""
    text = (text or "").translate(_KHONG_DAU)
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text[:80] or "tin"


def _tien(v: float) -> str:
    """Định dạng tiền kiểu Việt: 3500000 → '3,5 triệu'."""
    v = float(v or 0)
    if v >= 1_000_000_000:
        s = f"{v / 1_000_000_000:.1f}".rstrip("0").rstrip(".")
        return f"{s} tỷ".replace(".", ",")
    if v >= 1_000_000:
        s = f"{v / 1_000_000:.1f}".rstrip("0").rstrip(".")
        return f"{s} triệu".replace(".", ",")
    return f"{int(v):,}".replace(",", ".") + " đ"


def _base(request: Request | None = None) -> str:
    """Địa chỉ gốc để dựng URL tuyệt đối.

    Ưu tiên suy từ chính request (X-Forwarded-Proto + Host do NPM đặt) thay vì
    hằng số `APP_BASE_URL`: hằng số đó đang là `http://…` trong khi site chạy
    `https://`. Canonical sai giao thức khiến công cụ tìm kiếm coi http và https
    là hai trang trùng nội dung. Suy từ request cũng tự đúng ngay khi đổi sang
    tên miền riêng mà không phải sửa cấu hình.
    """
    if request is not None:
        host = request.headers.get("host", "").strip()
        if host:
            proto = request.headers.get("x-forwarded-proto", "").strip()
            if proto not in ("http", "https"):
                proto = request.url.scheme or "https"
            return f"{proto}://{host}"
    return settings.app_base_url.rstrip("/")


def _abs_url(path: str, request: Request | None = None) -> str:
    if not path:
        return ""
    if path.startswith("http://") or path.startswith("https://"):
        return path
    return f"{_base(request)}/{path.lstrip('/')}"


def duong_dan_tin(h: models.House) -> str:
    return f"/tin/{h.id}-{slugify(h.title)}"


def _mo_ta(h: models.House) -> str:
    """Mô tả ~155 ký tự cho thẻ meta — độ dài Google thường hiển thị."""
    noi = ", ".join(x for x in [h.district, h.city] if x)
    dau = f"{_tien(h.price)}"
    if (h.transaction_type or "rent") == "rent":
        dau += "/tháng"
    manh = [dau]
    if h.area:
        manh.append(f"{int(h.area)}m²")
    if h.bedrooms:
        manh.append(f"{h.bedrooms} phòng ngủ")
    if noi:
        manh.append(noi)
    mo_ta = " · ".join(manh)
    them = (h.description or "").strip().replace("\n", " ")
    if them:
        mo_ta = f"{mo_ta}. {them}"
    return mo_ta[:155]


def _trang(
    *,
    tieu_de: str,
    mo_ta: str,
    duong_dan: str,
    anh: str = "",
    than: str = "",
    du_lieu_co_cau: str = "",
    robots: str = "index, follow",
    request: Request | None = None,
) -> str:
    canonical = _abs_url(duong_dan, request)
    e = html.escape
    anh_tag = (
        f'<meta property="og:image" content="{e(_abs_url(anh, request))}">' if anh else ""
    )
    ld = (
        f'<script type="application/ld+json">{du_lieu_co_cau}</script>'
        if du_lieu_co_cau
        else ""
    )
    return f"""<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(tieu_de)}</title>
<meta name="description" content="{e(mo_ta)}">
<meta name="robots" content="{e(robots)}">
<link rel="canonical" href="{e(canonical)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="ancu365">
<meta property="og:title" content="{e(tieu_de)}">
<meta property="og:description" content="{e(mo_ta)}">
<meta property="og:url" content="{e(canonical)}">
{anh_tag}
<meta name="twitter:card" content="summary_large_image">
{ld}
<style>
:root{{--do:#B71C1C;--muc:#1a1a1a;--nhat:#666;--vien:#e5e5e5}}
*{{box-sizing:border-box}}
body{{margin:0;font:16px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
color:var(--muc);background:#fff}}
.bao{{max-width:760px;margin:0 auto;padding:24px 20px 64px}}
header{{border-bottom:1px solid var(--vien);padding:16px 0;margin-bottom:24px}}
header a{{color:var(--do);font-weight:700;font-size:20px;text-decoration:none}}
h1{{font-size:26px;line-height:1.3;margin:0 0 8px}}
.gia{{color:var(--do);font-size:22px;font-weight:700;margin:0 0 4px}}
.noi{{color:var(--nhat);margin:0 0 20px}}
.thong-so{{display:flex;flex-wrap:wrap;gap:8px;list-style:none;padding:0;margin:0 0 24px}}
.thong-so li{{border:1px solid var(--vien);border-radius:4px;padding:6px 12px;font-size:14px}}
img{{width:100%;height:auto;border-radius:6px;margin-bottom:12px;display:block}}
.mo-ta{{white-space:pre-wrap;margin-bottom:28px}}
.nut{{display:inline-block;background:var(--do);color:#fff;text-decoration:none;
padding:14px 28px;border-radius:6px;font-weight:600}}
ul.ds{{list-style:none;padding:0}}
ul.ds li{{border-bottom:1px solid var(--vien);padding:14px 0}}
ul.ds a{{color:var(--muc);text-decoration:none;font-weight:600}}
ul.ds a:hover{{color:var(--do)}}
.phu{{color:var(--nhat);font-size:14px}}
footer{{border-top:1px solid var(--vien);margin-top:40px;padding-top:16px;
color:var(--nhat);font-size:14px}}
</style>
</head>
<body>
<div class="bao">
<header><a href="/">ancu365</a></header>
{than}
<footer>ancu365 — nền tảng thông tin bất động sản và thi công.</footer>
</div>
</body>
</html>"""


@router.get("/tin/{slug}", response_class=HTMLResponse)
def trang_tin(
    slug: str, request: Request, response: Response, db: Session = Depends(get_db)
):
    """Trang chi tiết một tin đăng, dựng sẵn ở máy chủ.

    [slug] dạng `{id}-{tieu-de}`. Chỉ phần id được dùng để tra cứu; phần chữ chỉ
    để URL dễ đọc, đổi tiêu đề không làm chết liên kết cũ.
    """
    m = re.match(r"^(\d+)", slug)
    if not m:
        return HTMLResponse(_trang_khong_thay(), status_code=404)

    h = db.query(models.House).filter(models.House.id == int(m.group(1))).first()
    if not h or h.status != _PUBLIC_STATUS:
        # 404 chứ không phải 200-với-nội-dung-rỗng: bot cần biết trang này không
        # tồn tại để loại khỏi chỉ mục, thay vì giữ lại một trang chết.
        return HTMLResponse(_trang_khong_thay(), status_code=404)

    # URL chuẩn khác URL đang gọi (tiêu đề đã đổi) → chuyển hướng vĩnh viễn để
    # gom sức mạnh liên kết về một địa chỉ duy nhất.
    dung = duong_dan_tin(h)
    if f"/tin/{slug}" != dung:
        response.status_code = 301
        response.headers["Location"] = dung
        return HTMLResponse("", status_code=301, headers={"Location": dung})

    e = html.escape
    thue = (h.transaction_type or "rent") == "rent"
    gia = _tien(h.price) + ("/tháng" if thue else "")
    noi = ", ".join(x for x in [h.address, h.district, h.city] if x)

    thong_so = []
    if h.area:
        thong_so.append(f"{int(h.area)} m²")
    if h.bedrooms:
        thong_so.append(f"{h.bedrooms} phòng ngủ")
    if h.bathrooms:
        thong_so.append(f"{h.bathrooms} phòng tắm")
    if h.available_units and h.total_units and h.total_units > 1:
        thong_so.append(f"còn {h.available_units}/{h.total_units} căn")

    anhs = [a for a in (h.images or []) if a][:3]
    anh_html = "".join(
        f'<img src="{e(_abs_url(a, request))}" alt="{e(h.title)}" loading="lazy">'
        for a in anhs
    )

    than = f"""<article>
<h1>{e(h.title)}</h1>
<p class="gia">{e(gia)}</p>
<p class="noi">{e(noi) or "Chưa cập nhật địa chỉ"}</p>
{anh_html}
<ul class="thong-so">{"".join(f"<li>{e(t)}</li>" for t in thong_so)}</ul>
<div class="mo-ta">{e((h.description or "").strip()) or "Chưa có mô tả."}</div>
<a class="nut" href="/#/house/{h.id}">Xem chi tiết và đặt lịch</a>
</article>"""

    ld = _json_ld_tin(h, request)
    return HTMLResponse(
        _trang(
            tieu_de=f"{h.title} — {gia} | ancu365",
            mo_ta=_mo_ta(h),
            duong_dan=dung,
            anh=anhs[0] if anhs else "",
            than=than,
            du_lieu_co_cau=ld,
            request=request,
        )
    )


def _json_ld_tin(h: models.House, request: Request) -> str:
    """Dữ liệu có cấu trúc schema.org — giúp kết quả tìm kiếm hiện giá, ảnh."""
    import json

    d = {
        "@context": "https://schema.org",
        "@type": "Residence",
        "name": h.title,
        "url": _abs_url(duong_dan_tin(h), request),
        "description": (h.description or "")[:500],
    }
    if h.images:
        d["image"] = [_abs_url(a, request) for a in h.images[:3] if a]
    diachi = {"@type": "PostalAddress", "addressCountry": "VN"}
    if h.address:
        diachi["streetAddress"] = h.address
    if h.district:
        diachi["addressLocality"] = h.district
    if h.city:
        diachi["addressRegion"] = h.city
    d["address"] = diachi
    if h.latitude is not None and h.longitude is not None:
        d["geo"] = {
            "@type": "GeoCoordinates",
            "latitude": h.latitude,
            "longitude": h.longitude,
        }
    if h.area:
        d["floorSize"] = {
            "@type": "QuantitativeValue",
            "value": h.area,
            "unitCode": "MTK",
        }
    if h.bedrooms:
        d["numberOfRooms"] = h.bedrooms
    return json.dumps(d, ensure_ascii=False)


def _trang_khong_thay() -> str:
    return _trang(
        tieu_de="Không tìm thấy tin đăng | ancu365",
        mo_ta="Tin đăng này không còn tồn tại hoặc đã được gỡ.",
        duong_dan="/tin/khong-tim-thay",
        robots="noindex, follow",
        than="<article><h1>Không tìm thấy tin đăng</h1>"
        '<p class="noi">Tin này có thể đã được gỡ hoặc cho thuê xong.</p>'
        '<a class="nut" href="/">Về trang chủ</a></article>',
    )


@router.get("/tin", response_class=HTMLResponse)
def danh_muc_tin(request: Request, db: Session = Depends(get_db)):
    """Trang mục lục — cho bot một điểm bò tới mọi tin, và cho người một chỗ duyệt."""
    hs = (
        db.query(models.House)
        .filter(models.House.status == _PUBLIC_STATUS)
        .order_by(models.House.created_at.desc())
        .limit(200)
        .all()
    )
    e = html.escape
    muc = "".join(
        f'<li><a href="{e(duong_dan_tin(h))}">{e(h.title)}</a>'
        f'<div class="phu">{e(_tien(h.price))}'
        f'{"/tháng" if (h.transaction_type or "rent") == "rent" else ""}'
        f'{" · " + e(h.district) if h.district else ""}'
        f'{" · " + e(h.city) if h.city else ""}</div></li>'
        for h in hs
    )
    than = (
        f"<h1>Tin đăng trên ancu365</h1>"
        f'<p class="noi">{len(hs)} tin đang hiển thị.</p>'
        f'<ul class="ds">{muc}</ul>'
        if hs
        else "<h1>Tin đăng trên ancu365</h1>"
        '<p class="noi">Chưa có tin nào được đăng.</p>'
    )
    return HTMLResponse(
        _trang(
            tieu_de="Tin đăng cho thuê & bán nhà | ancu365",
            mo_ta="Danh sách tin đăng cho thuê và bán bất động sản trên ancu365.",
            duong_dan="/tin",
            than=than,
            request=request,
        )
    )


@router.head("/privacy", response_class=HTMLResponse)
@router.get("/privacy", response_class=HTMLResponse)
def privacy_policy(request: Request):
    """Public privacy policy for App Store Connect."""
    than = """<article>
<h1>Chinh sach bao mat</h1>
<p class="phu">Cap nhat: 10/08/2026</p>
<p>ancu365 ton trong quyen rieng tu cua nguoi dung. Chinh sach nay mo ta cach chung toi thu thap, su dung va bao ve du lieu khi ban su dung ung dung ancu365.</p>
<h2>Du lieu chung toi thu thap</h2>
<ul>
<li>Thong tin tai khoan: ho ten, email, so dien thoai, anh dai dien va vai tro tai khoan.</li>
<li>Noi dung nguoi dung cung cap: tin dang, hinh anh, video, binh luan, danh gia, yeu cau dat lich, thong tin ho so chu nha/khach thue va ho so xac minh khi nguoi dung chu dong gui.</li>
<li>Vi tri: toa do chinh xac hoac gan dung khi nguoi dung chu dong bam lay vi tri hien tai hoac ghim vi tri tren ban do.</li>
<li>Dinh danh ky thuat: ma nguoi dung, ma thiet bi/cai dat va token thong bao day dung de dang nhap, bao mat phien va gui thong bao.</li>
<li>Du lieu su dung va chan doan: su kien tuong tac co ban, trang thai cap quyen, loi ung dung, log hieu nang va thong tin ky thuat can thiet de van hanh dich vu.</li>
</ul>
<h2>Muc dich su dung</h2>
<ul>
<li>Cung cap chuc nang tim phong, tim nha, dang tin, quan ly hop dong, hoa don, lich xem nha va dich vu xay dung.</li>
<li>Hien thi ket qua gan vi tri cua ban khi ban yeu cau.</li>
<li>Gui thong bao ve lich hen, tin nhan, cap nhat tai khoan va cac su kien lien quan den giao dich trong ung dung.</li>
<li>Phong chong gian lan, bao ve tai khoan, xu ly bao cao vi pham va cai thien do on dinh cua he thong.</li>
</ul>
<h2>Chia se du lieu</h2>
<p>Chung toi khong ban du lieu ca nhan va khong su dung du lieu de theo doi quang cao ben thu ba. Du lieu co the duoc xu ly boi cac nha cung cap ha tang can thiet nhu may chu, luu tru tep va Firebase Cloud Messaging de gui thong bao day.</p>
<h2>Quyen cua nguoi dung</h2>
<p>Ban co the cap nhat thong tin tai khoan trong ung dung, dang xuat, yeu cau xoa tai khoan hoac lien he chung toi de duoc ho tro ve du lieu ca nhan.</p>
<h2>Tre em</h2>
<p>ancu365 khong danh rieng cho tre em duoi 13 tuoi va khong co chu dich thu thap du lieu tu tre em.</p>
<h2>Lien he</h2>
<p>Email ho tro: <a href="mailto:support@ancu365.vn">support@ancu365.vn</a></p>
</article>"""
    return HTMLResponse(
        _trang(
            tieu_de="Chinh sach bao mat | ancu365",
            mo_ta="Chinh sach bao mat cua ung dung ancu365 ve du lieu tai khoan, vi tri, noi dung nguoi dung, thong bao va chan doan.",
            duong_dan="/privacy",
            than=than,
            request=request,
        )
    )


@router.head("/support", response_class=HTMLResponse)
@router.get("/support", response_class=HTMLResponse)
def support_page(request: Request):
    """Public support page for App Store Connect."""
    than = """<article>
<h1>Ho tro ancu365</h1>
<p>Neu ban can ho tro ve tai khoan, dang tin, dat lich xem nha, thong bao, vi tri hoac xoa tai khoan, vui long lien he doi ngu ancu365.</p>
<ul>
<li>Email ho tro: <a href="mailto:support@ancu365.vn">support@ancu365.vn</a></li>
<li>Thoi gian phan hoi thong thuong: trong 1-3 ngay lam viec.</li>
<li>Khi gui yeu cau, vui long kem email dang nhap, so dien thoai tai khoan va mo ta van de de chung toi xu ly nhanh hon.</li>
</ul>
<h2>Xoa tai khoan</h2>
<p>Nguoi dung co the yeu cau xoa tai khoan trong ung dung hoac gui email den support@ancu365.vn. Sau khi xac minh chu tai khoan, chung toi se vo hieu hoa tai khoan va xoa/an danh hoa du lieu ca nhan theo quy dinh van hanh cua dich vu.</p>
<h2>Quyen rieng tu</h2>
<p>Xem <a href="/privacy">Chinh sach bao mat</a> de biet them cach ancu365 thu thap va su dung du lieu.</p>
</article>"""
    return HTMLResponse(
        _trang(
            tieu_de="Ho tro | ancu365",
            mo_ta="Trang ho tro cua ancu365 cho tai khoan, dang tin, dat lich, thong bao, vi tri va yeu cau xoa tai khoan.",
            duong_dan="/support",
            than=than,
            request=request,
        )
    )


@router.get("/sitemap.xml")
def sitemap(request: Request, db: Session = Depends(get_db)):
    hs = (
        db.query(models.House)
        .filter(models.House.status == _PUBLIC_STATUS)
        .order_by(models.House.created_at.desc())
        .limit(5000)
        .all()
    )
    base = _base(request)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    def url(loc: str, lastmod: str, prio: str) -> str:
        return (
            f"<url><loc>{html.escape(loc)}</loc>"
            f"<lastmod>{lastmod}</lastmod>"
            f"<priority>{prio}</priority></url>"
        )

    muc = [url(f"{base}/", now, "1.0"), url(f"{base}/tin", now, "0.9")]
    for h in hs:
        lm = (h.created_at or datetime.now(timezone.utc)).strftime("%Y-%m-%d")
        muc.append(url(f"{base}{duong_dan_tin(h)}", lm, "0.8"))

    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        + "".join(muc)
        + "</urlset>"
    )
    return Response(content=xml, media_type="application/xml")


@router.get("/robots.txt", response_class=PlainTextResponse)
def robots(request: Request):
    # Chặn bot khỏi vùng riêng tư và vùng vô nghĩa với tìm kiếm. `/api/` bị chặn
    # để bot không đốt ngân sách bò vào JSON.
    return (
        "User-agent: *\n"
        "Allow: /\n"
        "Disallow: /api/\n"
        "Disallow: /admin\n"
        "Disallow: /uploads/\n"
        "Disallow: /docs\n"
        "Disallow: /redoc\n"
        f"\nSitemap: {_base(request)}/sitemap.xml\n"
    )
