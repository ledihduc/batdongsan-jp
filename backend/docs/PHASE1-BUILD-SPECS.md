# Phase 1 — Đặc tả kỹ thuật (turnkey build specs)

Mọi tính năng: **migration additive-only**, **flag env mặc định OFF** (trừ loan/compare vô hại), **provider stub mặc định**, **fallback 2 code-path**. Gate bằng dependency kiểu `deps.require_geo_search()` (404/503).

---

## 1. Payment core + Đặt cọc online  — Effort L  — ⚠️ cần credential + review bảo mật

### Flag & provider
`config.py`: `payments_enabled: bool = False`, `payment_provider: str = "stub"` (`stub|vnpay|momo|zalopay`), + env key/secret mỗi cổng (đặt sẵn rỗng).

### Data model (migration additive)
Bảng MỚI (không đụng bảng `payments` cũ = thu tiền trọ thủ công):
```
payment_transactions(
  id, provider, provider_txn_ref (UNIQUE), idempotency_key (UNIQUE),
  amount_vnd BIGINT, status ENUM(pending|authorized|paid|failed|refunded|expired),
  related_type ENUM(viewing_deposit|reservation|invoice|listing_boost),
  related_id, user_id, signature_verified BOOL, raw_callback_json JSONB,
  created_at, paid_at, expires_at
)
payment_refunds(id, txn_id FK, amount_vnd, reason, status, created_at)
```

### Backend
- `app/services/payment/`: `PaymentProvider` interface + `vnpay_provider.py`/`momo_provider.py`/`zalopay_provider.py` + `stub_provider.py` (đúng pattern `notification/`). Factory `from_settings()`.
- `app/routers/payments.py`:
  - `POST /api/payments/create` → tạo txn (idempotency_key), trả redirect URL / deeplink / VietQR.
  - `POST /api/payments/{provider}/ipn` (webhook) → **verify chữ ký HMAC/RSA của cổng**, idempotent theo `provider_txn_ref`, cập nhật status. Trả ack đúng format cổng yêu cầu.
  - `GET /api/payments/{id}/status` → cho client polling.
- Đặt cọc: gắn txn vào `viewing_appointments`/`reservation` qua `related_type/related_id`; dùng slot service (mig 0041) chống double-hold.

### Bảo mật / pháp lý (BẮT BUỘC)
- **PCI-DSS SAQ-A**: chỉ redirect/hosted checkout — TUYỆT ĐỐI không nhận/ lưu số thẻ.
- **Verify chữ ký IPN** trước khi tin callback (chống giả mạo credit).
- **Idempotency** theo `provider_txn_ref` + `idempotency_key` (chống double-credit khi cổng gửi IPN nhiều lần).
- **Giai đoạn đầu: trả THẲNG chủ nhà** (platform chỉ ghi nhận) — giữ hộ tiền (escrow) chạm quy định trung gian thanh toán/NHNN → chỉ làm khi có giấy phép. (QUYẾT ĐỊNH #1 của chủ dự án.)
- Log txn có PII → chạy qua redaction (pipeline observability đã có).

### Flutter
`lib/features/payment/`: `DsPaymentSheet` (bottom-sheet: dòng tiền, chọn cổng, khối trust/escrow, chính sách hoàn), mở URL bằng `url_launcher`/deeplink, màn return + polling status. Dark-launch `--dart-define PAYMENTS=off`.

### Test
Unit: verify chữ ký IPN (case hợp lệ/giả mạo), idempotency (gửi IPN 2 lần → 1 credit), state machine. Stub provider cho CI. Smoke IPN riêng trong `regression_smoke.sh`.

---

## 2. Saved-search + Cảnh báo giá  — Effort M

### Flag
`saved_search_enabled: bool = False`.

### Data model (additive)
```
saved_searches(id, user_id, name, filters_json JSONB, created_at, last_run_at)
price_alerts(id, user_id, saved_search_id NULL, house_id NULL,
             threshold_vnd BIGINT NULL, channel ENUM(push|email), last_notified_at)
```

### Backend
- `app/routers/saved_search.py`: CRUD `/api/saved-searches` (gate flag).
- **Job APScheduler** (tái dùng scheduler của planning ETL): định kỳ chạy từng saved-search qua `house_search_service` → so `last_run_at` → tin mới/giá đổi khớp → gọi `NotificationService` (cần #3). Idempotent theo `last_notified_at`.

### Flutter
Nút "Lưu tìm kiếm này" ở màn kết quả filter; tab "Lưu & Theo dõi" gộp wishlist + saved-search + compare; badge "N tin mới".

### Phụ thuộc
Notification hoàn thiện (#3) để alert tới push/email thật.

---

## 3. Hoàn thiện Notification (eSMS/SES + FCM push thật)  — Effort M

Khung + provider stub + FCM client (`fcm_service.dart`) **đã có**. Việc còn lại = điền HTTP thật:
- **eSMS/SES**: điền HTTP call trong `sms_service.py`/`email_service.py` (env `esms_api_key`, `ses_region`... đã có). Đổi `notification_*_provider = esms|ses`. Đăng ký SMS brandname; opt-out; PDPL consent marketing.
- **FCM push thật**: hiện `channel=push` trả `sent_stub`. Cần:
  - Bảng `device_tokens(user_id, token UNIQUE, platform, created_at, last_seen)`.
  - Endpoint `POST /api/devices/register` (Flutter `fcm_service.dart` đã lấy token).
  - Tích hợp `firebase-admin` (thêm requirement) gửi thật; xử lý token invalid/bounce → xoá; cập nhật `Notification.delivery_status` (cột đã có).
  - SES bounce webhook → `delivery_status='bounced'`.

---

## 4. Bật Geo-search — Effort S — Runbook

Code + migration 0037 đã có. Chỉ vận hành (KHÔNG code):
1. **Backfill toạ độ** (⚠️ ghi prod DB — cần chủ dự án duyệt): `python scripts/backfill_geocode.py` + `python scripts/backfill_province_code.py` (gọi Nominatim, tôn trọng rate-limit 1 req/s).
2. **Verify** GIST index trên `houses.geom` + trigger đồng bộ geom tồn tại: `\d+ houses` trên psql.
3. **Bật flag**: set `GEO_SEARCH_ENABLED=true` trong `.env`, redeploy backend (canary).
4. **QA**: `/api/houses/search-nearby?lat=..&lng=..&radius_km=..` trả kết quả sort theo khoảng cách; nhánh nearby của `/api/houses` hoạt động.
5. **Flutter**: `--dart-define` bật UI "Tìm quanh đây" (geolocator đã có).

Rollback: set flag=false → endpoint ẩn (404), fallback text search.

---

## Quick-wins đã BUILD sẵn (flag, chưa deploy)
- **Loan calculator**: `POST /api/tools/loan-calculator` — stateless, dư nợ giảm dần + trả đều. Flag `loan_calculator_enabled=True`. Không migration.
- **So sánh BĐS**: `GET /api/houses/compare?ids=1,2,3` — read-only, reuse `house_to_dict`. Flag `compare_enabled=True`. Không migration.
