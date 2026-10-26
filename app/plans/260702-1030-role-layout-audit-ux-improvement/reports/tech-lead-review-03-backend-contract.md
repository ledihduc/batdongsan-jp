# Backend Contract Audit — Frontend Plan Dependencies

## Summary

The frontend plan claims to be "frontend-only" (plan.md line 59), but this audit reveals **three unverified backend assumptions** and **one potential schema collision** that require confirmation before Phase 01 implementation. The X-Acting-As-Delegation-Id header is well-implemented backend-side, JWT auto-upgrade on guest→host works correctly, and role-based 403 responses are properly structured. However, the plan's assumption about tenant JWT verification and the interaction between logout and delegation context needs explicit backend confirmation to avoid silent failures.

## Verified Backend Contracts

### A1: JWT Structure & Role Claims
- **Location:** Backend `app/auth.py:30–39`, Frontend `lib/providers/auth_provider.dart:56–77`
- **Contract:** JWT payload contains `{"sub": user_id, "role": "guest|host|admin", "iat", "exp"}`
- **Verification:** CONFIRMED
  - Backend signs with `role` claim only; no `delegations` or `is_operator` claim
  - Frontend auth_provider parses `role` → `UserRole` enum (3 variants: guest, host, admin)
  - Frontend does NOT read operator/tenant from JWT — only from DelegationProvider

### A2: X-Acting-As-Delegation-Id Header Flow
- **Location:** Backend `app/api/dependencies/actor.py:71–161`
- **Contract:** Header triggers operator context lookup; missing header = owner self-acting mode
- **Verification:** CONFIRMED
  - UUID4 validation at parse time (line 54)
  - Per-request DB lookup ensures revocation propagates immediately (line 107–120)
  - Error codes structured as `{"code": "...", "message": "..."}` for Flutter handler
  - Revocation returns 401 with code `DELEGATION_REVOKED` (line 131–138)
  - Out-of-office check present (line 163–191) — logged but not hard-blocked at header resolution

### A3: Guest→Host Auto-Upgrade on House Creation
- **Location:** Backend `app/routers/houses.py:89–161` (POST /api/houses)
- **Contract:** Backend auto-upgrades user role in DB and returns new JWT in response
- **Verification:** CONFIRMED
  - Line 144–149: Checks `role != "host"`, upgrades user.role, signs new token, returns in payload
  - Idempotent — safe to call multiple times
  - Frontend assumption (Phase 01 line 16) that "backend returns new JWT" is correct
  - However: **frontend must use the returned token immediately** — if user closes app after hitting POST but before receiving response, JWT state is stale

### A4: 403 Error Format
- **Location:** Backend `app/auth.py:77–84`, `app/api/dependencies/actor.py:299–305`
- **Contract:** 403 responses return JSON: `{"detail": {"code": "...", "message": "..."}}`
- **Verification:** CONFIRMED
  - `PERMISSION_DENIED` code used for permission failures (actor.py line 303)
  - Frontend can parse error.detail.code to distinguish "no permission" from "resource not found"

### A5: Delegation Provider Lifecycle
- **Location:** Backend `app/api/dependencies/actor.py:94–104` (owner-self-acting path), Frontend `lib/providers/delegation_provider.dart`
- **Contract:** `DelegationProvider.myDelegationsAsOperator` list drives operator permissions; mutation on `/api/delegations` endpoints
- **Verification:** CONFIRMED
  - Backend has accept/reject/pause/terminate endpoints (`app/routers/delegation.py`)
  - Frontend caches list via `fetchMyDelegationsAsOperator()` (delegation_provider.dart:46–58)
  - **RISK:** Cache not automatically invalidated on backend mutation — backend returns updated delegation model, but frontend must call `refresh()` manually (line 62–66) or re-fetch (line 46–58)

## Unverified Assumptions (need backend confirmation)

### U1: Logout Clears X-Acting-As-Delegation-Id Client-Side
- **Plan location:** Phase 02 line 14, Phase 02 line 31 (auth_provider.dart:113–131)
- **Frontend evidence:** `lib/providers/auth_provider.dart:113–131` has logout but does NOT explicitly call `ActorContextProvider.clear()`
- **Backend evidence:** No backend logout endpoint exists; backend is stateless (no server-side session to invalidate)
- **Risk if wrong:** If frontend logs out mid-operator-session but ActorContextProvider is not cleared, next app open might still have stale delegation header in memory (though request-scoped per app/api/dependencies/actor.py design means new session = fresh context)
- **Fix:** Phase 02 must explicitly add `actor.clear()` call in `auth_provider.dart:logout()` BEFORE returning to login (line 127 in current code). Add test case: logout mid-operator → verify `ActorContextProvider.currentDelegation == null` on next navigation.

### U2: Tenant JWT Verification (Phase 02 line 41)
- **Plan location:** Phase 02 line 41: "`/tenant/report-unauthorized/:id` — `isAuth && hasValidTenantJwt` (nếu tenant vẫn là contact role) — verify JWT claim từ backend`"
- **Frontend evidence:** Plan assumes frontend can parse a `tenant_jwt` claim from main JWT
- **Backend evidence:** NO TENANT JWT CLAIM FOUND in `app/auth.py:30–39`. Backend only includes `{"sub", "role", "iat", "exp"}`. No tenant-specific JWT payload documented.
- **Database schema evidence:** `User.role` is string(20), hardcoded to `"guest|host|admin|operator"` per models.py line 69. No `tenant` role value in backend.
- **Risk if wrong:** Plan Phase 02 guard will not compile if it tries to read non-existent JWT claim. Plan assumes tenant deep-link includes a short-lived JWT for access control, but backend may not be issuing tenant JWTs yet (Phase 09 scope, not included in current backend).
- **Fix:** BLOCKER — confirm with backend team: Is there a tenant JWT model implemented? If not, defer Phase 02 tenant route guard to Phase 09. If yes, provide JWT claim name and structure. Current plan should mark this as "deferred tenant verification" per Phase 03 decision.

### U3: Role Enum Collision (Phase 03 Option B)
- **Plan location:** Phase 03 line 20–26, Option B: "thêm `role='operator'` trong auth"
- **Backend evidence:** `User.role` is string(20), accepts any string. No enum constraint at DB level per models.py line 60.
- **Database schema:** Migration 0027 adds `is_operator_capable` flag (line 72) but does NOT add `role='operator'` to enum. Role is still `"guest|host|admin|operator"` as a comment (line 69) but not enforced.
- **Risk if wrong:** If Phase 03 chooses Option B, backend must add enum constraint and migration to existing `users.role` column. Current rows have values `"guest|host|admin"` only. Migration must NOT fail on existing data.
- **Estimated backend effort:** 
  - Add SQLAlchemy Enum constraint to `User.role` 
  - Create alembic migration: `alter table users modify column role enum('guest','host','admin','operator') not null default 'guest'`
  - Downtime: ~5 mins (brief lock on small tables in MVP)
  - Rollback: feasible (remove constraint, revert default)
- **Fix:** If Option B chosen, add task: "Backend PR: extend role enum to include 'operator', 'tenant' (if Phase 09 included). Estimate 0.5 day."

### U4: Admin Role Can Toggle Host Persona (Plan line 44, Phase 03 line 35)
- **Plan location:** Phase 03 decision point 3: "admin có được phép toggle host persona (rủi ro tự-duyệt) hay disable?"
- **Frontend evidence:** GuestShell (host mode) is persona toggle in UI, not role check. Admin CAN toggle to host mode because UI checks `role == 'admin'` for visibility, not `role != 'admin'` to prevent toggle.
- **Backend evidence:** No backend restriction found on admin approving own listings. Ownership check exists on list endpoints (houses.py:39–42 filters by `hostId`) but no "actor cannot approve own listing" validation on approval endpoints.
- **Risk if wrong:** Admin toggles persona to host, approves own listing without visibility of approval action being their own. Audit trail would show admin ID, but UX is confusing.
- **Fix:** Phase 01 should clarify in phase-04-role-specific-shells.md: if admin persona toggle is enabled, add snackbar warning "Bạn sẽ thấy các yêu cầu duyệt của chính mình dưới tên chủ nhà. Điều này chỉ dành cho kiểm tra thủ công — không phải duyệt tự động." OR disable toggle for admin entirely per product decision. Backend unchanged.

## Backend Changes Required (contrary to plan's "frontend-only" claim)

### B1: Phase 02 — Logout Must Call actor.clear() [FRONTEND ONLY]
- Not backend change; frontend responsibility in auth_provider.dart

### B2: Phase 03 Option B — Role Enum Extension [BACKEND ONLY]
- **Effort:** 0.5 day (alembic migration + enum constraint)
- **Scope:** Modify `app/models.py:60` User.role mapping, create migration
- **Risk:** None if done before Phase 04 implementation

### B3: Phase 09 (Future) — Tenant JWT Model [BACKEND ONLY]
- Out of current plan scope; blocks Phase 02 tenant route guard if not deferred

## Migration Risks (Option B)

If Phase 03 selects Option B (add `role='operator'` to auth):

1. **Schema migration:** Enum extension on `users.role` column
   - Current values: `"guest", "host", "admin"` only (no `"operator"` in production yet)
   - New enum: `"guest", "host", "admin", "operator", "tenant"` (if Phase 09 included)
   - **Downtime:** ~5 mins (brief table lock) — acceptable for MVP
   - **Rollback:** Feasible if migration is idempotent

2. **Frontend migration:** 
   - `lib/providers/auth_provider.dart:160–171` must add cases for `'operator'`, `'tenant'`
   - Route guards in Phase 02 simplify (check `role == 'operator'` instead of `hasActiveDelegation`)
   - **Effort:** 0.5 day (add cases, test)

3. **API backward compatibility:**
   - Existing tokens with `role="guest|host|admin"` remain valid
   - New tokens may include `role="operator"` — frontend must handle gracefully
   - No breaking change if frontend checks `role != 'admin'` (still catches `"operator"`)

## Deliverables for Plan Reviewers

1. **Confirm Phase 02 assumption U1:** Frontend MUST call `ActorContextProvider.clear()` in logout. Add test.
2. **Confirm Phase 02 assumption U2:** Ask backend team — is tenant JWT model implemented? If deferred, mark Phase 02 tenant guard as "deferred to Phase 09".
3. **Confirm Phase 03 decision:** Ask product — admin persona toggle: enable with warning or disable? (No backend change required either way.)
4. **If Option B chosen:** Add backend task to plan — role enum extension (0.5 day, no breaking changes).

---

**Report Date:** 2026-07-02  
**Audit Scope:** Full stack (backend models, routers, auth; frontend providers, router, shell)  
**Confidence:** HIGH for A1–A5; MEDIUM for U1–U4 (pending backend team clarification)
