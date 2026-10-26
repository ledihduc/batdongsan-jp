"""Regression tests — đóng đinh các bug ĐÃ LỌT production (Tech Lead B2).

Mỗi test tương ứng 1 bug thật, chống tái phát:
- write_change_log nhận actor_id (backward-compat) → bug đăng tin 500 (TypeError).
- query_nearby default status='published' → bug /search-nearby trả rỗng.
- query_nearby lọc transaction_type → bug trộn thang giá rent/sale ở geo.
- HouseStatus constants nhất quán → chống drift 'approved' vs 'published'.

Requires SMOKE_DATABASE_URL (Postgres+PostGIS, alembic head). pg_session rollback.
"""

from __future__ import annotations


def test_house_status_constants_no_drift():
    from app.house_status import HouseStatus
    assert HouseStatus.PUBLISHED == "published"
    assert HouseStatus.PENDING_REVIEW == "pending_review"
    assert HouseStatus.REJECTED == "rejected"
    assert HouseStatus.PUBLIC == HouseStatus.PUBLISHED
    # Legacy phải KHÁC published (nếu bằng nhau là lẫn lộn trạng thái).
    assert HouseStatus.APPROVED_LEGACY != HouseStatus.PUBLISHED


def test_write_change_log_accepts_legacy_actor_id(pg_session):
    """Refactor đổi actor_id→explicit_actor_id làm ~19 caller gãy 500 (đăng tin)."""
    from app import auth, models
    from app.repositories.audit import write_change_log

    u = models.User(
        name="regr", email="regr_actor@test.local",
        password_hash=auth.hash_password("x"), role="host", is_active=True,
    )
    pg_session.add(u)
    pg_session.flush()

    row = write_change_log(
        pg_session, entity_type="host_profile", entity_id=u.id,
        action="create", before=None, after={"x": 1}, actor_id=u.id,
    )
    assert row.actor_id == u.id  # legacy actor_id vẫn được ghi đúng


def _mk_house(db, **kw):
    from app import models
    d = dict(host_id=1, title="t", description="", category_id=1, price=3_000_000.0,
             area=25.0, city="TP HCM", district="Q", status="published",
             available_units=1, transaction_type="rent")
    d.update(kw)
    h = models.House(**d)
    db.add(h)
    db.flush()
    return h


def test_query_nearby_default_status_published(pg_session):
    """query_nearby default 'approved' (cũ) làm /search-nearby trả rỗng."""
    from app.services import house_search_service as s
    _mk_house(pg_session, title="pub", latitude=10.7769, longitude=106.7009, status="published")
    _mk_house(pg_session, title="pend", latitude=10.7770, longitude=106.7010, status="pending_review")
    pg_session.flush()
    r = s.query_nearby(pg_session, near_lat=10.7770, near_lng=106.7010, radius_km=5)
    titles = [h["title"] for h in r["houses"]]
    assert "pub" in titles and "pend" not in titles


def test_query_nearby_transaction_type_partition(pg_session):
    """geo không lọc transaction_type → trộn thang giá rent(triệu)/sale(tỷ)."""
    from app.services import house_search_service as s
    _mk_house(pg_session, title="rentH", latitude=10.7769, longitude=106.7009, transaction_type="rent", price=5_000_000.0)
    _mk_house(pg_session, title="saleH", latitude=10.7770, longitude=106.7010, transaction_type="sale", price=2_000_000_000.0)
    pg_session.flush()
    r = s.query_nearby(pg_session, near_lat=10.777, near_lng=106.701, radius_km=5, transaction_type="rent")
    titles = [h["title"] for h in r["houses"]]
    assert "rentH" in titles and "saleH" not in titles
