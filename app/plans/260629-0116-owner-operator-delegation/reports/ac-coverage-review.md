# AC Coverage Audit — Owner-Operator Delegation v1

**Auditor:** code-reviewer | **Date:** 2026-06-30
**BA spec:** `phase-00-ba-requirements.md` v4 (66 ACs + 15 NFRs)
**Method:** Grep AC/NFR markers in `ancu365-backend/app/`, `alembic/versions/`, `ancu365-app/lib/`, scripts, CI; spot-read service/route files.

---

## Summary

| | Met ✅ | Partial ⚠️ | Missing ❌ | Deferred ⏭️ | Total |
|---|---|---|---|---|---|
| ACs | 60 | 4 | 2 | 0 | 66 |
| NFRs | 13 | 2 | 0 | 0 | 15 |
| TL critical | 9 | 0 | 0 | 0 | 9 |

**Tagged in code:** 77 ACs + 9 NFRs uniquely marked — strong discipline.
**Verdict: CONDITIONAL** — 2 production blockers (AC-51, AC-54), 1 CI hardening (AC-52), minor NFR/UI doc gaps.

---

## CRITICAL Gaps (Blockers)

### ❌ AC-54 Contract PDF dual-disclosure — NOT IMPLEMENTED
- No `contract_pdf_service.py` under `app/services/`.
- No PDF library in `requirements.txt` (no `reportlab`/`weasyprint`/`fpdf`/`pdfkit`/`wkhtmltopdf`).
- `app/templates/` only has `invoice_public.html` + `khai_bao_tam_tru.html`.
- `phase-09-pricing-and-commission.md` step 8 + line 187 todo unstarted.
- **Risk:** Legal compliance (BA Q6.4). Tenant cannot verify operator authority → fraud + TOS breach.
- **Fix:** Add `weasyprint`; build `contract_pdf_service.generate()` with mandatory Owner CCCD + Operator CCCD block; golden test for NFR-12 Vietnamese diacritics.

### ❌ AC-51 Marketplace `host_id` immutable payout — NOT ENFORCED
- `app/routers/marketplace_integration.py` + `app/services/marketplace_sync_service.py` exist (pre-delegation) but contain ZERO AC-51 marker, no `host_id` assertion, no `bank_account_target` validation on operator updates.
- `phase-03-delegation-lifecycle-api.md:250,258` todos "Modify marketplace_integration router for AC-51 enforcement" — unstarted.
- **Risk:** Direct financial-loss vector. Operator could divert marketplace payout from owner bank.
- **Fix:** Inject `actor_ctx` into marketplace router; assert `host_id == effective_owner_id`; reject bank-target change by operator; integration test.

---

## HIGH Gaps

### ⚠️ AC-52 CI host_id guard — script exists, not wired as dedicated CI step
- `scripts/check_no_host_id_alter.py` is comprehensive (60 LOC, all alter/drop/rename patterns).
- `tests/migrations/test_delegation_migrations.py:553` runs it as pytest → CI does cover via `pytest tests/` step in `tests.yml`.
- `.github/workflows/tests.yml` has NO standalone step calling the script directly.
- **Severity:** LOW-MED. Coverage is real (pytest blocks merge), but dedicated step is best-practice + survives test-file moves.
- **Fix (10 min):** Add to `tests.yml` before "Run Alembic migrations":
  ```yaml
  - name: AC-52 host_id schema guard
    run: python scripts/check_no_host_id_alter.py
  ```

### ⚠️ NFR-06 push delivery (FCM) — implementation unclear
- `app/services/notification/` has `email_service.py`, `sms_service.py`, `escalation_ladder.py`, `notification_service.py` — NO FCM/push service file located.
- `escalation_ladder.py:3-7` says "T+0h push + email" but no push transport implementation grep-able.
- **Risk:** NFR-06 p95 <30s push SLA cannot be met without FCM.
- **Fix:** Either add FCM service or document that v1 uses in-app polling + email + SMS only (deferral note in plan).

---

## MED / LOW Gaps

| Severity | AC/NFR | Issue | Action |
|---|---|---|---|
| MED | AC-32b | `threshold_evaluator.py:247` covers evaluator side; FE upload of location-stamp + photo + ≥2M tenant SMS counter-confirm not cross-verified | Trace upload path + tenant link endpoint |
| LOW | AC-58 OoO emergency | `lifecycle_service.py:25` says "phase-08 handles" — no explicit AC-58-OOO marker in `escalation_ladder.py` | Add marker + targeted code |
| LOW | AC-38 ActivityFeed | Route present (`app_router.dart:358`), backend audit module exists, no explicit AC-38 marker; filter chips today/week/month not verified | Add marker; verify filter UI |
| LOW | NFR-04 | Per-request semantics implemented in `actor.py` but no NFR-04 marker | Doc-only |
| LOW | NFR-08, NFR-10 | Implemented in Flutter; not marker-tagged | Doc-only |

---

## Critical AC Verification (in-depth — as requested)

### AC-52 CI guard — see HIGH section above. Script comprehensive + pytest-covered; dedicated CI step missing.

### AC-55 family (KB04 fast-track)
- **AC-55** ✅ `app/services/approval/kb04_workflow.py:59-93` `submit_fast_track()`, sla_class=`kb04_fast_track_6h`.
- **AC-55b** ✅ `kb04_workflow.py:109-134` `pre_file()` sets gate=`pending_pre_file_review`.
- **AC-55c** ✅ `kb04_workflow.py:37,134` district pre-file flag check + `DistrictPreFileNotAccepted` fallback.
- **AC-55d** ✅ `kb04_workflow.py:41` POA digital (FastCA/VinaCA) vs notarized verification.

### AC-58 family (owner death)
- **AC-58 (heir)** ✅ `app/api/routes/owner_death.py:108-166` report + 24h admin verify + 7d pause; `death_pause_service.py:25-61` pause logic.
- **AC-58b** ✅ `owner_death.py:371-379` admin designates heir.
- **AC-58d** ✅ `owner_death.py:422-486` executor exception **gated by `OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED` env flag** pending O3 legal gate — correct feature-flag pattern.

### NFR-07 (no JWT cache of delegation state)
- ✅ `app/api/dependencies/actor.py:7-8`: "JWT remains user-identity only (NFR-07): delegation state NOT cached in JWT" + `:107-140` per-request DB lookup with status check (paused/terminated/archived → 401 with typed codes).
- ✅ Flutter: `lib/providers/actor_context_provider.dart:42` "Does NOT write to any persistent storage — request-scoped only".

### NFR-13 (scope_type + scope_target_ids JSON)
- ✅ `app/domain/delegation.py:121-124`: `scope_type Mapped[str] = String(20)` indexed; `scope_target_ids Mapped[Optional[dict]] = JSON nullable`.
- ✅ Same on `delegation_invitations` (`:248-249`) for forward-compat. v2 nesting = add enum value only.

### TL-1 (NFR-13 scope schema) ✅ — see NFR-13 above.

### TL-2 (invoice immutability — `platform_fee_pct` snapshot at paid_at)
- ✅ `app/models.py:632`: `platform_fee_pct Mapped[Optional[object]] = Numeric(5,4) nullable`.
- ✅ `app/services/commission/commission_snapshot.py:64-134`: `snapshot_at_creation()` sets to 0 (v1 NFR-15); `snapshot_at_paid()` locks at paid_at.
- ✅ `invoice_service.py:9-12`: "locks commission_rate, commission_amount, platform_fee_pct, platform_fee_amount; both fields are immutable after paid_at IS NOT NULL (service-layer guard)."

### TL-3 (4 presets)
- ✅ `app/services/permission_set.py:154-158` `_PRESET_MAP = {owner_view, operator_full, accountant, viewer}`; immutable `frozenset` per preset.

---

## Coverage Snapshot (passing ACs, condensed)

**§6.1 lifecycle (AC-01..10b):** all ✅ via `delegation/invitation_service.py` + `lifecycle_service.py` + `domain/delegation.py`.
**§6.2 context-switch (AC-11..18):** all ✅ via Flutter `operator/portfolio/` + `operator/workspace/operator_workspace_shell.dart` + `actor_context_provider.dart`.
**§6.3 permissions (AC-19..23):** all ✅ via `permission_set.py` + `0032/0033` dual-identity migrations.
**§6.4 approvals (AC-24..31b):** all ✅ via `approval/threshold_evaluator.py` + `auto_reject_job.py` + `escalation_ladder.py` (NFR-14 early SMS on high-value).
**§6.5 finance (AC-32..37):** ✅ except AC-32b ⚠️.
**§6.6 audit (AC-38..41):** ✅ except AC-38 marker ⚠️.
**§6.7 termination (AC-42..46):** all ✅ including AC-43b 24h fraud SLA + AC-44 4-tier archive.
**§6.8 non-regression (AC-47..56):** ✅ except AC-51 ❌, AC-52 ⚠️ (CI step), AC-54 ❌.
**§6.9 OoO (AC-57..58):** AC-57 ✅; AC-58-OOO ⚠️ marker gap.
**§6.10 death (AC-58..58d):** all ✅.
**§6.11 tenant/PDPL (AC-59..66):** all ✅ — including AC-60 authority badge (`tenant/widgets/authority_badge_widget.dart`), AC-62 server-stamp (`models.py:315`), AC-64 sole-ownership, AC-65 PMC legal-rep change, AC-66 shared-login disclosure ack.

---

## Positive Observations

- **Marker discipline** — 77 ACs + 9 NFRs uniquely tagged; future audits trivially greppable.
- **NFR-01 concurrency** — `SELECT FOR UPDATE` consistent in `lifecycle_service.py:15,105,768` — race conditions on pause/terminate prevented.
- **AC-58d feature flag** — exemplary pattern: executor exception path implemented BUT gated until O3 legal gate clears.
- **TL-2 immutability** — both `commission_*` and `platform_fee_*` locked at `paid_at`; tampering window closed.
- **AC-52 actual coverage** — pytest exercises the guard script; not just a forgotten file.
- **TL-1 forward-compat** — JSON `scope_target_ids` enables v2 `room_list` enum addition without schema break.

---

## Action List (prioritized)

1. **[CRITICAL]** Build `app/services/contract_pdf_service.py` + add PDF library — AC-54.
2. **[CRITICAL]** Enforce `host_id` immutability in `marketplace_integration.py` router — AC-51 (phase-03 todos 250, 258).
3. **[HIGH]** Add explicit `python scripts/check_no_host_id_alter.py` step in `tests.yml` — AC-52 visibility.
4. **[MED]** Clarify FCM/push delivery path or formally defer NFR-06 to in-app+email+SMS only.
5. **[MED]** Verify AC-32b end-to-end (location/photo upload + ≥2M tenant SMS link).
6. **[LOW]** Add AC-58-OOO marker in `escalation_ladder.py`; AC-38 marker + filter UI check; NFR-04/08/10 doc markers.

---

## Verdict: **CONDITIONAL**

Coverage is strong (60/66 ACs, 13/15 NFRs fully met). Two implementation gaps must close before production:
- **AC-54** — legal compliance (contract PDF dual-disclosure).
- **AC-51** — financial-risk (marketplace payout immutability).

All other gaps are CI-hardening, FCM clarification, or doc/marker tweaks. Re-audit after AC-54 + AC-51 land.

---

## Unresolved Questions

1. Is FCM intentionally deferred? If yes, where is that recorded vs NFR-06 p95 <30s push SLA?
2. AC-32b tenant counter-confirm SMS link endpoint — implemented or stubbed?
3. AC-38 ActivityFeed depth — filter chips (today/week/month) + per-entity deep-links present in widget?
4. Is `contract_pdf_service.py` expected by phase-09 or has it been re-scoped post-plan?
