# Phase 09 — Rollout + Monitoring

**Mục tiêu:** đưa geo-search lên production an toàn, có thể rollback.
**Est.:** 0.5 ngày · **Phụ thuộc:** Phase 08.

---

## 1. Thứ tự rollout an toàn (D12)
1. **Deploy migration `0037`** (cột + trigger + GIST index; geom backfill từ lat/lng đã có — **không** đụng Nominatim). SQLite dev không ảnh hưởng nhờ dialect-guard.
2. **Deploy backend code** với `geo_search_enabled=False` (endpoint mới ẩn, `/api/houses` giữ hành vi cũ).
3. **Chạy backfill** (`scripts/backfill_geocode.py` throttled/resumable + backfill `province_code`). Theo dõi phân bố `geocode_status`.
4. **Bật `geo_search_enabled=True`** sau khi độ phủ toạ độ đạt ngưỡng (≥70% tin `approved`).
5. **Deploy Flutter** (app build có `geolocator` + UI mới). Kiểm tra permission trên android thật.

## 2. Rollback
- Flag `geo_search_enabled=False` → tắt geo-search tức thì, `/api/houses` về hành vi cũ (không cần redeploy).
- `alembic downgrade -1` gỡ trigger/index/cột; lat/lng là source of truth nên mất `geom` không mất dữ liệu.

## 3. An toàn dữ liệu
- Trigger DB là nguồn `geom` duy nhất → marketplace-sync/ETL ghi raw SQL tự có geom. Đảm bảo sync cũng set `province_code` (map slug) hoặc để backfill định kỳ quét `province_code IS NULL`.
- `CREATE INDEX` trên `houses`: nếu bảng lớn, chạy `CONCURRENTLY` ngoài Alembic để tránh lock.

## 4. Monitoring / Metrics (xem plan.md §10)
- Tỉ lệ phiên dùng geo-search (≥30%), tỉ lệ non-empty nearby/địa danh (≥80%).
- Độ phủ toạ độ tin `approved` (≥70% sau backfill) — dashboard theo `geocode_status`.
- p95 latency nearby (<400ms) + geocode (<800ms); tỉ lệ 5xx do Nominatim.
- % phiên nearby lỗi quyền vị trí (<5%).
- Rate-limit 429 trên `/search-nearby`.

---

## Definition of Done
- Migration + backfill chạy xong trên prod; độ phủ toạ độ đạt ngưỡng.
- Flag bật, 3 chế độ hoạt động end-to-end trên prod.
- Dashboard metrics online; rollback path đã kiểm thử (tắt flag).
