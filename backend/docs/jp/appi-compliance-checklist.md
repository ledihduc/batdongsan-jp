# APPI 2022 Compliance Checklist — Ancu365 JP

**Audit Date:** 2026-10-17  
**Scope:** Ancu365 SaaS platform handling tenant & broker personal data  
**Baseline:** P3 MVP features live (renewal, deposit settlement, DSR export, account deletion)

---

## Checklist Format

| # | APPI Article | Requirement | Status | Evidence | Notes |
|---|---|---|---|---|---|
| 1 | Article 2(1) | Personal information definition & scope | ✅ | `app/models.py` User model (name, phone, email, address) | Defined in model; captured at signup |
| 2 | Article 2(3) | Sensitive personal information (要配慮個人情報) handling | ⚠️ | N/A | Not currently collected; future-proofed in schema design |
| 3 | Article 15(1) | Consent required before collecting personal info | ✅ | `app/schemas/tenant.py` TenantConsentRequest; `/api/tenant/signup` endpoint | Checkbox + email confirmation at signup |
| 4 | Article 15(2) | Retain proof of consent | ✅ | `app/models.py` TenantConsent table (consent_given_at, ip_address, user_agent) | Immutable audit log stored in DB |
| 5 | Article 15(3) | Data retention limited to necessary period | ⚠️ | `docs/jp/legal-review-packet.md` section "Retention Period" | Default 2 years post-renewal; cron job removes old records |
| 6 | Article 17(1) | Disclose third parties if sharing data | ✅ | `docs/jp/launch-comms/privacy-policy-draft.md` | Tenants notified that broker (controller) accesses data; no other third parties |
| 7 | Article 27(1) | Implement security measures (encryption, access control) | ✅ | `app/core/security.py` Fernet encryption; `app/core/auth.py` OAuth role-based access | PII encrypted at rest (Fernet); access logs audited |
| 8 | Article 27(1) | Access control limiting authorized users | ✅ | `app/routers/tenant.py` @require_auth; role checks in middleware | Tenant can access own data; broker accesses via OAuth token |
| 9 | Article 27(1) | Secure storage (DB encryption + network) | ✅ | `docs/deploy-runbook.md` section "Database Security" | Postgres with TLS; env secrets in secure vault |
| 10 | Article 31(1) | Individual PII deletion on request | ✅ | `/api/tenant/{id}/delete` endpoint; `app/cron/delete-marked-tenants.py` | Immediate mark as "to_delete"; 30-day cooling-off; auto-delete after |
| 11 | Article 34(1) | Data Subject Rights — Export (DSR) | ✅ | `/api/tenant/{id}/dsr/export` endpoint; returns JSON/PDF of all PII held | Email verification + 2FA before export allowed |
| 12 | Article 34(2) | Data Subject Rights — Correction on request | ⚠️ | `PUT /api/tenant/{id}` endpoint exists; audit log tracks changes | Partial: correction implemented; no formal "correction request" workflow |
| 13 | Article 34(3) | Data Subject Rights — Cease processing (opt-out) | ❌ | Not implemented | Gap: tenants cannot opt-out of processing without deletion; needs UI + endpoint |
| 14 | Article 35 | Breach notification within 72 hours | ⚠️ | `docs/jp/compliance-runbook.md` section "Incident Procedure" | Process drafted; not yet operationalized (no automated alert) |
| 15 | Article 35(2) | Breach notification contents (PPC report template) | ⚠️ | Template in legal review packet; not yet integrated into runbook | Awaiting legal counsel format confirmation |
| 16 | Article 36(1) | Privacy Impact Assessment (PIA) for large-scale processing | ⚠️ | Not yet conducted | Annual PIA review scheduled; template in compliance-runbook.md |
| 17 | Article 38(1) | Designated Data Protection Officer (DPO) — optional | ❌ | Not assigned | [運営会社名: TBD] to designate DPO if required |
| 18 | Article 39(1) | APPI clauses in contracts with brokers | ⚠️ | Broker Terms of Service drafted; not finalized with counsel | Awaiting legal review before signing with first partner |
| 19 | Article 41 | Overseas transfer of personal data | ✅ | Not applicable | All data stored in Japan (Postgres in JP data center) |
| 20 | Article 42(2) | Accurate & up-to-date record keeping | ✅ | `app/models.py` UpdatedAt fields; audit logs in `audit_log` table | All PII records include created_at, updated_at, updated_by |

---

## Status Legend

| Status | Meaning |
|---|---|
| ✅ | Fully implemented & tested; evidence available |
| ⚠️ | Partially implemented or awaiting finalization |
| ❌ | Not implemented; gap identified |

---

## Detailed Gaps & Mitigations

### Gap #2: Sensitive Personal Information (Article 2(3))
- **Issue:** Not currently collected, but framework should be in place for future
- **Mitigation:** Schema already supports separate `sensitive_pii` field with distinct encryption key. When feature added, swap key + require explicit consent.

### Gap #5: Data Retention Policy
- **Issue:** Default 2-year retention is conservative; no formal published schedule
- **Mitigation:** 
  - Publish retention table in privacy policy (tenant, broker, document, audit log)
  - Implement automated retention checks in cron job
  - Test quarterly

### Gap #12: Data Correction Workflow
- **Issue:** Endpoint exists (`PUT /api/tenant/{id}`), but no formal "correction request" form
- **Mitigation:** Add form in help center or settings UI; tenants file formal request → admin verifies → updates record + audit log

### Gap #13: Opt-Out / Cease Processing ❌ PRIORITY
- **Issue:** APPI Article 34(3) allows tenants to request cessation of processing without deletion
- **Implication:** Tenant wants "anonymize my data but don't delete" — currently not supported
- **Mitigation:** 
  - Add `/api/tenant/{id}/anonymize` endpoint (not delete; removes PII, keeps stub for audit)
  - Update UI: offer "Stop using my data" vs. "Delete my account"
  - Test before launch

### Gap #14: Breach Notification
- **Issue:** Process drafted but not operationalized; no automated alerting
- **Mitigation:**
  - Integrate DB breach detection (e.g., alert on suspicious DB access, mass export attempts)
  - Define "major breach" threshold (PPC guidance: affects 1000+ individuals = probably major; <10 = minor)
  - Set up PagerDuty/Slack alert for ops team
  - Run drill quarterly

### Gap #17: DPO Assignment
- **Issue:** Optional under APPI, but if processing large scale, recommended
- **Mitigation:** [運営会社名: TBD] to decide post-legal review; if needed, designate + contact info to regulators

### Gap #18: Broker DPA
- **Issue:** Broker Terms of Service not yet finalized with counsel
- **Mitigation:**
  - Include APPI data processing clauses (controller/processor roles, data security requirements)
  - Broker confirms: data controller role, KYC/AML responsibility, sub-processor approval
  - Finalize before first broker signs up

---

## Quarterly Compliance Review Schedule

### Q1 2026 (Jan–Mar)
- [ ] Legal counsel review of 10 questions (from legal-review-packet.md)
- [ ] Finalize DPA / broker Terms
- [ ] Audit all third-party vendors for APPI compliance

### Q2 2026 (Apr–Jun)
- [ ] Conduct Privacy Impact Assessment (Article 36)
- [ ] Review data retention logs; delete aged records
- [ ] Test breach notification procedure

### Q3 2026 (Jul–Sep)
- [ ] Fernet key rotation (Q3)
- [ ] Audit consent records (7-year retention); archive older ones
- [ ] Update privacy policy with any new findings

### Q4 2026 (Oct–Dec)
- [ ] Annual compliance review (all 20 items in this checklist)
- [ ] Prepare audit report for [運営会社名: TBD] leadership
- [ ] Plan next year's focus areas

---

## Implementation Roadmap (Pre-Launch)

| Priority | Gap | Effort | Deadline |
|---|---|---|---|
| 🔴 P0 | Gap #13: Opt-out endpoint | 3 days | Pre-launch |
| 🟡 P1 | Gap #14: Breach alert automation | 2 days | Pre-launch |
| 🟡 P1 | Gap #18: Broker DPA finalization | Legal review | Pre-launch |
| 🔵 P2 | Gap #5: Publish retention policy | 1 day | Launch day |
| 🔵 P2 | Gap #12: Correction request UI | 2 days | Within 1 week post-launch |
| 🟢 P3 | Gap #17: Designate DPO | 1 day | Within 1 month post-launch |

---

## Audit Trail & Evidence Locations

All evidence links assume running against live Postgres DB. For testing, use staging DB snapshot.

### Data Collection & Consent (Articles 2, 15)
- **Evidence DB:** `ancu_jp_prod.tenant_consent` (records consent event)
- **Evidence Code:** `app/schemas/tenant.py` TenantConsentRequest model
- **Evidence Endpoint:** `POST /api/tenant/signup` captures consent
- **Test:** Create test tenant account; verify consent record inserted with IP/user agent

### Encryption (Article 27)
- **Evidence Code:** `app/core/security.py` FernetCipher class
- **Verify:** Check .env has FERNET_KEY; confirm production key is rotated quarterly
- **Test:** Decrypt sample record from production DB to verify key works

### Deletion & Retention (Articles 31, 35)
- **Evidence Endpoint:** `DELETE /api/tenant/{id}` marks as "to_delete"
- **Evidence Cron:** `app/cron/delete-marked-tenants.py` runs daily; deletes after 30 days
- **Test:** Mark test tenant for deletion; verify 30-day delay + auto-delete after period

### DSR Export (Article 34)
- **Evidence Endpoint:** `GET /api/tenant/{id}/dsr/export` returns JSON + PDF
- **Verify:** Endpoint requires 2FA; response includes all PII held
- **Test:** Request DSR as test tenant; verify completeness and format

### Audit Logging (Article 42)
- **Evidence Table:** `ancu_jp_prod.audit_log` (all PII access + modifications)
- **Fields:** timestamp, user_id, action (read/write/delete), record_id, old_value, new_value
- **Verify:** Query audit_log for any read/write to tenant PII; timestamp should match access time

---

## Pre-Launch Checklist (Product)

Before marking "Launch Ready":

- [ ] All ✅ items have been tested and passed UAT
- [ ] All ⚠️ items have mitigation plan documented
- [ ] All ❌ items prioritized (P0/P1 fixed before launch; P2+ in post-launch roadmap)
- [ ] Legal counsel has reviewed this checklist and signed off
- [ ] Broker partners have signed APPI-compliant Terms of Service
- [ ] Privacy policy published in Japanese
- [ ] Help center articles deployed (see launch-comms/ folder)
- [ ] Incident response team briefed on breach notification 72h window
- [ ] Audit logs tested; production retention verified
- [ ] Encryption key backup tested; restore procedure documented

---

**Document Owner:** Ancu365 Compliance & Legal  
**Last Audit:** 2026-10-17  
**Next Audit:** 2026-12-17 (quarterly) or upon material change
