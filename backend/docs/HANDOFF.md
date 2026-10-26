# HANDOFF — trạng thái & việc đang dở (2026-07)

Repo: `ancu365-backend` (FastAPI) + `ancu365-app` (Flutter). Cả 2 push GitHub (`ledihduc/*`).
Tài liệu liên quan: [ROADMAP.md](ROADMAP.md) · [RENTAL-PIVOT-PLAN.md](RENTAL-PIVOT-PLAN.md) · [PHASE1-BUILD-SPECS.md](PHASE1-BUILD-SPECS.md) · [HOST-REDESIGN-RISK.md](HOST-REDESIGN-RISK.md) · [../scripts/observability/README.md](../scripts/observability/README.md).

## 🔧 ĐANG DỞ — Lead segmentation (khách mục tiêu/tiềm năng)
- ✅ Backend XONG (commit này, **CHƯA deploy**): `app/routers/host_leads.py` → `GET /api/host/leads` (require_host). Target = khách có ViewingAppointment; Potential = khách wishlist (trừ target). Flag `leads_enabled` (config.py). Đăng ký ở main.py. Read-only, KHÔNG migration.
- ⬜ **CÒN LẠI**: (1) Flutter `LeadsScreen` (host) hiển thị target/potential + list + entry (đề xuất: menu tile "Khách quan tâm" ở `host_home_nha_tro_tab.dart` nhóm VẬN HÀNH KHÁC, gọi `ApiClient.get('/api/host/leads')`). (2) Deploy backend (không migration → chỉ `deploy_backend.sh`) + build web.

## 🟢 (a) CÒN LÀM — an toàn, không chặn
1. **Lead segmentation** (đang dở — xem trên): chỉ còn Flutter UI + deploy.
2. **Dashboard thích ứng homestay** (R4): tab "Nhà trọ" KPI (Còn nợ/HĐ) không hợp chủ homestay → cần KPI đêm-trống/check-in. Homestay có màn riêng `HomestayHomeScreen` (kiểm tra trước khi làm — có thể đủ rồi).
3. **Saved-search** (lưu bộ lọc): backend bảng `saved_searches` + CRUD; Flutter nút "Lưu tìm kiếm" + tab. *Cảnh báo giá* phần alert **chặn bởi Notification thật**.

## ✅ ĐÃ LIVE trên prod (tóm tắt)
- Observability + self-heal pipeline (report-only; cron 15'; `ENABLE_AUTOFIX`/`ENABLE_AUTODEPLOY` OFF).
- Tools: `/api/tools/loan-calculator` + `/compare` (loan UI ẩn theo flag SALE).
- **Pivot sàn THUÊ**: ẩn mua/bán sau flag `SALE_ENABLED` (default off).
- **Sao chất lượng** nhà trọ (mig 0042): self_star + gợi ý giá + UI (DsQualityStars, QualityCard, QualityEditorScreen).
- **Thẩm định verified_star** (mig 0043): admin queue (VerificationQueueScreen) → gắn sao.
- **Review integrity**: chặn tự-review; flag `review_requires_stay` OFF.
- **Geo-search: ĐÃ BẬT** (`.env` GEO_SEARCH_ENABLED=true, 13/13 nhà geocoded, endpoint chạy).
- **Fix DeferredLoadException**: auto-reload khi web redeploy.
- **Redesign quản trị host** (tab "Nhà trọ"): KPI 3 ô (Đã thu/Còn nợ/Lấp đầy) + Quick-Action (Tạo HĐ/Ghi điện nước/Nhắc nợ hàng loạt/Báo cáo) + "Việc cần làm hôm nay" + menu nhóm; mặc định vào tab vận hành; flag `HOST_SINGLE_DASHBOARD` (default OFF, dark-launch bỏ tab lồng — cần QA thiết bị trước khi bật).

## 🔴 BỊ CHẶN — cần chủ dự án
- **Payment core** → 4 quyết định: escrow vs trả thẳng · doanh thu (phí%/gói VIP) · eKYC sớm/muộn · cổng trực tiếp vs aggregator.
- Phí xác minh online (phụ thuộc Payment) · **Notification thật** (creds eSMS/SES) · **FCM push** (firebase-admin) · **eKYC/chữ ký số** (vendor VNPT/FPT/FastCA).
- Blacklist / xử lý review 1★ / mở rộng KCN-công nhân (spec sản phẩm). Slogan/SEO (marketing).

## ⚙️ Vận hành (QUAN TRỌNG khi làm ở máy khác)
- **Deploy web** = `flutter build web --release` (dùng image `ghcr.io/cirruslabs/flutter:stable`, mount repo). `build/web` **mount vào container `ancu365-web` → LIVE ngay**. Kiểm: `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3030/`.
- **Deploy backend** = `bash scripts/observability/deploy_backend.sh` (blue/green-lite + health-check + auto-rollback). **Bị auto-mode classifier GATE** → cần người ủy quyền RÕ RÀNG.
- **Migration prod** = `docker run --rm --network faceconst_default -v $PWD:/app -w /app -e PYTHONPATH=/app ancu365-backend:local sh -c 'DATABASE_URL=$(sed -n "s/^DATABASE_URL=//p" .env|tr -d "\"") alembic upgrade head'`. **PHẢI có `--network faceconst_default`** (DB host `faceconst-db`). Thứ tự an toàn: **migration → verify cột → deploy backend → build web**. Migration **additive-only** + có `downgrade()`.
- **Tests backend**: `docker run --rm -v $PWD:/app -w /app ancu365-backend:local bash -c "pip install -q pytest pytest-postgresql; pytest -q"` (conftest dùng DATABASE_URL giả + FakeSession → không đụng prod). Hiện ~1255 pass.
- **Flutter analyze**: `docker run ... ghcr.io/cirruslabs/flutter:stable ... flutter analyze <files>`.
- SQLite full-chain migration FAIL ở `0001_planning_reports` (postgres-only) — bình thường; test migration mới bằng cách so pattern với migration đã live, KHÔNG chạy full chain trên sqlite.

## 📌 Gotchas
- Router có pydantic body qua decorator (limiter) → KHÔNG dùng `from __future__ import annotations` (vỡ forward-ref).
- Thêm cột vào `houses` → PHẢI chạy migration trước khi deploy backend, nếu không mọi query houses vỡ.
- Có process/automation khác cũng commit+push 2 repo này (thấy commit lạ) — luôn `git fetch` + stage CHỌN LỌC (đừng `git add -A`, dễ gom nhầm việc dở của người khác).
