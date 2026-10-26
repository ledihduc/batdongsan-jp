# Phase 07 — Frontend Delegation UI (Flutter)

## Context Links

- BA v4 §6.2 (Context-switching AC-11..AC-18), §6.3 (Permissions AC-19..AC-23 UI), §6.6 (Audit AC-38..AC-41), §6.7 (Termination UI AC-42), §6.8 (Non-regression AC-47..AC-54), §6.11 (AC-60..AC-63 tenant badges + ownership attestation prompt), §6.12 (NFR-08..NFR-12 mobile-first + i18n)
- US-O1..O14 (owner invite/manage/audit views); US-O15 ("Mình" mode read-only); US-P1..P13 (operator dashboard + switcher); US-T1 (tenant authority badge)
- Research: `researcher-03-flutter-app.md` (Provider state mgmt, go_router, persona-switcher pattern in `guest_shell.dart`, `Ds*` widget library, `HD.*` design tokens, FCM notification tap routing)
- Prereq phases: 02 (backend actor context + `X-Acting-As-Delegation-Id` header contract), 03 (delegation lifecycle endpoints), 04 (approval endpoints), 05 (operator KYC flow + ActorContextProvider for KYC blocks)

## Overview

**Priority:** P0 (no UI = feature is invisible)
**Status:** Pending
**Brief:** Flutter screens + providers for delegation invitation, operator portfolio with persona-switcher overlay, owner approval inbox, audit activity feed, tenant authority badge. Reuses Editorial Cockpit `HD.*` design tokens + `Ds*` widget barrel. New `ActorContextProvider` (request-scoped, non-persisted) injects `X-Acting-As-Delegation-Id` header via `ApiClient` interceptor. Persona-switcher pattern (`guest_shell.dart`) extended for "acting-as" warm-orange overlay.

## Key Insights from Research

- **Provider, not Riverpod** (researcher-03 §A): 23 providers already at root in `main.dart`. Add 3 new: `ActorContextProvider`, `DelegationProvider`, `ApprovalProvider`. Register in `main.dart` MultiProvider list (file ownership: 07 only — append-only).
- **go_router with role-based redirect** (researcher-03 §A): `app_router.dart` L73–98 already gates by `currentUser?.role`. Add `/operator` route family (parallel to `/host`) + redirect logic for users with active delegations.
- **Persona-switcher precedent** (researcher-03 §D): `lib/features/guest/guest_shell.dart` is Airbnb-style toggle (guest ↔ host). **DO NOT REUSE for delegation** — that switcher is session-persistent. Delegation context must be **request-scoped** (AC-15, AC-15b) — new pattern `ActorContextProvider` does NOT persist to `UserPrefsService`, resets on app cold start.
- **Editorial Cockpit DS** (researcher-03 §F): `HD.paper`, `HD.ink`, `HD.accent`, `HD.warning` + `Ds*` barrel cover 95% of needed components. Acting-as overlay = `HD.warning` (warm orange #B5462E variant) on `DsAppBar` + eyebrow label.
- **FCM notification tap routing** (researcher-03 §C): `lib/features/permissions/helpers/notification_tap_router.dart` exists; extend with `approval_requested`, `delegation_invited`, `delegation_paused` notification types → deep-link with embedded `delegation_id` so cold-start tap auto-acquires actor context (AC-15b).
- **Image cache tuning** (researcher-03 §I-Risk 9): main.dart L146 tuned for ~2000 items; operator managing 50+ properties may bloat. Mitigation: paginate portfolio + lazy-load thumbnails (NFR-09 portfolio screen p95 ≤ 2.5s on 3G).

## Requirements (mapped to BA v4)

| AC / NFR / US | Covered by step |
|---------------|-----------------|
| AC-11..AC-12 | Step 3 (OperatorPortfolioScreen with KPI cards) |
| AC-13..AC-14 | Step 4 (context-switch + warm-orange header overlay + "Thoát" button) |
| AC-15, AC-15b, AC-16, AC-16b | Step 2 (`ActorContextProvider` request-scoped + 401 `DELEGATION_REVOKED` → force back to portfolio) |
| AC-17 | Step 5 (Owner sees no switcher — conditional render) |
| AC-18 | Step 5 ("Mình mode" read-only enforcement on owner side) |
| AC-19..AC-22 | Step 6 (permission-aware UI: hide/disable forbidden buttons; "request approval" CTA for above-threshold actions) |
| AC-23 | Step 6 (every mutation passes actor context through header — invisible to UI but tested) |
| AC-29..AC-31 | Step 7 (ApprovalInboxScreen + 1-tap approve/reject + biometric prompt for ≥50M VND) |
| AC-38..AC-41 | Step 8 (ActivityFeedScreen — timeline with filters; weekly digest banner) |
| AC-47..AC-48 | Step 9 (self-managed regression — `ActorContextProvider.actingAs == null` path unchanged) |
| AC-49 | Step 4 (mid-contract delegation activation: tenant contact stays owner; operator badge only) |
| AC-53 | Step 6 (bank account `****1234` masking in operator view) |
| AC-54 | Phase 09 PDF generation; phase-07 only displays disclosure preview |
| AC-60 | Step 10 (tenant home + contract detail badge "Operator: X | Owner: Y") |
| AC-63 | Step 10 (tenant in-app channel "report not my representative") |
| AC-64 | Step 11 (sole-ownership attestation modal at owner onboarding — blocks delegation creation if NO) |
| AC-66 | Step 12 (shared-login disclosure modal at operator-doanh-nghiệp first login) |
| NFR-08 | Android 7.0 build target (gradle.properties verification) |
| NFR-09 | Step 3 (portfolio pagination + lazy thumbnails) |
| NFR-10 | Step 5 (image_picker compression to ≤800KB) |
| NFR-11 | Step 7 (offline-tolerant approval / cash receipt draft) |
| NFR-12 | Step 10 (NFC normalization on name fields + Vietnamese diacritic-safe rendering) |
| US-O15 | Step 5 (read-only "Mình" mode when delegation active) |
| US-T1 | Step 10 (tenant badge) |

## Architecture

### Provider tree (additions)

```
MultiProvider (lib/main.dart)
  └── existing 23 providers
  ├── ChangeNotifierProvider<ActorContextProvider>     [NEW — request-scoped, non-persisted]
  ├── ChangeNotifierProvider<DelegationProvider>       [NEW — delegation list + invitation state]
  └── ChangeNotifierProvider<ApprovalProvider>         [NEW — approval inbox + polling 30s]
```

### Actor context flow (request-scoped per AC-15)

```
[ApiClient.request()]
   |
   v
[ActorContextProvider.currentDelegationId]
   |
   v (if non-null)
[HTTP header injected: 'X-Acting-As-Delegation-Id: <uuid>']
   |
   v
[Backend resolve_actor_context()]
   |
   +--- 200 OK + actor_context payload
   |
   +--- 401 DELEGATION_REVOKED → ActorContextProvider.clear() + go_router.go('/operator')
```

### Acting-as overlay (warm orange theme variant)

```
DsAppBar (Default — HD.paper background, HD.ink text)
   |
   v (when ActorContextProvider.actingAs != null)
DsAppBar (HD.warning tint background, HD.paper text)
  + Eyebrow: "Đang đại diện cho [Owner Name]"
  + Trailing: "← Thoát" button → ActorContextProvider.clear()
```

### Route map

```
/operator                  → OperatorPortfolioScreen (list of owners delegated)
/operator/owner/:id        → OperatorWorkspace (sets actor context on entry, calls existing /host/* screens under it)
/operator/owner/:id/audit  → ActivityFeedScreen
/operator/invitations      → InvitationInboxScreen (operator views pending invites)
/host/delegation/invite    → DelegationInviteScreen (owner-side)
/host/delegation/:id       → DelegationDetailScreen (owner manages active delegation)
/host/approvals            → ApprovalInboxScreen (owner-side queue)
```

## Related Code Files

### Create

- `lib/providers/actor_context_provider.dart` — new
- `lib/providers/delegation_provider.dart` — new
- `lib/providers/approval_provider.dart` — new
- `lib/data/services/delegation_api_repository.dart` — new (wraps ApiClient for delegation endpoints)
- `lib/data/services/approval_api_repository.dart` — new
- `lib/data/models/operator_delegation_model.dart` — new
- `lib/data/models/delegation_invitation_model.dart` — new
- `lib/data/models/approval_request_model.dart` — new
- `lib/features/operator/portfolio/operator_portfolio_screen.dart` — new
- `lib/features/operator/portfolio/owner_card_widget.dart` — new
- `lib/features/operator/workspace/operator_workspace_shell.dart` — new (acting-as overlay wrapper)
- `lib/features/operator/invitations/invitation_inbox_screen.dart` — new
- `lib/features/operator/invitations/invitation_accept_screen.dart` — new
- `lib/features/host/delegation/delegation_invite_screen.dart` — new
- `lib/features/host/delegation/delegation_detail_screen.dart` — new
- `lib/features/host/delegation/threshold_config_widget.dart` — new (5 threshold inputs per AC-31b)
- `lib/features/host/approvals/approval_inbox_screen.dart` — new
- `lib/features/host/approvals/approval_card_widget.dart` — new
- `lib/features/host/approvals/biometric_confirm_widget.dart` — new (for AC-29b ≥50M VND)
- `lib/features/audit/activity_feed_screen.dart` — new
- `lib/features/audit/audit_timeline_widget.dart` — new
- `lib/features/tenant/widgets/authority_badge_widget.dart` — new (AC-60)
- `lib/features/tenant/screens/report_unauthorized_operator_screen.dart` — new (AC-63)
- `lib/features/host/onboarding/sole_ownership_attestation_dialog.dart` — new (AC-64)
- `lib/features/operator/onboarding/shared_login_disclosure_dialog.dart` — new (AC-66)
- `lib/core/widgets/acting_as_app_bar.dart` — new (warm-orange overlay variant)
- `lib/l10n/delegation_strings.dart` — new (Vietnamese + English string dict)

### Modify

- `lib/main.dart` — register 3 new providers in MultiProvider list (append-only, end of list)
- `lib/data/services/api_client.dart` — interceptor injects `X-Acting-As-Delegation-Id` header when ActorContextProvider has value (single addition; existing methods untouched)
- `lib/core/router/app_router.dart` — add `/operator/*` route family + redirect logic for users with active delegations
- `lib/features/permissions/helpers/notification_tap_router.dart` — extend for delegation notification types
- `lib/features/host/property/screens/contract_detail_screen.dart` — display dual-disclosure preview snippet (PDF rendered server-side; phase-09 owns generation)
- `lib/features/host/property/widgets/tenant_row_widget.dart` (or equivalent) — add `AuthorityBadgeWidget` when operator manages tenant
- `lib/features/host/home/host_home_screen.dart` — add "Pending Approvals" badge + entry to ApprovalInboxScreen

### Delete

- None.

## Implementation Steps

1. **ApiClient interceptor for actor context** (lib/data/services/api_client.dart) — single-point injection: if `ActorContextProvider.currentDelegationId != null`, attach `X-Acting-As-Delegation-Id: <uuid>` header to every request. Also handle 401 with code `DELEGATION_REVOKED` → call `ActorContextProvider.clear()` + force `go_router` to `/operator`. AC-15b cross-tab safety: state is per ApiClient instance (one per app, not per tab — Flutter mobile single-instance is fine; for web build, each tab has own Provider tree).
2. **ActorContextProvider** — `ChangeNotifier` with `currentDelegationId`, `actingAsOwner` (cached UserModel), `permissionSet` (loaded on context switch). Methods: `enterContext(delegationId)`, `clear()`, `refresh()`. **NOT persisted to UserPrefsService** (AC-15 request-scoped).
3. **OperatorPortfolioScreen** — list of owner cards. Each card: owner name, property count, MTD revenue, pending action count, alert badge. Pagination via `ListView.separated` + `pageSize=20`. Lazy load thumbnails via `cached_network_image` (already in pubspec). NFR-09 perf target.
4. **Context switch flow** — tap owner card → `ActorContextProvider.enterContext(delegationId)` → push `/operator/owner/:id` → `OperatorWorkspaceShell` wraps existing host screens with `ActingAsAppBar` (orange tint + eyebrow + Thoát button). On Thoát or hardware back → `ActorContextProvider.clear()` + go_router pop.
5. **Owner "Mình" mode** (AC-17, AC-18) — When owner has active delegation, host screens show read-only banner: "Bạn đã uỷ thác Operator X. Để chỉnh sửa, tạm pause delegation." Mutation buttons disabled + tooltip explains. Owner has no switcher (AC-17). Onboarding tour explains "tài sản của tôi mà phải xin?" framing (BA §10.7 mitigation).
6. **Permission-aware UI** — `OperatorDelegationModel.permissionSet` (Set<String>) drives `canTerminateContract()`, `canEditBankAccount()`, `canViewBankFull()`, etc. Forbidden buttons hidden in `viewer`; above-threshold buttons converted to "Request approval" CTA in `operator_full` + `accountant`. Bank account display: `****1234` until owner one-time consent (separate modal — phase-09 owns reveal endpoint).
7. **ApprovalInboxScreen** — owner-side queue: list of pending approvals. Each row: operator name, action type (contract, expense, refund, etc.), amount, requested_at, ETA (72h or 6h KB04 fast-track). Tap row → ApprovalDetail bottom-sheet with full payload + 1-tap approve/reject. **AC-29b biometric:** if amount ≥ 50M VND → `local_auth` biometric prompt before commit. Offline draft (NFR-11): approval decision queued in sqflite, synced when online.
8. **ActivityFeedScreen** — timeline of operator actions on owner's property (AC-38). Filters: today / week / month, by entity type. Each row: timestamp, operator avatar, action description, link to entity. Export PDF/Excel via existing `host_export.py` extension (phase-09). Weekly digest banner shows summary at top.
9. **Self-managed regression** (AC-47, AC-48) — when `ActorContextProvider.actingAs == null` and user has no active delegations: zero behaviour change. Audit via integration test that golden-snapshots host_home_screen pre/post phase-07.
10. **Tenant authority badge** (AC-60, AC-63) — extend tenant home + contract detail + invoice chat with `AuthorityBadgeWidget`: small DsChip "Đại diện: [Operator] | Chủ: [Owner]". On tap → bottom sheet shows operator KYC verification status + "Report unauthorized" button (AC-63). NFR-12: NFC-normalize names; ensure `Be Vietnam Pro` font renders Vietnamese diacritics correctly on Android + iOS.
11. **Sole-ownership attestation** (AC-64) — first time owner clicks "Invite Operator", DsDialog: "Tài sản này có đăng ký dưới tên duy nhất của bạn (sổ đỏ chính chủ)?" with YES/NO. NO → block + show "v1 chỉ hỗ trợ chính chủ; tính năng đồng sở hữu launching v2 Q4 2026". YES → click-acknowledge ToS indemnity → persist `building.sole_ownership_attested_at` via API → proceed to invite.
12. **Shared-login disclosure** (AC-66) — operator-doanh-nghiệp first login after invite accept: DsDialog with 3 disclosure points (audit under single account, password rotation = company responsibility, per-user RBAC v2). "Tôi hiểu" button required to proceed. Acknowledgment timestamp via API to backend `delegation.shared_login_disclosure_ack_at`.
13. **Notification tap routing** — extend `notification_tap_router.dart` for `approval_requested` → ApprovalInboxScreen + auto-acquire context from payload `delegation_id`; `delegation_invited` → InvitationInboxScreen; `delegation_paused` → DelegationDetailScreen.

## Todo List

- [ ] Create 3 providers (`ActorContextProvider`, `DelegationProvider`, `ApprovalProvider`)
- [ ] Register providers in `main.dart` MultiProvider (append-only)
- [ ] Modify `api_client.dart` interceptor for header injection + 401 handling
- [ ] Create 2 API repositories (delegation, approval)
- [ ] Create 3 data models with fromJson/toJson
- [ ] Build OperatorPortfolioScreen + OwnerCard widget
- [ ] Build OperatorWorkspaceShell + ActingAsAppBar
- [ ] Build InvitationInboxScreen + InvitationAcceptScreen
- [ ] Build DelegationInviteScreen + ThresholdConfigWidget (5 threshold inputs)
- [ ] Build DelegationDetailScreen (owner manage view: pause/resume/terminate)
- [ ] Build ApprovalInboxScreen + ApprovalCard + BiometricConfirmWidget (for ≥50M)
- [ ] Build ActivityFeedScreen + AuditTimelineWidget
- [ ] Build AuthorityBadgeWidget for tenant views
- [ ] Build ReportUnauthorizedOperatorScreen
- [ ] Build SoleOwnershipAttestationDialog + SharedLoginDisclosureDialog
- [ ] Extend go_router with `/operator/*` routes + redirect logic
- [ ] Extend notification_tap_router for delegation notification types
- [ ] Add Vietnamese + English strings to `delegation_strings.dart`
- [ ] Unit tests: ActorContextProvider state transitions, ApiClient interceptor behavior, permission gates
- [ ] Widget tests: ApprovalCard rendering states, AuthorityBadge visibility, OperatorWorkspaceShell overlay
- [ ] Integration tests: end-to-end invite → accept → portfolio → context-switch → approval

## Success Criteria

- **AC-11..AC-14:** Operator logs in, sees portfolio with N owner cards, taps card, header turns warm-orange with eyebrow, Thoát button returns to portfolio.
- **AC-15, AC-15b:** Two browser tabs (or simulated two devices) can hold different delegation contexts simultaneously; no state bleed.
- **AC-16b:** Owner pauses delegation while operator is mid-session → next API call returns 401 DELEGATION_REVOKED → UI auto-redirects to portfolio + shows toast.
- **AC-18:** Owner with active delegation cannot mutate; UI shows read-only banner; pause button visible.
- **AC-29b:** Approval for ≥50M VND triggers biometric prompt (local_auth) before commit; cancel returns to inbox.
- **AC-47, AC-48:** Self-managed host snapshot tests pass unchanged.
- **AC-60:** Tenant home shows authority badge; tap reveals operator info + "Report" button.
- **AC-64, AC-66:** Sole-ownership + shared-login modals shown exactly once per delegation creation; ack timestamp persisted.
- **NFR-09:** Portfolio screen p95 ≤ 2.5s on simulated 3G (measured via Flutter DevTools).

## Risk Assessment

- **R1 — Persona-switcher antipattern reuse:** Strong temptation to reuse `guest_shell.dart` session-persistent toggle for delegation. Mitigation: code review checklist explicitly forbids it; `ActorContextProvider` must not write to `UserPrefsService`.
- **R2 — ApiClient interceptor refactor risk:** Single point of change in `api_client.dart`; if broken, all API calls fail. Mitigation: feature flag `ENABLE_DELEGATION_HEADER=false` at first; ramp up after smoke tests pass. Researcher-03 risk option B (repository-level injection) is fallback if interceptor proves fragile.
- **R3 — Permission gate drift between client and server:** Hiding a button client-side but missing server check = security hole. Mitigation: server enforces all permissions (phase-02); client UI is hint-only. Integration test asserts "operator hits forbidden endpoint with `viewer` role → 403".
- **R4 — Notification tap with stale context:** Tap arrives after delegation paused → 401 loop. Mitigation: tap router calls `actorContext.enterContext(delegationId)` + handles 401 → toast + redirect (not retry).
- **R5 — Image cache bloat in operator portfolio:** Operator with 50+ properties × 5 photos each = 250+ thumbnails. Mitigation: NFR-09 paginate (20/page) + `cached_network_image` thumbnails (small variant). Disable image preload on operator portfolio.
- **R6 — Vietnamese diacritics in PDF preview** (NFR-12): existing Be Vietnam Pro bundled; verify on Android viewer (some skia variants strip combining marks). Mitigation: golden tests for diacritic rendering in widget tests.
- **R7 — Provider memory leak when switching context fast:** ActorContextProvider clears cache; if not properly disposed, stale providers retain owner data. Mitigation: explicit `_disposeAllContextCaches()` on `clear()`.

## Security Considerations

- **No delegation state cached in SecureStorage / SharedPreferences** (AC-15, NFR-07). `ActorContextProvider` is in-memory only.
- **401 DELEGATION_REVOKED handling** must clear all delegation-derived state (UI cache, image cache for that owner) — not just the actor context.
- **Sole-ownership attestation TOS link** must point to live ToS page; broken link = legal exposure for owner.
- **Tenant report unauthorized** (AC-63) must not leak operator full PII; show only name + verification status.
- **Bank account masking** (AC-53) is client-side render only — server still returns masked unless `consent_grant_token` provided.
- **Biometric prompt** (AC-29b): `local_auth` fallback to PIN if no biometric enrolled; never silently skip.

## Estimated Effort

**10 dev-days** = 2 FE devs × 5d in parallel (one focused on owner-side screens, one on operator-side). Includes all 17 new files, modifications to 6 existing files, widget + integration tests, and i18n string dictionary. Persona-switcher overlay reuse + DS widget barrel keeps scope manageable.

## Next Steps / Dependencies

- **Blocks:** Phase 11 (testing — full E2E flows depend on UI being complete).
- **Blocked by:** Phase 02 (header contract + actor context resolution endpoints), Phase 03 (delegation lifecycle endpoints), Phase 04 (approval endpoints + biometric flag), Phase 05 (KYC blocks for operator onboarding screens — partial integration only).
- **Independent:** Phase 08 (notification backend — phase-07 only consumes notification payloads), Phase 09 (PDF generation — phase-07 only renders preview), Phase 10 (admin UI — completely separate).

## Open items flagged

- **Q-DD4** — email deliverability liability if Segment C owners (50-70 y.o.) don't open emails → UI cannot fix; phase-07 displays escalation status in approval modal ("Owner notified via email at 14:15") so operator/tenant transparency is maintained.
- **NFR-12 Android diacritic verification** — needs device farm testing (low-end Android 7 + Huawei without GMS); ship phase-11 device matrix.
- **AC-29b biometric on Huawei without GMS** (researcher-03 §I-N3) — biometric available via Huawei FingerprintManager; local_auth fallback path verified in phase-11.
