# Planning Lookup — Feature Documentation

> Version: P07 complete (2026-06-21)  
> Status: Feature complete, tests added in P08, deploy pending (P09)

---

## 1. Overview

Planning Lookup lets users and hosts check whether a property is located in a
regulated land-use zone in Ho Chi Minh City. The feature uses vector tile maps
powered by `flutter_map` + `vector_map_tiles` and queries a backend PostGIS
database via a proxied planning API.

**Four entry points:**

| # | Entry Point | Screen | User Role |
|---|-------------|--------|-----------|
| 1 | Bottom navigation tab "Tra quy hoạch" | `PlanningMapScreen` | Guest / Host |
| 2 | House detail badge (below address) | `PlanningBadge` inside `HouseDetailScreen` | Guest |
| 3 | Post-house warning button "Kiểm tra quy hoạch" | `PlanningWarningModal` in `PostHouseScreen` | Host |
| 4 | Admin tile "Listing rủi ro quy hoạch" | `RiskyListingsScreen` in admin panel | Admin |

---

## 2. User Flows

### 2.1 Flow A — Map Screen (Entry Point 1)

```
User taps "Tra quy hoạch" bottom tab
  └─> PlanningMapScreen loads
        ├─> FlutterMap renders with vector tile layer
        ├─> (optional) User types in SearchDropdown
        │     └─> debounced call to /api/planning/search (Nominatim proxy)
        │           └─> SearchHit results displayed
        │                 └─> User taps result → camera moves + BboxGuard check
        └─> User taps on map
              └─> BboxGuard.isInsideHCMC(lat, lng)
                    ├─> false → SnackBar "OUT_OF_BBOX" (AC-06)
                    └─> true  → getParcelByPoint() called
                                  ├─> loading: skeleton visible
                                  ├─> success: ParcelDetailSheet shown (DraggableScrollable)
                                  │     ├─> Zone name, area, district, sheet/parcel no
                                  │     ├─> Freshness warning if >30 days (AC-15)
                                  │     ├─> DisclaimerBanner (AC-09)
                                  │     └─> "Báo cáo dữ liệu sai" → ReportErrorScreen
                                  └─> error: ErrorCard + retry button (AC-07)
```

### 2.2 Flow B — House Detail Badge (Entry Point 2)

```
HouseDetailScreen loads house with lat/lng
  └─> PlanningBadge(lat, lng)
        ├─> lat==0 && lng==0 → SizedBox.shrink (no render)
        ├─> loading: LinearProgressIndicator (28×140)
        ├─> success: Chip showing "Quy hoạch: {zoneName}"
        │     └─> tap → Navigator.pushNamed('/tra-quy-hoach', {lat, lng, zoom:16})
        └─> error: SizedBox.shrink (fail-silently AC-04)
```

### 2.3 Flow C — Post-House Warning (Entry Point 3)

```
Host fills PostHouseScreen → taps "Kiểm tra quy hoạch"
  └─> PlanningWarningModal(lat, lng) shows as AlertDialog
        ├─> loading: CircularProgressIndicator
        ├─> success (risky zone): Amber banner + zone info + DisclaimerBanner
        │     └─> Log: PlanningAnalytics.logRiskyWarning(zoneCode)
        ├─> success (safe zone): Green banner + zone info + DisclaimerBanner
        └─> error: "Không tải được: {error}"
        Actions: "Báo cáo nếu thông tin sai" | "Đã hiểu" (close)
```

### 2.4 Flow D — Admin Risky Listings (Entry Point 4)

```
Admin taps "Listing rủi ro quy hoạch" in AdminHomeScreen
  └─> RiskyListingsScreen
        ├─> loading: CircularProgressIndicator
        ├─> success (empty): "Không có listing rủi ro" icon + text
        ├─> success (populated): ListView of RiskyHouse tiles
        │     ├─> Title, zone code chip (amber), zone name
        │     └─> tap → HouseDetailScreen(houseId)
        ├─> error 403: "Bạn không có quyền truy cập" (AC-19)
        └─> Pull-to-refresh: RefreshIndicator → _refresh()
```

---

## 3. State Diagram — PlanningMapProvider

```
                           ┌─────────────────────────────────────────────┐
                           │            PlanningMapProvider               │
                           │                                              │
                           │  state: MapState { idle, loading, ready,    │
                           │                    error }                   │
                           │  selectedParcel: ParcelDetail?               │
                           │  errorMessage: String?                       │
                           │  retryCount: int                             │
                           └─────────────────────────────────────────────┘

   [Initial]
      idle
       │
       │  tapParcel(lat, lng) — OUTSIDE bbox
       ├─────────────────────────────────────────> error
       │                                            errorMessage = 'OUT_OF_BBOX'
       │
       │  tapParcel(lat, lng) — INSIDE bbox
       ├──────────────> loading
       │                    │
       │                    │  getParcelByPoint() resolves
       │                    ├──────────────────────────────> ready
       │                    │  (parcel != null)               selectedParcel set
       │                    │                                 retryCount = 0
       │                    │
       │                    │  getParcelByPoint() returns null (404)
       │                    ├──────────────────────────────> error
       │                    │                                 errorMessage = "Không tìm thấy..."
       │                    │
       │                    │  getParcelByPoint() throws
       │                    └──────────────────────────────> error
       │                                                       retryCount++
       │                                                       if retryCount >= 3:
       │                                                         errorMessage = "Vui lòng kiểm tra mạng"
       │
   error ──── clearError() ──────────────────────> idle
   error ──── tapParcel() ──────────────────────> loading (retry — AC-07)
   ready ──── dismissSheet() ─────────────────────> idle
   ready ──── tapParcel() (rapid) ─────────────── loading (cancel prev token AC-17)
```

---

## 4. Widget Tree — PlanningMapScreen

```
PlanningMapScreen (StatelessWidget)
└─ ChangeNotifierProvider<PlanningMapProvider>
   └─ Scaffold
      ├─ AppBar
      │  └─ SearchDropdown (StatefulWidget)
      │     └─ TextField + ListView (search hits)
      └─ Stack
         ├─ FlutterMap
         │  ├─ TileLayer (vector_map_tiles: StorageCachingTileProvider)
         │  ├─ VectorTileLayer (planning overlay)
         │  └─ GestureDetector → PlanningMapProvider.tapParcel()
         ├─ LayerControlPanel (toggle + opacity slider)
         ├─ PlanningBadge / LoadingSkeleton (overlaid bottom)
         ├─ Consumer<PlanningMapProvider>
         │  ├─ state==loading   → LoadingSkeleton
         │  ├─ state==ready     → DraggableScrollableSheet
         │  │                      └─ ParcelDetailSheet
         │  └─ state==error     → ErrorCard + Retry button
         └─ DisclaimerBanner (footer, compact=false)
```

---

## 5. i18n Keys

Current state: all display strings are VI-language Dart constants (no ARB).
Each location has a `// TODO(i18n)` marker.

| Key (future ARB) | Current VI String | Location |
|---|---|---|
| `planningBadgeLabel` | `'Quy hoạch: {zoneName}'` | `planning_badge.dart:109` |
| `planningWarningTitle` | `'Kiểm tra quy hoạch'` | `planning_warning_modal.dart:69` |
| `planningOkText` | `'Đã hiểu'` | `planning_warning_modal.dart:92` |
| `planningRiskyWarning` | `'Khu vực này có thể ảnh hưởng...'` | `planning_warning_modal.dart:157` |
| `freshnessWarning` | `'Dữ liệu cũ hơn 30 ngày — cần đối chiếu thêm'` | `parcel_detail_sheet.dart:11` |
| `reportBtn` | `'Báo cáo dữ liệu sai'` | `parcel_detail_sheet.dart:12` |
| `disclaimerText` | `'Dữ liệu tham khảo. Vui lòng đối chiếu...'` | `disclaimer_banner.dart:7` |
| `riskyListingsTitle` | `'Listing rủi ro quy hoạch'` | `risky_listings_screen.dart:7` |
| `riskyListingsEmpty` | `'Không có listing rủi ro'` | `risky_listings_screen.dart:8` |
| `riskyListingsForbidden` | `'Bạn không có quyền truy cập'` | `risky_listings_screen.dart:9` |

**Migration path:** When ARB is set up, run `flutter gen-l10n`, replace const
strings with `AppLocalizations.of(context)!.<key>`, and delete `// TODO(i18n)`.

---

## 6. Cache Strategy

### Vector Tile Cache (AC-14)

| Layer | Mechanism | Default Size |
|---|---|---|
| Vector map tiles | `vector_map_tiles` `StorageCachingTileProvider` | ~50 MB (configurable) |
| House images | `cached_network_image` `DefaultCacheManager` | ~100 MB |

**Clear button location:** Currently deferred — `TODO(P08): expose clearTileCache()`
in `planning_map_provider.dart:183`. When implemented:
- Add settings entry in user profile screen
- Call `StorageCachingTileProvider.store.clear()` from `PlanningMapProvider.clearTileCache()`

---

## 7. Testing Guide

### Run unit + widget tests (headless)

```bash
cd ancu365-app
flutter test test/ --coverage
```

Coverage report: `coverage/lcov.info`

Generate HTML report:
```bash
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

### Run specific test files

```bash
# Utils only (fast, no Flutter)
flutter test test/utils/

# Provider state machine
flutter test test/providers/planning_map_provider_test.dart

# Widget tests (slower — use runAsync)
flutter test test/widgets/

# Service contract tests
flutter test test/services/planning_service_test.dart
```

### Run integration tests (requires device)

```bash
flutter test integration_test/planning_e2e_test.dart -d <device-id>
```

All integration tests are currently `skip: true` — deferred to P09 staging soak.
Remove `skip: true` and implement `TODO(P09)` sections when running against staging.

### Test file map

| File | What |
|---|---|
| `test/utils/bbox_guard_test.dart` | 16 cases: HCMC corners, outside points, boundaries |
| `test/utils/zone_color_resolver_test.dart` | Valid/invalid/null hex; dark mode opacity |
| `test/services/planning_service_test.dart` | 9 method contract tests via MockPlanningService |
| `test/providers/planning_map_provider_test.dart` | 17 state machine tests |
| `test/widgets/planning_badge_widget_test.dart` | Loading, (0,0) guard, fail-silent |
| `test/widgets/parcel_detail_sheet_widget_test.dart` | Field render, freshness, disclaimer |
| `test/widgets/planning_warning_modal_widget_test.dart` | Dialog structure, no amber on failure |
| `test/widgets/risky_listings_screen_widget_test.dart` | Empty, populated, 403, navigation |
| `integration_test/planning_e2e_test.dart` | E2E skeleton (skip: deferred to P09) |

---

## 8. Risky Zone Codes Sync

The risky zone codes are mirrored between frontend and backend.

**Frontend file:** `lib/features/planning/utils/risky_zone_codes.dart`

**Current codes:**

| Code | Name |
|---|---|
| `DGT` | Đất giao thông (giải tỏa) |
| `CXP` | Cây xanh công viên |
| `DCC` | Đất công cộng |
| `DXH` | Đất xã hội (công trình hành chính) |

**Backend config location:** `ancu365-backend/app/config.py` → `RISKY_ZONE_CODES`

**Sync process:** Currently manual. When backend adds/removes a code:
1. Update `lib/features/planning/utils/risky_zone_codes.dart` `codes` Set
2. Update this table above
3. Run `flutter test test/utils/` — add test case for new code
4. Phase 2 plan: expose `/api/planning/risky-codes` endpoint to eliminate drift

---

## 9. Open Questions

| # | Question | Status |
|---|---|---|
| Q1 | Firebase Analytics vs Mixpanel — which platform for `logRiskyWarning`? | Open — awaiting product decision |
| Q2 | Geocoding in PostHouseScreen — use Nominatim proxy or device GPS? | Open — affects lat/lng accuracy for badge |
| Q3 | i18n ARB setup timeline — when to migrate from const strings? | Deferred to feature-complete milestone |
| Q4 | clearTileCache() settings UI placement? | Deferred to P09 |
| Q5 | Max vector tile cache size (currently unlimited, target ≤100MB AC-14)? | Deferred to P09 perf soak |
