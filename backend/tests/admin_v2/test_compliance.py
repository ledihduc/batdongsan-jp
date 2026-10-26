"""Tin cậy & pháp lý: KYC, uỷ quyền, tranh chấp, legal hold, chủ sở hữu mất,
retention, nhật ký truy cập."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta

from app import models
from app.domain.bank_account_reveal_log import BankAccountRevealLog
from app.domain.delegation import Delegation
from app.domain.operator_business import OperatorBusinessProfile
from app.domain.owner_death import OwnerDeathCertificate
from app.domain.tenant_authority import TenantAuthorityFlag
from tests.admin_v2.conftest import w

API = "/api/v2/admin/compliance"


def _kyc(db, user_id, status="pending") -> OperatorBusinessProfile:
    p = OperatorBusinessProfile(
        user_id=user_id, business_name="Cty Vận Hành", business_registration_number="0312345678",
        gpkd_document_path="gpkd/x.pdf", gpkd_issued_at=datetime(2024, 1, 1),
        legal_representative_name="Nguyễn A", legal_representative_phone="0901234567",
        verification_status=status,
    )
    db.add(p)
    db.commit()
    return p


def _delegation(db, owner_id, operator_id, status="active", **kw) -> Delegation:
    d = Delegation(
        id=str(uuid.uuid4()), owner_id=owner_id, operator_id=operator_id, status=status,
        role_preset="operator_full", scope_type="all", commission_pct=5,
        threshold_monthly_rent_vnd=1, threshold_term_months=12, threshold_expense_vnd=1,
        threshold_rent_change_pct=1, threshold_refund_vnd=1, **kw,
    )
    db.add(d)
    db.commit()
    return d


def test_kyc_list_detail_and_approve_via_domain_service(client, db, staff, user):
    _, h = staff("COMPLIANCE")
    owner = user()
    p = _kyc(db, owner.id)
    r = client.get(f"{API}/kyc?verification_status=pending", headers=h)
    assert r.status_code == 200, r.text
    row = next(x for x in r.json()["data"] if x["id"] == p.id)
    assert row["ref"] == f"KYC-{p.id:05d}" and row["legal_representative_phone_masked"] != "0901234567"
    detail = client.get(f"{API}/kyc/{p.id}", headers=h).json()["data"]
    assert detail["allowed_actions"]["approve"] is True
    assert {d["field"] for d in detail["documents"]} == {"gpkd_document_path"}
    assert all(d["reason_required"] for d in detail["documents"])
    assert "gpkd/x.pdf" not in str(detail)

    url = f"{API}/kyc/{p.id}/approve"
    assert client.post(url, headers=w(h), json={"reason": "đủ hồ sơ"}).status_code == 428
    assert client.post(url, headers=w(h, detail["version"]), json={"reason": ""}).status_code == 422
    r = client.post(url, headers=w(h, detail["version"]), json={"reason": "đủ hồ sơ GPKD"})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["verification_status"] == "verified"
    db.expire_all()
    assert db.get(models.User, owner.id).is_operator_capable is True
    log = db.query(models.AdminActionLog).filter_by(action="kyc.approve", entity_id=str(p.id)).one()
    assert log.before_json == {"verification_status": "pending"} and log.reason == "đủ hồ sơ GPKD"
    assert db.query(models.AdminEvent).filter_by(event_type="admin.kyc.approve", entity_id=str(p.id)).count() == 1
    # Duyệt lại bằng phiên bản cũ → 409 xung đột.
    r = client.post(url, headers=w(h, detail["version"]), json={"reason": "đủ hồ sơ GPKD"})
    assert r.status_code == 409


def test_kyc_invalid_transition_is_409_and_moderator_is_denied(client, db, staff, user):
    _, h = staff("COMPLIANCE")
    p = _kyc(db, user().id, status="rejected")
    v = client.get(f"{API}/kyc/{p.id}", headers=h).json()["data"]["version"]
    r = client.post(f"{API}/kyc/{p.id}/revoke-gpkd", headers=w(h, v), json={"reason": "giấy phép giả"})
    assert r.status_code == 409 and r.json()["error"]["code"] == "ADMIN_INVALID_STATE"
    _, hm = staff("MODERATOR")
    assert client.get(f"{API}/kyc", headers=hm).status_code == 403
    assert client.get(f"{API}/disputes", headers=hm).status_code == 403


def test_force_revoke_requires_reauth_and_writes_both_logs(client, db, staff, user):
    _, h_noauth = staff("COMPLIANCE", reauth=False)
    _, h = staff("COMPLIANCE")
    d = _delegation(db, user().id, user().id)
    detail = client.get(f"{API}/delegations/{d.id}", headers=h).json()["data"]
    assert detail["allowed_actions"]["force_revoke"] is True and detail["approvals"] == []
    url = f"{API}/delegations/{d.id}/force-revoke"
    r = client.post(url, headers=w(h_noauth, detail["version"]), json={"reason": "lệnh toà án số 12"})
    assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_REAUTH_REQUIRED"
    r = client.post(url, headers=w(h, detail["version"]), json={"reason": "lệnh toà án số 12"})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["status"] == "terminated"
    # ChangeLog của service gốc + nhật ký quản trị V2 cùng transaction.
    assert db.query(models.ChangeLog).filter_by(action="admin_force_revoke", acted_via_delegation_id=d.id).count() == 1
    assert db.query(models.AdminActionLog).filter_by(action="delegation.force_revoke", entity_id=d.id).count() == 1
    trail = client.get(f"{API}/delegations/{d.id}", headers=h).json()["data"]["audit_trail"]
    assert trail[0]["action"] == "admin_force_revoke"


def test_suspend_and_reinstate_operator(client, db, staff, user):
    _, h = staff("COMPLIANCE")
    op = user()
    d1 = _delegation(db, user().id, op.id)
    d2 = _delegation(db, user().id, op.id)
    s = client.get(f"{API}/operators/{op.id}", headers=h).json()["data"]
    assert s["delegations_active"] == 2 and s["allowed_actions"]["suspend"] is True
    r = client.post(f"{API}/operators/{op.id}/suspend", headers=w(h, s["version"]), json={"reason": "điều tra gian lận"})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["delegations_paused"] == 2
    db.expire_all()
    assert {db.get(Delegation, d1.id).paused_reason, db.get(Delegation, d2.id).paused_reason} == {"admin_suspend"}
    s = r.json()["data"]
    r = client.post(f"{API}/operators/{op.id}/reinstate", headers=w(h, s["version"]), json={"reason": "đã xác minh xong"})
    assert r.status_code == 200 and r.json()["data"]["delegations_reinstated"] == 2
    s = r.json()["data"]
    r = client.post(f"{API}/operators/{op.id}/reinstate", headers=w(h, s["version"]), json={"reason": "đã xác minh xong"})
    assert r.status_code == 409


def test_dispute_escalate_resolve_and_legal_hold_blocks_archive(client, db, staff, user):
    _, h = staff("COMPLIANCE")
    op = user()
    d = _delegation(db, user().id, op.id)
    f = TenantAuthorityFlag(tenant_id=1, reported_operator_user_id=op.id, delegation_id=d.id,
                            report_reason="người lạ thu tiền nhà")
    db.add(f)
    db.commit()
    rows = client.get(f"{API}/disputes?status=pending", headers=h).json()["data"]
    row = next(x for x in rows if x["id"] == f.id)
    assert row["legal_hold"] is False and row["sla_due_at"]
    r = client.post(f"{API}/disputes/{f.id}/escalate", headers=w(h, row["version"]), json={"reason": "khách hoảng loạn"})
    assert r.status_code == 200 and r.json()["data"]["status"] == "escalated"
    v = r.json()["data"]["version"]
    r = client.post(f"{API}/disputes/{f.id}/resolve", headers=w(h, v),
                    json={"reason": "có bằng chứng", "outcome": "prima_facie_valid", "action": "pause_delegation"})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["status"] == "valid" and r.json()["data"]["resolution"]["delegation_paused"] is True

    # Legal hold lên uỷ quyền (đã chấm dứt > 30 ngày) → archive bỏ qua.
    dd = _delegation(db, user().id, user().id, status="terminated",
                     terminated_at=datetime.utcnow() - timedelta(days=40))
    free = _delegation(db, user().id, user().id, status="terminated",
                       terminated_at=datetime.utcnow() - timedelta(days=40))
    body = {"source_type": "delegation", "source_id": dd.id, "hold": True, "reason": "đang kiện tụng"}
    assert client.post(f"{API}/legal-holds", headers=w(h), json=body).status_code == 428
    r = client.post(f"{API}/legal-holds", headers=w(h, "0"), json=body)
    assert r.status_code == 200, r.text
    assert r.json()["data"]["legal_hold"] is True and r.json()["data"]["version"] == "1"
    r = client.post(f"{API}/legal-holds", headers=w(h, "1"), json=body)
    assert r.status_code == 409
    holds = client.get(f"{API}/legal-holds", headers=h).json()["data"]
    assert any(c["source_id"] == dd.id for c in holds)

    _, h_noauth = staff("COMPLIANCE", reauth=False)
    r = client.post(f"{API}/retention/archive-delegations", headers=w(h_noauth), json={"reason": "chạy định kỳ"})
    assert r.status_code == 403
    r = client.post(f"{API}/retention/archive-delegations", headers=w(h), json={"reason": "chạy định kỳ"})
    assert r.status_code == 200, r.text
    res = r.json()["data"]
    assert dd.id in res["held_ids"] and free.id in res["archived_ids"]
    db.expire_all()
    assert db.get(Delegation, dd.id).status == "terminated" and db.get(Delegation, free.id).status == "archived"
    st = client.get(f"{API}/retention", headers=h).json()["data"]
    assert st["legal_holds_active"] >= 1 and st["recent_runs"][0]["action"] == "retention.archive_delegations"


def test_owner_death_verify_needs_reauth_and_shows_heir(client, db, staff, user):
    _, h = staff("COMPLIANCE")
    _, h_noauth = staff("COMPLIANCE", reauth=False)
    owner, heir = user(), user()
    _delegation(db, owner.id, user().id)
    c = OwnerDeathCertificate(id=str(uuid.uuid4()), owner_user_id=owner.id, death_certificate_path="death_certs/a.pdf",
                              submitted_by_user_id=heir.id, executor_user_id=heir.id)
    db.add(c)
    db.commit()
    detail = client.get(f"{API}/owner-death/{c.id}", headers=h).json()["data"]
    assert detail["heir"]["user"]["id"] == heir.id
    assert {d["field"] for d in detail["documents"]} == {"death_certificate_path"}
    url = f"{API}/owner-death/{c.id}/verify"
    r = client.post(url, headers=w(h_noauth, detail["version"]), json={"reason": "giấy chứng tử hợp lệ"})
    assert r.status_code == 403
    r = client.post(url, headers=w(h, detail["version"]), json={"reason": "giấy chứng tử hợp lệ"})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["verification_status"] == "verified" and r.json()["data"]["delegations_paused"] == 1
    r = client.post(f"{API}/owner-death/{c.id}/reject", headers=w(h, r.json()["data"]["version"]),
                    json={"reason": "thiếu dấu đỏ của UBND"})
    assert r.status_code == 409


def test_access_logs_merge_sources(client, db, staff, user):
    u, h = staff("COMPLIANCE")
    target = user()
    d = _delegation(db, target.id, user().id)
    db.add(models.CCCDAccessLog(user_id=u.id, file_path="/srv/storage/cccd/abc.jpg", action="read",
                                ip_address="1.2.3.4"))
    db.add(BankAccountRevealLog(owner_user_id=target.id, operator_user_id=d.operator_id, delegation_id=d.id,
                                consent_token="x" * 64, ip_address="1.2.3.4"))
    db.add(models.ContactRevealLog(lead_id=1, contractor_id=2, revealed_by=target.id))
    db.commit()
    r = client.post(f"/api/v2/admin/users/{target.id}/reveal-pii", headers=h, json={"reason": "xác minh khiếu nại"})
    assert r.status_code == 200
    r = client.get(f"{API}/access-logs", headers=h)
    assert r.status_code == 200, r.text
    kinds = {x["kind"] for x in r.json()["data"]}
    assert kinds >= {"cccd", "bank_account", "contact", "admin"}
    assert "1.2.3.4" not in r.text  # IP chỉ dạng băm
    r = client.get(f"{API}/access-logs?user_id={target.id}&kind=admin,bank_account", headers=h)
    data = r.json()["data"]
    assert {x["kind"] for x in data} == {"admin", "bank_account"}
    assert client.get(f"{API}/access-logs?kind=xyz", headers=h).status_code == 422
