"""Tests: lớp kiểm quyền dùng chung (spec mục 4).

Bất biến quan trọng nhất của cả spec: **sale không bao giờ có quyền tài chính**,
kể cả trên phòng mình đang quản lý. Nếu test này đỏ thì có người vừa mở một
đường cho sale sờ vào hoá đơn.
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


def _nguoi(db, role="guest"):
    from app import auth, models

    u = models.User(
        name=f"N {random.randint(1000, 9999)}",
        email=f"p_{random.randint(100000, 999999)}@test.com",
        password_hash=auth.hash_password("pass"),
        role=role,
        is_active=True,
        created_at=datetime.datetime.utcnow(),
    )
    db.add(u)
    db.flush()
    return u


def _toa_va_phong(db, host_id):
    from app import models

    now = datetime.datetime.utcnow()
    b = models.Building(host_id=host_id, name="T", created_at=now, updated_at=now)
    db.add(b)
    db.flush()
    r = models.Room(building_id=b.id, code="P1", created_at=now, updated_at=now)
    db.add(r)
    db.flush()
    return b, r


def _lien_ket(db, sale_id, owner_id, building_id, status="active"):
    from app import models

    lk = models.SaleOwnerLink(
        sale_id=sale_id,
        owner_id=owner_id,
        building_id=building_id,
        status=status,
        linked_at=datetime.datetime.utcnow(),
    )
    db.add(lk)
    db.flush()
    return lk


def test_chu_phong_co_tai_chinh_nhung_khong_sua_noi_dung(pg_session):
    from app.services import sale_permissions as perm

    chu = _nguoi(pg_session)
    _, phong = _toa_va_phong(pg_session, chu.id)
    q = perm.quyen_phong(
        pg_session, actor_id=chu.id, actor_role="host", room=phong
    )
    assert q.vai == "owner"
    assert q.doc and q.tai_chinh and q.sua_trang_thai
    # Chủ phòng YÊU CẦU sửa nội dung, không tự sửa (spec mục 4).
    assert q.sua_noi_dung is False


def test_sale_quan_ly_thi_sua_duoc_noi_dung_nhung_KHONG_tai_chinh(pg_session):
    from app.services import sale_permissions as perm

    sale = _nguoi(pg_session)
    chu = _nguoi(pg_session)
    _, phong = _toa_va_phong(pg_session, chu.id)
    phong.owner_id = chu.id
    phong.managed_by_sale_id = sale.id
    pg_session.flush()
    _lien_ket(pg_session, sale.id, chu.id, phong.building_id)

    q = perm.quyen_phong(
        pg_session, actor_id=sale.id, actor_role="guest", room=phong
    )
    assert q.vai == "sale"
    assert q.doc and q.sua_noi_dung and q.sua_trang_thai
    assert q.tai_chinh is False


def test_lien_ket_ngat_thi_sale_mat_quyen_ngay(pg_session):
    from app.services import sale_permissions as perm

    sale = _nguoi(pg_session)
    chu = _nguoi(pg_session)
    _, phong = _toa_va_phong(pg_session, chu.id)
    phong.owner_id = chu.id
    phong.managed_by_sale_id = sale.id
    pg_session.flush()
    lk = _lien_ket(pg_session, sale.id, chu.id, phong.building_id)

    lk.status = "ended"
    pg_session.flush()
    q = perm.quyen_phong(
        pg_session, actor_id=sale.id, actor_role="guest", room=phong
    )
    assert q.khong_co_gi


def test_nguoi_la_khong_co_gi(pg_session):
    from app.services import sale_permissions as perm

    chu = _nguoi(pg_session)
    la = _nguoi(pg_session)
    _, phong = _toa_va_phong(pg_session, chu.id)
    q = perm.quyen_phong(pg_session, actor_id=la.id, actor_role="guest", room=phong)
    assert q.khong_co_gi
    assert q.tai_chinh is False


def test_phong_cu_chua_co_owner_id_thi_suy_tu_toa_nha(pg_session):
    """Backfill chưa chạy hết cũng không được làm mất chủ của phòng đang chạy."""
    from app.services import sale_permissions as perm

    chu = _nguoi(pg_session)
    _, phong = _toa_va_phong(pg_session, chu.id)
    assert getattr(phong, "owner_id", None) is None
    q = perm.quyen_phong(pg_session, actor_id=chu.id, actor_role="host", room=phong)
    assert q.tai_chinh is True


def test_admin_co_tat_ca(pg_session):
    from app.services import sale_permissions as perm

    chu = _nguoi(pg_session)
    ad = _nguoi(pg_session, role="admin")
    _, phong = _toa_va_phong(pg_session, chu.id)
    q = perm.quyen_phong(pg_session, actor_id=ad.id, actor_role="admin", room=phong)
    assert q.vai == "admin" and q.tai_chinh
