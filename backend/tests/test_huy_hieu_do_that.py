"""Tests: huy hiệu chỉ đứng được khi có PHÉP ĐO thật (migration 0087).

Bối cảnh: staging từng có `avg_response_hours = 0.6` trên 1.053 hồ sơ trong khi
bảng lịch hẹn RỖNG, và 1.025 đánh giá đều vào từ thời cổng còn tắt. Bộ test này
giữ cho hai con số đó không bao giờ tự đứng dậy làm huy hiệu được nữa.
"""

from __future__ import annotations

import datetime
import os
import random

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

pytestmark = pytest.mark.skipif(
    not os.getenv("SMOKE_DATABASE_URL"), reason="SMOKE_DATABASE_URL not set"
)


def _nguoi(db, role="host"):
    from app import auth, models

    u = models.User(
        name=f"H {random.randint(1000, 9999)}",
        email=f"hh_{random.randint(100000, 999999)}@test.com",
        password_hash=auth.hash_password("pass"),
        role=role,
        is_active=True,
        created_at=datetime.datetime.utcnow(),
    )
    db.add(u)
    db.flush()
    return u


def _loai(db):
    from app import models

    c = db.query(models.Category).first()
    if c is None:
        c = models.Category(name="Căn hộ")
        db.add(c)
        db.flush()
    return c.id


def _ho_so(db, uid, **kw):
    from app import models

    now = datetime.datetime.utcnow()
    p = models.HostProfile(user_id=uid, created_at=now, updated_at=now, **kw)
    db.add(p)
    db.flush()
    return p


def test_khong_co_lich_hen_thi_co_mau_bang_0(pg_session):
    """Đúng tình trạng staging: có avg_response_hours mà không có phép đo nào."""
    from app import helpers, models

    u = _nguoi(pg_session)
    p = _ho_so(pg_session, u.id, avg_response_hours=0.6)
    helpers.recompute_host_reputation(pg_session, u.id)
    pg_session.flush()
    assert pg_session.get(models.HostProfile, p.id).response_sample == 0


def test_danh_gia_cu_khong_tinh_vao_uy_tin(pg_session):
    """5 đánh giá 5 sao nhưng đều `verified_relationship=false` → KHÔNG uy tín."""
    from app import helpers, models

    now = datetime.datetime.utcnow()
    chu = _nguoi(pg_session)
    p = _ho_so(pg_session, chu.id, verified=True)
    nha = models.House(
        host_id=chu.id,
        title="N",
        description="",
        price=1,
        area=1,
        address="",
        city="",
        district="",
        category_id=_loai(pg_session),
        status="published",
        created_at=now,
    )
    pg_session.add(nha)
    pg_session.flush()
    for _ in range(5):
        pg_session.add(
            models.Review(
                user_id=_nguoi(pg_session, "guest").id,
                house_id=nha.id,
                rating=5,
                comment="ok",
                verified_relationship=False,
                created_at=now,
            )
        )
    pg_session.flush()

    helpers.recompute_host_reputation(pg_session, chu.id)
    pg_session.flush()
    pg_session.refresh(p)
    assert p.rating == 5.0  # điểm vẫn tính
    assert p.review_count == 5
    assert p.verified_review_count == 0  # nhưng mẫu đã kiểm bằng 0
    assert helpers.is_trusted_host(p) is False


def test_du_5_danh_gia_da_kiem_thi_duoc_uy_tin(pg_session):
    from app import helpers, models

    now = datetime.datetime.utcnow()
    chu = _nguoi(pg_session)
    p = _ho_so(pg_session, chu.id, verified=True)
    nha = models.House(
        host_id=chu.id,
        title="N",
        description="",
        price=1,
        area=1,
        address="",
        city="",
        district="",
        category_id=_loai(pg_session),
        status="published",
        created_at=now,
    )
    pg_session.add(nha)
    pg_session.flush()
    for _ in range(5):
        pg_session.add(
            models.Review(
                user_id=_nguoi(pg_session, "guest").id,
                house_id=nha.id,
                rating=5,
                comment="ok",
                verified_relationship=True,
                created_at=now,
            )
        )
    pg_session.flush()

    helpers.recompute_host_reputation(pg_session, chu.id)
    pg_session.flush()
    pg_session.refresh(p)
    assert p.verified_review_count == 5
    assert helpers.is_trusted_host(p) is True


def test_chua_xac_minh_thi_du_danh_gia_van_khong_uy_tin(pg_session):
    from app import helpers

    chu = _nguoi(pg_session)
    p = _ho_so(pg_session, chu.id, verified=False, rating=5.0)
    p.verified_review_count = 9
    pg_session.flush()
    assert helpers.is_trusted_host(p) is False


def test_api_tra_kem_co_mau(pg_session):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    from app.database import get_db
    from app.routers.hosts_public import router

    chu = _nguoi(pg_session)
    _ho_so(pg_session, chu.id, verified=True, avg_response_hours=0.6)
    pg_session.flush()

    app = FastAPI()
    app.include_router(router)

    def _o():
        yield pg_session

    app.dependency_overrides[get_db] = _o
    c = TestClient(app, raise_server_exceptions=False)
    d = c.get(f"/api/hosts/{chu.id}").json()
    # Con số vẫn trả về, nhưng cỡ mẫu đi kèm để client biết nó dựa trên 0 lần.
    assert d["avg_response_hours"] == 0.6
    assert d["response_sample"] == 0
    assert d["verified_review_count"] == 0
    assert d["trusted"] is False
