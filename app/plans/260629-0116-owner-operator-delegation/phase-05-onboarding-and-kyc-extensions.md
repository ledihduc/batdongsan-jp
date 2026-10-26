# Phase 05 — Onboarding & KYC Extensions

## Context Links
- BA v4: §2.4 (KYC existing), §5.2 (US-P3/P4), §6.11 (AC-64/AC-65/AC-66), §13 D3 (POA format default digital), §13 D4 (sole ownership self-attest)
- ACs: AC-06 (KYC complete gate), AC-50 (KYC expiry grace), AC-50b (PMC legal-rep change), AC-61 (GPKD revoked auto-pause), AC-64 (sole ownership attestation), AC-65 (PMC legal-rep change workflow), AC-66 (shared-login disclosure)
- User Stories: US-O19 (POA format choice), US-P3 (individual KYC), US-P4 (business KYC), US-P14 (KYC expiry pro-active notification), US-P16 (PMC legal-rep update)
- Assumptions: AS-06 (1 user pháp nhân), AS-12 (PROMOTED to AC-66), AS-14 (FastCA/VinaCA vendor), AS-15 (sole-ownership self-declaration)
- Research: `researcher-01-backend-auth-kyc.md` §B (KYC ~40% individual, 0% business), §F (KB04 60% owner); `researcher-03-flutter-app.md` §B (onboarding flow) + §E (forms)
- Dependent on phases: 01 (`operator_business_profiles` table + `users.sole_ownership_attested_at` + `delegations.shared_login_disclosure_ack_at`), 02 (actor context)
- Blocks: phase-03 invitation accept path (need operator KYC complete check), phase-04 POA-driven KB04 approval

## Overview
- **Priority:** P0
- **Status:** Pending
- **Effort:** 6 dev-days (3 BE + 3 FE)
- **Type:** full-stack
- **Description:** Build operator onboarding (individual reuses host KYC; business is greenfield), PMC legal-rep change flow, sole-ownership attestation modal, shared-login disclosure modal, and POA format selection at delegation creation. Owner-side: sole-ownership attestation gate before any delegation invite.

## Key Insights from Research
- Individual operator KYC reuses host CCCD + bank flow (`host_profiles` table) — researcher-01 §B.
- Business operator KYC is greenfield: no `OperatorBusiness` table existed before phase-01; no eKYC vendor.
- Onboarding 3 steps already exist on Flutter (researcher-03 §B): `step1_info`, `step2_cccd`, `step3_bank`. Adding step4 for business operator.
- No biometric integration today (researcher-03 §E). AC-29b biometric is at approval time (phase-04), not at KYC — confirm with planner.
- Existing `host_profiles.verified` boolean — no state machine. Add `kyc_verification_status` enum to mirror new business table.
- Existing CCCD fields are encrypted-at-rest pattern (hash + path). Mirror for business legal-rep CCCD.
- AC-64 sole-ownership lives on `users` (phase-01 schema) — per BA v4 it's an account-level attestation, not per-property.

## Requirements (mapped to BA v4)

### Functional ACs covered

| AC | Implementation |
|----|----------------|
| AC-06 | Backend `is_operator_kyc_complete(user) -> bool` helper; checks `host_profiles.verified=True AND host_profiles.cccd_number_hash IS NOT NULL AND host_profiles.bank_account_number IS NOT NULL` (individual) OR `operator_business_profiles.verification_status='verified'` (business). Returned in `GET /delegations/invitations/{id}` preview |
| AC-50 | KYC expiry cron (phase-03 `delegation_kyc_expiry_warner` + `_pauser` + `_grace_terminator`); this phase implements `kyc_expires_at` column writes during KYC submission (default = `verified_at + 5 years` for individual CCCD, `gpkd_expires_at` from GPKD field for business) |
| AC-50b | PMC legal-rep change workflow `POST /api/operator-business/me/legal-rep-change` — uploads new POA + new legal-rep CCCD; admin verifies within 48h (US-A4); upon admin approve, updates `user.id` ownership of `operator_business_profile`, retires old `previous_legal_rep_user_id`; in-flight approvals re-routed (notification + audit log) |
| AC-61 | Admin endpoint `PATCH /admin/operator-business/{id}/revoke-gpkd` → sets `verification_status='revoked'`; phase-03 cron auto-pauses delegations; if not re-verified in 15d → auto-terminate |
| AC-64 | UI modal at first login OR before first delegation invite send: "Property registered under single name (sole owner per red book)?" — Yes → click-ack → server `PATCH /api/me/sole-ownership-attestation` writes `users.sole_ownership_attested_at = now()`; No → blocks delegation invite send |
| AC-65 | PMC legal-rep change service: validates new POA + CCCD; admin approves via `POST /admin/operator-business/{id}/approve-legal-rep-change`; transitions `operator_business_profiles.legal_rep_changed_at + previous_legal_rep_user_id`; old credentials disabled within 48h (force-logout old user session) |
| AC-66 | Shared-login disclosure modal at operator-doanh-nghiệp first login post-acceptance: `PATCH /api/delegations/{id}/shared-login-disclosure-ack` writes `delegations.shared_login_disclosure_ack_at = now()` — blocks delegation activation until ack |

### NFRs
- NFR-08..NFR-11 (mobile-first) — Flutter components use existing Editorial Cockpit `Ds*` widgets (researcher-03 §F); CCCD upload uses existing `image_picker` + `image_cropper` (researcher-03 §E)
- NFR-12 (Vietnamese diacritics NFC) — all name fields normalize via existing utilities

### User Stories satisfied
- US-O19 (POA format selector at invite creation — see phase-03 invite payload; this phase ships the Flutter UI for selector)
- US-P3 (individual operator KYC reuse)
- US-P4 (business operator KYC greenfield)
- US-P14 (KYC expiry notification — wires cron from phase-03 to actual operator notification via phase-08)
- US-P16 (PMC legal-rep update without re-onboarding properties)
- US-A4 (admin review queue — admin endpoints here; admin UI in phase-10)

## Architecture

### Backend endpoints

**Operator-individual KYC (mostly reused — patch only):**
- Existing `POST /api/host/onboarding/cccd` and `/bank` — extend to set `host_profiles.kyc_expires_at = verified_at + 5y` on verification.

**Operator-business KYC (greenfield):**

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/operator-business/onboarding/business-info` | Body: `{business_name, business_registration_number, gpkd_industry_codes[]}`. Creates `operator_business_profiles` row `verification_status='pending'`. |
| `POST` | `/api/operator-business/onboarding/gpkd-upload` | Multipart file (PDF/image). Stores via `sensitive_file_service` (phase-01). Sets `gpkd_document_path` + `gpkd_issued_at` + `gpkd_expires_at`. |
| `POST` | `/api/operator-business/onboarding/legal-rep-info` | Body: `{name, cccd_number, phone}` + multipart CCCD front/back. Hash CCCD via existing utility, store paths via sensitive_file_service. |
| `POST` | `/api/operator-business/onboarding/legal-rep-change` | AC-50b/AC-65 — same body as legal-rep-info + reason; creates `verification_status='pending_legal_rep_change'`; pauses delegations of this operator (phase-03 hook). |
| `GET` | `/api/operator-business/me` | Returns full profile + verification status |

**Admin endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/admin/kyc-queue?type=individual\|business&status=pending` | Admin review queue (used by phase-10 UI) |
| `POST` | `/admin/operator-business/{id}/approve` | Verify + transition to `verified_at = now()` |
| `POST` | `/admin/operator-business/{id}/reject` | Body: `{reason}` |
| `POST` | `/admin/operator-business/{id}/approve-legal-rep-change` | AC-65 — completes the legal-rep change; force-logs out old user; transitions profile to active |
| `PATCH` | `/admin/operator-business/{id}/revoke-gpkd` | AC-61 admin action |
| `GET` | `/admin/kyc-queue/sla-overdue` | KYC pending > 48h alert dashboard |

**Owner endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| `PATCH` | `/api/me/sole-ownership-attestation` | AC-64 — body `{attested: true}`. Server records timestamp. Owner toggle False not allowed (one-way until v2). |
| `GET` | `/api/me/sole-ownership-attestation` | Returns `{attested_at: datetime|null}` for UI gating |

**Operator endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| `PATCH` | `/api/delegations/{id}/shared-login-disclosure-ack` | AC-66 — operator (legal rep) acks shared-login risk. Server writes timestamp + flips delegation from `pending_op_kyc` → `active` if all gates met. |

### Service layer

`app/services/operator_kyc_service.py` (NEW):
- `mark_individual_kyc_complete(user)` — wraps existing flow; sets `kyc_expires_at`.
- `submit_business_info(user, payload)`
- `submit_business_gpkd(user, file)`
- `submit_business_legal_rep(user, payload, cccd_front, cccd_back)`
- `admin_approve_business(profile, admin_user)`
- `admin_reject_business(profile, admin_user, reason)`
- `admin_revoke_gpkd(profile, admin_user)`
- `initiate_legal_rep_change(profile, new_payload, new_cccd_files)`
- `admin_approve_legal_rep_change(profile, admin_user)`
- `is_operator_kyc_complete(user) -> bool`

Every method writes ChangeLog + emits notification event (e.g., `operator_business_verified`, `legal_rep_change_completed`).

### Sole-ownership attestation gate (AC-64)

- Backend: `POST /api/delegations/invitations` (phase-03 endpoint) MUST check `users.sole_ownership_attested_at IS NOT NULL` for the inviting owner. If NULL → 412 PRECONDITION_FAILED with body `{code: 'SOLE_OWNERSHIP_ATTESTATION_REQUIRED', next_step: '/api/me/sole-ownership-attestation'}`.
- Flutter: route guard on `OperatorInviteScreen` → if `attested_at` null → push to `SoleOwnershipAttestationScreen` (new) first.

### Shared-login disclosure gate (AC-66)

- Backend: when accepting invitation as operator-doanh-nghiệp (where `operator_business_profiles` exists for accepting user), delegation transitions stay in `pending_op_kyc` until BOTH operator KYC verified AND `shared_login_disclosure_ack_at` set.
- Flutter: after accept, if business operator + ack NULL → modal blocks all other UI until ack.

### POA format selection (AC-55d, US-O19)

- This phase ships the **Flutter UI**: at `OperatorInviteScreen`, radio button `POA format: Digital (FastCA/VinaCA) [recommended] | Notarized PDF upload`.
- If `Notarized PDF` → `FilePickerField` (new component or `file_picker` package — add to pubspec). On submit, file uploaded via multipart to invitation creation endpoint (phase-03), stored at `delegations.poa_document_path`.
- If `Digital` AND vendor not configured → UI shows warning + suggests Notarized fallback.
- Backend (phase-03 invite endpoint) accepts `poa_format` + optional `poa_document` multipart.

### Flutter screens

**New screens:**
- `lib/features/operator/onboarding/business_info_screen.dart` — step1 of business KYC (form: business name, GPKD number, ngành nghề chips)
- `lib/features/operator/onboarding/business_gpkd_upload_screen.dart` — step2 (file picker + camera for GPKD scan)
- `lib/features/operator/onboarding/business_legal_rep_screen.dart` — step3 (legal rep CCCD form, reuses existing step2_cccd component pattern)
- `lib/features/operator/onboarding/business_review_screen.dart` — step4 (review + submit)
- `lib/features/owner/sole_ownership_attestation_screen.dart` — modal sheet pre-invite (AC-64)
- `lib/features/operator/disclosures/shared_login_disclosure_modal.dart` — DsDialog (AC-66)
- `lib/features/operator/legal_rep_change_screen.dart` — US-P16 / AC-50b / AC-65 flow

**Reused screens:**
- Existing `step1_info`, `step2_cccd`, `step3_bank` for individual operator (no changes — same backend, gated by `is_operator_capable`).

**Providers:**
- `lib/providers/operator_business_profile_provider.dart` (NEW)
- `lib/providers/sole_ownership_provider.dart` (NEW — tiny)

**Repositories:**
- `lib/data/repositories/api_operator_business_repository.dart` (NEW)
- `lib/data/repositories/api_kyc_status_repository.dart` (NEW — reads operator KYC complete flag)

### Vendor integration (AS-14, TL-7)

- `app/integrations/digital_signature.py` (already created in phase-04 as stub) — wired here for actual API calls.
- `FastCASignatureProvider`: REST client with `FASTCA_API_KEY` env var, `request_signature(user_phone, document_payload) -> signature_ref`. Returns mock if `FASTCA_MOCK_MODE=true` (dev).
- Fallback flow: if env not configured, `digital_signature.is_configured() == False` → flutter UI hides Digital option, only Notarized shown.

**Vendor contract (AS-14):** decision deadline = mid phase-05. If unsigned, ship without digital path; document in `docs/deployment-guide.md` how to enable when signed.

## Related Code Files

### To create
- `app/services/operator_kyc_service.py`
- `app/repositories/operator_business_repository.py`
- `app/routers/operator_kyc.py`
- `app/routers/admin_kyc.py`
- `app/routers/owner_attestation.py`
- `app/schemas/operator_kyc.py`
- `app/integrations/fastca_client.py` (concrete impl behind `app/integrations/digital_signature.py` interface)
- `lib/features/operator/onboarding/business_info_screen.dart`
- `lib/features/operator/onboarding/business_gpkd_upload_screen.dart`
- `lib/features/operator/onboarding/business_legal_rep_screen.dart`
- `lib/features/operator/onboarding/business_review_screen.dart`
- `lib/features/owner/sole_ownership_attestation_screen.dart`
- `lib/features/operator/disclosures/shared_login_disclosure_modal.dart`
- `lib/features/operator/legal_rep_change_screen.dart`
- `lib/providers/operator_business_profile_provider.dart`
- `lib/providers/sole_ownership_provider.dart`
- `lib/data/repositories/api_operator_business_repository.dart`
- `lib/data/repositories/api_kyc_status_repository.dart`
- `tests/services/test_operator_kyc_service.py`
- `tests/routers/test_operator_kyc_router.py`
- `tests/integrations/test_fastca_client.py` (mock-based)

### To modify
- `app/services/host_profile_service.py` (existing) — set `kyc_expires_at` on verification
- `app/routers/host_onboarding.py` (existing) — add `kyc_expires_at` return field
- `lib/features/host/onboarding/become_host_intro_screen.dart` — add branching: cá nhân vs doanh nghiệp
- `lib/features/operator/onboarding/...` — register new routes in `app_router.dart`
- `pubspec.yaml` — add `file_picker: ^8.x` (for POA upload + GPKD upload)
- `app/main.py` — include new routers

### To delete
- None.

## Implementation Steps

1. **Branch `feat/p05-onboarding-kyc`** off phase-02 merge (can parallel with phase-03).
2. **Backend services + repositories** first (TDD):
   - `operator_business_repository.py` — basic CRUD.
   - `operator_kyc_service.py` — all 10 methods.
3. **Routers:** `operator_kyc.py`, `admin_kyc.py`, `owner_attestation.py`. Wire `require_actor_with_permission` where applicable.
4. **FastCA integration:** `fastca_client.py` with `MOCK_MODE` env switch. Mock returns deterministic `signature_ref`.
5. **Pydantic schemas:** request/response for all endpoints.
6. **Tests (backend):**
   - All 10 service methods (positive + negative).
   - AC-50b legal-rep change end-to-end (operator submits → delegations pause → admin approve → resumes).
   - AC-64 invite rejected when `sole_ownership_attested_at IS NULL`.
   - AC-65 force-logout old user (verify session invalidation hook).
   - AC-66 delegation activation blocked until ack.
7. **Flutter screens:** start with `SoleOwnershipAttestationScreen` (smallest, blocks invite path).
8. **Business onboarding wizard:** 4 screens chained via `go_router` push.
9. **Disclosure modal:** triggered on first paint of `OperatorPortfolioScreen` (phase-07) when business operator + ack NULL.
10. **POA format selector:** added to phase-07 invite screen, but the selector component lives here.
11. **Legal-rep change flow UI:** form + status indicator while admin reviews.
12. **Pubspec update:** `file_picker`. Test on Android 7+ (NFR-08).
13. **i18n:** Vietnamese strings for all new screens (BA glossary §4).
14. **Integration tests:** Flutter widget tests for each new screen + provider tests.
15. **Document:** `docs/system-architecture.md` — operator onboarding flow diagram (individual vs business branches).
16. **PR review + merge.**

## Todo List
- [ ] Branch `feat/p05-onboarding-kyc` from phase-02
- [ ] Write `app/repositories/operator_business_repository.py`
- [ ] Write `app/services/operator_kyc_service.py` (10 methods)
- [ ] Write `app/routers/operator_kyc.py`, `admin_kyc.py`, `owner_attestation.py`
- [ ] Write `app/schemas/operator_kyc.py`
- [ ] Write `app/integrations/fastca_client.py`
- [ ] Modify `host_profile_service.py` to set `kyc_expires_at`
- [ ] Add `file_picker` to `pubspec.yaml`
- [ ] Write Flutter `business_info_screen.dart` + tests
- [ ] Write Flutter `business_gpkd_upload_screen.dart`
- [ ] Write Flutter `business_legal_rep_screen.dart`
- [ ] Write Flutter `business_review_screen.dart`
- [ ] Write Flutter `sole_ownership_attestation_screen.dart`
- [ ] Write Flutter `shared_login_disclosure_modal.dart`
- [ ] Write Flutter `legal_rep_change_screen.dart`
- [ ] Write Flutter providers + repositories
- [ ] Wire routes in `app_router.dart`
- [ ] Backend unit tests (10 service methods)
- [ ] Backend integration test: AC-50b legal-rep change end-to-end
- [ ] Backend integration test: AC-64 invite blocked without attestation
- [ ] Backend integration test: AC-66 delegation activation blocked
- [ ] Flutter widget tests for new screens
- [ ] i18n Vietnamese strings (BA §4 glossary aligned)
- [ ] Document onboarding flow in `docs/system-architecture.md`
- [ ] PR review + merge

## Success Criteria
- All 10 backend service methods unit-tested + passing.
- All 7 new endpoints integration-tested.
- AC-64 attestation enforced at backend (412 + Flutter route guard).
- AC-66 disclosure enforced at backend (`pending_op_kyc` → `active` blocked until ack).
- AC-50b legal-rep change reduces 0 downtime for property data; operator audit shows transition with `previous_legal_rep_user_id`.
- AC-61 admin GPKD revoke transitions delegations via phase-03 cron.
- Vietnamese localization complete for all new screens.
- FastCA mock mode works in dev; integration test passes with `MOCK_MODE=true`.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| FastCA vendor contract not signed by phase-05 mid-point | Med | High | Default to Notarized-PDF-only path; hide Digital option in UI; document re-enable steps. |
| GPKD industry code list disputed by legal (Q6.3) | Med | Med | Phase-05 stores codes as JSON array; admin manually verifies relevant code present; legal can publish definitive list later without schema change. |
| Legal-rep change creates dangling references in audit log | Low | Med | `previous_legal_rep_user_id` preserves history; ChangeLog records by user_id (which doesn't change, only owner of business_profile reassigned). |
| Force-logout of old legal-rep session (AC-65) fails to revoke active JWTs | Med | High | JWT revocation list (new table `revoked_tokens`) — backend checks on every auth. Defer if backlog → use short JWT TTL (24h) as compromise. Document in security risk register. |
| Owner accidentally checks "Yes, sole owner" then later reveals it's joint | Med | High | Modal text very clear in Vietnamese + ToS checkbox tying to indemnity (AS-15). Re-attestation requires admin assist (no self-toggle). |
| Business KYC steps abandoned mid-flow (4 screens) | High | Low | Auto-save progress to backend after each step; resume on app reopen. |
| GPKD/CCCD upload size > NFR-10 (800KB after compression) | Med | Med | Apply `image_cropper` + Flutter-side `image` package compression in upload screens (existing pattern in `step2_cccd`). |
| AC-65 in-flight approvals re-routed mid-decision | Low | Med | When legal-rep change initiated, pending approvals stay; on admin approve, system updates `delegation_approvals.requester_user_id` to new legal-rep user. Tests cover. |

## Security Considerations

- **AS-15 sole-ownership self-declaration:** indemnity clause in ToS (legal: Q6.1). Server records `attested_at` + IP + user_agent for evidence.
- **Business operator CCCD storage:** mirror existing host CCCD encryption (bcrypt hash + encrypted file path via `sensitive_file_service`).
- **POA document path:** encrypted-at-rest. Read access logged.
- **AC-65 legal-rep change:** old credentials must be invalidated (JWT revocation or short TTL). MUST be tested.
- **Shared-login risk (AC-66 / AS-12):** explicit ack + audit attribution to single account. ToS indemnity language: "all actions taken under this account are deemed taken by the legal representative."
- **Vendor (FastCA) API key:** stored in env, never logged. Mock mode for dev/test.

## Next Steps / Dependencies

- **Blocks:** Phase 07 (Flutter UI integrates POA selector + disclosure modal + attestation screen), Phase 10 (admin UI surfaces KYC queue).
- **Parallel-safe with:** Phase 03 (delegation API — different endpoints), Phase 04 (approval — different routers), Phase 08 (notifications — different code paths), Phase 09 (commission).

## Open items flagged
- Q6.1 — delegation contract template + indemnity legal language (legal counsel)
- Q6.3 — GPKD ngành dịch vụ quản lý BĐS hardcode list (legal counsel)
- AS-14 — FastCA/VinaCA vendor contract signed by mid-phase (procurement) — fallback to notarized-only path documented
- O2 — police digital POA acceptance per district (legal validation) — required before AC-55d digital default in production
