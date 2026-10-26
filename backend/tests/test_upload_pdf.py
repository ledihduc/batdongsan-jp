"""Upload PDF file thiết kế (Đợt 2 profile uy tín).

Bất biến chính: chỉ nhận PDF THẬT (magic bytes %PDF-), chặn đổi đuôi để nhét
file lạ vào ổ đĩa dưới danh nghĩa "file thiết kế".
"""

from __future__ import annotations

import base64
import os

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.auth import sign_token
from app.routers.upload import router as upload_router


@pytest.fixture
def client(tmp_path, monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, "upload_dir", str(tmp_path))
    app = FastAPI()
    app.include_router(upload_router)
    return TestClient(app)


def _b64(raw: bytes) -> str:
    return base64.b64encode(raw).decode()


def _tok(uid: int = 1) -> dict:
    return {"Authorization": f"Bearer {sign_token(uid, 'host')}"}


def test_pdf_that_duoc_chap_nhan(client):
    pdf = b"%PDF-1.7\n...noi dung ban ve..."
    r = client.post("/api/upload",
                    headers=_tok(),
                    json={"data": _b64(pdf), "filename": "banve.pdf"})
    assert r.status_code == 201
    assert r.json()["url"].endswith(".pdf")


def test_doi_duoi_pdf_nhung_KHONG_phai_pdf_bi_chan(client):
    # File thực chất là text/HTML đổi đuôi .pdf → magic bytes sai → chặn.
    fake = b"<html>not a pdf</html>"
    r = client.post("/api/upload",
                    headers=_tok(),
                    json={"data": _b64(fake), "filename": "gia.pdf"})
    assert r.status_code == 400


def test_pdf_qua_lon_bi_chan(client):
    # >27MB base64 → 413.
    big = _b64(b"%PDF-" + b"0" * (28 * 1024 * 1024))
    r = client.post("/api/upload",
                    headers=_tok(),
                    json={"data": big, "filename": "to.pdf"})
    assert r.status_code == 413


def test_upload_bat_buoc_dang_nhap(client):
    r = client.post("/api/upload",
                    json={"data": _b64(b"%PDF-1.7"), "filename": "x.pdf"})
    assert r.status_code in (401, 403)
