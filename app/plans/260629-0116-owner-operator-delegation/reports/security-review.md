# Security Review — Owner-Operator Delegation (Phase 02)

**Date:** 2026-06-30
**Reviewer:** security-reviewer (Opus 4.7)
**Scope:** 5 files (actor_context, actor dep, audit repo, permission_set, scope_check) + 3 targeted greps
**Verdict:** **APPROVED** (with 1 MEDIUM observation)

---

## CRITICAL
None.

## HIGH
None.

## MEDIUM

- **`app/api/dependencies/actor.py:107-111`** — Information disclosure via probing.
  - The delegation lookup `db.query(Delegation).filter(Delegation.id == delegation_header).first()` returns 404 `DELEGATION_NOT_FOUND` when the UUID does not exist, but 403 `NOT_YOUR_DELEGATION` when it exists but belongs to someone else. This lets an attacker who guesses/leaks a delegation UUID confirm its existence.
  - Severity: low practical risk (UUID4 is unguessable) but enables enumeration if any UUID ever leaks via logs/URLs.
  - Fix: return identical 404 for both "not found" and "not yours" cases (collapse to `DELEGATION_NOT_FOUND`). Keep server-side log distinguishing them for audit.

- **`app/repositories/audit.py:101`** — `datetime.utcnow()` is timezone-naive.
  - `created_at=datetime.utcnow()` produces a naive datetime; rest of codebase (`actor.py:175`) uses `datetime.now(timezone.utc)`. Prefer `datetime.now(timezone.utc)` for consistency and to avoid silent tz bugs on display.
  - Not a security issue per se but audit trails should always be tz-aware.

## LOW

- **`app/api/dependencies/actor.py:230`** — duplicated resolver logic in `get_optional_actor_context` mirrors `resolve_actor_context`. Drift risk: if main resolver gains a new revocation check (e.g., new status), optional path won't get it. Refactor to share a single `_resolve_inner()` helper.

- **`app/services/actor_context.py:149`** — `building_ids = [int(x) for x in raw_scope_ids]` will raise on non-int items and propagate as 500. Wrap in try/except → log + treat as empty list (fail-closed) so a corrupt JSON column never leaks to client as stack trace.

---

## Pass List (verified OK)

1. **SQL injection** — All `text()` calls in services use bound params (`:name`); no f-string concat observed in services/routes. SQLAlchemy ORM `.filter(Delegation.id == ...)` in `actor.py` uses parameterized binding. **PASS**
2. **Hardcoded secrets** — All API keys (FASTCA, VINACA, ESMS) sourced via `os.getenv()` / `getattr(settings, ...)`. No literal `sk_test_…` or hardcoded credentials in `app/`. **PASS**
3. **Path traversal (owner_death cert uploads)** — No `os.path.join` / `open()` calls in `app/services/owner_death/`. Module operates DB-only; no filesystem surface. **PASS** for this phase.
4. **Authentication enforcement** — `resolve_actor_context` requires `require_user` JWT dep; cannot be bypassed by omitting the delegation header (falls to owner self-acting which still requires JWT).
5. **Authorization / IDOR** — `actor.py:122` enforces `delegation.operator_id == actor_user_id` before granting operator context. Prevents one operator from claiming another's delegation.
6. **Permission tampering** — `permission_set` is `frozenset` (immutable); preset map is module-level `Final`. Handlers cannot mutate at runtime. `preset_to_permissions()` raises on unknown preset → fail-fast.
7. **Scope bypass** — `scope_check.py` resolves to canonical `building_id` via single indexed join (no string interpolation); `is_in_scope()` defaults to empty list `[]` on malformed scope → fail-closed.
8. **Revocation propagation (NFR-02)** — Per-request DB lookup; no JWT caching of delegation state. Status checks for `terminated`/`archived`/`paused` enforced on every request.
9. **Lockdown (AC-43)** — `is_lockdown_blocked()` reads from immutable frozenset; enforced before delegating action in `require_actor_with_permission`.
10. **Owner-self-mutate block (AC-18)** — `actor.py:352-372` correctly checks `active` delegation existence before allowing owner mutation, returning 409 with hint.
11. **Audit trail (dual-identity)** — `audit.py` writes both `actor_id` and `on_behalf_of_user_id` + `acted_via_delegation_id` + `scope_snapshot_json`. Forensically sound.
12. **No sensitive logging** — No `console.log` / `print()` of tokens, delegation IDs, or actor claims in reviewed code.
13. **Out-of-office (AC-57)** — 423 Locked returned with tz-aware comparison; both sides of window coerced to UTC.
14. **Input validation** — Delegation header validated as UUID4 before DB query (`_parse_delegation_header`); scope param coerced to int with typed error code.

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 0 |
| HIGH     | 0 |
| MEDIUM   | 2 |
| LOW      | 2 |

**Verdict: APPROVED**

The Phase 02 actor-context / permission / scope subsystem is well-designed defensively: immutable permission sets, per-request revocation checks, parameterized queries, fail-closed scope handling, dual-identity audit, and UUID4-validated headers. No blocking issues. Two MEDIUM observations (404/403 enumeration nuance + naive datetime in audit) should be tracked but do not block merge.

## Unresolved questions
1. Does the upstream `request.state.request_id` (referenced in `actor.py:92`) get set by an actual tracing middleware? If absent on every request, the UUID fallback works but log correlation across services may be missing.
2. Are operator JWTs short-lived enough that a revoked delegation cannot be exploited across the JWT TTL window via cached middleware results? (No caching observed here; confirm at middleware layer.)
