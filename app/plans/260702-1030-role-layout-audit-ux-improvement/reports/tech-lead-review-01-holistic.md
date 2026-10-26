# Tech Lead Review — Role Layout Audit Plan

**Date:** 2026-07-02
**Reviewer:** Tech Lead (holistic review)
**Plan:** `plans/260702-1030-role-layout-audit-ux-improvement/`

## Executive Summary

**Verdict: APPROVE_WITH_REVISIONS.** Plan is well-structured, phase boundaries logical, research reports strong. However there are 4 CRITICAL scope gaps (state/cache lifecycle, deep-link during role change, FCM routing per role, mid-implementation rollback) and 6 HIGH gaps (test strategy, Phase 04 estimate optimism, non-goal contradictions, backend contract validation, Phase 02/03 dependency inversion, delegation revocation flow). Recommend fixing findings below then greenlight. Do NOT start Phase 04 until Phase 03 decisions are locked.

## Findings

### CRITICAL (blockers)

**C1. State/cache eviction on role change is not addressed anywhere.**
- Evidence: Phase 02 adds `actor.clear()` on logout. Phase 04 mentions cold-start flash. But no phase covers: guest→host auto-upgrade eviction of WishlistProvider/BookingProvider caches; host→admin (rare) eviction of host caches; operator context exit clearing PropertyProvider cache scoped to owner X. Researcher-04 line 316-328 flags exactly this risk ("_reconcileWithRole re-evaluates on next build — window exists") but plan does not address.
- Why: Guest sees own wishlist; upgrades to host mid-session; without cache eviction, guest data (wishlists, bookings) persists in host shell as ghost state. Similar for operator exiting context — previous owner data leaks into next owner drill-down.
- Fix: Add new sub-section in Phase 02 titled "Provider cache invalidation on role/persona change". Enumerate every provider holding role-scoped state (WishlistProvider, BookingProvider, PropertyProvider, ContractProvider, DelegationProvider). Define `clearOnRoleChange()` on each. Wire into AuthProvider `_detectAndHandleRoleChange` + ActorContext `clear()`.

**C2. Deep-link handling during pending role change / bootstrap is undefined.**
- Evidence: Phase 02 lists 6 test scenarios but none cover: user cold-starts app via deep-link `/host/analytics` while auth still bootstrapping AND delegation still loading. Phase 04 risk section says "cold-start flash" but only shell-level. No explicit ordering for router redirect + provider bootstrap + FCM handoff.
- Why: `refreshListenable: Listenable.merge([auth, delegation])` (proposed in Phase 02 step 4) will fire redirect multiple times as each provider loads. Deep-link `/operator/owner/123` could route to `/` first (delegation not loaded → guard fails), then delegation loads and shell repaints. User sees broken navigation.
- Fix: Add explicit "bootstrap ordering" section in Phase 02: (1) Auth bootstraps first, (2) Delegation bootstraps only if auth succeeds, (3) Router `redirect` returns `null` (no redirect) while any bootstrap flag is true, (4) Deep-link stored in pending queue and replayed after bootstrap. Add test scenario #7: cold-start with `/operator/owner/123` deep-link.

**C3. FCM / notification routing per role not addressed.**
- Evidence: `auth_provider.dart:113-131` calls `_permissionService!.onLogout(userId)` to delete FCM tokens. Phase 04 introduces AdminShell, OperatorShell, TenantShell but never mentions notification handling. Push notification arrives for `/host/approvals/456` — which shell handles it? If admin gets notif meant for host persona, where does deep-link land?
- Why: Notifications are a per-role concern (host gets booking notifs, operator gets delegation notifs, tenant gets contract notifs). Without routing map, notif tap during wrong shell = broken UX or wrong-role screen exposure.
- Fix: Add small subsection "Notification deep-link routing per shell" in Phase 04. Enumerate: notification categories × role. Route through role-aware handler that (a) checks displayed role can handle notif, (b) if wrong role, defer or discard, (c) if right role but wrong shell tab, switch tab.

**C4. No rollback strategy if Phase 03 chosen option proves wrong mid-Phase-04.**
- Evidence: Phase 03 says "Option B has no exit path (backend migration hard to rollback)" but Phase 04 has no feature flag or dual-code path. If team chooses Option A and mid-Phase-04 discovers operator shell truly needs `role='operator'` in auth → must abandon Phase 04 work.
- Why: 2 days of shell work potentially wasted; no incremental deploy of Phase 04.
- Fix: Add "Rollout gates" section in `plan.md`. Between Phase 03 and Phase 04, require: (a) unit test of `DisplayedRoleProvider` for all 5 role permutations passing before starting shell work, (b) design doc `role-model.md` reviewed by product before shell implementation begins, (c) shell work behind feature flag `role_shells_v2_enabled` for A/B rollback.

### HIGH (should fix before impl)

**H1. Test strategy is smoke-test only — no automated coverage.**
- Evidence: Every phase ends with "smoke test N kịch bản" or "manual smoke test". No mention of unit tests for RoleGuard, DisplayedRoleProvider, route_guards.dart pure functions. Phase 07 modularization has "diff visual identical" but no widget test.
- Why: Phase 02 route_guards are pure functions — perfect for unit tests. Without them, regression risk on future auth changes is high. Phase 03 DisplayedRoleProvider matrix (5 roles × auth × delegation × JWT) has combinatorial complexity; smoke test cannot cover.
- Fix: Add "Testing" subsection to each phase: Phase 01 unit test for RoleGuard.canHost/canAdmin + PermissionDeniedException throws; Phase 02 unit test for each guard function (guardHostRoutes etc.) with truth table; Phase 03 unit test for DisplayedRoleProvider covering all 5×N permutations; Phase 04 widget test for shell selection based on DisplayedRole; Phase 07 golden test for split screens.

**H2. Phase 04 estimate (2 days) is optimistic for 3 new shells + role-aware Profile.**
- Evidence: Phase 04 creates AdminShell, OperatorShell, TenantShell + role switcher + Profile section refactor + role badge fix. Researcher-04 shows guest_shell.dart is 316+ lines with complex persona/bootstrap logic; each new shell needs comparable state + smoke pass.
- Why: 3 shells × ~200 LOC + integration + smoke = closer to 3-4 days. Underestimate cascades to entire plan.
- Fix: Revise Phase 04 to 3-4 days OR defer TenantShell to a follow-up phase (guarded by Phase 03 decision). Update `plan.md` total from 11-12 to 13-14 days.

**H3. Non-goal contradictions.**
- Evidence: `plan.md` line 59 says "Không refactor backend (trừ khi decision phase 03 chọn thêm role)" but Phase 02 non-goals line 108 says "Không đổi API contract cho X-Acting-As-Delegation-Id" — inconsistent because Phase 03 Option B directly requires backend enum + migration + role parsing changes. Phase 02 line 63 adds `actor.clear()` call to auth_provider.logout(); Phase 02 out-of-scope says "Không refactor ActorContext" — the clear() call IS a coupling change.
- Why: Ambiguous non-goals cause scope creep debate mid-implementation.
- Fix: Rewrite non-goals per phase precisely. Phase 02: "Không refactor ActorContextProvider internals; ONLY add clear() call from AuthProvider". Plan-level: "No backend changes unless Phase 03 Option B is chosen — in which case backend work spins into separate parallel plan."

**H4. Assumptions in Phase 01 not scout-verified.**
- Evidence: Phase 01 line 16 assumes "Auto-upgrade guest→host (server returns new JWT khi guest post first listing)" — but researcher reports do not confirm this backend behavior exists. Phase 01 line 61 assumes FAB in guest_shell can gate to dialog without breaking auto-upgrade flow. `_confirmDelete()` referenced at line 590-625 needs verify that line range matches current code.
- Why: If backend does not auto-return JWT on first post, guest confirm-dialog UX is broken (guest submits, still marked guest, next screen fails). Line references in Phase 01 could be stale.
- Fix: Add "Pre-flight scout" step at start of Phase 01: (a) grep backend endpoint for "role upgrade" or POST `/houses` behavior, confirm JWT response; (b) verify all cited line numbers in phase files match current HEAD. Block Phase 01 start until scout report attached.

**H5. Phase 02 depends on Phase 03 for guard signature, but Phase 02 comes first.**
- Evidence: Phase 02 step 1 defines `guardOperatorRoutes(loc, auth, delegation)` accepting DelegationProvider. Phase 03 step "Refactor route_guards.dart dùng DisplayedRole" says guards should later use DisplayedRole enum. This is double-write.
- Why: Phase 02 built with 3-arg signature; Phase 03 rewrites to use DisplayedRole. Waste + risk of stale guard code confusing later maintainers.
- Fix: Either (a) reorder to run Phase 03 spec (0.5 day) BEFORE Phase 02 impl, so guards written once against DisplayedRole; or (b) explicitly note in Phase 02 "guards are throwaway v1 — will refactor in Phase 03". Prefer (a).

**H6. Delegation revocation flow (AC-16b) missing from any phase.**
- Evidence: Researcher-04 line 219-225 flags "Operator acting as owner → API revokes → UI must catch 401 with code='DELEGATION_REVOKED' and clear actor context". Researcher-04 P1 rec #7 says this needs E2E test. No phase in plan covers this.
- Why: Revoked delegation mid-session = operator continues submitting requests with dead header until 401. UI must intercept and gracefully return to portfolio.
- Fix: Add small section in Phase 02 or new Phase 02b: "Delegation revocation handler". ApiClient error interceptor for `code='DELEGATION_REVOKED'` → `actor.clear()` + navigate to `/operator` + toast. Add test scenario in Phase 02.

### MEDIUM (nice to fix)

**M1. No Sentry / error monitoring plan.** Role guard failures should log to monitoring (fail-safe: if guard misbehaves in prod, we need to know). Add note to Phase 01/02.

**M2. Analytics events per role absent.** New shells (AdminShell, OperatorShell) need analytics screen-view events per role for product KPIs. Add note to Phase 04.

**M3. Phase 05 estimate (2-3 days) for 40+ file audit + tokens + snackbar migration + AppBar retrofit + color replace + error states is optimistic.** More realistic 3-4 days. Recommend splitting Phase 05 into 05a (tokens + snackbar + DsAppBar retrofit) and 05b (error/loading/empty state sweep).

**M4. Phase 07 modularization has no dependency on Phase 05 but should — DsAppBar refactor + file split ordering matters.** If Phase 07 runs first, split files then Phase 05 rewrites AppBars in each = double edit. Add dependency Phase 07 depends on Phase 05.

**M5. Audit logging of role changes not called out.** When guest→host auto-upgrade triggers, security audit should log event. Note in Phase 01.

**M6. Dark mode readiness not verified in Phase 05.** Adding heatmap/chart tokens — do they have dark variants? Even if dark mode is off today, tokens should be dark-ready.

### LOW (observations)

**L1.** Phase 08 depends on Phase 05 but could partially run parallel (a11y checklist doc, semantic labels).
**L2.** Vietnamese glossary Phase 06 could add automated CI grep check as tech debt task rather than "future".
**L3.** Phase 04 role switcher deferred without owner — decide who owns follow-up.
**L4.** Persona toggle on device-shared logout race window (researcher-04 line 140-148) not called out as edge case.
**L5.** OperatorWorkspaceShell existence not verified — Phase 04 assumes and researcher-04 open Q #3 flags this.

## Missing Phases / Scope

1. **Provider cache lifecycle phase (or expanded Phase 02):** Enumerate all state providers, define role-change eviction protocol. This is missing and is highest-risk gap.
2. **Delegation revocation E2E flow:** Small phase or subsection in Phase 02.
3. **Notification / FCM per-role routing:** Subsection in Phase 04.
4. **Automated test coverage phase:** Cross-cutting; either add to each phase or a dedicated "Test hardening" phase at end.
5. **Pre-flight scout report:** Before Phase 01 kickoff, verify all line references + backend contract assumptions. New artifact.

## Recommended Plan Changes

1. Add Rollout Gates section to `plan.md` between phase table and success criteria — with feature flag strategy for Phase 04.
2. Reorder: Phase 03 spec (0.5 day) → Phase 02 impl → Phase 03 impl → Phase 01 already OK. Update dependency graph in `plan.md`.
3. Update Phase 04 estimate 2 → 3-4 days; update total 11-12 → 13-14 days.
4. Add "Testing" subsection to each phase file with unit/widget/integration test list.
5. Add "Provider cache invalidation on role/persona change" subsection to Phase 02 with provider inventory.
6. Add "Bootstrap ordering & deep-link queue" subsection to Phase 02 with 7th test scenario.
7. Add "Delegation revocation handler" subsection to Phase 02 with error interceptor spec.
8. Add "Notification routing per shell" subsection to Phase 04.
9. Add Phase 00 (pre-flight scout) as gate before Phase 01 kickoff — verify all line refs + backend contract for role upgrade JWT.
10. Rewrite non-goals per phase precisely — remove contradictions between plan-level and phase-level.
11. Add Phase 07 depends on Phase 05 (avoid double edit of AppBar during split).
12. Consider splitting Phase 05 into 05a (tokens + AppBar) and 05b (error/loading/empty sweep) for realistic scope.

## Open Questions for User

Beyond the 4 decisions already in plan.md:

5. **Cache invalidation policy on role change:** hard clear all role-scoped state, or selective per-provider TTL? Impacts C1 fix scope.
6. **Notification behavior when wrong role receives push:** discard, defer, or force role switch prompt? Impacts C3 fix.
7. **Feature flag infrastructure:** does app have any flag system (Remote Config, LaunchDarkly, local pref) usable for Phase 04 rollback? If none, we need decision to add one or accept blind rollout.
8. **Analytics tooling:** is there a screen-view analytics library wired? Needed for M2 role shell events.
9. **Testing budget:** willing to invest ~1-2 extra days across phases for automated tests, or accept smoke-test-only risk?
10. **Multi-role user reality:** does any current production user have host+operator (or host+admin) both active? Answer determines urgency of role switcher in Phase 04.
11. **Phase 04 shells rollout order:** ship AdminShell first (highest security value), then OperatorShell, defer TenantShell? Or all-or-nothing?

**Status:** DONE_WITH_CONCERNS
**Summary:** Plan is high-quality overall; 4 critical gaps (cache lifecycle, deep-link bootstrap ordering, FCM routing, rollback strategy) must be addressed before Phase 02 impl begins. Test strategy needs upgrade from smoke-only. Estimate optimism in Phase 04 and Phase 05.
**Concerns:** Non-goal contradictions between plan and phases; Phase 02/03 dependency inversion causes double-write of guards; assumptions in Phase 01 need scout verify.
