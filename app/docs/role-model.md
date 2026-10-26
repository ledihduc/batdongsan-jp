# Role Model — 3-Dimension Architecture

**Locked:** 2026-07-02 (Phase 03 v3)
**Option chosen:** A (delegation scope, no backend enum change)

---

## Three orthogonal dimensions

The app tracks role identity along three axes. They are independent — a user has one value on each axis at all times.

| Dimension | Where it lives | Values | Changes when |
|-----------|---------------|--------|-------------|
| **Auth role** | JWT claim `role` + `AuthProvider.currentUser.role` | `guest` \| `host` \| `admin` | Login, register, auto-upgrade (guest→host on first listing) |
| **UI persona** | `GuestShell._mode` + `UserPrefsService.lastActiveMode` | `kModeGuest` \| `kModeHost` | User toggles inside profile screen |
| **Actor context** | `ActorContextProvider.currentDelegation` + request header | Owner-scoped delegation ID or none | Operator enters/exits owner scope |

## Displayed role — the fourth (derived) axis

`DisplayedRole` is a derived enum computed from the three axes above (plus tenant JWT once backend ships U2). It exists so UI code can ask a single question — "what should I show this user?" — instead of correlating three providers.

**Enum:** `lib/core/models/displayed_role.dart`

```
DisplayedRole { guest, host, admin, operator_, tenant }
```

**Priority when multiple axes qualify:**

```
admin > operator (if hasActiveDelegation) > host > guest
tenant — separate axis via tenant JWT claim (U2, deferred)
```

---

## Derivation matrix

| auth.role | delegation.hasActive | tenant JWT | → DisplayedRole |
|-----------|---------------------|------------|-----------------|
| `admin`   | any                 | any        | `admin`         |
| `host`    | true                | any        | `operator_`     |
| `host`    | false               | any        | `host`          |
| `guest`   | true                | any        | `operator_`     |
| `guest`   | false               | valid      | `tenant`        |
| `guest`   | false               | none       | `guest`         |
| null      | any                 | any        | `guest`         |

**Notes:**
- `tenant` requires backend U2 (tenant JWT endpoint). Until U2 ships, `DisplayedRole.tenant` is never produced — tenants sees the guest experience.
- A user with `role=admin` never appears as `operator_` even with active delegations — admin persona takes priority for consistency.
- A `host` with active delegations *becomes* an operator in UI while retaining host powers (matches product intent: "chủ nhà đang quản lý dùm chủ khác").

---

## Access matrix — displayed role × app surface

| Displayed role | Guest shell | Host shell | Operator shell | Admin shell | Tenant shell | Profile section |
|----------------|-------------|-----------|----------------|-------------|--------------|-----------------|
| `guest`        | default     | ❌ redirect `/` | ❌ redirect `/` | ❌ redirect `/` | ❌ redirect `/` | Basic + wishlist |
| `host`         | via persona toggle | default | ❌ redirect `/` | ❌ redirect `/` | ❌ redirect `/` | Basic + host suite |
| `admin`        | via persona toggle | via persona toggle | ❌ redirect `/` | default | ❌ redirect `/` | Basic + admin console |
| `operator_`    | via persona toggle | via persona toggle | default | ❌ redirect `/` | ❌ redirect `/` | Basic + operator portfolio |
| `tenant` (U2)  | ❌ redirect `/tenant` | ❌ redirect `/tenant` | ❌ redirect `/tenant` | ❌ redirect `/tenant` | default | Contract + invoices |

Persona toggle appears only when the user has `>1` displayed role available (per Q10 lock).

---

## Locked decisions (2026-07-02)

- **Q1 — Operator model:** Option A. Backend `User.role` stays `guest|host|admin`. Operator is derived from delegation state, not a persistent role.
- **Q2 — Tenant model:** Email deep-link + backend-issued tenant JWT (backend U2). Frontend renders `DisplayedRole.tenant` when the JWT is present. Tenant onboarding via email link only, no self-registration.
- **Q3 — Admin persona toggle:** Disabled. Admin cannot toggle into host persona to avoid self-approval. Impersonation for QA is a separate, later feature.
- **Q10 — Multi-role user:** Assumed YES. Role switcher inside Profile section is shown conditionally when >1 displayed role is available.

---

## Guard functions

Router guard implementations use `DisplayedRole` (Phase 02):

```dart
String? guardHostRoutes(String loc, DisplayedRole role) =>
    loc.startsWith('/host') && !role.canAccessHost ? '/' : null;

String? guardOperatorRoutes(String loc, DisplayedRole role) =>
    loc.startsWith('/operator') && !role.canAccessOperator ? '/' : null;

String? guardTenantRoutes(String loc, DisplayedRole role) =>
    loc.startsWith('/tenant') && !role.canAccessTenant ? '/' : null;

String? guardAdminRoutes(String loc, DisplayedRole role) =>
    loc.startsWith('/admin') && !role.canAccessAdmin ? '/' : null;
```

Backend must re-verify — router guard is a UX barrier, not a security boundary.

---

## Non-goals

- Not adding `operator` / `tenant` to backend `User.role` enum (Option B rejected)
- Not building server-side impersonation mode (Q3)
- Not building tenant self-registration (Q2 — deep-link only)
- Not building general role switcher UI here — that lives in Phase 04 Profile screen work
