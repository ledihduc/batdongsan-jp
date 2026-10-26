# Phase 02 — Router Guard Sweep + Provider Cache + FCM + Delegation Revocation

**Priority:** P0 | **Status:** pending | **Estimate:** 2 ngày (was 1 ngày v1) | **Depends on:** Phase 01, Phase 03 spec (0.5 ngày)

## Context

Router matrix (từ researcher-04): 9/24 routes thiếu guard. Deferred routes (`/host/analytics/*`) bypass hoàn toàn redirect logic. `/operator/*` không có guard nào. `ActorContextProvider` không clear khi logout.

**v2 mở rộng:** Tech Lead review (C1, C2, C3, H6) flag: 14/17 provider không clear on logout, FCM topic không lifecycle-aware, bootstrap ordering race gây flash sai shell, delegation revocation flow thiếu handler. Phase 02 gom tất cả thành 1 phase "cross-cutting router + lifecycle" vì tất cả share cùng entry point (AuthProvider + Router).

**Scout corrections (Phase 00 report 2026-07-02):**
- Provider count 14 → **18** (scout thấy 22 total, 4 đã có clear(): Wishlist, Notification, Chat, ActorContext → 18 cần add)
- Backend location: `/ancu365-backend/` (dùng cho reference contract)
- **FCM push channel là stub** — backend service marker "push_stub", chưa wire firebase-admin. Phase 02 skip topic logic, chỉ đăng ký token qua `POST /api/users/me/push-token`. Topic-based routing defer đến Phase 08 khi backend ready.
- **Tenant JWT NOT_FOUND** — chỉ có `TenantAuthorityFlag` model (dispute/pause), không có tenant auth endpoint. Phase 02 Section C3 tenant guard hard-defer với TODO.
- **Backend không guard admin self-approval** — Q3 (disable admin toggle) mitigate frontend; backend team cần add server-side check parallel.

## Requirements

**Functional:**
- Mọi route protected có role guard đúng
- Deferred route cũng qua guard (nested redirect trong DeferredRouteWidget hoặc redirect ở outer)
- Logout clears `ActorContextProvider` context + tất cả 18 provider role-scoped state
- FCM push token registration đúng lifecycle (attach on login, detach on logout); topic-based subscription defer đến Phase 08
- Deep-link cold-start: đợi bootstrap xong mới redirect (không flash sai shell)
- Delegation revoke mid-session (backend 401 `code=DELEGATION_REVOKED`) → auto clear actor context + navigate `/operator` + toast
- Deep-link đến route sai role → redirect `/` hoặc `/login` + snackbar "Bạn không có quyền truy cập"

**Non-functional:**
- Không break existing legit flows (host vào analytics, guest xem `/planning`)
- Redirect không được loop
- Không refactor `ActorContextProvider` internals — CHỈ add `clear()` call
- Không refactor provider architecture — CHỈ add `reset()` method vào provider hiện có

## Related files

**Read:**
- `lib/core/router/app_router.dart` (662 dòng — main target)
- `lib/providers/auth_provider.dart` (229 dòng — logout flow)
- `lib/providers/actor_context_provider.dart` (`clear()` đã tồn tại per state audit)
- `lib/providers/delegation_provider.dart`
- `lib/providers/notification_provider.dart:106–113` (`clear()`, `detachFcm()`)
- `lib/services/fcm_service.dart` (grep để verify tồn tại + `subscribeToTopic`/`unsubscribeFromTopic`)
- `lib/main.dart:287–306` (MultiProvider — enumerate 21 provider)

**Modify:**
- `lib/core/router/app_router.dart` — refactor redirect + bootstrap ordering
- `lib/providers/auth_provider.dart` — logout gọi cascade cleanup
- **18 provider** cần thêm `reset()` (scout Section C authoritative list):
  - Host domain: `HostProfileProvider`, `HouseProvider`, `ViewingAppointmentProvider`, `BuildingProvider`, `RoomProvider`, `ContractProvider`
  - Billing/khaibao: `InvoiceProvider`, `ServiceFeeProvider`, `MeterReadingProvider`, `KhaiBaoProvider`
  - Analytics: `ReportProvider`, `DrillProvider`, `DashboardProvider`
  - Homestay: `HomestayCalendarProvider`, `PricingRuleProvider`, `ReservationProvider`, `MarketplaceProvider`
  - Cross-role: `DelegationProvider`, `ApprovalProvider`
- **4 provider đã có clear()** (chỉ cần call trong logout): `WishlistProvider`, `NotificationProvider`, `ChatProvider`, `ActorContextProvider`
- **AuthProvider** không reset() — chính nó orchestrate logout
- `lib/services/fcm_service.dart` — add `attachRoleTopics(role)` + `detachRoleTopics()`
- `lib/services/api_client.dart` (hoặc dio interceptor) — handle `code=DELEGATION_REVOKED`

**Tạo mới:**
- `lib/core/router/route_guards.dart` — helper functions dùng `DisplayedRole` (từ Phase 03 spec)
- `lib/core/lifecycle/user_scope_cleanup.dart` — orchestrator gom reset() của tất cả provider

## Router matrix — post-fix

| Route | Guard sau fix |
|---|---|
| `/host/**` (deferred analytics, delegation, approvals) | `isAuth && DisplayedRole.canAccessHost` |
| `/operator/**` | `isAuth && DisplayedRole == operator_` (từ Phase 03 impl) — nếu chọn Option A, derive từ `delegation.hasActive`; nếu Option B, từ `auth.role == 'operator'` |
| `/tenant/report-unauthorized/:id` | `isAuth && DisplayedRole == tenant && hasValidTenantJwt` (**BLOCKED bởi U2** — backend chưa issue tenant JWT; nếu chưa ra, mark guard "defer" và pass-through auth check) |
| `/admin/**` | `isAuth && DisplayedRole == admin` |
| `/house/:id`, `/planning`, `/map` | `isAuth` (implicit) hoặc public — không đổi |

## Implementation steps

### Step 1: Route guards (2 giờ)

Tạo `lib/core/router/route_guards.dart`:
```dart
String? guardHostRoutes(String loc, DisplayedRole role) =>
  loc.startsWith('/host') && !role.canAccessHost ? '/' : null;

String? guardOperatorRoutes(String loc, DisplayedRole role) =>
  loc.startsWith('/operator') && role != DisplayedRole.operator_ ? '/' : null;

String? guardTenantRoutes(String loc, DisplayedRole role) =>
  loc.startsWith('/tenant') && role != DisplayedRole.tenant ? '/' : null;

String? guardAdminRoutes(String loc, DisplayedRole role) =>
  loc.startsWith('/admin') && role != DisplayedRole.admin ? '/' : null;
```

**Note:** Phase 03 spec phải xong trước để có `DisplayedRole` enum + `canAccessHost` getter. Nếu Phase 03 chưa xong khi Phase 02 kickoff, dùng temp string check + refactor lại sau (mất công double-write) — recommend đợi Phase 03 spec.

### Step 2: Refactor app_router.dart redirect (2 giờ)

- Refactor `app_router.dart:83–111` (redirect block) gọi các guard function theo thứ tự, first non-null wins
- Thêm helper `_matchesPrefix` cases mới: `/operator`, `/tenant/report-unauthorized`
- Snackbar "Không có quyền" khi guard reject (dùng scaffold messenger key global)

### Step 3: Bootstrap ordering + deep-link queue (2 giờ — new v2, from C2)

**Problem:** `Listenable.merge([auth, delegation])` fire redirect nhiều lần khi cold-start. Deep-link `/operator/owner/123` sẽ redirect `/` trước (delegation chưa load), rồi shell repaint sau khi delegation load.

**Solution:**
```dart
// app_router.dart redirect
if (auth.isBootstrapping || delegation.isBootstrapping) {
  return null;  // let SplashScreen handle, don't redirect
}
// only after both bootstraps done, evaluate guards
```

- Ensure `isBootstrapping` flag exists trên `AuthProvider` + `DelegationProvider` (add nếu chưa có)
- Deep-link cache: nếu app open qua deep-link, save `pendingDeepLink` trong AppRouter state; khi bootstrap done, `context.go(pendingDeepLink)` replay
- Chain refreshListenable = `Listenable.merge([auth, delegation, displayedRoleProvider])` — Phase 03 add thêm 1 listener

### Step 4: Provider cache eviction on role change (3 giờ — new v2, from C1)

**Policy locked (Decision Q5):** Hard clear khi **actual role change** — logout, auto-upgrade guest→host, actor context enter/exit. **KHÔNG clear** khi user chỉ persona toggle (guest↔host UI mode, same auth role).

Triggers cần gọi `UserScopeCleanup.resetAll()`:
- `AuthProvider.logout()` — user logout hoàn toàn
- `AuthProvider._detectAndHandleRoleChange()` — auto-upgrade guest→host (JWT mới)
- `ActorContextProvider.enterContext()` — operator vào scope owner X
- `ActorContextProvider.clear()` — operator exit scope

**KHÔNG trigger:**
- `GuestShell._selectedPersona` toggle guest↔host (UI mode only, same auth role, same data scope)

Tạo `lib/core/lifecycle/user_scope_cleanup.dart`:
```dart
class UserScopeCleanup {
  final BuildContext context;
  const UserScopeCleanup(this.context);
  
  void resetAll() {
    // Read providers with listen: false, call reset()
    context.read<HouseProvider>().reset();
    context.read<DashboardProvider>().reset();
    context.read<ReportProvider>().reset();
    // ... 14 more (see file list above)
    context.read<ActorContextProvider>().clear();
    context.read<WishlistProvider>().clear();  // already exists
    context.read<NotificationProvider>().clear();  // already exists
    context.read<ChatProvider>().clear();  // already exists
  }
}
```

- Add `reset()` method vào 14 provider file (từ inventory Phase 00 step C)
- Call `UserScopeCleanup(ctx).resetAll()` **trước** `_currentUser = null` trong `auth_provider.logout()` (đảm bảo provider có thể detect user change)
- Add `reset()` cũng gọi khi `_detectAndHandleRoleChange` fire (mid-session role change)

**Special: ReportProvider offline cache (from F3):** khi reset, cũng clear `_offline = false` + clear cache map. Cache key phải include userId — nếu hiện chưa có, add prefix.

### Step 5: FCM token lifecycle (1 giờ — reduced v3 sau scout)

**Scout finding:** Backend push channel là **stub** (chưa wire firebase-admin), endpoint duy nhất là `POST /api/users/me/push-token` (register device token). Backend KHÔNG dùng topic-based subscription. Topic naming convention chưa exist.

**Phase 02 scope (giới hạn theo scout):**
- Verify `FcmService.attachUserContext(userId)` gọi trong `NotificationProvider.attachUserContext()` — đã có (scout D2 confirm)
- Verify `FcmService.detachUserContext()` gọi trong `NotificationProvider.detachFcm()` — đã có
- Add TODO comment: "Topic-based role filtering deferred to Phase 08 khi backend firebase-admin ready"
- Không add `attachRoleTopics`/`detachRoleTopics` methods (defer)

**Defer to Phase 08:**
- Topic subscription/unsubscription
- Role-based FCM routing
- Backend push endpoint integration
- Naming convention design (recommend `notifications_{userId}` per-user topic)

### Step 6: Delegation revocation handler (1.5 giờ — new v2, from H6)

- `api_client.dart` (hoặc dio interceptor) thêm:
  ```dart
  if (response.statusCode == 401 && response.data['code'] == 'DELEGATION_REVOKED') {
    // Trigger via global callback / event bus
    GlobalActorRevokeHandler.trigger();
    return null;
  }
  ```
- `GlobalActorRevokeHandler`:
  ```dart
  static void trigger() {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    ctx.read<ActorContextProvider>().clear();
    ctx.read<DelegationProvider>().refresh();  // reload list
    DsSnackBar.warning(ctx, 'Ủy quyền đã bị thu hồi. Quay về portfolio.');
    ctx.go('/operator');
  }
  ```
- Test scenario: manually revoke delegation backend, verify frontend catch 401 và clear

### Step 7: Logout wiring (30 phút)

- `auth_provider.logout()` update:
  ```dart
  Future<void> logout() async {
    final userId = _currentUser?.id;
    final role = _currentUser?.role;
    // 1. Cleanup providers (reset all user-scoped state)
    UserScopeCleanup(_context).resetAll();
    // 2. Detach FCM topics
    if (userId != null && role != null) {
      await FcmService.instance.detachRoleTopics(userId, role);
    }
    // 3. Session/token clear
    await SessionService.instance.clearToken();
    // 4. NOW null out user
    _currentUser = null;
    notifyListeners();
  }
  ```
- Cần inject BuildContext hoặc provider references qua constructor — nếu current AuthProvider không có, dùng ChangeNotifierProxyProvider trong main.dart

## Testing (new v2, from H1)

**Unit tests:**
- `test/core/router/route_guards_test.dart` — truth table cho 4 guard function × 5 DisplayedRole × 10 sample loc
- `test/providers/auth_provider_logout_test.dart` — mock UserScopeCleanup, verify order (cleanup → detach FCM → clear token → null user)
- `test/services/fcm_service_test.dart` — attach/detach topic idempotent
- `test/core/api_client_delegation_revoke_test.dart` — 401 với DELEGATION_REVOKED trigger callback

**Widget tests:**
- Cold-start với deep-link `/operator/owner/123` → SplashScreen → bootstrap done → OperatorShell mount (not flash GuestShell)

**Test scenarios (manual smoke):**

1. **Guest** deep-link `/host/analytics` → redirect `/` + snackbar
2. **Guest** deep-link `/operator/owner/123` → redirect `/` + snackbar
3. **Host** deep-link `/admin` → redirect `/` + snackbar
4. **Host** deep-link `/host/analytics` → mount OK
5. **Operator** (guest role + active delegation) deep-link `/operator/owner/123` → mount OK
6. **Anyone** logout mid-operator-session → shell resets, `actor.currentDelegation == null`, tất cả 17 provider reset (verify log)
7. **Cold-start** deep-link `/operator/owner/123` → không flash GuestShell, straight to OperatorShell (v2 new)
8. **Delegation revoked mid-session** → 401 catch → auto navigate `/operator` + toast (v2 new)
9. **Guest → host auto-upgrade** → FCM detach guest topic, attach host topic (verify Firebase Console) (v2 new)
10. **Login user B sau khi logout user A** → HouseProvider/ReportProvider blank, không thấy data của A (v2 new)

## TODO checklist

- [ ] Tạo `lib/core/router/route_guards.dart` với 4 guard function (dùng DisplayedRole)
- [ ] Refactor `app_router.dart` redirect gọi guards
- [ ] Bootstrap flag + deep-link cache trong app_router
- [ ] Chain `refreshListenable` include `DisplayedRoleProvider`
- [ ] Add role check trong deferred widget
- [ ] **Add `reset()` method vào 14 provider (list ở "Related files")**
- [ ] **Tạo `user_scope_cleanup.dart` orchestrator**
- [ ] **Wire cleanup vào `auth_provider.logout()` đúng order**
- [ ] **FCM `attachRoleTopics` + `detachRoleTopics`**
- [ ] **API client interceptor cho `code=DELEGATION_REVOKED`**
- [ ] **`GlobalActorRevokeHandler`**
- [ ] Snackbar "Không có quyền" khi guard reject
- [ ] Test 10 scenario (smoke + widget + unit)
- [ ] `flutter analyze` clean

## Success criteria

- Router matrix 24/24 routes có guard đúng
- Deferred routes cũng bị guard
- Logout clears actor context + 17 provider + FCM topics
- Deep-link cold-start không flash sai shell
- Delegation revoke mid-session tự động recover
- 10/10 test scenario pass
- Unit test coverage cho route_guards + cleanup ≥ 80% (nếu chọn testing budget)

## Risk

- **Redirect loop:** nếu guard trả về route mà chính nó cũng bị guard → infinite. Mitigation: cuối chain fallback về `/` — root luôn public.
- **DelegationProvider chưa load khi router check:** `hasActiveDelegation` có thể null tạm. Mitigation: dùng `isBootstrapping` flag, return null (không redirect) trong lúc bootstrap.
- **Circular dependency:** AuthProvider gọi UserScopeCleanup → cần BuildContext hoặc provider refs. Mitigation: dùng `ProxyProvider` pattern trong main.dart, hoặc `GetIt` service locator cho non-Provider deps.
- **FCM topic naming mismatch backend/frontend:** nếu Phase 00 không confirm được với backend → risk sub sai topic. Mitigation: document naming convention rõ trong `docs/fcm-topics.md`.
- **Reset() method viết 14 lần** → boilerplate. Mitigation: xem xét base class `ResettableProvider` với abstract `reset()`.
- **Tenant JWT chưa ra (U2 blocker):** Phase 02 tenant guard fallback về auth check only, log warning "tenant guard partial — awaiting backend U2".

## Security notes

- Router guard là UX barrier, không phải security. Backend PHẢI verify role và delegation scope trên mọi endpoint.
- Provider reset là data hygiene, không phải security. Data đã fetch xong nằm trong RAM cho đến khi Flutter GC — memory dump attack vẫn có thể extract. Đây là defense in depth, chấp nhận residual risk.
- FCM topic unsub best-effort — Firebase có eventual consistency, có thể race window vài giây.
- Delegation revocation client-side detect **không đủ** cho security (attacker có thể patch client) — backend phải hard-reject request với header revoked.

## Out of scope

- Không refactor DelegationProvider internal logic
- Không đổi API contract cho `X-Acting-As-Delegation-Id`
- Không animation cho unauthorized screen
- Không thay đổi FCM plugin (giữ firebase_messaging)
- Không thay đổi HTTP client (giữ dio/http hiện tại)
