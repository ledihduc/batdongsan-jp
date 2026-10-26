"""
Nominatim proxy: forward search sang Nominatim nội bộ.
Không expose port Nominatim ra public — chỉ backend gọi nội bộ.
Authorization header bị strip trước khi forward (không leak token ra upstream).
"""

from __future__ import annotations

import httpx

from app.config import settings

# Nominatim viewbox: left,top,right,bottom (toàn Việt Nam)
# Chú ý: viewbox dùng lon,lat không phải lat,lon
# Định dạng: lng_west,lat_north,lng_east,lat_south
_VN_BBOX_VIEWBOX = "102.0,23.5,110.0,8.0"


async def search(q: str, limit: int = 10) -> list[dict]:
    """
    Forward search query sang Nominatim.
    Giới hạn kết quả trong viewbox HCMC (bounded=1).
    Không forward Authorization header.
    """
    async with httpx.AsyncClient(timeout=8.0) as client:
        resp = await client.get(
            f"{settings.nominatim_url}/search",
            params={
                "q": q,
                "format": "json",
                "limit": limit,
                "viewbox": _VN_BBOX_VIEWBOX,
                "bounded": 1,
                "countrycodes": "vn",
                "addressdetails": 1,
            },
            # Không forward Authorization header — bảo mật
            headers={"User-Agent": "ancu365-backend/1.0 (ops@ancu365.vn)"},
        )
        resp.raise_for_status()
        return resp.json()


async def reverse(lat: float, lon: float) -> dict:
    """Reverse geocode một điểm sang địa chỉ (dùng cho UI khi tap map)."""
    async with httpx.AsyncClient(timeout=8.0) as client:
        resp = await client.get(
            f"{settings.nominatim_url}/reverse",
            params={
                "lat": lat,
                "lon": lon,
                "format": "json",
                "addressdetails": 1,
            },
            headers={"User-Agent": "ancu365-backend/1.0 (ops@ancu365.vn)"},
        )
        resp.raise_for_status()
        return resp.json()
