# Backoffice quản trị V2 — hợp đồng & vận hành

Admin web chính thức = `ancu365-web/app/admin` (Next.js, container riêng `ancu365-admin`).
Màn Admin Flutter giữ làm **lối tắt khẩn cấp** cho SUPER_ADMIN; không thêm tính năng
admin mới vào Flutter.

## 1. Trục quyền

| Trục | Ý nghĩa | Nơi lưu |
|---|---|---|
| `users.role` | quyền JWT của app (`guest/host/admin`). `admin` ⇔ có vai SUPER_ADMIN (đồng bộ tự động) | `users` |
| `account_type` / workspace | vai NGHIỆP VỤ customer/sale/owner — mọi tài khoản đều mở được | `users`, `business_access.py` |
| **Vai quản trị** | quyền nhân viên backoffice theo hành động | `admin_user_roles` ↔ `admin_role_permissions` |

Nguồn sự thật của danh mục quyền/vai: `app/services/admin_v2/permissions.py`
(`ensure_catalog()` đồng bộ vào DB lúc khởi động — thêm thiếu, gỡ thừa).
Guard `require_permission()` đọc quyền **từ DB mỗi request**, kiểm tài khoản còn
hoạt động và phiên admin chưa bị thu hồi. Bị từ chối → 403 + dòng `permission.denied`.

Endpoint cũ (`/api/admin/*`, `/admin/kyc`, `/api/reels/moderation`…) vẫn chạy cho
Flutter, nhưng `require_admin` nay đọc lại `users.role` từ DB (không tin claim 7 ngày)
→ nhân viên vai hẹp KHÔNG đi được đường cũ.

### Ma trận vai — quyền (sinh từ code)

| Quyền | Mô tả | SUPER_ADMIN | OPS_ADMIN | MODERATOR | SUPPORT | FINANCE | COMPLIANCE | ANALYST | AUDITOR |
|---|---|---|---|---|---|---|---|---|---|
| `dashboard.read` | Xem tổng quan vận hành | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `work_items.read` | Xem hộp việc cần xử lý | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `work_items.assign` | Phân công, đổi ưu tiên, ghi chú việc | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `users.read` | Tra cứu người dùng: SĐT, nơi ở & tình trạng thuê (email/CCCD che) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |  |  |
| `users.reveal_pii` | Xem PII đầy đủ (bắt buộc lý do, có nhật ký) | ✓ |  |  |  |  | ✓ |  |  |
| `users.suspend` | Khoá / mở khoá tài khoản, thu hồi phiên | ✓ |  |  |  |  | ✓ |  |  |
| `users.manage_admin_roles` | Quản lý nhân viên và vai quản trị | ✓ |  |  |  |  |  |  |  |
| `listings.read` | Xem tin đăng | ✓ | ✓ | ✓ | ✓ |  |  |  |  |
| `listings.moderate` | Duyệt / từ chối / gỡ tin | ✓ |  | ✓ |  |  |  |  |  |
| `listings.mark_trusted` | Gắn / gỡ nhãn tin cậy | ✓ |  | ✓ |  |  |  |  |  |
| `content.read` | Xem báo cáo nội dung, Reel, review | ✓ |  | ✓ |  |  |  |  |  |
| `content.moderate` | Xử lý báo cáo, duyệt / ẩn Reel | ✓ |  | ✓ |  |  |  |  |  |
| `verification.review` | Thẩm định sao chất lượng | ✓ |  | ✓ |  |  |  |  |  |
| `rental_journeys.read` | Xem lịch xem, hành trình thuê, booking, hợp đồng | ✓ | ✓ |  | ✓ | ✓ |  |  |  |
| `rental_journeys.override` | Lệnh ngoại lệ trên hành trình / booking | ✓ | ✓ |  |  |  |  |  |  |
| `rental_documents.read` | Mở chứng từ thuê (hợp đồng, ảnh cọc) | ✓ | ✓ |  |  | ✓ | ✓ |  |  |
| `payments.read` | Xem sổ tiền, hoá đơn, hoa hồng, đối soát | ✓ | ✓ |  |  | ✓ |  |  |  |
| `payments.record` | Ghi nhận thanh toán | ✓ |  |  |  | ✓ |  |  |  |
| `payments.refund` | Ghi nhận hoàn tiền | ✓ |  |  |  | ✓ |  |  |  |
| `payments.reconcile` | Đánh dấu đã đối soát / xác minh cọc | ✓ |  |  |  | ✓ |  |  |  |
| `policies.manage` | Thay chính sách cọc | ✓ |  |  |  | ✓ |  |  |  |
| `partners.read` | Xem Sale, nhà thầu, lead, yêu cầu dịch vụ | ✓ | ✓ |  | ✓ |  | ✓ |  |  |
| `partners.review` | Duyệt hồ sơ Sale / nhà thầu, xử lý lead | ✓ |  |  |  |  | ✓ |  |  |
| `kyc.review` | Duyệt KYC doanh nghiệp | ✓ |  |  |  |  | ✓ |  |  |
| `compliance.read` | Xem uỷ quyền, tranh chấp, hồ sơ pháp lý | ✓ |  |  |  |  | ✓ |  |  |
| `disputes.manage` | Xử lý tranh chấp, chủ sở hữu mất | ✓ |  |  |  |  | ✓ |  |  |
| `delegations.force_revoke` | Thu hồi cưỡng bức uỷ quyền, đình chỉ operator | ✓ |  |  |  |  | ✓ |  |  |
| `retention.manage` | Chạy retention / archive, legal hold | ✓ |  |  |  |  | ✓ |  |  |
| `audit.read` | Xem nhật ký quản trị hợp nhất | ✓ |  |  |  |  | ✓ |  | ✓ |
| `system.read` | Xem sức khoẻ hệ thống, push, job, cờ | ✓ |  |  |  |  |  |  |  |
| `settings.manage` | Danh mục, cấu hình tỉnh / quy hoạch | ✓ |  |  |  |  |  |  |  |

Luật đặc biệt:
- Không ai tự đổi vai của chính mình; không thu hồi được SUPER_ADMIN cuối cùng.
- Cấp **SUPER_ADMIN** và **ghi nhận hoàn tiền ≥ 5.000.000 ₫**, **mọi thay đổi chính sách cọc** và **đề nghị thu hồi uỷ quyền** đi qua maker-checker
  (`admin_change_requests`): người tạo ≠ người duyệt.
- Cần **xác thực lại** (≤ 10 phút): cấp/thu vai, đổi chính sách cọc, mở khoá tài khoản
  từng bị báo cáo gian lận, force-revoke uỷ quyền, retention, xác minh chủ sở hữu mất,
  duyệt maker-checker.
- `users.role` không còn đổi được thành/khỏi `admin` qua `PATCH /api/users/{id}`.

## 2. Phiên & bảo mật

- Đăng nhập: `POST /api/v2/admin/auth/login` → token `typ=admin` gắn `sid` (bảng
  `admin_sessions`, 12 giờ). Token admin KHÔNG dùng được cho API app và ngược lại.
- BFF Next.js giữ token trong cookie `vn_admin_session` (HttpOnly, SameSite=Strict,
  Secure). Lệnh ghi qua BFF phải qua kiểm Origin + CSRF double-submit (`vn_admin_csrf`).
- Khoá tài khoản: `is_active=false` + dời `password_changed_at` (mọi JWT app cũ chết)
  + thu hồi mọi phiên admin. Tài khoản bị khoá nhận 403 ở mọi API `require_user`.
- PII che mặc định trong mọi DTO; xem đầy đủ cần `users.reveal_pii` + lý do (log `pii.reveal`).
  **Ngoại lệ (chủ dự án chốt 12/10/2026):** trang Người dùng (`GET /users`, `GET /users/{id}`) trả
  `phone` ĐẦY ĐỦ cho mọi vai có `users.read` — hỗ trợ/vận hành phải gọi được khách. Email, CCCD,
  ngày sinh vẫn che; thẻ người dùng dùng chung ở module khác (`user_brief`) vẫn che SĐT.
- Mỗi người dùng kèm `residence` — "đang trọ ở đâu / ở khâu nào" (`services/admin_v2/residence.py`):
  hợp đồng dài hạn (nối `tenants` theo SĐT/email bằng CHÍNH luật của app,
  `guest_dang_thue.nguoi_thue_cua_nhieu`), lưu trú ngắn hạn, hành trình đang mở, lịch xem sắp tới,
  toà nhà sở hữu. Danh sách chỉ trả `summary`; chi tiết trả đủ kèm lịch sử.
- Chứng từ riêng tư: `POST /api/v2/admin/documents/sign` → URL ký 5 phút; quyền kiểm
  theo nguồn; KYC/CCCD/giấy chứng tử bắt buộc lý do; mỗi lần ký/mở ghi log.
  Đường dẫn file luôn lấy từ DB, client không gửi path.
  Chặn `/uploads` tĩnh với file đã đăng ký: chạy `scripts/migrate_private_uploads.py --apply`
  rồi bật `PRIVATE_UPLOADS_ENFORCED=true` — **chỉ sau khi app Flutter chuyển sang
  `POST /api/v2/documents/sign`** (endpoint cho người tham gia đã có), nếu không người
  thuê/chủ nhà/sale mất ảnh hợp đồng/cọc của chính họ.

## 3. Quy ước API `/api/v2/admin/*`

- Thành công: `{"data": …, "meta": {"generated_at", "request_id", "total", "limit", "cursor", "next_cursor", …}}`.
- Lỗi: `{"error": {"code", "message", "request_id", "details?"}}` (request_id thêm cho mọi API).
- Danh sách luôn phân trang server (`limit` ≤ 100, `cursor`), có bộ lọc; không endpoint nào tải cả bảng.
- Lệnh ghi (`run_command` trong `core.py`):
  - `Idempotency-Key` bắt buộc (428) — gửi lại cùng khoá trả đúng kết quả cũ, không thao tác trùng;
  - `If-Match: <version>` với bản ghi có sẵn (428 thiếu, 409 `ADMIN_CONFLICT` lệch);
  - lý do ≥ 5 ký tự cho thao tác nhạy cảm (422 `ADMIN_REASON_REQUIRED`);
  - nhật ký `admin_action_logs` + sự kiện `admin_events` ghi CÙNG transaction (append-only, trigger chặn UPDATE/DELETE trên Postgres);
  - không có `PATCH {status}` chung — chỉ lệnh nghiệp vụ đi qua domain service; client không gửi actor id.
- Tiền: số nguyên VND; hệ thống chỉ **ghi nhận & đối soát**, `transfer_execution = DISABLED`.
- Realtime: `GET /events/stream` (SSE đọc outbox `admin_events` theo cursor — đúng khi chạy nhiều worker) + `GET /events?after=`; REST luôn là nguồn sự thật, FE poll 30s dự phòng.
- Dashboard: mỗi nhóm có `status ok|stale|error` + `updated_at/last_success_at` — lỗi KHÔNG hiển thị thành 0.

## 4. Hộp việc hợp nhất

`app/services/admin_v2/work_items.py` gom các hàng đợi SẴN CÓ (tin chờ duyệt, báo cáo,
Reel, thẩm định, hồ sơ Sale, nhà thầu, KYC, tranh chấp, chủ sở hữu mất, cọc chờ xác minh,
hành trình kẹt >72h, booking chờ xác nhận, báo cáo trong giao dịch, lead, dịch vụ, push lỗi),
tính hạn SLA và phủ `admin_cases` (người phụ trách, ưu tiên, ghi chú, legal hold).
`admin_cases` KHÔNG thay trạng thái nghiệp vụ. Thêm hàng đợi = thêm một `Source`.

## 5. Deploy & rollback

Trạng thái 12/10/2026: migration `0137` ĐÃ chạy trên DB dùng chung (sao lưu
`backups/ancu365_staging-truoc-0137-admin-v2-20261012-0821.sql.gz`). Tầng STAGING chạy code mới:
`ancu365-backend-staging` = `ancu365-backend:admin-v2-20261012-r2` (:3011) và backoffice
`ancu365-admin` = `ancu365-admin:admin-v2-20261012-r5` (127.0.0.1:3041 → backend staging).
(Bản trước để quay lại: backend `admin-v2-20261012`, admin `admin-v2-20261012-do`.)
Backend LIVE (`ancu365-backend`) còn ảnh cũ — promote sau khi review.

1. Sao lưu DB: `docker exec faceconst-db pg_dump -U faceconst ancu365_staging | gzip > backups/…sql.gz`.
2. Migration additive `0137_admin_backoffice` (11 bảng mới + cấp SUPER_ADMIN cho `role=admin`).
   Rollback: `alembic downgrade 0136_cach_tinh_theo_nguoi` (chỉ xoá bảng mới + trigger append-only).
3. Backend: `docker build -t ancu365-backend:<tag> .` rồi dựng lại container với env cũ
   (`docker inspect … .Config.Env`) + các mount cũ + **mount mới**
   `ancu365-staging/private_documents:/app/storage/private_documents` (kho chứng từ riêng tư —
   không mount là mất khi dựng lại container) + `docker network connect proxy_default` +
   `docker exec proxy-proxymanager-1 nginx -s reload`.
   Rollback staging: dựng lại bằng tag `ancu365-backend:staging-truoc-admin-v2`.
4. Backoffice: `cd ancu365-web && ADMIN_TAG=<tag> ADMIN_URL=https://<host> BACKEND_INTERNAL_URL=http://<backend>:3000 ./deploy-admin.sh`.
   Chưa có DNS cho subdomain admin → xem qua SSH tunnel
   `ssh -L 3041:127.0.0.1:3041 <máy chủ>` rồi mở http://localhost:3041/admin (cookie Secure
   vẫn chạy trên localhost). Gắn tên miền: `npm-admin.conf.example` + cert LE.
5. Kiểm: backend `pytest tests/` (2708 xanh), FE `npx playwright test -c playwright.admin.config.ts`
   (CHỈ chạy trên DB thử `ancu365_admin_dev` — có ghi dữ liệu; môi trường dev:
   container `ancu365-admin-dev-be` :3019 + `/tmp/admindev/start-next.sh` :3040).

## 6. Việc còn mở (cần quyết định nghiệp vụ / hạ tầng)

- **Tên miền backoffice**: `admin.ancu365.ddns.net` không phân giải; `*.digi-lab.vn` là wildcard
  trỏ IP khác. Cần một bản ghi DNS trỏ về máy chủ (hoặc dùng lại `ancu.digi-lab.vn`).
- **Promote backend live** sang `ancu365-backend:admin-v2-20261012` (kèm mount private_documents).
- Hành trình `DISPUTED` không có chuyển trạng thái ra trong domain → admin chỉ xét
  báo cáo (valid/invalid), chưa "giải quyết tranh chấp" được.
- Domain không có bước nền tảng xác nhận cọc APP_DEPOSIT → "xác minh cọc" của admin là
  bản ghi kiểm soát (admin_cases + log), không đổi trạng thái hành trình.
- Không tiến trình nào gửi `push_outbox` → push xếp hàng/thử lại chưa ra khỏi hệ thống.
- `PRIVATE_UPLOADS_ENFORCED` còn TẮT: bật sau khi app Flutter chuyển sang
  `POST /api/v2/documents/sign` và đã chạy `scripts/migrate_private_uploads.py --apply`.
- Hợp đồng HD-00026 trên DB thật đang có tiền cọc 20.250 tỷ ₫ (bug `dat_coc` đã vá ở code
  `tien_coc_hop_dong`, dữ liệu cũ CHƯA sửa).
- Retention cũ (`/api/admin/retention/*` + cron) chưa tôn trọng legal hold; bản V2 có.

## 7. Maker-checker (phê duyệt hai người)

`admin_change_requests`: DRAFT → PENDING → APPROVED | REJECTED | CANCELLED. Loại đã đăng ký:
`grant_admin_role` (cấp/đổi sang SUPER_ADMIN), `refund_record` (hoàn tiền ≥ 5.000.000 ₫),
`deposit_policy` (mọi thay đổi chính sách cọc), `delegation_force_revoke` (đề nghị thu hồi uỷ
quyền từ hồ sơ tranh chấp). Người lập không tự duyệt; người duyệt phải xác thực lại; trang chi
tiết `/admin/work/approvals/{id}` hiện bảng "dự kiến sau khi duyệt" tính lại mỗi lần xem.
