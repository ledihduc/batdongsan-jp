"""Chứng từ riêng tư: ký URL theo nguồn DB, quyền theo nguồn, lý do, hết hạn,
nhật ký mở, cổng `/uploads`, script chuyển kho."""

from __future__ import annotations

from datetime import datetime

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app import models
from app.domain.operator_business import OperatorBusinessProfile
from app.services import private_uploads, sensitive_file_service
from app.services.admin_v2 import documents as docs
from tests.admin_v2.conftest import app_token

PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 32


@pytest.fixture
def stores(tmp_path, monkeypatch):
    up = tmp_path / "uploads"
    priv = tmp_path / "private"
    sens = tmp_path / "sensitive"
    for d in (up, sens):
        d.mkdir()
    monkeypatch.setattr(docs.settings, "upload_dir", str(up))
    monkeypatch.setenv("PRIVATE_DOCUMENTS_DIR", str(priv))
    monkeypatch.setattr(sensitive_file_service, "_BASE_DIR", sens)
    return {"uploads": up, "private": priv, "sensitive": sens}


def _kyc(db, owner_id: int, stores) -> OperatorBusinessProfile:
    (stores["sensitive"] / "gpkd").mkdir(exist_ok=True)
    (stores["sensitive"] / "gpkd" / "abc.pdf").write_bytes(b"%PDF-1.4 gpkd")
    p = OperatorBusinessProfile(
        user_id=owner_id, business_name="Cty Vận Hành", business_registration_number="0312345678",
        gpkd_document_path="gpkd/abc.pdf", gpkd_issued_at=datetime(2024, 1, 1),
        legal_representative_name="Nguyễn A", legal_representative_phone="0901234567",
        verification_status="pending",
    )
    db.add(p)
    db.commit()
    return p


def _journey(db, customer, owner, urls) -> models.RentalJourney:
    j = models.RentalJourney(appointment_id=next_id(), customer_id=customer.id, owner_id=owner.id,
                             status="CONTRACT_SUBMITTED", contract_urls=urls)
    db.add(j)
    db.commit()
    return j


_n = iter(range(700000, 800000))


def next_id() -> int:
    return next(_n)


def test_compliance_signs_kyc_doc_only_with_reason_and_download_is_logged(client, db, staff, user, stores):
    u, h = staff("COMPLIANCE")
    p = _kyc(db, user().id, stores)
    body = {"source_type": "operator_business_profile", "source_id": str(p.id), "field": "gpkd_document_path"}
    r = client.post("/api/v2/admin/documents/sign", headers=h, json=body)
    assert r.status_code == 422 and r.json()["error"]["code"] == "ADMIN_REASON_REQUIRED"
    r = client.post("/api/v2/admin/documents/sign", headers=h, json={**body, "reason": "đối chiếu GPKD #7"})
    assert r.status_code == 200, r.text
    data = r.json()["data"]
    assert data["url"].startswith("/api/v2/admin/documents/download/") and data["expires_in"] == 300
    assert "gpkd/abc.pdf" not in r.text  # không bao giờ lộ đường dẫn lưu trữ
    sign_log = db.query(models.AdminActionLog).filter_by(action="document.sign", actor_user_id=u.id).one()
    assert sign_log.reason == "đối chiếu GPKD #7"

    d = client.get(data["url"])  # không cần Authorization: token là quyền
    assert d.status_code == 200, d.text
    assert d.content == b"%PDF-1.4 gpkd"
    assert d.headers["cache-control"].startswith("no-store")
    assert d.headers["content-disposition"].startswith("inline")
    assert d.headers["content-type"].startswith("application/pdf")
    opened = db.query(models.AdminActionLog).filter_by(action="document.open", actor_user_id=u.id).one()
    assert opened.reason == "đối chiếu GPKD #7" and opened.entity_id == str(p.id)
    # Kho nhạy cảm tự ghi cccd_access_logs khi đọc.
    assert db.query(models.CCCDAccessLog).filter_by(user_id=u.id, action="read").count() == 1
    # Ảnh lại trong TTL vẫn được (thẻ <img> tải lại).
    assert client.get(data["url"]).status_code == 200


def test_moderator_cannot_sign_rental_or_payment_docs(client, db, staff, user, stores):
    u, h = staff("MODERATOR")
    c, o = user(), user()
    (stores["uploads"] / "hd.jpg").write_bytes(PNG)
    j = _journey(db, c, o, ["/uploads/hd.jpg"])
    pay = models.PlatformPayment(source_type="rental_journey", source_id=j.id, amount=1, external_reference="x",
                                 recorded_by_user_id=o.id, paid_at=datetime(2026, 1, 1),
                                 evidence_urls=["/uploads/hd.jpg"])
    db.add(pay)
    db.commit()
    for body in ({"source_type": "rental_journey", "source_id": str(j.id), "field": "contract_urls"},
                 {"source_type": "platform_payment", "source_id": str(pay.id), "field": "evidence_urls"}):
        r = client.post("/api/v2/admin/documents/sign", headers=h, json=body)
        assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_PERMISSION_DENIED"
    assert db.query(models.AdminActionLog).filter_by(actor_user_id=u.id, action="permission.denied").count() == 2
    # OPS có rental_documents.read → ký được hợp đồng (không cần lý do).
    _, ho = staff("OPS_ADMIN")
    r = client.post("/api/v2/admin/documents/sign", headers=ho,
                    json={"source_type": "rental_journey", "source_id": str(j.id), "field": "contract_urls"})
    assert r.status_code == 200, r.text
    got = client.get(r.json()["data"]["url"])
    assert got.status_code == 200 and got.content == PNG


def test_client_supplied_path_is_impossible(client, db, staff, user, stores):
    _, h = staff("OPS_ADMIN")
    (stores["uploads"] / "ok.jpg").write_bytes(PNG)
    j = _journey(db, user(), user(), ["/uploads/../../etc/passwd", "https://evil.example/x.jpg", "/uploads/ok.jpg"])
    base = {"source_type": "rental_journey", "source_id": str(j.id), "field": "contract_urls"}
    # Trường lạ (path) bị bỏ qua — chỉ giá trị trong hàng DB được dùng.
    r = client.post("/api/v2/admin/documents/sign", headers=h, json={**base, "index": 2, "path": "/etc/passwd"})
    assert r.status_code == 200
    assert client.get(r.json()["data"]["url"]).content == PNG
    # Giá trị DB có `..` hoặc link ngoài → không phải tệp của hệ thống.
    for idx in (0, 1):
        r = client.post("/api/v2/admin/documents/sign", headers=h, json={**base, "index": idx})
        assert r.status_code == 422 and r.json()["error"]["code"] == "ADMIN_DOC_EXTERNAL"
    # Tên trường phải nằm trong danh mục của nguồn.
    r = client.post("/api/v2/admin/documents/sign", headers=h, json={**base, "field": "../../etc/passwd"})
    assert r.status_code == 422 and r.json()["error"]["code"] == "ADMIN_DOC_BAD_FIELD"
    r = client.post("/api/v2/admin/documents/sign", headers=h, json={**base, "index": 9})
    assert r.status_code == 404


def test_expired_and_invalid_tokens_are_rejected(client, db, staff, user, stores, monkeypatch):
    u, h = staff("OPS_ADMIN")
    (stores["uploads"] / "a.jpg").write_bytes(PNG)
    j = _journey(db, user(), user(), ["/uploads/a.jpg"])
    d = docs.resolve(db, "rental_journey", str(j.id), "contract_urls", 0)
    monkeypatch.setattr(docs, "TOKEN_TTL_SECONDS", -5)
    tok, _ = docs.sign_token(actor_id=u.id, audience="admin", doc=d, sign_log_id=None, permission="rental_documents.read")
    r = client.get(f"/api/v2/admin/documents/download/{tok}")
    assert r.status_code == 410 and r.json()["error"]["code"] == "ADMIN_DOC_TOKEN_EXPIRED"
    r = client.get("/api/v2/admin/documents/download/khong-phai-token")
    assert r.status_code == 401
    # Token đăng nhập app KHÔNG dùng làm token chứng từ và ngược lại.
    app_tok = app_token(user())["Authorization"].split()[1]
    assert client.get(f"/api/v2/admin/documents/download/{app_tok}").status_code == 401
    assert db.query(models.AdminActionLog).filter_by(action="document.open").count() == 0


def test_download_rechecks_permission(client, db, staff, user, stores):
    from app.services.admin_v2 import rbac

    u, h = staff("OPS_ADMIN")
    (stores["uploads"] / "b.jpg").write_bytes(PNG)
    j = _journey(db, user(), user(), ["/uploads/b.jpg"])
    r = client.post("/api/v2/admin/documents/sign", headers=h,
                    json={"source_type": "rental_journey", "source_id": str(j.id), "field": "contract_urls"})
    url = r.json()["data"]["url"]
    rbac.revoke_role(db, user_id=u.id, role_code="OPS_ADMIN", revoked_by=u.id, reason="nghỉ")
    db.commit()
    assert client.get(url).status_code == 403


def test_participant_signing_only_own_documents(app_, client, db, user, stores):
    from app.api.routes.admin_v2.documents import public_router

    app_.include_router(public_router)
    customer, owner, stranger = user(), user(), user()
    (stores["uploads"] / "c.jpg").write_bytes(PNG)
    j = _journey(db, customer, owner, ["/uploads/c.jpg"])
    body = {"source_type": "rental_journey", "source_id": str(j.id), "field": "contract_urls"}
    r = client.post("/api/v2/documents/sign", headers=app_token(stranger), json=body)
    assert r.status_code == 404
    r = client.post("/api/v2/documents/sign", headers=app_token(customer), json=body)
    assert r.status_code == 200, r.text
    url = r.json()["data"]["url"]
    assert url.startswith("/api/v2/documents/download/")
    assert client.get(url).content == PNG
    log = db.query(models.AdminActionLog).filter_by(action="document.open", actor_user_id=customer.id).one()
    assert log.permission == "participant"
    assert client.post("/api/v2/documents/sign", json=body).status_code == 401


def _static_app(directory: str) -> TestClient:
    api = FastAPI()
    api.mount("/uploads", private_uploads.GatedUploadsStaticFiles(directory=directory), name="uploads")
    return TestClient(api)


def test_uploads_gate_blocks_registered_names_only_when_enforced(tmp_path, monkeypatch):
    (tmp_path / "secret.jpg").write_bytes(PNG)
    (tmp_path / "public.jpg").write_bytes(PNG)
    monkeypatch.setattr(private_uploads, "loader", lambda: frozenset({"secret.jpg"}))
    private_uploads.reset_cache()
    c = _static_app(str(tmp_path))
    monkeypatch.setattr(docs.settings, "private_uploads_enforced", False, raising=False)
    monkeypatch.delenv("PRIVATE_UPLOADS_ENFORCED", raising=False)
    assert c.get("/uploads/secret.jpg").status_code == 200
    monkeypatch.setattr(docs.settings, "private_uploads_enforced", True, raising=False)
    assert c.get("/uploads/secret.jpg").status_code == 404
    assert c.get("/uploads/public.jpg").status_code == 200
    private_uploads.reset_cache()


def test_uploads_gate_never_crashes_when_table_missing(tmp_path, monkeypatch):
    (tmp_path / "x.jpg").write_bytes(PNG)

    def boom():
        raise RuntimeError("no such table: private_documents")

    monkeypatch.setattr(private_uploads, "loader", boom)
    monkeypatch.setattr(docs.settings, "private_uploads_enforced", True, raising=False)
    private_uploads.reset_cache()
    assert _static_app(str(tmp_path)).get("/uploads/x.jpg").status_code == 200
    private_uploads.reset_cache()


def test_migration_script_registers_copies_and_is_idempotent(client, db, staff, user, stores):
    from scripts.migrate_private_uploads import run

    (stores["uploads"] / "hd1.jpg").write_bytes(PNG)
    j = _journey(db, user(), user(), ["/uploads/hd1.jpg", "/uploads/khong-co.jpg", "https://x.vn/a.jpg"])
    out: list[str] = []
    dry = run(db, apply=False, out=out.append)
    assert dry["rental_journey"]["to_register"] == 1 and dry["rental_journey"]["missing_file"] == 1
    assert db.query(models.PrivateDocument).count() == 0
    run(db, apply=True, out=out.append)
    reg = db.query(models.PrivateDocument).filter_by(legacy_upload_name="hd1.jpg").one()
    assert reg.source_type == "rental_journey" and reg.source_id == str(j.id) and reg.category == "contract"
    assert (stores["private"] / reg.object_key).read_bytes() == PNG
    assert (stores["uploads"] / "hd1.jpg").exists()  # bản gốc giữ nguyên
    again = run(db, apply=True, out=out.append)
    assert again["rental_journey"].get("already_registered") == 1
    assert db.query(models.PrivateDocument).count() == 1
    # Sau khi đăng ký, chứng từ được đọc từ KHO RIÊNG (xoá bản ở /uploads vẫn mở được).
    (stores["uploads"] / "hd1.jpg").unlink()
    _, h = staff("OPS_ADMIN")
    r = client.post("/api/v2/admin/documents/sign", headers=h,
                    json={"source_type": "rental_journey", "source_id": str(j.id), "field": "contract_urls"})
    assert r.status_code == 200, r.text
    assert client.get(r.json()["data"]["url"]).content == PNG
