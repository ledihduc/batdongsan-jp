# Tech Lead Code Review — Owner-Operator Delegation v1

**Date:** 2026-06-30
**Reviewer:** Tech Lead (synthesized from 3 focused sub-reviews + inline verification)
**Scope:** Phases 01–10 production code (phase-11 testing artifacts reviewed separately)

## Final Verdict: **APPROVED** (post-remediation)

Initial review was CONDITIONAL with 2 production blockers + 1 HIGH bug + 1 HIGH CI gap. **All 4 closed in remediation round.** Coverage 62/66 ACs + 13/15 NFRs + 9/9 TL decisions met. Two pre-existing Phase-11 test scaffold issues remain (do NOT block ship — production code unaffected).

### Remediation Round (post-review fixes)

| Issue | Fix | Verification |
|---|---|---|
| B1 — AC-54 PDF | `contract_pdf_service.py` (187 LOC) + Jinja2 template + 24 unit tests; weasyprint import deferred so app boots without system libs | 24/24 pass |
| B2 — AC-51 marketplace | Router uses `actor_ctx.effective_owner_id` (root-cause fix: `claims["sub"]` was being passed as host_id); two-layer guard (router boundary + service); fixed pre-existing audit signature drift | 47/47 pass (10 new + 37 regression) |
| B3 — commission_pct unit | Pydantic validator `(0,1]`; migration 0036 with CHECK constraint; 6 test files + conftest fixed (5.00→0.05) | 43/43 commission tests pass; schema rejects 5.00, accepts 0.05 |
| H1 — AC-52 CI step | Dedicated `python scripts/check_no_host_id_alter.py` step in tests.yml line 73 (runs before alembic upgrade — fails fast) | YAML valid, 1 AC-52 marker grep |

**Regression run:** app boots ✅ · 43 commission + 71 routes + 7 security + commission regression all pass except 2 known Phase-11 scaffold tests (`test_jwt_not_cached_after_pause.py:166` wrong kwarg, `test_invoice_flow_v1_freemium.py:115` non-existent method) — flagged separately, production code unaffected.

### Outstanding (post-launch tracking)

- **Phase-11 scaffold cleanup** — 2 tests with wrong API bindings (see above)
- **Migration safety** — task #42: if staging DB has commission_pct > 1 rows, migration 0036 needs data-cleanup pre-step
- **M1** — NFR-06 FCM/push: decide implement vs formally defer
- **M2** — AC-32b tenant counter-confirm SMS link: end-to-end trace
- **M3/M4** — Security: collapse 404/403 enumeration nuance + tz-aware audit timestamps
- **LOW** — Marker tweaks (AC-58 OoO, AC-38, NFR-04/08/10), actor.py optional helper refactor

---

## Sub-Reviews

| # | Scope | Verdict | Report |
|---|-------|---------|--------|
| 1 | Security (auth/IDOR/SQLi/secrets/dual-identity) | ✅ APPROVED | `security-review.md` |
| 2 | AC coverage vs BA v4 (66 ACs + 15 NFRs) | ⚠️ CONDITIONAL | `ac-coverage-review.md` |
| 3 | Code quality + architecture (TL-1..TL-9) | ⚠️ partial (agent stalled, 1 HIGH bug confirmed inline) | (no file — bug logged below) |

---

## Aggregate Findings

### 🔴 BLOCKERS (must fix before ship)

#### B1 — AC-54 Contract PDF dual-disclosure NOT implemented
- **Source:** AC review
- **Evidence:** No `app/services/contract_pdf_service.py`. No PDF library in `requirements.txt` (no `reportlab`/`weasyprint`/`fpdf`/`pdfkit`). `app/templates/` has only invoice + KB04 templates.
- **Phase reference:** phase-09 step 8 + line 187 todo unstarted.
- **Risk:** Legal compliance gap (BA Q6.4). Tenant cannot verify operator authority → TOS breach + fraud surface.
- **Fix:** Add `weasyprint` to requirements; build `contract_pdf_service.generate()` with Owner CCCD + Operator CCCD mandatory disclosure block; NFR-12 Vietnamese diacritics golden test.

#### B2 — AC-51 Marketplace `host_id` immutable payout NOT enforced
- **Source:** AC review
- **Evidence:** `app/routers/marketplace_integration.py` + `app/services/marketplace_sync_service.py` have zero AC-51 marker, no `host_id` assertion, no `bank_account_target` validation on operator-initiated updates.
- **Phase reference:** phase-03 lines 250, 258 todos unstarted.
- **Risk:** Direct financial-loss vector — operator could divert marketplace payout from owner bank.
- **Fix:** Inject `actor_ctx` into marketplace router; assert `host_id == effective_owner_id`; reject operator-initiated bank-target change; integration test.

#### B3 — `commission_pct` unit confusion (cross-cutting)
- **Source:** Code-quality agent (confirmed inline before agent stalled)
- **Evidence:**
  - Production code `app/services/commission/commission_snapshot.py:174`: `full_commission = total * pct_decimal` → expects fraction
  - Unit test `tests/services/commission/test_commission_snapshot.py:62`: `Decimal("0.05")  # 5%` → confirms fraction convention
  - **But fixtures/integration tests use 5.00:** `tests/conftest.py:330` (default `commission_pct=5.00`), `tests/security/test_*.py` (×3), `tests/api/test_admin_routes.py`, `tests/api/test_delegation_routes.py:128,162`, `tests/regression/test_invoice_flow_with_commission_v1_freemium.py:81`
  - **Schema lacks validator:** `app/schemas/delegation.py:84` — `commission_pct: Optional[Decimal] = None`, no range check
  - **Migration lacks CHECK:** `alembic/versions/0021_*.py:139` — `Numeric(5,2)`, no `[0,1]` constraint
- **Risk:** User submits "5" via invitation API → DB stores `5.00` → every invoice computes **500% commission** instead of 5%. Direct financial loss.
- **Fix (must do all 3):**
  1. Schema: add `@field_validator` `0 < commission_pct <= 1`
  2. Migration: add `CHECK (commission_pct IS NULL OR (commission_pct > 0 AND commission_pct <= 1))`
  3. Fixtures: replace all `Decimal("5.00")` with `Decimal("0.05")` (10+ test files)

---

### 🟠 HIGH (should fix before ship)

#### H1 — AC-52 CI guard runs via pytest only (no dedicated workflow step)
- **Source:** AC review
- **Evidence:** `scripts/check_no_host_id_alter.py` is comprehensive + wired via `tests/migrations/test_delegation_migrations.py:553`. `.github/workflows/tests.yml` has no standalone step.
- **Fix (10 min):**
  ```yaml
  - name: AC-52 host_id schema guard
    run: python scripts/check_no_host_id_alter.py
  ```

---

### 🟡 MEDIUM

| # | Area | Issue | File:Line |
|---|------|-------|-----------|
| M1 | Notifications | NFR-06 push (FCM) — no FCM service implementation found; `escalation_ladder.py:3-7` claims "T+0h push" but no transport. Either add FCM or formally defer to in-app+email+SMS only. | `app/services/notification/` |
| M2 | Tenant flow | AC-32b counter-confirm SMS link — evaluator side covered (`threshold_evaluator.py:247`), but tenant FE upload (location+photo) + ≥2M SMS link endpoint not cross-verified end-to-end. | (trace needed) |
| M3 | Security | 404 vs 403 enumeration nuance — `actor.py:107-111` distinguishes "delegation not found" (404) vs "not yours" (403). With UUID4 the risk is low, but if a UUID ever leaks via logs/URLs, it confirms existence. | `app/api/dependencies/actor.py:107-111` |
| M4 | Audit | `datetime.utcnow()` is tz-naive; rest of codebase uses `datetime.now(timezone.utc)`. Inconsistent audit timestamps. | `app/repositories/audit.py:101` |

---

### 🟢 LOW (post-launch tidy)

- AC-58 OoO emergency marker missing in `escalation_ladder.py`
- AC-38 ActivityFeed filter chips (today/week/month) not verified in widget
- NFR-04 / NFR-08 / NFR-10 implemented but lack code markers (doc-only)
- `app/api/dependencies/actor.py:230` — `get_optional_actor_context` duplicates `resolve_actor_context` logic → drift risk
- `app/services/actor_context.py:149` — `int(x) for x in raw_scope_ids` raises 500 on corrupt JSON → wrap in try/except, fail-closed

---

## TL Decisions Verification (9/9 met)

| Decision | Status | Evidence |
|----------|--------|----------|
| TL-1 NFR-13 scope schema | ✅ | `app/domain/delegation.py:121-124` — `scope_type` String(20) indexed + `scope_target_ids JSON` |
| TL-2 invoice immutability snapshot | ✅ | `commission_snapshot.py:64-134` locks both `commission_*` and `platform_fee_*` at `paid_at` |
| TL-3 4-preset permission matrix | ✅ | `permission_set.py:154-158` — owner_view/operator_full/accountant/viewer, immutable frozenset |
| TL-4 Lockdown 30d window | ✅ | `lockdown_service.py` — 30d window, batch queries, AC-43 enforced before mutation |
| TL-5 Per-request actor context (no JWT cache) | ✅ | `actor.py:7-8` + `:107-140` per-request DB lookup with status check |
| TL-6 APScheduler conventions | ✅ | `register_*_jobs(scheduler)` pattern in `planning_etl/scheduler.py` |
| TL-7 Provider-pluggable integrations | ✅ | `digital_signature.py` (FastCA/VinaCA/Mock + circuit breaker); notification email/SMS providers |
| TL-8 Dual-identity audit log | ✅ | `audit.py:43-99` writes `actor_user_id` + `on_behalf_of_user_id` + `acted_via_delegation_id` |
| TL-9 Snapshot at paid_at | ✅ | `commission_snapshot.snapshot_at_paid()` called from `invoice_service.py:289` |

---

## Critical AC Verification (in-depth)

- **AC-55 KB04 fast-track** ✅ — `submit_fast_track()` with `kb04_fast_track_6h` SLA
- **AC-55b pre-file** ✅ — `pre_file()` sets gate `pending_pre_file_review`, always pending (not auto-approved)
- **AC-55c district flag** ✅ — `_check_district_flag_for_contract` + `DistrictPreFileNotAccepted` fallback
- **AC-55d POA format** ✅ — digital (FastCA/VinaCA) vs notarized, fallback on vendor unavailable
- **AC-58 owner death pause** ✅ — 24h admin verify + 7d pause via `death_pause_service`
- **AC-58b heir designation** ✅ — admin designates `executor_user_id`
- **AC-58d executor exception** ✅ — gated by `OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED` env (waiting on O3 legal)
- **NFR-07 no JWT cache** ✅ — verified by security agent + AC agent (backend + Flutter `actor_context_provider.dart:42`)
- **NFR-01 concurrency** ✅ — `SELECT FOR UPDATE` consistent in `lifecycle_service.py:15,105,768`

---

## Positive Observations

- **Marker discipline** — 77 ACs + 9 NFRs uniquely tagged in code → trivially greppable for future audits
- **Feature-flag pattern** — AC-58d executor exception implemented but gated until legal gate clears
- **Security defensive posture** — immutable frozenset permissions, per-request revocation, parameterized SQL, fail-closed scope, UUID4 header validation, dual-identity audit
- **TL-1 forward-compat** — JSON `scope_target_ids` allows v2 `room_list` extension without schema break
- **TL-2 immutability** — both `commission_*` and `platform_fee_*` locked at `paid_at`; tampering window closed

---

## Remediation Plan

**Pre-ship (required to clear CONDITIONAL):**

1. [B1 AC-54] Build `contract_pdf_service.py` + add weasyprint (~1 day)
2. [B2 AC-51] Enforce `host_id` immutability in marketplace router (~0.5 day)
3. [B3 commission_pct] Schema validator + migration CHECK + fix 10+ fixtures (~0.5 day)
4. [H1 AC-52] Add dedicated CI step (10 min)

**Post-ship hardening (track as follow-up):**
5. [M1] FCM decision (implement or formally defer NFR-06)
6. [M2] Cross-verify AC-32b end-to-end
7. [M3, M4] Security & audit tz cleanup
8. [LOW items] Marker additions + actor.py refactor

---

## Verdict: **CONDITIONAL — Ship after B1+B2+B3+H1 close + re-audit**

Coverage is strong, security posture is defensive, all 9 TL decisions verified. Two missing features (AC-51, AC-54) + one financial-unit bug (commission_pct) are the only blockers. Once these land, this is a green-light release.

---

## Unresolved Questions

1. Is FCM intentionally deferred for v1? If yes, where is that recorded vs NFR-06 p95 <30s push SLA?
2. AC-32b tenant counter-confirm SMS link endpoint — implemented or stubbed?
3. Is `contract_pdf_service.py` expected by phase-09 or has it been re-scoped post-plan? (User decision)
4. Should `commission_pct` convention switch to integer percent (0..100) for user-friendliness, or stay fraction (0..1) with stricter validation?
5. JWT TTL vs delegation revocation latency — confirm no caching at middleware layer above `resolve_actor_context`
