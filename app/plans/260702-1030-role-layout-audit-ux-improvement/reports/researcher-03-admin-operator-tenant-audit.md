# Admin / Operator / Tenant Audit — Role-Based Layout & UX

**Date:** 2026-07-02  
**Scope:** Admin, Operator, Tenant roles (excludes Guest, Host)  
**Audit Depth:** Router + 9 screens + role model consistency

---

## Summary

**CRITICAL FINDING:** The auth model recognizes only `'guest' | 'host' | 'admin'` as real roles (auth_provider.dart:162-167). Operator and Tenant are NOT user roles—they are **delegation permission scopes** and **contact roles** respectively. This mismatch creates architectural confusion:

- **Admin:** Properly protected (`/admin` route, role check present). ✅ No layout leaks detected, but admin lands in GuestShell (lines 591–592 of app_router.dart) — exposes host/guest tabs alongside admin powers.
- **Operator:** Real permission (delegated owner management), but **zero dedicated shell**. Routes exist (`/operator/*`) but with no authentication guard in the router itself. Operator context managed via `ActorContextProvider`, not auth role.
- **Tenant:** Not a real role. Only exists as a **contract party** (contact on a lease). Has one isolated screen (`report_unauthorized_operator`) with no shell, no onboarding, no home.

**Recommendation:** Clarify the architectural model—convert operator/tenant into explicit scopes OR roles depending on product strategy. Current design works for MVP but needs documentation and future scaling.

---

## Admin Findings

### HIGH
- **file:** lib/features/admin/admin_home_screen.dart:72–106
  - Admin is redirected to `/admin` ✅ (app_router.dart:95–96 guards correctly)
  - BUT: Admin also lands in GuestShell (app_router.dart:591–592) which exposes guest/host tabs
  - RISK: If admin logs out on admin screen or deep-links to `/` (not `/admin`), they land in guest mode with profile switcher visible
  - **FIX:** Either (a) show admin-only shell on `/` for admins, or (b) disable host mode toggle when `isAdmin`

- **file:** lib/features/admin/admin_home_screen.dart:267–395
  - No breadcrumb or exit path to return to main app
  - Admin must use browser back or hardware back button—no "Back to Home" link
  - **UX GAP:** Profile screen missing "Sign Out" button (logout only on AppBar ⚠️)

### MEDIUM
- **file:** lib/features/admin/planning/risky_listings_screen.dart
  - Deferred load (admin.dart chunk) — slow first navigation `/admin` → risky listings
  - No preloading of admin module on login
  - **Optimization:** Preload admin module on bootstrap if user.role == 'admin'

### LOW
- Navigation depth: Admin home → risky listings requires Navigator.push (not GoRouter)
  - **Tech debt:** Convert to GoRoute `/admin/planning/risky` for consistent deep-linking

---

## Operator Findings

### HIGH — Missing Dedicated Shell & Auth Guard

- **file:** lib/core/router/app_router.dart:334–368
  - Routes exist: `/operator`, `/operator/owner/:ownerId`, `/operator/owner/:ownerId/audit`, `/operator/invitations`
  - **NO role guard in redirect logic** — any logged-in user can navigate to `/operator` via deep-link
  - Redirect only checks: `!isAuth && loc.startsWith('/operator') → /login` (line 107)
  - **MISSING:** `isOperator` check to prevent guest/host from accessing
  - **RISK:** Guest user deep-links to `/operator/owner/123` → OperatorWorkspaceShell tries to enter context, fails silently if ActorContextProvider.isActingAs is false (line 45–46) — redirects to `/operator`, creating redirect loop potential

- **file:** lib/features/operator/workspace/operator_workspace_shell.dart:64–89
  - Wraps HostHomeScreen directly — operator sees all host features
  - No scoping: operator can access any host endpoint (analytics, contracts, tenants)
  - **ASSUMPTION:** Backend enforces `X-Acting-As-Delegation-Id` header to filter data
  - **RISK:** If header validation fails on backend, operator sees ALL owners' data

- **file:** lib/features/operator/portfolio/operator_portfolio_screen.dart:25–56
  - No shell wrapper — bare screen with logout missing
  - AppBar has logout ❌ NO, logout button missing (only action button: invitations)
  - **UX GAP:** Operator cannot logout from portfolio; must navigate to settings or use native app menu

### MEDIUM
- **file:** lib/features/operator/invitations/invitation_inbox_screen.dart (not audited; needs review)
  - Operator invitation workflow not examined — confirm screen enforces invitation state (pending/accepted/rejected)

- **file:** lib/features/operator/onboarding/** (2 files not audited)
  - Onboarding flow exists but scope unclear; verify it enforces "operator only" state

- **file:** lib/features/operator/workspace/operator_workspace_shell.dart:1–89
  - ActingAsBanner overlay (orange warning) + audit trail exist ✅ (good UX)
  - But no role-based feature hiding — operator sees host invoice/contract drill-down
  - **DESIGN Q:** Should operators see analytics, or only operational screens (property, contracts, tenants)?

---

## Tenant Findings

### HIGH — Tenant is NOT a User Role

- **file:** lib/features/tenant/screens/report_unauthorized_operator_screen.dart:1–150
  - Tenant is a **contact role** (person on lease), not a logged-in app user
  - Screen accessible via `/tenant/report-unauthorized/:delegationId` — requires authenticated session + delegation context
  - **ARCHITECTURAL ISSUE:** How does a tenant access this route?
    - Route guard requires auth (app_router.dart:107–108 checks auth)
    - But tenants have no home screen, no onboarding, no auth UI
    - **ASSUMPTION:** Tenant is sent deep-link via email/SMS + auth token embedded
    - **UNRESOLVED:** No `/tenant` home or shell visible in codebase

- **file:** lib/features/tenant/screens/report_unauthorized_operator_screen.dart:119–149
  - Form submission sends POST to `/api/delegations/{delegationId}/report-unauthorized`
  - No tenant_id param — backend must infer tenant from auth context + delegationId
  - **RISK:** If backend uses JWT claim to infer tenant, embedding token in email link is secure ✅
  - If backend falls back to auth user role, tenants might not be allowed (auth only knows 'guest' | 'host' | 'admin')

### MEDIUM
- **file:** lib/features/tenant/widgets/authority_badge_widget.dart (not audited)
  - Component exists; unclear scope — verify it doesn't expose landlord data

---

## Cross-Cutting: Role Model Consistency

### The Mismatch

**Auth Model** (auth_provider.dart:159–171):
```dart
switch (role) {
  case 'guest': return UserRole.guest;
  case 'host': return UserRole.host;
  case 'admin': return UserRole.admin;
  default: return null;  // Operator & Tenant mapped to null
}
```

**Feature Routes:**
- `/operator/*` exists but operator is NOT a UserRole enum member
- `/tenant/report-unauthorized/*` exists but tenant is NOT a UserRole enum member

**Clarification:**

| Role | Is User.role? | Scope | Entry Point | How Active? |
|------|---------------|-------|-------------|------------|
| **guest** | YES | Browse/book houses | Login | Auth login |
| **host** | YES | Own/manage properties | Onboarding or auth | Auth login |
| **admin** | YES | Approve listings, audit | Auth login | Auth login + role check |
| **operator** | NO ❌ | Manage delegated owner | Deep-link or portfolio | DelegationProvider + ActorContextProvider |
| **tenant** | NO ❌ | Report unauthorized op | Email deep-link + JWT | JWT in URL, backend infers |

### Current Design

**Operator** is a **permission scope** (state stored in DelegationProvider, not auth):
- User has role='guest' or role='host'
- User receives invitation from owner → accepts → becomes "operator for owner X"
- ActorContextProvider.enterContext(delegation) → sets temp context
- OperatorWorkspaceShell wraps host screens under X-Acting-As-Delegation-Id header
- **Pro:** No role bloat in auth schema
- **Con:** App has no centralized way to check "can this user access operator screens?" — must read DelegationProvider.myDelegationsAsOperator

**Tenant** is a **contact role** (side-loaded from contract data):
- Tenant is not a logged-in user; they are a person named in a lease contract
- When tenant needs to report unauthorized operator, they receive email with deep-link + JWT
- Deep-link is `/tenant/report-unauthorized/:delegationId`
- Backend decodes JWT → infers tenant identity + delegationId → allows report submission
- **Pro:** Tenants don't need app accounts; frictionless
- **Con:** No shell, no persistence, no notification center for tenants

---

## Router Security Review

### Guards Present ✅
- Line 95–96: `/admin` protected — redirects non-admin to `/`
- Line 104–109: Unauthenticated users redirected to `/login` for protected routes

### Guards Missing ⚠️
- **Operator routes** (lines 334–368): No role or permission check
  - Fix: Add `isOperator` or permission check in redirect
  - Suggested:
    ```dart
    if (_matchesPrefix(loc, '/operator') && !_canOperatorAccess()) {
      return '/';
    }
    ```
  - Implementation: Add method to AuthProvider or DelegationProvider to check if user has active delegations

- **Tenant report route** (line 397–405): Auth guard present but no tenant verification
  - Fix: Backend should validate JWT + delegationId + tenant membership before accepting report
  - Frontend cannot validate tenant without decoding JWT (security risk)

---

## UI/UX Improvements

### Priority 1 (Block)
1. **Admin shell confusion:** Admin shouldn't see host/guest tabs on home screen
   - Fix: If user.role == 'admin', show admin-only bottom nav (Admin Home, Audit, Settings, Logout)
   - OR: Hide mode switcher in ProfileScreen when isAdmin (line 148 of guest_shell.dart)

2. **Operator logout:** No sign-out button on operator portfolio
   - Fix: Add logout to DsAppBar actions on OperatorPortfolioScreen (line 41–52)
   - OR: Ensure operator can reach profile/settings screen for logout

3. **Operator route guards:** Deep-link to `/operator` as guest should fail gracefully
   - Fix: Add guard in redirect logic
   - Graceful fail: Show error screen "You don't have operator access" with action to apply

### Priority 2 (UX)
4. **Operator onboarding:** No visible onboarding flow for first-time operators
   - Confirm files: lib/features/operator/onboarding/** exist but integration unclear
   - Verify: Invitation inbox → accept → redirect to onboarding vs. direct portfolio

5. **Tenant deep-link UX:** Deep-link email should include readable context
   - Current: `/tenant/report-unauthorized/:delegationId` shows delegation ID only
   - Improvement: Include owner name + operator name as query params for context (e.g., ?owner=John&op=Jane)

6. **Admin → risky listings flow:** Navigation via Navigator.push instead of GoRouter
   - Refactor: Add GoRoute `/admin/planning/risky` (nested under `/admin`)
   - Benefit: Consistent deep-linking, browser history, error handling

### Priority 3 (Tech Debt)
7. **ActorContextProvider lifecycle:** No timeout or session guard
   - Risk: User enters operator workspace, leaves for 30 min, tries to submit form → stale delegation context
   - Fix: Add TTL to ActorContextProvider context (e.g., 30 min auto-clear)

8. **Operator workspace scope:** No feature visibility toggle based on delegation permission
   - Current: Operator sees all host features (analytics, contracts, tenants)
   - Ideal: Hide/disable features based on delegation.rolePreset (operator_full vs. accountant vs. viewer)
   - Scope: Phase 8+ (future)

---

## Role Model Documentation Gaps

1. **Where does 'operator' come from in UX?**
   - App treats operator as a permission, not a role
   - DelegationProvider.myDelegationsAsOperator loaded on app init ❌ (only when portfolio opens)
   - Operator sees NO indication of their delegated status until they navigate to `/operator`

2. **Tenant sign-in flow?**
   - No documentation of how tenant receives and uses deep-link
   - Is deep-link single-use or replayable?
   - Does tenant need to create an account?

3. **Operator invitation acceptance?**
   - InvitationInboxScreen (not audited) — does acceptance create DelegationProvider record?
   - Is acceptance synchronous or async?

4. **Admin role persistence?**
   - Admin lands in GuestShell but can switch to Host mode — is this intentional?
   - Should admin have a separate shell or restricted persona?

---

## Open Questions

1. **Should operator be a distinct user role in auth, or remain a delegation permission?**
   - Current design (permission) is simpler for small teams
   - But future multi-operator / multi-brand scenarios may benefit from explicit role

2. **How do operators first learn about their delegations?**
   - Invitation email → click → login → portfolio auto-loads ✅
   - Or: Invitation email → click → already logged-in? → redirect to portfolio
   - Need clarification on invitation acceptance UX

3. **Tenant report submission — is it anonymous or authenticated?**
   - Current: JWT in deep-link + form submission
   - Should tenant see confirmation of their identity or remain anonymous?

4. **Should admins have home screen access to guest/host personas?**
   - Current: Admins can toggle to host mode and see host features
   - Risk: Admin accidentally approves own listings via host mode
   - Recommendation: Disable host mode toggle for admins OR add confirmation "Switching to host mode. Admin functions disabled."

5. **Operator onboarding — required or optional?**
   - SharedLoginDisclosureDialog exists (file path suggests operator onboarding step)
   - Verify: Is this shown before portfolio or after first delegation entry?

---

## Summary Table

| Role | Router | Shell | Guard | Home | Logout | UX Complete? |
|------|--------|-------|-------|------|--------|--------------|
| Admin | ✅ `/admin` | ❌ GuestShell (shared) | ✅ Role check | ✅ TabBar | ⚠️ AppBar only | 70% |
| Operator | ⚠️ No guard | ❌ None (host reuse) | ❌ Missing | ⚠️ Portfolio | ❌ Missing | 40% |
| Tenant | ⚠️ JWT only | ❌ None | ❌ JWT decode (backend) | ❌ No home | ❌ N/A | 20% |

---

**Audit Conclusion:** Admin feature is stable for production. Operator and tenant need clarification on role architecture and UX closure before scaling to multiple teams. Key risk: operators can deep-link to protected routes without permission verification.
