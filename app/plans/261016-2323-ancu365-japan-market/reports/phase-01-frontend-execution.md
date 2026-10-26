# Phase 01 — Core Chintai Frontend: Execution Report

**Date:** 2026-10-16  
**Status:** COMPLETED  
**Tests:** 1772/1772 passed (49 new JP tests)  
**Analyze:** 0 errors, 0 warnings in new files

---

## Files Modified

### Locale / ARB (~150 keys added)
- `lib/l10n/app_vi.arb`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_ja.arb`

### Data Models (created)
- `lib/data/models/jp/jp_rental_terms.dart`
- `lib/data/models/jp/jp_property_info.dart`
- `lib/data/models/jp/jp_station.dart`
- `lib/data/models/jp/jp_listing.dart`
- `lib/data/models/jp/jp_viewing.dart`
- `lib/data/models/jp/jp_application.dart`

### Domain Interfaces (created)
- `lib/domain/repositories/jp/i_jp_listing_repository.dart`
- `lib/domain/repositories/jp/i_jp_viewing_repository.dart`
- `lib/domain/repositories/jp/i_jp_application_repository.dart`
- `lib/domain/repositories/jp/i_jp_station_repository.dart`

### Repositories — Real (created)
- `lib/data/repositories/jp/api_jp_listing_repository.dart`
- `lib/data/repositories/jp/api_jp_viewing_repository.dart`
- `lib/data/repositories/jp/api_jp_application_repository.dart`
- `lib/data/repositories/jp/api_jp_station_repository.dart`

### Repositories — Mock (created)
- `lib/data/repositories/jp/mock_jp_listing_repository.dart`
- `lib/data/repositories/jp/mock_jp_viewing_repository.dart`
- `lib/data/repositories/jp/mock_jp_application_repository.dart`
- `lib/data/repositories/jp/mock_jp_station_repository.dart`

### Tenant Persona (created)
- `lib/features/guest/listing/jp_terms_section.dart`
- `lib/features/guest/listing/jp_property_info_section.dart`
- `lib/features/guest/search/transit_filter_chip.dart`
- `lib/features/guest/search/jp_search_facets_drawer.dart`
- `lib/features/guest/viewing/viewing_request_sheet.dart`
- `lib/features/guest/viewing/viewing_status_screen.dart`
- `lib/features/guest/application/application_wizard_screen.dart`
- `lib/features/guest/application/steps/step1_basic_info.dart`
- `lib/features/guest/application/steps/step2_employer.dart`
- `lib/features/guest/application/steps/step3_guarantor.dart`
- `lib/features/guest/application/steps/step4_documents.dart`
- `lib/features/guest/application/steps/step5_confirm.dart`

### Host Persona (created)
- `lib/features/host/listing_edit/jp_terms_edit_section.dart`
- `lib/features/host/listing_edit/jp_money_matrix_input.dart`
- `lib/features/host/listing_edit/jp_property_info_edit_section.dart`

### Sales Persona (created)
- `lib/features/sales/dashboard_screen.dart`
- `lib/features/sales/viewing_inbox_screen.dart`
- `lib/features/sales/application_queue_screen.dart`

### Chat (created)
- `lib/features/chat/jp_quick_reply_chips.dart`

### Wired into parent screens (modified)
- `lib/features/guest/house_detail/house_detail_screen.dart` — JP sections mounted
- `lib/features/guest/home/guest_home_screen.dart` — JP facets drawer as endDrawer
- `lib/features/chat/chat_screen.dart` — JP quick reply chips mounted
- `lib/core/router/app_router.dart` — 5 JP routes registered (deferred)

### Bug fixes during QA (modified)
- `lib/features/sales/application_queue_screen.dart` — `onTap` → `onPressed` on DsButton
- `lib/features/guest/viewing/viewing_status_screen.dart` — same
- `lib/features/guest/viewing/viewing_request_sheet.dart` — same
- `lib/features/guest/search/jp_search_facets_drawer.dart` — same
- `lib/features/guest/application/application_wizard_screen.dart` — `trailing` → `actions`
- `lib/features/guest/application/steps/step1_basic_info.dart` → step5_confirm.dart — same
- `lib/features/host/listing_edit/jp_property_info_edit_section.dart` — `suffixText` → label append

### Tests (created)
- `test/features/jp/jp_property_info_section_test.dart` — 5 widget tests
- `test/features/jp/jp_terms_section_test.dart` — 5 widget tests
- `test/features/jp/jp_search_facets_drawer_test.dart` — 5 widget tests
- `test/data/repositories/jp/mock_jp_listing_repository_test.dart` — 7 unit tests
- `test/data/repositories/jp/mock_jp_viewing_repository_test.dart` — 6 unit tests
- `test/data/repositories/jp/mock_jp_application_repository_test.dart` — 8 unit tests
- `test/core/router/jp_route_gate_test.dart` — 9 unit tests (VN gate + filter params)

---

## Tasks Completed

- [x] ~150 JP ARB keys in all 4 locale files
- [x] JP data models (rental terms, property info, station, listing, viewing, application)
- [x] Domain interfaces for 4 JP repositories
- [x] Real API implementations (`api_jp_*.dart`)
- [x] Mock implementations with fixture data (`mock_jp_*.dart`)
- [x] JpTermsSection + JpPropertyInfoSection (listing detail)
- [x] JpSearchFacetsDrawer + TransitFilterChip
- [x] ViewingRequestSheet (DraggableScrollableSheet)
- [x] ViewingStatusScreen (`/viewings/:id`)
- [x] ApplicationWizardScreen 5-step (`/applications/:id`)
- [x] Host edit sections (JpTermsEditSection, JpMoneyMatrixInput, JpPropertyInfoEditSection)
- [x] Sales persona screens (dashboard, viewing inbox, application queue)
- [x] JpQuickReplyChips — mounted in ChatScreen when isJapan
- [x] JpSearchFacetsDrawer — wired into GuestHomeScreen endDrawer when isJapan
- [x] Routes registered in app_router.dart (5 deferred JP routes)
- [x] Widget tests: 15 tests across 3 files
- [x] Repository tests: 21 tests across 3 files
- [x] Route gate + filter param tests: 9 tests
- [x] flutter analyze: 0 errors in new files
- [x] flutter test: 1772/1772 passed

---

## Architecture Notes

- All JP widgets gated behind `FeatureFlags.isJapan` (compile-time constant)
- Mock repos hit fixture data; swap for `Api*` when BE Phase 01 ships
- JP routes excluded from VN bundle via `if (FeatureFlags.isJapan)` — Dart tree-shaker removes dead branches in AOT
- `JpSearchFacetsDrawer` mounted as Scaffold endDrawer; `GuestHomeScreen._moBoLocBds()` opens it via `GlobalKey<ScaffoldState>` pattern
- `JpQuickReplyChips` inserts preset text into chat compose field via `onSelect` callback

---

## Remaining / Follow-up

- Search screen (`SearchScreen`) is VN global text search — JP listing browse with filter is via `GuestHomeScreen` + endDrawer. Confirm with PM if a dedicated JP listing browse screen is needed.
- `showViewingRequestSheet()` is created but not yet wired to a trigger button in `HouseDetailScreen` — pending UX decision on CTA placement.
- Real API implementations (`api_jp_*.dart`) ready; swap when backend Phase 01 is live.
- VN regression build: `flutter build web --dart-define=REGION=vn --release` not yet run (Docker build takes ~8min). Run before deploy.
- JP build: `flutter build web --dart-define=REGION=jp --release` not yet run. Run before deploy.
