# Phase 04 — Launch Ops & Legal

**Priority:** P3 · **Status:** 🚀 Starting · **Est:** 1 week ops/content

## Overview

Non-engineering deliverables cho JP launch: legal review packet, help center content (14 FAQ), compliance checklist, launch comms.

## Scope

### 1. Legal review packet (for 弁護士/宅建士 consultation)
- `docs/jp/legal-review-packet.md`:
  - Business model: B2B SaaS cho licensed JP brokers; chúng ta KHÔNG hold 宅建業免許
  - Data flows: APPI classification matrix (personal / sensitive / anonymized)
  - 特定商取引法 notice (template fields)
  - User flow diagrams: tenant signup, consent, deletion request
  - Known compliance gaps + proposed mitigations
  - Questions for lawyer (10 numbered)
- `docs/jp/appi-compliance-checklist.md`:
  - 20 items mapped to APPI 2022 amendment articles
  - Status column: ✅ implemented / ⚠️ partial / ❌ gap
  - Evidence links to code/endpoints

### 2. Help Center content (14 JP FAQ articles)
Delivered as `.md` files in `ancu365-app/assets/jp/help/`:
- 更新 (3): `renewal-overview.md`, `renewal-fee-breakdown.md`, `renewal-decline-process.md`
- 敷金精算 (3): `settlement-overview.md`, `settlement-dispute.md`, `settlement-timeline.md`
- APPI (3): `appi-your-rights.md`, `appi-data-export.md`, `appi-account-deletion.md`
- 支払い (2): `payment-methods.md`, `payment-failure.md`
- アカウント (2): `account-setup.md`, `account-verification.md`
- 問い合わせ (1): `contact-support.md`
- Each: 300–600 chars JP, step-by-step tone, no legal advice

### 3. Compliance evidence runbook
- `docs/jp/compliance-runbook.md`:
  - Monthly: pull `/jp/compliance/evidence`, archive
  - Quarterly: Fernet key rotation procedure
  - Annual: APPI PIA review
  - Incident: breach notification 72h window procedure

### 4. Launch comms templates
- `docs/jp/launch-comms/`:
  - `broker-onboarding-email-ja.md` (invite partner broker)
  - `tenant-welcome-email-ja.md`
  - `incident-notification-template-ja.md`
  - `press-release-draft-ja.md`

## Files

**New:**
- `ancu365-backend/docs/jp/legal-review-packet.md`
- `ancu365-backend/docs/jp/appi-compliance-checklist.md`
- `ancu365-backend/docs/jp/compliance-runbook.md`
- `ancu365-backend/docs/jp/launch-comms/*.md` (4 files)
- `ancu365-app/assets/jp/help/*.md` (14 files)

## Success Criteria
- Legal packet complete, 10 questions clearly flagged for lawyer input
- All 14 help articles pass JP native speaker read-through (deferred to launch team)
- Compliance checklist has evidence links for every ✅ item
- Launch comms localized in natural JP (not translated-from-EN tone)

## Open Questions
- Operator company legal entity: Synora KK or offshore + JP representative?
- Help article tone preference: です/ます (polite) throughout — confirmed.
