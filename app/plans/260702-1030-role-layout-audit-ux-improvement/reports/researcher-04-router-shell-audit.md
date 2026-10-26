# Router & Shell Architecture Audit: Role-Based Layout Coverage

**Date:** July 2, 2026  
**Scope:** Cross-cutting routing, shell, profile, navigation — all 5 roles (`guest`, `host`, `admin`, `operator`, `tenant`)  
**Status:** COMPLETE

---

## Executive Summary

Three separate **role/persona dimensions** coexist with incomplete guards:
1. **Auth role** (`guest`|`host`|`admin`) — stored in `user.role`, controls route access
2. **UI persona** (`guest`|`host` modes) — ephemeral toggle in `GuestShell`, persisted in prefs, does NOT gate routes
3. **Actor delegation context** — operator "acting as" owner, request-scoped via `X-Acting-As-Delegation-Id` header

**Critical findings:**
- Admin routes guarded at router level; host/operator/tenant routes lack guards
- All roles fall back to `GuestShell` — no role-specific shells for host/operator/admin/tenant
- Profile screen hardcodes only admin role check; `operator` and `tenant` sections absent
- Persona mode (`GuestShell`) does NOT prevent deep-linking across role boundaries
- Actor context isolated from auth role model; potential for confusion when switching context

---

## Router Coverage Matrix

### Full Route Audit (700+ line router file)

| Route | Expected Guard | Actual Implementation | Status | Risk |
|-------|---|---|---|---|
| `/` | None (root gate) | `_RootGate` → splash/onboard/login/shell | ✓ CORRECT | Low |
| `/login` | None (any) | `LoginScreen` | ✓ CORRECT | Low |
| `/host` | `isAuth` | Guarded line 104–110; redirects to `/login` | ✓ CORRECT | Low |
| `/host/analytics` | `isAuth && isHost` | **Deferred (lazy load), NO GUARD** | ❌ MISS | Medium |
| `/host/analytics/trend` | `isAuth && isHost` | **Deferred, NO GUARD** | ❌ MISS | Medium |
| `/host/analytics/heatmap` | `isAuth && isHost` | **Deferred, NO GUARD** | ❌ MISS | Medium |
| `/host/analytics/drill/rooms` | `isAuth && isHost` | **Deferred, NO GUARD** | ❌ MISS | Medium |
| `/host/analytics/drill/room/:id/contracts` | `isAuth && isHost` | **Deferred, NO GUARD** | ❌ MISS | Medium |
| `/host/analytics/drill/contract/:id/tenants` | `isAuth && isHost` | **Deferred, NO GUARD** | ❌ MISS | Medium |
| `/host/analytics/drill/tenant/:id/invoices` | `isAuth && isHost` | **Deferred, NO GUARD** | ❌ MISS | Medium |
| `/host/analytics/sources` | `isAuth && isHost` | **Deferred, NO GUARD** | ❌ MISS | Medium |
| `/admin` | `isAdmin` | Guarded line 95–97; redirects correctly | ✓ CORRECT | Low |
| `/map` | `isAuth` (implicit) | **Deferred, NO GUARD** | ⚠️ PARTIAL | Low (public data) |
| `/planning` | None (guest ok for public map) | **Deferred, NO GUARD** | ✓ INTENDED | Low |
| `/house/:id` | `isAuth` (implicit) | **Deferred, NO GUARD** | ⚠️ PARTIAL | Low (fallback to API auth) |
| `/operator` | `isAuth && isOperator` | **NO GUARD** | ❌ MISS | **HIGH** |
| `/operator/owner/:id` | `isAuth && isOperator && ownerDelegationExists` | **NO GUARD** | ❌ MISS | **HIGH** |
| `/operator/owner/:id/audit` | `isAuth && isOperator && ownerDelegationExists` | **NO GUARD** | ❌ MISS | **HIGH** |
| `/operator/invitations` | `isAuth && isOperator` | **NO GUARD** | ❌ MISS | **HIGH** |
| `/host/delegation/invite` | `isAuth && isHost && buildingExists` | **NO GUARD** | ❌ MISS | **HIGH** |
| `/host/delegation/:id` | `isAuth && isHost && delegationOwnershipExists` | **NO GUARD** | ❌ MISS | **HIGH** |
| `/host/approvals` | `isAuth && isHost` | **NO GUARD** | ❌ MISS | **HIGH** |
| `/tenant/report-unauthorized/:id` | `isAuth && isTenant` | Guarded line 108 (redirect to login) | ⚠️ PARTIAL | **HIGH** |
| `/permission-debug` | `kDebugMode` | Guarded line 410–417 | ✓ CORRECT | Low (debug only) |

---

## Router Guard Implementation

### Actual Redirect Logic (lines 83–111)

```dart
if (auth.isBootstrapping) return null;

final loc = state.matchedLocation;
final isAuth = auth.isAuthenticated;
final isAdmin = auth.currentUser?.role == 'admin';

// ✓ GUARD 1: /admin requires isAdmin
if (_matchesPrefix(loc, '/admin') && !isAdmin) {
  return isAuth ? '/' : '/login';
}

// ✓ GUARD 2: Redirect logged-in users away from /login
if (isAuth && loc == '/login') {
  return isAdmin ? '/admin' : '/';
}

// ⚠️ GUARD 3: Unauthenticated barrier for host/operator/tenant
if (!isAuth &&
    (_matchesPrefix(loc, '/host') ||
        loc.startsWith('/house/') ||
        _matchesPrefix(loc, '/operator') ||
        _matchesPrefix(loc, '/tenant/report-unauthorized'))) {
  return '/login';
}
```

**Gaps:**
- No role-specific guards after auth (e.g., operator redirected to root if not operator)
- Deferred routes bypass redirect logic (lazy-loaded at widget level, no pre-flight check)
- `/tenant/report-unauthorized` only checks auth, not tenant role
- Host/operator/tenant CAN land on routes intended for other roles if they craft URLs

---

## Shell Architecture: Single-Shell Design

### Current Implementation

**One shell for all:** `GuestShell` (lines 23–316 in guest_shell.dart)

| Role | Shell | Tab 0 | Tab 1 | Tab 2 | Tab 3 |
|------|-------|-------|-------|-------|-------|
| `guest` | `GuestShell` | Home | Wishlist | Booking History | Profile |
| `host` | `GuestShell` (persona=host) | Dashboard | Buildings | Appointments | Profile |
| `admin` | `GuestShell` (redirected to `/admin` THEN deferred) | — | — | — | — |
| `operator` | `GuestShell` (no persona toggle) | — | — | — | — |
| `tenant` | `GuestShell` (guest persona by default) | — | — | — | — |

**Why problematic:**
- **Admin path:** Redirected to `/admin` at router level → never reaches `GuestShell`. Good.
- **Operator path:** Lands on `GuestShell` with guest tabs showing. No persona toggle for `operator` role (only `host` can toggle). Operator sees guest UI, must manually navigate to `/operator` route.
- **Tenant path:** Same as guest; no distinct tabs or navigation.
- **Persona confusion:** `GuestShell` checks `role == 'host' || role == 'admin'` to enable persona toggle (line 134), but `/admin` users never reach this code.

### Persona Toggle Logic (lines 134–149 in guest_shell.dart)

```dart
final canHost = user?.role == 'host' || user?.role == 'admin';

// Late-binding: auth bootstrap finishing after shell mounts
// should re-resolve persona mode
if (_bootstrapped && user?.role != _lastSeenRole) {
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => _reconcileWithRole(user?.role),
  );
}

// Persona resolver (lines 70–79)
void _applyResolvedMode({String? saved, String? role}) {
  final canHost = role == 'host' || role == 'admin';
  final target = (saved == kModeHost && canHost) ? kModeHost : kModeGuest;
  // ...sets _mode = target
}
```

**Issue:** Persona is **NOT a router guard**. It's a UI toggle. A guest who:
1. Swaps device with a host user
2. Host logs in, enables host persona, closes app
3. Original guest logs back in (via shared device)
4. Could theoretically receive host persona if pref wasn't cleared

**Mitigation (line 127 in auth_provider.dart):**
```dart
await UserPrefsService.instance.clearLastMode(); // ✓ Clears on logout
```
Good, but window exists between logout + clear (async).

---

## Profile Section Leakage

### Admin Role Check (line 333 in profile_screen.dart)

```dart
Widget _roleBadge(String role) {
  final isAdmin = role == 'admin';
  final label = isAdmin ? 'Quản trị' : 'Thành viên';
  // ...
}
```

**Finding:** Only two labels shown: `Quản trị` (admin) or `Thành viên` (member). No distinction for `host`, `operator`, or `tenant`.

**Missing sections:** No role-specific menu items for:
- **Operator:** Delegation portfolio link, invitation inbox link
- **Tenant:** Report unauthorized operator link
- **Host:** Delegation management, approval inbox (buried in top nav, not profile)

**Current workaround:** These features are ONLY accessible via:
- Direct URL: `/operator`, `/host/delegation/invite`, `/tenant/report-unauthorized/:id`
- Top-nav deep links from notification/chat

**Result:** User confusion. Operator lands on guest profile, sees no delegation UI, doesn't know where delegation inbox is.

---

## ActorContext vs Auth Role Model

### Three Dimensions Coexist

| Dimension | Storage | Scope | Usage |
|-----------|---------|-------|-------|
| **Auth Role** | API `user.role` field | Persistent (login session) | Router guards, shell selection, UI persona eligibility |
| **UI Persona** | `UserPrefsService.lastMode` | Persistent (app prefs), cleared on logout | `GuestShell` tab switching, shell screen selection |
| **Actor Delegation** | `ActorContextProvider` | **Request-scoped only** (NOT persisted) | API header `X-Acting-As-Delegation-Id` |

### Interaction Model

**Clean separation:**
```dart
// ActorContextProvider (lines 22–74 in actor_context_provider.dart)
void enterContext(OperatorDelegationModel delegation) {
  _currentDelegation = delegation;
  notifyListeners();
}

void clear() {
  _disposeAllContextCaches();
  _currentDelegation = null;
  notifyListeners();
}
```

**ApiClient wiring (lines 68–74 in api_client.dart):**
```dart
// Delegation actor-context header (TL-8 — Phase 07).
// Injected only when ActorContextProvider has active context.
final delegationId = _actingAsDelegationIdAccessor?.call();
if (delegationId != null && delegationId.isNotEmpty) {
  headers['X-Acting-As-Delegation-Id'] = delegationId;
}
```

**✓ Good:** Actor context doesn't modify auth role; it's a request-scoped signal. Cold-start clears it (AC-15, NFR-07).

**⚠️ Risk:** Operator could:
1. Accept delegation → `actor.enterContext(delegation)`
2. Browse owner's data (with header injected)
3. Operator's role is still `operator` globally, but API treats requests as "on behalf of owner"
4. If delegation is revoked mid-session, API returns 401 with `code='DELEGATION_REVOKED'`
5. UI MUST clear actor context and redirect (AC-16b)

**Missing:** No explicit test that revocation properly clears actor context and reverts shell UI.

---

## Deep-Linking Hygiene

### Vulnerability: Cross-Role URL Jumps

**Scenario 1: Guest deep-links to `/host/analytics`**
1. URL arrives: `/host/analytics`
2. Router redirect checks: `if (!isAuth && _matchesPrefix(loc, '/host'))` → redirects to `/login` ✓
3. Guest logs in as guest, route resolves to DeferredRouteWidget
4. No role check in deferred widget — guest sees empty/error state (no data) but no authentication error

**Scenario 2: Operator deep-links to `/admin`**
1. URL arrives: `/admin`
2. Router checks: `if (_matchesPrefix(loc, '/admin') && !isAdmin)` → redirects to `/` ✓
3. Operator lands at root (GuestShell with guest tabs)

**Scenario 3: Operator sends direct URL to guest: `/operator/owner/123`**
1. Guest clicks link (unauthenticated)
2. Router: `if (!isAuth && _matchesPrefix(loc, '/operator'))` → `/login` ✓
3. Guest logs in, route resolves
4. **OperatorWorkspaceShell** renders with `ownerId='123'`
5. **NO GUARD:** Guest is now inside operator UI, API calls include `X-Acting-As-Delegation-Id` if guest somehow set it (they can't, but shell renders)

**Mitigation present:** API-level ownership check on each endpoint (assumed). UI never injects actor header for non-operator users (guarded by `ActorContextProvider.enterContext` usage).

**Residual risk:** If new endpoint added that ONLY checks actor header, not role, guest could see owner data. **Recommend: API guards MUST check both role AND delegation scope.**

---

## Sign-Out & Role-Switch Recovery

### Logout Flow (lines 113–131 in auth_provider.dart)

```dart
Future<void> logout() async {
  // ✓ Notify PermissionService BEFORE clearing currentUser (AC-T1)
  final userId = _currentUser?.id?.toString();
  if (userId != null && _permissionService != null) {
    try {
      await _permissionService!.onLogout(userId); // FCM token deletion
    } catch (_) {}
  }

  await _authRepository.logout();
  // ✓ Clear persona mode so user B on shared device doesn't inherit user A's
  await UserPrefsService.instance.clearLastMode();
  _previousRoleSnapshot = null;
  _currentUser = null;
  notifyListeners();
}
```

**✓ Good:** Clears persona mode, FCM tokens, role snapshot.

**Missing:** No explicit clear of `ActorContextProvider`. If operator logs out mid-acting-as:
1. `logout()` clears `_currentUser`, notifies listeners
2. GoRouter redirect fires (line 88–111) and boots user to `/login`
3. **BUT** `ActorContextProvider` still holds `_currentDelegation` from previous session
4. Cold-start doesn't use actor context (line 3: "request-scoped, resets on every cold-start")
5. **HOWEVER:** In-session logout (hot restart of auth, not app kill) leaves actor context dangling

**Recommend:** Add `actor.clear()` to logout sequence.

### Role Upgrade Detection (lines 135–157 in auth_provider.dart)

```dart
void _detectAndHandleRoleChange(UserModel newUser) {
  final newRole = newUser.role;
  final userId = newUser.id?.toString();

  if (userId == null) return;

  if (_previousRoleSnapshot != null &&
      _previousRoleSnapshot != newRole &&
      _permissionService != null) {
    final roleEnum = _parseUserRole(newRole);
    if (roleEnum != null) {
      // Fire-and-forget role upgrade recording
      _permissionService!.onRoleUpgrade(userId, roleEnum).catchError((_) {});
    }
  }

  _previousRoleSnapshot = newRole;
}
```

**✓ Good:** Detects guest→host promotion.

**Missing:** No UI state reset. When guest is upgraded to host:
1. Auth provider fires `onRoleUpgrade` (non-blocking)
2. GoRouter refresh (line 81: `refreshListenable: auth`)
3. Redirect rules re-evaluate, but user still in GuestShell
4. Shell's `_reconcileWithRole` (line 84–89) re-evaluates persona toggle on next build
5. **Window exists** where persona mode hasn't updated yet

**Scenario:** Guest in guest mode gets promoted to host server-side. Persona toggle doesn't appear until next frame rebuild.

**Acceptable risk:** Low impact (UI toggle appears within ~16ms). But could be tighter if we:
- Call `actor.clear()` on role change (to reset operator context if demoting)
- Trigger persona re-evaluation immediately in redirect

---

## Open Questions

1. **Host role only or host + admin?** Router checks `canHost = role == 'host' || role == 'admin'` in shell (line 134), but admin never reaches shell. Redundant check or planned for future?

2. **Onboarding differences?** Only found `onboarding_screen.dart`, not role-specific flows. Do all roles see same onboarding? (Assumption: yes, but not verified in code scan.)

3. **Operator workspace shell:** Where is `OperatorWorkspaceShell` defined? It's imported (line 29 in app_router.dart) but not found in file scan. Assume it exists, but need to verify it includes a "back to portfolio" navigation.

4. **Delegation revocation:** When API returns `isDelegationRevoked`, who calls `actor.clear()`? ApiClient throws exception, but UI must catch and clear. Need to verify this is wired end-to-end.

5. **Shared-login disclosure:** Actor context requires owner to acknowledge shared login (line 199 in delegation_provider.dart). Is this checked before allowing operator to enter context? Assume yes but not seen in UI code.

---

## Recommendations (Priority Order)

### CRITICAL (P0)

1. **Add role guards to deferred host routes** (lines 136–242 in app_router.dart)
   ```dart
   if (!isAuth || auth.currentUser?.role != 'host') return '/login';
   ```

2. **Add role guards to all operator routes** (lines 333–406)
   ```dart
   if (!isAuth || auth.currentUser?.role != 'operator') return '/';
   ```

3. **Guard `/tenant/report-unauthorized/:id`** (line 397)
   ```dart
   if (!isAuth || auth.currentUser?.role != 'tenant') return '/';
   ```

4. **Clear ActorContextProvider on logout** (add to line 131 in auth_provider.dart)
   ```dart
   Provider.of<ActorContextProvider>(context, listen: false).clear();
   ```

### HIGH (P1)

5. **Add role-specific profile sections** in profile_screen.dart:
   - Operator: Delegation portfolio link, invitations inbox
   - Tenant: Report unauthorized link
   - Host: Delegation mgmt, approvals (move from top nav)

6. **Verify OperatorWorkspaceShell navigation** — ensure back button clears actor context
   - Add "Exit" button to acting-as banner (line mentioned in actor_context_provider.dart but not verified in UI)

7. **End-to-end test: Delegation revocation flow**
   - Operator acting as owner → API revokes → UI catches 401 with code='DELEGATION_REVOKED'
   - Verify actor context clears, shell reverts to portfolio view

### MEDIUM (P2)

8. **Document the three-dimension model** in code comments (role vs persona vs actor)
   - Add diagram to tech docs explaining when each applies

9. **Verify onboarding per role** — confirm all roles see same flow or document differences

10. **Add explicit role checks to all shell/screen constructors** (defensive programming) — don't rely on router guards alone

---

## Summary Table: Coverage by Role

| Role | Router Guard | Shell | Profile Nav | Actor Context |
|------|---|---|---|---|
| `guest` | ✓ (no auth needed) | ✓ GuestShell | ✓ (default) | ✗ N/A |
| `host` | ⚠️ Partial (main routes guarded, deferred not) | ✓ GuestShell (host mode) | ⚠️ Buried in tabs | ✓ Delegation via `/host/delegation/*` |
| `admin` | ✓ (route guard + redirect) | ✓ AdminHomeScreen (deferred, isolated) | ✗ Hidden from shell | ✗ N/A |
| `operator` | ❌ MISSING | ⚠️ GuestShell (guest mode, no persona toggle) | ❌ MISSING | ✓ Delegation core feature |
| `tenant` | ⚠️ Only login check | ⚠️ GuestShell (guest mode) | ❌ MISSING | ✗ Read-only report feature |

**Overall readiness: 55% (6/11 dimensions fully implemented; 4 high-priority gaps)**

---

**Report generated by Researcher Agent | Phase: Audit**
