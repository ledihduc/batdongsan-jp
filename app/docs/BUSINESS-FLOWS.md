# Luồng nghiệp vụ đầy đủ — ancu365

> ⚠️ **Kiểm lại bằng code trước khi tin tài liệu này.** Bản 18/07 từng mô tả
> trạng thái TRƯỚC ngày 14/07 và khiến chính tôi lập kế hoạch sai (báo nhầm 2
> "khoảng hở" thực ra đã được giải quyết). Đã rà lại ngày 19/07 — nhưng code
> vẫn đi nhanh hơn tài liệu.

> Tài liệu BA tổng hợp từ điều tra codebase (backend `ancu365-backend`, frontend `ancu365-app`) — 2026-07-14.
> Bản đồ **VAI TRÒ × CỤM CHỨC NĂNG**, luồng nghiệp vụ từng bước, kèm màn hình + endpoint + guard.
> Quy ước: `[K]` khách chưa đăng nhập · `[U]` user đã đăng nhập · `[H]` chủ nhà · `[A]` admin · `[O]` operator (uỷ quyền) · `[C]` đơn vị thi công.

---

## PHẦN I — BẢN ĐỒ VAI TRÒ

### 1. Ba vai trò BỀN VỮNG trong JWT/DB (`User.role`)
Chuẩn hoá theo `ancu365-app/docs/role-model.md` (Locked, "Option A — 3 trục độc lập"). `User.role` **chỉ** nhận `{guest, host, admin}`.

| Role | Đại diện | Trạng thái |
|---|---|---|
| **guest** — Khách thuê | Mặc định mọi tài khoản mới. Tìm/xem nhà, đặt lịch xem, wishlist, chat, gửi RFQ thi công, feed cộng đồng. | Đầy đủ |
| **host** — Chủ nhà | Đăng tin BĐS + quản lý cho thuê (toà nhà/phòng/hợp đồng/hoá đơn/công tơ/tạm trú/homestay/báo cáo). | Đầy đủ |
| **admin** — Quản trị | Siêu quản trị = super-host + super-operator: duyệt tin, quản lý user, thẩm định, điều phối marketplace, moderation. | Đầy đủ |

### 2. Vai trò PHÁI SINH / khái niệm nghiệp vụ (KHÔNG nằm trong `User.role`)

| Khái niệm | Cơ chế | Trạng thái |
|---|---|---|
| **operator** (Đại lý quản lý — uỷ quyền) | Người được **chủ nhà uỷ quyền** quản lý BĐS hộ. Không phải JWT role — là "actor context" phái sinh từ **delegation đang active**, xác thực qua header `X-Acting-As-Delegation-Id`. | Hạ tầng đầy đủ; **auto-land bị dark-launch tắt** (`roleShellsV2Enabled=OFF`) — chỉ vào qua deep-link FCM/redirect. |
| **operator điều phối thi công** | Điều phối lead thi công dùng `require_admin`; quyền nhà thầu kiểm bằng **ownership** (`_own_contractor_or_admin`), không bằng JWT role. | ✅ Thiết kế đã chốt (role-model "Option A", 14/07). |
| **contractor** (đơn vị thi công) | **Bản ghi dữ liệu** trong bảng `contractors` (liên kết `user_id`, có `status` pending/active). Quyền kiểm bằng ownership, KHÔNG bằng JWT role. `require_contractor` là **code chết**. | Đầy đủ (qua ownership). |
| **tenant** (người thuê đăng nhập) | Login qua email deep-link + JWT tenant riêng để xem hợp đồng/hoá đơn. | **CHƯA XÂY (deferred "U2")** — `hasTenantJwt=false`, mọi `/tenant/*` redirect về `/`. |

### 3. Gán & xác định role
- **Đăng ký:** LUÔN ép `role="guest"` (whitelist chống leo thang) — `auth_router.py:35`.
- **Auto-upgrade guest→host (2 đường):** (a) tự động khi **đăng tin đầu tiên** → set `role=host`, tạo `HostProfile`, trả JWT mới (`houses.py:367`); (b) chủ động `POST /api/host/upgrade-to-host`.
- **Đổi role:** chỉ **admin** PATCH được, trong `{guest,host,admin}` (`users.py:69`). Admin **không** hạ được xuống host (chống tự duyệt).
- **Persona/mode (khách↔chủ nhà):** trục UI riêng (`kModeGuest`/`kModeHost`), lưu bền; toggle ở tab Cá nhân, chỉ hiện khi `role ∈ {host,admin}`. Không đổi JWT.
- **DisplayedRole (client):** ưu tiên `admin > operator_(có delegation active) > host > guest`; `tenant` tách riêng (chưa dùng).
- **Trạng thái tài khoản:** chỉ `User.is_active` (True/False). Khoá tài khoản = `is_active=False`. Không có enum banned/locked.

### 4. Feature flags then chốt (mặc định)
- **BẬT:** `social_enabled`, `quality_rating_enabled`, `verification_enabled`, `leads_enabled`, `loan_calculator_enabled`, `compare_enabled`, `client_logs_enabled`; FE `guestBrowse`, `redesignV2`, `worldSplit`, `listingV2Enabled`.
- **TẮT (dark-launch, prod có thể override):** `construction_enabled`, `contractor_marketplace_enabled`, `industrial_re_enabled`, `geo_search_enabled`; FE `saleEnabled`, `superAppNav`, `roleShellsV2Enabled`, `tenantShellEnabled`, `hostSingleDashboard`.
- ⚠️ Theo memory dự án, **mảng Thi công + redesign v2 đã shipped LIVE** ở prod (env override `construction_enabled=True`).

---

## PHẦN II — 16 CỤM CHỨC NĂNG (BACKEND)

| # | Cụm | Router chính | Guard chủ đạo |
|---|---|---|---|
| 1 | Xác thực & tài khoản | auth_router, users, preferences | public / require_user / require_admin |
| 2 | Danh mục & Geo master | catalog | public |
| 3 | Sàn BĐS (tin, tìm kiếm, thẩm định, đặt xem) | houses, booking_availability, quality_rating, verification, viewing_appointments, wishlists, reviews | optional_user / require_user / require_host / require_admin |
| 4 | Quản lý cho thuê (host suite) | host_building/room/contract/tenant/service_fee/meter/invoice/khai_bao/report/analytics/sources/dashboard | require_host |
| 5 | Homestay / OTA / Marketplace sync | host_homestay, guest_reservation, marketplace_integration | require_host / resolve_actor_context |
| 6 | Trang công khai theo token | public_invoice, public_khai_bao | token (không auth) |
| 7 | Thi công / dịch vụ | construction | optional_user / require_user / require_operator / require_admin |
| 8 | Cộng đồng / Social | social | optional_user / require_user |
| 9 | Thông báo & Chat / WS | notifications, chat, ws | require_user |
| 10 | Quy hoạch / Bản đồ | planning, planning_tiles | public / require_admin (+PostGIS) |
| 11 | Uỷ quyền vận hành (Delegation) | delegation | require_host / require_user |
| 12 | KYC / Định danh | kyc | host / admin |
| 13 | Duyệt hành động uỷ quyền (Approval) | approval | resolve_actor_context |
| 14 | Chủ sở hữu mất / thừa kế | owner_death | require_user / require_admin |
| 15 | Admin & kiểm duyệt | admin_houses, admin_dashboard/delegations/disputes/retention, verification | require_admin |
| 16 | Công cụ + Observability + Upload | tools, client_logs, upload | public / require_user |

---

## PHẦN III — LUỒNG NGHIỆP VỤ THEO VAI TRÒ

### A. KHÁCH CHƯA ĐĂNG NHẬP `[K]` (browse-first, `guestBrowse=ON`)

**A1. Khám phá & tìm nhà**
1. Mở app → onboarding (3 slide, lưu `onboarding_done`) → (redesign v2) khảo sát phân loại `IntroSurveyScreen` → suy ra "thế giới mặc định" → GuestShell.
2. Trang chủ (`GuestHomeScreen`, thế giới BĐS): feed nhà kiểu Facebook. Gõ tìm kiếm, chọn danh mục, bộ lọc nâng cao (khu vực/giá/diện tích/phòng ngủ), "Quanh đây" (định vị) — `GET /api/houses`, `search-nearby`.
3. Mở chi tiết (`HouseDetailScreen`): ảnh, thông số, mô tả, review, badge quy hoạch, chủ nhà (SĐT đã mask), copy link chia sẻ — `GET /api/houses/{id}`, reviews.
4. Bản đồ (`/map`): marker nhà; toggle sang Quy hoạch (`PlanningMapScreen`) tra thửa đất, tile Martin/OSM.
5. So sánh / công cụ: "Tính khoản vay" (chỉ tin bán + `saleEnabled`), So sánh BĐS (từ Wishlist).

**A2. Hành động cần đăng nhập** → chặn bằng `GuestGate.requireAuth` (bottom-sheet mời đăng nhập → `/login`):
- Lưu tin (wishlist), Đặt lịch xem nhà, Nhắn tin chủ nhà, Đăng bài cộng đồng/like.
- ⚠️ **Không nhất quán:** một số màn cộng đồng (`social_feed`, `community_block`, `post_comments`) dùng SnackBar "Vui lòng đăng nhập" thay vì GuestGate.

**A3. Thi công (thế giới Construction)**
1. Feed thi công (`ConstructionWorldBody`): gộp bài cộng đồng + showcase đơn vị + RFQ; story đơn vị nổi bật; tab ngành (Tất cả/Thiết kế/Xây dựng/Nội thất/Công nghiệp) — `GET /api/construction/feed`.
2. Danh bạ + Bảng xếp hạng đối tác + Hồ sơ đơn vị (portfolio, review).
3. **Gửi RFQ (yêu cầu báo giá) — KÊNH DUY NHẤT khách vãng lai gửi dữ liệu không cần login:** `rfq_sheet` chỉ cần Tên + SĐT → `POST /api/construction/leads`. ⚠️ Fail-silent (luôn báo "Đã gửi" kể cả backend lỗi).

---

### B. KHÁCH ĐÃ ĐĂNG NHẬP `[U]`

**B1. Đặt lịch xem nhà (end-to-end)** — xem luồng xuyên vai trò IV-2.
- `ScheduleBookingScreen`: chọn ngày + slot 1h (`GET /available-slots`) + lời nhắn → `POST /api/viewing-appointments` (chống trùng slot).
- Theo dõi: `BookingHistoryScreen` (Chờ duyệt/Đã duyệt/Hoàn thành) → `BookingDetailScreen`: hủy, gọi/nhắn host (khi approved), viết đánh giá (khi completed).

**B2. Yêu cầu dịch vụ thi công của tôi** (`MyServiceRequestsScreen`): xem leads đã gửi, so sánh báo giá, **chấp nhận báo giá** (`POST /quotes/{id}/accept`), đánh giá đơn vị.

**B3. Tài khoản cá nhân** (`ProfileScreen`): sửa hồ sơ + avatar (upload), đổi mật khẩu, "Sở thích của tôi" (khảo sát), Tin đã đăng, Lịch hẹn, Yêu thích. Persona switcher / CTA "Trở thành chủ nhà".

**B4. Cộng đồng & Chat:** đăng bài (tối đa 10 ảnh + chuyên mục + địa danh), like, bình luận đa cấp; nhắn tin 1-1 realtime (WebSocket `/ws`); thông báo (booking/social → deep-link).

---

### C. CHỦ NHÀ `[H]` (persona "Chủ nhà"; bottom-nav: Tổng quan / Nhà trọ / Yêu cầu / Cá nhân)

**C1. Trở thành chủ nhà**
- Nhanh: đăng tin đầu tiên → auto-upgrade role=host (dialog xác nhận).
- Bài bản: `BecomeHostIntroScreen` → Step1 thông tin (`POST /upgrade-to-host`) → Step2 CCCD (upload) → Step3 ngân hàng (`PATCH /host/profile`) → bootstrap role=host.

**C2. Đăng & quản lý tin đăng** (`HostHomeTinDangTab`, `PostHouseScreen`)
- Đăng/sửa/xoá tin (`POST/PUT/DELETE /api/houses`), đóng 1 phòng, cấu hình khung giờ nhận xem (`HostAvailabilityScreen` → `PUT /houses/{id}/availability`).
- Tự khai chất lượng (`QualityEditorScreen`, 5 tiêu chí, PCCC thiếu → tối đa 3 sao → `PUT /houses/{id}/quality`).
- Duyệt yêu cầu xem nhà (`HostAppointmentsScreen`): Duyệt/Từ chối/Khoá → `PATCH /viewing-appointments/{id}/status`.

**C3. Vận hành nhà trọ (Host suite)** — `HostHomeNhaTroTab` là trung tâm.
1. **Cấu trúc tài sản:** Toà nhà (`BuildingListScreen` → `POST /host/buildings`) → Phòng (`RoomFormScreen`) → bảo trì/nhân bản phòng.
2. **Hợp đồng:** `ContractFormScreen` (nhiều người thuê/roommate, upload CCCD + ảnh bàn giao) → `POST /host/contracts` (nháp) → Kích hoạt/Trả phòng/Chuyển phòng. Gia hạn hàng loạt (`batch-renew`, chưa có UI).
3. **Hoá đơn & thu tiền:** ghi công tơ điện/nước → tạo hoá đơn hàng loạt (`generate-batch`) → gửi → ghi nhận thanh toán → link công khai `/public/invoices/{token}` → nhắc nợ qua Zalo → credit note.
4. **Công nợ:** `DebtAgingScreen` (bucket theo ngày) + nhắc nợ hàng loạt (`BatchReminderScreen`).
5. **Khai báo tạm trú (NĐ 144/2021):** banner urgency (đỏ nếu quá hạn 12h) → `KhaiBaoListScreen` (Chưa khai/Quá hạn/Đã khai) → đánh dấu "Đã khai báo"/"Bỏ qua"; phiếu công khai `/public/khai-bao/{token}`.
6. **Báo cáo & Analytics:** `AnalyticsHomeScreen` (5 KPI + period), xu hướng doanh thu, heatmap lấp đầy, drill-down 4 cấp (phòng→hợp đồng→người thuê→hoá đơn), quản lý nguồn doanh thu; **Export TT200** (yêu cầu `X-Reauth-Token`).
7. **Khách quan tâm (leads, WIP):** `LeadsScreen` — Mục tiêu (đã đặt lịch) / Tiềm năng (wishlist), read-only.

**C4. Homestay / OTA (Phase 07)** (`HomestayHomeScreen`): lịch hợp nhất nhiều phòng, chặn/mở ngày, quy tắc giá (base/weekend/holiday), hàng đợi đặt phòng → Duyệt/Từ chối/Check-in/Check-out/Hủy. Đồng bộ Room→House (`marketplace/sync-status`, publish/unpublish — cần admin duyệt).

**C5. Uỷ quyền cho Operator** (`DelegationInviteScreen`): attestation sở hữu duy nhất → mời email + role preset (operator_full/accountant/viewer) + ngưỡng phê duyệt → `POST /api/delegation-invitations`. Quản lý: tạm dừng/tiếp tục/chấm dứt/sửa ngưỡng. **Hộp phê duyệt** (`ApprovalInboxScreen`): duyệt/từ chối hành động operator; giao dịch ≥50M cần sinh trắc học.

---

### D. ĐƠN VỊ THI CÔNG `[C]` (contractor — qua tài khoản user + bản ghi contractor)

> Gate `construction_enabled` (prod ON). Quyền = ownership (`user_id`), không JWT role.

**D1. Đăng ký kênh đơn vị** (`ProviderHubScreen` → `_OnboardProviderScreen`): tạo hồ sơ (`POST /api/construction/contractors`, status=pending) → admin duyệt (`POST /contractors/{id}/verify`) → active.
**D2. Portfolio & quảng bá:** thêm dự án/ảnh (`/contractors/{id}/projects`), nhận đánh giá, hiển thị trên danh bạ + bảng xếp hạng + story "đơn vị nổi bật".
**D3. Nhận nhu cầu & báo giá:** feed nhu cầu khớp ngành/khu vực (`/my/leads-feed`, SĐT đã che) → gửi báo giá (`POST /leads/{id}/quotes`); hoặc bấm "Báo giá" ngay trên RFQ trong feed thi công (cần có hồ sơ đơn vị).

---

### E. ADMIN `[A]` (đăng nhập → redirect `/admin`)

**E1. Kiểm duyệt tin đăng** (`AdminHomeScreen`, 3 tab): Duyệt / Từ chối (bắt buộc lý do) / Gỡ / Duyệt lại → `PATCH /api/admin/houses/{id}/moderate`. Đánh dấu "tin uy tín" (`AdminTrustedMarkScreen` → `/trusted`).
**E2. Thẩm định chất lượng** (`VerificationQueueScreen`): hàng đợi → kiểm tra thực tế → gắn 1-5 sao verified → `POST /verification/{id}/complete`.
**E3. Rủi ro quy hoạch** (`RiskyListingsScreen`): tin nằm zone rủi ro → `GET /planning/admin/risky-listings`.
**E4. Duyệt đơn vị thi công:** `POST /construction/contractors/{id}/verify`.
**E5. Điều phối lead thi công:** `GET/PATCH /construction/leads` (⚠️ dùng `require_operator` nhưng thực tế chỉ admin).
**E6. Quản trị uỷ quyền/tranh chấp/KYC:** dashboard, force-revoke delegation, suspend/reinstate operator, disputes escalate/resolve, hàng đợi KYC operator (approve/reject GPKD), owner-death verify.
**E7. Quản lý user:** `GET /api/users`, `PATCH /users/{id}` (đổi role, khoá `is_active`).
**E8. Điều tra thị trường** (`MarketResearchScreen`): báo cáo cạnh tranh 10 đối thủ (nội dung tĩnh, chỉ admin).

---

### F. OPERATOR `[O]` (uỷ quyền — hạ tầng đủ, entry chính dark-launch)
1. Nhận lời mời (deep-link FCM `delegation_invited` → `InvitationInboxScreen`) → Chấp nhận → `/operator`.
2. Danh mục chủ nhà uỷ thác (`OperatorPortfolioScreen`) → chọn owner → `enterContext` (header `X-Acting-As-Delegation-Id`) → `OperatorWorkspaceShell` bọc `HostHomeScreen` với banner "Đang đại diện".
3. Thao tác host hộ chủ nhà (theo scope/role_preset/ngưỡng); hành động vượt ngưỡng → tạo Approval cho chủ nhà duyệt.
4. Nhật ký hoạt động (`ActivityFeedScreen` → `/delegations/{id}/audit-log`). Thoát → xoá context.

> ⚠️ Auto-land `/operator` chỉ bật khi `roleShellsV2Enabled=ON` (mặc định OFF). `SharedLoginDisclosureDialog` **chưa nối nav**.

### G. TENANT `[T]` — **CHƯA CHẠY (deferred U2)**
Route `/tenant/report-unauthorized/:id` + `AuthorityBadgeWidget` đã có code nhưng **chưa nối nav** + guard chặn + JWT tenant chưa phát → người thuê hiện dùng trải nghiệm guest.

---

## PHẦN IV — LUỒNG XUYÊN VAI TRÒ (quan trọng nhất)

**IV-1. Đăng tin → duyệt → hiển thị**
`[H]` đăng tin (`POST /houses`, status=pending_review) → `[A]` duyệt/từ chối kèm lý do (`/moderate`) → published → `[K]` xem trên feed/tìm kiếm. Host thấy lý do từ chối; có thể sửa & gửi lại.

**IV-2. Đặt lịch xem → thuê → đánh giá**
`[H]` cấu hình khung giờ → `[U]` đặt lịch (slot 1h, chống trùng) → `[H]` duyệt/khoá → xem thực tế → completed → `[U]` viết đánh giá (`POST /reviews`) → (tuỳ chọn) `[H]` chuyển yêu cầu xem thành hợp đồng (`marketplace/contracts/from-appointment`).

**IV-3. RFQ thi công → báo giá → chọn → đánh giá**
`[K/U]` gửi RFQ (`POST /construction/leads`) → `[C]` thấy trong leads-feed → gửi báo giá → `[U]` so sánh & chấp nhận (`/quotes/{id}/accept`) → sau thi công đánh giá đơn vị. (`[A]` điều phối/gán lead khi cần.)

**IV-4. Vòng đời cho thuê (vận hành)**
Hợp đồng (draft→active) → công tơ → hoá đơn (draft→sent→paid) → công nợ/nhắc Zalo → khai báo tạm trú → báo cáo/analytics → (kết thúc) trả phòng + hoàn cọc.

**IV-5. Uỷ quyền operator**
`[H]` mời (attestation + preset + ngưỡng) → `[O]` chấp nhận → thao tác trong context → hành động vượt ngưỡng → Approval → `[H]` duyệt (biometric nếu ≥50M) → audit log. Admin có thể force-revoke/suspend.

**IV-6. Thẩm định chất lượng (2 lớp sao)**
`[H]` tự khai (`self_star`, PCCC gate ≤3) → yêu cầu thẩm định (`POST /houses/{id}/verification`) → `[A]` kiểm tra thực tế → gắn `verified_star` + badge "Đã thẩm định".

---

## PHẦN V — KHOẢNG HỞ & CHƯA HOÀN THIỆN (từ điều tra, KHÔNG bịa)

| Vấn đề | Chi tiết | Ảnh hưởng |
|---|---|---|
| ~~Role "operator" JWT không tồn tại~~ | **ĐÃ GIẢI QUYẾT (14/07).** `require_operator`/`require_contractor` được gỡ có chủ đích (`app/auth.py:98`). `User.role` chỉ còn `{guest,host,admin}`; điều phối lead dùng `require_admin`, quyền nhà thầu dùng ownership, operator BĐS dùng `resolve_actor_context` (delegation). | Không còn là khoảng hở. |
| **`require_contractor` là code chết** | Định nghĩa nhưng không router nào dùng. | Không ảnh hưởng (dùng ownership). |
| **`tenant` chưa xây (U2)** | JWT tenant chưa phát; route/widget có sẵn nhưng chưa nối nav. | Người thuê chưa có cổng riêng xem hợp đồng/hoá đơn. |
| **Không nhất quán "cần đăng nhập"** | BĐS dùng `GuestGate` (bottom-sheet đẹp); cộng đồng (`social_feed`/`community_block`/`post_comments`) dùng SnackBar. | UX lệch giữa các màn. |
| **RFQ fail-silent** | `rfq_sheet` luôn báo "Đã gửi" kể cả backend 404. | Có thể mất lead âm thầm. |
| **`commission.py` không mount** | 2 endpoint hoa hồng không include trong `main.py`. | Code chết. |
| **Placeholder/TODO** | `AdrReportScreen` (chờ Homestay P07), Profile: Ngôn ngữ (no-op)/Dark mode ("Sắp ra mắt")/Notifications switch (no-op); `post_house` TODO geocoding lat/lng; house detail "Xem tất cả đánh giá" onPressed rỗng. | Tính năng phụ chưa xong. |
| **`SharedLoginDisclosureDialog` / `AuthorityBadgeWidget`** | Chưa được gọi ở đâu (dead code UI). | Luồng operator/tenant chưa khép kín. |
| **Endpoint chưa có UI** | ~~`contracts/batch-renew`, `meter-readings/batch`~~ — **đã kiểm lại 19/07: cả hai ĐÃ được frontend gọi.** Chỉ còn `homestay/` (create) là thật sự thiếu màn. | Kiểm lại bằng code trước khi tin dòng này. |

---

## PHẦN VI — GỢI Ý ƯU TIÊN (từ khoảng hở)
1. ~~**Chốt mô hình operator thi công**~~ — ✅ **XONG 2026-07-14**: 2 endpoint điều phối lead (`construction.py` `/leads` GET/PATCH) đổi `require_operator`→`require_admin` (admin-only rõ ràng, verify guest→403/admin→200); **xoá `require_operator` + `require_contractor`** khỏi `auth.py` (đã thành code chết). Tests role/delegation/marketplace/construction: 382 passed.
2. ~~**Nhất quán hoá "cần đăng nhập"** — dùng `GuestGate` cho cả cộng đồng.~~ — ✅ **XONG 2026-07-14**: `social_feed_screen`, `community_block_screen`, `post_comments_screen` đổi từ SnackBar → `GuestGate.requireAuth` (bottom-sheet đăng nhập nhất quán).
3. ~~**RFQ không fail-silent** — báo lỗi thật khi gửi thất bại.~~ — ✅ **XONG 2026-07-14**: `rfq_sheet._submit` catch → hiện lỗi "Gửi yêu cầu chưa thành công… thử lại" + giữ form (không còn báo "Đã gửi" giả).
4. **Cổng Tenant (U2)** — ✅ **CHỐT 2026-07-14: giữ ngủ đông + gắn nhãn DEFERRED** (`report_unauthorized_operator_screen`, `authority_badge_widget`). Xây thật khi Payment/uỷ quyền go-live. Không xoá (scaffold có giá trị).
5. **Dọn code chết** — ✅ **XONG 2026-07-14 (một phần):** xoá `require_operator` + `require_contractor` (thật sự vô chủ). **GIỮ `commission.py`** — KHÔNG phải dead code: router chưa mount nhưng có service `app/services/commission/` đang chạy (dùng trong `invoice_service`) + test riêng → scaffold monetization chờ Payment. Gắn TODO chờ-nối cho `SharedLoginDisclosureDialog` (operator) + `AuthorityBadgeWidget` (tenant), giữ lại.

> Nguồn: điều tra trực tiếp `ancu365-backend/app/**` và `ancu365-app/lib/**` + `docs/role-model.md`. Số liệu flag/endpoint chính xác tại thời điểm 2026-07-14; kiểm lại `app/config.py` + env prod trước khi coi là chân lý.
