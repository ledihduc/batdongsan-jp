"""Pydantic shapes cho geo-search (tường minh để có OpenAPI schema cho Flutter).

Router houses hiện trả dict thô qua helpers.house_to_dict; các endpoint geo mới
trả thêm `distance_km` (chỉ khi sort=distance) và `place` (khi geocode địa danh).
"""

from __future__ import annotations

from pydantic import BaseModel


class PlaceRef(BaseModel):
    """Điểm địa danh đã geocode (tâm để tìm quanh)."""

    display_name: str
    lat: float
    lng: float


class HouseNearbyResponse(BaseModel):
    """Kết quả tìm theo địa danh: houses + tâm địa danh.

    `houses` giữ shape dict cũ (house_to_dict) + trường `distance_km` (km, làm tròn
    2 chữ số) khi có toạ độ. `place=None` khi không geocode được địa danh.
    """

    houses: list[dict]
    total: int
    place: PlaceRef | None = None
