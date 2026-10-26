# Code Review — Phase 01 DB Migration

**Date:** 2026-06-22
**Phase:** 01 (DB Migration SQLite → Postgres + Alembic baseline)
**Reviewer:** code-reviewer agent
**Scope:** 14 files (8 modified, 6 created) — Alembic baseline, env, conftest, smoke tests, CI workflow, README, seed script
**Spec verified against:** BA AC §5, Phase 01 §Success criteria, §Security considerations
**Tester input:** `reports/tester-phase-01.md` (14/14 smoke pass + 61 pre-existing pass)

---

## Overall Assessment

Phase 01 đạt được **mục tiêu chính**: SQLite bị remove khỏi runtime, Alembic baseline (`bef9a3d80bf2`) tạo đủ 9 core tables + 3 planning tables, multi-metadata env.py setup đúng, CI workflow chạy được. Tester đã verify AC1–AC6 pass.

Tuy nhiên có **2 HIGH issue** vi phạm trực tiếp tinh thần Phase 01:
1. `tests/conftest.py:294` vẫn dùng `Base.metadata.create_all()` trong smoke fixture → defeats the goal "schema managed by alembic only".
2. `tests/conftest.py:318` có `return fake_db_session` ngoài scope → fixture teardown silently raise NameError (giải thích 67 warnings trong tester report).

Ngoài ra có **README port mismatch** (5433 vs 5432 thực) sẽ break user follow setup-from-scratch (vi phạm AC docs).

FK constraints **không có** trên model ORM (pre-existing — phase spec đã accept ở risk table "FK CASCADE missing → Phase 02 refactor"). Migration phản ánh đúng model, không phải bug Phase 01 introduce, nhưng cần document rõ là technical debt phải xử lý phase 02.

**Rating: CONDITIONAL** — fix 2 HIGH issues + 1 README mismatch trước khi merge.

---

## Findings

### CRITICAL (BLOCK merge)

_Không có CRITICAL issue._

---

### HIGH (FIX before merge)

| # | File:line | Issue | Fix |
|---|-----------|-------|-----|
| H1 | `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/tests/conftest.py:294` | `Base.metadata.create_all(bind=engine)` vẫn được gọi trong `pg_smoke_engine` fixture. Comment "safety net" nhưng thực ra vi phạm AC6 (schema must come from alembic only). Tệ hơn: nếu model thay đổi mà chưa generate migration mới → fixture sẽ silently sync schema mismatched với production, che giấu missing migration. | Remove dòng 294 hoàn toàn. Nếu lo schema chưa tồn tại, fail loudly: `inspect(engine).has_table("users")` → raise nếu thiếu, hướng dẫn user chạy `alembic upgrade head`. |
| H2 | `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/tests/conftest.py:318` | `return fake_db_session` xuất hiện ngoài scope của `pg_session` fixture — tên `fake_db_session` không nằm trong args (chỉ có `pg_smoke_engine`). Sau `yield session` + teardown 3 dòng, Python execute `return fake_db_session` → **NameError** được pytest swallow thành warning. Đây là root cause của "67 warnings" trong tester report. | Xóa dòng 318. Fixture đã `yield session` rồi, không cần return gì thêm. |
| H3 | `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/README.md:33-34, 57, 96, 109` | README ghi `localhost:5433` trong khi `docker-compose.yml:16` expose `127.0.0.1:5432:5432`. User follow setup-from-scratch sẽ gặp "connection refused" ở Bước 4. Phase 01 §Security considerations cũng nêu `127.0.0.1:5432` (line 159) → đồng nhất port 5432. | Replace all `5433` → `5432` trong README (4 dòng) HOẶC update docker-compose port mapping to `127.0.0.1:5433:5432` (and update .env.example comment). Pick một và stick với nó. |

---

### MEDIUM

| # | File:line | Issue | Fix |
|---|-----------|-------|-----|
| M1 | `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/app/config.py:6` | Default `database_url = "sqlite:///./urbannest.db"`. Nếu user chạy không có `.env`, app silently fall back về SQLite (the very thing Phase 01 ripped out). | Đổi default sang empty string + raise `RuntimeError` trong `app/database.py` nếu rỗng. Hoặc default sang `postgresql://localhost/ancu365_dev` để fail-fast khi không có Postgres. |
| M2 | `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/app/models.py:11, models.py:84/87/110-113/...` | `ForeignKey` được import nhưng KHÔNG dùng. Tất cả `host_id`, `category_id`, `house_id`, `guest_id`, `user_id` đều khai báo plain `Integer` không có FK constraint → Postgres cho phép orphan rows (booking trỏ tới house không tồn tại). Phase 01 risk table đã accept "FK CASCADE missing → Phase 02 refactor" nhưng Phase 01 nên ít nhất add FK (non-cascade) để data integrity ngay từ baseline. | Phase 02 task: add `ForeignKey("users.id")` cho tất cả `*_id` columns. Tạo migration `add_fk_constraints.py`. Document rõ trong phase-02 plan. |
| M3 | `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/tests/conftest.py:23-32` | Module-level `os.environ["DATABASE_URL"] = "postgresql://localhost/fake_test"` + xóa `sys.modules['app.*']`. Effect: bất kỳ test import `app.*` đều dùng fake URL. `pg_smoke_engine` (line 282-286) phải xóa modules lần nữa và set lại env var → fragile, side-effect global, khó debug. | Đổi sang `monkeypatch` fixture (pytest idiomatic) hoặc tách 2 conftest: `tests/planning/conftest.py` (fake) vs `tests/smoke/conftest.py` (real). |
| M4 | `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/scripts/seed_dev.py:24-31` | `try/except ImportError` chỉ in error rồi `sys.exit(1)` — mất stack trace gốc. | Re-raise hoặc dùng `logging.exception()` để giữ traceback. |
| M5 | `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/app/seed.py:7` | Idempotency check `db.query(User).first()` — nếu admin xoá user nhưng category/amenity vẫn còn, seed sẽ chạy lại và crash UNIQUE constraint. Phase 01 OK vì AC3 chỉ test re-run trên DB seeded, nhưng sẽ vỡ trên DB partial. | Idempotent từng entity: `if not db.query(Category).filter_by(name=...).first(): db.add(...)`. Hoặc dùng `INSERT ... ON CONFLICT DO NOTHING`. |
| M6 | `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/alembic/versions/bef9a3d80bf2_initial_baseline_all_tables.py:1-22` | Baseline migration KHÔNG include `planning.reports` table — model `PlanningReport` (planning_models.py:98) tồn tại nhưng table được tạo bởi migration cũ `0001_planning_reports`. Đúng cho hiện tại, nhưng nếu sau này drop `0001` (flatten history) sẽ mất reports table. | Document trong comment đầu file: "Note: planning.reports created by previous migration 0001; do not re-create here." (Hoặc accept since down_revision = '0001_planning_reports' ensures chain.) |
| M7 | `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/main.py:51-53` | `seed_run(db)` được gọi ở **module-level startup**, không phải trong `@app.on_event("startup")`. Side effect: any import of `main` (e.g., uvicorn reload, alembic env, test runner) sẽ chạy seed → unintended writes to DB. | Move vào `@app.on_event("startup")` (line 127) hoặc gate bằng `if __name__ == "__main__":` / env flag `SEED_ON_BOOT=1`. |
| M8 | `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/.github/workflows/tests.yml:35` | `BACKEND_CORS_ORIGINS: "*"` trong CI. OK cho test, nhưng cùng giá trị trong `.env.example` line 12 (default for dev) + line 52 (mới nói "production: set domain"). Risk: dev sẽ copy paste `*` sang prod. | `.env.example` line 12 default → `BACKEND_CORS_ORIGINS=http://localhost:3000` (dev safe). Giữ wildcard chỉ trong CI workflow. |

---

### LOW / NITPICK

- `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/alembic/versions/bef9a3d80bf2_initial_baseline_all_tables.py:175` — duplicate `parcels_district_idx` đã được tạo trong `0001_planning_reports.py`? Kiểm tra lại — actually `0001` chỉ tạo `reports` table, không có parcels. OK. Nhưng comment line 173-176 confusing với "GeoAlchemy2 auto-index" — link tới docs/issue ref sẽ rõ hơn.
- `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/app/models.py:44-45` — `now_utc` dùng `datetime.utcnow()` (deprecated trong Python 3.12). Thay bằng `datetime.now(timezone.utc)`.
- `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/tests/conftest.py:30-32` — `del sys.modules[k]` không thread-safe; nếu pytest-xdist parallel chạy sẽ flaky. Phase 01 chưa dùng xdist nên OK.
- `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/README.md:113-119, 126-132` — 2 bảng "Tài khoản demo" trùng lặp. Xóa 1.
- `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/scripts/seed_dev.py:18-19` — `sys.path.insert(0, ...)` hack. Tốt hơn: chạy `python -m scripts.seed_dev` với `__init__.py` trong `scripts/` (chưa có).
- `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/.env.example:9` — `JWT_SECRET=please_rotate_in_prod_32_chars_min` chỉ 34 char. Comment line 8 nói "Generate: python -c \"import secrets; print(secrets.token_hex(32))\"" → token_hex(32) sinh 64 hex chars. Thay default placeholder thành empty string + raise nếu rỗng (fail-fast).
- `/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-backend/.github/workflows/tests.yml:32` — CI `JWT_SECRET=ci-test-secret-not-for-production-32c` cứng trong workflow file. Acceptable cho test, nhưng nên dùng `${{ secrets.CI_JWT_SECRET }}` để consistent với pattern.

---

## Strengths

- **Multi-metadata setup đúng pattern Alembic**: `target_metadata = [Base.metadata, PlanningBase.metadata]` + `include_name` filter exclude tiger/topology PostGIS schemas. Clean and future-proof for Phase 02 add HostProfile.
- **`get_url()` validation trong env.py**: raise loud nếu thiếu DATABASE_URL — đúng security principle "fail fast".
- **`include_name` callback** với `_MANAGED_SCHEMAS` + `_EXCLUDED_TABLES` constants — readable, single-source-of-truth.
- **Downgrade function complete**: drop tất cả tables + indexes theo reverse order. Tester confirmed roundtrip works.
- **Idempotent seed logic** (basic): check existing user → skip. AC3 verified.
- **Smoke tests có cross-host isolation case** (TestCrossHostIsolation:273-306) — thực sự verify isolation, không chỉ assert true/true.
- **CI workflow tách 2 step**: smoke tests (real DB) vs planning tests (fake) — clean separation, faster failure feedback.
- **Docstring đầy đủ ở mọi file mới** — env.py, conftest.py, smoke tests, seed_dev.py.
- **`pool_pre_ping=True`** ở engine (database.py:13) — chống stale connection sau DB restart.
- **No hardcoded secrets** trong any committed file. Placeholder strings rõ ràng (`change_me_strong_64_chars`).
- **Port binding** `127.0.0.1:5432` (loopback only) — đúng security spec.

---

## AC Adherence

| AC | Status | Note |
|----|--------|------|
| AC1 (`docker compose up` + `alembic upgrade head` clean first run) | ✅ PASS | Verified by tester E2E |
| AC2 (pytest clean Postgres, no SQLite) | ⚠️ PARTIAL | Tests pass nhưng `tests/conftest.py:294` vẫn dùng `create_all()` để "safety net" → AC vi phạm về spirit |
| AC3 (seed_dev.py idempotent) | ✅ PASS | Verified; xem M5 cho edge case partial-data |
| AC4 (CI workflow green) | ✅ PASS | YAML valid, postgres:16 service đúng |
| AC5 (API smoke: register → login → create → list 200 OK) | ✅ PASS | Tester verified |
| AC6 (psql `\dt` shows 9+ core tables from alembic) | ✅ PASS | 11 public + 3 planning |
| Multi-tenant isolation (BA AC §5) | ⚠️ PARTIAL | Smoke test có cross-host case (TestCrossHostIsolation), nhưng model thiếu FK (M2) → orphan rows có thể qua mặt isolation ở DB level. Phase 02 phải fix. |
| Repo pattern (BA AC §5) | ❌ NOT IMPLEMENTED | Phase 01 chỉ migration; repo pattern là Phase 02 scope (đã document) |
| Migration safe Alembic versioned (BA AC §5) | ✅ PASS | baseline + 0001 + downgrade tested |

---

## Recommendations

**Trước merge (HIGH must fix):**
1. Fix H1: remove `Base.metadata.create_all()` ở `tests/conftest.py:294`. Replace với assertion table exists.
2. Fix H2: xóa orphan `return fake_db_session` ở `tests/conftest.py:318`. Re-run pytest → expect warnings drop từ 67 xuống <10.
3. Fix H3: align README port với docker-compose. Recommend giữ `5432` (current docker), update README 4 occurrences.

**Có thể merge ngay với follow-up issues:**
4. Create Phase 02 sub-task: add FK constraints (M2) + repository pattern + tenant isolation enforcement.
5. M1 (default `database_url = sqlite://...`) — change ở Phase 02 cùng config refactor.
6. M7 (seed_run ở module-level startup) — refactor ở Phase 02 khi touch main.py.
7. Run `pytest -W error` để force warnings → errors khi tests phải clean → expose bugs ẩn.

**Documentation:**
8. Update `docs/code-standards.md` mục Database: "all FK columns MUST declare `ForeignKey()`; no plain Integer for `*_id`".
9. Document trong Phase 01 plan retrospective: 4 pre-existing planning bbox failures cần tracked sang Phase 0X.

---

## Final Rating

- [ ] APPROVED — ready to merge
- [x] CONDITIONAL — fix H1, H2, H3 then merge
- [ ] REJECTED

**Rating: CONDITIONAL**

Phase 01 đạt mục tiêu chính (Postgres + Alembic) nhưng 2 lỗi trong `tests/conftest.py` làm broken contract của AC2 + AC6 (silent warnings, fallback create_all). README port mismatch sẽ fail UX cho new dev. Tất cả đều fix trong <30 phút.

---

## Unresolved Questions

1. Có chủ ý giữ `Base.metadata.create_all()` ở conftest:294 như "safety net" thật sự, hay là copy-paste sót khi refactor? Nếu intentional → cần document tại sao không trust alembic. Nếu sót → xóa.
2. Port nào là canonical: `5432` (docker-compose) hay `5433` (README + phase spec)? Phase spec line 159 cũng nói `5432`. README có vẻ outdated.
3. FK constraint absence là tech debt cố ý (per risk table) hay oversight? Phase 02 plan có explicit task add FK không?

---

**Status:** DONE_WITH_CONCERNS
**Summary:** Phase 01 đạt mục tiêu chính nhưng có 3 HIGH issues (`create_all` fallback ở conftest, orphan `return` dòng 318 gây 67 warnings, README port 5433 vs docker 5432) cần fix trước merge. Không có CRITICAL security issue.
