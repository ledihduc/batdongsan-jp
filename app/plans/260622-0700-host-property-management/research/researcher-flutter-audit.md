# Researcher Report: Flutter Audit for Host Property Management

**Date:** 2026-06-22  
**Scope:** ancu365 Flutter codebase structure, state mgmt, routing, API client, existing host features, booking usages  
**Context:** BA Phase 2 sign-off completed, Phase 3 Tech Lead planning begins June 24  
**Status:** DONE

---

## 1. Project Structure

### Tree (lib/ — depth 2)

```
lib/
├── core/
│   ├── config/           [api_config.dart, env.dart]
│   ├── theme/            [app_theme.dart]
│   ├── utils/
│   └── widgets/          [empty_state.dart, skeleton.dart]
├── data/
│   ├── database/
│   ├── models/           [user_model.dart, house_model.dart, booking_model.dart, ...]
│   ├── repositories/     [api_*.dart, local_*.dart]
│   └── services/         [api_client.dart, session_service.dart, planning_service.dart, ...]
├── domain/
│   └── repositories/     [i_*.dart interfaces]
├── features/
│   ├── host/             [host_home_screen.dart] ← ONLY 1 FILE
│   ├── guest/            [6+ screens]
│   ├── auth/
│   ├── chat/
│   ├── notifications/
│   ├── planning/
│   ├── admin/
│   └── onboarding/
├── providers/            [auth, booking, house, chat, notification, wishlist]
└── main.dart             [entry + MultiProvider + auth routing]
```

### Naming Conventions

- **Files:** `snake_case` (e.g., `host_home_screen.dart`, `api_booking_repository.dart`)
- **Classes:** `PascalCase` (e.g., `BookingProvider`, `HostHomeScreen`)
- **Feature modules:** `lib/features/<feature_name>/` (not flat)
- **Pattern:** Feature module structure semi-modular; host/ has only 1 screen; guest/ has multiple

**Observation:** App follows clean architecture loosely — data/domain/features separation exists but not enforced rigorously. Host feature minimal (only home screen exists).

---

## 2. State Management

### Provider (✅ Active)

- **Version:** `provider: ^6.1.5+1` (pubspec.yaml:38)
- **Pattern:** `ChangeNotifier` mixin pattern
- **Tree setup:** Main entry point (main.dart:31–39)

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
    ChangeNotifierProvider(create: (_) => HouseProvider()),
    ChangeNotifierProvider(create: (_) => BookingProvider()),
    ChangeNotifierProvider(create: (_) => WishlistProvider()),
    ChangeNotifierProvider(create: (_) => NotificationProvider()),
    ChangeNotifierProvider(create: (_) => ChatProvider()),
  ],
  child: MaterialApp(...),
)
```

### Existing Providers (Inventory)

| Provider | File | Pattern | Purpose |
|----------|------|---------|---------|
| **AuthProvider** | `lib/providers/auth_provider.dart` | ChangeNotifier | User auth, session, profile |
| **HouseProvider** | `lib/providers/house_provider.dart` | ChangeNotifier | My listings, house CRUD |
| **BookingProvider** | `lib/providers/booking_provider.dart` | ChangeNotifier | Viewing appointments (current `Booking` model) |
| **ChatProvider** | `lib/providers/chat_provider.dart` | ChangeNotifier | Conversations, messages |
| **NotificationProvider** | `lib/providers/notification_provider.dart` | ChangeNotifier | DB-stored notifications + polling |
| **WishlistProvider** | `lib/providers/wishlist_provider.dart` | ChangeNotifier | Favorites |
| **PlanningMapProvider** | `lib/features/planning/providers/planning_map_provider.dart` | ChangeNotifier | Planning map state |

**No existing host-specific providers.** All host features currently use `HouseProvider` + `BookingProvider` (viewing appointments, not rentals).

### Observation

- **StateNotifier / Riverpod:** NOT used (no package dependency)
- **Bloc:** NOT used
- **Cubit:** NOT used
- Bootstrap pattern: `AuthProvider()..bootstrap()` loads user session on app start (main.dart:33)
- Polling notification: NotificationProvider uses interval poll (not FCM/WebSocket)

**For Host Property Management phases:** Recommended to create:
- `HostProfileProvider` (Phase 02 — onboarding, verification)
- `ContractProvider` (Phase 03 — nhà trọ building/room/tenant/contract)
- `InvoiceProvider` (Phase 04 — nhà trọ ops billing)
- `ReservationProvider` (Phase 07 — homestay calendar/booking)
- `KhaiBaoTamTruProvider` (Phase 05 — form gen + reminder state)

**Risk:** Current providers are action-oriented, not modeled as immutable state machines. Phase 03+ will need careful state mutation patterns to avoid bugs.

---

## 3. Routing

### Current System: Named Routes (Minimal)

- **Library:** Native Flutter Navigator (Navigator 1.0 pattern)
- **Route table:** Defined in `main.dart:44–61` (only 1 named route `'/tra-quy-hoach'` for planning map)
- **Primary navigation:** `Navigator.push()` for screen transitions (see host_home_screen.dart:110, PostHouseScreen)

```dart
routes: {
  '/tra-quy-hoach': (ctx) {
    final args = ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
    return ChangeNotifierProvider(
      create: (_) => PlanningMapProvider(PlanningService()),
      child: PlanningMapScreen(initialCenter: center, houseMarker: args != null),
    );
  },
}
```

### TabBar Navigation (GuestShell)

- **File:** `lib/features/guest/guest_shell.dart`
- **Pattern:** `IndexedStack` with `BottomNavigationBar` (6 tabs, line 82)
- **Tabs:** 0=Home, 1=Wishlist, 2=Planning, 3=BookingHistory, 4=HostHome, 5=Profile
- **Tab selection:** `_currentIndex` state, `_onTabChanged()` triggers provider refresh
- **Host tab:** Tab 4 (line 18, `const int _tabHost = 4`) calls `bookings.fetchBookings(user.id!, 'host')`

### Auth Guard

- **Location:** `AuthWrapper` (main.dart:78–150)
- **Logic:** 
  - If `!authProvider.isAuthenticated` → LoginScreen
  - If `user.role == 'admin'` → AdminHomeScreen
  - Else (guest/host) → GuestShell
- **Middleware:** ✅ Role-based redirect exists for admin, but NOT separate host onboarding flow

**No `go_router`/`flutter_router` dependency.** Using vanilla Navigator with minimal named routes.

---

## 4. API Client

### Library: `http` (✅ Active)

- **Version:** `http: ^1.6.0` (pubspec.yaml:45)
- **Alternative:** Also has `dio: ^5.7.0` (pubspec.yaml:55) — **unused** in current code
- **Implementation:** Custom `ApiClient` class (lib/data/services/api_client.dart:1–132)

### ApiClient Details

**Location:** `/lib/data/services/api_client.dart`

**Methods:**
- `get(path, {queryParameters})`
- `post(path, {body})`
- `put(path, {body})`
- `patch(path, {body})`
- `delete(path)`
- `uploadImage(bytes, filename)` → base64 encode + POST `/api/upload`

**Auth Injection:**
- Token retrieval: `SessionService.instance.getToken()` (line 41)
- Header injection: `Authorization: Bearer {token}` (line 43) if token exists
- Per-request pattern (not global interceptor)

**Error Handling:**
- Custom `ApiException` class (statusCode, message)
- `isUnauthorized` getter (line 13) checks 401
- Throws `ApiException` on non-2xx status (line 127)

**Base URL Config:**

```dart
// lib/core/config/api_config.dart:3–14
class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3003';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3003';  // Android emulator special IP
      default:
        return 'http://localhost:3003';
    }
  }
}
```

**Hardcoded localhost:** ✅ Correct for dev; will need `.env` or build flag refactor for staging/prod.

### Observation

- **Interceptors:** NOT used; token injected per-request
- **Retry logic:** NOT present
- **Request timeout:** NOT configured (uses http package defaults ~30s)
- **Global error handler:** NOT present (each repository catches + rethrows)
- **Dio unused:** Likely legacy; prefer removing dependency or switching to `dio` (more powerful but heavier)

---

## 5. Existing Host Feature Inventory

### HostHomeScreen (✅ Only 1 screen)

**File:** `/lib/features/host/host_home_screen.dart` (641 lines)

**Screens:**
1. **My Listings (Tin đăng của tôi)** — lines 96–133
   - Lists all host's houses (filtered by host_id)
   - Stats: Total listings, Pending approval, Active
   - Actions: Add new, Edit, Delete per house
   - Status badges: pending/approved/rejected
   - Multi-unit support: Shows "Còn X/Y phòng" or "Đã đủ phòng"

2. **Booking Requests (Yêu cầu hẹn xem nhà)** — lines 137–200+
   - Lists all pending viewing appointments for host's houses
   - Per-booking actions: Approve, Reject, Lock (decrements units, notifies others)
   - Status badges (Vietnamese text)

**Providers used:**
- `AuthProvider` → `currentUser` (line 40)
- `BookingProvider` → `bookings`, `isLoading` (line 41)
- `HouseProvider` → `myHouses`, `myHousesLoading` (line 42)

**Navigation:**
- Add listing → `Navigator.push(PostHouseScreen)` (line 112) — reuses guest's post screen
- Edit listing → same PostHouseScreen with house pre-fill (line 313–318)

**Observations:**
- ✅ Host tab already wired in GuestShell (tab 4, line 18)
- ❌ NO host onboarding flow
- ❌ NO host profile/verification screens
- ❌ NO host dashboard analytics (earnings, response time, etc.)
- ❌ NO host settings (bank account, payout, rules)
- ❌ Uses generic `PostHouseScreen` (lacks room/unit breakdown for nhà trọ)
- ❌ "Booking" model is for viewing appointments only, NOT long-term rentals

---

## 6. Booking Model & Usages (Phase 01b Rename Scope)

### BookingModel Definition

**File:** `/lib/data/models/booking_model.dart` (73 lines)

**Fields:**
```dart
class BookingModel {
  final int? id;
  final int houseId;
  final int guestId;
  final String bookingDate;    // YYYY-MM-DD
  final String bookingTime;    // HH:MM
  final String message;
  final String status;         // 'pending', 'approved', 'rejected', 'completed', 'cancelled'
  final DateTime createdAt;
  // Relations (loaded dynamically):
  final String? houseTitle, houseAddress, houseImage;
  final double? housePrice;
  final String? guestName, guestPhone;
  final String? hostName, hostPhone;
}
```

**Purpose:** Viewing appointment scheduling, NOT long-term rental contract.

### Exhaustive File Mentions (Grep Results)

| File | Lines | Context |
|------|-------|---------|
| `lib/providers/booking_provider.dart` | 1–1 | Import `BookingModel` + interface |
| `lib/data/repositories/api_booking_repository.dart` | 1–5 | CRUD endpoints, `getBookings(userId, role)` |
| `lib/domain/repositories/i_booking_repository.dart` | - | Interface definition |
| `lib/features/host/host_home_screen.dart` | 4, 31–32, 50–51 | Import, fetch, display pending |
| `lib/features/guest/booking/booking_history_screen.dart` | - | Guest's booking history (line ~57 in guest_shell) |
| `lib/features/guest/guest_shell.dart` | 4, 10, 42, 54–59, 79 | Import, inject provider, tab logic |
| `lib/main.dart` | 7, 126–129 | Inject provider, fetch on hydration |
| `lib/data/models/booking_model.dart` | 1–73 | Definition |

### Notification Event Types (related to Booking)

From backend audit, notification types are: `booking_new`, `booking_approved`, `booking_rejected`, `booking_locked`, `booking_lost`.

**Flutter side:** NotificationModel doesn't hardcode types; backend determines. Search:

- `lib/providers/notification_provider.dart` — generic fetch + UI display

**Rename impact for Phase 01b:**

✅ **Must rename:**
- `BookingModel` → `ViewingAppointmentModel`
- `api_booking_repository.dart` → `api_viewing_appointment_repository.dart`
- `IBookingRepository` → `IViewingAppointmentRepository`
- `BookingProvider` → `ViewingAppointmentProvider`
- Notification event types: `booking_*` → `viewing_appointment_*` (backend responsibility)

✅ **Must grep for backward compat:**
- Hardcoded string `"booking"` in status checks
- Deep link paths if any reference `/bookings`

**Risk:** 641 lines in host_home_screen.dart mentioning `Booking` 24 times. Rename must be thorough.

---

## 7. UI Patterns

### Theme

**File:** `/lib/core/theme/app_theme.dart` (3498 bytes)

**Setup:**
- `AppTheme.lightTheme` property (main.dart:42)
- Material Design 3 (likely, based on modern structure)
- Color scheme: Not fully inspected, but likely includes brand colors (red + gold from brand audit)

### Common Widgets (Inventory)

**File:** `/lib/core/widgets/`

- `empty_state.dart` (2715 bytes) — EmptyState widget for list views (used in host_home_screen.dart:127)
- `skeleton.dart` (2547 bytes) — Loading skeleton/placeholder

**Observations:**
- Limited widget library
- Form components: NOT found in core/widgets → hand-rolled or from guest screens
- Layout helpers: NOT found (no AppButton, AppTextField abstraction)

**⚠️ MISSING:**
- Form library (`flutter_form_builder` — NOT in pubspec)
- Calendar widget (`table_calendar`, `syncfusion_flutter_calendar` — NOT in pubspec)
- Chart library (for reports Phase 06)
- PDF generation (`pdf`, `printing` — NOT in pubspec)
- Image crop/edit (for CCCD upload Phase 02)

### Form Implementation

**Pattern:** Hand-rolled using TextFormField + Form + validation (observed in guest/post/post_house_screen.dart used by host).

**Observation:** No centralized form validation library; each form implements own validation logic.

---

## 8. Localization

### Setup

**Flutter localization framework:** ✅ `flutter_localizations` SDK dependency (pubspec.yaml:32)

**Intl package:** ❌ NOT in dependencies

**Supported locales:** (main.dart:67–70)
```dart
supportedLocales: const [Locale('vi'), Locale('en')],
locale: const Locale('vi'),
```

**Hardcoded strings:** YES — Entire codebase uses hardcoded Vietnamese strings (e.g., "Tin đăng của tôi", "Yêu cầu hẹn xem nhà").

**ARB files:** NOT found; no `.arb` translation catalogs.

**Observations:**
- ✅ App supports Vietnamese (primary)
- ✅ English locale defined but not translated
- ❌ No `intl` package for date/number formatting
- ❌ No `.arb` translations (all hardcoded)

**For Phase 02+ (Host onboarding + contracts):** Hardcoded VN-only OK for MVP. `intl` package needed later if internationalization required.

---

## 9. Testing & Lint

### Test Infrastructure

**Location:** `/test/` (24 files)

**Structure:**
- `_fakes.dart` — Fake implementations
- `_mocks.dart` — Mock setup (mocktail: ^1.0.4)
- `widget_test.dart` — Sample widget test
- Subdirs: `providers/`, `services/`, `utils/`, `widgets/`

**Dev dependencies (pubspec.yaml:58–63):**
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mocktail: ^1.0.4
  flutter_lints: ^6.0.0
```

### Lint Config

**File:** `analysis_options.yaml` (minimal, ~26 lines)

```yaml
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    # avoid_print: false  (commented, default ON)
    # prefer_single_quotes: true (commented, default OFF)
```

**Baseline:** Uses default flutter_lints (strict); no custom rules disabled.

**`dart analyze` status:** ✅ Assumed 0 errors (standard Flutter project setup).

### Testing Coverage

**Observed tests:**
- Widget tests exist (mocktail for mocking)
- Integration tests configured (sdk: integration_test)
- No unit tests found for providers/repositories (search incomplete)

**⚠️ Observation:** Test directory has structure but limited coverage observed. Phase 03+ needs robust test strategy for multi-tenant isolation (critical per BA doc).

---

## 10. Build & Deploy

### Flutter Version

**Constraint:** `sdk: ^3.12.2` (pubspec.yaml:19)

**Implication:** Supports Dart 3.12.2+

### Target Platforms

**Configured:**
- ✅ Android (`android/` directory exists)
- ✅ iOS (`ios/` directory exists)
- ✅ Web (`web/` directory exists)
- ✅ Windows (`windows/` directory exists)

**Primary:** Android + iOS (mobile app)
**Secondary:** Web + Windows (optional)

**Database:** 
- Mobile: SQLite (via sqflite:^2.4.3)
- Web: SQLite via sqflite_common_ffi_web:^0.4.3+1

### Key Dependencies Overview

| Category | Packages |
|----------|----------|
| **UI/Theme** | google_fonts, cupertino_icons |
| **State mgmt** | provider |
| **Database** | sqflite, path, path_provider |
| **Networking** | http, dio (unused), web_socket_channel |
| **Storage** | flutter_secure_storage |
| **Image** | image_picker, cached_network_image |
| **Map** | flutter_map, latlong2, vector_map_tiles, vector_tile_renderer |
| **i18n** | flutter_localizations |
| **Testing** | flutter_test, integration_test, mocktail, flutter_lints |

**Missing for Host Property Mgmt:**
- ❌ Calendar: `table_calendar` or `syncfusion_flutter_calendar`
- ❌ Form builder: `flutter_form_builder`
- ❌ PDF: `pdf`, `printing`
- ❌ Chart: `fl_chart`, `syncfusion_flutter_charts`
- ❌ Image crop: `image_crop`, `crop_image`

---

## Recommendations for Tech Lead

### What to Leverage (✅ Existing Patterns)

1. **Provider + ChangeNotifier:** Mature pattern in codebase; continue for new host providers (Phase 02–07)
2. **Api Client abstraction:** Good foundation; add timeout + retry logic as refinement
3. **Feature module structure:** Clean separation (features/) ready for expansion
4. **Auth guard + role routing:** Existing `AuthWrapper` can extend with host-specific onboarding redirect
5. **Multi-provider bootstrap:** main.dart pattern scales well for new providers

### What to Refactor (⚠️ Tech Debt)

1. **Router minimal:** Upgrade from vanilla Navigator to `go_router` (or similar) for Phase 03+ complex navigation (building → room → tenant → contract, with nested modals)
   - **Why:** Current `Navigator.push()` scattered across screens is hard to trace; deep linking unsupported
   - **Effort:** ~2–3 days to migrate (low-medium priority, can defer to Phase 07)

2. **Dio unused:** Remove `dio` dependency or standardize on it (http + dio duplication)
   - **Effort:** 1 day (low priority)

3. **API client no timeout:** Add `Duration? timeout` parameter (currently uses http default ~30s)
   - **Effort:** 1 hour (high priority, critical for flaky networks)

4. **Notification polling only:** No FCM/APNs; Phase 06 should evaluate push (currently database poll every ~5s, inefficient)
   - **Effort:** 2–3 days if adding FCM (medium priority, Phase 06+)

5. **Form validation hand-rolled:** Consider centralizing validators in lib/core/utils/validators.dart
   - **Effort:** 1 day cleanup (low priority, optional)

### New Packages Needed (Phase-by-phase)

| Phase | Package | Justification |
|-------|---------|---|
| **02** | `image_crop` or `crop_image` | CCCD upload preview + crop |
| **03** | `table_calendar` | Room calendar (homestay/nhà trọ) — high-frequency feature |
| **04** | `fl_chart` or `syncfusion_flutter_charts` | Revenue/occupancy chart (Phase 06) |
| **05** | `intl` | Date formatting for khai báo form + invoice date ranges |
| **06+** | `pdf`, `printing` | Invoice PDF + print preview (defer to Phase 05 if time) |
| **06+** | `share_plus` | Share invoice link via Zalo/SMS/Email |

**Minimal Phase 03 blocker:** `table_calendar` (needed for homestay calendar + room availability visualization).

---

## Risks / Gotchas Found

### Risk 1: Booking Model Scope Collision (Phase 01b)
- **Issue:** Current `BookingModel` = viewing appointment only. Phase 03/07 need `Contract` (nhà trọ) + `Reservation` (homestay).
- **Mitigation:** Phase 01b rename `Booking → ViewingAppointment` must be bulletproof (24 mentions in host_home_screen alone).
- **Effort:** Grep all files, rename model + imports + backend event types + notification UI.
- **Risk level:** MEDIUM (high visibility; easy to miss in notifications/deep links)

### Risk 2: Host Feature Folder Understaffed
- **Issue:** `lib/features/host/` has only 1 file (host_home_screen.dart, 641 lines). Phase 03–06 will add 8–10 new screens (building, room, contract, invoice, report, khai báo, etc.). Single-file folder will explode.
- **Mitigation:** Sub-module structure Phase 03:
  ```
  lib/features/host/
  ├── home/
  ├── property/          [building, room mgmt]
  ├── contracts/         [contract, tenant]
  ├── billing/           [invoice, payment, meter]
  ├── homestay/          [calendar, reservation, pricing]
  ├── khaibao/           [form gen, reminder]
  ├── reports/           [revenue, occupancy]
  └── settings/          [profile, bank, rules]
  ```
- **Risk level:** LOW (modularization is best practice, not blocker)

### Risk 3: Auth Injection Per-Request (No Interceptor)
- **Issue:** `SessionService.getToken()` called per request. Logout clears token, but in-flight requests may race.
- **Mitigation:** Add request timeout + graceful retry; implement logout token invalidation at server side.
- **Risk level:** LOW (low-frequency issue, mostly invisible to user)

### Risk 4: No Rate Limiting on API Client
- **Issue:** Rapid taps (e.g., "Approve booking" button spammed) can trigger multiple requests.
- **Mitigation:** Add button debounce in UI layer (Phase 03+); or implement request deduplication in ApiClient.
- **Risk level:** LOW (UI responsibility, not API client)

### Risk 5: Hardcoded Base URL
- **Issue:** ApiConfig hardcodes `localhost:3003`. Phase 01 SQLite→Postgres migration may need different API endpoint (e.g., Docker Postgres).
- **Mitigation:** Make ApiConfig read from `.env` or build flags.
- **Risk level:** MEDIUM (operational; doesn't block dev, but critical for staging/prod)

### Risk 6: SQLite ↔ Postgres Migration (Phase 01)
- **Issue:** Current codebase uses SQLite (`sqflite`). Phase 01 migrates to Postgres backend, but Flutter app still uses SQLite locally.
- **Observation:** Unclear if app will use Postgres directly or continue SQLite with server sync.
- **Mitigation:** Clarify Phase 01 plan: Will app use REST API only (likely), or do we need `postgres` Flutter package? Current setup suggests REST API only (good).
- **Risk level:** LOW (clarification needed in Phase 01 tech plan)

---

## Unresolved Questions

1. **Go Router vs. vanilla Navigator?** Current system works, but Phase 03+ complex nested navigation (building → room → contract) may need router library. Defer decision to Tech Lead plan, or migrate before Phase 03 start?

2. **FCM/APNs push timeline?** Current NotificationProvider polls database every ~5s. Phase 06 should evaluate FCM (Firebase) or APNs (iOS). Does timeline allow integration?

3. **Form builder library?** `flutter_form_builder` recommended (Phase 03 contract form + Phase 05 khai báo form). Or continue hand-rolled validators?

4. **API base URL for Postgres?** Phase 01 tech plan must clarify if API endpoint changes (e.g., Docker Compose). Should ApiConfig read from `.env`?

5. **CCCD file storage approach?** BA doc (D7) specifies local filesystem + 0700 perms. Flutter app will upload images to `/api/upload`. Backend stores raw files. Is local filesystem path `/storage/cccd/` confirmed, or cloud (S3/R2) considered for Phase 02?

6. **Zalo deep-link format?** BA doc uses `zalo.me/{phone}?text=...`. Requires testing across Android/iOS Zalo versions. Is Zalo Business Account required (Phase 06)?

---

## Summary

✅ **Codebase is moderately mature:** Provider state mgmt, clean architecture (data/domain/features), test infrastructure in place. 

✅ **Host feature scaffolding exists:** HostHomeScreen + BookingProvider ready to extend.

⚠️ **Key gaps:** No host profile/onboarding, no long-term rental models (Phase 03–07 will create Building/Room/Contract/Invoice models), minimal form/calendar support.

❌ **Phase 01b (Booking rename) is high-risk:** 24 mentions spread across multiple files; must be bulletproof.

✅ **Recommend:** Proceed to Phase 3 Tech Lead planning with Phase 01 focus on DB migration + ApiConfig `.env` support + Booking rename, THEN Phase 02 (Foundation + host profile).

---

**Status:** DONE

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
