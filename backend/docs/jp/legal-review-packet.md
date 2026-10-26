# Legal Review Packet — Ancu365 JP Launch

**Prepared for:** 弁護士/宅建士 Legal Review  
**Date:** 2026-10-17  
**Status:** Draft — Awaiting counsel feedback

---

## Executive Summary

Ancu365 is a **B2B SaaS platform** for licensed Japanese real estate brokers (宅建業者). We provide digital infrastructure for rental transaction management (更新・敷金精算・入居者マッチング). 

**Key point:** We do NOT hold a 宅建業免許 (real estate broker license). Our customers hold it. We are a technology service provider (情報通信業).

---

## Business Model Overview

### What We Do (Our Scope)
1. **Platform as a Service:** Brokers use Ancu365 to manage their rental operations
   - Tenant applications (入居希望者情報)
   - Renewal management (更新請求・書類処理)
   - Deposit settlement (敷金精算計算・DSR export)
   - Document storage & DSR-compliant export
   - Account management for tenants

2. **Data Processor:** We hold and process tenant PII under APPI 2022
   - Tenant name, phone, address, emergency contact
   - Payment history (decision: store or delete — TBD)
   - Document snapshots (application forms, ID copies)

3. **Non-Broker Activities:**
   - We do NOT take 仲介手数料 (brokerage fees)
   - We do NOT negotiate lease terms
   - We do NOT hold deposits (敷金保管)
   - We do NOT conduct KYC/AML on tenants (broker's responsibility)
   - We do NOT provide legal advice

### What Our Customers Do (Their Scope)
- Licensed brokers (宅建業者) operate on the platform
- They negotiate leases, collect fees, manage DSR
- They are the 個人情報取扱事業者 (data controller) for tenant data
- They are liable for 業として obligations

---

## Data Classification & Flow Diagrams

### Data Categories Ancu365 Handles

#### 1. Personal Information (個人情報) — APPI Category
- **Tenant Data:** Name, phone, email, address, date of birth
- **Broker Data:** Business license number (宅建免許番号), business name, registered address
- **Owner Data:** Account name, contact info (minimal)
- **Co-Tenant Data:** Emergency contacts, guarantor name/phone

**Our Handling:** Encrypted at rest (Fernet). Accessible only to:
- The broker operator account (OAuth via platform)
- Tenant via DSR export (30-day retention, then deleted)
- Admin support (via audit-logged dashboard, not direct DB access)

#### 2. Sensitive Personal Information (要配慮個人情報) — APPI Article 2(3)
- **Examples in our platform:** None currently collected
- **Potential future collection:** Disability status (for accessible housing), medical conditions (guarantor evaluation)
- **If added:** Explicit consent + separate encryption key + access logs

#### 3. Anonymized Data (匿名加工情報)
- Aggregated renewal statistics (e.g., "50 renewals processed Q3")
- Property type distribution (e.g., "30% 1LDK, 50% 2LDK")
- No individual tenant ID linkage

#### 4. Pseudo-Anonymous Data (仮名加工情報)
- Not currently used. If needed for analytics: separate encryption key + mapping table under broker control.

### Data Flow Diagram (Text)

```
TENANT SIGNUP:
┌─────────────────────────────────────────────────────────────┐
│ 1. Tenant visits broker's Ancu365 onboarding link           │
│ 2. Enters: name, phone, email, address, ID upload           │
│ 3. Consent capture (APPI 2022 Article 15): "Your data will   │
│    be used to process your rental application & renewal."    │
│ 4. Data encrypted → database (Fernet key in env)            │
│ 5. Broker receives notification (not PII in email)          │
└─────────────────────────────────────────────────────────────┘

DATA RETENTION & DELETION:
┌─────────────────────────────────────────────────────────────┐
│ 1. After rental ends: Broker marks "renewal declined"       │
│ 2. Tenant data → "deletion pending" (not immediate)         │
│ 3. 30-day cooling-off period (allow restore request)        │
│ 4. Day 31: Cron job runs /cron/delete-marked-tenants        │
│ 5. All PII erased. Only anonymized stats remain.            │
│ 6. Audit log: timestamp + action (no PII logged)            │
└─────────────────────────────────────────────────────────────┘

DSR EXPORT (APPI Article 34):
┌─────────────────────────────────────────────────────────────┐
│ 1. Tenant requests: "Export my data" (DSR endpoint)         │
│ 2. System verifies tenant identity (email + SMS code)       │
│ 3. Query all PII: name, phone, address, documents, events   │
│ 4. Generate PDF: structured, human-readable                 │
│ 5. Serve download (30-day retention post-export)            │
│ 6. Track: who exported, when, what content (audit log)      │
└─────────────────────────────────────────────────────────────┘

BROKER ACCOUNT DELETION:
┌─────────────────────────────────────────────────────────────┐
│ 1. Broker requests deletion of their company account        │
│ 2. System marks account "deletion pending" (30-day period)  │
│ 3. Day 31: All associated tenant data → marked for delete   │
│ 4. Tenant data deletion proceeds as above                   │
│ 5. Broker operator can restore within 30 days               │
└─────────────────────────────────────────────────────────────┘
```

---

## APPI 2022 Classification Matrix

| Requirement | Data Type | Our Handling | APPI Article |
|---|---|---|---|
| Personal Info Definition | Name, phone, email, address, DOB | Collected at signup | Article 2(1) |
| Sensitive Personal Info | None currently collected | If added: explicit consent + separate key | Article 2(3) |
| Purpose Limitation | Rental transaction processing only | Stated in consent notice | Article 15(1) |
| Consent Requirement | Before PII collection | Checkbox at signup (email confirmation) | Article 15(1) |
| Consent Records | Must retain proof | Stored in auth_consent table | Article 15(2) |
| Data Security (Encryption) | PII at rest | Fernet (AES-128 in CBC mode) | Article 27(1) |
| Data Security (Access Control) | Restrict to authorized users | OAuth + role-based access | Article 27(1) |
| Breach Notification (72h) | Major data exposure | Procedure: alert ops team → PPC report within 72h | Article 35 |
| Data Subject Rights (DSR) | Export, correction, deletion | /api/tenant/{id}/dsr endpoints | Article 34 |
| Deletion on Request | User-initiated deletion | Immediate mark + 30-day cron delete | Article 35(1) |
| Retention Period | No data longer than necessary | Renewal cycle = 2 years max; then delete | Article 15(3) |
| Disclosure to Third Parties | Broker only (controller) | No external API; broker owns data | Article 17 |
| Personal Data Protection Officer | Optional for small processor | [운영회사명: TBD] to decide | Article 38(1) |
| Privacy Impact Assessment (PIA) | Large-scale processing | Annual review of renewal/deposit pipelines | Article 36 |
| International Transfer | Data leaving Japan | Not applicable (JP-based storage only) | Article 27(1) |

---

## 特定商取引法 (Act on Specified Commercial Transaction) — Notice Template

This applies if Ancu365 acts as an intermediary or service seller to consumers (tenants). 

**Note:** If tenants access Ancu365 only via broker portals (broker owns the relationship), notice may not apply. **Clarify with counsel.**

If notice is required, display at signup / in help center:

```
──────────────────────────────────────────────────────
特定商取引法に基づく表示

【事業者情報】
事業者名: [運営会社名: TBD]
代表者: [氏名]
所在地: [住所]
電話: [電話番号]
メール: [メールアドレス]
営業時間: [営業時間]

【商品・サービス】
名称: Ancu365 賃貸管理プラットフォーム
説明: 仲介業者向けの入居者管理・更新手続きSaaS

【料金】
パッケージ: [料金表へのリンク]
支払い方法: 自動口座振替（月次）
支払い時期: 毎月末日

【キャンセル・返金】
- 月間サブスクリプション: 30日前通知で解約可能
- 返金: 未使用期間は日割り精算
- 利用中止後30日以内にデータを削除（APPI対応）

【トラブル対応】
- 不具合報告: support@ancu365.jp
- 苦情受付: complaints@ancu365.jp
- 紛争解決: [協会名] 仲裁委員会（予定）

【個人情報】
個人情報保護: プライバシーポリシーを参照
問い合わせ: privacy@ancu365.jp
──────────────────────────────────────────────────────
```

---

## Known Compliance Gaps & Proposed Mitigations

### 🔴 CRITICAL GAPS

1. **Payment Data Handling**
   - **Issue:** Do we store tenant payment history? If yes, PCI-DSS scope.
   - **Current:** Unclear in codebase
   - **Mitigation:** 
     - Decide: store minimal (last 4 digits only) or delegate to payment gateway
     - If storing: implement PCI-DSS Level 1 tokenization
     - If delegating: update privacy policy

2. **Encryption Key Rotation**
   - **Issue:** Fernet key rotation procedure not documented
   - **Current:** Key stored in env; no rotation plan
   - **Mitigation:**
     - Implement quarterly key rotation (see compliance-runbook.md)
     - Test restore from key backups before deploy
     - Maintain key history for decryption of old records

3. **Breach Notification Procedure**
   - **Issue:** No written 72-hour escalation procedure
   - **Current:** Ad-hoc
   - **Mitigation:** 
     - Document PPC (個人情報保護委員会) notification flow
     - Define roles: who decides "major breach"?
     - Test procedure quarterly

### ⚠️ MEDIUM-RISK GAPS

4. **Third-Party Vendor Compliance**
   - **Issue:** Sub-processors (e.g., payment gateway, email service) need data processing agreements (DPA)
   - **Current:** Unclear if DPAs signed
   - **Mitigation:**
     - Audit all third-party services
     - Require APPI-compliant DPA or Terms
     - Notify tenants in privacy policy

5. **Tenant Consent Record Retention**
   - **Issue:** APPI Article 15(2) requires proof of consent; retention period unclear
   - **Current:** DB stores consent, but no archive/immutability
   - **Mitigation:**
     - Implement blockchain-style immutable log (or sealed audit trail)
     - Retain consent records for 7 years (standard)

6. **Sensitive Data Collection (Future)**
   - **Issue:** If platform expands to disability/medical data, requires separate framework
   - **Current:** Not applicable now
   - **Mitigation:** Pre-plan for future: separate encryption key, explicit consent, access audit

### ℹ️ LOWER-RISK GAPS

7. **Data Retention Policy Documentation**
   - **Issue:** No published data retention schedule
   - **Current:** Ad-hoc deletion
   - **Mitigation:** Publish retention policy in help center (e.g., "Tenant data deleted 2 years after renewal")

8. **APPI Privacy Impact Assessment (PIA)**
   - **Issue:** Large-scale processing should trigger PIA (Article 36)
   - **Current:** Not documented
   - **Mitigation:** Schedule annual PIA review; template in compliance-runbook.md

---

## Questions for 弁護士 (Legal Counsel)

Below are 10 key questions the Ancu365 team needs answered before JP market launch:

### 1. **Licensing Requirement (宅建業免許)**
   - **Q:** Ancu365 provides tools for brokers to manage rentals, but we never directly negotiate leases or take fees. Do we need 宅建業免許?
   - **Legal concept:** RETIO Article 2 (definition of 宅建業)
   - **Implication:** If yes, significant compliance burden; if no, SaaS model stands.

### 2. **Data Controller vs. Processor Classification**
   - **Q:** Are we a 個人情報取扱事業者 (controller) or データ処理事業者 (processor) for tenant data? Or both?
   - **Our assumption:** Broker is controller; Ancu365 is processor (data processing agreement required?)
   - **Implication:** Affects liability for APPI violations; affects consent obligations.

### 3. **Consent Mechanism Compliance**
   - **Q:** Is a checkbox at signup sufficient for APPI Article 15(1) consent? Do we need separate confirmation email?
   - **Our approach:** Checkbox + confirmation email (link-based)
   - **Implication:** If insufficient, need to update UX before launch.

### 4. **Breach Notification Threshold**
   - **Q:** What constitutes a "breach" triggering 72-hour PPC notification under Article 35?
   - **Examples:** 1 tenant's name/email leaked? 100? 10,000? Depends on re-identifiability risk?
   - **Implication:** Define our internal threshold + escalation SLA.

### 5. **Payment Data Scope**
   - **Q:** If we store tenant payment history (e.g., "failed payment on X date"), does that trigger PCI-DSS?
   - **Our current:** Undecided (may not store)
   - **Implication:** If yes, significant audit/compliance cost; may delegate to payment processor instead.

### 6. **Guarantor Data (保証人)**
   - **Q:** When a tenant enters their guarantor's name/phone, is that a separate personal record requiring explicit consent?
   - **Implication:** May need separate consent capture + storage for guarantor PII.

### 7. **Cross-Border Data (If Tenants are Expat)**
   - **Q:** If platform expands to international tenants (e.g., expat worker in JP), do non-JP residents' data trigger GDPR/CCPA?
   - **Current:** Assuming JP tenants only
   - **Implication:** If expats included, need separate DPA / privacy framework.

### 8. **Document Upload & Retention**
   - **Q:** When tenant uploads ID copy (government-issued photo ID), how long can we store it? APPI Article 15(3)?
   - **Implication:** Defines retention schedule for sensitive documents.

### 9. **Sub-Processor DPA Requirements**
   - **Q:** Which third-party services need formal data processing agreements (DPA) under APPI?
   - **Examples:** Payment gateway, email service (Sendgrid), storage (AWS), SMS (Twilio)
   - **Implication:** Audit all vendors + negotiate APPI-compliant terms before launch.

### 10. **Deposit Settlement & 敷金保証会社 Integration**
   - **Q:** If Ancu365 integrates with 敷金保証会社 (deposit guarantee company) via API, are we facilitating 貸金業 (money lending)?
   - **Issue:** Deposit guarantee ≠ lending, but API integration may blur lines
   - **Implication:** Clarify our role; may need separate legal review if we handle refunds.

---

## Summary Table for Review

| Topic | Current Status | Risk Level | Counsel Input Needed? |
|---|---|---|---|
| Business model (no 宅建業免許 needed) | Clear, but needs confirmation | Medium | Q1 |
| Data controller/processor role | Assumed broker = controller | Medium | Q2 |
| Consent mechanism (checkbox + email) | Implemented | Low | Q3 |
| Breach notification (72h PPC) | Process drafted | Medium | Q4 |
| Payment data storage | Undecided | High | Q5 |
| Guarantor consent | Assumed covered by tenant consent | Medium | Q6 |
| Expat tenant data | Out of scope for MVP | Low | Q7 |
| Document retention | 2-year default; TBD | Low | Q8 |
| Sub-processor DPA | Audit in progress | High | Q9 |
| Deposit guarantee integration | Possible future feature | Low | Q10 |

---

## Next Steps

1. **Share this packet with 弁護士** (include APPI-compliance-checklist.md as appendix)
2. **Receive legal counsel responses** to the 10 questions
3. **Update privacy policy & T&C** based on counsel feedback
4. **Schedule pre-launch audit** (2 weeks before go-live)
5. **Brief broker partners** on APPI compliance expectations

---

**Document Owner:** Ancu365 Product & Legal Team  
**Last Updated:** 2026-10-17  
**Next Review:** Upon counsel feedback / 2 weeks before JP launch
