"""
test_smoke_geo_search.py — Postgres/PostGIS integration smoke tests cho geo-search.

Kiểm tra:
- Trigger houses_sync_geom: geom được set từ lat/lng; set NULL → geom NULL.
- house_search_service.query_nearby: sort khoảng cách, loại tin geom NULL, lọc bán kính.
- Lọc province_code (nhánh ORM).

Requires SMOKE_DATABASE_URL trỏ tới Postgres+PostGIS đã `alembic upgrade head`.
Dùng pg_session (transactional rollback — không để lại data).
"""

from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.orm import Session


def _mk_house(db: Session, *, title, lat, lng, status="approved", price=3_000_000,
              city="TP HCM", province_code=None, available_units=1):
    from app import models

    h = models.House(
        host_id=1, title=title, description="", category_id=1, price=price, area=25,
        address="addr", city=city, district="Q", latitude=lat, longitude=lng,
        status=status, available_units=available_units, province_code=province_code,
    )
    db.add(h)
    db.flush()
    return h


def test_trigger_syncs_geom_from_latlng(pg_session: Session):
    h = _mk_house(pg_session, title="geo-A", lat=10.7769, lng=106.7009)
    pg_session.flush()
    has_geom = pg_session.execute(
        text("SELECT geom IS NOT NULL FROM houses WHERE id=:i"), {"i": h.id}
    ).scalar()
    assert has_geom is True

    # set lat/lng NULL → trigger nulls geom
    h.latitude = None
    h.longitude = None
    pg_session.flush()
    geom_null = pg_session.execute(
        text("SELECT geom IS NULL FROM houses WHERE id=:i"), {"i": h.id}
    ).scalar()
    assert geom_null is True


def test_query_nearby_distance_sort_and_null_exclusion(pg_session: Session):
    from app.services import house_search_service as s

    a = _mk_house(pg_session, title="near-A", lat=10.7769, lng=106.7009)  # ~0km
    b = _mk_house(pg_session, title="near-B", lat=10.7300, lng=106.7215)  # ~5.7km
    c = _mk_house(pg_session, title="near-C-null", lat=None, lng=None)     # no coords
    pg_session.flush()

    r = s.query_nearby(pg_session, near_lat=10.7770, near_lng=106.7010,
                       radius_km=8, sort="distance", limit=50)
    titles = [h["title"] for h in r["houses"]]
    assert "near-A" in titles and "near-B" in titles
    assert "near-C-null" not in titles                    # geom NULL bị loại
    # đúng thứ tự khoảng cách
    assert titles.index("near-A") < titles.index("near-B")
    # distance_km tăng dần + có giá trị
    dists = [h["distance_km"] for h in r["houses"] if h["title"] in ("near-A", "near-B")]
    assert dists == sorted(dists)
    assert all(d is not None for d in dists)

    # bán kính 1km → chỉ A
    r1 = s.query_nearby(pg_session, near_lat=10.7770, near_lng=106.7010,
                        radius_km=1, sort="distance", limit=50)
    assert [h["title"] for h in r1["houses"]] == ["near-A"]
    _ = (a, b, c)


def test_query_nearby_province_and_price_filter(pg_session: Session):
    from app.services import house_search_service as s

    _mk_house(pg_session, title="hcm-cheap", lat=10.7769, lng=106.7009,
              province_code="tp-ho-chi-minh", price=2_000_000)
    _mk_house(pg_session, title="hcm-pricey", lat=10.7770, lng=106.7010,
              province_code="tp-ho-chi-minh", price=9_000_000)
    pg_session.flush()

    r = s.query_nearby(pg_session, near_lat=10.7770, near_lng=106.7010, radius_km=5,
                       province="tp-ho-chi-minh", max_price=3_000_000, sort="distance")
    titles = [h["title"] for h in r["houses"]]
    assert "hcm-cheap" in titles
    assert "hcm-pricey" not in titles     # bị lọc bởi max_price
