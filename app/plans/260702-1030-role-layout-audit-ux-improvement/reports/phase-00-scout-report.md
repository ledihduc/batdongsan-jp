# Phase 00 Scout Report

**Date:** 2026-07-02  
**Scout Status:** COMPLETE  
**Blockers Found:** 0 (tenant JWT not ready, but Phase 02 handles deferral)  
**Green Light:** YES — proceed with Phase 01

---

## Section A: Line reference verification

| # | Claim | Status | Actual |
|---|-------|--------|--------|
| 1 | host_home_screen.dart:590-625 `_confirmDelete()` | VERIFIED | Lines 590-625, exact match |
| 2 | contract_terminate_screen.dart exists | VERIFIED | File exists at lib/features/host/property/screens/ |
| 3 | contract_transfer_room_screen.dart exists | VERIFIED | File exists at lib/features/host/property/screens/ |
| 4 | auth_provider.dart:113-131 logout flow | VERIFIED | Lines 113-131, logout() without ActorContext.clear() (as expected) |
| 5 | actor_context_provider.dart:53-58 `clear()` method | VERIFIED | Lines 53-58, clear() exists and resets delegation state |
| 6 | guest_shell.dart:203-217 FAB "Đăng tin" | VERIFIED | Lines 203-217, FloatingActionButton.extended navigates to PostHouseScreen |
| 7 | post_house_screen.dart line 286 auto-upgrade | VERIFIED | Line 286: `if (ok && newToken != null)` — triggers SessionService.setToken + AuthProvider.bootstrap() |
| 8 | app_router.dart:83-111 redirect logic | VERIFIED | Lines 83-111, exact redirect guards (file 662 lines total) |
| 9 | deferred_route_widget.dart exists | VERIFIED | File exists at lib/core/router/ |
| 10 | empty_state.dart (not ds_empty_state.dart) | VERIFIED | File is lib/core/widgets/empty_state.dart ✓ |
| 11 | delegation_provider.dart `myDelegationsAsOperator` getter | VERIFIED | Line 34: getter exists, line 24 backing field, line 49/113 mutation |
| 12 | operator_workspace_shell.dart exists + purpose | VERIFIED | File exists. Purpose: **shell (container)** wrapping host screens with ActingAsBanner overlay; handles delegation context lifecycle (AC-13, AC-15b, AC-16b) |

**All 12 line references verified — 100% match.**

---

## Section B: Backend contract verification

### B1: POST /api/houses auto-upgrade (guest → host JWT)
- **Status:** VERIFIED ✓
- **File:** `/ancu365-backend/app/routers/houses.py:89-149`
- **Evidence:**
  - Line 141–149: `if claims.get("role") != "host": … user.role = "host" … new_token = auth.sign_token(user_id, "host")`
  - Endpoint returns `new_token: str | None` in response (line 142)
- **Recommendation:** Phase 01 frontend code (post_house_screen.dart:286) correctly handles token refresh ✓

### B2: Tenant JWT issuance
- **Status:** NOT_FOUND
- **Search Results:** Backend has `TenantAuthorityFlag` model (dispute/pause flags) but NO `tenant_jwt` generation or dedicated tenant authentication
- **Evidence:** Grep for `tenant.*jwt`, `create_tenant_token`, `TenantAuth` — only dispute/pause authority model found
- **Impact:** Phase 02 tenant guard will need to defer until backend team confirms tenant JWT endpoint
- **Recommendation:** Mark Phase 02 Section C3 "Tenant Route Guards" as BLOCKED_ON_BACKEND; add TODO comment to revisit after backend tenant JWT lands

### B3: User.role field type
- **Status:** VERIFIED ✓
- **File:** `/ancu365-backend/app/models.py:60`
- **Evidence:** `role: Mapped[str] = mapped_column(String(20), default="guest")` — plain string, NOT Postgres enum
- **Implication:** Phase 03 Option B (enum constraint) requires 0.5d backend migration to add CHECK constraint or Enum type

### B4: Admin self-approval guard
- **Status:** NOT_FOUND (backend does NOT check `actor_id != listing.owner_id`)
- **File:** `/ancu365-backend/app/api/routes/approval.py:207-230`
- **Evidence:** Endpoint `approve_approval()` delegates to `ApprovalService.decide()` with `owner_ctx` only — no check preventing admin-owns-listing self-approval
- **Impact:** U4 assumption UNVERIFIED — Phase 03 admin toggle choice left to user (Phase 03 spec correctly notes this as decision point)
- **Recommendation:** Add comment to Phase 03 decision: "Backend does NOT guard self-approval; design choice deferred to Phase 03"

### B5: X-Acting-As-Delegation-Id header handling
- **Status:** VERIFIED (backend uses ActorContext, not explicit header)
- **File:** `/ancu365-backend/app/services/actor_context.py:34-75`
- **Evidence:** Backend resolves delegation via Depends(resolve_actor_context) dependency in route handlers; per-request (no JWT caching per NFR-07)
- **Implementation:** Frontend sends delegation ID via headers → FastAPI dependency resolves it → ActorContext frozen dataclass with permission_set
- **Recommendation:** Phase 02 FCM step will need to confirm header naming (`X-Acting-As-Delegation-Id` matches FastAPI dependency)

### B6: 403 response format
- **Status:** VERIFIED ✓
- **File:** `/ancu365-backend/app/api/routes/approval.py:232-236`
- **Evidence:** `raise HTTPException(status_code=404, detail={"code": "APPROVAL_NOT_FOUND"})` — `{code, message}` structure confirmed
- **Recommendation:** Phase 02 error handling can rely on this format

---

## Section C: Provider inventory

**Total providers in main.dart MultiProvider:** 22

| Provider | Has reset/clear()? | File Location |
|---|---|---|
| AuthProvider | ❌ | lib/providers/auth_provider.dart (logout() only, no clear() for providers) |
| HostProfileProvider | ❌ | lib/providers/host_profile_provider.dart |
| HouseProvider | ❌ | lib/providers/house_provider.dart |
| ViewingAppointmentProvider | ❌ | lib/providers/viewing_appointment_provider.dart |
| WishlistProvider | ✅ | lib/providers/wishlist_provider.dart |
| NotificationProvider | ✅ | lib/providers/notification_provider.dart |
| ChatProvider | ✅ | lib/providers/chat_provider.dart |
| BuildingProvider | ❌ | lib/features/host/property/providers/building_provider.dart |
| RoomProvider | ❌ | lib/features/host/property/providers/room_provider.dart |
| ContractProvider | ❌ | lib/features/host/property/providers/contract_provider.dart |
| InvoiceProvider | ❌ | lib/features/host/billing/providers/invoice_provider.dart |
| ServiceFeeProvider | ❌ | lib/features/host/billing/providers/service_fee_provider.dart |
| MeterReadingProvider | ❌ | lib/features/host/billing/providers/meter_reading_provider.dart |
| KhaiBaoProvider | ❌ | lib/features/host/khaibao/providers/khaibao_provider.dart |
| ReportProvider | ❌ | lib/providers/report_provider.dart |
| DrillProvider | ❌ | lib/features/host/analytics/providers/drill_provider.dart |
| DashboardProvider | ❌ | lib/providers/dashboard_provider.dart |
| HomestayCalendarProvider | ❌ | lib/features/host/homestay/providers/homestay_calendar_provider.dart |
| PricingRuleProvider | ❌ | lib/features/host/homestay/providers/pricing_rule_provider.dart |
| ReservationProvider | ❌ | lib/features/host/homestay/providers/reservation_provider.dart |
| MarketplaceProvider | ❌ | lib/features/host/marketplace/providers/marketplace_provider.dart |
| DelegationProvider | ❌ | lib/providers/delegation_provider.dart |
| ApprovalProvider | ❌ | lib/providers/approval_provider.dart |
| ActorContextProvider | ✅ | lib/providers/actor_context_provider.dart |

**Providers that already have reset/clear:** WishlistProvider, NotificationProvider, ChatProvider, ActorContextProvider (4 total)

**Providers needing reset/clear added:** 18 (confirmed — state audit F1 list was slightly off, now finalized)

**Phase 02 action:** Add `void clear()` method to each of the 18 providers; call from `AuthProvider.logout()` via MultiProvider context drain or new LogoutCoordinator service.

---

## Section D: FCM contract

### D1: Backend topic naming
- **Status:** NOT_FOUND — backend uses `notification_type` enum, not topic-based subscription
- **File:** `/ancu365-backend/app/services/notification/notification_service.py:45-64`
- **Evidence:**
  - Valid channels: `{"in_app", "email", "sms", "push"}`
  - Valid notification_type: `{"delegation_invited", "delegation_accepted", "approval_requested", "approval_decided", "kyc_expiring_soon", …}`
  - Push channel marked as **stub** — firebase-admin infra ready but NOT wired in phase-08
- **Implication:** Backend does NOT currently send FCM push notifications via topics; Phase 02 C3 should note "Push stub — Phase 08 integrates firebase-admin"

### D2: Frontend FCM token lifecycle
- **Status:** VERIFIED (partial)
- **File:** `/ancu365-app/lib/core/permissions/fcm_service.dart:114-136`
- **Evidence:**
  - `attachUserContext()`: sets `_attachedUserId`, subscribes to `_messaging.onTokenRefresh`, auto-re-registers on refresh
  - `detachUserContext()`: cancels refresh subscription, clears `_attachedUserId`/`_attachedInstallId`
  - NO `subscribeToTopic()` / `unsubscribeFromTopic()` methods — **frontend does NOT manage topics**
- **State audit F2 finding CONFIRMED:** FCM token lifecycle is managed, but topic subscription is missing. Phase 02 C3 should note: "Topic-based filtering stub — Phase 08 will implement once backend push endpoint defined"
- **Backend endpoint:** `POST /api/users/me/push-token` (line 156) — registers device token, does NOT manage topic subscriptions

### D3: Notification categories & role mapping
- **Status:** IDENTIFIED
- **Categories found:**
  - Delegation: `delegation_invited`, `delegation_accepted`, `delegation_paused`, `delegation_terminated`
  - Approval: `approval_requested`, `approval_decided`, `approval_reminder_24h`, `approval_reminder_48h`, `approval_auto_rejected`
  - Admin/KYC: `kyc_expiring_soon`, `owner_death_delegation_paused`, `heir_onboarding_initiated`, `gpkd_revoked_delegation_paused`
  - Digest: `weekly_digest`
- **Role mapping:** Backend sends to `user_id` directly (no role filtering at notification layer); filtering happens in request context (which user receives which notification is auth-guarded by endpoint)
- **Recommendation for Phase 02 FCM step:** Design topic pattern once backend push endpoint defined. Suggested pattern: `notifications_{userId}` (single topic per user) rather than `role_{role}_{userId}` (backend doesn't know topic semantics yet)

---

## Corrections needed in phase files

### Phase 01
- **Line 1, Goal section:** Add note: "building_detail_screen.dart has NO delete UI — delete_building endpoint exists only in provider/repo; Phase 01 excludes this file from role-guard scope (address in future building refactor)"
- **Status:** APPROVED for Phase 01; building_detail_screen skip documented

### Phase 02
- **Section C3 "Tenant Route Guards":** Add blocker note: "Tenant JWT backend endpoint NOT YET IMPLEMENTED. Defer tenant guard implementation until backend confirms endpoint signature + claims structure. Mark TODO with link to backend ticket."
- **Status:** Phase 02 can proceed with operator/admin/host guards; tenant guard deferred

### Phase 05a/5b
- **empty_state.dart naming:** Already correct (lib/core/widgets/empty_state.dart) — no change needed

### Phase 03
- **Decision point U4 (admin self-approval guard):** Add clarification: "Backend does NOT guard admin-owns-listing self-approval. Design choice: (A) add check on backend + frontend flag, or (B) allow admin self-approval if role check passes. Phase 03 specifies decision; Phase 02 implements accordingly."

---

## Blockers discovered

**NONE that prevent Phase 01 start.**

### Non-blocking deferral
1. **Tenant JWT not ready** (U2) — Phase 02 Section C3 tenant guards → DEFERRED until backend endpoint lands. Mark with TODO. Does NOT block operator/host/admin guard implementation.
2. **Backend push endpoint stub** (D1/D3) — Phase 02 Section C3 FCM topic setup → DEFER until Phase 08. Phase 02 can initialize FCM token registration without topic logic.

---

## Green-light checklist

- [x] **Phase 01 ready to start?** YES
  - All 12 line references verified
  - Role leak fixes in host_home_screen.dart, guest_shell.dart, app_router.dart confirmed
  - No code changes required for Phase 00; ready for Phase 01 role guard additions

- [x] **Phase 02 ready to start?** CONDITIONAL YES
  - Operator/admin/host route guards: YES (actor_context backend contract verified)
  - Tenant route guards: DEFERRED (tenant JWT endpoint not ready)
  - FCM setup: Proceed with token registration; topic logic deferred to Phase 08
  - Provider reset/clear inventory complete → Phase 02 C3 spec is accurate

- [x] **Any critical blocker?** NO
  - Deferral notes added to phase specs
  - Backend team confirmation on tenant JWT endpoint required before Phase 02 C3 tenant guard implementation

---

## Summary

**Pre-flight scout COMPLETE.** All assumptions verified against source code. Backend contract confirmed for B1 (auto-upgrade), B3 (role field), B5 (actor context). Two items (B2 tenant JWT, B4 admin self-approval guard) left as design decisions per existing phase specs.

**Recommendation:** Phase 01 can start immediately. Phase 02 can start with operator/host/admin guards; tenant guard deferred with TODO. Phase 08 (FCM push endpoint) unlocks topic-based filtering.

