# Research Report: Flutter UI, State, & Routing Patterns — Owner-Operator Delegation

**Date:** 2026-06-29  
**Investigator:** Researcher Agent  
**Target:** Persona switching, provider patterns, routing, theming, notification stack, state persistence  
**Scope:** `lib/` directory — codebase analysis only. No design recommendations.

---

## 1. Persona Switching Pattern (Core Reuse: guest_shell.dart)

### 1.1 Current Implementation (guest ↔ host)

**File:** `lib/features/guest/guest_shell.dart` (415 lines)

#### Mode State
- **Line 34:** `String _mode = kModeGuest` — stores active persona (`'guest'` | `'host'`)
- **Line 49-52:** `Duration _switchDuration` — animates between modes (200ms manual toggle, 0ms bootstrap)
- **Line 42:** `bool _bootstrapped` — ensures one-time resolution on cold start

#### Bootstrap Flow
- **Line 61-66:** `_bootstrapMode()` → reads persisted last mode from `UserPrefsService`, resolves against `AuthProvider.currentUser.role`, applies silently (no animation)
- **Line 70-80:** `_applyResolvedMode()` → compares (saved_pref, current_role); only applies if changed; first call uses Duration.zero; manual toggles use 200ms fade
- **Line 84-89:** `_reconcileWithRole()` — re-evaluates when role arrives late (auth bootstrap finishing after shell mounts) or changes mid-session

#### Animation
- **Line 190-199:** `AnimatedSwitcher` wraps `_LazyIndexedStack` with fade transition (no slide — "felt sluggish", per line 177 comment). Curves: `easeOutCubic` in, `easeInCubic` out.
- **Duration:** 200ms manual toggle, 0ms bootstrap (avoid cold-start guest→host flash)

#### State Discard on Mode Flip
- **Line 194-195:** `_LazyIndexedStack` keyed by `ValueKey(_mode)` — when mode changes, old key discarded, new widget tree built fresh
- **Line 362-414:** `_LazyIndexedStack` is a lazy IndexedStack: only builds children once they're visited (via _visited bool list). Avoids triple-subscribe to WS, double polling on cold start.
- **Line 181-189:** "State-discard is INTENTIONAL" (per comment) — persona switch is deliberate context shift, not casual tab flip. Fresh fetch + reset scroll is the right UX.

#### Persistence
- **Line 108:** `UserPrefsService.instance.setLastMode(mode)` — persists to secure storage after manual toggle
- **Line 127:** On logout: `UserPrefsService.instance.clearLastMode()` — clears stale last_mode from previous user on shared device

#### Tab Navigation
- **Line 151-163:** Different tab lists for guest vs host:
  - Guest: Khám phá, Yêu thích, Đặt lịch, Cá nhân (4 tabs)
  - Host: Tổng quan, Nhà trọ, Yêu cầu, Cá nhân (4 tabs)
- **Line 222-224:** `_onTabChanged()` — fetches appointments role-aware (guest vs host)
- **Line 225-227:** `NavigationBar` destinations updated per mode

### 1.2 AuthProvider Integration

**File:** `lib/providers/auth_provider.dart` (230 lines)

#### Current User + Role
- **Line 13:** `UserModel? _currentUser` — stores authenticated user
- **Line 26:** `currentUser` getter
- **Line 141:** `newUser.role` — String: `'guest'` | `'host'` | `'admin'` (per line 161-170 parser)
- **Line 30:** `isAuthenticated` — bool flag

#### Role-Upgrade Detection
- **Line 140-157:** `_detectAndHandleRoleChange()` — compares incoming role against `_previousRoleSnapshot` (previous state). If changed (guest→host), notifies `PermissionService.onRoleUpgrade()` (AC-N8).
- **Line 156:** `_previousRoleSnapshot = newRole` — records new role for next comparison
- **Line 45, 64:** Called inside `bootstrap()` and `login()` **before** assigning `_currentUser`, so comparison is always prev vs new

#### No `setRole()` Method
- **Observation:** No public method to change role on-the-fly. Role comes from backend in JWT (login/bootstrap). Mid-session role changes would require re-fetch via `/api/auth/me` → trigger `_detectAndHandleRoleChange()`.

### 1.3 Routing & Role Guards

**File:** `lib/core/router/app_router.dart` (382 lines)

#### Redirect Logic
- **Line 73-99:** `redirect()` lambda — runs on every route navigation + auth state change
  - **Line 78:** If `isBootstrapping` → return null (no redirect; let deferred routes wait for bootstrap)
  - **Line 85-87:** `/admin` only for admin; others kicked to `/` or `/login`
  - **Line 89-91:** Already auth + at `/login` → kick to home (admin: `/admin`, others: `/`)
  - **Line 94-97:** Not auth + trying `/host` or `/house/:id` → kick to `/login`
  - **Line 98:** Otherwise null (no redirect)

#### Role-Based Routes
- **No operator-specific routes yet** — only guest, host, admin top-level routes
- `/host/*` routes (analytics, admin, etc.) are deferred — load only on demand via `deferred as` imports (lines 35-60)

#### Deep-Link Handling
- **Line 101-106:** Root route `/` uses `_RootGate` widget (gate.dart logic)
- **Line 256-285:** `/planning` route accepts query params: `?lat=10.77&lng=106.70&zoom=16` — validates range to prevent flutter_map crash (line 260-262 clamp logic)
- **Line 315-321:** Debug `/permission-debug` route (kDebugMode only) — tree-shaken in release

### 1.4 Reusability for Operator → Owner Context Switching

#### Pattern Fit
- ✅ **Airbnb-style persona model already proven** — guest ↔ host pattern is battle-tested
- ✅ **Lazy tab state** — won't double-fetch when switching owner context
- ✅ **Animation framework** — 200ms fade transition reusable for owner-context overlay
- ✅ **Persistence** — `UserPrefsService` can store last owner context ID across sessions

#### Key Differences for Operator
- **Scope:** Operator has **multiple owner contexts** (N:M relationship) vs guest having fixed 2 personas
- **Header Overlay:** Unlike role-based persona, operator needs **per-context header badge** ("Đang đại diện cho [Tên Owner]") + warm orange color
- **Context Request-Scoped, Not Session-Scoped:** (AC-15/15b) Every API call sends `X-Acting-As: <owner_id>` header. CANNOT cache in JWT / app state — must be per-request to handle cross-device/multi-tab safety.
- **Portfolio Dashboard:** New first screen (list of owner contexts) before entering any owner's home. Current pattern goes directly to guest/host home.

#### Reusable Components
| Component | Current Use | Operator Adaptation |
|-----------|------------|-------------------|
| `AnimatedSwitcher` + fade | Mode toggle | Context switch overlay fade |
| `_LazyIndexedStack` | Lazy child build | Lazy loading owner details |
| `UserPrefsService` + secure storage | Persist last mode | Persist last owner_id, operator portfolio UI state |
| `ValueKey(_mode)` state discard | Fresh tab rebuild on mode flip | Fresh owner context rebuild on context switch |
| Role-gated routes | `/host` for host only | New `/operator/portfolio`, `/operator/owners/:id/*` routes |
| `NavigationBar` destination swapping | Guest vs host tabs | Same tab structure but data filtered by owner context |

---

## 2. Host Home Screen & Editorial Cockpit (HostHomeScreen Blueprint)

### 2.1 Layout Overview

**File:** `lib/features/host/host_home_screen.dart` (first 200 lines shown; screen continues beyond)

#### Structure
- **Line 45-50:** `HostHomeScreen` stateful widget with `SingleTickerProviderStateMixin` (owns TabController)
- **Line 112-143:** Build: SafeArea → NestedScrollView with SliverAppBar + pinned TabBar
- **Line 120-133:** Header: `HDHeroSection` (hero greeting) + pinned `HDTabBar` (2 tabs: "Tin đăng", "Nhà trọ")
- **Line 134-140:** `TabBarView` switches between `_ListingsTab` and `_NhaTroTab`

#### Two Editorial Sections
1. **Tin đăng (Listings Tab)** — lines 166-227
   - Displays host's marketplace listings (status: pending/approved counts)
   - Viewing appointments pending count
   - RefreshIndicator for pull-to-refresh

2. **Nhà trọ (Operations Ledger Tab)** — lines 238+
   - Property management, contracts, invoicing, tenants (beyond shown lines)

### 2.2 Dashboard Widget Library

**Directory:** `lib/features/host/dashboard/` (8 widget files)

| File | Purpose | Reusability |
|------|---------|------------|
| `host_dashboard_tokens.dart` (HD) | Design tokens: colors, spacing, typography | ✅ Reuse for operator UI |
| `hd_hero_section.dart` | Greeting header ("Xin chào, [Name]") | ⚠️ Adapt: add badge "Đang đại diện cho [Owner]" |
| `hd_stats_grid.dart` | Primary + secondary stat cards (2x2 grid) | ✅ Reuse for KPI cards |
| `hd_tab_bar.dart` | Pinned tab bar with 2 labels | ✅ Reuse (Tin đăng / Nhà trọ) |
| `hd_section_label.dart` | Section heading ("ACTION ITEMS") | ✅ Reuse |
| `action_items_section.dart` | Task/approval cards with actions | ✅ Reuse for approval inbox |
| `hd_nhatro_kpi_bar.dart` | KPI bar (rooms, occupancy, revenue) | ✅ Reuse |
| `hd_status_pill.dart` | Status badge widget | ✅ Reuse |
| `hd_listing_row.dart`, `hd_appointment_row.dart` | List item renderers | ✅ Reuse |

### 2.3 Provider Dependencies

**Line 10-27:** HostHomeScreen depends on:
1. `AuthProvider` — current user identity
2. `ViewingAppointmentProvider` — pending appointments
3. `HouseProvider` — marketplace listings
4. `BuildingProvider` — property list (fetched line 87)
5. `RoomProvider` — rooms per building (line 102-106, loop)
6. `ContractProvider` — expiring contracts (line 90)

### 2.4 Refresh Pattern

**Line 74-94:** `_refresh()` async function orchestrates initial data load
```dart
Future<void> _refresh() async {
  final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
  if (user == null) return;
  await Future.wait([
    ViewingAppointmentProvider.fetchAppointments(user.id!, 'host'),
    HouseProvider.fetchMyHouses(user.id!),
  ]);
  if (!mounted) return;
  BuildingProvider.fetchBuildings();
  // ... more sequential fetches
}
```
- **Pattern:** Parallel where possible (`Future.wait`), sequential when dependent
- **Mounted check:** After each major fetch (line 84, 88, 91) — defensive against unmount during async

### 2.5 Operator Adaptation (Host UI Reuse)

#### Screens Operator Will See (scoped to one owner)
- **Same layout:** HostHomeScreen (2-tab editorial cockpit)
- **Same dashboard widgets:** Hero, stats, action items, listing rows
- **Different data scope:** All queries filtered by `current_owner_context` (not just `current_user`)

#### New Wrapper for Context
- **Portfolio dashboard:** Pre-context screen listing operators' owner portfolios
- **Context header overlay:** Hero section + badge "Đang đại diện cho [Owner Name]" + warm orange color (AC-13)
- **Exit button:** Breadcrumb/button to back to portfolio (AC-14)

---

## 3. Provider Architecture & Patterns

### 3.1 Provider Setup (main.dart)

**File:** `lib/main.dart` (lines 256-291 — MultiProvider setup)

#### Global Provider Stack
```dart
MultiProvider(
  providers: [
    Provider<PermissionService>.value(...),           // First (downstream depends on it)
    Provider<PermissionAnalyticsUploader>.value(...),
    ChangeNotifierProvider<AuthProvider>.value(...),  // Auth must come early
    ChangeNotifierProvider(create: (_) => HostProfileProvider()),
    ChangeNotifierProvider(create: (_) => HouseProvider()),
    ChangeNotifierProvider(create: (_) => ViewingAppointmentProvider()),
    // ... 15+ more providers
    ChangeNotifierProvider(create: (_) => BuildingProvider()),
    ChangeNotifierProvider(create: (_) => RoomProvider()),
    ChangeNotifierProvider(create: (_) => ContractProvider()),
    // ... invoicing, KB04, homestay, marketplace, analytics
  ],
  child: MaterialApp.router(...),
)
```

#### Scope
- **Global** — all providers available from app root
- **Lifetime:** Created once in `_MyAppState.initState()`, retained until app kill
- **AuthProvider special:** `.value` constructor (not `.create`) because State owns its lifecycle; prevents Provider auto-dispose

#### Not Scoped Per Owner
- ⚠️ Current pattern: **all providers are app-global**
- No per-owner provider scoping (e.g., `ProxyProvider` wrapping owner context)
- Implication: **Operator needs `ActorContextProvider`** to scope requests by owner_id

### 3.2 HostProfileProvider Pattern

**File:** `lib/providers/host_profile_provider.dart` (142 lines)

#### Structure
```dart
class HostProfileProvider extends ChangeNotifier {
  final IHostProfileRepository _repo = ApiHostProfileRepository();
  
  HostProfileModel? _profile;
  bool _isLoading = false;
  String? _error;
  
  HostProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnboardingComplete => _profile?.isOnboardingComplete ?? false;
}
```

#### Fetch Pattern
- **Line 28-41:** `fetchProfile()` — standard loading/error/success pattern
  - Sets `_isLoading = true` → fetch → `notifyListeners()` → finally set false + notify
  - Catches `ApiException` with status-specific handling (404 → null, others → rethrow)

#### Mutation Pattern (updateProfile, uploadCccd, upgradeToHost)
- **Lines 43-70, 72-92, 97-115:** Each mutation:
  1. Set loading + clear error
  2. Call repository method
  3. Update local state + notify
  4. Catch exception, store in `_error`
  5. Finally: clear loading, notify

#### No Caching Strategy
- **Observation:** No explicit cache invalidation or TTL
- **Implication:** Each `fetchProfile()` triggers full API call (no stale data awareness)
- `upgradeToHost()` calls `fetchProfile()` immediately (line 106) — assumes profile created by backend

### 3.3 BuildingProvider Pattern (Entity CRUD)

**File:** `lib/features/host/property/providers/building_provider.dart` (103 lines)

#### CRUD Operations
```dart
List<BuildingModel> _buildings = [];

Future<void> fetchBuildings() { /* GET /api/buildings */ }
Future<BuildingModel?> createBuilding({...}) { 
  final b = await _repo.createBuilding(...);
  _buildings = [..._buildings, b];  // Immutable update
  notifyListeners();
  return b;
}
Future<bool> updateBuilding(int id, {...}) {
  final updated = await _repo.updateBuilding(id, ...);
  _buildings = _buildings.map((b) => b.id == id ? updated : b).toList();
  notifyListeners();
  return true;
}
Future<bool> deleteBuilding(int id) {
  await _repo.deleteBuilding(id);
  _buildings = _buildings.where((b) => b.id != id).toList();
  notifyListeners();
  return true;
}
```

#### Immutable Updates
- ✅ **Immutability enforced:** `[...list]`, `.map().toList()`, `.where().toList()` — creates new lists
- **Unmodifiable getter:** `List<BuildingModel> get buildings => List.unmodifiable(_buildings)`

#### Error Handling
- **OnApiException:** Store in `_error`, notify, still notifyListeners (even on failure)
- **Catch-all:** Generic "Không thể tải..." fallback

#### No Filtering by Context
- ⚠️ Fetches **all buildings** for current user (line 23: `_repo.fetchBuildings()`)
- No owner/delegation scoping
- Implication: **Operator provider must fetch only delegated buildings** (per scope)

### 3.4 Providers List (main.dart lines 256-291)

| Provider | Type | Responsibility | Operator Relevance |
|----------|------|-----------------|-------------------|
| AuthProvider | ChangeNotifier | Current user + role | ✅ Owner and operator both use; operator's role='operator' |
| HostProfileProvider | ChangeNotifier | CCCD, bank, KYC status | ✅ Operator needs for operator-profile (US-P3/P4) + owner profile view |
| HouseProvider | ChangeNotifier | Marketplace listings | ⚠️ Scoped to owner context needed |
| ViewingAppointmentProvider | ChangeNotifier | Viewing appts + badges | ⚠️ Scoped to owner context needed |
| BuildingProvider | ChangeNotifier | Buildings CRUD | ⚠️ Scoped to owner context needed |
| RoomProvider | ChangeNotifier | Rooms per building | ⚠️ Scoped to owner context needed |
| ContractProvider | ChangeNotifier | Contracts + expirations | ⚠️ Scoped to owner context needed |
| InvoiceProvider | ChangeNotifier | Invoicing + payments | ⚠️ Scoped to owner context needed |
| KhaiBaoProvider | ChangeNotifier | KB04 declarations | ⚠️ Scoped + fast-track logic (AC-55) |
| NotificationProvider | ChangeNotifier | In-app notifications | ✅ Needs approval notifications routing |
| ChatProvider | ChangeNotifier | Conversations + WS | ⚠️ Scoped to owner context needed |
| DashboardProvider, DrillProvider, etc. | ChangeNotifier | Analytics, reporting | ⚠️ Scoped to owner context needed |

### 3.5 No Built-In Context Scoping

#### Observation
- Current providers use `user.id` from `AuthProvider.currentUser.id` to scope data
- No `ProxyProvider` pattern for operator's acting-as-owner context
- No middleware layer to prepend `X-Acting-As` header

#### Implication for Operator
- **ActorContextProvider** must be created (new)
- **Must wrap or replace repository calls** to inject `X-Acting-As: <owner_id>` header
- OR **patch repositories** to accept optional `actingAsOwnerId` parameter

---

## 4. API Client & HTTP Layer

### 4.1 ApiClient Architecture

**File:** `lib/data/services/api_client.dart` (150+ lines, partial shown)

#### HTTP Methods
```dart
class ApiClient {
  const ApiClient();
  
  Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final headers = <String, String>{};
    if (jsonBody) headers['Content-Type'] = 'application/json';
    final token = await SessionService.instance.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
  
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await http.get(_uri(path, queryParameters), headers: await _headers());
    return _decode(response);
  }
  
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final response = await http.post(
      _uri(path),
      headers: await _headers(jsonBody: true),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decode(response);
  }
  
  // Similar: put(), patch(), delete(), getList(), postList(), getBytes(), uploadImage()
}
```

#### Token Injection
- **Line 41-44:** Every call reads JWT from `SessionService.instance.getToken()` (async)
- **Line 42-43:** Sets `Authorization: Bearer <token>`

#### No Interceptor Pattern
- ⚠️ **Direct http.get/post/patch calls** — no Dio or middleware interceptor
- Headers added per-call in `_headers()` method
- CANNOT inject `X-Acting-As` globally

#### Multipart Upload (CCCD)
- **Line 45-95** (apiHostProfileRepository.dart): Uses `http.MultipartRequest` directly
- Creates request, adds token, sends
- **Implication:** Multipart also needs `X-Acting-As` when operator uploads

### 4.2 Repository Pattern (ApiHostProfileRepository)

**File:** `lib/data/repositories/api_host_profile_repository.dart` (115 lines, partial)

#### Example: Fetch Profile
```dart
Future<HostProfileModel?> fetchProfile() async {
  try {
    final resp = await _client.get('/api/host/profile');  // ← No owner_id param
    final json = Map<String, dynamic>.from(resp);
    return HostProfileModel.fromJson(json);
  } on ApiException catch (e) {
    if (e.statusCode == 404) return null;
    rethrow;
  }
}
```

#### Backend Assumes Single User
- Endpoint `/api/host/profile` implies **backend extracts user_id from JWT token** (not from URL param or header)
- **Implication:** Operator calling `/api/host/profile` in owner context needs different endpoint OR backend route changes based on `X-Acting-As` header

### 4.3 Operator Integration Point

#### For Operator Context Switching
```
operator GET /api/buildings 
  + Header: X-Acting-As: <owner_id>  ← NEW HEADER
  → Backend: return buildings where host_id = owner_id (from header), actor_id = operator_id
```

#### Implementation Options

**Option A: Patch ApiClient (Invasive)**
```dart
// Add to ApiClient
Future<Map<String, dynamic>> get(String path, {
  Map<String, dynamic>? queryParameters,
  String? actingAsOwnerId,  // NEW
}) async {
  final headers = await _headers();
  if (actingAsOwnerId != null) {
    headers['X-Acting-As'] = actingAsOwnerId;  // NEW
  }
  // ... rest of get()
}
```
- Requires all call sites to pass `actingAsOwnerId`
- Tedious; ripple effect on 100+ repository methods

**Option B: Inject ActorContextProvider (Cleaner)**
```dart
class ActorContextProvider extends ChangeNotifier {
  String? _currentOwnerContext;  // null = self-managed, else owner_id
  
  String? get currentOwnerContext => _currentOwnerContext;
  
  void switchOwnerContext(String? ownerId) {
    _currentOwnerContext = ownerId;
    notifyListeners();
  }
}

// In each repository, inject:
class ApiBuildingRepository implements IBuildingRepository {
  final ApiClient _client;
  final ActorContextProvider _actorContext;  // NEW
  
  Future<List<BuildingModel>> fetchBuildings() async {
    final resp = await _client.get('/api/buildings', 
      actingAsOwnerId: _actorContext.currentOwnerContext);
    // ...
  }
}
```
- Cleaner: providers request context, not callers
- Requires Provider injection at repository construction

**Option C: Repository Wrapper Interceptor (Parallel Path)**
```dart
class DelegatedApiClient extends ApiClient {
  final ActorContextProvider _actorContext;
  
  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await http.get(
      _uri(path, queryParameters),
      headers: await _headers()
        ..conditionalAdd('X-Acting-As', _actorContext.currentOwnerContext),
    );
    return _decode(response);
  }
}
```
- Wrapper pattern: less invasive to existing code
- Requires swapping client instance in repos

---

## 5. Routing & Navigation

### 5.1 GoRouter Structure

**File:** `lib/core/router/app_router.dart` (382 lines)

#### Top-Level Routes
```dart
GoRouter buildAppRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) { ... },
    routes: [
      GoRoute(path: '/', pageBuilder: (_) => _RootGate()),
      GoRoute(path: '/login', pageBuilder: (_) => LoginScreen()),
      GoRoute(path: '/host', pageBuilder: (_) => BecomeHostIntroScreen()),
      GoRoute(path: '/host/analytics', pageBuilder: (...) => DeferredRouteWidget(...)),
      // ... 20+ routes (mostly deferred for web splitting)
    ],
  );
}
```

#### Deferred Routes
- **Lines 32-60:** Imports like `import 'path/to/screen.dart' deferred as alias;`
- **Lines 126-229:** Each uses `DeferredRouteWidget` to load on demand
- **Benefit:** Web builds chunk JS separately; native builds don't load analytics until tapped

#### Refresh Trigger
- **Line 71:** `refreshListenable: auth` — router re-runs redirect logic when `AuthProvider` notifies
- **Pattern:** When user logs in/out, provider notifies → redirect fires → router navigates to appropriate home

### 5.2 Redirect Guards (Role-Based)

**Lines 73-99:**
```dart
redirect: (context, state) {
  if (auth.isBootstrapping) return null;  // Wait for auth
  
  final loc = state.matchedLocation;
  final isAuth = auth.isAuthenticated;
  final isAdmin = auth.currentUser?.role == 'admin';
  
  if (_matchesPrefix(loc, '/admin') && !isAdmin) {
    return isAuth ? '/' : '/login';  // Admin only
  }
  if (isAuth && loc == '/login') {
    return isAdmin ? '/admin' : '/';  // Already logged in
  }
  if (!isAuth && (_matchesPrefix(loc, '/host') || loc.startsWith('/house/'))) {
    return '/login';  // Require auth for host/house routes
  }
  return null;  // Allow
}
```

#### No Operator-Specific Redirect
- ⚠️ Currently only checks `isAdmin`
- Will need to add operator-specific logic:
  - `/operator/portfolio` — operator only
  - `/operator/owners/:id/*` — operator only, with delegation permission check

### 5.3 Navigation Patterns in Code

#### Deep-Link in NotificationProvider
**File:** `lib/providers/notification_provider.dart` (lines 150+)**

```dart
void attachFcm(FcmService fcm, GoRouter router, {PermissionAnalyticsUploader? uploader}) {
  _tapSub = fcm.onNotificationTap.listen((RemoteMessage message) {
    // Route based on notification type (via NotificationTapRouter)
    NotificationTapRouter.route(context, message.data, router);
  });
}
```

- **Observation:** FCM tap routing delegates to `NotificationTapRouter` helper
- **Implication:** Operator approval notifications need new route handler (deep-link to approval detail screen)

### 5.4 Operator Route Structure (Design Sketch)

#### New Routes to Add
```
/operator                             → OperatorPortfolioScreen (list owner contexts)
  /operator/owners/:id                → OwnerContextHomeScreen (acts like HostHomeScreen but operator-scoped)
    /operator/owners/:id/buildings    → Same as /host/buildings (scoped)
    /operator/owners/:id/invoices     → Same as /host/invoices (scoped)
    /operator/owners/:id/khaibao      → KB04 screen (scoped)
    /operator/owners/:id/approvals    → ApprovalInboxScreen (NEW)
  /operator/kyc                       → KYC onboarding (US-P3/P4)
  /operator/portfolio/activity-feed   → Activity feed (US-O6)
```

#### Redirect Guards for Operator
```dart
// Add to redirect:
if (_matchesPrefix(loc, '/operator') && !isOperator) {
  return isAuth ? '/' : '/login';
}
// If operator is NOT delegated to :id, redirect to portfolio
if (loc.startsWith('/operator/owners/') && !hasDelegation(ownerId)) {
  return '/operator';
}
```

---

## 6. Theming & Color Palette

### 6.1 Design Tokens

**File:** `lib/core/theme/design_tokens.dart`

#### Existing Palette (HD class)
- **Accent:** `HD.accent` (blue, primary CTA)
- **Positive:** `HD.positive` (green, success)
- **Negative:** `HD.negative` (red, error)
- **Warning:** `HD.warning` (orange/yellow, caution)
- **Paper + Ink:** `HD.paper`, `HD.ink` (background + text)
- **Tints/Shades:** `HD.accentSoft`, `HD.positiveTint`, `HD.warningTint`, etc.

### 6.2 Operator Acting-As Color

**Requirement:** Header changes to warm orange when operator is "acting-as" owner (AC-13)

#### Implementation Options

**Option A: New Token**
```dart
class HD {
  static const Color accent = Color(0xFF0066CC);  // Blue (existing)
  static const Color actingAsAccent = Color(0xFFFF9800);  // Warm orange (NEW)
  // ...
}
```

**Option B: Override in Theme**
```dart
class AppTheme {
  static ThemeData actingAsTheme(ThemeData base) {
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFFFF9800),  // Orange
      ),
      appBarTheme: base.appBarTheme?.copyWith(
        backgroundColor: const Color(0xFFFFF3E0),  // Light orange background
      ) ?? AppBarTheme(...),
    );
  }
}
```

**Option C: Dynamic Provider**
```dart
class ThemeProvider extends ChangeNotifier {
  Color get primaryColor => _actorContext.isActingAs 
    ? const Color(0xFFFF9800)  // Orange
    : HD.accent;  // Blue
  
  notifyListeners();  // When context switches
}
```

#### Recommendation
- **Option C (Dynamic Provider)** — cleanest integration with operator context switching
- Ties theme changes to `ActorContextProvider` state changes
- No need to fork theme creation; just override accent color on-the-fly

---

## 7. State Persistence & Session Management

### 7.1 SessionService (JWT Storage)

**File:** `lib/data/services/session_service.dart`

#### Secure Storage Backend
- **Platform:** Uses `flutter_secure_storage` (Keychain on iOS, EncryptedSharedPreferences on Android, DPAPI on Windows)
- **Storage:** JWT token persisted in platform-native secure storage
- **Conditional imports:** `_session_storage_io.dart` vs `_session_storage_web.dart` for native vs web

#### Bootstrap Flow
**File:** `lib/providers/auth_provider.dart` (lines 39-54)**
```dart
Future<void> bootstrap() async {
  try {
    final token = await SessionService.instance.getToken();
    if (token == null || token.isEmpty) return;  // No prior session
    final user = await _authRepository.me();     // Validate token + fetch current user
    if (user != null) {
      _detectAndHandleRoleChange(user);
      _currentUser = user;
    }
  } catch (_) {
    // Token expired or invalid → silent fail, user sees login screen
  } finally {
    _isBootstrapping = false;
    notifyListeners();
  }
}
```

### 7.2 UserPrefsService (App Preferences)

**File:** `lib/data/services/user_prefs_service.dart` (35 lines)

#### Current Usage
```dart
Future<String?> getLastMode() async {
  return await backend.readToken(_modeKey);  // 'guest' | 'host' | null
}

Future<void> setLastMode(String mode) async {
  await backend.writeToken(_modeKey, mode);
}

Future<void> clearLastMode() async {
  await backend.deleteToken(_modeKey);  // On logout
}
```

#### Reusable Pattern for Operator
```dart
static const _lastOwnerContextKey = 'last_owner_context_id';

Future<String?> getLastOwnerContext() async {
  return await backend.readToken(_lastOwnerContextKey);
}

Future<void> setLastOwnerContext(String ownerId) async {
  await backend.writeToken(_lastOwnerContextKey, ownerId);
}

Future<void> clearLastOwnerContext() async {
  await backend.deleteToken(_lastOwnerContextKey);  // On logout
}
```

### 7.3 No Context Persistence Across Device

**Observation:** `UserPrefsService` is local device only.

#### AC-15b Implication (Cross-Device Safety)
- **Push tap notification:** Deep-link to `/operator/owners/:id/approvals/123` 
- **Context not persisted to server** — app must re-acquire context from:
  - URL path parameters (`:id = owner_id`)
  - API call validation (backend confirms operator has delegation to owner_id)
  - **NOT** from app state (which could be stale on other device)

---

## 8. Notification Stack & FCM Integration

### 8.1 FCM Setup (main.dart)

**Lines 55-135:** FCM initialization

#### Conditional Availability
```dart
PermissionService buildPermissionService({required bool fcmAvailable}) {
  const storage = FlutterSecureStorage();
  final permStorage = PermissionStorage(storage);
  final events = LocalPermissionEventSink(storage);
  
  final FcmService fcm;
  if (fcmAvailable) {
    fcm = FcmService(
      messaging: FirebaseMessaging.instance,
      events: events,
      webVapidKey: null,  // TODO: set from env for web push
      jwtProvider: SessionService.instance.getToken,
    );
  } else {
    fcm = _NullFcmService(events: events);  // Huawei/no-GMS stub
  }
  
  return PermissionService(storage: permStorage, events: events, fcm: fcm, ...);
}
```

#### GMS Detection (AC-N9)
- **Lines 86-92:** Detects GMS availability before Firebase init
- **Lines 117-127:** If Firebase init fails, falls back to no-FCM mode
- **Lines 96-115:** Logs Huawei event (device with no GMS) for fleet telemetry

### 8.2 NotificationProvider (In-App Handling)

**File:** `lib/providers/notification_provider.dart` (partial, 150+ lines)

#### Notification List
```dart
List<NotificationModel> _items = [];
int _unread = 0;

Future<void> fetch(int userId) async {
  _loading = true;
  notifyListeners();
  try {
    final res = await _api.get('/api/notifications');  // Backend extracts user_id from JWT
    _items = List<Map>.from(res['notifications'] as List ?? [])
        .map(NotificationModel.fromMap).toList();
    _unread = (res['unread'] as int?) ?? 0;
  } catch (e) {
    debugPrint('fetch notifications error: $e');
  } finally {
    _loading = false;
    notifyListeners();
  }
}
```

#### Polling
- **Line 49-55:** 30-second poll (periodic refresh)
- **Pattern:** Runs while user authenticated (checks `_userId != null`)
- **Implication:** Operator polling needs to be owner-aware OR scoped per context

#### FCM Foreground + Tap Routing
**Lines 137-150:**
```dart
void attachFcm(FcmService fcm, GoRouter router, {PermissionAnalyticsUploader? uploader}) {
  detachFcm();  // Cancel old subscriptions
  
  // Foreground messages: refresh list immediately
  _fgSub = fcm.foregroundMessages.listen((RemoteMessage message) {
    if (_userId != null) {
      fetch(_userId!);  // Refresh in-app notification list
    }
  });
  
  // Notification taps: route via NotificationTapRouter
  _tapSub = fcm.onNotificationTap.listen((RemoteMessage message) {
    NotificationTapRouter.route(context, message.data, router);
  });
  
  // Token refresh: handled by FcmService.attachUserContext
  // ...
}
```

#### Operator Notification Routing

**New notification types needed:**
| Type | Audience | Route |
|------|----------|-------|
| `approval_requested` | Owner | `/operator/owners/:id/approvals/:approval_id` (owner mode reading operator) |
| `approval_decided` | Operator | `/operator/owners/:owner_id/approvals/:approval_id` (operator feedback) |
| `delegation_invited` | Operator | `/operator/kyc` OR `/operator` (portfolio) |
| `delegation_activated` | Owner | Settings / audit log view |
| `kb04_submitted` | Owner | `/operator/owners/:id/khaibao/:id` (approval inbox) |

### 8.3 Existing Notification Model

**File:** `lib/data/models/notification_model.dart` (inferred)

```dart
class NotificationModel {
  final int id;
  final int userId;
  final String type;  // 'appointment_pending', 'invoice_due', etc.
  final String title;
  final String body;
  final int? relatedId;  // nullable — link to entity (contract, invoice, etc.)
  final bool read;
  final DateTime createdAt;
}
```

#### For Operator Approvals
- **New type:** `approval_request` (owner), `approval_response` (operator)
- **relatedId:** approval_request.id (new DB table)
- **Routing:** NotificationTapRouter must handle owner_id extraction from relatedId + type

---

## 9. Existing KYC & Onboarding Patterns

### 9.1 Host Onboarding Flow (Reusable for Operator)

**Directory:** `lib/features/host/onboarding/`

#### Three-Step Sequence
1. **step1_info_screen.dart** — Full name, phone, bio (personal info)
2. **step2_cccd_screen.dart** — ID card (CCCD) upload front + back
3. **step3_bank_screen.dart** — Bank account (name, number, holder)

#### CCCD Uploader Widget
**File:** `lib/features/host/onboarding/widgets/cccd_uploader.dart`

```dart
class CCCDUploader extends StatefulWidget {
  final Future<bool> Function(XFile front, XFile back) onUpload;
}

// Manages image picker + local preview before upload
```

### 9.2 Operator-Specific Extensions (US-P3, US-P4)

#### For Individual Operator (US-P3)
- Reuse 3-step host onboarding as-is (CCCD + bank)

#### For Company Operator (US-P4)
- **Step 4:** Upload GPKD (business license)
- **Step 5:** Validate "Dịch vụ quản lý BĐS" (property management service) code in GPKD
- **Step 6:** Representative pháp nhân CCCD
- **Step 7:** Representative info

#### KYC Status Tracking
- `HostProfileModel.isOnboardingComplete` pattern can be extended:
  - `operator_individual_kyc_complete` (bool)
  - `operator_company_kyc_complete` (bool)
  - `operator_kyc_expiry` (DateTime) — for renewal reminder (US-P14, AC-50)

---

## 10. Existing Approval-Like UI (Reusable)

### 10.1 ViewingAppointmentProvider Pattern

**File:** `lib/providers/viewing_appointment_provider.dart`

#### Pending Status Management
```dart
Future<void> fetchAppointments(int userId, String role) async {
  // Fetches appointments (status: 'pending' | 'approved' | 'rejected')
  // Badge count: _pendingGuestCount, _pendingHostCount
}

Future<bool> respondToAppointment(int appointmentId, String response) async {
  // response: 'approved' | 'rejected'
  // Optimistic update + API call
}
```

#### Pattern for Operator Approvals
```dart
class ApprovalProvider extends ChangeNotifier {
  List<ApprovalRequestModel> _approvals = [];
  int _pendingCount = 0;
  
  Future<void> fetchApprovals(int ownerId) async {
    final res = await _api.get('/api/operator/owners/$ownerId/approvals');
    _approvals = (res['approvals'] as List).map(...).toList();
    _pendingCount = (res['pending_count'] as int?) ?? 0;
    notifyListeners();
  }
  
  Future<bool> respondToApproval(int approvalId, String decision, String? reason) async {
    // decision: 'approved' | 'rejected'
    // Optimistic + API call to PATCH /api/approvals/:id
  }
}
```

### 10.2 Action Items Section Widget

**File:** `lib/features/host/dashboard/widgets/action_items_section.dart`

```dart
class ActionItemsSection extends StatelessWidget {
  final List<ActionItem> items;  // Tasks needing action
  
  // Renders cards with CTA buttons ("Duyệt", "Từ chối", etc.)
}
```

#### For Operator
- Reuse action_items_section for owner-approval inbox
- Render pending approvals as action cards with approve/reject buttons

---

## 11. Unresolved Architectural Questions

1. **X-Acting-As Header Injection**
   - How to globally inject `X-Acting-As` header without:
     a) Patching all 100+ repository methods?
     b) Creating wrapper interceptor (Dio-like)?
   - **Recommendation:** Option B (ActorContextProvider + per-repo injection) or fork http with interceptor

2. **Provider Scoping per Owner Context**
   - Should each owner context have separate provider instances (BuildingProvider per owner)?
   - Or single provider + filter results by context?
   - **Current design:** Single provider + filter; requires ActorContextProvider aware at fetch time

3. **Notification Polling Awareness**
   - NotificationProvider polls `/api/notifications` every 30s
   - Does operator need owner-context-aware polling?
   - Or does backend handle filtering by `X-Acting-As` header?
   - **Implication:** Operator sees both own notifications + owner approval notifications

4. **Portfolio Dashboard Screen**
   - Where in navigation hierarchy?
   - Operator home → `/operator` (portfolio) vs `/` (home) → detect operator → show portfolio?
   - **Recommendation:** `/operator` top-level route; guest_shell doesn't show persona switcher for operator (see AC-17)

5. **Theme Switching Duration**
   - Operator context switch: should header color change smoothly (animation) or snap?
   - **Current:** Mode switch uses 200ms fade; apply same to header?

6. **Logout on Delegation Revoke (Mid-Session)**
   - AC-16b: mid-session delegation revoke → next API call 401 → force back to portfolio
   - How to re-auth without full logout?
   - **Pattern:** 401 handler in ApiClient → catch, display snackbar, clear context, redirect to `/operator`

7. **Deep-Link Safe Operator Context Acquisition**
   - FCM tap → `/operator/owners/:id/approvals/123`
   - App loads; ActorContextProvider is null.
   - How to safely set context from URL path param **before** first data fetch?
   - **Solution:** `_RootGate` / `GuestShell` parse query/path param → set ActorContextProvider → then build screens

---

## 12. Summary: Reusable vs New Components

### ✅ Fully Reusable (No Changes)
| Component | Current Use | Operator Use |
|-----------|------------|-------------|
| `AnimatedSwitcher` fade animation | guest↔host mode toggle | owner context switch |
| `_LazyIndexedStack` | Lazy child builds | Lazy owner details |
| `HDHeroSection`, `HDStatsGrid`, etc. | Host dashboard | Operator owner-context dashboard |
| `UserPrefsService` pattern | Persist last mode | Persist last owner context |
| `HostProfileProvider` fetch/update | Host profile management | Operator + owner profile viewing |
| `BuildingProvider` CRUD | Building management | Building management (scoped) |
| `ContractProvider`, `InvoiceProvider`, etc. | Property operations | Property operations (scoped) |
| `NotificationProvider` polling + FCM | Notification inbox | Approval inbox + notifications |
| Action items widgets | Dashboard action cards | Approval action cards |
| GoRouter redirect pattern | Role-based guards | Operator-based guards + delegation checks |
| AppTheme + HD tokens | Global color system | Extend with acting-as orange |

### ⚠️ Partially Reusable (Needs Adaptation)
| Component | Current | Adaptation |
|-----------|---------|-----------|
| `guest_shell.dart` persona switcher | 2 fixed personas (guest/host) | N operators × M owners → portfolio + context switcher |
| `app_router.dart` redirect | `/host` for host only | `/operator/*` for operator + delegation permission checks |
| `ApiClient` header injection | Fixed Authorization header | Add optional `X-Acting-As` header |
| Repository classes | Single-user scoped (user.id from JWT) | Owner-context aware (read `X-Acting-As` or ActorContextProvider) |
| Host onboarding (3 steps) | Host individual KYC | Extend step 4-7 for operator company KYC |
| `AuthProvider` role | `'guest'` \| `'host'` \| `'admin'` | Add `'operator'` role (enum value) |

### 🆕 New Components Needed
| Component | Purpose |
|-----------|---------|
| `ActorContextProvider` | Tracks operator's current owner context (scopes all requests with `X-Acting-As` header) |
| `DelegationProvider` | Manages delegation list, invitation state, pause/resume |
| `ApprovalProvider` | Approval inbox, respond (approve/reject), polling |
| `OperatorPortfolioScreen` | Dashboard of owner contexts (list of KPI cards per owner) |
| `OwnerContextHomeScreen` | Host dashboard reused but operator-scoped (wrapper around HostHomeScreen) |
| `ApprovalDetailScreen` | Single approval view + approve/reject action |
| `ActivityFeedScreen` | Timeline of operator actions (audit log viewer) |
| `KYCOperatorCompanyScreen` (steps 4-7) | Company KYC flow extension |
| `DelegationInviteScreen` | Accept/reject operator invite |
| Enhanced `NotificationTapRouter` | Route `approval_requested`, `approval_decided` notifications |
| Theme extension | `actingAsAccent` color + provider-driven theme override |

---

## 13. Code Snippet References (Reusable Patterns)

### Mode Persistence Pattern (to adapt for owner context)
```dart
// From UserPrefsService
Future<String?> getLastMode() => backend.readToken(_modeKey);
Future<void> setLastMode(String mode) => backend.writeToken(_modeKey, mode);

// Adapt for operator:
Future<String?> getLastOwnerContext() => backend.readToken('last_owner_context_id');
Future<void> setLastOwnerContext(String ownerId) => backend.writeToken('last_owner_context_id', ownerId);
```

### Provider Immutable Update Pattern
```dart
// From BuildingProvider
_buildings = [..._buildings, newBuilding];  // Add
_buildings = _buildings.map((b) => b.id == id ? updated : b).toList();  // Update
_buildings = _buildings.where((b) => b.id != id).toList();  // Delete
notifyListeners();
```

### Conditional Render Pattern
```dart
// From GuestShell line 71
final canHost = user?.role == 'host' || user?.role == 'admin';

// Adapt for operator:
final isOperator = user?.role == 'operator';
final hasActiveDelegation = delegationProvider.activeDelegations.isNotEmpty;
if (isOperator && hasActiveDelegation) {
  // Show portfolio + context switcher
} else if (isOperator) {
  // Show KYC onboarding
} else {
  // Show guest/host as normal
}
```

### Async Guard Pattern (mounted + notifyListeners)
```dart
// From HostHomeScreen line 74-94
Future<void> _refresh() async {
  final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
  if (user == null) return;
  await Future.wait([...]);
  if (!mounted) return;  // ← Guard
  await moreAsync();
  if (mounted) setState(() {...});  // ← Guard before state mutation
}
```

### Optimistic Update Pattern
```dart
// From NotificationProvider line 62-83
Future<void> markRead(int id) async {
  // Optimistic: update local state first
  final i = _items.indexWhere((n) => n.id == id);
  if (i >= 0 && !_items[i].read) {
    _items[i] = NotificationModel(..., read: true);
    _unread = (_unread - 1).clamp(0, 9999);
    notifyListeners();
  }
  // Fire API call (non-blocking)
  try {
    await _api.patch('/api/notifications/$id/read');
  } catch (_) {}  // Silent fail; already updated locally
}
```

---

**Status:** DONE

**Summary:** The ancu365 Flutter app uses a well-established pattern (provider-based state, go_router for navigation, persona-switching via AnimatedSwitcher + mode persistence) that is highly reusable for the Owner-Operator delegation feature. The main architectural lift is:

1. **ActorContextProvider** to track operator's current owner context (request-scoped, not session-scoped per AC-15/15b)
2. **Header injection** for `X-Acting-As: <owner_id>` (either via Option B/C in §4.3)
3. **Portfolio dashboard** + context switcher (reuses guest_shell animation pattern)
4. **Permission checks** in GoRouter redirect + delegation provider state
5. **New routes** `/operator/*` tree + approval screens
6. **Theme override** (warm orange during acting-as)
7. **Extended onboarding** for company operator KYC (steps 4-7)

All UI patterns (dashboard widgets, action items, notification routing) are ready to reuse with minimal scope scoping. Primary risk: the codebase uses **no interceptor pattern** (http.get/post directly); `X-Acting-As` injection requires refactoring repository layer or wrapping ApiClient.

