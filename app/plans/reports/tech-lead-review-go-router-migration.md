# Tech Lead Review — go_router + Deferred Imports Migration

**Date:** 2026-06-28
**Reviewer:** Tech Lead (code-reviewer agent)
**Scope:** Migration `MaterialApp.routes` → `go_router` + 5 deferred chunks + 8 call site updates.
**Verdict:** **CONDITIONAL** — 2 CRITICAL must fix, 4 HIGH should fix trước merge.

---

## Files Reviewed

Router core
- `lib/core/router/app_router.dart` (280 LOC)
- `lib/core/router/deferred_route_widget.dart` (72 LOC)
- `lib/main.dart` (128 LOC)

Call sites
- `lib/features/guest/home/guest_home_screen.dart`
- `lib/features/host/host_home_screen.dart`
- `lib/features/admin/admin_home_screen.dart`
- `lib/features/admin/planning/risky_listings_screen.dart`
- `lib/features/map/map_screen.dart`
- `lib/features/notifications/notifications_screen.dart`
- `lib/features/guest/wishlist/wishlist_screen.dart`
- `lib/features/guest/profile/my_listings_screen.dart`
- `lib/features/planning/widgets/planning_badge.dart`

Cross-check
- `lib/features/auth/login_screen.dart` (login flow → router refresh)
- `lib/features/guest/profile/profile_screen.dart` (logout flow)
- `lib/features/guest/booking/booking_detail_screen.dart` (eager HouseDetailScreen leak — see HIGH-2)
- `lib/providers/auth_provider.dart` (bootstrap lifecycle)

---

## Overall Assessment

Migration phần lớn đúng. Router config compact, redirect logic dễ đọc, deferred symbol references nằm trong builder closures (đúng pattern). Call site refactor sạch — 8 sites đều dùng `context.push('/house/$id')` đồng nhất.

Tuy vậy còn 2 lỗi correctness CRITICAL liên quan tới deep-link UX (bootstrap race) + URL strategy mặc định của Flutter web (hash routing) làm task brief #3 "URL share-able + deep link" chưa thực sự đạt. Plus 1 HIGH về bundle splitting bị defeat bởi eager import sót lại, 1 HIGH về `_RootGate` skip re-hydration sau redirect.

---

## CRITICAL — Must Fix Before Merge

### CRIT-1: Redirect không xét `isBootstrapping` → deep-link bị kick về `/` sau cold-start

**File:** `lib/core/router/app_router.dart:47-67`

```dart
redirect: (context, state) {
  final loc = state.matchedLocation;
  final isAuth = auth.isAuthenticated;
  ...
  if (!isAuth && (loc.startsWith('/host') || loc.startsWith('/house/'))) {
    return '/login';
  }
}
```

**Repro:**
1. User logged-in session token vẫn còn (`SessionService`).
2. User paste URL `https://app.com/#/house/42` vào browser, mở tab mới.
3. `AuthProvider.bootstrap()` chạy async — trong khi chờ `_authRepository.me()`, `isAuthenticated == false`.
4. Router redirect ngay lập tức → `/login`.
5. Sau ~500ms `bootstrap()` xong → notify → router re-evaluate → user đang ở `/login` + auth → đẩy sang `/`. **Target `/house/42` mất.**

**Impact:** Deep-link share (mục đích chính của migration) bị broken cho mọi user còn session.

**Fix:**
```dart
redirect: (context, state) {
  if (auth.isBootstrapping) return null; // Wait until bootstrap done.
  final loc = state.matchedLocation;
  ...
}
```
Hoặc giữ `null` cho mọi route protected khi `isBootstrapping`, và để `_RootGate` render Splash cho `/` (đã làm).

---

### CRIT-2: Flutter web mặc định hash URL strategy → URL có `#`, SSR / share kém

**File:** `lib/main.dart` (thiếu) — không có `usePathUrlStrategy()` hoặc `setUrlStrategy(PathUrlStrategy())`.

**Tác động:**
- URL share trở thành `https://app.com/#/house/42` thay vì `https://app.com/house/42`.
- SEO / Open Graph preview crawler không index được fragment.
- Browser back/forward vẫn hoạt động nhưng URL xấu, không match task brief #3.

**Fix:** Trong `lib/main.dart` `main()`:
```dart
import 'package:flutter_web_plugins/url_strategy.dart';
...
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // No hash on web.
  ...
}
```

Phối hợp build flag: `flutter build web --base-href=/` (giữ default) và server config SPA fallback (`try_files $uri /index.html`) — nếu prod chưa setup SPA fallback, path strategy sẽ 404 khi user refresh `/house/42`. **Cần xác nhận server config trước khi enable.**

---

## HIGH — Should Fix Before Merge

### HIGH-1: `_RootGate` skip re-hydration sau khi redirect tạo state instance mới

**File:** `lib/core/router/app_router.dart:215-274`

`_hydratedAfterLogin` là instance var — reset về `false` mỗi lần State mới được tạo. Vấn đề: nếu user navigate `/admin` (sau đó admin logout / role demote), router redirect → `/`, GoRouter pop tất cả, push lại `/` page → `_RootGate` instance MỚI → re-hydrate.

Cụ thể có 2 case:
- Hydration chạy lại nhiều lần khi redirect chain xảy ra (provider fetch network duplicate). Idempotent nên không corrupt data, nhưng waste network call.
- Nếu user logout trên `/host` page → token clear → AuthProvider notify → router re-router. `/host` redirect → `/login`. `_RootGate` không liên quan. OK.

**Fix:** Move hydration logic lên Provider level (vd. `HouseProvider.fetchInitialData()` self-guard `_hasFetched`), không gắn vào widget lifecycle. Trade-off acceptable hiện tại nhưng đáng note. Hoặc dùng `static bool _hydratedThisSession` thay vì instance var.

### HIGH-2: Eager `import HouseDetailScreen` còn sót → tree-shake không split chunk

**File:** `lib/features/guest/booking/booking_detail_screen.dart:9`

```dart
import 'package:house_booking/features/guest/house_detail/house_detail_screen.dart';
...
MaterialPageRoute(builder: (_) => HouseDetailScreen(houseId: _a.houseId)),  // line 165
```

**Impact:** Nếu `BookingDetailScreen` được reach từ guest flow (booking_history → tap appointment), Dart compiler không thể tree-shake `HouseDetailScreen` ra khỏi main chunk → defeat toàn bộ `deferred as detail` của migration.

**Lookup hiện tại:** Grep cho thấy `BookingDetailScreen(` không xuất hiện anywhere ngoài file định nghĩa — có thể là dead code chưa wire. Nếu thật sự orphan, tree-shake sẽ loại bỏ. Nếu wire ở phase sau → bundle leak.

**Fix:**
1. Nếu orphan → xoá file (`booking_detail_screen.dart` + `write_review_screen.dart` chain) hoặc move sang `_legacy/`.
2. Nếu sẽ dùng → sửa thành `context.push('/house/${_a.houseId}')` (cùng pattern với 8 call sites khác).

### HIGH-3: `buildAppRouter(auth)` gọi trong `Builder.build()` — recreation rủi ro tương lai

**File:** `lib/main.dart:105-124`

Hiện tại safe vì `Provider.of<AuthProvider>(ctx, listen: false)` không subscribe → Builder chỉ build 1 lần. Comment đã giải thích. **Nhưng:** nếu dev tương lai thêm `listen: true` (vd. lấy theme provider), `Builder.build()` chạy lại → tạo `GoRouter` mới → history nav stack bị reset, listeners leak (router cũ không dispose).

**Fix:** Convert `MyApp` → `StatefulWidget`, tạo router 1 lần trong `initState`:

```dart
class _MyAppState extends State<MyApp> {
  late final AuthProvider _auth;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _auth = AuthProvider()..bootstrap();
    _router = buildAppRouter(_auth);
  }

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }
  ...
}
```
(Cần restructure providers tree — `AuthProvider` create outside MultiProvider, register via `.value`.)

### HIGH-4: `/planning` query không validate range + bỏ qua `zoom` param

**File:** `lib/core/router/app_router.dart:117-121`

```dart
final lat = double.tryParse(qp['lat'] ?? '');
final lng = double.tryParse(qp['lng'] ?? '');
```

- Không clamp `lat ∈ [-90, 90]`, `lng ∈ [-180, 180]` → `?lat=99999&lng=-99999` qua → `LatLng(99999, -99999)` đẩy xuống `PlanningMapScreen` → có thể crash flutter_map khi compute tile coords, hoặc render blank.
- Task brief #6 yêu cầu `?zoom=16` từ `planning_badge` nhưng router không parse `zoom` — `PlanningMapScreen` cũng không nhận `initialZoom` param. → Feature incomplete.

**Fix:**
```dart
final lat = double.tryParse(qp['lat'] ?? '');
final lng = double.tryParse(qp['lng'] ?? '');
final zoom = double.tryParse(qp['zoom'] ?? '');
final validLat = (lat != null && lat >= -90 && lat <= 90) ? lat : null;
final validLng = (lng != null && lng >= -180 && lng <= 180) ? lng : null;
final center = (validLat != null && validLng != null) ? LatLng(validLat, validLng) : null;
final validZoom = (zoom != null && zoom >= 1 && zoom <= 20) ? zoom : null;
```

Add `final double? initialZoom;` vào `PlanningMapScreen` + apply trong initState.

---

## MEDIUM

### MED-1: `_RootGate` sống cùng file router → kéo eager dep vào main chunk

**File:** `lib/core/router/app_router.dart:215-280`

`_RootGate` import `SplashScreen`, `OnboardingScreen`, `LoginScreen`, `GuestShell`, 6 provider — tất cả qua top-level `import` của `app_router.dart`. Vì `app_router.dart` là root của initial bundle (entry từ `main.dart`), mọi eager import của file này nằm trong main chunk. Hiện tại OK vì `GuestShell` + login + onboarding đều cần cho cold-start.

**Note:** Nếu sau này cần split `OnboardingScreen` (heavy intro animations) ra chunk riêng, sẽ phải tách `_RootGate` thành file riêng và làm `OnboardingScreen` deferred. Hiện tại chỉ là code organization concern — file `app_router.dart` 280 LOC vẫn dưới ngưỡng 200 LOC guideline đã được lệch nhẹ.

**Fix (optional):** Tách `_RootGate` ra `lib/core/router/root_gate.dart` để app_router.dart thuần routing config (~200 LOC).

### MED-2: `redirect` dùng `loc.startsWith('/host')` — fragile với route tương lai

**File:** `lib/core/router/app_router.dart:53, 62-63`

`startsWith('/host')` match cả `/hostess`, `/host-tools`, … Hiện chưa có route trùng prefix nhưng future-proofing nên dùng:
```dart
bool _matchesHost(String loc) =>
    loc == '/host' || loc.startsWith('/host/');
```

Tương tự `'/admin'`. Risk LOW hiện tại, dễ trở thành auth bypass nếu thêm route mới mà quên check redirect.

### MED-3: Hydration call duplicate `Provider.of<HouseProvider>(context, listen: false)` 2 lần liên tiếp

**File:** `lib/core/router/app_router.dart:258-260`

```dart
Provider.of<HouseProvider>(context, listen: false).fetchInitialData();
Provider.of<HouseProvider>(context, listen: false).fetchMyHouses(user.id!);
```

Lookup 2 lần — extract local var. Cosmetic.

### MED-4: `errorPageBuilder` button "Về trang chủ" dùng `ctx.go('/')` không clear deeper history

`ctx.go` push trên go_router clear stack — đúng intended. NHƯNG nếu user đang ở deep nested chunk loading state, `_DeferredRouteWidgetState._future` đã fail và sẽ vẫn cached. Tuy nhiên `errorPageBuilder` xử lý ở route-resolve level, không phải deferred load fail. Deferred error vào `DeferredRouteWidget.errorBuilder` (default UI plain text — chưa có nút retry). Improvement opportunity.

**Fix:** Trong `DeferredRouteWidget`, default `errorBuilder` cần nút "Tải lại" (gọi `setState` để re-trigger `_future = widget.loadLibrary()`).

---

## LOW

### LOW-1: Comment lỗi thời trong `planning_badge.dart:12`

```dart
/// - Tap → mở /tra-quy-hoach zoom 16 tại vị trí BDS.
```

Route đã đổi sang `/planning`. Cập nhật comment.

### LOW-2: `host_dashboard_tokens.dart` import trong host_home_screen — không thấy dùng

Grep nhanh không thấy `host_dashboard_tokens` symbol được reference trong `host_home_screen.dart`. Có thể là dead import. Verify với `dart analyze`.

### LOW-3: `debugLogDiagnostics: false` — bật khi dev sẽ giúp trace redirect loop

Cân nhắc `kDebugMode` guard:
```dart
debugLogDiagnostics: kDebugMode,
```

### LOW-4: Fade transition 180ms — không conflict với mobile platform transition

CustomTransitionPage thay thế hoàn toàn platform transition → user iOS sẽ mất swipe-back gesture. Trade-off chấp nhận cho consistency với web. Nếu muốn giữ iOS swipe-back: dùng `MaterialPage` thay cho web hash; conditional `kIsWeb ? CustomTransitionPage : MaterialPage`. Hiện tại không phải bug — chỉ note UX.

---

## Security

### SEC-1: Admin guard không bypass-able từ frontend route — backend vẫn phải verify

Redirect `loc.startsWith('/admin') && !isAdmin` → kick. Tuy nhiên đây chỉ là client-side UX guard. Mọi API call từ AdminHomeScreen (`admin_api_service.dart`) **phải** verify role server-side. Nếu attacker disable JS redirect (devtools), họ vẫn render được `AdminHomeScreen` nhưng API call sẽ fail. **OK assuming backend enforces.** Cần đảm bảo audit `admin_api_service` endpoints có middleware role check — ngoài scope review này.

### SEC-2: Query param `lat/lng/zoom` không sanitize → XSS / injection vector?

`double.tryParse` an toàn — non-numeric → null. Không có HTML rendering trực tiếp từ user input. **Safe.**

### SEC-3: `/house/:id` path param chỉ accept int

`int.tryParse(raw ?? '')` → reject mọi non-integer (vd `/house/abc`, `/house/<script>`). **Safe.**

---

## Positive Observations

- Deferred symbol references đặt trong `builder: (_) =>` closure — đúng pattern, không crash runtime.
- `refreshListenable: auth` clean integration với existing AuthProvider — không cần wrap thêm StreamController.
- 8 call sites migrate đồng nhất `context.push('/house/$id')` — không lẫn `context.go` (giữ history stack).
- `DeferredRouteWidget` có error UI (dù basic) — không silent fail khi chunk load lỗi.
- `_RootGate` preserve logic AuthWrapper cũ (Splash → Onboarding → Login → Hydrate) — không regression.
- `Consumer<HouseProvider>` wrap đúng scope ở `guest_home_screen.dart:200` — AppBar không rebuild theo HouseProvider notify (giữ tối ưu cũ).
- Hash strategy mặc định + `<base href>` từ flutter giữ web app deployable mà không cần SPA fallback nginx config (trade-off với CRIT-2).
- `int.tryParse` cho `/house/:id` validate đầu vào — return 404-like UI thay vì crash.
- Comment in-code (vi) giải thích rationale của từng decision — đọc dễ.

---

## Recommended Action Plan

**Trước merge:**
1. Fix **CRIT-1** (bootstrap redirect race) — 5 phút.
2. Fix **CRIT-2** (path URL strategy) — confirm prod server config; nếu chưa sẵn sàng → defer + accept hash URL tạm thời, document trong README.
3. Fix **HIGH-2** (booking_detail eager import) — verify orphan rồi xoá / migrate.
4. Fix **HIGH-4** (lat/lng clamp + zoom param).

**Có thể sau merge (next sprint):**
5. **HIGH-1** — refactor hydration ra Provider self-guard.
6. **HIGH-3** — convert MyApp → StatefulWidget cho router lifecycle.
7. **MED-1** — tách `_RootGate` ra file riêng.
8. **MED-4** — add retry button vào `DeferredRouteWidget` error UI.

---

## Metrics

- Files changed/touched: ~12
- New LOC (router): ~350
- MaterialPageRoute → context.push: 8 call sites migrated, 0 missed (nested flows giữ Navigator.push đúng theo design).
- Eager imports leak risk: 1 confirmed (HIGH-2).
- Type safety: pass — không dùng `dynamic` / `any` (Dart strict mode).

---

## Unresolved Questions

1. **Prod server SPA fallback đã setup chưa?** Quyết định CRIT-2 (PathUrlStrategy enable hay defer) phụ thuộc câu này. Nếu nginx/Cloudflare chưa rewrite `/house/* → index.html` thì user F5 trên deep URL sẽ 404.
2. **`BookingDetailScreen` là dead code hay sẽ wire ở phase tiếp theo?** Quyết định HIGH-2 fix path.
3. **Có analytics tracking cho route change không?** go_router có `observers: [GoRouterObserver()]` nếu cần Firebase Analytics screen tracking. Migration mất tracking nếu trước đây dùng `MaterialApp.navigatorObservers`.
4. **iOS swipe-back gesture có phải requirement?** Fade transition hiện tại disable native gesture. Sản phẩm chấp nhận?
5. **`refreshListenable: auth` notify khi profile update (avatar đổi) → redirect chạy lại nhưng `loc` không đổi → return null. OK nhưng waste compute. Có cần debounce / chỉ refresh khi auth state material thay đổi (login/logout/role)?**
