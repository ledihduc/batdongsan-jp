# Phase 01 — Critical Role-Leak Fixes + Widget State Lifecycle

**Priority:** P0 | **Status:** COMPLETE (2026-07-02) | **Estimate:** 1.5 ngày | **Depends on:** Phase 00

## Completion summary

- Created `lib/core/permissions/role_guard.dart` — `RoleGuard`, `RoleGuardWidget`, `PermissionDeniedException`
- Created `lib/core/telemetry/analytics_service.dart` — Q8 stub facade
- Moved `post_house_screen.dart` guest → host, fixed 3 import sites
- Moved `my_listings_screen.dart` guest → host, fixed 1 import site
- Added `RoleGuard.enforceHost` to `_confirmDelete`, `_confirmCloseUnit`, terminate `_submit`, transfer `_submit`
- Added defensive `PermissionDeniedException` throw with optional `actor:` param on `deleteBuilding`, `deleteHouse`, `terminateContract`, `transferRoom`
- FAB reworked: shows for authenticated users on guest home; pure guest gets upgrade confirm dialog before mount
- Post-house widget: pop route on auth session change (F5 draft leak defense)
- Audit log events: `role_upgraded` at auto-upgrade site, `permission_denied` inside `RoleGuard.enforceHost`
- Unit tests: `role_guard_test.dart` (12), `destructive_role_guard_test.dart` (6) — 18/18 pass
- `flutter analyze` on touched files: 0 errors, only pre-existing lints


## Context

Guest folder chứa 2 màn host-only; host destructive actions không có role guard. Đây là fix "code-level" không cần đổi backend hay kiến trúc.

Nguồn: `reports/researcher-01-guest-audit.md` (CRITICAL #1, #2), `reports/researcher-02-host-audit.md` (P0 destructive ops), `reports/tech-lead-review-02-state-lifecycle.md` (F5 form draft leak), `reports/tech-lead-review-04-references-verified.md` (fix inaccuracy #4).

## Requirements

**Functional:**
- Guest role KHÔNG mount/build được PostHouseScreen, MyListingsScreen
- Host destructive actions (`deleteHouse`, `deleteBuilding`, `terminateContract`, `transferRoom`) hard-fail nếu `user.role != 'host' && user.role != 'admin'` — cả UI layer và provider layer
- Auto-upgrade guest→host (server returns new JWT khi guest post first listing) vẫn hoạt động nhưng có confirm dialog "Bạn sẽ trở thành chủ nhà" **(assumption verified in Phase 00 backend audit: POST /api/houses trả JWT mới — pass)**
- **Widget state cleanup:** logout clear TextEditingController draft trong forms — không leak sang user tiếp trên shared device

**Non-functional:**
- Không được đổi API contract
- Backward-compatible với deep-link cũ (`/post-house` etc.)

## Corrections từ Phase 00 scout

- `building_detail_screen.dart` **KHÔNG có delete button** (INACCURATE trong v1 plan). Actual state: `deleteBuilding` chỉ tồn tại ở `providers/building_provider.dart:90` và repository — **không có UI caller nào gọi**.
  - **Decision:** Bỏ file này khỏi "add UI guard" list. Provider-level defensive check vẫn thêm (defense in depth). Nếu tương lai add delete UI, developer phải wrap trong `RoleGuard`.

## Related files

**Move (guest → host):**
- `lib/features/guest/post/post_house_screen.dart` → `lib/features/host/post/post_house_screen.dart`
- `lib/features/guest/profile/my_listings_screen.dart` → `lib/features/host/profile/my_listings_screen.dart`
- Cập nhật tất cả import (grep `guest/post/` và `guest/profile/my_listings`)

**Add role guards (UI layer — pre-action check):**
- `lib/features/host/host_home_screen.dart:590–625` — `_confirmDelete()` (line range verify in Phase 00)
- `lib/features/host/property/screens/contract_terminate_screen.dart` — terminate
- `lib/features/host/property/screens/contract_transfer_room_screen.dart` — transfer
- ~~`lib/features/host/property/screens/building_detail_screen.dart`~~ — **SKIP** (không có UI để guard, đã note trong corrections)

**Add role guards (Provider layer — defense in depth):**
- `lib/features/host/property/providers/building_provider.dart:90` — `deleteBuilding()`
- `lib/features/host/property/providers/house_provider.dart` — `deleteHouse()`
- `lib/features/host/property/providers/contract_provider.dart` — `terminate/transfer`

**Widget guard (shared component):**
- Create `lib/core/permissions/role_guard.dart` — `RoleGuardWidget` component

**Guest shell — auto-upgrade UX:**
- `lib/features/guest/guest_shell.dart:203–217` — FAB "Đăng tin" cần confirm dialog trước khi push PostHouseScreen (line range verify in Phase 00)

**Widget state lifecycle (new v2 — from state audit F5):**
- `lib/features/guest/post/post_house_screen.dart:45–55` — 10 TextEditingController, cần `@override dispose()` + reset trên user change
- Audit host property forms (room_form, contract_form) same pattern

## Implementation steps

1. **Create RoleGuard** (30 phút):
   ```dart
   // lib/core/permissions/role_guard.dart
   class RoleGuard {
     static bool canHost(AuthProvider auth) =>
       auth.currentUser?.role == 'host' || auth.currentUser?.role == 'admin';
     static bool canAdmin(AuthProvider auth) => auth.currentUser?.role == 'admin';
     static void enforceHost(BuildContext ctx, {VoidCallback? onDenied}) {...}
   }
   class RoleGuardWidget extends StatelessWidget { ... }  // fallback UI
   class PermissionDeniedException implements Exception { ... }
   ```
2. **Move files** (45 phút):
   - Di chuyển `post_house_screen.dart` sang `lib/features/host/post/` — cập nhật package path
   - Di chuyển `my_listings_screen.dart` sang `lib/features/host/profile/`
   - Grep + sửa hết import (`import.*guest/post/post_house_screen`, `import.*guest/profile/my_listings`)
   - Router: giữ route `/post-house` (backward compat với deep-link cũ), internally redirect sang path mới
3. **Wrap moved screens với RoleGuardWidget** (30 phút):
   - Guest deep-link `/post-house` → RoleGuardWidget block với message "Bạn cần là chủ nhà để đăng tin"
4. **Add pre-action check trong host destructive dialogs** (1 giờ):
   - `_confirmDelete/_confirmTerminate/_confirmTransfer` — early return + snackbar "Bạn không có quyền" nếu role không hợp lệ
   - Files: `host_home_screen.dart`, `contract_terminate_screen.dart`, `contract_transfer_room_screen.dart`
5. **Add defensive throw trong provider** (30 phút):
   - `building_provider.deleteBuilding`, `house_provider.deleteHouse`, `contract_provider.terminate/transfer` — throw `PermissionDeniedException` nếu role sai
   - Note: Backend PHẢI có authz check tương ứng — defensive throw chỉ là double-guard
6. **FAB "Đăng tin" confirm dialog** (30 phút):
   - Guest role → show dialog "Trở thành chủ nhà: bạn sẽ đăng tin đầu tiên và tự động nâng cấp lên chủ nhà. Tiếp tục?" → OK → mount PostHouseScreen
   - Host role → mount trực tiếp không dialog
7. **Widget state lifecycle** (1 giờ — new v2):
   - `post_house_screen.dart`: add `@override dispose()` — dispose 10 TextEditingController
   - Add key-based rebuild pattern: wrap form container với `key: ValueKey(auth.currentUser?.id ?? 'anonymous')` để rebuild khi user change
   - Audit host forms: `room_form_screen.dart`, `contract_form_screen.dart` — same pattern
   - Test: draft form → logout → login khác → form phải blank
8. **Audit logging** (30 phút — new v2 M5):
   - Auto-upgrade guest→host: log event `role_upgraded` với `{from: guest, to: host, trigger: first_listing}` để security audit
   - Permission denied: log event `permission_denied` với `{action, user_role, required_role}`
9. **Verification** (1 giờ):
   - `flutter analyze` = 0 issues
   - Manual smoke test 5 kịch bản (below)

## Testing (new v2 subsection — from H1 Tech Lead review)

**Unit tests (mandatory nếu chọn testing budget câu 9):**
- `test/core/permissions/role_guard_test.dart`:
  - `RoleGuard.canHost` với 5 role: admin (true), host (true), guest (false), operator/tenant (false — role='guest' with delegation)
  - `RoleGuard.canAdmin` với 5 role: admin (true), rest (false)
- `test/features/host/property/providers/building_provider_test.dart`:
  - `deleteBuilding` throws `PermissionDeniedException` khi role != host/admin
  - Same cho `house_provider.deleteHouse`, `contract_provider.terminate/transfer`

**Widget tests:**
- `RoleGuardWidget` shows fallback UI khi role sai
- FAB "Đăng tin" hiện dialog khi role=guest, mount screen ngay khi role=host

**Smoke tests (manual):**
1. Guest deep-link `/post-house` → RoleGuardWidget block
2. Guest FAB "Đăng tin" → dialog xác nhận nâng cấp
3. Host FAB "Đăng tin" → screen mount ngay
4. Guest draft form → logout → login user khác → form blank (F5 test)
5. Host delete/terminate/transfer → success; guest gọi provider trực tiếp (test unit) → throw exception

## TODO checklist

- [ ] Tạo `lib/core/permissions/role_guard.dart` với `PermissionDeniedException`
- [ ] Move `post_house_screen.dart` sang `host/post/`
- [ ] Move `my_listings_screen.dart` sang `host/profile/`
- [ ] Wrap 2 màn bằng `RoleGuardWidget`
- [ ] Router giữ route `/post-house` backward compat
- [ ] Add pre-action check `_confirmDelete/_confirmTerminate/_confirmTransfer` (3 file — bỏ building_detail_screen)
- [ ] Add defensive throw trong 3 provider (deleteHouse/deleteBuilding/terminate/transfer)
- [ ] Update FAB flow trong `guest_shell.dart` với confirm dialog cho guest
- [ ] **Widget state lifecycle: dispose() trong post_house_screen + host forms + key-based rebuild**
- [ ] **Audit log event `role_upgraded` + `permission_denied`**
- [ ] **Unit test `role_guard_test.dart` + 3 provider test**
- [ ] Grep + fix hết import cũ
- [ ] `flutter analyze` = 0 issues
- [ ] Smoke test 5 kịch bản

## Success criteria

- Guest deep-link `/post-house` → hiện RoleGuardWidget, KHÔNG hiện form
- Host FAB "Đăng tin" → PostHouseScreen mount ngay không dialog
- Guest FAB "Đăng tin" → dialog xác nhận nâng cấp
- Guest gọi delete/terminate/transfer trực tiếp qua provider (test unit) → throw PermissionDeniedException
- Draft form không leak sang user khác trên shared device
- Auto-upgrade event có audit log
- 0 import bị vỡ, `flutter analyze` clean
- (Nếu chọn testing budget) unit test coverage cho `role_guard` ≥ 90%

## Risk

- **Import breakage cascade** — 2 file move có thể ảnh hưởng nhiều nơi. Mitigation: grep trước khi move, dùng find-replace bulk.
- **Deep-link cũ vỡ** — `/post-house` từ notification. Mitigation: giữ route cũ trong router, redirect internal sang path mới.
- **Auto-upgrade JWT flow** — Phase 00 đã verify backend trả JWT mới. Rủi ro còn lại: nếu user tap Cancel trên confirm dialog → không gọi backend → không phát sinh state lệch.
- **Widget state key rebuild có thể mất draft khi persona toggle** — key dựa vào `userId`, không đổi khi guest↔host toggle (cùng user). OK.

## Security notes

- Provider-layer check là **defense in depth** — không thay thế backend authz. Backend PHẢI check role trên mọi DELETE/PATCH endpoint.
- `RoleGuardWidget` chỉ là UI barrier, không phải security barrier. Bypass được nếu attacker gọi API trực tiếp — backend là single source of truth.
- Audit log là **required** cho security compliance — nếu chưa có analytics tool wired (câu hỏi 8), tạm log console + TODO wire vào Sentry/Firebase Analytics sau.

## Out of scope

- Không refactor form logic của PostHouseScreen (chỉ dispose + key rebuild)
- Không đổi backend endpoint
- Không animation/transition mới cho RoleGuardWidget
- Không add delete UI cho building (out of scope — Phase 01 chỉ fix leak hiện có)
