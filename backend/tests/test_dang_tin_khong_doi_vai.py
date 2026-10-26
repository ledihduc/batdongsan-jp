"""Đăng tin KHÔNG biến người bán thành chủ nhà.

Vì sao khoá lại bằng test: `create_house` TRƯỚC ĐÂY tự nâng `User.role` lên
'host' ở tin đầu tiên rồi trả về một JWT mới. Hệ quả trên app: đăng một tin
xong là tài khoản đổi vai — thanh tab đổi, trang cá nhân đổi — mà người dùng
không hề yêu cầu và cũng không được báo. Nó còn trộn hai việc khác hẳn nhau:
ĐĂNG TIN là việc của người bán (mọi tài khoản đăng ký đều là người bán), còn
CHỦ NHÀ là người vận hành căn nhà: hợp đồng, khách thuê, hoá đơn, công tơ.

Kéo theo đó, sửa/xoá/đóng tin không còn đòi vai 'host' nữa — nếu còn đòi thì
người bán đăng được tin rồi lại không sửa nổi tin của chính mình.

Dùng SQLite in-memory + TestClient, theo đúng khuôn `test_houses_transaction_type.py`.
"""

from __future__ import annotations

import os
import uuid
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

import app.models  # noqa: F401 — đăng ký ORM class
from app.auth import sign_token
from app.database import Base, get_db
from app.routers.houses import router as houses_router

SALE_ID = 30  # người bán: role='guest', account_type='sale'
NGUOI_KHAC_ID = 31


@pytest.fixture(scope="module")
def sqlite_engine():
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}
    )
    Base.metadata.create_all(bind=engine)
    yield engine
    engine.dispose()


@pytest.fixture
def db_session(sqlite_engine) -> Generator[Session, None, None]:
    connection = sqlite_engine.connect()
    transaction = connection.begin()
    session = sessionmaker(bind=connection, autoflush=False, autocommit=False)()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(db_session: Session) -> Generator[TestClient, None, None]:
    app = FastAPI()
    app.include_router(houses_router)

    def _override_db() -> Generator[Session, None, None]:
        yield db_session

    app.dependency_overrides[get_db] = _override_db
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


def _auth(uid: int, role: str = "guest") -> dict:
    return {"Authorization": f"Bearer {sign_token(user_id=uid, role=role)}"}


def _tao_nguoi_ban(db: Session, uid: int = SALE_ID) -> None:
    from app.models import User

    if db.get(User, uid):
        return
    db.add(
        User(
            id=uid,
            name="Nguoi Ban",
            email=f"sale_{uid}_{uuid.uuid4().hex[:4]}@test.com",
            password_hash="hashed",
            role="guest",
            account_type="sale",
        )
    )
    db.flush()


def _tao_danh_muc(db: Session) -> int:
    from app.models import Category

    cat = Category(name="Nha pho", icon="home")
    db.add(cat)
    db.flush()
    return cat.id


def _dang_tin(client: TestClient, db: Session, uid: int = SALE_ID) -> dict:
    body = {
        "title": "Nha pho 3 tang Thu Duc",
        "description": "Tin kiem thu",
        "price": 5_000_000,
        "address": "12 Vo Van Ngan",
        "city": "TP Ho Chi Minh",
        "district": "Thu Duc",
        "category_id": _tao_danh_muc(db),
        "host_id": uid,
    }
    return client.post("/api/houses", json=body, headers=_auth(uid))


def test_dang_tin_khong_nang_vai(client: TestClient, db_session: Session):
    """Người bán đăng tin xong vẫn là role='guest'."""
    from app.models import User

    _tao_nguoi_ban(db_session)
    r = _dang_tin(client, db_session)
    assert r.status_code == 201, r.text

    db_session.expire_all()
    assert db_session.get(User, SALE_ID).role == "guest"


def test_dang_tin_khong_tra_ve_token_moi(client: TestClient, db_session: Session):
    """Không đổi vai thì không có JWT mới để đánh tráo phiên."""
    _tao_nguoi_ban(db_session)
    r = _dang_tin(client, db_session)
    assert r.status_code == 201, r.text
    assert "token" not in r.json()


def test_nguoi_ban_sua_duoc_tin_cua_minh(client: TestClient, db_session: Session):
    """role='guest' vẫn phải sửa được tin mình đăng — nếu không thì bỏ nâng vai
    ở bước đăng sẽ khoá luôn người bán ra khỏi tin của chính họ."""
    _tao_nguoi_ban(db_session)
    hid = _dang_tin(client, db_session).json()["house"]["id"]

    r = client.put(
        f"/api/houses/{hid}",
        json={"title": "Nha pho 3 tang — da sua"},
        headers=_auth(SALE_ID),
    )
    assert r.status_code == 200, r.text


def test_nguoi_ban_xoa_duoc_tin_cua_minh(client: TestClient, db_session: Session):
    _tao_nguoi_ban(db_session)
    hid = _dang_tin(client, db_session).json()["house"]["id"]

    r = client.delete(f"/api/houses/{hid}", headers=_auth(SALE_ID))
    assert r.status_code == 200, r.text


def test_nguoi_khac_van_khong_sua_duoc(client: TestClient, db_session: Session):
    """Nới cổng vai KHÔNG được nới quyền: chốt chặn thật là kiểm chủ sở hữu."""
    _tao_nguoi_ban(db_session)
    hid = _dang_tin(client, db_session).json()["house"]["id"]

    r = client.put(
        f"/api/houses/{hid}",
        json={"title": "Cuop tin"},
        headers=_auth(NGUOI_KHAC_ID),
    )
    assert r.status_code == 403, r.text


def test_nguoi_khac_van_khong_xoa_duoc(client: TestClient, db_session: Session):
    _tao_nguoi_ban(db_session)
    hid = _dang_tin(client, db_session).json()["house"]["id"]

    r = client.delete(f"/api/houses/{hid}", headers=_auth(NGUOI_KHAC_ID))
    assert r.status_code == 403, r.text
