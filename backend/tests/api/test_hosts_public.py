"""Integration test cho /api/hosts/featured + /api/hosts/{id} (hồ sơ CÔNG KHAI).

Trọng tâm là chỗ nguy hiểm nhất của một endpoint public về NGƯỜI: rò rỉ PII.
`GET /api/users` là admin-only vì trả email/SĐT; hai endpoint mới này ai cũng
gọi được nên phải chứng minh chúng KHÔNG trả những trường đó.

Ngoài ra canh luật lọt danh sách: chưa có tin đăng nào thì không được trưng ra.
"""

from __future__ import annotations

import os
import shutil
import uuid
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

import app.models as models  # noqa: F401
from app.database import Base, get_db
from app.routers import hosts_public
from app.routers.hosts_public import router as hosts_router

TRUSTED_ID, PLAIN_ID, NO_LISTING_ID, GUEST_ID, INACTIVE_ID = (
    810001, 810002, 810003, 810004, 810005,
)


@pytest.fixture(scope="module")
def db_template(tmp_path_factory) -> str:
    path = str(tmp_path_factory.mktemp("tpl") / "t.db")
    e = create_engine(f"sqlite:///{path}")
    Base.metadata.create_all(bind=e)
    e.dispose()
    return path


@pytest.fixture
def db(tmp_path, db_template) -> Generator[Session, None, None]:
    target = tmp_path / "test.db"
    shutil.copyfile(db_template, target)
    engine = create_engine(
        f"sqlite:///{target}", connect_args={"check_same_thread": False}
    )
    s = sessionmaker(bind=engine, autoflush=False)()
    yield s
    s.close()
    engine.dispose()


@pytest.fixture(autouse=True)
def _clear_featured_cache():
    """Cache danh sách tiêu biểu sống ở module → rò rỉ giữa các test (test này
    seed DB khác test kia mà vẫn nhận kết quả cũ). Dọn trước+sau mỗi test."""
    hosts_public._featured_cache.clear()
    yield
    hosts_public._featured_cache.clear()


@pytest.fixture
def client(db) -> Generator[TestClient, None, None]:
    app = FastAPI()
    app.include_router(hosts_router)

    def _override_db():
        yield db

    app.dependency_overrides[get_db] = _override_db
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


@pytest.fixture
def seed(db):
    """5 nhân vật: host tin cậy · host thường · host chưa có tin · khách · host khoá."""
    people = [
        (TRUSTED_ID, "host", True),
        (PLAIN_ID, "host", True),
        (NO_LISTING_ID, "host", True),
        (GUEST_ID, "guest", True),
        (INACTIVE_ID, "host", False),
    ]
    for uid, role, active in people:
        db.add(models.User(
            id=uid, name=f"U{uid}", email=f"u{uid}_{uuid.uuid4().hex[:4]}@t.com",
            phone=f"09{uid:08d}"[:11], password_hash="x", role=role,
            is_active=active,
        ))
    # Điểm: TRUSTED đủ ngưỡng "chủ nhà tin cậy" — verified + ≥4.8 + ≥5 đánh giá
    # ĐÃ KIỂM. Từ migration 0087, ngưỡng đếm `verified_review_count` chứ không
    # phải `review_count`: đánh giá không chứng minh được quan hệ thật thì
    # không được cộng vào uy tín.
    db.add(models.HostProfile(
        user_id=TRUSTED_ID, verified=True, rating=4.9, review_count=8,
        verified_review_count=8,
    ))
    db.add(models.HostProfile(
        user_id=PLAIN_ID, verified=False, rating=4.0, review_count=2,
    ))
    for uid in (TRUSTED_ID, PLAIN_ID, GUEST_ID, INACTIVE_ID):
        db.add(models.House(
            host_id=uid, title=f"Nhà {uid}", description="d", address="a",
            district="q1", city="hcm", price=1000000, category_id=1,
            status="published",
        ))
    db.commit()


class TestDanhSachTieuBieu:
    def test_chi_hien_host_co_tin_dang(self, client, seed):
        ids = [h["id"] for h in client.get("/api/hosts/featured").json()["hosts"]]
        assert TRUSTED_ID in ids and PLAIN_ID in ids
        # Chưa đăng tin nào → trưng ra chỉ tổ dẫn tới hồ sơ rỗng.
        assert NO_LISTING_ID not in ids
        # Khách thường và tài khoản bị khoá không phải "môi giới".
        assert GUEST_ID not in ids
        assert INACTIVE_ID not in ids

    def test_host_tin_cay_xep_truoc(self, client, seed):
        hosts = client.get("/api/hosts/featured").json()["hosts"]
        assert hosts[0]["id"] == TRUSTED_ID
        assert hosts[0]["trusted"] is True
        assert hosts[0]["listing_count"] == 1

    def test_limit_bi_kep(self, client, seed):
        assert len(client.get("/api/hosts/featured?limit=1").json()["hosts"]) == 1
        # Xin 999 cũng chỉ trả tối đa 50 — không cho quét cả bảng user.
        assert client.get("/api/hosts/featured?limit=999").status_code == 200


class TestDanhBaSale:
    def _sale(self, db, uid: int, *, email: str, active: bool = True):
        db.add(models.User(
            id=uid, name=f"Sale {uid}", email=email, password_hash="x",
            role="guest", account_type="sale", is_active=active,
        ))
        db.add(models.SaleProfile(
            user_id=uid, sale_code=f"SL-{uid}", display_name=f"Tư vấn {uid}",
            service_areas=["Ba Đình", "Cầu Giấy"], verified=True,
        ))
        db.commit()

    def test_sale_khong_co_tin_van_xuat_hien(self, client, db):
        self._sale(db, 820001, email="sale.hot@example.com")
        body = client.get("/api/hosts/sales").json()
        assert body["total"] == 1
        assert body["sales"][0]["id"] == 820001
        assert body["sales"][0]["listing_count"] == 0
        assert body["sales"][0]["service_areas"] == ["Ba Đình", "Cầu Giấy"]

    def test_tim_email_chinh_xac_khong_tra_email_ra_ngoai(self, client, db):
        self._sale(db, 820002, email="Sale@Example.com")
        found = client.get("/api/hosts/sales?q=sale@example.com").json()["sales"]
        assert [item["id"] for item in found] == [820002]
        assert "email" not in found[0]
        assert client.get("/api/hosts/sales?q=sale@exam").json()["sales"] == []

    def test_tim_theo_ten_va_an_sale_bi_khoa(self, client, db):
        self._sale(db, 820003, email="active@example.com")
        self._sale(db, 820004, email="locked@example.com", active=False)
        found = client.get("/api/hosts/sales?q=820003").json()["sales"]
        assert [item["id"] for item in found] == [820003]
        all_ids = [x["id"] for x in client.get("/api/hosts/sales").json()["sales"]]
        assert 820004 not in all_ids


class TestCacheDanhSach:
    def test_lan_hai_khong_dung_lai_DB(self, client, db, seed):
        """Trong TTL, thêm host mới cũng chưa hiện — đó là ĐÁNH ĐỔI có chủ ý
        (danh sách công khai, không cá nhân hoá, đổi rất chậm)."""
        first = client.get("/api/hosts/featured").json()["hosts"]
        db.add(models.House(
            host_id=NO_LISTING_ID, title="Nhà mới", description="d", address="a",
            district="q3", city="hcm", price=1, category_id=1,
            status="published",
        ))
        db.commit()
        second = client.get("/api/hosts/featured").json()["hosts"]
        assert [h["id"] for h in second] == [h["id"] for h in first]

        # Hết TTL (mô phỏng bằng cách dọn cache) → thấy ngay người mới.
        hosts_public._featured_cache.clear()
        third = client.get("/api/hosts/featured").json()["hosts"]
        assert NO_LISTING_ID in [h["id"] for h in third]

    def test_cache_tach_theo_limit(self, client, seed):
        assert len(client.get("/api/hosts/featured?limit=1").json()["hosts"]) == 1
        assert len(client.get("/api/hosts/featured?limit=2").json()["hosts"]) == 2


class TestKhongRoPII:
    """Endpoint public → tuyệt đối không có email/SĐT/ngân hàng/CCCD."""

    _CAM = ("email", "phone", "password_hash", "cccd_number_hash",
            "bank_account_number", "tax_id", "id_number")

    def test_danh_sach_khong_co_pii(self, client, seed):
        for h in client.get("/api/hosts/featured").json()["hosts"]:
            for k in self._CAM:
                assert k not in h, f"rò rỉ {k}"

    def test_ho_so_khong_co_pii(self, client, seed):
        body = client.get(f"/api/hosts/{TRUSTED_ID}").json()
        for k in self._CAM:
            assert k not in body, f"rò rỉ {k}"
        assert body["name"] == f"U{TRUSTED_ID}"


class TestSoLieuHoSo:
    def test_dem_khu_vuc_theo_quan_huyen(self, client, db, seed):
        """Địa bàn = số quận/huyện KHÁC NHAU, không phải số tin."""
        db.add(models.House(
            host_id=TRUSTED_ID, title="Nhà 2", description="d", address="a",
            district="q7", city="hcm", price=1, category_id=1,
            status="published",
        ))
        db.add(models.House(
            host_id=TRUSTED_ID, title="Nhà 3", description="d", address="a",
            district="q1", city="hcm", price=1, category_id=1,
            status="published",
        ))
        db.commit()
        body = client.get(f"/api/hosts/{TRUSTED_ID}").json()
        assert body["listing_count"] == 3
        assert body["area_count"] == 2  # q1 + q7


class TestNhanXetGopTheoNguoi:
    def test_gop_review_cua_moi_tin(self, client, db, seed):
        house = db.query(models.House).filter(
            models.House.host_id == TRUSTED_ID).first()
        db.add(models.Review(house_id=house.id, user_id=PLAIN_ID, rating=5,
                             comment="Tốt"))
        db.commit()
        rv = client.get(f"/api/hosts/{TRUSTED_ID}/reviews").json()["reviews"]
        assert len(rv) == 1
        assert rv[0]["rating"] == 5
        assert rv[0]["house_title"] == house.title
        assert rv[0]["user_name"] == f"U{PLAIN_ID}"

    def test_khong_co_review_tra_rong(self, client, seed):
        assert client.get(f"/api/hosts/{PLAIN_ID}/reviews").json()["reviews"] == []


class TestHoSoMotNguoi:
    def test_khach_thuong_VAN_co_ho_so(self, client, seed):
        """Tài khoản `role='guest'` VẪN có trang công khai.

        Test cũ ở đây khẳng định 404 và đã đỏ suốt — nó thuộc mô hình cũ, khi
        trang công khai bị gác bằng `role`. Nay "sale và guest là MỘT": ai đăng
        ký cũng là người bán và cũng có trang riêng để gửi cho khách. Chặn bằng
        `role` chính là lỗi gặp thật khi seed tài khoản sale đầu tiên
        (05/09/2026) — xem `TestSaleLaTaiKhoanThuong` bên dưới, nơi khẳng định
        điều ngược lại. Hai test cùng file mà nói ngược nhau thì cái nào cũng
        hết giá trị canh gác, nên bỏ hẳn cái sai.

        Ẩn hồ sơ vẫn có nghĩa với tài khoản BỊ KHOÁ và id không tồn tại — hai
        test ngay dưới giữ phần đó.
        """
        assert client.get(f"/api/hosts/{GUEST_ID}").status_code == 200

    def test_tai_khoan_khoa_tra_404(self, client, seed):
        assert client.get(f"/api/hosts/{INACTIVE_ID}").status_code == 404

    def test_khong_ton_tai_tra_404(self, client, seed):
        assert client.get("/api/hosts/99999999").status_code == 404

    def test_host_chua_co_tin_van_xem_duoc_ho_so(self, client, seed):
        """Không lọt danh sách tiêu biểu ≠ không có hồ sơ."""
        body = client.get(f"/api/hosts/{NO_LISTING_ID}").json()
        assert body["listing_count"] == 0
        assert body["trusted"] is False


class TestSaleLaTaiKhoanThuong:
    """Sale có `role='guest'` theo thiết kế (spec: "user bthg chính là sale").

    Chặn trang công khai bằng `role` thì `/sale/:id` của chính họ trả 404 — lỗi
    gặp thật khi seed tài khoản sale đầu tiên, 05/09/2026.
    """

    def test_sale_role_guest_van_co_trang_cong_khai(self, client, db):
        import uuid

        u = models.User(
            name="Sale Vinh",
            email=f"s_{uuid.uuid4().hex[:6]}@t.com",
            phone="0912345678",
            password_hash="x",
            role="guest",
            account_type="sale",
            is_active=True,
        )
        db.add(u)
        db.commit()
        r = client.get(f"/api/hosts/{u.id}")
        assert r.status_code == 200, r.text
        assert r.json()["name"] == "Sale Vinh"

    def test_tai_khoan_cu_customer_van_co_trang_sale(self, client, db):
        import uuid

        u = models.User(
            name="Khách",
            email=f"k_{uuid.uuid4().hex[:6]}@t.com",
            phone="0900000000",
            password_hash="x",
            role="guest",
            account_type="customer",
            is_active=True,
        )
        db.add(u)
        db.commit()
        r = client.get(f"/api/hosts/{u.id}")
        assert r.status_code == 200, r.text
        assert r.json()["name"] == "Khách"


class TestSoDienThoaiCongKhai:
    """Bất biến của repo: SĐT không ra endpoint công khai.

    Migration 0088 mở một lối CÓ CHỦ Ý (`show_phone`), mặc định TẮT. Bộ test
    này giữ cho cái mặc định đó không bị lật vì một lần sửa vô ý.
    """

    def _ho_so(self, db, *, show_phone: bool, zalo=None, facebook=None):
        import uuid

        u = models.User(
            name="Người bán",
            email=f"p_{uuid.uuid4().hex[:6]}@t.com",
            phone="0912345678",
            password_hash="x",
            role="host",
            is_active=True,
        )
        db.add(u)
        db.flush()
        db.add(
            models.HostProfile(
                user_id=u.id,
                show_phone=show_phone,
                zalo=zalo,
                facebook=facebook,
            )
        )
        db.commit()
        return u

    def test_mac_dinh_KHONG_lo_so(self, client, db):
        u = self._ho_so(db, show_phone=False)
        r = client.get(f"/api/hosts/{u.id}")
        # Khoá phải VẮNG MẶT chứ không phải `null` — khoá vắng mặt thì không có
        # cách nào rò.
        assert "phone" not in r.json()
        # Kiểm cả CHUỖI THÔ: số không được lọt ra qua bất kỳ khoá nào khác.
        assert "0912345678" not in r.text

    def test_bat_len_thi_tra_so(self, client, db):
        u = self._ho_so(
            db,
            show_phone=True,
            zalo="0912345678",
            facebook="https://www.facebook.com/vuanha.sale",
        )
        d = client.get(f"/api/hosts/{u.id}").json()
        assert d["phone"] == "0912345678"
        assert d["zalo"] == "0912345678"
        assert d["facebook"] == "https://www.facebook.com/vuanha.sale"

    def test_chua_co_ho_so_thi_khong_no(self, client, db):
        import uuid

        u = models.User(
            name="Chưa hồ sơ",
            email=f"n_{uuid.uuid4().hex[:6]}@t.com",
            phone="0900000001",
            password_hash="x",
            role="host",
            is_active=True,
        )
        db.add(u)
        db.commit()
        d = client.get(f"/api/hosts/{u.id}").json()
        assert "phone" not in d and "zalo" not in d and "facebook" not in d


class TestDangPhanPhoi:
    """Dòng "Đang phân phối" SUY TỪ dự án sale quản lý, không tự khai.

    Cột `agency` (mig 0089) là ô chữ tự do — ai cũng gõ được "CBRE". Dòng này
    nằm ngay cạnh tick xanh nên khách đọc thành "đã xác minh"; vì thế nó phải
    dựa trên bản ghi thật.
    """

    def _sale_co_du_an(self, db, *, cong_khai: bool):
        import uuid

        s = models.User(
            name="Sale",
            email=f"d_{uuid.uuid4().hex[:6]}@t.com",
            phone="0912345678",
            password_hash="x",
            role="guest",
            account_type="sale",
            is_active=True,
        )
        chu = models.User(
            name="Chủ",
            email=f"c_{uuid.uuid4().hex[:6]}@t.com",
            phone="0909999999",
            password_hash="x",
            role="host",
            is_active=True,
        )
        db.add_all([s, chu])
        db.flush()
        b = models.Building(
            host_id=chu.id, name="Toà S1 — Vinhomes", is_public=cong_khai
        )
        db.add(b)
        db.flush()
        db.add(
            models.Room(
                building_id=b.id,
                code="S1-01",
                owner_id=chu.id,
                managed_by_sale_id=s.id,
            )
        )
        db.commit()
        return s

    def test_quan_ly_du_an_cong_khai_thi_hien(self, client, db):
        s = self._sale_co_du_an(db, cong_khai=True)
        d = client.get(f"/api/hosts/{s.id}").json()
        assert d["distributing"] == ["Toà S1 — Vinhomes"]

    def test_du_an_tat_cong_khai_thi_KHONG_hien(self, client, db):
        """Dự án đang ẩn là việc nội bộ sale ↔ chủ nhà, không phải thành tích."""
        s = self._sale_co_du_an(db, cong_khai=False)
        assert "distributing" not in client.get(f"/api/hosts/{s.id}").json()

    def test_khong_quan_ly_du_an_nao_thi_vang_khoa(self, client, db):
        import uuid

        u = models.User(
            name="Sale mới",
            email=f"m_{uuid.uuid4().hex[:6]}@t.com",
            phone="0911111111",
            password_hash="x",
            role="guest",
            account_type="sale",
            is_active=True,
        )
        db.add(u)
        db.commit()
        assert "distributing" not in client.get(f"/api/hosts/{u.id}").json()
