---
title: "Phase 01h — Postgres concurrency hardening (EXCLUDE USING gist on reservations)"
description: "Replace app-level overlap check with DB-level EXCLUDE constraint to make anti-overbooking race-condition-proof"
status: pending
priority: P1
effort: 0.5d
branch: TBD
tags: [backend, infrastructure, postgres, alembic, homestay, concurrency]
created: 2026-06-28
---

# Phase 01h — Postgres concurrency hardening

**Sized:** 0.5d
**Status:** ⏸ Pending (scoped, ready to execute)
**Blocks:** none (production safety polish for Phase 07 reservations)
**Blocked by:** Phase 01 baseline (✅ commit 7bd7e55), Phase 07 reservations table (✅ alembic 0009)

## Context

Phase 01 base migration đã xong (commit `7bd7e55 feat(db): migrate to Postgres
+ Alembic baseline for all tables`) — Postgres+PostGIS đã chạy CI, alembic
baseline áp dụng cho toàn bộ core tables, `Base.metadata.create_all` đã gỡ.

Item duy nhất còn lại của Phase 01 (đánh dấu TODO trong 2 chỗ code):
- `alembic/versions/0009_homestay_core.py:135-138` — NOTE: "When Phase 01
  lands on Postgres, add EXCLUDE USING gist constraint on reservations…"
- `app/services/reservation_service.py:3-14` — docstring: "Phase 01
  (Postgres) will install EXCLUDE USING gist… Until then, in-transaction
  overlap query + INSERT… *not* race-condition-proof under true concurrency."

Hiện tại 2 client gọi `POST /reservations` cùng thời điểm cho cùng phòng,
cùng khoảng ngày overlap, đều thấy `find_overlapping` empty → double-book.
Chấp nhận được ở scale hiện tại nhưng cần đóng trước khi mở public booking.

## Goal

Cài đặt **EXCLUDE USING gist** trên `reservations` để chính DB từ chối INSERT
overlap, độc lập với code app. Test bằng cách thử INSERT trực tiếp 2 row
overlap → row thứ 2 raise `IntegrityError`.

## Architecture

### DB constraint
```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE reservations
ADD CONSTRAINT excl_reservations_room_overlap
EXCLUDE USING gist (
  room_id WITH =,
  daterange(check_in_date::date, check_out_date::date, '[)') WITH &&
)
WHERE (status IN ('pending', 'approved', 'checked_in'));
```

Notes:
- `btree_gist` extension cần thiết cho operator `=` trên integer (`room_id`).
- `check_in_date`/`check_out_date` hiện là `VARCHAR(20)` (ISO date string).
  Cast `::date` an toàn vì service code chỉ ghi format `YYYY-MM-DD`.
- Range bound `'[)'` — inclusive check-in, exclusive check-out (đêm trả
  phòng KHÔNG block đêm khách mới check-in cùng ngày).
- Predicate `WHERE status IN (...)` — chỉ chặn overlap với reservation
  còn active; `cancelled` / `rejected` / `checked_out` không block.

### App code
- `reservation_service.create_reservation` giữ nguyên app-level overlap
  check (UX: trả 400 với message tiếng Việt thay vì 500 IntegrityError).
- Cập nhật docstring để bỏ "Phase 01 will install" → ghi "Phase 01 đã
  install".

### Tests
- New `tests/homestay/test_reservation_exclude_constraint.py` — Postgres-
  only (skip nếu thiếu `SMOKE_DATABASE_URL`). Insert trực tiếp qua raw SQL
  bypass service code để chứng minh constraint reject ở DB layer.

## Related code files

### New
- `alembic/versions/0011_reservation_exclude_constraint.py` — upgrade
  (CREATE EXTENSION + ALTER TABLE ADD CONSTRAINT) + downgrade (DROP
  CONSTRAINT, KHÔNG drop extension vì có thể bị shared).
- `tests/homestay/test_reservation_exclude_constraint.py` — 3 cases:
  - reject INSERT overlap với pending reservation
  - reject INSERT overlap với approved reservation
  - allow INSERT overlap khi reservation cũ status=cancelled

### Modified
- `app/services/reservation_service.py:1-20` — update docstring để phản
  ánh thực tế.
- `alembic/versions/0009_homestay_core.py:135-138` — đổi NOTE comment
  thành "See migration 0011 for the EXCLUDE constraint."

## Implementation steps

1. **New migration:** Tạo `alembic/versions/0011_reservation_exclude_constraint.py`:
   - `down_revision = '0010_marketplace_integration'`
   - upgrade(): `op.execute("CREATE EXTENSION IF NOT EXISTS btree_gist")` + `op.execute(...)` cho ALTER TABLE.
   - downgrade(): `op.execute("ALTER TABLE reservations DROP CONSTRAINT IF EXISTS excl_reservations_room_overlap")`.
2. **Single-head check:** `.venv/bin/python -c "from alembic.config import Config; ..."` xác nhận head = 0011.
3. **Apply CI:** CI sẽ chạy `alembic upgrade head` trên Postgres 16 trong
   pipeline existing (`.github/workflows/tests.yml`). Verify pipeline green.
4. **Update service docstring:** `app/services/reservation_service.py:3-14`
   — đổi "Phase 01 (Postgres) will install… Until then" → "Phase 01h đã
   install EXCLUDE USING gist; app-level overlap check vẫn giữ để trả 400
   thay vì 500 IntegrityError."
5. **Update 0009 NOTE:** đổi 135-138 → "See migration 0011 for the EXCLUDE
   constraint."
6. **Write tests:** `tests/homestay/test_reservation_exclude_constraint.py`
   — dùng `pg_session` fixture existing; cố tình INSERT raw SQL 2 row
   overlap → assert IntegrityError trên row 2; case 3 với status=cancelled
   → assert insert OK.
7. **Local verify (optional):** `SMOKE_DATABASE_URL=… pytest tests/homestay/test_reservation_exclude_constraint.py`.

## Todo list
- [ ] Create `alembic/versions/0011_reservation_exclude_constraint.py`
- [ ] Verify single alembic head
- [ ] Update `reservation_service.py` docstring
- [ ] Update `0009_homestay_core.py` NOTE comment
- [ ] Write `tests/homestay/test_reservation_exclude_constraint.py` (3 cases)
- [ ] Commit + push, verify CI green

## Success criteria
- **AC1:** `alembic upgrade head` apply clean (CI green).
- **AC2:** Trực tiếp INSERT 2 reservation overlap (cùng room, ngày
  overlap, status='pending') → row 2 raise `IntegrityError` với
  constraint name `excl_reservations_room_overlap`.
- **AC3:** INSERT reservation overlap với row cũ status='cancelled' →
  pass.
- **AC4:** Service-level test suite (`tests/homestay/*`) vẫn pass 16/16
  (no behavior change cho happy path).
- **AC5:** Docstring + NOTE comment update — không còn TODO "Phase 01
  will install" trong codebase.

## Risk assessment
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `check_in_date::date` cast crash trên row có format lạ | 10% | HIGH | Service code validate ISO format trước INSERT; existing rows toàn ISO chuẩn. |
| btree_gist extension thiếu trên prod Postgres | 20% | MED | Migration tự `CREATE EXTENSION IF NOT EXISTS` — Postgres 16 đã ship sẵn. |
| Constraint chặn legit edge case (back-to-back booking) | 5% | LOW | Range bound `'[)'` cho phép check-out + check-in cùng ngày khác guest. |
| Downgrade hỏng nếu drop extension (shared) | 15% | LOW | Migration downgrade chỉ DROP CONSTRAINT, không drop extension. |

## Security considerations
- Không thay đổi auth/permission. Constraint là database integrity.
- IntegrityError raise lên service → service ép thành 400 với message
  tiếng Việt (không leak constraint name ra client).

## Next steps
- After merge: Phase 07 reservation flow trở nên production-grade cho
  concurrent booking.
- Optional follow-up: migrate `check_in_date`/`check_out_date` từ
  VARCHAR → DATE type (cleaner, không cần cast) — defer cho đến khi cần
  schema cleanup.
