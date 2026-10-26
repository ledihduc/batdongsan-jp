"""
Mapping province slug → guland CDN path (port từ faceconst).

CDN base: https://l5cfglaebpobj.vcdn.cloud
Tile URL format: {base}/{path}/{z}/{x}/{y}.png

Hai variant CDN path đã xác thực qua live probe 2026-06-05:
- 49 tỉnh: "{slug}-2030"
- 7 tỉnh:  "v2/{slug}-2030"

Lưu ý: 15 tỉnh chỉ có tile từ zoom 12+, chưa có ở zoom 8/10.
Faceconst excluded (no planning data at any zoom): bac-giang, da-nang,
ha-giang, ha-noi, hau-giang, lao-cai, nam-dinh — nhưng phía ta vẫn có
local cache cho da-nang nên giữ enable.
"""

from __future__ import annotations

# slug (vietnam-provinces.json) → guland CDN sub-path
GULAND_PROVINCE_MAP: dict[str, str] = {
    # ── 49 tỉnh no-prefix ────────────────────────────────────────────────────
    "an-giang": "an-giang-2030",
    "ba-ria-vung-tau": "ba-ria-vung-tau-2030",
    "bac-kan": "bac-kan-2030",
    "bac-lieu": "bac-lieu-2030",
    "bac-ninh": "bac-ninh-2030",
    "ben-tre": "ben-tre-2030",
    "binh-dinh": "binh-dinh-2030",
    "binh-duong": "binh-duong-2030",
    "binh-phuoc": "binh-phuoc-2030",
    "ca-mau": "ca-mau-2030",
    "cao-bang": "cao-bang-2030",
    "dak-lak": "dak-lak-2030",
    "dak-nong": "dak-nong-2030",
    "dien-bien": "dien-bien-2030",
    "dong-nai": "dong-nai-2030",
    "dong-thap": "dong-thap-2030",
    "gia-lai": "gia-lai-2030",
    "ha-nam": "ha-nam-2030",
    "ha-tinh": "ha-tinh-2030",
    "hai-duong": "hai-duong-2030",
    "hai-phong": "hai-phong-2030",
    "hoa-binh": "hoa-binh-2030",
    "hung-yen": "hung-yen-2030",
    "kien-giang": "kien-giang-2030",
    "kon-tum": "kon-tum-2030",
    "lai-chau": "lai-chau-2030",
    "lam-dong": "lam-dong-2030",
    "lang-son": "lang-son-2030",
    "long-an": "long-an-2030",
    "nghe-an": "nghe-an-2030",
    "ninh-binh": "ninh-binh-2030",
    "ninh-thuan": "ninh-thuan-2030",
    "phu-tho": "phu-tho-2030",
    "phu-yen": "phu-yen-2030",
    "quang-binh": "quang-binh-2030",
    "quang-ngai": "quang-ngai-2030",
    "quang-ninh": "quang-ninh-2030",
    "soc-trang": "soc-trang-2030",
    "son-la": "son-la-2030",
    "tay-ninh": "tay-ninh-2030",
    "thai-binh": "thai-binh-2030",
    "thanh-hoa": "thanh-hoa-2030",
    "thua-thien-hue": "thua-thien-hue-2030",
    "tp-ho-chi-minh": "tp-ho-chi-minh-2030",
    "tra-vinh": "tra-vinh-2030",
    "tuyen-quang": "tuyen-quang-2030",
    "vinh-long": "vinh-long-2030",
    "vinh-phuc": "vinh-phuc-2030",
    "yen-bai": "yen-bai-2030",
    # ── 7 tỉnh v2/ prefix ────────────────────────────────────────────────────
    "binh-thuan": "v2/binh-thuan-2030",
    "can-tho": "v2/can-tho-2030",
    "khanh-hoa": "v2/khanh-hoa-2030",
    "quang-nam": "v2/quang-nam-2030",
    "quang-tri": "v2/quang-tri-2030",
    "thai-nguyen": "v2/thai-nguyen-2030",
    "tien-giang": "v2/tien-giang-2030",
    # ── Đà Nẵng (faceconst exclude — ta vẫn có cache local) ─────────────────
    "da-nang": "da-nang-2030",
    # ── 6 tỉnh Guland để ở HOST/tên KHÁC (dò 20/08/2026) — base ở GULAND_TOKEN_BASE ──
    "nam-dinh": "nam-dinh-2030",       # DigitalOcean /qh
    "ha-giang": "ha-giang-2030",       # DigitalOcean /qh
    "hau-giang": "hau-giang-2030",     # DigitalOcean /qh
    "lao-cai": "lao-cai-2030",         # DigitalOcean /qh
    "ha-noi": "hanoi-pk",              # vcdn /v2 (slug lạ 'hanoi-pk')
    "bac-giang": "bac-giang-road",     # CMC Telecom S3 /guland6
}

# Token (path segment đầu) → CDN base RIÊNG. Không có trong đây → dùng GULAND_CDN_BASE.
# Guland phân tán tile ra nhiều object-storage + đặt tên không đồng nhất theo tỉnh.
_DO_QH = "https://guland.sgp1.cdn.digitaloceanspaces.com/qh"
GULAND_TOKEN_BASE: dict[str, str] = {
    "nam-dinh-2030": _DO_QH,
    "ha-giang-2030": _DO_QH,
    "hau-giang-2030": _DO_QH,
    "lao-cai-2030": _DO_QH,
    "hanoi-pk": "https://r4gmiynxmeobj.vcdn.cloud/v2",
    "bac-giang-road": "https://s3.hn-1.cloud.cmctelecom.vn/guland6",
}


def get_guland_path(province_slug: str) -> str | None:
    """Trả CDN sub-path (vd 'binh-thuan' → 'v2/binh-thuan-2030') hoặc None."""
    return GULAND_PROVINCE_MAP.get(province_slug)


# CDN gốc — không bao giờ expose ra client.
# CDN host của Guland (object-storage vcdn.cloud). LƯU Ý: host này XOAY định kỳ —
# khi tile 403 (body <Code>InvalidAccessKeyId</Code>) nghĩa là bucket cũ bị thu hồi,
# mở guland.vn bằng trình duyệt → xem request tile trong DevTools để lấy host mới rồi
# cập nhật dòng dưới. (l5cfglaebpobj → r4gmiynxmeobj: đổi 20/08/2026). Zoom 8–17.
GULAND_CDN_BASE = "https://r4gmiynxmeobj.vcdn.cloud"
