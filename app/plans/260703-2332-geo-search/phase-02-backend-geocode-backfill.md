# Phase 02 — Backend: Geocode backfill + chuẩn hoá `province_code`

**Mục tiêu:** tăng độ phủ toạ độ cho tin NULL-coord và gán `province_code` từ `city` free-text.
**Est.:** 1 ngày · **Phụ thuộc:** Phase 01 · **Chạy SONG SONG, ngoài đường tới hạn release UI (D11).**

---

## 1. Backfill toạ độ (Nominatim)

**File:** `scripts/backfill_geocode.py` (CLI standalone, style `app/services/planning_etl/cli.py`). Ngoài request path. Tái dùng `app/services/nominatim_proxy.py` (đã bounded VN bbox + strip Authorization).

**Tính chất:**
- **Idempotent + resumable** qua `geocode_status`: chỉ lấy `WHERE geocode_status='pending' AND (lat IS NULL OR lng IS NULL)`, commit **từng tin** → kill giữa chừng chạy lại tiếp đúng chỗ.
- **Throttled** `asyncio.sleep(sleep)` (mặc định 1 req/s) để không nghẽn Nominatim dùng chung với planning search.
- **Forward-geocode** query `address + district + city + ", Việt Nam"`; miss → fallback `district + city + ", Việt Nam"`.
- **VN bbox guard:** kết quả ngoài `settings.vn_bbox_full` → đánh `failed` (không ghi rác).
- Set lat/lng → **trigger tự tính geom** (không set geom trong script).

**Chạy:** `python -m scripts.backfill_geocode --batch 200 --sleep 1.0`
Yêu cầu Postgres (`if not database_url.startswith("postgresql"): SystemExit`).

*(Snippet đầy đủ trong ghi chú Tech Lead.)*

---

## 2. Backfill `province_code` (không cần Nominatim)

Một pass thuần Python, **chạy được cả SQLite dev**, dùng `provinces_service.search_provinces` (accent-strip + slug đã có):

```python
from app.services import provinces_service
for h in db.query(models.House).filter(models.House.province_code.is_(None)).all():
    hits = provinces_service.search_provinces(h.city or "", limit=1)
    if hits:
        h.province_code = hits[0]["slug"]   # slug = province_code (D4)
db.commit()
```

Tin `city` rác không map được → `province_code=NULL`, vẫn tìm được qua text search cũ (không mất tin). **Log tỉ lệ map-fail** để đo chất lượng dữ liệu.

---

## 3. Set code ngay khi tạo/sync tin

Để tin mới không cần đợi backfill:
- **`create_house`** (và update): sau khi có `city` → `h.province_code = provinces_service.search_provinces(city, limit=1)[0]["slug"]` nếu match.
- **Marketplace-sync job**: thêm bước map slug tương tự (hoặc để backfill định kỳ quét `province_code IS NULL`). Trigger DB đã lo `geom` cho sync raw SQL.

---

## Definition of Done
- Script chạy 2 lần liên tiếp: tin `geocoded`/`failed` **không** gọi lại Nominatim (kiểm bằng mock đếm call).
- Kết quả ngoài bbox VN → `failed`, không ghi lat/lng rác.
- `province_code` phủ ≥ mục tiêu trên tập `approved`; log rõ tỉ lệ fail.
- `create_house` set `province_code` đúng từ `city`; `city` rác → `None` nhưng tin vẫn tạo thành công.
