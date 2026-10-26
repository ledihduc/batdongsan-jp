# Tech Lead Review — go_router Migration (Round 2)

**Date:** 2026-06-28
**Reviewer:** Tech Lead (code-reviewer agent)
**Scope:** Verify 6 fixes (2 CRIT + 4 HIGH) applied by developer after Round 1.
**Verdict:** **CONDITIONAL** — 1 HIGH bị fix sót (regression risk), 1 HIGH có corner case (NaN) chưa cover. 4 fix còn lại PASS.

---

## Verdict Summary

| # | Issue | Round 1 Severity | Round 2 Result | Note |
|---|-------|------------------|----------------|------|
| CRIT-1 | Bootstrap race redirect | CRITICAL | ✅ PASS | Guard correct, target URL giữ qua bootstrap |
| CRIT-2 | usePathUrlStrategy | CRITICAL | ✅ PASS | Gọi đúng thời điểm, no-op trên mobile |
| HIGH-1 | static `_hydratedAfterLogin` | HIGH | ✅ PASS | Logout reset OK, không leak qua process |
| HIGH-2 | Eager HouseDetailScreen import | HIGH | ⚠️ PARTIAL | Fix booking_detail nhưng **bỏ sót booking_history** |
| HIGH-3 | StatefulWidget MyApp | HIGH | ✅ PASS | Provider.value đúng spec, lifecycle OK |
| HIGH-4 | Range clamp lat/lng/zoom | HIGH | ⚠️ PARTIAL | **NaN bypass** range guard → LatLng(NaN, NaN) crash |

---

## Per-Fix Verification

### CRIT-1: Bootstrap Race — ✅ PASS

**File:** `lib/core/router/app_router.dart:47-52`

```dart
redirect: (context, state) {
  if (auth.isBootstrapping) return null;
  ...
}
```

**Scenario trace (cold start + deep link `/house/42`):**
1. `_auth = AuthProvider()..bootstrap()` → `_isBootstrapping=true`
2. GoRouter resolve URL → `/house/42`
3. Redirect runs → `auth.isBootstrapping` → `return null` → giữ location
4. `DeferredRouteWidget` mount → start loading `detail` chunk song song với bootstrap
5. Bootstrap done → `_isBootstrapping=false`, notifyListeners() → refreshListenable trigger redirect re-evaluate
6. Auth state đã định → đúng nhánh redirect (auth → giữ /house/42; unauth → /login)

**Bonus:** `_matchesPrefix()` helper áp dụng cho cả `/admin` + `/host` — chống `/hostess`, `/admin-tools` bypass (đồng thời resolve MED-2). Clean.

**Edge case kiểm tra:**
- Guest paste `/house/42` không có session → bootstrap fail silently → `isAuth=false` → kick `/login`. Mất target URL nhưng đây là correct behavior (cannot show protected detail to guest). Nếu muốn restore-after-login: cần `?returnTo=` param — ngoài scope.
- `/planning?lat=...` public route khi bootstrapping → guard return null → giữ URL → after bootstrap không match auth check → render OK. ✅

---

### CRIT-2: usePathUrlStrategy — ✅ PASS

**File:** `lib/main.dart:22-30`

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  _installGlobalErrorHandlers();
  _tuneImageCache();
  runApp(const MyApp());
}
```

**Verification:**
- Gọi sau `ensureInitialized()`, trước `runApp()` — đúng spec Flutter docs.
- `flutter_web_plugins: sdk: flutter` đã add vào `pubspec.yaml:61-62`.
- Trên non-web platform (Android/iOS/desktop): function là no-op (verified qua Flutter API docs + community confirmation). KHÔNG throw runtime exception.
- Web URL bây giờ là `https://app.com/house/42` thay vì `https://app.com/#/house/42`.

**Reminder (KHÔNG block merge nhưng phải done trước deploy):**
- Prod server **MUST** có SPA fallback (`try_files $uri /index.html` hoặc tương đương) — nếu không, user F5 trên `/house/42` sẽ 404. Đã note ở Round 1 Unresolved Q1; deploy team cần verify nginx/Cloudflare config trước khi push web build.

---

### HIGH-1: static `_hydratedAfterLogin` — ✅ PASS

**File:** `lib/core/router/app_router.dart:250, 275, 282-283`

```dart
static bool _hydratedAfterLogin = false;
...
if (!authProvider.isAuthenticated) {
  _hydratedAfterLogin = false;   // reset trên unauth path
  return const LoginScreen();
}
...
if (!_hydratedAfterLogin) {
  _hydratedAfterLogin = true;
  WidgetsBinding.instance.addPostFrameCallback((_) { ... });
}
```

**Verification:**
- Static class var → giữ trạng thái qua mọi lần `_RootGate` State được recreate trong cùng isolate. Tránh waste fetch khi redirect chain.
- Reset path: bất cứ khi nào `!isAuthenticated` được render → reset về `false`. Cover cả logout + session expire + role demote (admin → guest). ✅
- Mobile app restart → isolate mới → static var khởi tạo lại = `false` → OK.
- Hot-reload: hot-reload **không** reset static vars trong cùng isolate. Dev khi test logout flow + hot-reload có thể thấy hydrate KHÔNG re-run sau khi logout-login khi `_hydratedAfterLogin` còn `true` từ trước hot-reload. **Mitigation:** đã có reset path ở line 275 — sẽ chạy ngay khi `LoginScreen` render → reset → hydrate lại ở lần auth tiếp theo. ✅
- Hot-restart (R) → isolate restart → static reset → OK.
- Test isolation: hiện tại không có test instantiate `_RootGate` (grep confirmed) → không có issue. Nếu sau này thêm test, cần `setUp(() { ... reset state ... })` thủ công — đã note trong comment ở line 246-249.

**Multiple logout triggers:** Logout từ profile_screen → AuthProvider.logout() → `_currentUser = null` → notifyListeners → router refresh → mọi protected route redirect → `/login`. `_RootGate` không liên quan trong redirect path (vì user đang ở `/host` chẳng hạn). Khi user re-login → router redirect đẩy về `/` → `_RootGate` render → `!isAuth` không match (vì đã login) → vào hydrate path → reset đã xảy ra ở lần previous render `LoginScreen`. ✅

---

### HIGH-2: Eager HouseDetailScreen import — ⚠️ PARTIAL (FAIL)

**File 1 (fixed):** `lib/features/guest/booking/booking_detail_screen.dart`
- Eager import `HouseDetailScreen` đã xoá. ✅
- `_openHouse()` → `context.push('/house/${_a.houseId}')`. ✅

**File 2 (BỎ SÓT):** `lib/features/guest/booking/booking_history_screen.dart`

```dart
// line 13
import 'package:house_booking/features/guest/house_detail/house_detail_screen.dart';
...
// line 642-649
void _openHouse(ViewingAppointmentModel appointment) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => HouseDetailScreen(houseId: appointment.houseId),
    ),
  );
}
```

**Impact:**
- `BookingHistoryScreen` được reach từ guest flow (profile → "Lịch hẹn của tôi") → file này nằm trong main chunk.
- Eager import `HouseDetailScreen` → Dart compiler giữ symbol → defeat `deferred as detail` của router. **Main chunk vẫn chứa toàn bộ HouseDetailScreen + transitive deps (CachedNetworkImage detail UI, review widgets, vv).**
- Round 1 conclusion về tree-shaking sai vì lúc đó chỉ grep `BookingDetailScreen(` (orphan check) chứ không kiểm `booking_history_screen` — file này wire active.

**Fix required:**
```dart
// booking_history_screen.dart:13 → XOÁ import
// booking_history_screen.dart:642-649 → REPLACE:
void _openHouse(ViewingAppointmentModel appointment) {
  context.push('/house/${appointment.houseId}');
}
// + import 'package:go_router/go_router.dart'; (nếu chưa có)
```

**Verify after fix:**
```bash
grep -n "HouseDetailScreen" lib/features/guest/booking/booking_history_screen.dart  # should be empty
grep -rn "import.*house_detail_screen" lib/ | grep -v "deferred"  # only app_router.dart
```

---

### HIGH-3: StatefulWidget MyApp — ✅ PASS

**File:** `lib/main.dart:90-153`

**Verification checklist:**
- [x] `MyApp` extends `StatefulWidget` — `_MyAppState` holds router + auth.
- [x] `_auth` + `_router` init trong `initState()` đúng 1 lần.
- [x] `dispose()` gọi `_router.dispose()` + `_auth.dispose()` theo thứ tự đúng (router listener trước, ChangeNotifier sau).
- [x] `ChangeNotifierProvider<AuthProvider>.value(value: _auth)` — Provider.value KHÔNG tự dispose (đúng spec `provider` package). Owner = `_MyAppState`.
- [x] Comment ở line 122-123 giải thích rationale rõ ràng.

**Edge case kiểm tra:**
- Hot-reload không trigger `initState` lại → router + auth giữ instance. OK.
- App lifecycle backgrounded → resumed: không re-init State → OK.
- Double-dispose? `_router.dispose()` rồi `_auth.dispose()`. AuthProvider không override `dispose()` → dùng ChangeNotifier.dispose() default. Sau dispose, mọi `notifyListeners` sẽ throw `FlutterError("...dispose()...")`. Vì `_auth.dispose()` chỉ gọi 1 lần tại app teardown → an toàn.
- GoRouter dispose có gọi `refreshListenable.removeListener` (auth) không? Có — `GoRouter` register listener trong constructor, remove trong dispose. ✅ Không leak.
- `ChangeNotifierProvider.value` không dispose value khi widget unmount → đúng kỳ vọng (vì State.dispose() đã handle). Nếu unmount Provider mà ko gọi State.dispose → leak — nhưng State + Provider có cùng lifetime trong MyApp tree → OK.

---

### HIGH-4: Range clamp lat/lng/zoom — ⚠️ PARTIAL (NaN edge case)

**File:** `lib/core/router/app_router.dart:122-153, 212-216`

```dart
final lat = _parseInRange(qp['lat'], -90, 90);
final lng = _parseInRange(qp['lng'], -180, 180);
final zoom = _parseInRange(qp['zoom'], 1, 20);
...
double? _parseInRange(String? raw, double min, double max) {
  final v = double.tryParse(raw ?? '');
  if (v == null || v < min || v > max) return null;
  return v;
}
```

**Tested behaviors:**
| Input | tryParse | Range guard | Result | Expected |
|-------|----------|-------------|--------|----------|
| `null` / `""` | null | null check | null | null ✅ |
| `"abc"` | null | null check | null | null ✅ |
| `"99999"` | 99999.0 | `> 90` | null | null ✅ |
| `"-99999"` | -99999.0 | `< -90` | null | null ✅ |
| `"Infinity"` | infinity | `> max` | null | null ✅ |
| `"-Infinity"` | -infinity | `< min` | null | null ✅ |
| **`"NaN"`** | **NaN** | **`NaN < min` = false, `NaN > max` = false** | **NaN passes!** | null ❌ |

**Proof (executed):**
```dart
final v = double.tryParse('NaN');   // returns double.nan
print(v != null && v < -90);        // false (NaN comparison)
print(v != null && v > 90);         // false (NaN comparison)
```

**Impact:**
- `/planning?lat=NaN&lng=NaN` → `_parseInRange` returns `NaN` → `LatLng(NaN, NaN)` → flutter_map `MapOptions.initialCenter` nhận NaN → tile coord compute crash (assertion failure) hoặc render blank tiles. SEC-impact LOW (cần explicit NaN string) nhưng UX-impact HIGH (crash white screen).
- Same risk cho `zoom=NaN` → `initialZoom: NaN` → flutter_map crash on assert `zoom.isFinite`.

**Fix required:**
```dart
double? _parseInRange(String? raw, double min, double max) {
  final v = double.tryParse(raw ?? '');
  if (v == null || !v.isFinite || v < min || v > max) return null;
  return v;
}
```

`isFinite` returns `false` cho NaN + Infinity → cover cả 3 special values trong 1 check (cũng hợp lý hơn về mặt code).

---

## Regression Check

### Flutter Analyze

```
111 issues found (ran in 2.2s)
- 3 warnings (out of scope: post_house_screen unused optional params — pre-existing)
- 108 info (deprecated_member_use withOpacity, unnecessary_underscores, avoid_print)
- 0 errors
```

**Baseline comparison:** Round 1 noted "3 warnings ngoài scope". Round 2: cùng 3 warnings, 0 mới. ✅

### LOC Check

| File | Round 1 LOC | Round 2 LOC | Δ | Status |
|------|-------------|-------------|---|--------|
| `lib/main.dart` | 128 | 153 | +25 | StatefulWidget conversion. Still under 200 ✅ |
| `lib/core/router/app_router.dart` | 280 | 307 | +27 | `_parseInRange` + `_matchesPrefix` + isBootstrapping guard. **Over 200 LOC guideline** ⚠️ (was already over in R1 — MED-1 từ Round 1 vẫn áp dụng: tách `_RootGate` ra file riêng) |
| `lib/features/guest/booking/booking_detail_screen.dart` | 743 | 743 | 0 | Net zero (xoá import + change Navigator → context.push) |

### Dead Code Check

- `booking_detail_screen.dart`: import `HouseDetailScreen` đã xoá, không còn unused import. ✅
- `booking_detail_screen.dart` line 4: `import 'package:go_router/go_router.dart';` đã có (nếu trước đây chỉ dùng Provider, giờ thêm dùng `context.push`). Verified used at line 162. ✅
- `host_dashboard_tokens` từ Round 1 LOW-2 — không trong scope round 2.

### Mobile vs Web

- `usePathUrlStrategy()`: confirmed no-op trên Android/iOS/desktop. ✅
- `static bool _hydratedAfterLogin`: app restart → isolate restart → static reset. Mobile background/resume → State không recreate → state preserved. ✅ Không có lifecycle scenario nào kẹt.

### Provider Tree Lifecycle

`MultiProvider` re-mount nếu `MyApp.build()` re-run với key thay đổi — nhưng `MyApp` là root (`runApp(const MyApp())`), key luôn null + parent là root → không bao giờ remount → providers giữ lifecycle qua toàn app session. ✅

---

## Other Findings (Non-Blocking)

### NEW-1 (info): `MultiProvider` create lambdas chạy lazy
Provider lazy by default → `HouseProvider()` etc. chỉ instantiate khi consumer đầu tiên đọc. OK với hiện tại nhưng bootstrap-fetch trong `_RootGate` đòi consumer đọc qua `Provider.of` → trigger create đúng lúc. Không vấn đề.

### NEW-2 (info): `_router.dispose()` gọi trước `_auth.dispose()` — đúng thứ tự
Nếu reverse order → router đang listen auth → auth dispose → router cố add/remove listener → lỗi. Order hiện tại an toàn. ✅

### Carry-over từ Round 1 (vẫn applicable, không block round 2)
- MED-1: tách `_RootGate` ra file riêng để `app_router.dart` về dưới 200 LOC.
- MED-4: `DeferredRouteWidget` thêm retry button cho chunk load fail.
- LOW-1: comment lỗi thời trong `planning_badge.dart`.
- LOW-3: `debugLogDiagnostics: kDebugMode`.

---

## Required Actions Trước Merge

1. **HIGH-2 (bỏ sót)** — Migrate `booking_history_screen.dart` _openHouse từ MaterialPageRoute → `context.push('/house/$id')`, xoá eager import `house_detail_screen.dart`.
2. **HIGH-4 (NaN)** — Add `!v.isFinite` check trong `_parseInRange`.

Estimated effort: ~5 phút cả 2 fix.

Sau khi fix → re-verify:
```bash
grep -rn "import.*house_detail_screen" lib/ | grep -v "deferred"  # → only app_router.dart line
flutter analyze  # → 0 new warnings
```

---

## Metrics

- Files re-reviewed: 4 core (app_router, main, planning_map_screen, booking_detail) + 1 cross-check (booking_history) + 1 pubspec.
- Round 1 issues claimed fixed: 6. Verified PASS: 4. PARTIAL/FAIL: 2.
- Net new bugs introduced by Round 2 fixes: 0 (NaN bug existed in Round 1, không bắt; HIGH-2 leak existed in Round 1, bắt sai scope).
- Analyzer baseline preserved: 0 new errors/warnings.
- LOC budget overrun: `app_router.dart` 307 (over 200 guideline — same as R1).

---

## Unresolved Questions

1. **Prod web server SPA fallback đã setup chưa?** Repeat từ Round 1 Q1 — vẫn pending. Block deploy nếu chưa.
2. **`booking_history_screen` có UI test E2E không?** Nếu có, cần verify navigation từ history → detail không broken sau fix (`context.push` cần BuildContext còn mounted — khác Navigator.push semantics).
3. **NaN attack vector:** `?lat=NaN` có thể trigger từ malicious link share. Có cần audit các route handler khác (vd. `/house/:id` int.tryParse) cho special-value bypass? `int.tryParse('NaN')` returns null → safe. Chỉ `double.tryParse` vulnerable. Ngoài `/planning` không có route nào parse double.
4. **`debugPrint` trong `_installGlobalErrorHandlers` (main.dart:46-51):** sẽ log ra console trong release web build cũng. Có muốn guard `kReleaseMode` không? — không block, observation.

---

## Sources

- [usePathUrlStrategy non-web no-op confirmed](https://docs.flutter.dev/ui/navigation/url-strategies)
- [GitHub flutter#152490: usePathUrlStrategy on non-web platforms](https://github.com/flutter/flutter/issues/152490)
