"""
Tính sao chất lượng nhà trọ theo tiêu chí + gợi ý đơn giá.

Thuần toán (không I/O) → dễ test. Trọng số/hệ số cấu hình qua config để Product
chốt sau mà không sửa code.
"""

from __future__ import annotations

# 5 tiêu chí chất lượng (theo cuộc họp).
CRITERIA_KEYS = (
    "pccc",  # phòng cháy chữa cháy
    "full_furniture",  # đầy đủ đồ
    "kitchen",  # có bếp
    "private_bathroom",  # vệ sinh khép kín
    "air_conditioner",  # điều hoà
)

# Hệ số giá theo sao (so với mức 3★ = chuẩn).
STAR_PRICE_MULTIPLIER = {1: 0.8, 2: 0.9, 3: 1.0, 4: 1.15, 5: 1.3}


def normalize_criteria(raw: dict | None) -> dict:
    """Chỉ giữ đúng 5 khoá, ép về bool."""
    raw = raw or {}
    return {k: bool(raw.get(k)) for k in CRITERIA_KEYS}


def compute_self_star(criteria: dict | None) -> int:
    """
    Suy sao từ số tiêu chí đạt.
    - 0 tiêu chí → 1★, 5 tiêu chí → 5★ (tuyến tính, làm tròn).
    - PCCC là điều kiện chặn: thiếu PCCC → tối đa 3★ (an toàn cháy nổ).
    """
    c = normalize_criteria(criteria)
    met = sum(1 for k in CRITERIA_KEYS if c[k])
    star = round(1 + met * 0.8)  # 0→1 … 5→5
    if not c["pccc"]:
        star = min(star, 3)
    return max(1, min(5, star))


def suggested_price(area_m2: float, star: int, base_rate_per_m2: int) -> int:
    """Gợi ý đơn giá thuê/tháng = diện tích × đơn giá/m² × hệ số sao.

    v1 dùng base_rate cố định (config). v2 sẽ thay bằng trung vị giá/m² theo khu
    vực (PostGIS) — xem docs/RENTAL-PIVOT-PLAN.md.
    """
    if area_m2 <= 0:
        return 0
    mult = STAR_PRICE_MULTIPLIER.get(star, 1.0)
    return int(round(area_m2 * base_rate_per_m2 * mult))
