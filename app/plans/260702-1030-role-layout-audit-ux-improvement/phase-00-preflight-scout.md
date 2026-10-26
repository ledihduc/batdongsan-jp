# Phase 00 — Pre-flight Scout & Assumption Verification

**Priority:** P0 gate | **Status:** pending | **Estimate:** 0.5 ngày | **Depends on:** none — must run BEFORE Phase 01

## Context

Tech Lead review (`reports/tech-lead-review-01-holistic.md` H4) và Backend Contract audit (`reports/tech-lead-review-03-backend-contract.md`) flag: một số assumption trong Phase 01–02 chưa verify với source code / backend thật. Reference verification (`reports/tech-lead-review-04-references-verified.md`) tìm 2 inaccuracy + 1 minor drift.

Chạy Phase 00 để **verify tất cả assumption + line references** trước khi bắt tay code Phase 01. Cost 0.5 ngày, save khả năng phải rework Phase 01 nếu assumption sai.

## Goal

- Verify 100% line reference trong phase-01, phase-02, phase-04 khớp HEAD hiện tại
- Verify backend contract: auto-upgrade guest→host trả JWT mới; delegation lifecycle; tenant JWT
- Confirm 4 unverified assumption từ backend audit (U1–U4)
- Produce short "scout report" attach vào từng phase file

## Verify checklist

### A. Line reference verification (grep + read)

- [ ] `lib/features/guest/post/post_house_screen.dart` exists ✓ (đã verify — pass)
- [ ] `lib/features/guest/profile/my_listings_screen.dart` exists ✓ (đã verify — pass)
- [ ] `lib/features/host/host_home_screen.dart:590–625` `_confirmDelete()` — verify exact line range
- [ ] `lib/features/host/property/screens/building_detail_screen.dart` **có delete button hay không?**
  - Scout finding: **KHÔNG có delete UI**. `deleteBuilding` chỉ tồn tại ở `providers/building_provider.dart:90` và `data/repositories/api_building_repository.dart:57`.
  - Ý nghĩa: Phase 01 phải note "add delete button với role guard" hoặc bỏ file này khỏi target list
- [ ] `lib/features/host/property/screens/contract_terminate_screen.dart` — file tồn tại?
- [ ] `lib/features/host/property/screens/contract_transfer_room_screen.dart` — file tồn tại?
- [ ] `lib/providers/auth_provider.dart:113–131` là logout flow — verify (file 229 dòng total)
- [ ] `lib/providers/actor_context_provider.dart:53–58` `clear()` method — verify
- [ ] `lib/features/guest/guest_shell.dart:203–217` FAB "Đăng tin" — verify (file 415 dòng)
- [ ] `lib/features/guest/post/post_house_screen.dart` line 286 auto-upgrade — verify
- [ ] `lib/core/router/app_router.dart:83–111` redirect logic (file 662 dòng — plan nói 700, chấp nhận drift)
- [ ] `lib/core/router/deferred_route_widget.dart` tồn tại?
- [ ] `lib/core/widgets/empty_state.dart` (**không phải `ds_empty_state.dart`** như Phase 05 note nhầm)
- [ ] `lib/providers/delegation_provider.dart` có `myDelegationsAsOperator` getter
- [ ] `lib/features/operator/workspace/operator_workspace_shell.dart` tồn tại và làm gì (shell hay workspace picker)?

### B. Backend contract verification

- [ ] **U1** — Verify `auth_provider.logout()` **chưa** gọi `ActorContextProvider.clear()` (Phase 02 sẽ add). Backend audit đã confirm — mark verified.
- [ ] **U2 (BLOCKER cho tenant guard)** — Backend có issue tenant JWT chưa?
  - Nếu **có:** tìm claim structure (`contract_id`, `scope`, expiry), pass sang Phase 02 `guardTenantRoutes` implementation
  - Nếu **không:** Phase 02 tenant guard block sau đến khi backend ra tenant JWT (mark Phase 02 partial)
- [ ] **U3** — Backend `User.role` **không có enum constraint** (audit confirm). Nếu Phase 03 chọn Option B → 0.5 ngày backend migration
- [ ] **U4** — Verify backend **không có** check "admin không được approve tin của chính mình" — passing đến user quyết định Phase 03 admin toggle
- [ ] Verify `POST /api/houses` trả JWT mới khi guest đăng tin đầu tiên (audit confirm — passed)
- [ ] Verify 403 response format `{code, message}` (audit confirm — passed)
- [ ] Verify header `X-Acting-As-Delegation-Id` backend check revocation trên mọi endpoint operator dùng

### C. Provider inventory (cho C1 fix trong Phase 02)

- [ ] List tất cả `ChangeNotifierProvider` trong `main.dart` MultiProvider
- [ ] Với mỗi provider hold user-scoped data: check có `clear()`/`reset()` method chưa
- [ ] Confirm 14 provider chưa clear trên logout (state audit finding F1): HouseProvider, DashboardProvider, ReportProvider, BuildingProvider, RoomProvider, ContractProvider, InvoiceProvider, ServiceFeeProvider, MeterReadingProvider, KhaiBaoProvider, DrillProvider, HomestayCalendarProvider, PricingRuleProvider, ReservationProvider, MarketplaceProvider, HostProfileProvider

### D. FCM contract (cho C3 fix trong Phase 02+04)

- [ ] Grep backend `subscribeToTopic`, tìm topic naming convention (`host_$userId`? `role_$userId`?)
- [ ] Verify frontend `NotificationProvider.detachFcm()` có clear topic subscription không (state audit F2 finding: **không** — cần add)
- [ ] Xác định notification categories (booking, contract, invoice, delegation, approval) và mapping category → role

## Deliverable

Output: `plans/260702-1030-role-layout-audit-ux-improvement/reports/phase-00-scout-report.md` — short doc với 3 section:

1. **Verified assumptions** (checklist trên, tick từng cái)
2. **Corrections needed cho phase files** (Phase 01 building delete note, Phase 05 empty_state.dart naming, etc.)
3. **Blockers phát hiện** (nếu tenant JWT chưa ra → Phase 02 tenant guard defer)

## TODO checklist

- [ ] Verify tất cả line reference trong section A
- [ ] Verify 4 backend assumption trong section B
- [ ] Inventory provider trong section C
- [ ] FCM topic contract trong section D
- [ ] Report `phase-00-scout-report.md` published
- [ ] Update phase-01, phase-02, phase-05 nếu có correction (patch inline)

## Success criteria

- 100% line reference verified hoặc corrected
- Backend contract clear cho Phase 01 (guest→host JWT) và Phase 02 (delegation revocation, tenant JWT status)
- Provider inventory ready cho Phase 02 step 5b
- 0 assumption "guess" còn trong plan sau khi Phase 00 xong

## Risk

- **Tenant JWT chưa ra:** Phase 02 tenant guard defer, không blocker overall
- **Backend team unavailable to answer questions:** vẫn có thể grep backend repo local nếu clone; nếu không → mark assumption "unverified" thay vì "verified" và note risk

## Out of scope

- Không code implementation trong Phase 00
- Không refactor gì — chỉ read + verify + document
