"""Router tile NỀN bản đồ: GET /api/basemap/{z}/{x}/{y}.png

Vì sao có: `tile.openstreetmap.org` không phân giải DNS được từ mạng của dịch
vụ (và của người dùng qua đo thực tế) → bản đồ toàn app trống nền. Xem
`app/services/basemap_tile_proxy.py` để biết chi tiết + nguồn thay thế.
"""

from __future__ import annotations

from fastapi import APIRouter, Response

from app.services.basemap_tile_proxy import get_tile

# Cố ý nằm DƯỚI /api: cả staging (nginx `^~ /api`) lẫn prod (NPM `location
# /api/`) đã route sẵn tiền tố này về backend. Đặt prefix riêng `/basemap` sẽ
# phải sửa cấu hình nginx của HAI site (và NPM UI có thể ghi đè file 3.conf —
# xem memory), đổi lấy rủi ro không đáng.
router = APIRouter(prefix="/api/basemap", tags=["basemap"])

_TILE_HEADERS = {
    # Tile nền gần như bất biến → cache dài để trình duyệt không hỏi lại.
    "Cache-Control": "public, max-age=2592000, immutable",
    "Access-Control-Allow-Origin": "*",
}


@router.get("/{z}/{x}/{y}.png")
async def serve_basemap_tile(z: int, x: int, y: int) -> Response:
    data = await get_tile(z, x, y)
    if data is None:
        return Response(status_code=404)
    return Response(content=data, media_type="image/png", headers=_TILE_HEADERS)
