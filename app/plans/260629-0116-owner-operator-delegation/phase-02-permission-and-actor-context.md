# Phase 02 — Permission Layer & Actor Context

## Context Links
- BA v4: §3 (Model A), §6.2 (context-switching ACs), §6.3 (permission preset ACs), §10.2 (auth/permission NFRs)
- ACs: AC-02, AC-04 (validation), AC-09, AC-15, AC-15b, AC-16, AC-16b, AC-17, AC-18, AC-19, AC-20, AC-21, AC-22, AC-23, AC-32, AC-39, AC-43, AC-43b (guard layer), AC-47, AC-48, AC-53, AC-56
- NFRs: NFR-02 (revocation ≤ 1 next-request), NFR-04 (per-request scope), NFR-05 (scope check low-latency), NFR-07 (no JWT delegation cache)
- Research: `researcher-01-backend-auth-kyc.md` §A, §E, §H (RBAC maturity 30%); `researcher-03-flutter-app.md` §A (Provider, request-scoped delegation)
- Dependent on phases: 01 (ORM models)
- Blocks: 03, 04, 05, 06, 07

## Overview
- **Priority:** P0
- **Status:** Pending
- **Effort:** 5 dev-days (1 senior BE + 0.5 FE for client interceptor)
- **Type:** backend + Flutter interceptor wiring
- **Description:** Build the request-scoped actor context layer. New FastAPI dependency that resolves `(actor_user, on_behalf_of_user, delegation, scope, permission_set)` per request from JWT + `X-Acting-As-Delegation-Id` header. New decorator `require_actor_with_permission(action, scope_kind)` replaces `require_host` on delegation-aware endpoints. Flutter interceptor injects the header on every API call.

## Key Insights from Research
- Current `require_host` / `require_admin` are flat role gates (researcher-01 §A). No property-level access control; `host_id` filter is implicit in every router.
- IDOR checks (`_ensure_owner_or_admin`, researcher-01 §A) are spot-applied — not universal. NEW pattern must be universal for delegation-aware endpoints.
- Admin still acts as super-host today — keep that, but add audit on `actor_user_id` so admin actions are distinguishable from operator-on-behalf actions.
- Per BA v4 NFR-07: JWT MUST NOT cache delegation state — propagation must be ≤ 1 next-request (AC-15b cross-tab safety + AC-16b mid-session revoke).
- Flutter side: `AuthProvider` holds current user only (researcher-03 §A). No "acting-as" context exists.

## Requirements (mapped to BA v4)

### Functional ACs covered
- **AC-15 / AC-15b** request-scoped, per-tab safe
- **AC-16 / AC-16b** mid-session revoke → next API call returns 401 with code `DELEGATION_REVOKED`
- **AC-17** owner sees no switcher; only operator-capable + active delegation enables it
- **AC-18** owner "Mình" mode read-only when active delegation exists; mutation requires explicit pause
- **AC-19/20/21** 4 preset role enforcement (matrix below)
- **AC-22** operator cannot CRUD delegations (other than accept/reject + self-resign)
- **AC-23** every mutation captures actor + on_behalf_of + delegation reference
- **AC-32, AC-39, AC-43, AC-43b** audit attribution (writes happen here, queries happen in phase-07)
- **AC-47, AC-48** non-regression for self-managed host (NULL actor context = legacy path unchanged)
- **AC-53** bank account masking middleware on response serialization
- **AC-56** self-owner-self-operator support (user can be both)

### NFRs
- **NFR-02 / NFR-07** revocation ≤ 1 next-request latency — achieved by per-request DB lookup (no caching).
- **NFR-04** per-request, not session-scoped
- **NFR-05** scope check low-latency — single indexed lookup `(delegations.id WHERE status='active')` + in-memory scope match on `scope_target_ids` array (avg ≤ 5 building IDs). Target p95 < 20ms.

### User Stories satisfied
- US-O15 ("Mình" mode read-only enforcement)
- US-O16 (in-flight on revocation — enforced by phase-03 / phase-04, but mid-session blocker is here)
- US-P7 (cross-tenant isolation)
- US-P8 (operator daily ops without approval — permission matrix decides)
- US-S1 (self-managed host unaffected)

## Architecture

### Actor context resolution flow

```
Request arrives (FastAPI)
   │
   ├─► extract JWT → claims {sub, role}                      (existing auth.py)
   │
   ├─► extract X-Acting-As-Delegation-Id header (UUID or absent)
   │
   ├─► resolve_actor_context() dependency:
   │      IF header absent:
   │          actor_ctx = ActorContext(
   │              actor_user_id=claims.sub,
   │              on_behalf_of_user_id=None,        # self-acting
   │              delegation=None,
   │              scope=None,
   │              permission_set=role_to_permissions(claims.role)
   │          )
   │      ELSE:
   │          delegation = db.query(Delegation).filter_by(id=header_uuid).first()
   │          IF delegation is None → raise 404 DELEGATION_NOT_FOUND
   │          IF delegation.operator_id != claims.sub → raise 403 NOT_YOUR_DELEGATION
   │          IF delegation.status != 'active' → raise 401 DELEGATION_REVOKED / DELEGATION_PAUSED
   │          IF delegation in out_of_office window AND request_is_action_creation → raise 423 OPERATOR_OUT_OF_OFFICE  (AC-57)
   │          actor_ctx = ActorContext(
   │              actor_user_id=claims.sub,
   │              on_behalf_of_user_id=delegation.owner_id,
   │              delegation=delegation,
   │              scope={'type': delegation.scope_type, 'target_ids': delegation.scope_target_ids},
   │              permission_set=preset_to_permissions(delegation.role_preset)
   │          )
   │
   ├─► request.state.actor_ctx = actor_ctx
   │
   └─► route handler runs, can use Depends(get_actor_context)
```

### `ActorContext` dataclass

```python
# app/auth/actor_context.py (NEW)
@dataclass(frozen=True)
class ActorContext:
    actor_user_id: int
    on_behalf_of_user_id: Optional[int]      # owner id when delegated; None when self
    delegation: Optional[Delegation]
    scope_type: Optional[str]                # 'all' | 'building_list' | None for self
    scope_target_building_ids: Optional[list[int]]
    permission_set: frozenset[str]           # e.g., {'contract.create', 'invoice.read', ...}
    actor_role: str                          # JWT role for legacy paths
    request_id: str                          # for log correlation

    @property
    def effective_owner_id(self) -> int:
        return self.on_behalf_of_user_id or self.actor_user_id

    @property
    def is_acting_on_behalf(self) -> bool:
        return self.on_behalf_of_user_id is not None

    def has_permission(self, action: str) -> bool:
        return action in self.permission_set

    def is_in_scope(self, building_id: int) -> bool:
        if not self.is_acting_on_behalf:
            return True  # self-acting, scope check by host_id filter
        if self.scope_type == 'all':
            return True
        return building_id in (self.scope_target_building_ids or [])
```

### Permission matrix (4 presets)

Each preset = frozenset of action strings. Stored in `app/auth/permission_matrix.py` (NEW).

| Action | `owner_view` | `operator_full` | `accountant` | `viewer` | Notes |
|--------|--------------|-----------------|--------------|----------|-------|
| `building.read` | ✓ | ✓ | ✓ | ✓ | |
| `building.create` / `.update` / `.delete` | ✗ | ✗ | ✗ | ✗ | Owner-only always (AC-19 exclusion) |
| `room.read` | ✓ | ✓ | ✓ | ✓ | |
| `room.create` / `.update` | ✗ | ✓ | ✗ | ✗ | |
| `room.delete` | ✗ | ✗ | ✗ | ✗ | Owner-only (AC-19 exclusion) |
| `tenant.read` | ✓ | ✓ | ✓ | ✓ | |
| `tenant.create` / `.update` | ✗ | ✓ | ✗ | ✗ | |
| `contract.read` | ✓ | ✓ | ✓ | ✓ | |
| `contract.create` | ✗ | ✓ | ✗ | ✗ | AC-24 may gate on threshold |
| `contract.update` | ✗ | ✓ | ✗ | ✗ | |
| `contract.terminate` | ✗ | ✓ | ✗ | ✗ | AC-27 always needs approval |
| `invoice.read` | ✓ | ✓ | ✓ | ✓ | |
| `invoice.create` | ✗ | ✓ | ✓ | ✗ | AC-25 amount threshold |
| `invoice.record_payment` | ✗ | ✓ | ✓ | ✗ | |
| `meter_reading.create` | ✗ | ✓ | ✓ | ✗ | |
| `service_fee.update` | ✗ | ✓ | ✗ | ✗ | |
| `refund.create` | ✗ | ✓ | ✓ | ✗ | AC-28 threshold |
| `khaibao.submit` | ✗ | ✓ | ✗ | ✗ | AC-55 fast-track |
| `host_profile.update_basic` | ✗ | ✓ | ✗ | ✗ | Excludes bank/CCCD/tax |
| `host_profile.update_bank` | ✗ | ✗ | ✗ | ✗ | Owner-only (AC-19) |
| `host_profile.update_cccd` | ✗ | ✗ | ✗ | ✗ | Owner-only |
| `host_profile.reveal_bank` | ✗ | ✓ | ✓ | ✗ | Triggers `bank_account_reveal_logs` write (AC-53) |
| `delegation.read_own` | ✓ | ✓ | ✓ | ✓ | Operator reads delegation row |
| `delegation.accept` / `.reject` | ✓ | ✓ | ✓ | ✓ | On invitation |
| `delegation.resign` | ✓ | ✓ | ✓ | ✓ | Self-rescind (US-P12) |
| `delegation.update_threshold` / `.update_scope` | ✗ | ✗ | ✗ | ✗ | Owner-only (AC-22) |
| `approval.read_own_inbox` | ✓ | ✓ | ✓ | ✓ | |
| `approval.decide` | ✗ | ✗ | ✗ | ✗ | Owner-only |
| `audit.read_own` | ✓ | ✓ | ✓ | ✓ | |
| `audit.export` | ✗ | ✗ | ✗ | ✗ | Owner-only (AC-40) |
| `marketplace.listing.update` | ✗ | ✓ | ✗ | ✗ | AC-51 payout destination immutable |

`owner_view`: ALL read permissions, NO mutation (mirrors what owner sees — read-only mode when delegation active per AC-18).

Owner self-acting (no delegation) gets full unrestricted access via legacy `require_host` path (researcher-01 §A) — NO change.

### Decorator: `require_actor_with_permission`

```python
# app/auth/decorators.py (NEW)
def require_actor_with_permission(
    action: str,
    *,
    scope_kind: Optional[str] = None,   # 'building' | 'contract' | 'invoice' | None
    scope_param: str = "building_id",   # path/query param to extract scope check target
):
    """FastAPI dependency factory."""
    async def _dep(
        request: Request,
        actor_ctx: ActorContext = Depends(resolve_actor_context),
        db: Session = Depends(get_db),
    ) -> ActorContext:
        # 1. AC-19/20/21 — permission check
        if not actor_ctx.has_permission(action):
            raise HTTPException(403, detail={'code': 'PERMISSION_DENIED', 'action': action})

        # 2. NFR-05 — scope check (if scope-bound endpoint)
        if scope_kind and actor_ctx.is_acting_on_behalf:
            target_id = _extract_scope_target(request, scope_param)  # path/query/body
            building_id = _resolve_to_building_id(db, scope_kind, target_id)
            if not actor_ctx.is_in_scope(building_id):
                raise HTTPException(403, detail={'code': 'OUT_OF_SCOPE'})

        # 3. AC-43 lockdown — if delegation in terminating phase + this action is BLOCKED tier
        if actor_ctx.delegation and actor_ctx.delegation.status == 'terminating':
            if _is_lockdown_blocked(action):
                raise HTTPException(403, detail={'code': 'LOCKDOWN_BLOCKED', 'action': action})
            # WITH-approval tier handled by phase-04 approval flow (not blocked here)

        # 4. AC-18 — owner can't mutate while active delegation exists (only on owner-self path)
        if not actor_ctx.is_acting_on_behalf and _is_mutation(action):
            active_delegation = db.query(Delegation).filter_by(
                owner_id=actor_ctx.actor_user_id,
                status='active'
            ).first()
            if active_delegation:
                raise HTTPException(409, detail={
                    'code': 'OWNER_MUTATION_WHILE_DELEGATED',
                    'hint': 'Pause delegation before mutating, or send instruction to operator.'
                })

        return actor_ctx
    return _dep
```

### Auto-audit hook

Replace existing `write_change_log()` calls (researcher-02 §D, `app/repositories/audit.py`) with a wrapper that auto-fills dual-identity from `actor_ctx`:

```python
# app/repositories/audit.py (MODIFY)
def write_change_log(
    db, *, entity_type, entity_id, action, before, after,
    actor_ctx: ActorContext = None,          # NEW required parameter (default None for migration)
    explicit_actor_id: Optional[int] = None  # for system jobs without actor_ctx
):
    actor_id = actor_ctx.actor_user_id if actor_ctx else explicit_actor_id
    on_behalf_of = actor_ctx.on_behalf_of_user_id if actor_ctx else None
    delegation_id = actor_ctx.delegation.id if actor_ctx and actor_ctx.delegation else None
    scope_snapshot = (
        {'type': actor_ctx.scope_type, 'target_ids': actor_ctx.scope_target_building_ids}
        if actor_ctx and actor_ctx.delegation else None
    )
    db.add(ChangeLog(
        entity_type=entity_type, entity_id=entity_id,
        actor_id=actor_id,
        on_behalf_of_user_id=on_behalf_of,
        acted_via_delegation_id=delegation_id,
        scope_snapshot_json=scope_snapshot,
        action=action,
        before_json=json.dumps(before),
        after_json=json.dumps(after),
        acted_at=None,  # server-stamp via default created_at
    ))
    db.flush()
```

Migration of existing `write_change_log` callers: add `actor_ctx` keyword. Existing self-host callers pass `actor_ctx=Depends(resolve_actor_context)` which yields `on_behalf_of=None` — backwards compatible (AC-48).

### Response masking middleware (AC-53)

```python
# app/middleware/bank_mask_middleware.py (NEW)
class BankAccountMaskMiddleware(BaseHTTPMiddleware):
    """Mask owner bank account in any response when actor is operator (not owner)."""
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        actor_ctx = getattr(request.state, 'actor_ctx', None)
        if actor_ctx and actor_ctx.is_acting_on_behalf:
            # Stream-mask response body for known sensitive keys
            response = _mask_response_body(response, keys=['bank_account_number'])
        return response
```

Mask format: `****1234` (last 4 chars only). Reveal endpoint (`POST /host/bank-account/reveal`) requires owner consent token → writes `bank_account_reveal_logs` → returns full number for one-time use (5min token TTL).

### Flutter side: `ActorContextProvider` + `ApiClient` interceptor

```dart
// lib/providers/actor_context_provider.dart (NEW)
class ActorContextProvider extends ChangeNotifier {
  String? _activeDelegationId;        // UUID; null = self mode
  String? get activeDelegationId => _activeDelegationId;

  bool get isActingAsOperator => _activeDelegationId != null;

  void enterDelegationContext(String delegationId) {
    _activeDelegationId = delegationId;
    notifyListeners();
  }

  void exitToSelf() {
    _activeDelegationId = null;
    notifyListeners();
  }

  // CRITICAL: NOT persisted to UserPrefsService.
  // Reset on app cold start to enforce per-tab/per-session safety (AC-15b).
}
```

`ApiClient` interceptor injects header on every request:
```dart
// lib/data/services/api_client.dart (MODIFY)
final actorCtx = read<ActorContextProvider>();
if (actorCtx.activeDelegationId != null) {
  headers['X-Acting-As-Delegation-Id'] = actorCtx.activeDelegationId!;
}
```

On any 401 response with code `DELEGATION_REVOKED` or `DELEGATION_PAUSED` (AC-16b): force-clear `ActorContextProvider`, force-navigate to `/operator` portfolio root, show snackbar with reason. Same for 409 `OWNER_MUTATION_WHILE_DELEGATED` (AC-18) → show dialog explaining + offering pause action.

### Permission preset documentation

New `docs/code-standards.md` section "Actor context + permission matrix" — single source of truth for the permission table above + decorator usage examples.

## Related Code Files

### To create
- `app/auth/actor_context.py` — `ActorContext` dataclass + `resolve_actor_context` dependency
- `app/auth/permission_matrix.py` — preset → permission_set frozen mapping; `preset_to_permissions()`, `_is_lockdown_blocked()`, `_is_mutation()` helpers
- `app/auth/decorators.py` — `require_actor_with_permission()` factory
- `app/middleware/bank_mask_middleware.py` — AC-53 response masking
- `lib/providers/actor_context_provider.dart` — Flutter provider
- `tests/auth/test_actor_context.py` — extensive permission matrix tests
- `tests/auth/test_decorators.py` — decorator tests (scope, lockdown, mutation block)

### To modify
- `app/auth.py` — keep `require_host` / `require_admin` (legacy paths); add `get_jwt_claims()` helper used by `resolve_actor_context`.
- `app/repositories/audit.py` — `write_change_log()` signature add `actor_ctx` parameter (default None for back-compat)
- `app/main.py` — register `BankAccountMaskMiddleware`
- `lib/data/services/api_client.dart` — inject `X-Acting-As-Delegation-Id` header from `ActorContextProvider`
- `lib/providers/auth_provider.dart` — on logout / role change, also reset `ActorContextProvider`
- `lib/main.dart` — register `ActorContextProvider` in `MultiProvider` (researcher-03 §A, L262–297)
- `lib/core/router/app_router.dart` — on `DELEGATION_REVOKED` 401 from any API call, navigate to `/operator` root

### To delete
- None.

## Implementation Steps

1. **Branch `feat/p02-actor-context`** off `feat/p01-data-model` (or main once 01 merged).
2. **Permission matrix:** write `app/auth/permission_matrix.py` with full 4-preset frozenset table. Write unit tests asserting every action in every preset (table-driven test for explicit coverage).
3. **`ActorContext` dataclass + `resolve_actor_context` dependency:** write `app/auth/actor_context.py`. Tests:
   - No header → self mode (on_behalf_of=None).
   - Valid header + active delegation → populated.
   - Header + paused delegation → 401 DELEGATION_PAUSED.
   - Header + terminated delegation → 401 DELEGATION_REVOKED.
   - Header + delegation owned by different operator → 403 NOT_YOUR_DELEGATION.
   - Invalid UUID → 400 INVALID_HEADER.
4. **Decorator `require_actor_with_permission`:** write `app/auth/decorators.py`. Tests cover:
   - Permission allowed → request proceeds.
   - Permission denied → 403 PERMISSION_DENIED.
   - Scope mismatch (building not in `scope_target_ids`) → 403 OUT_OF_SCOPE.
   - Lockdown blocked action during `terminating` → 403 LOCKDOWN_BLOCKED.
   - Owner self-mutate while delegation active → 409 OWNER_MUTATION_WHILE_DELEGATED.
5. **Audit hook:** modify `app/repositories/audit.py` `write_change_log()` to accept `actor_ctx`. Add tests asserting `change_logs.on_behalf_of_user_id` + `acted_via_delegation_id` populated when delegated.
6. **Bank mask middleware:** write + register in `app/main.py`. Tests: GET /host/profile while delegated returns masked; GET while self returns full.
7. **Endpoint conversion script:** Identify all `Depends(require_host)` call sites (grep). Categorize:
   - **A. Read endpoints (~30 endpoints):** add `Depends(resolve_actor_context)` alongside `require_host`. No permission decorator yet — phase 03/04/05 will wire `require_actor_with_permission` per endpoint based on permission matrix.
   - **B. Self-only endpoints (e.g., `PATCH /host/profile/bank`):** stay on `require_host` AND add `actor_ctx.is_acting_on_behalf == False` assertion at handler top.
   - **C. To be wired in phases 03/04/05:** mark with TODO comment; do NOT convert in phase-02.

   This phase ONLY ships the infra; per-endpoint conversion happens in 03/04/05.
8. **Flutter `ActorContextProvider`:** write `lib/providers/actor_context_provider.dart` + register in `main.dart`.
9. **Flutter `ApiClient` interceptor:** inject `X-Acting-As-Delegation-Id` header. Handle 401/409 response codes with global error mapper (auto-navigate + snackbar).
10. **Wire into auth_provider:** on logout, reset `ActorContextProvider`. On role change detection (auth_provider.dart L45), reset.
11. **Document** in `docs/code-standards.md` (new section "Actor context + permission matrix").
12. **Integration test:** end-to-end — login as operator with active delegation → call GET /buildings with header → returns owner's buildings, not operator's own.
13. **PR review + merge.**

## Todo List
- [ ] Branch off main (after 01 merged)
- [ ] Write `app/auth/permission_matrix.py` with 4-preset table
- [ ] Write `app/auth/actor_context.py` (`ActorContext` + `resolve_actor_context`)
- [ ] Write `app/auth/decorators.py` (`require_actor_with_permission`)
- [ ] Modify `app/repositories/audit.py` (`write_change_log` accepts `actor_ctx`)
- [ ] Write `app/middleware/bank_mask_middleware.py` (AC-53) + register in `main.py`
- [ ] Unit test permission matrix (table-driven, every preset × every action)
- [ ] Unit test `resolve_actor_context` (6 cases)
- [ ] Unit test `require_actor_with_permission` (5 cases incl. lockdown + mutation)
- [ ] Unit test bank mask middleware
- [ ] Integration test: operator with header sees owner's buildings, not own
- [ ] Audit existing routers, tag each `require_host` site with comment (A/B/C category)
- [ ] Flutter: create `lib/providers/actor_context_provider.dart`
- [ ] Flutter: register provider in `lib/main.dart`
- [ ] Flutter: modify `api_client.dart` to inject `X-Acting-As-Delegation-Id`
- [ ] Flutter: add global 401/409 handler (auto-navigate + snackbar)
- [ ] Flutter: reset `ActorContextProvider` on logout (auth_provider.dart)
- [ ] Document in `docs/code-standards.md` "Actor context + permission matrix"
- [ ] PR review + merge

## Success Criteria
- All permission matrix tests pass (~120 table entries × 4 presets = comprehensive).
- All 6 `resolve_actor_context` test cases pass.
- All 5 decorator test cases pass.
- Bank mask integration test passes (operator GET → masked; owner GET → full).
- Flutter interceptor unit test asserts header injected only when `activeDelegationId != null`.
- Flutter 401 handler unit test asserts navigation to `/operator` + snackbar.
- No regression on existing self-managed host flows (run full existing regression suite — AC-47, AC-48).
- `docs/code-standards.md` "Actor context + permission matrix" section published and PR-reviewed.

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Existing `require_host` callers break when we add `actor_ctx` to `write_change_log` | High | High | Default `actor_ctx=None` parameter; explicit migration in phases 03/04/05 with per-route review. |
| Bank mask middleware corrupts non-JSON responses (e.g., PDFs, XLSX) | Med | Med | Type-check `response.headers['content-type']` — only mask `application/json`. |
| Flutter `ActorContextProvider` accidentally persisted to UserPrefs by a dev | Med | High (NFR-04 violation) | Lint rule: forbid `userPrefs.set...` calls inside `actor_context_provider.dart`. Add code comment in capital letters. |
| Permission matrix grows unmaintainable as actions accumulate | Med | Med | Single source-of-truth in `permission_matrix.py` — table-driven test enforces every new action declared in every preset. CI fails if missing. |
| `_resolve_to_building_id()` adds N+1 queries on scope check | Med | High (NFR-05 latency) | Resolution cache per-request (request.state.scope_resolver_cache). Single SQL per unique scope_kind/target_id. |
| Owner-mutation-while-delegated block (AC-18) trips legit owner self-operations (e.g., reading own profile) | Med | High (US-O15 UX) | `_is_mutation(action)` whitelist ONLY actions that are state-changing on entities the operator can also touch. Reads always pass. Bank-update (`host_profile.update_bank`) does NOT trip — owner only. |
| Race: delegation paused while request in flight | Low | Med | `resolve_actor_context` is the gate; each request re-reads. Worst case = 1 stale request slips through, then next call 401. Acceptable per NFR-02. |

## Security Considerations

- **JWT remains user-identity only.** Delegation state NEVER cached in token (NFR-07). Per-request DB lookup is the cost we accept for revocation safety.
- **Header transport:** `X-Acting-As-Delegation-Id` is UUID — non-guessable. Backend always validates `delegation.operator_id == claims.sub` before honoring. Spoofing impossible without operator's own JWT.
- **Permission frozen set:** prevents accidental mutation in handler code (e.g., `permission_set.add('contract.create')` raises AttributeError).
- **IDOR universal:** the new decorator + scope check replaces ad-hoc `_ensure_owner_or_admin` for delegation-aware endpoints. Phase 03/04/05 migrations enforce.
- **Audit dual-identity:** every mutation through `write_change_log()` now records both actor + on_behalf_of, satisfying AC-23 / AC-32 / AC-39 court-evidence requirement.
- **Bank account reveal:** AC-53 satisfied — masking is response-layer (defense-in-depth); explicit reveal is single-use with audit row + consent token.
- **AgentShield (per security-review-rules.md):** all permission checks use parameterized DB calls; no string interpolation. Logging strips header values from access logs (no PII leak).

## Estimated Effort

**5 dev-days** = 1 BE × 5d. Covers actor context dependency, 4 preset permission matrix, scope resolver with per-request cache, dual-identity audit hook in `change_logs`, AC-43 3-tier lockdown guard, bank account masking middleware (AC-53), and full unit + integration test coverage for matrix.

## Next Steps / Dependencies

- **Blocks:** Phase 03 (delegation CRUD uses decorator + audit), Phase 04 (approval state machine uses lockdown check), Phase 05 (KYC endpoints use `require_actor_with_permission`), Phase 06 (owner-death pause uses actor_ctx), Phase 07 (Flutter uses `ActorContextProvider`).
- **Parallel-safe with:** Phase 08 (notifications), Phase 09 (commission schema).

## Open items flagged
- AC-58d executor exception — phase-02 leaves a hook (`_is_lockdown_blocked` can flag executor case). Actual executor-acts-for-owner permission grant deferred to phase-06.
- Q3.2 marketplace booking routing under delegation — permission `marketplace.listing.update` granted to `operator_full` per AC-51; payout destination immutability is phase-09 service-layer concern (NOT permission layer).
