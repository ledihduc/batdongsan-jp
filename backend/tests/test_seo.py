"""Trang dựng sẵn cho công cụ tìm kiếm.

Vì sao có: app Flutter web dùng CanvasKit nên bot chỉ thấy tài liệu rỗng. Các
test dưới đây giữ cho trang HTML thật sự CHỨA nội dung (tiêu đề, giá, địa chỉ)
— nếu ai đó lỡ biến chúng thành vỏ rỗng như app, test sẽ đỏ.

Hai bất biến dễ mất nhất:
 1. Tin CHƯA published không được lộ ra ngoài.
 2. URL chuẩn (canonical) phải đúng giao thức đang phục vụ, nếu không công cụ
    tìm kiếm coi http và https là hai trang trùng nội dung.
"""

from __future__ import annotations

import os
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

import app.models  # noqa: F401 — đăng ký lớp ORM
from app import models
from app.database import Base, get_db
from app.routers import seo


@pytest.fixture(scope="module")
def sqlite_engine():
    eng = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}
    )
    Base.metadata.create_all(bind=eng)
    yield eng
    eng.dispose()


@pytest.fixture
def db(sqlite_engine) -> Generator[Session, None, None]:
    conn = sqlite_engine.connect()
    tx = conn.begin()
    s = sessionmaker(bind=conn, autoflush=False, autocommit=False)()
    yield s
    s.close()
    tx.rollback()
    conn.close()


@pytest.fixture
def client(db) -> TestClient:
    app = FastAPI()
    app.include_router(seo.router)

    # PHẢI là hàm generator — `lambda: iter([db])` khiến FastAPI coi đây là
    # dependency thường và truyền vào một iterator thay vì Session.
    def _get_db():
        yield db

    app.dependency_overrides[get_db] = _get_db
    return TestClient(app)


@pytest.fixture
def house(db) -> models.House:
    h = models.House(
        host_id=1,
        title="Nhà 2PN Quận 7 full nội thất",
        description="Căn hộ sáng, ban công hướng Đông Nam.",
        category_id=1,
        price=8_500_000,
        area=65,
        address="12 Nguyễn Văn Linh",
        district="Quận 7",
        city="TP Hồ Chí Minh",
        bedrooms=2,
        bathrooms=2,
        status="published",
        transaction_type="rent",
        images=["/uploads/a.jpg"],
    )
    db.add(h)
    db.commit()
    db.refresh(h)
    return h


class TestSlug:
    @pytest.mark.parametrize(
        "vao,ra",
        [
            ("Nhà 2PN Quận 7", "nha-2pn-quan-7"),
            ("Căn hộ Đống Đa", "can-ho-dong-da"),
            ("Phòng trọ  --  giá rẻ", "phong-tro-gia-re"),
            ("", "tin"),
            ("!!!", "tin"),
        ],
    )
    def test_bo_dau_va_ky_tu_la(self, vao, ra):
        assert seo.slugify(vao) == ra

    def test_cat_ngan_url_qua_dai(self):
        assert len(seo.slugify("nhà " * 200)) <= 80


class TestDinhDangTien:
    @pytest.mark.parametrize(
        "vao,ra",
        [
            (3_500_000, "3,5 triệu"),
            (5_000_000, "5 triệu"),
            (2_000_000_000, "2 tỷ"),
            (1_200_000_000, "1,2 tỷ"),
            (500_000, "500.000 đ"),
        ],
    )
    def test_doc_duoc_kieu_viet(self, vao, ra):
        assert seo._tien(vao) == ra


class TestTrangTin:
    def test_trang_chua_NOI_DUNG_THAT_khong_phai_vo_rong(self, client, house):
        # Đây là lý do tồn tại của cả tệp này.
        r = client.get(f"/tin/{house.id}-x")
        body = r.text
        assert house.title in body, "thiếu tiêu đề → bot không hiểu trang nói gì"
        assert "triệu" in body or "tỷ" in body or "đ" in body, "thiếu giá"
        assert "<h1" in body

    def test_co_the_meta_description(self, client, house):
        r = client.get(f"/tin/{house.id}-{seo.slugify(house.title)}")
        assert '<meta name="description"' in r.text

    def test_co_du_lieu_co_cau_schema_org(self, client, house):
        r = client.get(f"/tin/{house.id}-{seo.slugify(house.title)}")
        assert 'application/ld+json' in r.text
        assert '"@type": "Residence"' in r.text

    def test_canonical_dung_giao_thuc_dang_phuc_vu(self, client, house):
        # NPM đặt X-Forwarded-Proto; canonical phải theo nó, không theo hằng số
        # APP_BASE_URL (đang là http trong khi site chạy https).
        r = client.get(
            f"/tin/{house.id}-{seo.slugify(house.title)}",
            headers={"X-Forwarded-Proto": "https", "Host": "ancu365.vn"},
        )
        assert '<link rel="canonical" href="https://ancu365.vn/tin/' in r.text

    def test_slug_sai_thi_chuyen_huong_ve_url_chuan(self, client, house):
        # Gom sức mạnh liên kết về một địa chỉ duy nhất.
        r = client.get(f"/tin/{house.id}-slug-cu-sai", follow_redirects=False)
        assert r.status_code == 301
        assert r.headers["location"] == f"/tin/{house.id}-{seo.slugify(house.title)}"

    def test_id_khong_ton_tai_tra_404(self, client):
        r = client.get("/tin/999999-abc")
        assert r.status_code == 404

    def test_slug_khong_co_so_tra_404(self, client):
        r = client.get("/tin/khong-co-so")
        assert r.status_code == 404

    def test_trang_404_co_noindex(self, client):
        # Không để bot giữ trang chết trong chỉ mục.
        r = client.get("/tin/999999-abc")
        assert 'content="noindex' in r.text

    def test_TIN_CHUA_DUYET_KHONG_LO_RA_NGOAI(self, client, house, db):
        # Bất biến an toàn quan trọng nhất tệp này.
        for trang_thai in ("draft", "pending", "rejected", "hidden"):
            house.status = trang_thai
            db.commit()
            r = client.get(f"/tin/{house.id}-x")
            assert r.status_code == 404, f"tin '{trang_thai}' bị lộ ra ngoài"
            assert house.title not in r.text


class TestMucLuc:
    def test_liet_ke_tin_da_dang(self, client, house):
        r = client.get("/tin")
        assert r.status_code == 200
        assert house.title in r.text
        assert f"/tin/{house.id}-" in r.text

    def test_khong_liet_ke_tin_chua_duyet(self, client, house, db):
        house.status = "pending"
        db.commit()
        r = client.get("/tin")
        assert house.title not in r.text


class TestSitemap:
    def test_la_xml_hop_le_va_co_tin(self, client, house):
        r = client.get("/sitemap.xml")
        assert r.status_code == 200
        assert "xml" in r.headers["content-type"]
        assert "<urlset" in r.text
        assert f"/tin/{house.id}-" in r.text

    def test_dung_host_cua_request(self, client, house):
        r = client.get(
            "/sitemap.xml", headers={"X-Forwarded-Proto": "https", "Host": "ancu365.vn"}
        )
        assert "https://ancu365.vn/tin/" in r.text

    def test_khong_liet_ke_tin_chua_duyet(self, client, house, db):
        house.status = "draft"
        db.commit()
        assert f"/tin/{house.id}-" not in client.get("/sitemap.xml").text


class TestRobots:
    def test_cho_bo_trang_cong_khai_chan_vung_rieng(self, client):
        t = client.get("/robots.txt").text
        assert "Allow: /" in t
        for cam in ("/api/", "/admin", "/uploads/"):
            assert f"Disallow: {cam}" in t

    def test_tro_toi_sitemap(self, client):
        assert "Sitemap:" in client.get("/robots.txt").text
        assert "/sitemap.xml" in client.get("/robots.txt").text
