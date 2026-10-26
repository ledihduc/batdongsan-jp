"""Profile uy tín Đợt 1 — tự ghi rating/response host + review đa tiêu chí.

Bất biến chính: các cột uy tín host (rating, avg_response_hours) TRƯỚC ĐÂY CHẾT
(có schema, không nguồn ghi) nay được hệ thống tự cập nhật từ dữ liệu thật, và
điểm TỔNG do khách cho trực tiếp — KHÔNG phải trung bình các tiêu chí con.
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

import app.models  # noqa: F401
from app import helpers, models
from app.database import Base


@pytest.fixture(scope="module")
def engine():
    e = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=e)
    yield e
    e.dispose()


@pytest.fixture
def db(engine) -> Generator[Session, None, None]:
    conn = engine.connect()
    tx = conn.begin()
    s = sessionmaker(bind=conn, autoflush=False, autocommit=False)()
    yield s
    s.close()
    tx.rollback()
    conn.close()


@pytest.fixture
def host_setup(db):
    """Host #1 có hồ sơ + 1 nhà."""
    prof = models.HostProfile(user_id=1, verified=True)
    house = models.House(host_id=1, title="Nhà A", category_id=1, price=5_000_000)
    db.add_all([prof, house])
    db.commit()
    db.refresh(prof); db.refresh(house)
    return {"prof": prof, "house": house}


class TestHostRating:
    def test_rating_tinh_tu_reviews(self, db, host_setup):
        h = host_setup["house"]
        db.add_all([
            models.Review(user_id=2, house_id=h.id, rating=5),
            models.Review(user_id=3, house_id=h.id, rating=3),
        ])
        db.commit()
        helpers.recompute_host_reputation(db, 1)
        db.commit()
        db.refresh(host_setup["prof"])
        assert host_setup["prof"].rating == 4.0  # (5+3)/2

    def test_khong_co_review_thi_rating_khong_doi(self, db, host_setup):
        helpers.recompute_host_reputation(db, 1)
        db.commit()
        db.refresh(host_setup["prof"])
        assert host_setup["prof"].rating is None

    def test_host_khong_co_ho_so_thi_bo_qua_khong_no(self, db):
        # host 999 không có HostProfile → không được nổ.
        helpers.recompute_host_reputation(db, 999)  # không raise
        db.commit()


class TestResponseHours:
    def test_avg_response_tinh_tu_responded_at(self, db, host_setup):
        h = host_setup["house"]
        now = datetime(2026, 7, 20, 10, 0, 0)
        db.add_all([
            models.ViewingAppointment(
                house_id=h.id, guest_id=2, status="approved",
                created_at=now, responded_at=now + timedelta(hours=2)),
            models.ViewingAppointment(
                house_id=h.id, guest_id=3, status="approved",
                created_at=now, responded_at=now + timedelta(hours=4)),
            # Chưa phản hồi → không tính vào trung bình.
            models.ViewingAppointment(
                house_id=h.id, guest_id=4, status="pending",
                created_at=now, responded_at=None),
        ])
        db.commit()
        helpers.recompute_host_reputation(db, 1)
        db.commit()
        db.refresh(host_setup["prof"])
        assert host_setup["prof"].avg_response_hours == 3.0  # (2+4)/2


class TestReviewSubCriteria:
    def test_review_luu_duoc_tieu_chi_con(self, db, host_setup):
        # Điểm TỔNG (rating) độc lập với các mục con — không phải trung bình.
        r = models.Review(
            user_id=2, house_id=host_setup["house"].id, rating=5,
            cleanliness=4, accuracy=5, checkin=3, communication=5,
            location=2, value=4)
        db.add(r)
        db.commit()
        db.refresh(r)
        assert r.rating == 5  # tổng do khách cho, KHÁC trung bình mục con (3.83)
        assert r.cleanliness == 4 and r.location == 2

    def test_tieu_chi_con_nullable(self, db, host_setup):
        r = models.Review(user_id=3, house_id=host_setup["house"].id, rating=4)
        db.add(r)
        db.commit()
        db.refresh(r)
        assert r.cleanliness is None  # không bắt buộc
