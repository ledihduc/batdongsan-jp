# Phase 11 — Testing & Pre-launch Validations

## Context Links

- BA v4 §11 (Success Metrics + KPI hard-gates), §13 (D1-D9+Q1 decisions, pre-launch validation items O1-O4), §14 (Approval gates)
- All ACs (66 total) carry "Test" column — phase-11 ensures full coverage
- Research: `researcher-01-backend-auth-kyc.md` §H (RBAC readiness 30% — needs full IDOR test suite); `researcher-02-backend-money-flows.md` §F (no state-machine framework — service-layer + router-guard pattern needs explicit tests); `researcher-03-flutter-app.md` §I (mocktail + integration_test in pubspec, no current test suite found in scope)
- Prereq phases: ALL implementation phases (01-10) — testing is rolling within each phase + final cross-cutting validation here

## Overview

**Priority:** P0 (no merge without green tests; pre-launch gates block release)
**Status:** Pending
**Brief:** Cross-cutting test matrix + dedicated regression suite + 4 pre-launch validation gates (O1-O4). Unit tests live within each phase; phase-11 owns integration suite, end-to-end flows, security/IDOR matrix, performance load tests, device matrix, and the 4 ops validation gates (police pre-file acceptance, police digital POA acceptance, legal counsel on executor exception, NHNN intermediary license scope).

## Key Insights from Research

- **RBAC test surface large** (researcher-01 §H): 30% readiness today; phase-02 builds the rest. Every endpoint × every preset role × every entity = full matrix needed. Pre-compute matrix (~150-200 cases).
- **State machine has no framework** (researcher-02 §F): all transitions enforced at service layer. Tests must cover every transition + edge (mid-transition revoke, race conditions).
- **No mock-DB precedent in backend** (researcher-02 §G): tests use real Postgres test DB. Use pytest fixtures with transactional rollback per test. SQLite fallback for fast local dev tests.
- **Flutter test scaffolding minimal** (researcher-03 §I): `mocktail` + `integration_test` in pubspec but no tests in scope. Phase-11 establishes test conventions + golden file structure.
- **CCCDAccessLog audit** (researcher-02 §D): every PII access must trigger log; tests assert log creation.

## Requirements (mapped to BA v4)

| Category | Coverage |
|----------|----------|
| Unit tests | Every service function with business logic (~150-200 cases) |
| Integration tests | All API endpoints × actor context × permission preset (~150 cases) |
| State machine tests | Delegation lifecycle (10 states), approval lifecycle (5 states), owner death (8 states) |
| Security / IDOR tests | Owner X cannot access Owner Y's data; operator cannot escalate; admin actions audited |
| Performance tests | NFR-03 (audit log p95 <1s at scale), NFR-05 (scope check latency), NFR-06 (push delivery p95 <30s), NFR-09 (operator portfolio p95 ≤ 2.5s on 3G) |
| Device matrix | NFR-08 (Android 7.0+), Huawei without GMS, iOS 16+, Vietnamese diacritic golden tests (NFR-12) |
| Email deliverability | NFR-14 ≥95% inbox rate (third-party test: Postmark inbox-placement) |
| Legal validations | O1 police pre-file, O2 police digital POA, O3 executor exception counsel sign-off, O4 NHNN license (v2 gate) |
| Operational | Vendor contracts (SES, eSMS/FPT.AI, FastCA/VinaCA), DLT registration, AWS production access |

## Architecture

### Test pyramid

```
                  ┌─────────────────────┐
                  │   E2E (~30 cases)   │   real backend + Flutter integration
                  ├─────────────────────┤
                  │ Integration (~150)  │   FastAPI TestClient + Postgres test DB
                  ├─────────────────────┤
                  │   Unit (~200)       │   pytest, mocktail (Dart)
                  └─────────────────────┘
                  ┌─────────────────────┐
                  │  Static (~10 lints) │   mypy, eslint, flutter analyze
                  └─────────────────────┘
```

### Test categories

```
backend/tests/
├── unit/                      — per-service + per-function
├── integration/               — per-router endpoint × actor context
├── security/                  — IDOR matrix, role escalation, audit assertions
├── state_machine/             — delegation, approval, owner death transitions
├── performance/               — NFR-03/05/06 load + latency
└── fixtures/                  — shared test DB seeders

ancu365-app/integration_test/
├── e2e/                       — full user flows (invite → accept → approve → audit)
├── golden/                    — PDF diacritic rendering, widget snapshots
├── device_matrix/             — Android 7.0, 12, Huawei, iOS 16, 17
└── perf/                      — portfolio screen latency on simulated 3G
```

### Pre-launch validation gates (BA §14)

```
[O1 police pre-file (CT01)] ──┐
[O2 police digital POA]     ──┤
[O3 legal counsel executor] ──┼── ALL must be GREEN before v1 launch
[Vendor contracts (SES+SMS+sig)] ──┤
[Q-DD5 sponsor TAM defer accept] ──┘

[O4 NHNN license] ─── BLOCKS v2 only (not v1 launch gate)
```

## Related Code Files

### Create

- `backend/tests/conftest.py` — shared fixtures (test DB, factories, auth helpers)
- `backend/tests/fixtures/factories.py` — User, Delegation, Invitation, ApprovalRequest factories (FactoryBoy or pydantic-factories)
- `backend/tests/unit/test_delegation_service.py`
- `backend/tests/unit/test_approval_service.py`
- `backend/tests/unit/test_commission_service.py`
- `backend/tests/unit/test_owner_death_service.py`
- `backend/tests/unit/test_retention_service.py`
- `backend/tests/unit/test_business_hours.py`
- `backend/tests/integration/test_delegation_router.py`
- `backend/tests/integration/test_approval_router.py`
- `backend/tests/integration/test_admin_routers.py`
- `backend/tests/integration/test_commission_router.py`
- `backend/tests/integration/test_pdpl_rod.py`
- `backend/tests/security/test_idor_matrix.py` — generated matrix
- `backend/tests/security/test_role_escalation.py`
- `backend/tests/security/test_audit_dual_identity.py`
- `backend/tests/state_machine/test_delegation_lifecycle.py`
- `backend/tests/state_machine/test_approval_lifecycle.py`
- `backend/tests/state_machine/test_owner_death_lifecycle.py`
- `backend/tests/performance/test_audit_log_latency.py`
- `backend/tests/performance/test_scope_check_latency.py`
- `backend/tests/performance/test_push_delivery_latency.py`
- `ancu365-app/test/providers/actor_context_provider_test.dart`
- `ancu365-app/test/providers/delegation_provider_test.dart`
- `ancu365-app/test/providers/approval_provider_test.dart`
- `ancu365-app/test/widgets/acting_as_app_bar_test.dart`
- `ancu365-app/test/widgets/authority_badge_widget_test.dart`
- `ancu365-app/test/golden/contract_pdf_diacritic_test.dart` — golden image of dual-disclosure PDF
- `ancu365-app/integration_test/e2e_invite_accept_test.dart`
- `ancu365-app/integration_test/e2e_approval_flow_test.dart`
- `ancu365-app/integration_test/e2e_context_switch_test.dart`
- `ancu365-app/integration_test/e2e_owner_death_admin_test.dart`
- `ancu365-app/integration_test/perf_portfolio_3g_test.dart`
- `docs/pre-launch-checklist.md` — O1-O4 + vendor contracts status tracker

### Modify

- `pyproject.toml` or `requirements-dev.txt` — add `pytest`, `pytest-asyncio`, `factory-boy`, `freezegun`, `httpx` (TestClient already in FastAPI)
- `.github/workflows/test.yml` — CI matrix runs unit → integration → security → state_machine (perf nightly only)
- `pubspec.yaml` — confirm `mocktail` + `integration_test` versions; add `golden_toolkit` for golden file management

### Delete

- None.

## Implementation Steps

1. **Backend test scaffolding** — set up `conftest.py` with:
   - Test DB fixture (Postgres, transactional rollback per test).
   - User factory with role variants (guest, host, operator, admin).
   - Delegation factory with all 4 presets + threshold defaults.
   - Auth helper to mint JWT + populate `X-Acting-As-Delegation-Id` header.
   - Time-mocking via `freezegun`.

2. **Unit test coverage by service** — write ≥1 test per public function:
   - `delegation_service`: create, accept, reject, pause, resume, terminate (with 30d notice and immediate), force_revoke.
   - `approval_service`: create, decide (approve/reject), expire (72h), escalate, cancel_in_flight, reassign_to_new_legal_rep.
   - `commission_service`: compute_commission (percentage, fixed_amount, partial payment AC-37, NULL delegation).
   - `owner_death_service`: activate_death_workflow, start_executor_onboarding, transfer_delegation_to_executor.
   - `retention_service`: tier transitions, redact_tier_c, ROD processor.
   - `business_hours`: weekend + holiday + DST edge.

3. **State machine tests** — exhaustive transition matrix:
   - Delegation lifecycle: pending → active → paused → active → terminated_pending → terminated → archived (each invalid transition raises ValueError + audit not written).
   - Approval lifecycle: pending → approved | rejected | expired | auto_rejected_owner_death (test each path + idempotency).
   - Owner death lifecycle: normal → death_pending → death_verified → pause_state → (executor_onboarded → transferred | not_onboarded → terminated_admin_review).

4. **Integration test matrix** — per endpoint:
   - For each `/api/*` route × {guest, host, operator-full, accountant, viewer, admin, unauthenticated}:
     - Expected status code (200 / 401 / 403)
     - Expected response shape
     - Audit log assertion (actor + on_behalf_of + action)
   - Generate matrix programmatically (csv → pytest.parametrize).

5. **IDOR + cross-tenant isolation tests** (AC-16, AC-16b):
   - Operator with active delegation A tries to access Owner B's data → 403.
   - Owner with paused delegation, operator hits API → 401 with code `DELEGATION_PAUSED`.
   - Operator after mid-session revoke, next call → 401 `DELEGATION_REVOKED`.
   - Tenant cannot access other tenants' data on same property.

6. **Security regression** (AC-22, AC-23, AC-53):
   - Operator cannot CRUD `operator_delegations`.
   - Every mutation writes dual-identity audit (actor=operator, on_behalf_of=owner, delegation_id present).
   - Bank account fields masked in operator view; full reveal requires consent token (CCCDAccessLog row written).

7. **Performance tests** (NFR-03, NFR-05, NFR-06, NFR-09):
   - Seed 10M audit rows → query by owner_id + date range → assert p95 < 1s.
   - Seed 50 delegations under 1 operator → scope check at request time p95 < 50ms (NFR-05 threshold TBD by Tech Lead).
   - Send 1000 notifications → measure FCM ack latency p95 < 30s.
   - Flutter integration: simulated 3G profile → portfolio screen render p95 ≤ 2.5s (use `flutter_driver` + network throttle).

8. **Device matrix** (NFR-08, NFR-12):
   - Android 7.0 (API 24) emulator + real Huawei device (no GMS).
   - iOS 16 + iOS 17 simulator + real device.
   - Vietnamese diacritic golden tests: render full alphabet `àáảãạăằắẳẵặâầấẩẫậ...` in DsTextField + PDF preview → compare to golden bytes.

9. **NFR-14 email deliverability** — third-party validation:
   - Sign up for Postmark or Litmus inbox-placement testing.
   - Send 100 test emails to seed list across major VN ISPs (Gmail, Yahoo, FPT, VNPT, Viettel).
   - Measure inbox vs spam vs missing rate; target ≥95% inbox.
   - Repeat post-launch monthly.

10. **Pre-launch validation gates execution**:
    - **O1**: Coordinate with legal + ops to file CT01 at HCMC quận 1, HCMC quận 7, Hà Nội quận Hoàn Kiếm, Hà Nội quận Cầu Giấy. Document acceptance/rejection per district. Populate `buildings.district_pre_file_accepted` flag.
    - **O2**: Same 4 districts — submit digital signed POA (FastCA test signature). Document acceptance.
    - **O3**: Legal counsel review of AC-58d executor-exception path; written sign-off → feature flag `ENABLE_EXECUTOR_DECIDE_EXCEPTION=true` enabled.
    - **O4**: Corporate counsel memo on NHNN intermediary license scope for v2 auto-commission (not v1 blocker).
    - **Q-DD5**: Sponsor written acceptance of cumulative TAM defer (D4 + D6 + D7 = ~30-40% Segment C).
    - **Vendor contracts**: AWS SES production access, eSMS/FPT.AI account + DLT, FastCA/VinaCA contract.

11. **Pre-launch checklist** — single source-of-truth doc `docs/pre-launch-checklist.md`:
    ```
    ## Pre-launch validation gates (BA v4 §14)
    [ ] O1  Police pre-file acceptance (4 districts)        Owner: legal+ops  Status: ___ Due: phase-04 mid
    [ ] O2  Police digital POA acceptance (4 districts)     Owner: legal      Status: ___ Due: phase-05 freeze
    [ ] O3  Legal counsel on AC-58d executor exception      Owner: counsel    Status: ___ Due: phase-06 freeze
    [ ] Q-DD5  Sponsor TAM defer acceptance                 Owner: sponsor    Status: ___ Due: before phase-04
    [ ] AS-14  FastCA OR VinaCA contract signed              Owner: procurement Status: ___ Due: phase-05 mid
    [ ] AWS SES production access                           Owner: ops        Status: ___ Due: phase-08
    [ ] eSMS / FPT.AI account + DLT brand                   Owner: ops        Status: ___ Due: phase-08
    [ ] NFR-14 inbox deliverability ≥95% measured           Owner: BE+ops     Status: ___ Due: phase-11
    [ ] All ACs (66) have ≥1 passing test                   Owner: QA         Status: ___ Due: phase-11
    [ ] All NFRs (15) measured and meet threshold           Owner: QA+BE      Status: ___ Due: phase-11
    ```

12. **CI matrix** — GitHub Actions:
    - PR build: lint + unit + integration (parallel matrix on backend phases).
    - Merge to main: + state machine + security + IDOR.
    - Nightly: + performance + device matrix (Android emulators + iOS sim).
    - Weekly: + email deliverability check.

13. **Test coverage gate** — ≥80% coverage for `app/services/` directory (delegation, approval, owner_death, retention, commission). Coverage tool: `pytest --cov`.

14. **Smoke test for pilot launch** — single E2E script:
    - Create owner + operator + tenant.
    - Owner invites operator with `operator_full` preset.
    - Operator accepts, KYC completes.
    - Owner creates contract via UI; verify operator can view + manage.
    - Operator creates invoice above threshold → approval request to owner.
    - Owner approves via push notification deep-link.
    - Operator marks invoice paid → commission computed.
    - Owner exports commission report (TNCN format) → file present + sha256 matches.
    - Owner pauses delegation → operator next call gets 401 DELEGATION_PAUSED.

## Todo List

- [ ] Set up backend test scaffolding (conftest, factories, auth helper, time-mock)
- [ ] Write unit tests for 6 services (delegation, approval, commission, owner_death, retention, business_hours)
- [ ] Write state machine transition tests (3 lifecycles)
- [ ] Write integration test matrix (endpoint × role × expected outcome)
- [ ] Write IDOR + cross-tenant security tests
- [ ] Write audit dual-identity assertion tests
- [ ] Write performance tests (audit p95, scope check, push delivery, portfolio screen)
- [ ] Set up Flutter test scaffolding (mocktail mocks, golden_toolkit)
- [ ] Write Flutter unit tests for 3 providers
- [ ] Write Flutter widget tests for key widgets (ActingAsAppBar, AuthorityBadge, ApprovalCard)
- [ ] Write golden tests for diacritic rendering + PDF preview
- [ ] Write E2E integration tests for 4 critical flows (invite/accept, approval, context switch, owner death admin)
- [ ] Set up device matrix CI (Android emulators, iOS simulators)
- [ ] Sign up for Postmark/Litmus inbox-placement testing
- [ ] Execute O1 police pre-file validation (4 districts)
- [ ] Execute O2 police digital POA validation (4 districts)
- [ ] Secure O3 legal counsel sign-off on AC-58d
- [ ] Secure O4 corporate counsel memo on NHNN license (v2 gate, not v1 blocker)
- [ ] Sign vendor contracts: AWS SES production, eSMS/FPT.AI + DLT, FastCA/VinaCA
- [ ] Secure Q-DD5 sponsor TAM defer acceptance (written)
- [ ] Build and maintain `docs/pre-launch-checklist.md`
- [ ] Configure GitHub Actions CI matrix
- [ ] Set coverage gate ≥80% for services
- [ ] Run smoke test E2E for pilot launch readiness
- [ ] Publish go/no-go report to sponsor with all gates green

## Success Criteria

- **Tests:** All 66 ACs have ≥1 passing test in the integration suite; all 15 NFRs measured and meet threshold; ≥80% coverage on `app/services/` directory; CI matrix green on main branch.
- **Pre-launch gates:** All 9 items in `docs/pre-launch-checklist.md` marked complete + dated + owner-signed.
- **Performance:** Audit query p95 < 1s at 10M rows; portfolio screen p95 ≤ 2.5s on simulated 3G; push delivery p95 < 30s; scope check well under any reasonable threshold.
- **Email:** NFR-14 measured ≥95% inbox rate on Postmark seed list across major VN ISPs.
- **Device matrix:** Golden tests pass on Android 7.0, Android 12, iOS 16, iOS 17, Huawei without GMS; Vietnamese diacritics render correctly on all.
- **Smoke test:** End-to-end pilot scenario completes in <5 minutes with no errors.

## Risk Assessment

- **R1 — Test surface explosion**: matrix tests can balloon. Mitigation: programmatic generation from csv; deduplicate via parametrize; target meaningful coverage not 100%.
- **R2 — Flaky integration tests** (real DB, real APScheduler): mitigation: deterministic time-mock via freezegun; transactional rollback per test; mock external vendors (SES/SMS/FCM) at the boundary.
- **R3 — Pre-launch gate slippage**: O1/O2 require physical police office visits — calendar risk. Mitigation: start gate execution at phase-04 kickoff (not at phase-11). Budget 2-3 weeks for police validation.
- **R4 — Vendor contract delays**: AWS SES production approval, DLT brand registration, FastCA contract all have multi-week lead times. Mitigation: ops files all paperwork at sprint 1; phase-11 only verifies completion.
- **R5 — Device matrix coverage gaps**: Huawei without GMS, low-end Android 7 phones not in office. Mitigation: BrowserStack / device farm subscription; or buy 2-3 representative devices for QA team.
- **R6 — Diacritic golden test flakiness**: font rendering varies between OS versions. Mitigation: per-platform golden files (golden_android.png, golden_ios.png); update annually with new OS releases.
- **R7 — Performance test environment != production**: synthetic load on staging may not predict prod. Mitigation: shadow-test in pilot phase with real Segment C owners (10 delegations) before broader launch.
- **R8 — Smoke test brittleness**: full E2E depends on all phases shipping. Mitigation: gate smoke test on phase 01-10 completion; if blocked, run partial smoke for completed segments.

## Security Considerations

- **No production secrets in tests**: all credentials via env vars + dummy values; CI uses GitHub secrets.
- **Test data isolation**: each test creates its own users + delegations; transactional rollback prevents cross-contamination.
- **Security tests as gatekeepers**: IDOR matrix + role escalation tests are blocking on merge — security regression = CI fail.
- **Audit log tests assert dual-identity** on every mutation; missing audit row = test failure.
- **Pen-test recommendation** (out-of-band): commission third-party pen-test for v1 launch (not phase-11 responsibility; ops budget).

## Estimated Effort

**8 dev-days** = 1 QA × 5d (test authoring + CI setup) + 1 BE × 2d (perf tests + state machine tests) + 1 FE × 1d (golden + integration tests). Pre-launch validation gates run in parallel as ops/legal tasks (3-4 calendar weeks lead time, not dev-days).

## Next Steps / Dependencies

- **Blocks:** v1 launch (no go-live without green CI + all gates green).
- **Blocked by:** ALL implementation phases (01-10). Begin scaffolding + early unit tests after phase-02 ships.
- **Independent:** Pre-launch ops gates (O1-O4, vendor contracts) run in parallel from sprint 1.

## Open items flagged

- **O1** — Police pre-file acceptance validation in HCMC + Hà Nội target districts.
- **O2** — Police digital POA acceptance per district.
- **O3** — Legal counsel sign-off on AC-58d executor exception.
- **O4** — NHNN intermediary license (v2 gate, not v1 blocker but tracked).
- **Q-DD5** — Sponsor written acceptance of TAM defer.
- **Q-DD8** — Admin team scaling decision (informs ops capacity for SLA testing).
- **Pen-test budget** — third-party security validation pre-launch (out-of-scope here; recommend ops budget item).
