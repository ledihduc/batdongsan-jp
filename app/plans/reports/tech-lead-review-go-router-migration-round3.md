# Tech Lead Review — go_router migration (Round 3, FINAL)

**Date:** 2026-06-28
**Reviewer:** code-reviewer (Tech Lead role)
**Scope:** Verify 2 PARTIAL items từ Round 2 (HIGH-2 + HIGH-4)
**Previous reports:**
- Round 1: `plans/reports/tech-lead-review-go-router-migration.md`
- Round 2: `plans/reports/tech-lead-review-go-router-migration-round2.md`

---

## Verdict: **APPROVED**

Cả 2 fix đã clean. Regression check pass — 0 errors / 0 new warnings từ migration. Migration go_router sẵn sàng land.

---

## 1. HIGH-2 — `booking_history_screen.dart` eager import

**Status: PASS**

Verified `lib/features/guest/booking/booking_history_screen.dart`:
- Line 6: `import 'package:go_router/go_router.dart';` — đã thêm.
- Lines 11–16: Không còn `import .../house_detail_screen.dart`. Imports đã sort lại đúng convention (booking, chat, review, providers).
- Lines 642–644: `_openHouse()` đã chuyển sang `context.push('/house/${appointment.houseId}')`. Syntax go_router đúng (extension method từ `package:go_router/go_router.dart`).
- Không còn `Navigator.push(...HouseDetailScreen...)` nào trong file.

**Grep `HouseDetailScreen` toàn `lib/`:**
- `lib/core/router/app_router.dart:172`: `detail.HouseDetailScreen(houseId: id)` — chính là deferred entry point. ✓
- `lib/features/guest/home/guest_home_screen.dart:14`: chỉ là comment giải thích "KHÔNG import eager". ✓
- `lib/features/guest/house_detail/house_detail_screen.dart`: file định nghĩa class. ✓

→ **Zero leakage.** HouseDetailScreen chỉ còn được reach qua deferred route `/house/:id`. Tree-shaking sẽ tách thành chunk riêng trên web build, đạt mục tiêu code-splitting của migration.

---

## 2. HIGH-4 — `_parseInRange` NaN/Infinity bypass

**Status: PASS**

Verified `lib/core/router/app_router.dart:215–219`:

```dart
double? _parseInRange(String? raw, double min, double max) {
  final v = double.tryParse(raw ?? '');
  if (v == null || !v.isFinite || v < min || v > max) return null;
  return v;
}
```

- `!v.isFinite` đặt **đúng vị trí**: sau null-check, trước compare → short-circuit chặn NaN/Infinity trước khi vào `< min` (luôn false với NaN).
- Comment block lines 212–214 giải thích đúng rationale (NaN < x luôn false, attacker bypass guard → crash flutter_map).

**Mental test với input:**

| Input | `double.tryParse` | `isFinite` | Compare | Result |
|-------|-------------------|------------|---------|--------|
| `"NaN"` | `NaN` | `false` | skipped | `null` ✓ |
| `"Infinity"` | `Infinity` | `false` | skipped | `null` ✓ |
| `"-Infinity"` | `-Infinity` | `false` | skipped | `null` ✓ |
| `"99999"` (lat) | `99999.0` | `true` | `> 90` | `null` ✓ |
| `"10.77"` (lat) | `10.77` | `true` | in range | `10.77` ✓ |
| `"abc"` | `null` | skipped | skipped | `null` ✓ |
| `null` / `""` | `null` | skipped | skipped | `null` ✓ |

Tất cả branches đều handle đúng. flutter_map sẽ nhận `center = null` thay vì crash, fallback safely về default location.

---

## 3. Regression Final Check

**`flutter analyze`:** `133 issues found` — tất cả là `info` level (lint hints, deprecated `withOpacity`, `unnecessary_underscores`). Search grep cụ thể:
- `error •` → **0 matches**
- `warning •` → 3 matches, đều ở `lib/features/guest/post/post_house_screen.dart` (`unused_element_parameter` cho `uploadedUrl`/`isUploading`/`failed`). **Pre-existing** — không liên quan migration (file này có trong `git status M` nhưng warnings ở constructor private widget từ trước).

**Auto-format / merge của `main.dart` (3 provider mới Invoice/ServiceFee/MeterReading + `flutter_web_plugins`):** không phá vỡ router setup. `app_router.dart` không động chạm `main.dart`; deferred imports vẫn isolated.

---

## Migration Strengths (toàn bộ)

1. **URL-based deep linking thật sự**: `/house/:id`, `/planning?lat=&lng=&zoom=`, `/admin`, `/map` — browser back/forward + share link hoạt động.
2. **Code-splitting hiệu quả**: 5 deferred imports (`admin`, `detail`, `map`, `planning_screen`, `planning_provider`) → mỗi route nặng 1 chunk JS riêng trên web build.
3. **Auth redirect logic chắc**: `_matchesPrefix` chặn prefix-collision bypass (`/hostess` không match `/host`), bootstrap-aware (giữ deep link trong lúc auth load).
4. **Input validation tại boundary**: `_parseInRange` clamp lat/lng/zoom + chặn NaN/Infinity — không trust query params từ user.
5. **Bootstrap-safe redirect**: `if (auth.isBootstrapping) return null` — không kick deep-link về `/` khi refresh tab.
6. **Loading UX**: `DeferredRouteWidget` lo `loadLibrary()` + skeleton, không expose async edge để user.
7. **Error route**: `errorPageBuilder` có "Về trang chủ" — không bao giờ stuck.

## Conditions: NONE

## Open Questions

Không còn câu hỏi mở. Migration ready to ship.

---

**Recommended Action:** Merge. Sau merge nên smoke test:
1. Direct deep link `/house/123` sau hard reload tab.
2. `/planning?lat=NaN` → fallback an toàn (không crash, không dùng NaN).
3. Guest cố access `/admin` → redirect về `/login` hoặc `/` đúng role.

**Status:** APPROVED
**Summary:** Cả 2 PARTIAL từ round 2 đã clean: HouseDetailScreen không còn eager import, `_parseInRange` chặn NaN/Infinity tại boundary. 0 errors, không có regression mới từ migration.
