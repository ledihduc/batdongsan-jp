# Phase 01 — Backend: Data model + Migration `0037`

**Mục tiêu:** thêm cột geo-spatial + chuẩn hoá vào `houses`, giữ đồng bộ `geom` bằng trigger, không phá vỡ SQLite dev.
**Est.:** 1 ngày · **Phụ thuộc:** Phase 00 · **Alembic head hiện tại:** `0036_commission_pct_check_constraint`.

---

## 1. Cột thêm vào `houses`

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `geom` | `geometry(Point,4326)` (Postgres) / bỏ qua (SQLite) | Điểm dẫn xuất từ lat/lng. NULL khi thiếu toạ độ. **Không** khai báo ở ORM. |
| `province_code` | `String(10)` nullable, indexed | Mã tỉnh = **slug** trong `vietnam-provinces.json` (vd `tp-ho-chi-minh`). |
| `district_code` | `String(20)` nullable, indexed | Mã quận/huyện chuẩn hoá (giai đoạn 2, optional). |
| `geocode_status` | `String(16)` default `'pending'`, indexed | `pending`/`geocoded`/`failed`/`manual` — phục vụ backfill idempotent. |
| `geocoded_at` | `TIMESTAMP(tz)` nullable | Lần geocode gần nhất. |

**Quyết định (D3):** `geom` **không** đặt trên ORM `House` (tránh import geoalchemy2 khi dev SQLite — `House` là core model luôn load). `geom` sống ở DB, đọc/ghi bằng raw SQL `text()` như module planning. ORM chỉ thêm 4 cột an toàn cross-dialect:

```python
# app/models.py — thêm vào class House
    province_code: Mapped[Optional[str]] = mapped_column(String(10), nullable=True, index=True)
    district_code: Mapped[Optional[str]] = mapped_column(String(20), nullable=True, index=True)
    geocode_status: Mapped[str] = mapped_column(String(16), default="pending", index=True)
    geocoded_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    # geom (geometry Point 4326) sống ở DB, truy cập raw SQL.
```

---

## 2. Đồng bộ `geom` ↔ lat/lng: DB trigger (D2)

Trigger là **nguồn sự thật duy nhất** — phủ cả marketplace-sync/ETL ghi raw SQL (không đi qua ORM). Không dual-write app-level.

```sql
CREATE OR REPLACE FUNCTION houses_sync_geom() RETURNS trigger AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.geom := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
  ELSE
    NEW.geom := NULL;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_houses_sync_geom
  BEFORE INSERT OR UPDATE OF latitude, longitude ON houses
  FOR EACH ROW EXECUTE FUNCTION houses_sync_geom();
```

> Chọn trigger thay vì `GENERATED ... STORED`: trigger cho phép **re-backfill** (`UPDATE houses SET latitude=latitude`) khi đổi logic, và xử lý được nguồn ghi ngoài ORM.

---

## 3. Index

```sql
-- partial GIST: nearby query luôn kèm status='approved' AND geom IS NOT NULL → index nhỏ, chọn lọc cao
CREATE INDEX houses_geom_approved_gist ON houses USING GIST (geom)
  WHERE status = 'approved' AND geom IS NOT NULL;
CREATE INDEX houses_geom_gist ON houses USING GIST (geom);
CREATE INDEX houses_province_code_idx ON houses (province_code) WHERE status = 'approved';
```

> `CREATE INDEX CONCURRENTLY` **không** chạy trong transaction Alembic. Bảng nhỏ/vừa hiện tại → `CREATE INDEX` thường là đủ. Nếu bảng lớn cần zero-lock, tách GIST index ra migration riêng với `autocommit_block()`.

---

## 4. Migration `0037` (dialect-guarded)

File: `alembic/versions/0037_houses_geo_search.py`, `down_revision = "0036_commission_pct_check_constraint"`.

Cấu trúc (theo pattern `0011`/`0013`):
1. **Cross-dialect (chạy cả SQLite):** `add_column` cho 4 cột code/status + `create_index` cho chúng.
2. `if bind.dialect.name != "postgresql": return` — SQLite dừng ở đây.
3. **Postgres only:** `CREATE EXTENSION IF NOT EXISTS postgis` → `ALTER TABLE houses ADD COLUMN geom geometry(Point,4326)` → **backfill geom từ lat/lng đã có** (`UPDATE ... SET geom=ST_SetSRID(ST_MakePoint(longitude,latitude),4326), geocode_status='geocoded' WHERE lat/lng NOT NULL`) → tạo function + trigger → tạo GIST + partial index.
4. `downgrade()`: drop trigger/function/index/geom (Postgres) rồi drop 4 cột (cross-dialect). Vì lat/lng là source of truth, mất `geom` không mất dữ liệu.

*(Snippet đầy đủ đã có trong ghi chú Tech Lead — copy vào file migration.)*

---

## Definition of Done
- `alembic upgrade head` xanh trên cả SQLite (dev) và Postgres (prod-like).
- Trên Postgres: insert/update lat/lng → `geom` tự cập nhật; set NULL → geom NULL (kiểm bằng psql).
- Tin có sẵn lat/lng → `geom` backfilled + `geocode_status='geocoded'`.
- `alembic downgrade -1` gỡ sạch, không lỗi.
