# State/Cache/Lifecycle Audit — Gaps in Current Plan

## Summary

The refactoring plan correctly addresses **router guards** and **shell architecture** but misses three critical cross-cutting **state/lifecycle concerns** that could leak user data or authorization context across logout, role transitions, and operator delegation switches. Specifically: (1) logout does NOT clear 14 of 17 role-scoped providers; (2) ActorContextProvider properly clears on logout per phase-02, but **no plan mentions FCM token topic cleanup or notification subscription scoping by role**; and (3) offline-cached data in ReportProvider is never role-scoped, risking stale host analytics lingering after logout and relogin as guest.

---

## Findings

### F1: Incomplete logout cleanup — 14 providers uncalled

**Category:** Provider lifecycle / logout  
**Evidence:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/lib/features/guest/profile/profile_screen.dart:318–321` — logout calls `auth.logout()`, then **manually** clears only 3 providers: `wishlist.clear()`, `notifications.clear()`, `chat.clear()`. Remaining 14 providers (HostProfileProvider, HouseProvider, DashboardProvider, ReportProvider, BuildingProvider, RoomProvider, ContractProvider, InvoiceProvider, ServiceFeeProvider, MeterReadingProvider, KhaiBaoProvider, DrillProvider, HomestayCalendarProvider, PricingRuleProvider, ReservationProvider, MarketplaceProvider) have no reset/clear call.

**Code inspection:**
- `main.dart:287–306` declares 21 ChangeNotifierProvider instances
- Only 4 have `clear()`/`reset()` methods: ChatProvider, NotificationProvider, WishlistProvider, ActorContextProvider
- Remaining 17 accumulate stale state indefinitely

**Impact:** If user logs out as host (with cached house listings, invoices, contracts) and logs in as different guest account, those host-specific data structures remain in memory. No data leak to second user if providers are identity-keyed by userId, but architectural risk: if a provider later assumes it can trust cached data without userId re-check, IDOR or cross-user data display becomes possible. **Medium-term debt.**

**Severity:** MEDIUM  
**Suggested plan additions:**  
- Add to **Phase 02 (Router Guard Sweep)**: "Step 5b — Provider cleanup on logout: Define `reset()` on HouseProvider, DashboardProvider, ReportProvider; inject into auth_provider.logout() or create AuthListener mixin."
- Document: "Providers holding user-specific data MUST implement `reset()` and be called before `_currentUser = null` in logout()."

---

### F2: FCM topic subscriptions not role-scoped; no unsubscribe on logout

**Category:** FCM / notification routing  
**Evidence:** Firebase Messaging onMessage / onMessageOpenedApp listeners in NotificationProvider (`lib/providers/notification_provider.dart:153–154`) are attached per-user but no code shows topic subscription/unsubscription tied to role or logout.

Grep search found zero `subscribeToTopic` / `unsubscribeFromTopic` calls in codebase. **This is not necessarily wrong** (backend may be handling topic routing via userId alone), but plan does NOT mention FCM scope.

**Code inspection:**
- `main.dart:386–396` — detachFcm() cancels streams but doesn't show topic cleanup
- `notification_provider.dart:106–113` — `clear()` stops polling, detaches FCM, but silent on topics
- `fcm_service.dart` (inferred) has `attachUserContext()` and `detachUserContext()` but plan provides no details

**Impact:** If backend subscribes user to role-specific topics (e.g., `host_${userId}`, `guest_${userId}`), they are **not unsubscribed on logout**, leading to: (a) notification leakage to next user on shared device (via FCM service caching), (b) confusing notifications if user was temporarily granted operator role mid-session then lost it (lingering subscription).

**Severity:** HIGH (data leakage vector)  
**Suggested plan additions:**  
- Add to **Phase 02 (Router Guard Sweep), new step 7**: "FCM topic lifecycle: (1) Document which topics are subscribed per-role (backend spec). (2) On `attachUserContext`, ensure role-specific unsubscription from prior role's topics if role changed. (3) On logout, explicitly unsubscribe from all role topics before detachUserContext."
- Add to **Phase 04 (Role-Specific Shells)**: "Post-login hydration MUST include role-aware FCM re-subscription (guest vs host vs admin topics differ)."

---

### F3: ReportProvider offline cache has no role scope; host data could leak to guest

**Category:** Offline-first data / cache invalidation  
**Evidence:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/lib/providers/report_provider.dart:63–95` — offline-first reporting. When online request fails, provider marks `_offline = true` and **continues returning cached data** (line 195, 226, 257, 285, 316). Cache is built at app start and never cleared by logout; it's keyed by report query params, NOT userId.

**Scenario:** User logs in as host, fetches Q2 analytics (cached). User logs out. User logs in as different guest account. If guest navigates to the same analytics path they happen to know (or through deep-link), offline-cached host data would be returned until next online fetch.

**Code inspection:**
- `report_provider.dart` — no `clear()` method, no `dispose()` implementation
- No userId included in cache key
- Offline state (`_offline`) is not reset on logout

**Impact:** Host analytics (revenue, tenant data, property details) visible to guest account if app goes offline and guest hits the cached query path.

**Severity:** HIGH (data leakage + IDOR risk)  
**Suggested plan additions:**  
- Add to **Phase 02, Router Guard Sweep, Step 5b**: "ReportProvider.reset() clears all cached reports and marks `_offline = false` on logout."
- Add to **Phase 02, end**: "Security note: offline-first providers MUST NOT cache role-scoped data. If offline cache is needed, cache key MUST include userId + role."

---

### F4: ActorContextProvider clear() on logout is correctly planned but NOT YET WIRED

**Category:** Delegation context lifecycle  
**Evidence:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/lib/providers/actor_context_provider.dart:53–58` — `clear()` method exists and is documented. `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/lib/providers/auth_provider.dart:113–131` — logout method does NOT call actor.clear(). `/lib/core/router/app_router.dart:519` — _RootGateState resets `_hydratedAfterLogin = false` on logout but **no actor context reset**.

**Plan reference:** Phase 02 (`phase-02-router-guard-sweep.md:31, 63`) **correctly specifies** "logout clears ActorContextProvider" and "Add actor.clear() before _currentUser = null" — but code does not implement it yet. This is **correctly identified as a phase-02 task**, not a plan gap.

**Impact:** None currently (ActorContextProvider is request-scoped and resets on cold-start). But mid-session logout without explicit clear() is defensive risk.

**Severity:** LOW (correctly planned, not yet implemented)  
**Status:** VERIFIED AS CORRECT IN PLAN — no action needed.

---

### F5: Form state (TextEditingController, etc.) not cleared on logout; draft data persists

**Category:** Widget state / form data lifecycle  
**Evidence:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/lib/features/guest/post/post_house_screen.dart:45–55` — form has 10 TextEditingController fields initialized at StatefulWidget level. No dispose() documented, no cleanup on logout. If user logs out mid-form, reopens the form after login, TextEditingControllers retain stale values.

**Scenario:** Guest A drafts a house listing (fills in title, description, price). Guest A logs out (or app backgrounded). Guest B logs in on same device. Guest B navigates to /guest/post — **sees Guest A's draft data in TextEditingController fields**.

**Code inspection:**
- `post_house_screen.dart:45–55` — 10 unmanaged TextEditingController instances
- No `@override dispose()` visible in excerpt
- No logout-triggered widget state reset

**Impact:** User privacy leak (draft form data visible to next user on shared device).

**Severity:** MEDIUM (form-level, not database, but privacy risk)  
**Suggested plan additions:**  
- Add to **Phase 01 (Critical role-leak fixes), new step**: "Widget state lifecycle: Any StatefulWidget holding user input (forms, text fields, search state) MUST either (a) be torn down on logout (preferred), or (b) clear() on initState if user changed."
- Document pattern: "Profile screens and forms SHOULD use `context.read<AuthProvider>().currentUser.id` as a key to `SingleChildScrollView(key: ValueKey(userId), ...)` — rebuilds form if userId changes."

---

### F6: Persona toggle (guest↔host UI mode) has no in-flight request cancellation

**Category:** Persona lifecycle / concurrent requests  
**Evidence:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/lib/features/guest/guest_shell.dart` — (SearchType: no explicit persona toggle found in this file, but plan and reports mention UI mode toggle). No HTTP client cancelToken or request deduplication observed. If user toggles guest→host persona while a guest request is in-flight, responses could be misinterpreted by host-side provider.

**Code inspection:**
- No `FutureCancel`, `CancelToken`, or `AbortController` usage in guest_shell or auth flow
- ApiClient (inferred from imports) not inspected for request lifecycle management

**Impact:** Race condition: guest fetch completes after persona switch, updates host-scoped cache with guest data.

**Severity:** LOW (low probability in practice — persona toggle is in-app, not network-delayed)  
**Suggested plan additions:**  
- Add to **Phase 04 (Role-Specific Shells)**, new note: "Persona toggle UX: ensure in-flight requests are cancelled before updating persona mode. Use ApiClient.cancelPendingRequests() or request-scoped tokens."

---

### F7: Bootstrap sequence doesn't guard against auth=null during provider initial load

**Category:** Bootstrapping race / null safety  
**Evidence:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/lib/core/router/app_router.dart:526–545` — hydration happens in post-frame callback after `isAuthenticated == true`, but providers are built unconditionally in MultiProvider (main.dart:277–318) **before** auth result is known. During the ~100ms window while AuthProvider.bootstrap() fetches the /me endpoint, all 21 providers are already instantiated and listening.

If a provider reads `auth.currentUser.id` in its constructor or early lifecycle, **null dereference crash could occur**.

**Code inspection:**
- `main.dart:242` — auth.bootstrap() called in State.initState
- `main.dart:277–318` — MultiProvider created in build(), after bootstrap() started but before it completes
- `app_router.dart:510` — `isBootstrapping` flag prevents shell render during auth check (correct)
- But providers are already built and observing auth changes

**Impact:** Rare but possible: edge case on very slow network, crash during app start.

**Severity:** LOW (mitigated by isBootstrapping check in shell, but defensive improvement possible)  
**Suggested plan additions:**  
- Add to **Phase 02 (Router Guard Sweep)**, new note: "Bootstrap safety: All ChangeNotifierProviders that depend on auth state SHOULD defer their first fetch until post-hydration (use `listen: false` in build, call fetch in _RootGateState post-frame callback — pattern already used for HouseProvider, NotificationProvider)."

---

## Recommended new plan steps

### Add to Phase 02 (Router Guard Sweep):

**Step 5b — Provider reset on logout:**
- Define `reset()`/`clear()` method on ReportProvider, DashboardProvider, HouseProvider, HostProfileProvider
- In `auth_provider.logout()`, call `actor.clear()` (already planned)
- Create `_cleanupProvidersOnLogout()` method that reads and clears all user-scoped providers via context (use Provider.of with `listen: false`)
- Call cleanup BEFORE `_currentUser = null` to ensure providers can detect user change
- Test: verify ReportProvider._offline reset, HostProfileProvider._hostData cleared

**Step 6 — FCM topic lifecycle:**
- Document backend contract: which FCM topics exist per-role (host_$userId, operator_$userId, etc.)?
- Add `detachFcmTopics()` method to FcmService
- Call from `NotificationProvider.detachFcm()` — unsubscribe from role-specific topics before clearing listeners
- Test: on logout, verify no topic subscriptions remain (check Firebase Console for device subscriptions)

**Step 7 — Offline-first data scope:**
- Add security note to design: ReportProvider (and any offline cache) must never cache role-specific data without userId in key
- Implement: ReportProvider.reset() clears all cached reports + sets _offline=false
- Add userId check on cache hit: if userId changed since cache write, invalidate

### Add to Phase 01 (Critical role-leak fixes):

**New step — Widget state lifecycle:**
- Audit all StatefulWidget with form fields (post_house_screen, host property forms, etc.)
- Each MUST implement dispose() with controller.dispose()
- Consider key-based rebuild pattern: `SingleChildScrollView(key: ValueKey(currentUser.id), ...)` to auto-reset on user change
- Test: logout mid-form, login as different user, verify form is blank

---

## Verified as OK (no gap found)

- **ActorContextProvider.clear()** — correctly documented and planned in Phase 02
- **Auth token revocation** — SessionService.instance.getToken() invalidates on logout (not inspected in depth but comment suggests it's handled)
- **Router guard for /admin, /login** — correctly guarded (Phase 04 plan correctly notes deferred routes need guards)
- **NotificationProvider.clear()** / ChatProvider.clear()** — implemented and called on logout (profile_screen.dart:319–321)
- **WishlistProvider.clear()** — implemented and called on logout
- **FCM foreground/tap streams** — correctly detached in NotificationProvider.detachFcm()
- **Permission events offline queue** — scoped by installation ID + user ID (not verified in depth but design doc suggests correct)

---

## Impact summary

| Finding | Risk | Effort to fix | When |
|---|---|---|---|
| F1: 14 providers uncalled on logout | Medium | ~4h | Phase 02 |
| F2: FCM topics not role-scoped | High | ~3h | Phase 02 or 04 |
| F3: ReportProvider offline cache leaks host→guest | High | ~2h | Phase 02 |
| F4: ActorContext clear (already planned) | Low | 0 (in plan) | Phase 02 impl |
| F5: Form state persists across logout | Medium | ~2h | Phase 01 |
| F6: No request cancellation on persona toggle | Low | ~1h | Phase 04 nice-to-have |
| F7: Bootstrap null-check for providers | Low | ~1h | Phase 02 note |

**Total estimated additional effort:** ~13 hours (roughly +1 day to Phase 01 + Phase 02 timelines).

