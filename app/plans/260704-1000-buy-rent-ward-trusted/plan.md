# Plan — Mua–Bán / Cho thuê tabs + Phường/xã trước-sau sáp nhập + Auto-publish + Cờ "Uy tín"

> **Target apps:** `ancu365-app` (Flutter, package `house_booking`) + `ancu365-backend` (FastAPI + PostGIS).
> **Ngày:** 2026-07-04
> **Trạng thái:** **APPROVED 2026-07-04 → Release 1 (F1–F4) đang implement.** F5 (ward picker) defer.
> **Nguồn tổng hợp:** BA doc (`phase-00-ba-requirements.md`) + scout codebase (`reports/scout-buy-rent-ward-approval.md`) + plan geo-search song song (`../260703-2332-geo-search/plan.md`).

## User decisions locked 2026-07-04

| # | Câu hỏi | Chốt |
|---|---------|------|
| Q1 | Tab mặc định | **Cho thuê** |
| Q6/Q7 | Nguồn ward data | HC 2020 (pre) + Nghị quyết 202/2025/QH15 (post). **Codebase đã có `app/data/vn_admin_2025.json` từ Nghị quyết 1171/NQ-UBTVQH15** (nội dung tương đương, 34 tỉnh/~3321 xã) → tái dùng cho post-2025 khi làm F5, không tạo mới. Pre-2025 dataset sẽ generate lúc làm Phase 08. |
| F5 | Ward picker | **Defer** đến sau geo-search Phase 04–05 landed. Release 1 KHÔNG có ward picker. |
| Q9 | Rate-limit POST | **KHÔNG rate-limit**. Chống spam sẽ dựa vào admin "Ẩn tin" 1-click + report abuse (v2). |

## Codebase state (verified 2026-07-04)

- **Geo-search Phase 01–03 đã merged** vào backend (`b11ca7e` app / `78132e0` backend): House có `province_code`, có `admin_units_service.py`, `house_search_service.py`, backfill scripts.
- Vẫn CHƯA có: `transaction_type`, `is_trusted`, `ward_slug` fields — Release 1 sẽ add.

---

## 1. Mục tiêu

4 tính năng gộp thành 1 release, hỗ trợ mở rộng app từ "thuê phòng" sang "mua bán + cho thuê":

| # | Tính năng | Impact |
|---|-----------|--------|
| F1 | Guest home 2 tab: **Mua bán** / **Cho thuê** | Guest UX |
| F2 | Post listing chọn **Đăng bán** hoặc **Đăng cho thuê** | Host UX + data model |
| F3 | **Auto-publish** (bỏ approval gate) + rate-limit 5 tin/24h | Business flow |
| F4 | Admin đánh **cờ "Uy tín"** hiển thị trên khung ảnh | Trust signal |
| F5 | **Phường/xã picker** với toggle **Trước / Sau sáp nhập 01/07/2025** | Search UX + data |

F5 depend on geo-search Phase 04 → xếp thứ tự phù hợp.

---

## 2. Hiện trạng codebase (đã verify)

**Đã có — TÁI DÙNG:**
- Backend: `House` model (`app/models.py:100-138`) — có `status: pending|approved|rejected|hidden`, `price: float`, `listing_type: single|multi_unit`, `product_type: apartment|boarding_house|homestay`, `category_id`.
- Backend router `/api/houses` (`app/routers/houses.py`) — POST default `status='pending'`, GET filter `status='approved'`.
- Provinces service (`app/services/provinces_service.py`) — 63 tỉnh cũ trong `data/vietnam-provinces.json`; đã có fuzzy search không dấu, slug format.
- Flutter `HouseModel` (`lib/data/models/house_model.dart:1-143`) — mirror backend; đã có `distanceKm` (từ geo-search) và `rejectionReason`.
- Flutter `HouseProvider` — infinite scroll, filter theo query/category/price/area.
- Flutter `GuestHomeScreen` (`lib/features/guest/home/guest_home_screen.dart`) — 874 dòng, đã có `_VerifiedBadge` chip nhỏ (chip "XÁC THỰC" xanh) — dùng cho khác mục đích (host verified), KHÔNG dùng lại cho "Uy tín" (cần badge riêng).
- Flutter `ProvincePicker` (`lib/features/planning/widgets/province_picker.dart`) — pattern picker có sẵn.
- Flutter `PostHouseScreen` (`lib/features/host/post/post_house_screen.dart`) — form đăng tin hiện tại.
- Admin screen (`lib/features/admin/admin_home_screen.dart`) — hiện có approve flow, sẽ retrofit thành "trusted-mark" flow.

**Khoảng trống — CẦN LÀM:**
- ❌ `House.transaction_type` chưa có (sale vs rent).
- ❌ `House.is_trusted` + `trusted_at`, `trusted_by_admin_id` chưa có.
- ❌ `House.ward_slug`, `House.ward_slug_legacy` chưa có.
- ❌ Không có bảng/JSON `wards.json` (pre-2025) + `wards-2025.json` + `wards_mapping.json`.
- ❌ Guest home chưa có TabBar/TabController.
- ❌ Post screen chưa có Sale/Rent picker.
- ❌ Không có UI trusted badge cỡ lớn cho khung ảnh.
- ❌ Không có rate-limit `POST /api/houses` (chống spam khi auto-publish).

---

## 3. Locked Decisions (đề xuất, cần user approve trước khi implement)

| # | Quyết định | Nguồn / lý do |
|---|-----------|---------------|
| **D1** | `transaction_type` là cột riêng trên `House`: values `'rent' \| 'sale'`, default `'rent'` (giữ backward-compat). | Rõ ràng, index tốt, filter đơn giản. |
| **D2** | Giá vẫn dùng `price: float` chung, nhưng thêm `price_period: 'monthly' \| 'once'` derived từ `transaction_type` (`rent → monthly`, `sale → once`). Không tách column `sale_price`/`rent_price` để tránh phá schema hiện tại. | Ít migration risk. |
| **D3** | Đổi flow approval: **default `status='published'` khi POST**, không còn 'pending'. Backend API alias: `status=approved` được map thành `status=published` khi filter (backward-compat 100%). Migration `approved → published`, giữ `pending` cho tin nào chưa migrate xong. | Reversible, không phá client cũ. |
| **D4** | Thêm `is_trusted: bool` (default false) + `trusted_at: datetime?` + `trusted_by_admin_id: int?`. Không dùng bảng riêng — 1 flag đủ cho v1. | KISS. |
| **D5** | ~~Rate-limit POST~~ **BỎ theo quyết định user 2026-07-04.** Chống spam v1 dựa vào admin "Ẩn tin" 1-click + report abuse (v2). | User quyết. |
| **D6** | Tab home mặc định = **"Cho thuê"** (giữ hành vi cũ). Tab bar Editorial style, KHÔNG dùng Material default. | Không đảo lộn UX cũ. |
| **D7** | Cờ "Uy tín" là badge riêng (KHÔNG tái dùng `_VerifiedBadge`). Vàng-đỏ Editorial tone, icon `Icons.workspace_premium`, label 'UY TÍN', overlay top-left khung ảnh, padding tránh nút wishlist top-right. Semantics label: 'Tin đã được ancu365 kiểm chứng'. | Rõ semantic, tách rời "host verified" (KYC) và "listing trusted" (moderation). |
| **D8** | Dataset ward: 2 JSON assets riêng — `assets/planning/wards-pre-2025.json` (~10.600 record, ~180KB) + `assets/planning/wards-post-2025.json` (~3.321 record, ~60KB). Mapping trong `assets/planning/wards-mapping.json` (old_slug → new_slug, ~10.600 dòng). Gzip inflate on-demand. | Bundle vẫn <500KB, không phá cold-start. |
| **D9** | Ward picker mặc định **"Sau sáp nhập"** — hợp giấy tờ hiện tại. Toggle 1 tap sang "Trước sáp nhập" khi user cần. | UX hợp thời điểm implement (sau 01/07/2025 đã 1 năm). |
| **D10** | Backend nhận cả `ward_slug` (canonical, new) và `ward_slug_legacy` (old); luôn resolve về canonical để query. Frontend chỉ gửi 1 field `ward_slug` sau khi resolve local. | Đơn giản API. |
| **D11** | Ranking impact của `is_trusted`: **v1 KHÔNG boost** — chỉ hiển thị. Đo A/B sau 4 tuần rồi cân nhắc v2. | Tránh lockdown feedback loop khi admin thiên vị. |
| **D12** | F5 (ward picker) **defer** đến sau geo-search Phase 04 xong (`SearchProvider` + `LocationPicker` sẵn) → tránh conflict merge trên cùng file. | Trình tự thực tế. |
| **D13** | Feature flag `LISTING_V2_ENABLED` (build-time via `--dart-define`). Nếu bật false → giữ nguyên home 1 tab + post form cũ. Rollback nhanh. | An toàn rollout. |

---

## 4. Kiến trúc tổng quan

```
┌───────────────── Flutter (ancu365-app) ─────────────────┐
│ GuestHomeScreen ──▶ TabBar(Mua bán / Cho thuê)          │
│   Tab body: HouseListView(transactionType: sale|rent)   │
│                                                          │
│ SearchOverlay (từ geo-search plan)                       │
│   └── WardPicker(mode: pre|post, provinceSlug)          │
│         └── WardService.load(pre|post) + mapping        │
│                                                          │
│ PostHouseScreen ──▶ TransactionTypePicker (Bán/Thuê)     │
│   └── PriceField(period: monthly/once, label đổi theo)  │
│   └── on submit → POST /api/houses (status=published)   │
│                                                          │
│ HouseCard ──▶ Stack(image + TrustedBadge if isTrusted)  │
│                                                          │
│ AdminHomeScreen ──▶ ListingsReviewTab                    │
│   └── PATCH /api/admin/houses/{id}/trusted              │
└─────────────────────────┬────────────────────────────────┘
                          │ HTTPS
┌─────────────────────────▼───────────────── ancu365-backend ─┐
│ POST /api/houses (status='published', rate-limit 5/24h)     │
│ GET  /api/houses ?transaction_type=&ward_slug=&is_trusted=  │
│ PATCH /api/admin/houses/{id}/trusted  (admin only, audit)   │
│ GET  /api/planning/wards ?province_slug=&edition=pre|post   │
└─────────────────────────┬───────────────────────────────────┘
                          ▼
   PostgreSQL: House.{transaction_type, is_trusted, trusted_at,
                       trusted_by_admin_id, ward_slug,
                       ward_slug_legacy}
   + assets JSON: wards-pre-2025 · wards-post-2025 · mapping
```

---

## 5. Data model deltas

### Backend `House` (`app/models.py:100`)
```python
# NEW columns
transaction_type: Mapped[str] = mapped_column(String(10), default="rent", index=True)
is_trusted: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
trusted_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
trusted_by_admin_id: Mapped[Optional[int]] = mapped_column(
    Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
)
ward_slug: Mapped[Optional[str]] = mapped_column(String(80), index=True, nullable=True)
ward_slug_legacy: Mapped[Optional[str]] = mapped_column(String(80), index=True, nullable=True)

# CHANGED default
status: Mapped[str] = mapped_column(String(20), default="published", index=True)
```

### Migration `0038_listing_v2.py`
- Add 6 columns above.
- Update: `UPDATE houses SET status='published' WHERE status='approved';`
- Composite index: `CREATE INDEX ix_houses_tx_status_trusted ON houses (transaction_type, status, is_trusted);`
- Reversible: `downgrade()` drop cột, revert 'approved'.

### Flutter `HouseModel` (`lib/data/models/house_model.dart`)
```dart
// NEW fields
final String transactionType; // 'rent' | 'sale', default 'rent'
final bool isTrusted;
final DateTime? trustedAt;
final String? wardSlug;
final String? wardSlugLegacy;
```
Update `fromMap`, `toMap`, constructor. Backward-compat: nếu API cũ không trả field → default sensibly.

### `WardModel` (mới)
```dart
class WardModel {
  final String slug;         // canonical (new or old depending on edition)
  final String name;         // 'Phường Trúc Bạch', 'Xã An Khánh'
  final String provinceSlug; // 'ha-noi', 'tp-ho-chi-minh'
  final String? districtSlug; // legacy only — null for post-2025
  final String edition;      // 'pre' | 'post'
  final double? lat, lng;    // optional centroid
}
```

### Assets (mới)
- `assets/planning/wards-pre-2025.json` — array of `{slug, name, province_slug, district_slug, lat, lng}`
- `assets/planning/wards-post-2025.json` — array of `{slug, name, province_slug, lat, lng}` (no district level)
- `assets/planning/wards-mapping.json` — `{ "phuong-truc-bach-hoan-kiem-ha-noi": "phuong-ba-dinh-ha-noi", ... }` — old_slug → new_slug
- Update `pubspec.yaml` assets section.

---

## 6. Phases

| # | Phase | Priority | Effort | Depends on |
|---|-------|----------|--------|------------|
| **00** ✅ | BA requirements | P0 | 0.5 ngày | — |
| **01** | Backend: migration `0038` (6 columns) + POST default 'published' + `status=approved` alias | P0 | 0.75 ngày | 00 |
| **02** | Backend: `/api/houses` filter mở rộng (`transaction_type`, `ward_slug`, `is_trusted`) + `PATCH /api/admin/houses/{id}/trusted` + audit log | P0 | 1 ngày | 01 |
| **03** | Flutter data layer: `HouseModel` fields, `HouseProvider.transactionType` state, repository update | P0 | 0.5 ngày | 02 |
| **04** | Flutter home: `GuestHomeScreen` TabBar (Mua bán / Cho thuê), tab state cache, Editorial tone | P1 | 1 ngày | 03 |
| **05** | Flutter post: `TransactionTypePicker` widget + `PostHouseScreen` retrofit, price label theo type, feature flag `LISTING_V2_ENABLED` | P1 | 1 ngày | 03 |
| **06** | Flutter admin: `TrustedMarkScreen` (list published + toggle), audit trail hiển thị. Retrofit `admin_home_screen.dart` | P1 | 1 ngày | 02 |
| **07** | Flutter trusted badge widget (`DsTrustedBadge`) + integrate vào `HouseCard`/`_VerifiedBadge` neighbours ở guest home + house detail + my_listings | P1 | 0.5 ngày | 03 |
| **08** | Ward data: prepare `wards-pre-2025.json`, `wards-post-2025.json`, `wards-mapping.json` (từ nguồn nhà nước 2020 + Nghị quyết 2025); pubspec asset registration | P2 | 1 ngày | — (parallel) |
| **09** | Backend: `/api/planning/wards?province_slug=&edition=` endpoint + slug resolver (legacy → canonical) | P2 | 0.5 ngày | 08 |
| **10** | Flutter ward: `WardService` + `WardPicker` widget + toggle Pre/Post + integrate vào SearchOverlay (từ geo-search) | P2 | 1.5 ngày | 08, 09, geo-search phase 04–05 |
| **11** | Tests + QA: unit test HouseModel/WardModel/HouseProvider, backend pytest cho transaction filter + trusted PATCH, migration up/down test | P0 | 1 ngày | 01–07 |
| **12** | Rollout: feature flag on staging → beta users → prod. Monitor rate-limit, spam metrics, trusted coverage | P0 | 0.5 ngày | 11 |

**Tổng ước tính:** ~10.5 ngày dev (1 fullstack). Đường tới hạn: 01 → 02 → 03 → 04/05/06/07 → 11 → 12. Phase 08–10 (ward) chạy song song, không chặn v1 release.

**Chia release theo priority:**
- **Release 1 (P0+P1, ~7 ngày):** F1 (tabs) + F2 (sale/rent) + F3 (auto-publish) + F4 (trusted badge) → có thể ship sau 1 tuần.
- **Release 2 (P2, ~3 ngày):** F5 (ward picker) → ship sau khi geo-search plan Phase 04–05 landed.

---

## 7. File-level plan

### Phase 01 — Backend migration + rate-limit + status default
**Files to modify:**
- `ancu365-backend/app/models.py:100-138` — add 6 columns to `House`.
- `ancu365-backend/app/routers/houses.py:89-135` (POST) — change `status=body.get("status") or "pending"` → `"published"`. Add `transaction_type` param default `"rent"`.
- `ancu365-backend/app/routers/houses.py:23-40` (GET list) — accept `status=approved` alias, add `transaction_type`, `is_trusted` filters.
- `ancu365-backend/app/main.py` — mount slowapi limiter if not already; POST `/api/houses` decorated `@limiter.limit("5/day")` for non-admin.

**Files to create:**
- `ancu365-backend/alembic/versions/0038_listing_v2.py` — migration.

**Tests:**
- `ancu365-backend/tests/test_houses_listing_v2.py` — POST returns 201 + status=published; rate-limit 6th request in 24h returns 429; `status=approved` alias returns published rows.

### Phase 02 — Backend admin trusted PATCH
**Files to create:**
- `ancu365-backend/app/routers/admin_houses.py` — new router, `PATCH /api/admin/houses/{id}/trusted` body `{is_trusted: bool}`; require admin; write audit row.
- `ancu365-backend/app/schemas/admin_trusted.py` — Pydantic in/out schemas.

**Files to modify:**
- `ancu365-backend/app/main.py` — include router.
- `ancu365-backend/app/audit_models.py` (nếu có) — thêm event `HOUSE_TRUSTED_TOGGLED`.

### Phase 03 — Flutter data layer
**Files to modify:**
- `lib/data/models/house_model.dart` — 5 new fields, `fromMap`/`toMap` update.
- `lib/providers/house_provider.dart` — `transactionType` state, `setTransactionType(String)`, refetch on change.
- `lib/data/services/api_client.dart` (nếu có wrapper) — thêm `transactionType` param cho list.

### Phase 04 — Flutter home tabs
**Files to modify:**
- `lib/features/guest/home/guest_home_screen.dart` — wrap body in `DefaultTabController(length: 2)` + `TabBar(labelStyle: HD.eyebrow(...))` + `TabBarView(children: [_HomeTab(txType: 'sale'), _HomeTab(txType: 'rent')])`.

**Files to create:**
- `lib/features/guest/home/home_tab_view.dart` — reusable body cho 1 tab (extract phần list hiện tại).
- `lib/features/guest/home/tabs_header.dart` — Editorial-style tab bar (không dùng Material default).

### Phase 05 — Flutter post + Sale/Rent picker
**Files to modify:**
- `lib/features/host/post/post_house_screen.dart` — thêm `_transactionType` state, đặt `TransactionTypePicker` đầu form, đổi label giá theo type, validator đổi theo.

**Files to create:**
- `lib/features/host/post/widgets/transaction_type_picker.dart` — chip picker Editorial style.
- `lib/core/config/feature_flags.dart` — thêm `LISTING_V2_ENABLED = bool.fromEnvironment('LISTING_V2_ENABLED', defaultValue: true)`.

### Phase 06 — Flutter admin trusted-mark screen
**Files to modify:**
- `lib/features/admin/admin_home_screen.dart` — thay tab "Duyệt tin" bằng "Đánh dấu uy tín".

**Files to create:**
- `lib/features/admin/screens/trusted_mark_screen.dart` — list houses + toggle switch + confirm dialog + audit view.
- `lib/features/admin/providers/trusted_mark_provider.dart` — state + PATCH call.

### Phase 07 — Flutter trusted badge
**Files to create:**
- `lib/core/widgets/ds_trusted_badge.dart` — chip + icon `Icons.workspace_premium`, palette vàng-đỏ Editorial. Semantics label 'Tin đã được ancu365 kiểm chứng'.

**Files to modify:**
- `lib/features/guest/home/guest_home_screen.dart` — `HouseCard` widget: `Stack` overlay trusted badge top-left nếu `house.isTrusted`.
- `lib/features/guest/house_detail/house_detail_screen.dart` — hero image overlay badge.
- `lib/features/host/profile/my_listings_screen.dart` — badge trên card (chủ nhà cũng thấy).

### Phase 08 — Ward data preparation
**Files to create:**
- `assets/planning/wards-pre-2025.json` — từ danh mục HC 2020 (nguồn: gso.gov.vn + danhmuchanhchinh.gov.vn).
- `assets/planning/wards-post-2025.json` — từ Nghị quyết 202/2025/QH15.
- `assets/planning/wards-mapping.json` — mapping bảng cứng old_slug → new_slug.
- `tools/scripts/generate_ward_data.py` — script generate 3 file từ raw CSV/JSON gov.

**Files to modify:**
- `pubspec.yaml` — thêm `assets/planning/` vào assets section.

### Phase 09 — Backend ward endpoint
**Files to create:**
- `ancu365-backend/app/routers/planning_wards.py` — `GET /api/planning/wards?province_slug=&edition=pre|post` + `GET /api/planning/wards/resolve?legacy_slug=` → canonical.
- `ancu365-backend/app/data/vietnam-wards-pre-2025.json` (copy từ Flutter asset).
- `ancu365-backend/app/data/vietnam-wards-post-2025.json`.
- `ancu365-backend/app/data/vietnam-wards-mapping.json`.

**Files to modify:**
- `ancu365-backend/app/services/provinces_service.py` — thêm `search_wards(province_slug, edition, query)` + `resolve_legacy_ward_slug(slug)`.

### Phase 10 — Flutter ward picker + integrate
**Files to create:**
- `lib/data/services/ward_service.dart` — load asset JSON, cache, search.
- `lib/data/models/ward_model.dart` — as spec above.
- `lib/features/planning/widgets/ward_picker.dart` — segmented control Pre/Post + list + search.
- `lib/features/planning/providers/ward_provider.dart` — state per province.

**Files to modify:**
- SearchOverlay từ geo-search Phase 05 — thêm nút "Chọn phường/xã" nhảy sang WardPicker.
- `HouseProvider.setWardSlug(String)` — filter param.

### Phase 11 — Tests
- Backend: `tests/test_houses_transaction_type.py`, `tests/test_admin_trusted.py`, `tests/test_wards_endpoint.py`.
- Flutter: `test/data/models/house_model_v2_test.dart`, `test/features/guest/home/tabs_test.dart` (widget), `test/features/host/post/transaction_type_picker_test.dart`.

### Phase 12 — Rollout
- Staging deploy → smoke test.
- Beta 10 users → check rate-limit không quá strict.
- Prod deploy behind flag `LISTING_V2_ENABLED=true`.
- Monitor 48h: rate-limit 429 count, trusted PATCH audit count, transaction_type='sale' post count.

---

## 8. Rủi ro & Giảm thiểu

| # | Rủi ro | Giảm thiểu |
|---|--------|-------------|
| R1 | Auto-publish gây spam màn hình chính | Rate-limit 5/24h + admin ẩn tin 1-click + report abuse từ guest (v2). |
| R2 | Ward dataset (~250KB assets) làm bundle Flutter phình | Gzip on-demand; chỉ inflate JSON của tỉnh user chọn. |
| R3 | Mapping old→new ward sai/thiếu ~10% | UI show fallback "Phường này đã đổi tên"; không crash. Log tỉ lệ mismatch. |
| R4 | Change `status` default 'pending'→'published' phá report/analytics cũ | Migration reversible + alias `approved` cho 4 tuần → deprecate. Note changelog rõ. |
| R5 | Admin trusted flag bị lạm dụng | Audit log every toggle; super-admin review dashboard (v2). |
| R6 | Rent user quen home 1 mode, tab bar phá muscle memory | Tab "Cho thuê" default + tab bar sticky top → chỉ 1 tap thêm. Đo CTR/DAU sau 2 tuần. |
| R7 | Conflict merge với geo-search plan trên `HouseModel` + `HouseProvider` + `guest_home_screen.dart` | Serialize: chạy Phase 01–07 (release 1) TRƯỚC khi merge geo-search Phase 04–05; F5 defer đến sau. |
| R8 | Feature flag misconfig ở prod | Default `true` nhưng có kill-switch qua env; smoke test bật-tắt trước release. |

---

## 9. Definition of Done (v1 = Release 1)

- Guest home hiển thị 2 tab "Mua bán" và "Cho thuê", tab Cho thuê default.
- Chủ nhà đăng tin chọn được Bán / Cho thuê; label giá đổi theo.
- Sau POST /api/houses → tin xuất hiện ngay trên guest search (không cần admin).
- Admin đánh cờ "Uy tín" → badge hiển thị trên khung ảnh của tin.
- Rate-limit 5 tin/24h/user hoạt động (429 khi vượt).
- `/api/houses?status=approved` vẫn hoạt động (backward-compat).
- Migration reversible (up + down test xanh).
- Widget test + backend pytest xanh.
- `dart analyze lib/`: 0 errors.
- Manual AC checklist (AC-1..AC-6) pass.

## 9b. Definition of Done (v2 = Release 2 — Ward picker)

- Ward picker mở từ SearchOverlay.
- Toggle Pre/Post đổi list ngay.
- Chọn ward pre-2025 → chip "(nay thuộc: X)" hiển thị dưới.
- Search API `?ward_slug=` filter chính xác.
- 3 assets JSON có trong bundle.

---

## 10. Ngoài phạm vi (v1+v2)

- KHÔNG làm hệ thống chấm điểm uy tín tự động (v3+).
- KHÔNG làm A/B ranking dựa trên trusted.
- KHÔNG auto-verify listing qua KYC / giấy tờ.
- KHÔNG multi-select ward.
- KHÔNG heatmap giá bán/thuê theo phường.
- KHÔNG gói VIP / boost tin.
- KHÔNG dịch dữ liệu ward sang tiếng Anh / dân tộc.

---

## 11. Chỉ số thành công (4 tuần đầu)

- Sale tab adoption: ≥15% guest DAU.
- Sale post ratio: ≥10% tin đăng mới.
- Publish latency p95: <5s.
- Trusted badge coverage: ≥30% tin top-viewed.
- Ward search usage: ≥40% search có ward_slug (sau Release 2).
- Rate-limit 429 rate: <2% POST (điều chỉnh nếu >5%).
- User retention 7d: không giảm >5% baseline.

---

## Phụ lục — file phase

- `phase-00-ba-requirements.md` ✅ (this bundle)
- `phase-01-backend-migration-rate-limit.md` (tạo sau approve)
- `phase-02-backend-admin-trusted-endpoint.md`
- `phase-03-flutter-data-layer.md`
- `phase-04-flutter-home-tabs.md`
- `phase-05-flutter-post-transaction-picker.md`
- `phase-06-flutter-admin-trusted-mark.md`
- `phase-07-flutter-trusted-badge-widget.md`
- `phase-08-ward-data-preparation.md`
- `phase-09-backend-ward-endpoint.md`
- `phase-10-flutter-ward-picker.md`
- `phase-11-tests-qa.md`
- `phase-12-rollout.md`

Các file phase chi tiết sẽ được tạo NGAY sau khi user approve plan này để tránh làm tràn context.
