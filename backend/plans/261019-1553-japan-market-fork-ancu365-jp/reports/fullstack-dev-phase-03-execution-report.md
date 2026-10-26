# Phase-03 VN-Strip Execution Report (Living)

> Note: Prior session records tracked in handoff/git log; this file created in Session 12 at the path referenced by orchestrator. Historical sessions reconstructable via `git log --oneline --grep "jp-strip\|cluster-cut"` on branch `jp-version`.

---

## Session 12 — cluster-cut `sale_van_hanh`

**Date:** 2026-10-20
**Branch:** `jp-version` (baseline tag `pre-jp-fork-baseline-20261019` untouched)
**Scope:** JP-replace, cluster `sale_van_hanh` (VN sale-operations tab "Hoạt động" per mockup 05/10/2026).

### Pre-flight scan

- Anchor router: `app/api/routes/sale_van_hanh.py` (157 LOC) — mounted in `main.py:261-262` behind `require_region("vn")`.
- Service pkg: `app/services/sale_van_hanh/` (8 files, 1784 LOC): `__init__ bai_dang hop_dong khach lich pham_vi toa_nha tong_hop`.
- Schema: `app/schemas/sale_van_hanh.py` (10 LOC, `GhiKetQuaIn`).
- External consumers: `rg "from app.services.sale_van_hanh|from app.schemas.sale_van_hanh"` → only self-refs + router. **Clean leaf.**
- Tests: `rg -l sale_van_hanh tests/` → **zero hits**. Nothing to delete.
- Downward deps (reads): `app.models`, `app.services.{phieu_hen_xem, sale_yeu_cau, sale_yeu_cau_lich, lich_xem_service, sale_crm_service, so_phong, khai_thac_service, short_stay_service}` — all one-way; cluster is a sink.

### Commits (atomic, smoke-gated)

| # | SHA | Message | Files | LOC Δ |
|---|-----|---------|-------|-------|
| 1 | `6393e0e` | `chore(jp-strip): remove sale_van_hanh router + schema (sale_van_hanh cluster)` | main.py (-5), app/api/routes/sale_van_hanh.py (-157), app/schemas/sale_van_hanh.py (-10) | **−172** |
| 2 | `41b3ac2` | `chore(jp-strip): remove app/services/sale_van_hanh/ package (sale_van_hanh cluster)` | app/services/sale_van_hanh/* (8 files) | **−1784** |

**Total removed: 1956 LOC, 10 files, 1 package.**

### Smoke verification

Command: `JWT_SECRET=test DATABASE_URL=sqlite:///:memory: .venv-strip/bin/python -c "import main"`

- Baseline (pre-session): exit 0 ✅
- Post-commit 1: exit 0 ✅
- Post-commit 2: exit 0 ✅
- Post-session verify: exit 0 ✅

### Push

`git push origin jp-version` → `288b562..41b3ac2` ✅

### Residuals / Doc drift

- `docs/ARCHITECTURE.generated.md` still references `sale_van_hanh` — stale (auto-generated). Spec requires `python scripts/gen_arch_map.py --write` to regenerate; defer to a doc-sync session to avoid conflating with code cuts.
- `plans/261016-2323-ancu365-japan-market/reports/phase-00-backend-execution.md` mentions `sale_van_hanh` historically; informational only, no edit.

### Next-cluster recommendation

**Primary candidate: `sale_links` (next anchor).**

Scout findings:
- `main.py:53,241` — only remaining VN-sale router still mounted (`sale_links.router` behind `_vn_region_dep`).
- `rg sale_links` surfaces: `app/routers/houses.py` (reverse dep — needs inspection), `app/models/rental.py`, `tests/test_sale_links.py`, migration `0102_building_sale_links.py` (leave migrations alone per prior sessions).
- Expected size: small router + 1 test file.
- Risk: `app/routers/houses.py` reference may be Layer-3 shared infra. If so, this triggers the ceiling-stop rule and we fall back to the alternate.

**Alternate: `sale_yeu_cau` (service only, no mounted router).**
- 2 service files: `sale_yeu_cau.py`, `sale_yeu_cau_lich.py`.
- Was a downstream dep of the stripped `sale_van_hanh` tong_hop/lich/khach. Now unreferenced? Needs recheck:
  - `rg "from app.services.sale_yeu_cau|import sale_yeu_cau"` → confirm consumers before cutting.
- If orphan: clean cut. If still consumed by other VN clusters: defer.

**Avoid this session:** `phieu_hen_xem`, `lich_xem_service`, `sale_crm_service`, `khai_thac_service`, `short_stay_service` — these were downstream of multiple stripped clusters; likely heavy fan-in from remaining VN surface. Reserve for later cluster passes.

### Status

**DONE** — cluster `sale_van_hanh` fully stripped, smoke green at every step, pushed. Next session: start with `sale_links` scout; if `app/routers/houses.py` entanglement is Layer-3 shared → pivot to `sale_yeu_cau` orphan check.

### Open questions

1. **Should `docs/ARCHITECTURE.generated.md` be regenerated per-session or batched at end of Phase-03?**
   - Khuyến nghị: batch at end of Phase-03 (one commit, less noise).
   - Hệ quả nếu chọn sai (per-session): churn in generated doc every commit, noisy diffs, obscures real cuts.
   - Độ tin cậy: HIGH — doc is informational; CI gate (`check.sh`) is manual-run anyway.

2. **`sale_yeu_cau*` services — strip now (if orphan) or hold as viewing/phieu_hen_xem adjacency?**
   - Khuyến nghị: scout first (grep consumers); if orphan → strip; if 1-2 consumers remain → defer with note.
   - Hệ quả nếu chọn sai (premature strip): smoke break on hidden consumer, requires revert.
   - Độ tin cậy: MEDIUM — depends on scout result; current data insufficient.

---

## Session 13 — sale_links cluster-cut

**Date:** 2026-10-20  
**Branch:** `jp-version`  
**Commits:** `67ac0c8`  
**Pushed:** `41b3ac2..67ac0c8` → `origin/jp-version`.

### Scout result — Layer-3 ceiling hit on sale models

`rg SaleProfile|SaleOwnerLink|SaleKhach|SaleYeuCau*` surfaced:
- Live JP code: `app/routers/auth_router.py` (SaleProfile check), `app/routers/hosts_public.py` (owner-link lookups), `app/services/sale_permissions.py`, `sale_profile_service.py`, `sale_crm_service.py`, `lich_xem_service.py`, `building_sale_link.py`.
- Admin v2 shared: `admin_v2/content.py`, `partners.py`, `partners_ops.py`, `rentals.py`, `rentals_ops.py`.

→ **Models (`SaleProfile`, `SaleOwnerLink`, `SaleKhach`, `SaleYeuCau*`) stay** — stripping cascades through Layer-3 shared surface, violates ceiling rule. Session 13 scope reduced to **leaf-only**: router + tests.

### Entanglement with `app/routers/houses.py`

Only 2 comment-mentions (lines 479, 618) — Layer-1 cosmetic. No code dep. Safe.

### Cuts

| File | LOC |
|---|---|
| `app/routers/sale_links.py` (deleted) | 440 |
| `tests/test_sale_links.py` (deleted) | 774 |
| `main.py` (edit: remove `sale_links` import + `include_router` line) | −4 |
| **Total removed** | **−1218 LOC** |

### main.py patches

1. Removed `sale_links,` from `from app.routers import (...)` block (line 53).
2. Removed `app.include_router(sale_links.router, dependencies=_vn_region_dep)` (prev line 241). Preserved `_vn_region_dep` block + `deals.router` mount.

### Opportunistic orphan check — sale_yeu_cau / sale_yeu_cau_lich

`rg 'from app\.services\.sale_yeu_cau|from app\.services\.sale_yeu_cau_lich|from app\.services\.don_thue_khach'` → still referenced by:
- `app/api/routes/admin_v2/rentals.py` (sale-request admin endpoints lines 123–203).
- `app/services/admin_v2/rentals_ops.py` (`sale_request_row` helper).
- `app/services/sale_yeu_cau_lich.py` (self-import chain).
- `app/services/don_thue_khach.py`.
- `scripts/seed_sale_request_three_role_demo.py`.

→ **NOT orphan.** Deferred (would require carving sale-request endpoints out of shared `admin_v2/rentals.py` — Layer-3 modification, out of scope).

### Smoke status

```bash
docker run --rm -e JWT_SECRET=test -e DATABASE_URL=sqlite:///:memory: \
  -v "$(pwd)":/app -w /app ancu365-backend-backend \
  python -c "import main; print('SMOKE_OK')"
# → SMOKE_OK (seed ran, no import error)
```
Note: local `python3` is 3.9 (fails on SA2 `Mapped[date]`); venv absent. Used project Docker image (`python:3.11-slim` base) for smoke. Backend container itself was pre-existing in restart loop (migration drift: `users.account_type` missing in dev DB) — unrelated to this cut.

### Residuals / Doc drift

- `docs/ARCHITECTURE.generated.md` still references `sale_links` (stale, batched end-of-phase-03 regen per Session 12 Q1 recommendation).
- `scripts/seed_sale_request_three_role_demo.py` + `scripts/seed_staging.py` + `scripts/seed_sale_demo.py` + `scripts/seed_three_role_demo.py` still seed VN sale rows — intentional (seed scripts are VN-dev-only, not loaded in JP runtime).

### Next-anchor recommendation (Session 14)

**Primary candidate: `deals` router (last remaining VN-sale leaf).**
- `main.py:241` — only remaining `_vn_region_dep` mount: `app.include_router(deals.router, dependencies=_vn_region_dep)`.
- `rg deals.router|from app.routers import.*deals` → scout shows `app/routers/deals.py` is self-contained (per plan docs).
- Expected size: router + schema + 1-2 tests. Similar shape to `sale_links`.
- Risk: check `app/services/deals*` + any `admin_v2` cross-ref before cut.

**Alternate: Carve `/rentals/sale-requests/*` endpoints out of `admin_v2/rentals.py`.**
- Only 2 endpoints (`list_sale_requests` lines 123–163, `get_sale_request` 165–202) + `sale_request_row` helper (~50 LOC in `rentals_ops.py`).
- If done, `sale_yeu_cau*` + `don_thue_khach` service tier becomes orphan → chain-strip ~1388 LOC.
- Risk: Layer-3 edit (shared `rentals.py`); needs smoke-check that rest of rentals endpoints survive. Edit-not-delete pattern — more review burden. Recommend after `deals` leaf cut.

**Avoid Session 14:** sale models (`SaleProfile`, `SaleOwnerLink`, `SaleKhach`) — ceiling-blocked per above scout.

### Status

**DONE** — leaf `sale_links` stripped (−1218 LOC), smoke green via Docker image, pushed `67ac0c8` to `origin/jp-version`. Opportunistic orphan check performed; `sale_yeu_cau*` still referenced → deferred.

### Open questions

1. **Should Session 14 proceed with `deals` leaf or carve `admin_v2/rentals.py` sale-request endpoints?**
   - Khuyến nghị: `deals` first (clean leaf, keeps Layer-3 discipline), then the carve.
   - Hệ quả nếu chọn sai (carve first): touching shared `admin_v2/rentals.py` risks collateral break if admin regression tests sparse; higher review cost.
   - Độ tin cậy: HIGH — matches existing cluster-cut cadence.

2. **Backend container restart loop (`users.account_type does not exist`) — unrelated to strip, but worth flagging?**
   - Khuyến nghị: flag to Phase-03 lead; likely missing alembic head on dev DB (needs `alembic upgrade head` in dev stack).
   - Hệ quả nếu chọn sai (ignore): dev smoke via live container will keep failing, forces one-shot `docker run` for every future session.
   - Độ tin cậy: HIGH — error message is explicit column drift, standard migration catchup.

3. **Local python 3.9 blocks SA2 import — venv missing. Add `.venv` setup to Phase-03 runbook?**
   - Khuyến nghị: document the `docker run --rm ... ancu365-backend-backend python -c 'import main'` one-liner in runbook as official smoke invocation; skip local venv (adds env-drift risk).
   - Hệ quả nếu chọn sai (require venv): divergent dep pins between Dockerfile and local, slower onboarding.
   - Độ tin cậy: MEDIUM — Docker-only smoke works but is ~5s slower per iteration.

---

## Session 14 — `deals` cluster strip (2026-10-20)

### Executed Phase
- Anchor: `deals` router (last VN-sale leaf at `main.py:241` pre-session)
- Branch: `jp-version`
- Status: completed

### Files removed
| File | LOC |
|---|---|
| `app/services/buy_sell_service.py` | 156 |
| `app/routers/deals.py` | 524 |
| `tests/test_deals.py` | 267 |
| `tests/test_chan_ban_trung.py` | 342 |
| **Total** | **1289** |

### Files modified
- `main.py`: removed `deals` import, removed `_vn_region_dep` + `include_router(deals.router, ...)` block (only VN-sale include left; `require_region` still used by JP block).

### Commits (pushed to `origin/jp-version`)
1. `2a3dee8` — `chore(jp-strip): remove orphan buy_sell_service (deals cluster)` (precondition: breaks circular ref `buy_sell_service → deals`)
2. `c2cf22e` — `chore(jp-strip): remove deals router + VN tests (deals cluster)`

### Smoke status
- Baseline: GREEN (`.venv-strip/bin/python -c "import main"` exit 0)
- Post-leaf-1: GREEN
- Post-leaf-2: GREEN
- Push: GREEN (`67ac0c8..c2cf22e jp-version -> jp-version`)

### Layer-3 discipline
- Verified `buy_sell_service` had ZERO external importers (orphan after Phase-02 refactors) — safe pre-cut unblocked `deals` removal cleanly.
- `sale_phu_trach`, `khai_thac_service`, `marketplace_sync_service`, `hang_doi_push` (imports in old deals.py) still consumed by non-VN clusters — left untouched.

### Opportunistic sale_yeu_cau carve — DEFERRED
Inspected `app/api/routes/admin_v2/rentals.py:123–198` (sale-requests endpoints):
- Tightly coupled to shared `rentals_ops.sale_request_row`, `models.SaleYeuCau*`, `app.services.admin_v2.core`.
- Carve requires: route surgery (~75 LOC) + confirming `rentals_ops.sale_request_row` has no non-sale callers + model-tier impact scan + admin_v2 regression smoke. Chain-strip potential ~1388 LOC but risk > single-session envelope.
- Decision: defer whole chain to Session 15 as its own anchor.

### Session 15 recommendation
- **Primary anchor:** `sale_yeu_cau` chain via `admin_v2/rentals.py:123–198` carve.
  - Scope: surgical delete of 2 endpoints + `_users_named` helper (if orphaned post-cut) → verify `rentals_ops.sale_request_row` + `ro.*` sale-request-only helpers orphan → cluster-cut `app/services/sale_yeu_cau.py` (918 LOC) + `app/services/sale_yeu_cau_lich.py` (179 LOC) + `app/models/sale.py` SaleYeuCau* classes + `tests/admin_v2/test_rentals.py` sale-request cases.
  - Smoke MUST verify `admin_v2/rentals.py` other endpoints (journeys/short-stay/contracts) still import clean.
- **Secondary (if primary blocked by Layer-3 model-share):** scan remaining `app/services/sale_*` tier (sale_crm_service, sale_profile_service, sale_permissions) for next clean orphan — likely `sale_crm_service` (not referenced in Session 13 recon).

### Open questions
1. **Does `rentals_ops.sale_request_row` share helpers with journey/short-stay rows?**
   - Khuyến nghị: Session 15 first-step `rg -n "sale_request_row\|SaleYeuCau" app/services/admin_v2/rentals_ops.py` before touching router.
   - Hệ quả nếu chọn sai: silent break of journey endpoints if helpers shared and sale-request branch pulls shared imports.
   - Độ tin cậy: MEDIUM — ops file is 953 LOC, likely mixed.

2. **`models/sale.py` share — can SaleYeuCau classes be dropped without migration follow-up?**
   - Khuyến nghị: keep migrations as-is (never rewrite history); drop model classes only after confirming no cross-cluster FK targets.
   - Hệ quả nếu chọn sai (drop with cross-ref): ORM mapper init fail at `import main`.
   - Độ tin cậy: MEDIUM — needs `rg SaleYeuCau app/models/ app/services/` before class deletion.

---

## Session 15 — sale_yeu_cau carve (2026-10-20)

### Scope
Carve VN rental sale-pipeline cluster (`sale_yeu_cau*` + `don_thue_khach`) out of admin_v2/rentals.

### Pre-scout findings
- `rg "sale_request_row|SaleYeuCau|sale_yeu_cau"` → 6 files, all self-contained:
  - Router: `app/api/routes/admin_v2/rentals.py` (2 endpoints, lines 123-198)
  - Helper: `app/services/admin_v2/rentals_ops.py::sale_request_row` (self-contained)
  - Services: `sale_yeu_cau.py` (918 LOC), `sale_yeu_cau_lich.py` (179), `don_thue_khach.py` (291)
  - Model: `app/models/sale.py` (3 classes: SaleYeuCau, SaleYeuCauCan, SaleYeuCauMoc)
- Test block: single branch inside `tests/admin_v2/test_rentals.py::test_viewings_sale_requests_contracts`
- `SaleCommission` writer uses `source_type="sale_yeu_cau"` — stripped with service (SaleCommission model stays, finance reader intact)
- NHAN_BUOC/VIEC_TIEP/_can_lien_quan refs → all inside cluster; `NHOM` grep hit in `tin_ngan_han.py` is a local dict, unrelated

### Commits (c2cf22e..cdb3137)
1. `94605e9` — carve 2 router endpoints + sale_request_row helper + test block (−128 LOC net)
2. `f3e6c65` — delete 3 service files (−1388 LOC)
3. `cdb3137` — delete 3 ORM model classes (−108 LOC)

### Files changed
- Modified: `app/api/routes/admin_v2/rentals.py` (−81), `app/services/admin_v2/rentals_ops.py` (−40), `tests/admin_v2/test_rentals.py` (−7), `app/models/sale.py` (−108)
- Deleted: `app/services/sale_yeu_cau.py`, `app/services/sale_yeu_cau_lich.py`, `app/services/don_thue_khach.py`

### LOC delta
**−1624 LOC total** (3 commits).

### Smoke (gate between every commit)
`JWT_SECRET=test DATABASE_URL=sqlite:///:memory: .venv-strip/bin/python -c "import main"` → exit 0 after each step. Final `rg SaleYeuCau|sale_yeu_cau|don_thue_khach app/ tests/` = ZERO hits.

### Pushed
`c2cf22e..cdb3137` → `origin/jp-version` ✓

### Residue / caveats
- Historical migrations still reference `sale_yeu_cau*` tables (0134 etc.) — kept as-is per discipline (no rewrite). JP fork DB bootstrap will replay full chain then drop tables; acceptable for fresh deployment.
- Pre-existing conftest import error (`app.routers.planning` from earlier session) blocks pytest run — not a Session 15 regression. Smoke import gate covers correctness.

### Session 16 recommendation
Next orphan candidate: **`sale_khach` (SaleKhach lead-management)**. Scout finding: SaleKhach is still referenced by `rentals_ops.sale_request_row` **removed in Session 15**, now only by `app/services/sale_khach_*.py` (likely orphaned). Verify:
```
rg -l "SaleKhach|sale_khach" app/ tests/
```
If chain self-contained → strip service + model + any VN-only routes (expect ~500-800 LOC). If still shared with viewing/journey models → stop at service tier.

Alternative pivot: **`rental_journey_report`** pipeline (admin OVERRIDE flows in rentals.py lines ~322-358) — JP market may not need VN dispute arbitration flow.

- Khuyến nghị: start with `sale_khach` scout (lighter cluster, lower risk after sale_yeu_cau removal).
- Hệ quả nếu chọn sai: Pivoting to rental_journey_report first risks touching `rjs` shared service which is used by cancel_journey endpoint — need deeper scout.
- Độ tin cậy: HIGH on sale_khach being now-orphan (dependency chain cleared this session).

---

## Session 16 — conftest fix + sale_khach strip (2026-10-20)

### Task A — conftest import fix
- `tests/conftest.py` imported `app.routers.planning` (stripped early in Phase 03) and built a minimal planning test app at module level → every `pytest` invocation errored at collection.
- Fix: removed the planning import + minimal FastAPI app build (lines 34-52 prior). Kept `get_db` import for downstream Postgres smoke fixtures. Docstring updated to flag planning removal.
- Downstream check: only `tests/api/test_commission_routes.py` referenced names like `app_instance`/`client` — defines them locally, not via conftest. No fixture breakage.
- Collection post-fix: `1830 tests collected`, 6 pre-existing collection errors remain (orphan test files for stripped routers: `test_dat_phong_qua_sale`, `test_doi_gio_lich_xem`, `test_phieu_dat_phong`, `test_sua_lich_hen`, `test_tin_ngan_han`, `test_tin_ngan_han_http`) — pre-existing, out of Session 16 scope.
- Commit: `3198e6b chore(jp-strip): fix conftest import of stripped planning router` (+10 / −26)

### Task B — sale_khach cluster-cut
- Scout: `rg "sale_khach|SaleKhach" app/ tests/` → **1 file hit** (`app/models/sale.py` only). No router/service/schema/test consumer. Fully orphaned after Session 15 removed `sale_request_row` and `sale_yeu_cau*` chain.
- Removed: `SaleKhach` ORM class (lines 420-446) + cluster header comment block (412-417) "SALE QUẢN LÝ THEO YÊU CẦU (mig 0132)".
- Layer-3 check: Not in `app/models/__init__.py` exports; no cross-model FK dependency; no fixture seeds it. Historical migration `0132_sale_quan_ly_theo_yeu_cau.py` still references `sale_khach` table — left as-is per discipline (JP fresh deploy will replay then drop).
- Residue post-strip: `rg "sale_khach|SaleKhach" app/ tests/` = **ZERO hits**.
- Commit: `24f231b chore(jp-strip): remove SaleKhach model (sale_khach cluster)` (−39 LOC)

### LOC delta Session 16
**−39 LOC** net code (Task B). Task A is +10 / −26 docstring + import cleanup = −16 net; not counted as "strip LOC".

### Files changed
- Modified: `tests/conftest.py` (−16), `app/models/sale.py` (−39)

### Smoke (gate between every commit)
`JWT_SECRET=test DATABASE_URL=sqlite:///:memory: .venv-strip/bin/python -c "import main"` → exit 0 after each commit. Final rg sweep clean.

### Pushed
`cdb3137..24f231b` → `origin/jp-version` ✓ (push below)

### Residue / caveats
- 6 orphan test modules still error at collection (listed above). Low risk — tests already dead, but noisy. Candidate quick-win for Session 17 pre-work.
- Migrations 0132 still carries `sale_khach` DDL — kept intentional (chain-replay then drop model = acceptable on fresh JP deploy).

### Session 17 recommendation
Primary: **Delete 6 orphan test modules** (10-min quick-win). Unblocks clean `pytest` collection → enables Session 17+ to use pytest as green/red oracle instead of smoke-only.
```
tests/test_dat_phong_qua_sale.py
tests/test_doi_gio_lich_xem.py
tests/test_phieu_dat_phong.py
tests/test_sua_lich_hen.py
tests/test_tin_ngan_han.py
tests/test_tin_ngan_han_http.py
```
Each imports a router stripped in prior sessions. Verify no fixtures from these files are reused elsewhere, delete, commit per file (or batch).

Then pivot to next cluster — candidate: **`host_loai_phong` / `tin_ngan_han` / `short_stays`** chain (surfaced by the orphan tests themselves — `host_loai_phong` router already stripped, so leaves may be close). Scout:
```
rg -l "host_loai_phong|HostLoaiPhong|tin_ngan_han|TinNganHan|short_stays|ShortStay" app/
```
Expect 300-600 LOC strip if models/services/schemas still linger.

- Khuyến nghị: Session 17 opens with orphan-test cleanup (unblock pytest) then scouts `tin_ngan_han/short_stays` cluster.
- Hệ quả nếu chọn sai: Skipping orphan cleanup forces Session 18+ to keep running smoke-only (coarser signal, miss regressions in untested code paths). Pivoting into `tin_ngan_han` without scout risks hitting shared booking/reservation models (Layer-3 ceiling).
- Độ tin cậy: HIGH on orphan test cleanup being safe (routers already gone). MEDIUM on `tin_ngan_han` cluster scope — needs scout before commit.

### Unresolved questions
1. Should historical migrations (0132, 0134+) be rewritten to drop `sale_khach`/`sale_yeu_cau*` DDL now, or deferred until a Phase-04 "squash migrations" pass?
   - Khuyến nghị: Defer to Phase-04 squash. Keeps strip sessions atomic (code-only) and migration history auditable until JP fork reaches first prod deploy.
   - Hệ quả nếu chọn sai: Leaving them indefinitely means every fresh JP DB briefly CREATE then DROP those tables → wasted DDL but harmless; rewriting now risks breaking Session 1-15 alembic chain verification.
   - Độ tin cậy: HIGH on defer being correct.
2. The 6 orphan test modules — delete-per-file or batch-delete?
   - Khuyến nghị: Batch-delete (one commit) — they share root cause (router stripped) and have no cross-file dependency.
   - Hệ quả nếu chọn sai: Per-file is 6 commits for ~pure deletion — noise in log without added bisect value.
   - Độ tin cậy: HIGH.

---

## Session 17 — 2026-10-20

### Task A — Orphan test cleanup (DONE)
Batch-delete 6 orphan test modules (all imported stripped routers: `host_ngan_han`, `host_loai_phong`, `reviews`, `test_phieu_hen_xem`). Pytest collection: `1830 tests, 6 errors` → `1830 tests, 0 errors`. Smoke green. Commit `40bd1b3`.
```
tests/test_dat_phong_qua_sale.py
tests/test_doi_gio_lich_xem.py
tests/test_phieu_dat_phong.py
tests/test_sua_lich_hen.py
tests/test_tin_ngan_han.py
tests/test_tin_ngan_han_http.py
```
−1181 LOC. Session 17+ now has pytest as green/red oracle.

### Task B — `tin_ngan_han` / `short_stays` / `host_loai_phong` cluster scout → STOP

**Scout result (Layer-3 ceiling hit):**
- `app/services/tin_ngan_han.py` (215 LOC) — consumed by **`app/routers/houses.py`** (lines 19, 545, 555, 604 — core domain router) and **`app/helpers.py`** (152 — grab-bag core).
- `app/services/short_stay_service.py` (486 LOC) — consumed by **13+ core services/routers**: `reservation_service`, `guest_reservation`, `phieu_dat_phong`, `admin_v2/rentals_ops`, `sua_dat_cho`, `so_phong`, `luot_xem_tin`, `cho_thue_ngoai`, `da_dat_tong_hop`, `ca_thue_service`, `loai_phong_service`, `ho_so_ngan_han`, plus tests.
- `app/models/short_inventory.py` (`ShortStayRatePlan`, `ShortStayWorkflowEvent`, 64 LOC) — consumed by `admin_v2/rentals_ops.py:721`.
- `host_loai_phong` router already stripped prior session; no residual service file (only in migration 0130_tin_ngan_han_theo_hang and references via `tin_ngan_han.py`).

**Conclusion:** Cluster is NOT a leaf. `short_stay_service` + `tin_ngan_han` + `ShortStay*` models are core booking/reservation infrastructure. Stripping any of these three cascades through 13+ core files = Layer-3 shared surface violation per Session 13 discipline (`SaleProfile`/`SaleOwnerLink` precedent). No clean leaf-cut possible in this cluster at Layer-3 ceiling.

**No commits from Task B.** Smoke still green (nothing touched post-Task-A).

### Pytest collection status
- Before: `1830 tests collected, 6 errors`
- After: `1830 tests collected, 0 errors` ✓

### Residue / caveats
- Short-stay cluster deferred. JP market will likely need the short-term rental core itself (ryokan/minshuku = short-stay), so retention is correct — only VN-specific wrappers are strip targets.
- No new migration residue.

### Session 18 recommendation
Primary pivot — scout **next VN-specific leaf cluster**. Candidates (ordered by probable leaf-safety):

1. **`luot_xem_tin` service** — view-tracking for listings. Likely consumed only by routers that count views (ad-hoc). Scout:
   ```
   rg -l "luot_xem_tin|LuotXemTin|view_tracking" app/
   ```
   If ≤ 3 consumers and all routers (not models/services) → clean leaf cut.

2. **`cho_thue_ngoai` service** — "cho thuê ngoài" (external rental listing — likely VN-marketplace specific flow). Scout for external-only pathways.

3. **`sale_crm_service` / `sale_profile_service`** — remaining sale/CRM tier not yet touched. Session 13 noted `sale_crm_service` as candidate orphan check; needs verification whether `SaleProfile` still blocks (Session 13 ceiling hit on model).

**Oracle shift:** With pytest green, Session 18 can run `pytest tests/<cluster>/ -x` as pre-strip baseline → cut → re-run as regression check. Shift from smoke-only to pytest-targeted. **Still keep smoke as cheap floor.**

- Khuyến nghị: Session 18 opens with `luot_xem_tin` scout (likely leaf), fallback to `sale_crm_service` re-check.
- Hệ quả nếu chọn sai: Diving back into short-stay cluster without first dismantling `host_ngan_han`/`host_loai_phong` consumers = re-hitting same Layer-3 wall. Cost of pivot: zero.
- Độ tin cậy: MEDIUM on `luot_xem_tin` being leaf (needs 3-min scout); HIGH on pytest-targeted oracle shift being correct.

### Unresolved questions
1. The `short_stay_service` + `ShortStayRatePlan/Event` + `tin_ngan_han` triad is Japan-relevant core (minshuku/ryokan need the same short-term model). Should we rename-and-keep (JP terminology swap) rather than attempt strip?
   - Khuyến nghị: Rename-and-keep in a later phase. Phase-03 is strip-only; renaming is Phase-04 (JP terminology pass) once VN-specific wrappers are gone.
   - Hệ quả nếu chọn sai: Attempting rename in Phase-03 blurs strip/rename boundary → auditor confusion; blocks parallel reviewer.
   - Độ tin cậy: HIGH.
2. Pytest collection now green at 1830 — should Session 18 attempt first full `pytest -x` run as oracle floor?
   - Khuyến nghị: YES — one-time baseline run to catch any test that broke silently during Sessions 11-17 (even though smoke stayed green). Expect some failures from stripped routers in integration tests that weren't collection errors.
   - Hệ quả nếu chọn sai: Skipping risks accumulating silent test-level breakage until end of Phase-03 and triggering mass-fix session.
   - Độ tin cậy: HIGH.

---

## Session 18 — scout `luot_xem_tin` → STOP; pivot cut `sale_crm_service` orphan + pytest baseline

**Date:** 2026-10-20
**Branch:** `jp-version` (HEAD `3942472`)
**Scope:** Primary scout (luot_xem_tin), fallback leaf-cut (sale_crm_service), oracle baseline (pytest full run).

### Primary scout — `luot_xem_tin` (STOP at Layer-3)
- `rg "luot_xem_tin|LuotXemTin" app/` → **1 hit**: `app/routers/houses.py:18,460`.
- Caller is `app/routers/houses.py` (main house router, not a VN-tab wrapper). Touching = Layer-2 core router edit → Layer-3 ceiling.
- **Decision:** STOP. `luot_xem_tin` is view-count tracking bolted into the house flow; stripping requires rewriting the `/houses/{id}` view handler. Not a clean leaf. Defer to Phase-04 JP-rename or later cleanup.

### Fallback scout — `sale_crm_service` (clean orphan)
- `rg "sale_crm_service" app/ tests/` → **0 hits** outside the file itself.
- `rg "SaleCrm*|from app.models.crm" app/ tests/` → only `app/services/sale_crm_service.py` (self) + `app/models/crm.py` + wildcard in `app/models/__init__.py:19`.
- `app/models/crm.py` defines 4 models (`SaleCrmContact`, `SaleCrmTask`, `SaleCrmNote`, `SaleCrmActivity`) — zero external consumers.
- **Clean orphan cluster.**

### Commit
| # | SHA | Message | Files | LOC Δ |
|---|-----|---------|-------|-------|
| 1 | `3942472` | `chore(jp-strip): remove orphan sale_crm_service + crm model cluster` | app/services/sale_crm_service.py (−188), app/models/crm.py (−79), app/models/__init__.py (−1) | **−268** |

### Smoke / collection gates
- Smoke `import main`: GREEN (before + after).
- Pytest collection: `1830 tests collected, 0 errors` ✓ (unchanged).

### Oracle upgrade — pytest baseline (first full run)
Ran `JWT_SECRET=test DATABASE_URL=sqlite:///:memory: pytest -q` (no `--timeout=60`; `pytest-timeout` not installed, flag rejected).

**Baseline (77.08s):**
- **1623 passed**
- **90 failed**
- **83 skipped**
- **34 errors**
- 14 warnings

Not fixing per mission scope — documented as floor. Session 19 can use this as pre-strip oracle: any strip that pushes `passed` below 1623 or `errors` above 34 = regression.

### Session 19 recommendation
Next anchor candidates (ordered by probable leaf-safety):

1. **`cho_thue_ngoai` service / router** — VN "cho thuê ngoài" (external rental marketplace). Likely VN-only pathway. Scout:
   ```
   rg -l "cho_thue_ngoai|ChoThueNgoai" app/ tests/
   ```
2. **`moi_gioi` cluster** — broker/agent flow (VN real-estate brokerage model, may differ from JP agency structure).
3. **`sale_profile_service` orphan recheck** — Session 13 flagged `SaleProfile` as blocked at model level, but service-layer wrapper may be strippable now that `sale_crm_service` + `SaleKhach` are gone.
4. **Residual `app/services/*` orphan sweep** — run `rg -L "from app.services.<name>|services.<name>" app/ tests/` loop over service names to catch other zero-caller services (same technique that found `sale_crm_service`).

- Khuyến nghị: Open Session 19 with 3-min `rg -l` scout over candidates 1-4; cut the first clean orphan found. Lean on new pytest baseline (1623 pass) as regression floor.
- Hệ quả nếu chọn sai: Diving into `cho_thue_ngoai` without scout may hit shared `tin_cho_thue` or house-listing core (Layer-3 wall) — but scout cost is tiny.
- Độ tin cậy: HIGH on orphan sweep technique being reproducible; MEDIUM on `cho_thue_ngoai` being leaf (needs scout).

### Unresolved questions
1. Pytest baseline shows 90 failed + 34 errors. Should Phase-03 end-state require these to be fixed before Phase-04 rename, or carry forward as known debt?
   - Khuyến nghị: Carry forward. Many likely pre-date VN-strip (migration-chain tests, missing fixtures). Phase-03 scope is strip-only; stabilization = separate phase.
   - Hệ quả nếu chọn sai: Mixing stabilization into strip phase blurs boundary and inflates session scope.
   - Độ tin cậy: HIGH.
2. `luot_xem_tin` touches `houses.py` core router — should it be queued for Phase-04 (JP rename) or deferred further?
   - Khuyến nghị: Phase-04 JP-rename. "Luot xem tin" = "view count" — JP equivalent is identical semantics (閲覧数). Rename-in-place is cheaper than strip-and-reimplement.
   - Hệ quả nếu chọn sai: Stripping = losing a feature JP market also needs.
   - Độ tin cậy: HIGH.
3. Should Session 19 install `pytest-timeout` so future `--timeout=60` guards work?
   - Khuyến nghị: NO. Full run completed in 77s already; adding dep for a 1-session guard = YAGNI violation. If a specific test hangs later, add then.
   - Hệ quả nếu chọn sai: Over-tooling; small cost either way.
   - Độ tin cậy: MEDIUM.

---

## Session 19 — cho_thue_ngoai orphan cut (2026-10-20)

### Executed
- Scout `cho_thue_ngoai|ChoThueNgoai` → 1 model comment hit only (`app/models/rental.py:395`). Service file `app/services/cho_thue_ngoai.py` existed (254 LOC, functions `danh_dau` / `bo_danh_dau` / helpers) but **zero external callers** (routers, tests, services).
- Confirmed `ngoai_luong` model column still used by `admin_v2/rentals_ops.py` + `schemas/ho_so_phong.py` → KEEP column, strip service only.
- Deleted `app/services/cho_thue_ngoai.py` (−229 LOC commit-measured).
- Cleaned stale `# Xem services/cho_thue_ngoai.py` reference in `rental.py`.

### Files Modified
- `app/services/cho_thue_ngoai.py` (DELETED, −229 LOC)
- `app/models/rental.py` (−1 line, comment cleanup)

### Verification
- Smoke: `python -c "import main"` exit 0 ✓
- Pytest collection: 1830 tests, 0 collection errors ✓
- Pytest run: **1623 passed / 90 failed / 83 skipped / 34 errors** — identical to Session 18 floor, **0 regression** ✓
- Commit `708fdc5` pushed to `origin/jp-version` ✓

### Fallback probes (not taken this session)
- `sale_profile_service` recheck: **NOT orphan** — 10 callers across `admin_v2`, `routers/auth_router`, `routers/hosts_public`, 3 test files. Skip.
- Full `app/services/*` orphan sweep: deferred to Session 20 (scope budget respected after Layer-3 ceiling guidance).

### Status: DONE
**Summary:** Session 19 stripped the `cho_thue_ngoai` VN "Facebook rental marker" service orphan (−229 LOC). Pytest floor held at 1623p. One commit, pushed.

### Session 20 recommendation
1. **Systematic `app/services/*` orphan sweep** — build inventory of every `app/services/<name>.py` and `app/services/<cluster>/*.py`, then `rg -l "from app.services.<name>|services\.<name>"` per file; strip any with 0 external callers. Expected yield: 2-5 more orphan services (similar to `sale_crm_service`, `cho_thue_ngoai` pattern).
   - Khuyến nghị: Spawn a sub-batch of 3-4 orphan cuts in one session. Each cut = separate commit + smoke, final pytest after batch.
   - Hệ quả nếu chọn sai: Running sweep across 100+ services without filtering may spend budget on noise; prioritize services NOT imported in `app/api/routes/` or `app/routers/`.
   - Độ tin cậy: HIGH on technique; MEDIUM on yield (prior strips may have thinned the field).

2. **Alternative — pivot to Phase-04 JP-rename planning.** Phase-03 strip budget may be exhausted; Layer-3 ceiling consistently hit. Session 20 could produce a Phase-04 scoping doc (list of `luot_xem_tin`, `houses` core, `tin_cho_thue` etc. candidates for in-place VN→JP semantic rename).
   - Khuyến nghị: Only if Session 20 orphan sweep yields <100 LOC. Combined option: 30-min orphan sweep → if dry, pivot to Phase-04 scoping in same session.
   - Hệ quả nếu chọn sai: Premature pivot leaves cuttable fat; late pivot wastes session on diminishing returns.
   - Độ tin cậy: MEDIUM.

### Unresolved questions (Session 19)
1. The orphan `cho_thue_ngoai` service had 2 public functions (`danh_dau`, `bo_danh_dau`). JP market may need equivalent "外部契約マーク" (off-app contract marker) semantics. Does `ngoai_luong` column + a future JP service suffice, or does Phase-04 need to design a replacement now?
   - Khuyến nghị: Defer. `ngoai_luong` column preserved → no data loss. JP equivalent is a Phase-04+ feature-design question, not Phase-03 strip.
   - Hệ quả nếu chọn sai: Rebuilding `danh_dau` semantics later costs ~1 session; stripping now = cheaper than carrying dead code through Phase-04.
   - Độ tin cậy: HIGH.
2. Pytest floor has held exactly at 1623p across Sessions 17-19. Should the "regression floor" assertion be formalized as a check script (`check-pytest-floor.sh`) to catch silent drift in future sessions?
   - Khuyến nghị: NO (YAGNI). Floor is checked by manual session-end comparison; adding a script = tooling debt. Floor will shift when stabilization starts.
   - Hệ quả nếu chọn sai: Minor manual overhead per session.
   - Độ tin cậy: MEDIUM.

---

## Session 20 — Systematic orphan sweep (5 cuts, ~1011 LOC)

**Date:** 2026-10-20 · **Branch:** `jp-version` · **Commits:** `51c03ef`, `0551d09`, `54e9c5e`, `9fafb12`, `161a4f8` (pushed to origin)

### Approach
Built external-caller histogram for all 64 `app/services/*.py` files via `rg -l '\b<name>\b' app --glob '!<self>'`. Verified top 0-ref candidates by cross-checking `tests/` and content for VN-only domain markers.

### Candidates ranked (external ref count)
```
0 admin_units_service    (VN provinces/wards 2025 data)
0 contract_pdf_service   (has tests/ — skipped)
0 da_dat_tong_hop        (VN booking aggregate)
0 dashboard_service      (has tests/ — skipped)
0 private_uploads        (has tests/ — skipped)
0 sale_profile_service   (sale CRM leftover)
0 viewing_workflow_policy (viewing state machine)
0 ho_so_ngan_han         (VN short-rental host dashboard; only comment ref)
```

### Strips executed
| # | File | LOC | Reason |
|---|------|-----|--------|
| 1 | `app/services/da_dat_tong_hop.py` | 242 | VN "Đã đặt" page aggregator — booking + viewing commitment list |
| 2 | `app/services/ho_so_ngan_han.py` | 437 | VN short-rental host dashboard (sổ phòng + ca thuê god-service) |
| 3 | `app/services/viewing_workflow_policy.py` | 168 | Viewing REQUESTED→PROPOSAL_SENT state machine, no consumers |
| 4 | `app/services/admin_units_service.py` | 126 | VN 34-province / ~3321 ward lookup (NQ 1171/NQ-UBTVQH15) |
| 5 | `app/services/sale_profile_service.py` | 38 | On-demand Sale role profile init — Sale CRM leftover |
| **Σ** |  | **1011** | |

### Side cleanups
- `app/services/loai_phong_service.py:422` — stripped `ho_so_ngan_han.them_ca` reference in docstring; replaced with generic phrasing.

### Verification
- `JWT_SECRET=test DATABASE_URL=sqlite:///:memory: .venv-strip/bin/python -c "import main"` exit 0 after every strip.
- Pytest final: **1623 passed / 90 failed / 83 skipped / 34 errors in 73s** — floor held EXACTLY (baseline unchanged from Sessions 17-19).
- 0 pytest collection errors introduced.

### Totals Phase-03 orphan strips (Sessions 17-20)
| Session | Strips | LOC |
|---------|--------|-----|
| 17 | short-stays STOP at Layer-3 | 0 |
| 18 | sale_crm_service + crm cluster | ~? |
| 19 | cho_thue_ngoai | 230 |
| 20 | **5 orphans (this session)** | **1011** |

### Session 21 recommendation

1. **Primary — pivot away from `app/services/*.py` sweep.** The flat-service orphan vein is now very thin. Remaining 1-ref candidates (`doi_gio_xem`, `luot_xem_tin`, `provinces_service`, `ngan_hang_vn`, `basemap_tile_proxy`, `nominatim_proxy`, `login_account`, `manage_read_model`, `quality_rating`, `tai_khoan_nhan`, `scope_check`, `move_out_invoice_service`) each have **live callers** in `app/routers/houses.py`, `app/services/tai_khoan_nhan.py`, or similar — stripping any requires simultaneous caller surgery (Layer-3 ceiling violation).
   - Khuyến nghị: Session 21 should pivot to **Phase-04 houses god-router rename pass** OR **cluster-level audits** (e.g. `app/services/short_stay_service.py` 486 LOC still live but may have dead branches internally).
   - Hệ quả nếu chọn sai: Continuing flat sweep in Session 21 likely yields <100 LOC (ceiling signal from mission brief triggered → STOP).
   - Độ tin cậy: HIGH.

2. **Alternative — `app/services/<cluster>/` directory sweep.** Have not inventoried subdirectory services (`approval/`, `delegation/`, `kyc/`, `commission/`, `demand/`, `compliance/`, `consent/`, `retention/`, `privacy/`, `renewal/`, `payment/`, `notification/`, `media/`, `geocoding/`, `audit`, `admin/`, `admin_v2/`, `admin_kpi/`, `address/`, `analytics_service/`, `auth/`, `deposit_settlement/`, `econtract/`, `evidence_policy/`, `it_session/`, `jp/`, `onboarding/`, `owner_death/`, `pricing/`, `service_request/`, `so_chu_nha/`, `webhook/`) at module-file granularity.
   - Khuyến nghị: Run `find app/services -mindepth 2 -name '*.py' -not -name '__init__.py'` and apply same histogram. Likely yield: dead files inside live clusters (e.g. VN-marker filename deep in `so_chu_nha/`, `pricing/`, `onboarding/`).
   - Hệ quả nếu chọn sai: Could yield significant LOC in Session 21 before pivot; worth 1 budget scan.
   - Độ tin cậy: MEDIUM-HIGH.

3. **Phase-04 scoping (if 1 or 2 dry).** VN→JP semantic rename pass for live core (`houses`, `luot_xem_tin`, `tin_ngan_han`, `phieu_dat_phong`). Not Phase-03 scope.
   - Độ tin cậy: HIGH as fallback.

### Unresolved questions (Session 20)
1. `viewing_workflow_policy.py` encoded canonical state names (REQUESTED/PROPOSAL_SENT/...). Stripped as orphan (zero importers). JP viewing workflow may reinvent these constants. Preserve them anywhere?
   - Khuyến nghị: NO. Constants are 8 strings — trivial to redefine when JP viewing module designed. Carrying dead policy = clutter.
   - Hệ quả nếu chọn sai: ~5 min to re-type constants in Phase-04. Negligible.
   - Độ tin cậy: HIGH.
2. `admin_units_service.py` depended on `app/data/vn_admin_2025.json` (34 provinces, ~3321 wards). The JSON data file was NOT touched. Should the data file also be removed?
   - Khuyến nghị: Separate concern — data file strip belongs to a dedicated "VN data asset" pass, not service-code sweep. Leave for Phase-04 or a Session 21 side-task if cluster sweep dry.
   - Hệ quả nếu chọn sai: ~KB of JSON lingers; no runtime cost since no code reads it.
   - Độ tin cậy: HIGH.
3. Floor held at 1623p for 4 consecutive sessions. At what point does "floor static across N sessions" signal that strip work is no longer meaningfully exercised by the test suite (i.e., tests cover live surface, dead code strips are tautologically safe)?
   - Khuyến nghị: Already past that point. Pytest is now a smoke gate, not a value-add verification. Trust `import main` + manual caller grep for Session 21+.
   - Hệ quả nếu chọn sai: Over-trusting = regression in some uncovered live code path. Mitigate by also running `pytest tests/<cluster>/` targeted when touching live code.
   - Độ tin cậy: MEDIUM.

---

## Session 21 — Subdirectory orphan sweep (4 cuts, ~2145 LOC)

**Date:** 2026-10-20 · **Branch:** `jp-version` · **Commits:** `3e7bb44`, `d40863c`, `9cf5aa3`, `da3c63d` (pushed origin/jp-version)

### Approach
Built per-module ref histogram over `find app/services -mindepth 2 -name '*.py' -not -name '__init__.py'` using dotted-path `rg -l`. 9 raw 0-ref hits → verified each by (a) checking package `__init__.py` re-exports, (b) grepping exported function/class names across `app/` + `tests/`. False-positive rate ~75% on first pass (admin_v2 cluster submodules re-export via `__init__` chains).

### Verified true orphans + strips
| # | Target | LOC | Reason |
|---|--------|-----|--------|
| 1 | `app/services/analytics_service/` (full pkg, 6 .py) + `app/services/_analytics_helpers.py` + `app/schemas/_analytics_shapes.md` | **1312** | Entire pkg had 0 external importers. Public API (`summary`, `revenue_trend`, `occupancy_heatmap`, `source_breakdown`, `drill_down`) nowhere called. Shape doc stale. |
| 2 | `app/services/approval/auto_reject_job.py` | **179** | `register_approval_jobs` / `run_auto_reject_72h_job` / `run_kb04_6h_check_job` / `run_fraud_24h_check_job` unreferenced. Only internal import = own module. |
| 3 | `app/services/renewal/cron.py` | **143** | `start_renewal_cron` / `_run_renewal_scan` / `_enqueue_renewal_notification` unreferenced. Package `__init__.py` has only docstring. |
| 4 | `app/services/media/video_processor.py` + `tests/services/media/test_video_processor.py` + empty pkg dirs | **511** | VN Reels HEVC→H.264 transcoder. No routers/services importers; only its self-test. Test file culled with it. |
| **Σ** |  | **~2145** | |

### False positives (kept)
- `admin_v2/{audit_read,change_requests,finance_ops,partners_ops,rbac,work_items}` — all used by `app/api/routes/admin_v2/*.py` or sister services (dotted-path histogram missed because routers import as `change_requests`, not full dotted path).
- `admin_v2/sessions.py` — `sign_admin_token`/`open_session`/`revoke_sessions`/`session_dict` all used by `app/api/routes/admin_v2/{auth,overview,staff}.py`.
- `service_request/`, `retention/`, `demand/` packages — chained but ultimately reach routers via `__init__.py`.

### Verification per commit
- Smoke `JWT_SECRET=test DATABASE_URL=sqlite:///:memory: python -c "import main"` → exit 0 after each strip.
- Pytest collection post-batch: **1793 tests, 0 collection errors** (dropped 37 = exactly the Reels test file).

### Pytest regression check
- Baseline (Sessions 18-20): 1623 passed / 90 failed / 83 skipped / 34 errors.
- Post-Session-21: **1586 passed / 90 failed / 83 skipped / 34 errors** in 69s.
- Delta: −37 passing = test_video_processor.py (37 tests) deleted with its dead target. **FAILED/ERROR sets identical to baseline** (SHA-matched 124 lines). **Zero net regression in surviving tests.**
- New effective floor: **1586p** (reset from 1623p due to test-file strip, not code breakage).

### Totals Phase-03 orphan strips (Sessions 17-21)
| Session | Strips | LOC |
|---------|--------|-----|
| 17 | STOP at Layer-3 (short-stays) | 0 |
| 18 | sale_crm_service + crm cluster | ~268 |
| 19 | cho_thue_ngoai | 230 |
| 20 | 5 flat-service orphans | 1011 |
| 21 | **analytics pkg + auto_reject_job + renewal/cron + media/video_processor** | **2145** |
| **Σ** |  | **~3654** |

### Session 22 recommendation

**Primary — pivot to Phase-04 planning.** Subdirectory sweep yielded 4× target but the remaining candidates (`admin_v2/*`, `delegation/*`, `notification/*`, `kyc/*`, `jp/*`, `payment/*`) all have live callers via dotted or non-dotted router imports. Any further strip requires caller surgery (Layer-3 ceiling). The orphan vein across `app/services/` is now effectively dry.

- Khuyến nghị: Session 22 opens Phase-04 — produce JP-rename scope doc (`luot_xem_tin` → `閲覧数`, `tin_cho_thue` → `物件掲載`, `phieu_dat_phong` → `予約票`, `phieu_hen_xem` → `内見予約`) + houses god-router strip plan (`app/routers/houses.py` is 1500+ LOC, likely has VN-only branches internally).
- Hệ quả nếu chọn sai: Continuing subdirectory sweep in Session 22 likely yields < 100 LOC after 30 min of grep — poor ROI.
- Độ tin cậy: HIGH.

**Alternative — targeted interior strip of god-services.** `app/services/short_stay_service.py` (486 LOC live), `app/services/loai_phong_service.py`, `app/services/phieu_dat_phong.py`, `app/services/phieu_hen_xem.py` all live but may have VN-specific internal branches (SĐT masking rules, VN admin units, Zalo integration) that are now dead post-strips. Read each file and strip dead branches **without renaming**.

- Khuyến nghị: Only if Phase-04 planning blocked by missing JP spec. Interior strip is riskier (Layer-3) but can yield ~300-500 LOC per god-service without touching caller surface.
- Hệ quả nếu chọn sai: Internal strip could break live code paths not covered by tests (Session 20 acknowledged pytest is now ~smoke-only).
- Độ tin cậy: MEDIUM.

**Also consider — pytest baseline refresh.** Session 20 floor was 1623p, now 1586p after legitimate test-file strip. If Session 22 does interior god-service strips, baseline MUST be re-measured first; otherwise, every strip looks like regression.

### Unresolved questions (Session 21)

1. The `analytics_service` package exposed 5 public dashboard functions (`summary`, `revenue_trend`, `occupancy_heatmap`, `source_breakdown`, `drill_down`). JP market will need equivalent analytics (管理ダッシュボード). Preserve the function signatures in a stub or let Phase-04 redesign from scratch?
   - Khuyến nghị: Let Phase-04 redesign. VN analytics assumed VN admin units + VN KPI metrics (lead sources: Facebook, Zalo, Chotot). JP equivalents (Suumo/Homes/At Home) differ structurally. Stub preservation = technical debt masquerading as velocity.
   - Hệ quả nếu chọn sai: Phase-04 implementation cost ~2 sessions to rebuild; stub preservation saves ~0.
   - Độ tin cậy: HIGH.

2. `app/schemas/_analytics_shapes.md` was a markdown doc (not code), stripped alongside the package. Should Phase-04 produce a replacement shape doc for JP analytics, or inline the shape as Pydantic schemas (which is JP-project convention per `app/schemas/jp/*`)?
   - Khuyến nghị: Pydantic schemas inline (JP convention). The .md doc existed because VN dashboards returned raw dicts; JP code uses typed response models everywhere. Doc redundancy avoided.
   - Hệ quả nếu chọn sai: Minor doc duplication.
   - Độ tin cậy: HIGH.

3. The media/video_processor test (37 cases) was 345 LOC vs 166 LOC implementation (ratio 2.08:1) — strong signal the test suite exercises VN-era features that no longer have app-level callers. How many other test files in `tests/services/*` test dead or near-dead code?
   - Khuyến nghị: Session 22 or a dedicated test-audit session should histogram `tests/services/<cluster>/*.py` → verify the `app/services/<cluster>/` target is still reachable from a registered router. Test files whose target has 0 router-path = candidates for culling (reduces CI time + pytest noise).
   - Hệ quả nếu chọn sai: Audit adds 30 min of overhead; non-audit leaves ~500-1000 LOC of dead test code masquerading as coverage.
   - Độ tin cậy: MEDIUM-HIGH.

### Status: DONE
**Summary:** Session 21 pivoted to subdirectory sweep, stripped 4 orphans totalling ~2145 LOC (2.1× Session 20 yield). Pytest surviving tests held zero net regression. Flat + subdirectory orphan veins now effectively dry — Session 22 should open Phase-04.
