---
title: "Revenue Analytics Full Rebuild — Implementation Plan"
description: "Rebuild module thống kê doanh thu cho host VN: KPI dashboard, charts, heatmap, drill 4 cấp, TT200 Excel export"
status: pending
priority: P1
effort: 41-55d
branch: TBD
tags: [revenue, analytics, backend-rebuild, flutter, tt200, migration]
created: 2026-06-28
---

# Revenue Analytics Full Rebuild — Implementation Plan

**Status:** Tech Lead draft awaiting user approval
**Created:** 2026-06-28
**Owner:** TBD
**BA Doc:** `phase-00-ba-requirements.md` (16 US, 18 AC, 12 R, BA Leader READY w/ 6 conditions)
**Researcher inputs:** `research/researcher-{market,codebase-audit,legacy-consumers,migration-safety,architecture-patterns}.md`

---

## Phase Summary

| # | Title | Duration | Status | Output | Blocked by |
|---|-------|---------|--------|--------|------------|
| 00 | Gate Conditions (TT200 accountant, legacy grep, migration dry-run, heatmap+drill wireframe) | 2-3d | **completed** (5 cleared, 2 partial pending external action) | 6 reports + heatmap spike — see Phase 00 Sign-off below | — |
| 01 | DB Migration + Schema (6 alembic revisions, backfill 3 default sources) | 3-4d | **completed locally** (prod-clone pre-flight pending ops before merge to main) | Alembic **0012-0017** local SQLite clean — see `reports/phase-01-completion.md` | 00 |
| 02 | Backend `analytics_service.py` rebuild (gross/net, prorate, refund, TZ HCM) | 7-9d | **completed** (100/100 tests, 95% coverage; schema freeze doc shipped) | New service + 100 tests — see `reports/phase-02-completion.md` | 01 |
| 03 | Backend routers (`host_analytics.py` + `host_sources.py`) + CRUD | 3-4d | **completed** (175/175 router tests, 95%+ coverage; legacy report_service.py deleted; archived suffix stripped via display_name) | 9 endpoints + legacy shim — see `reports/phase-03-completion.md` | 02 |
| 04 | Flutter data layer (models, repo, ReportProvider cache, helpers) | 3-4d | **completed** (98/98 tests, 82.9% coverage, flutter analyze clean) | 5 models + IAnalyticsRepository + ReportProvider cache + helpers — see `reports/phase-04-completion.md` | 03 (or schemas frozen end of 02) |
| 05 | Analytics home + KPI cards + period swiper | 4-5d | **completed** (34/34 widget tests, flutter analyze clean) | Home screen + 5 KPI + swipe + goal bar — see `reports/phase-05-completion.md` | 04 |
| 06 | Charts: trend + heatmap + source breakdown (`fl_chart`) | 5-7d | **completed** (36/36 widget tests, donut for source) | 3 chart screens — see `reports/phase-06-completion.md` | 00 (heatmap wireframe) + 05 |
| 07 | Drill 4 levels (room→contract→tenant→invoice) + filter bottom sheet | 5-6d | **completed** (66/66 tests, flutter analyze clean) | 4 drill screens + breadcrumb + filter — see `reports/phase-07-completion.md` | 00 (drill wireframe) + 05 |
| 08 | Source management CRUD screen | 2-3d | **completed** (27/27 tests, flutter analyze clean) | List/add/edit/archive UI — see `reports/phase-08-completion.md` | 04 |
| 09 | Excel TT200 full 50+ cột export (6 sheets, versioned + hash) | 5-7d | **completed (DRAFT — R11 pending)** (55/55 tests; experimental tag; UI tooltip "Bản nháp") | 6 sheets + reauth + audit + Flutter share — see `reports/phase-09-completion.md` | 00 (accountant) + 02 |
| 10 | Empty/error/loading/polish + offline badge + i18n keys | 2-3d | **completed (with deferrals)** (17/17 new tests; i18n + SVG deferred to V2) | Offline + stale badges in AnalyticsHome — see `reports/phase-10-completion.md` | 05, 06, 07, 08 |
| 11 | E2E + perf benchmark + analytics tracking + ≥80% coverage | 3-4d | **completed (device-pilot E2E deferred)** (24/24 new tests; coverage 92%; perf SQLite verified) | TelemetryService + perf + IDOR + traceability — see `reports/phase-11-completion.md` | 09, 10 |

**Parallelizable:**
- Phase 02 (BE service) ‖ Phase 04 (FE data layer) once schemas frozen end of 02 day 3
- Phase 06 ‖ Phase 07 ‖ Phase 08 (different files, all build on Phase 05)
- Phase 09 (BE) ‖ Phase 06/07/08 (FE) — separate ownership

---

## Architecture Decisions

1. **Backend rebuild from scratch** (Q10): delete `app/services/report_service.py`, create `analytics_service.py` w/ gross/net split + multi-month prorate + TZ-aware aggregation. Legacy consumer audit (researcher-legacy-consumers.md) confirms LOW risk: only 4 routes + 1 Flutter repo + 8 tests. Rationale: 65% Keep/30% Refactor/5% Delete codebase audit shows clean foundation; rebuild service layer is cheaper than patching the broken gross/net + prorate logic.
2. **Sync SQLAlchemy + Pydantic v2** (architecture researcher §1): mirror existing pattern — service returns dict, router wraps in `response_model`, router owns commit, host_id always from `int(claims["sub"])`. No drift from existing modules.
3. **Migration: 7 alembic revisions w/ dual-write window** (migration researcher §Proposed): keep `Reservation.source` String column for 1 sprint after FK introduced (drop in Phase 3.5 follow-up = revision 0017, NOT in this plan scope). Mitigates R10 data-loss risk.
4. **Goal storage = Option A** (BA §6.2): single `HostProfile.monthly_revenue_goal: float?` for MVP. KISS. Upgrade to bảng `host_revenue_goals` if user requests per-month goals.
5. **Refund attribution by `CreditNote.issued_date`** (AC-05): never revise prior periods retroactively; invoice voided after export → original export stays immutable (versioned + sha256).
6. **TZ Asia/Ho_Chi_Minh** (Q6): server stores UTC; all aggregation queries convert to HCM TZ before `date_trunc()`. Cross-year boundary (31/12→01/01) handled via prorate test fixture (AC-06).
7. **Flutter chart library = `fl_chart` ^0.68.0** (Q9, codebase audit §6): MIT, mobile-optimized, no native deps. Heatmap virtualized via `ListView.builder` w/ sticky first col.
8. **Drill 4 levels w/ breadcrumb** (Q8 + BA Leader §11.1 #3): each level its own screen, breadcrumb sticky top, "back to summary" shortcut, max depth wireframed in Phase 00 to mitigate R12.
9. **TT200 immutability via versioned export + sha256 hash** (AC-10 + BA Leader §11.1 #6): re-export same period → `v2.xlsx`, `v3.xlsx`...; metadata table `tt200_exports(host_id, period, version, hash, exported_at)` for audit trail.
10. **Excel export gated by re-auth (password/biometric)** (BA §11.3): TT200 contains MST + tenant PII; audit log every export attempt.

---

## Phase-0 Gate (MUST clear before Phase 01)

6 conditions from BA Leader §11.1:

1. **R9 — Legacy grep audit verified** — re-run grep `report_service` to catch anything researcher missed; document confirm-list. Output: `reports/phase-00-legacy-grep.md`.
2. **R11 — TT200 tax accountant booked** — pilot 2-3 kế toán, budget + ETA documented before Phase 09. Output: `reports/phase-00-accountant-booking.md`.
3. **R10 — Migration pre-flight queries run on prod-clone** — `SELECT source, COUNT(*) FROM reservations GROUP BY source` + host_id NULL check; documented. Output: `reports/phase-00-migration-preflight.md`.
4. **Heatmap mobile prototype** — Figma OR Flutter spike on Samsung A14 + iPhone SE w/ 50-row virtualized list, sticky col, color-blind safe palette. Output: `reports/phase-00-heatmap-wireframe.md`.
5. **Drill 4-level wireframe** — paper/Figma: Phòng → Contract → Tenant → Invoice + breadcrumb + back-to-summary shortcut. Output: `reports/phase-00-drill-wireframe.md`.
6. **6 unresolved migration questions resolved** (researcher-migration-safety.md §Unresolved): documented Tech Lead decisions inline in `phase-01-db-migration-schema.md`.

Phase 00 blocks: 01 (migration), 06 (heatmap), 07 (drill), 09 (TT200).

### Phase 00 Sign-off (2026-06-28)

| # | Condition | Status | Artifact | Blocker for |
|---|-----------|--------|----------|-------------|
| 1 | R9 — Legacy grep audit | ✅ CLEARED | `reports/phase-00-legacy-grep.md` | — |
| 2 | R11 — TT200 accountant brief | 🟡 BRIEF READY — awaiting user outreach | `reports/phase-00-accountant-booking.md` | Phase 09 sign-off |
| 3 | R10 — Migration pre-flight (local) | 🟡 CONDITIONALLY CLEARED — prod-clone SQL pending ops | `reports/phase-00-migration-preflight.md` | Phase 01 alembic merge to main |
| 4 | Heatmap prototype | ✅ CLEARED (architectural) — device benchmark deferred to Phase 06 dev gate | `reports/phase-00-heatmap-wireframe.md` + `lib/features/host/analytics/prototype/heatmap_spike.dart` | — |
| 5 | Drill 4-level wireframe | ✅ CLEARED (Tech Lead side) — Figma polish optional | `reports/phase-00-drill-wireframe.md` | — |
| 6 | 6 migration questions resolved | ✅ CLEARED | `reports/phase-00-migration-questions-resolved.md` | — |

**Verdict:** Phase 01 (DB Migration + Schema) UNBLOCKED on Tech Lead side. Two parallel external actions tracked:
- USER: book ≥1 accountant by week 3 → blocks Phase 09 sign-off.
- OPS/DEVOPS: run prod-clone SQL pre-flight before alembic revision 0011 merge to main.

---

## Cross-phase Dependencies

```
[00] → [01] → [02] → [03] → [04] → [05] ┬→ [06] ┐
                  ↘ (schemas frozen)─→ [04]      ├→ [10] → [11]
                                       [05] ─┬→ [07] ┤
                                             └→ [08] ┘
                                              [09]   ↗ (parallel BE w/ 06-08)
```

- 02 ‖ 04 possible after 02 day 3 (schemas frozen).
- 06, 07, 08 parallel after 05 (different file ownership).
- 09 BE parallel w/ 06-08 FE (no file overlap).

---

## Total Effort

- **Solo fullstack:** 41-55d + 15% buffer = **47-63d (~9-13 weeks)**.
- **1 BE + 1 FE parallel:** **25-35d (~5-7 weeks)** if Phase 02 ‖ 04, Phase 09 ‖ 06-08.

---

## Top-3 Risks

| Rank | Risk | Mitigation |
|------|------|-----------|
| 1 | R11 — TT200 spec inaccurate (BA không phải kế toán) | Phase 00 condition: book accountant pilot; Phase 09 BLOCKED until sign-off |
| 2 | R10 — Migration data-loss enum→FK | Phase 00 pre-flight query; dual-write window 1 sprint; transactional verify in revision 0013 |
| 3 | R12 — Mobile drill 4 cấp lost user | Phase 00 wireframe; breadcrumb sticky; "back to summary" shortcut tested w/ 3 host pilot |

---

## Test Strategy Summary

- **Unit (Phase 02 + 09):** `analytics_service` gross/net + prorate cross-month/year/leap-year, refund > invoice (422), voided invoice immutability; `excel_exporter_tt200` per-sheet generation, sha256 stability.
- **Integration (Phase 03 + 09):** endpoint contract tests (Pydantic schema round-trip); IDOR coverage (host A cannot read host B sources/data); auth gate on every endpoint.
- **E2E (Phase 11):** Flutter widget tests for new screens (KPI cards, heatmap virtualization, drill navigation, source CRUD); integration test full flow (login → analytics home → drill → export).
- **Performance (Phase 11):** KPI load <1.5s on Samsung A14 (4GB), heatmap 60fps with 30 rooms / 30fps degraded w/ 100, Excel 12 months <3s server-side.
- **Coverage target:** ≥80% for `analytics_service.py` + `excel_exporter_tt200.py`.

---

## Definition of Done

- All 11 phases status=completed.
- AC-01 … AC-18 each covered by at least one passing test (traceability matrix in Phase 11 report).
- Migration applied on staging, verified post-flight queries pass.
- TT200 accountant pilot sign-off documented.
- Perf benchmark report shows all targets met.
- Code reviewed by `code-reviewer`, security reviewed by `security-reviewer` (IDOR, PII, audit log).
- Docs synced (`./docs/system-architecture.md`, `./docs/code-standards.md` if new patterns introduced).
- All tests passing on CI.
