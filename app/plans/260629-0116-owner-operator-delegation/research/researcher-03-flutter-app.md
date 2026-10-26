# Researcher 03 — Flutter App (Owner-Operator Delegation Frontend Research)

**Plan:** `plans/260629-0116-owner-operator-delegation/`
**Author:** Researcher 3
**Date:** 2026-06-29
**Scope:** Flutter app architecture, UI patterns, notification handling, state management, role-based logic

---

## A. Architecture / State Management

### State Management: Provider (not Riverpod, GetX)
- **Framework:** `provider: ^6.1.5+1` (ChangeNotifier-based)
- **Bootstrap:** `main.dart` L262–297 — ~23 providers registered at app root via `MultiProvider`
- **Auth state:** `AuthProvider` (lib/providers/auth_provider.dart) holds `_currentUser: UserModel?`
- **Current user propagation:** Via `Provider.watch<AuthProvider>().currentUser` on any screen

**Key insight:** No context layer concept today — just `currentUser` at root. For operator delegation:
- Will need new provider (e.g. `OperatorDelegationProvider`) to track "acting-as" context (owner_id)
- Context must be **request-scoped** per BA v4 §3 (not session-scoped) → likely passed as param to API calls, not cached in JWT
- Auth refresh on app resume (L254–258) calls `_uploader.flush()` — hook point for syncing delegation context

### Routing: go_router (not Navigator 2.0, custom, or GetX)
- **Framework:** `go_router: ^14.6.2`
- **Configuration:** `lib/core/router/app_router.dart` L66–300+
- **Redirect logic:** L73–98 checks `isAuthenticated`, `currentUser?.role`, `matchedLocation`
- **Route refresh:** L71 `refreshListenable: auth` — router rebuilds on AuthProvider notifyListeners
- **Routes by role:** Admin → `/admin` only (L82–86); host → `/host`, `/host/analytics`, etc.; guest → `/`, `/house/:id`
- **Deferred routes:** Analytics, admin, detail use `deferred as` for code-splitting on web (L35–59)

**For delegation:**
- New route `/operator` (parallel to `/host`) for operator portfolio dashboard
- No new PersonShell needed — reuse `GuestShell` pattern (persona_mode.dart) for owner-context overlay
- Deep linking: notification tap → operator can land on owner's property (AC-51)

### Current User Model
- **Location:** `lib/data/models/user_model.dart`
- **Fields:** `id`, `name`, `email`, `phone`, `avatarPath`, `role` (string: 'admin'|'host'|'guest'), `isActive`, `birthday`, `bio`, `idNumber`
- **Role:** single string, NOT array — no multi-tenancy yet
- **Auth flow:** LoginScreen → register/login → AuthProvider stores user + token (SessionService)

**Gap for delegation:**
- UserModel.role is single string — needs to track "can operate as owner_id X" alongside "primary role"
- No company affiliation (operator_doanh_nghiệp needs GPKD + legal rep info)

---

## B. Existing Relevant Screens

### Onboarding / Auth Flow
1. **LoginScreen** (`lib/features/auth/login_screen.dart`) — email/password
2. **RegisterScreen** (`lib/features/auth/register_screen.dart`) — name/email/phone/password, sets `role: 'guest'`
3. **OnboardingScreen** (`lib/features/onboarding/onboarding_screen.dart`) — post-login KYC flow
4. **BecomeHostIntroScreen** (`lib/features/host/onboarding/become_host_intro_screen.dart`) — entry to host signup (likely multi-step: info/CCCD/bank)

**For delegation:**
- Operator signup: extend BecomeHostIntroScreen + add step for company type (cá nhân vs doanh nghiệp)
- KYC cá nhân: reuse existing 3-step flow (step1_info, step2_cccd, step3_bank)
- KYC doanh nghiệp: new step — GPKD + legal rep info + high-value biometric (AC-29b)

### Property / Contract Management
1. **BuildingListScreen** (`lib/features/host/property/screens/building_list_screen.dart`) — list all buildings
2. **BuildingDetailScreen** → rooms → contracts (nested nav)
3. **RoomDetailScreen** → can edit, view contracts, tenant badges
4. **ContractDetailScreen** (`lib/features/host/property/screens/contract_detail_screen.dart`) — full contract view + tenant list
5. **ContractFormScreen** (`lib/features/host/property/screens/contract_form_screen.dart`) — create/edit contract
6. **ContractTerminateScreen** — soft-delete workflow
7. **ContractTransferRoomScreen** — move tenant to different room

**For delegation:**
- Operator dashboard = property portfolio (subset of owner's buildings)
- Tenant badges: add "Operated by [Operator Name]" (AC-60)
- Contract approve/reject modal: operator requests, owner approves (AC-51 + high-value approval threshold D5 from expert matrix)

### Notifications / Inbox
1. **NotificationsScreen** (`lib/features/notifications/notifications_screen.dart`) — list + mark read
2. **NotificationProvider** (`lib/providers/notification_provider.dart`) — polling 30s, FCM push streams

**For delegation:**
- Operator receives: invitation status, owner approval requests (contract create, KB04 submit, etc.)
- Owner receives: "operator did X on property Y" + escalation badges (high-value actions)
- Push UI: only in-app push (v1) → email (v1) → SMS/Zalo ZNS (v1.1, D8 decision)

### Host Home / Dashboard
1. **HostHomeScreen** — host shell (likely tab bar or bottom nav)
2. **HostDashboardTokens** — KPI widgets (revenue, occupancy, expiring contracts)
3. **AnalyticsHomeScreen** (deferred) — drill-down revenue charts

**For delegation:**
- Operator dashboard: subset of metrics (only their managed properties) + owner overlay badge ("Bạn đang xem/đang đại diện cho Anh A")
- Owner view: operator performance metrics + audit breadcrumb (who did what)

### Admin
1. **AdminHomeScreen** (deferred) — backend-only or light Flutter UI?

**Note:** BA v4 doesn't mention Flutter admin UI — confirm with planner if operator approval flows live here or in host dashboard.

---

## C. Notification Handling on Client

### FCM Setup
- **Service:** `lib/core/permissions/fcm_service.dart` (Phase 4–6 integration)
- **Firebase init:** main.dart L125–126 (GMS detection on Android; no-FCM stub on Huawei, L325–379)
- **Foreground presentation:** FCM.setForegroundNotificationPresentationOptions L88–91 (alert/badge/sound on iOS)
- **Message streams:** `foregroundMessages` + `notificationTaps` (L353–356)
- **Token lifecycle:** registerToken/unregisterToken (L371–378), token refresh listener on attach (L80)

### NotificationProvider Streams
- **Polling:** 30s timer L52, only when authenticated
- **FCM:** foreground subscription (when app in focus) + tap router (L20–23 sub handlers, Phase 4 integration)
- **Tap routing:** `lib/features/permissions/helpers/notification_tap_router.dart` — maps notification type → route

**Current capabilities:**
- ✅ Fetch notification list (REST `/api/notifications`)
- ✅ Mark read (optimistic + async `/notifications/{id}/read`)
- ✅ Unread badge count
- ✅ FCM token registration (Phase 6: registerToken + attachUserContext)
- ❌ Deep linking from FCM push to owner's property (exists as mechanism, not yet used in delegation context)
- ❌ Zalo ZNS / SMS fallback (deferred v1.1, D8)

### Audit Event Logging for Permission Priming
- **Location:** `lib/core/permissions/permission_events.dart` + `permission_storage.dart`
- **Events:** Tracks permission outcomes (granted, denied, deferred, Huawei GMS missing) — NOT audit of operator actions
- **Purpose:** Analytics on permission grant rates (not relevant to delegation audit trail, which is backend)

**For delegation:**
- Operator actions logged on backend (audit_log / change_log) — Flutter only displays
- Notification UI: use existing NotificationProvider + extend tap router for delegation context (e.g. tap "Owner approved contract" → jump to ContractDetailScreen with owner context overlay)

---

## D. Role-Based UI

### Current Role Logic
- **Auth level:** `currentUser.role` (string: 'admin'|'host'|'guest')
- **Router level:** L82–86 redirect admin-only routes; L94–96 kick non-auth users from `/host`
- **Screen level:** RegisterScreen L52 hardcodes `role: 'guest'`; auth_provider.dart L45, L64 detect role changes (L45 `_detectAndHandleRoleChange`)

### Persona Switcher (Airbnb Pattern)
- **Location:** `lib/features/guest/guest_shell.dart` + `lib/features/guest/persona_mode.dart`
- **Mechanism:** L34 `_mode = kModeGuest|kModeHost`; toggle stored in UserPrefsService L62–66, persists across sessions
- **Animation:** L52 Duration.zero on bootstrap, 200ms on manual toggle
- **Bottom nav:** 4 tabs in guest mode, 4 different tabs in host mode

**Reusability for delegation:**
- ✅ Can wrap host dashboard in similar overlay
- ✅ "Bạn đang đại diện cho [Owner Name]" header badge + muted orange tint (BA v4 §3.1)
- ⚠️ Persona mode is top-level (session-wide) — delegation context should be **request-scoped** (BA v4 says so); need new pattern (context provider, not persisted mode)

### No Current Role-Based UI Filtering
- **Gap:** No component-level `.watch<AuthProvider>()` role checks for conditional rendering within a screen
- **Typical pattern:** Most host screens assume `role == 'host'` after navigation (router guards it)
- **For delegation:** Need operator view of contracts to hide/disable "terminate" + "change operator" buttons, show "request owner approval" instead

---

## E. Forms / KYC UI Components

### Image Picker + Camera
- **Package:** `image_picker: ^1.1.2`, `image_cropper: ^12.2.1`
- **Usage:** Likely in KYC CCCD step + room/contract handover photos
- **Pattern:** Not explicitly found in grep scope — check `step2_cccd` and room/contract forms

### Form Builder
- **Package:** `flutter_form_builder: ^10.0.0` + `form_builder_validators: ^11.0.0`
- **Usage:** Likely in RegisterScreen, BecomeHostIntroScreen, ContractFormScreen
- **Patterns:** GlobalKey<FormState>, _formKey.currentState!.validate() (RegisterScreen L40)

**For delegation:**
- Operator signup form: new company type selector (cá nhân / doanh nghiệp)
- If doanh nghiệp: GPKD upload + legal rep name + signing authority checkbox
- POA digital signature UI (AC-55d): new component for FastCA/VinaCA cert upload (not found in current codebase — new)

### File Upload / Storage
- **Gap:** No explicit file upload UI component found (expected in KYC steps)
- **Likely:** Combined with image_picker + image_cropper for CCCD photo
- **For delegation:** POA PDF + digital signature cert — need file picker + upload progress

### Permissions / Biometric
- **Location:** `lib/core/permissions/` — PermissionService, BiometricService(?), GmsDetector, FcmService
- **Permission handling:** permission_handler L66, permission_service.dart (requestPermission flow)
- **Biometric:** Not found in current scope — AC-29b (high-value biometric) is new requirement

**For delegation:**
- AC-29b KYC doanh nghiệp: might need biometric capture (confirm with planner)
- Existing permission priming can be extended (currently for notifications)

---

## F. Design System / Shared Widgets

### Design Tokens (Editorial Cockpit)
- **Location:** `lib/core/theme/design_tokens.dart` (class `HD`)
- **Palette:** Warm cream (paper #F4F1EC), navy ink (#0B1C30), terracotta accent (#B5462E), earthy status colors
- **Naming:** `HD.paper`, `HD.ink`, `HD.accent`, `HD.positive`, `HD.warning`, `HD.negative`
- **Typography:** Be Vietnam Pro (via google_fonts, bundled in assets/google_fonts/), Material 3 scales
- **Spacing:** Not explicitly defined in token class (likely Material 3 defaults)

### Widget Library (Ds* family)
- **Barrel:** `lib/core/widgets/ds.dart` — exports all Ds* components
- **Components:** DsAppBar, DsButton, DsCard, DsDialog, DsBottomSheet, DsChip, DsTextField, DsTabBar, DsListTile, DsKpiCard, DsBigNumeral, DsFormSection, Skeleton, EmptyState, AppFeedback

**For delegation:**
- DsDialog / DsBottomSheet: owner approval modals (contract create, KB04 submit, operator invite)
- DsChip + badge: "Operated by X" tenant badge (AC-60)
- DsAppBar: overlay "Bạn đang đại diện cho [Owner]" eyebrow (mimic persona_mode design)
- Skeleton: loading state for operator portfolio on first load
- EmptyState: "Chưa có property nào được ủy thác" / "Chưa có yêu cầu phê duyệt nào"

### Empty / Loading / Error Patterns
- **Skeleton:** `lib/core/widgets/skeleton.dart` — DsSkeleton, DsRowSkeleton, HouseCardSkeleton
- **EmptyState:** `lib/core/widgets/empty_state.dart` — DsEmptyState (with illustration + text)
- **Error feedback:** AppFeedback (not explicit in barrel export, but used in RegisterScreen L65)

**Status:** Good coverage; reusable for delegation screens.

---

## G. API Client / Data Layer

### HTTP Client
- **Library:** `http: ^1.6.0` (NOT Dio, but Dio IS in pubspec L53 for potential future use)
- **Client class:** `ApiClient` (lib/data/services/api_client.dart) — wraps http with auth headers
- **Base URL:** ApiConfig.baseUrl (config file not in scope)
- **Auth:** Bearer token from SessionService L42–44

### API Methods
- GET, POST, PUT, PATCH, DELETE (L48–100+)
- Query params filtered (L26–30) — null values dropped
- Response decode: `_decode()` (not shown in scope, likely JSON parse + error handling)

### Repository Pattern
- **Example:** `ApiContractRepository` (imported in contract_provider.dart) — wraps HTTP calls
- **Methods:** fetchContracts, createContract, etc.
- **Exception:** `ApiException(statusCode, message)` with `.isUnauthorized` helper

**For delegation:**
- New repository: `ApiOperatorDelegationRepository` with methods:
  - fetchMyDelegations() → List<OperatorDelegation>
  - inviteOperator(ownerUserId, operatorUserId, rolePreset) → Invitation
  - approveContract(contractId, approvalType) → Contract
  - getOperatorActions(delegationId) → List<AuditLogEntry>

### Data Models (Codegen?)
- **Models:** UserModel, ContractModel, etc. — manually written (no freezed/json_serializable evident)
- **Serialization:** fromJson/fromMap factories + toMap methods

**For delegation:**
- New models:
  - `OperatorDelegation` (id, owner_id, operator_id, rolePreset, scope_id, status, createdAt, updatedAt)
  - `DelegationInvitation` (id, owner_id, operator_id, status, createdAt, approvedAt)
  - `ApprovalRequest` (id, owner_id, operator_id, request_type, entity_id, status, sla_expires_at)

---

## H. i18n Setup

### Flutter i18n
- **Package:** `intl: ^0.20.0`
- **Localization delegates:** flutter_localizations (main.dart L8, 302–305)
- **Supported locales:** Vietnamese + English (L307–310)
- **Default:** Locale('vi') (L311)

**Current state:**
- Strings are hardcoded in UI (e.g. RegisterScreen L42 'Bạn cần đồng ý với Điều khoản sử dụng')
- No .arb or i18n message catalog found in scope

**For delegation:**
- Need string dictionary for:
  - Operator signup copy (company type, GPKD, legal rep)
  - Approval request modal copy (contract pending owner approval, KB04 SLA 6h, etc.)
  - Audit timeline labels (who did what, when)
  - Tenant badge: "[Operator Name] đang quản lý"
  - Error messages: "Vượt quá ngưỡng phê duyệt", "Chưa được cấp quyền cho property này"

---

## I. Testing / Build

### Unit Test Setup
- **Framework:** `flutter_test` (SDK)
- **Mocking:** `mocktail: ^1.0.4`
- **Pattern:** Not found in app (likely in separate test/ directory not in scope)

### Integration Test
- **Framework:** `integration_test` (SDK)
- **Note:** Referenced in pubspec but no tests in scope

### Build / CI
- **Linting:** `flutter_lints: ^6.0.0` + `analysis_options.yaml` (minimal config)
- **Build commands:** Assumed standard `flutter build apk|ios|web`

**For delegation:**
- Add unit tests for OperatorDelegationProvider (scope switching)
- Add integration tests for operator invite → approval → contract flow

---

## J. Existing API Contracts (Flutter ↔ Backend)

### Auth Endpoints (Assumed)
- `POST /auth/register` — name, email, phone, password, role
- `POST /auth/login` — email, password
- `GET /api/me` — returns UserModel (called in auth_provider.dart L43)

### Notification Endpoints
- `GET /api/notifications` — list (notification_provider.dart L35)
- `PUT /notifications/{id}/read` — mark read (L80+)

### Property / Contract Endpoints (Inferred)
- `GET /api/buildings` — list all buildings (BuildingProvider assumed)
- `GET /api/buildings/{id}` — detail
- `POST /api/buildings/{id}/rooms` — create room
- `GET /api/contracts?status=...&roomId=...` — list (contract_provider.dart L31)
- `POST /api/contracts` — create (L67, expects roomId, tenants list)
- `GET /api/contracts/{id}` — detail
- `PUT|PATCH /api/contracts/{id}` — update
- `DELETE /api/contracts/{id}` — soft-delete / terminate

### FCM Endpoints (Phase 6)
- `POST /api/fcm-tokens` — register token (fcm_service.dart L371 stub)
- `DELETE /api/fcm-tokens/{tokenId}` — unregister

**For delegation (NEW endpoints needed):**
- `POST /api/operator-delegations` — create delegation + send invitation
- `GET /api/operator-delegations?owned_by=X` (for owner dashboard)
- `GET /api/operator-delegations?operator_id=X` (for operator portfolio)
- `PUT /api/operator-delegations/{id}` — update status (approve/revoke)
- `GET /api/operator-delegations/{id}/actions` — audit log (who did what)
- `GET /api/invitations` — operator views pending invites to accept/reject
- `POST /api/contracts/{id}/approvals` — owner approval request queue (new entity)
- `GET /api/approvals?assigned_to=owner_id` — owner dashboard approval queue
- `PUT /api/approvals/{id}` — approve/reject contract create, KB04 pre-file, etc.

---

## Implications for Delegation Feature (BA v4 sections)

### US-O1 (Owner invites operator)
- **Screen location:** New "Invite Operator" tab on HostHomeScreen (or separate SettingsScreen)
- **UX:** Modal form → operator email/phone → role preset selector → set approval thresholds → send invite
- **Widget reuse:** DsDialog + DsFormSection + DsButton
- **State:** OperatorDelegationProvider manages invitation list

### US-P1 / US-P2 (Operator dashboard)
- **Screen location:** New `/operator` route (parallel to `/host`)
- **Shell:** Reuse GuestShell pattern for persona switching (operator-as-owner context)
- **Content:** Portfolio of delegated properties (BuildingListScreen subset) + audit timeline
- **UX:** "Bạn đang đại diện cho [Owner Name]" overlay badge at top

### US-T1 (Tenant badge AC-60)
- **Screen location:** RoomDetailScreen, TenantRowWidget
- **Badge:** "Operated by [Operator Name]" chip next to tenant name (DsChip + icon)
- **Data:** Fetch operator name from delegations table at contract load time

### AC-29b (High-value biometric)
- **Flow:** During operator onboarding (BecomeHostIntroScreen step 4?)
- **UI:** Camera capture + biometric library (NOT YET INTEGRATED)
- **Decision:** Confirm with planner if using platform-native biometric or third-party service

### AC-55d (POA digital signature)
- **Flow:** Operator doanh nghiệp upload GPKD + legal rep info (new onboarding step)
- **UI:** File picker for POA PDF + digital signature cert upload (NOT YET INTEGRATED)
- **Service:** FastCA / VinaCA integration (new dependency, not in pubspec)
- **Status:** Deferred to phase with contract signing feature

### AC-30b (Push + email + SMS escalation)
- **v1 (current):** In-app push only (FCM stream → NotificationProvider → tap router)
- **v1:** Email fallback (backend sends; Flutter displays badge/count)
- **v1.1:** SMS + Zalo ZNS (decision D8 defers to v1.1; no client code v1)
- **Flutter responsibility:** Display escalation status in approval modal (e.g. "Owner notified via email at 2:15 PM")

### AC-64 (Sole-ownership attestation modal at onboarding)
- **Flow:** During operator invite acceptance (new modal before contract operations)
- **Content:** "Tôi xác nhận tôi là chủ sở hữu duy nhất" ← legal attestation (D4 decision: refuse co-owned in v1)
- **UI:** DsDialog + checkbox + button
- **State:** Tracked in OperatorDelegationProvider or stored server-side

### AC-66 (Shared-login disclosure modal at first login for PMC)
- **Flow:** Operator doanh nghiệp first login after invite accepted
- **Content:** "Shared login không hỗ trợ RBAC v1. Mọi hành động được ghi vào audit log với shared identity."
- **UI:** DsDialog + info text + "I understand" button
- **State:** One-time shown flag in UserPrefsService or server-side seen flag

### Audit / Timeline View (AC-32)
- **Screen location:** New "Audit Log" tab on property detail (OperatorDelegationProvider.getActions)
- **Content:** Timeline list: "[Operator Name] tạo contract #123 lúc 2:30 PM" + "Chi tiết" (expandable JSON)
- **UI:** DsListTile with timeline dot + operator avatar + action description
- **Widget:** Timeline widget (likely custom, not in pubspec)

---

## Known Risks / Gotchas

### Risk 1: No Existing "Acting-As" / Delegation Context Pattern
- **Issue:** Provider only tracks single currentUser; no concept of "operator acting on behalf of owner"
- **Mitigation:** New OperatorDelegationProvider with request-scoped context (param passed to API, not JWT)
- **Effort:** 1–2 days to establish pattern + integrate with all relevant providers

### Risk 2: Role-Based UI Logic Scattered
- **Issue:** No centralized role/permission service; role checks live in routers + screens individually
- **Mitigation:** Create PermissionService variant or extend AuthProvider with capability checks (e.g. `canTerminateContract(contractId)`)
- **Effort:** 3–5 days to audit all role checks + refactor into provider

### Risk 3: No Biometric Integration Yet
- **Issue:** AC-29b requires biometric capture; not in pubspec or codebase
- **Mitigation:** Add platform-native biometric (local_auth or similar) or defer to later phase
- **Effort:** 2–3 days for baseline integration

### Risk 4: No Digital Signature / Document Upload UI
- **Issue:** AC-55d POA signature + GPKD upload not in codebase
- **Mitigation:** Use image_picker for file upload; sign via FastCA/VinaCA backend
- **Effort:** 2 days for file picker UI + FormField validation

### Risk 5: Persona Mode Is Session-Wide, Delegation Must Be Request-Scoped
- **Issue:** GuestShell.persona_mode persists mode to UserPrefsService; BAv4 says delegation context is per-request
- **Mitigation:** Create new DelegationContextProvider (NOT persisted) that wraps each API call with `?acting_as=owner_id`
- **Effort:** 1 day, but CRITICAL for security (prevent stale context across tab switches)

### Risk 6: ContractModel + Related Entities Don't Have Operator Awareness
- **Issue:** ContractModel.hostId = owner_id; no operator_id or delegation_id field
- **Mitigation:** Backend returns delegation info in related field or separate endpoint; Flutter cache in OperatorDelegationProvider
- **Effort:** 1 day for model updates + provider caching

### Risk 7: No Timeline / Audit UI Widget Library
- **Issue:** AC-32 audit timeline display not in design system
- **Mitigation:** Create custom DsTimeline widget or use third-party package (e.g. timeline)
- **Effort:** 1–2 days

### Risk 8: Notification Deep Linking + Operator Context
- **Issue:** Notification tap routed to contract detail; must include delegation context
- **Mitigation:** Notification payload includes delegation_id; router passes it to screen
- **Effort:** 1 day (plumbing in tap_router.dart + notification_provider.dart)

### Risk 9: Image Cache May Bloat with Operator Portfolio
- **Issue:** main.dart L146–150 tunes image cache for ~2000 items; operator managing 50+ properties = many more images
- **Mitigation:** Portfolio pagination or lazy-load property thumbnails
- **Effort:** 1 day (if issue occurs in testing)

### Risk 10: Zalo Integration Deferred (v1.1)
- **Issue:** D8 decision defers Zalo ZNS to v1.1; v1 must handle SMS/email notification display gracefully
- **Mitigation:** UI shows "Owner notified via [channel]" label; backend provides channel hint in notification payload
- **Effort:** 1 day (label display, no actual SMS client code needed v1)

---

## Recommended Tech Lead Discussion Points

1. **Request-scoped delegation context (NOT persisted):**
   - How to pass `?acting_as=owner_id` on all OperatorDelegationRepository calls without threading through 20+ screens?
   - Consider: OperatorDelegationProvider field + Listener middleware on ApiClient to inject header/query param?

2. **Approval request workflow UI pattern:**
   - New "Pending Approvals" badge on HostHomeScreen?
   - Approval modal: blocking (prevent operator proceed) or advisory (operator can see rejection history)?

3. **Biometric + high-value operator KYC:**
   - Use platform-native (local_auth package) or third-party service (Jumio, etc.)?
   - Timing: phase 02 (schema/models) or phase 03+ (UI flows)?

4. **POA document upload + digital signature:**
   - File picker + backend FastCA/VinaCA integration scope?
   - Or defer to phase 05+?

5. **Timeline widget:**
   - Build custom DsTimeline or import pub.dev package?
   - Data format: backend returns flat list of AuditLogEntry or nested ChangeLog records?

---

**Status:** DONE
**Summary:** Flutter app uses Provider + go_router, has Airbnb-style persona switching (reusable for operator context), and mature notification/form infrastructure. Key gaps: no delegation/approval request UI patterns, no biometric/digital sig, and role-based UI logic scattered across routers + screens.
**Report location:** `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/plans/260629-0116-owner-operator-delegation/research/researcher-03-flutter-app.md`
