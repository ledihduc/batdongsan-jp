# Phase 04 — Role-Specific Shells + Role-Aware Profile + Notification Routing

**Priority:** P1 | **Status:** pending | **Estimate:** 3–4 ngày (was 2 ngày v1) | **Depends on:** Phase 02, Phase 03 impl

## Context

Hiện mọi role fallback vào GuestShell (kể cả admin — họ redirect đến `/admin` nhưng cũng lands vào shell nếu vào `/`). Operator không có shell riêng → thấy tab guest, không thấy delegation UI. Tenant không có shell/home/logout.

Phase này tách shell theo displayed role, và cải Profile screen thành role-aware.

**v2 mở rộng (from C3 + M2 + H2):**
- Estimate bump 2→3–4 ngày (3 shell mới × 200 LOC + integration + smoke realistic hơn)
- Add notification routing per shell (C3 — FCM push routing khi wrong role receive)
- Add analytics events per role shell (M2)
- **Behind feature flag `role_shells_v2_enabled`** — rollback nhanh nếu prod issue (C4)
- Persona toggle: cancel in-flight request khi user toggle guest↔host (F6 defensive)

## Requirements

**Functional:**
- Admin có `AdminShell` với bottom nav riêng (Home / Duyệt tin / Kiểm toán / Cá nhân) — không có persona toggle
- Operator (nếu có active delegation) thấy `OperatorShell` với "Portfolio" / "Đang quản lý" / "Lời mời" / "Cá nhân"
- Tenant có `TenantShell` tối giản: "Hợp đồng" / "Báo cáo" / "Cá nhân" — **BLOCKED bởi U2** nếu backend chưa issue tenant JWT
- Profile screen: mỗi role có section tương ứng (Host thấy Delegation Mgmt + Approvals, Operator thấy Portfolio + Invitations, Tenant thấy Report link)
- Logout available từ Profile của mọi shell
- Role badge chính xác cho 5 role (không chỉ "Quản trị" vs "Thành viên") — dùng `DisplayedRole.vietnameseLabel` từ Phase 03
- **Notification routing per shell:** push notification tap → land đúng shell + tab, không cross-role leak

**Non-functional:**
- Không break existing host/guest UX
- Route root `/` chọn shell theo displayed role
- Cold-start smooth (không flash sai shell — leverage Phase 02 bootstrap ordering)
- **Behind feature flag `role_shells_v2_enabled`**:
  - `false` → giữ GuestShell fallback cho mọi role (rollback)
  - `true` → route theo DisplayedRole

## Related files

**Đọc:**
- `lib/features/guest/guest_shell.dart` (415 dòng — reference pattern)
- `lib/features/guest/profile/profile_screen.dart` (extend, không rewrite; line 332–352 role badge)
- `lib/features/operator/workspace/operator_workspace_shell.dart` (verify tồn tại + purpose trong Phase 00)
- `lib/core/router/app_router.dart` — root gate logic
- `lib/providers/notification_provider.dart` — notification routing hooks

**Tạo mới:**
- `lib/features/admin/admin_shell.dart` (nếu chưa có)
- `lib/features/operator/operator_shell.dart` — nếu chưa có
- `lib/features/tenant/tenant_shell.dart` — mới hoàn toàn (defer nếu U2 blocked)
- `lib/core/widgets/role_switcher.dart` — nếu user có nhiều displayed role (host + operator)
- `lib/core/lifecycle/notification_router.dart` — route push notification đến đúng shell/tab
- `lib/core/config/feature_flags.dart` — flag `role_shells_v2_enabled` (nếu chưa có infra — câu hỏi 7)

**Modify:**
- `lib/core/router/app_router.dart` — `_RootGate` route by DisplayedRole (behind flag)
- `lib/features/guest/profile/profile_screen.dart` — role-aware section list
- `lib/providers/auth_provider.dart:logout` — đảm bảo clear tất cả shell state (đã xong Phase 02)
- Profile role badge (line 332–352) → dùng DisplayedRole

## Implementation steps

### Step 1: Feature flag infra (1 giờ)

Nếu chưa có Remote Config / LaunchDarkly (câu hỏi 7):
```dart
// lib/core/config/feature_flags.dart
class FeatureFlags {
  static const bool roleShellsV2Enabled = bool.fromEnvironment(
    'ROLE_SHELLS_V2_ENABLED', defaultValue: false,
  );
}
```
Set qua `--dart-define=ROLE_SHELLS_V2_ENABLED=true` khi build. Simpler than Remote Config, sufficient cho rollback.

Nếu có Remote Config → wire vào để toggle runtime.

### Step 2: Root gate refactor (2 giờ)

```dart
// app_router.dart _RootGate.build
if (!FeatureFlags.roleShellsV2Enabled) {
  return const GuestShell();  // legacy fallback
}

final displayedRole = context.watch<DisplayedRoleProvider>().current;
return switch (displayedRole) {
  DisplayedRole.admin => const AdminShell(),
  DisplayedRole.operator_ => const OperatorShell(),
  DisplayedRole.tenant => const TenantShell(),
  DisplayedRole.host || DisplayedRole.guest => const GuestShell(),
};
```

### Step 3: AdminShell (6 giờ)

- Copy pattern GuestShell nhưng bỏ persona toggle
- 4 tabs: Home (dashboard admin) / Duyệt tin (approval queue) / Kiểm toán (audit feed) / Cá nhân (profile với role='admin')
- Reuse `admin_home_screen.dart` cho tab 0, `risky_listings_screen.dart` cho tab 1, `activity_feed_screen.dart` cho tab 2
- Verify tồn tại của các reusable screen trong Phase 00

### Step 4: OperatorShell (6 giờ)

- 4 tabs: Portfolio (`operator_portfolio_screen.dart`) / Đang quản lý (workspace picker) / Lời mời (invitations) / Cá nhân
- Show "Acting as: [owner name]" banner khi enterContext active — reuse existing `ActingAsBanner` (đã tồn tại theo audit)
- Exit context button — return to portfolio (clears actor context)

### Step 5: TenantShell (4 giờ nếu U2 unblocked, else defer)

- 3 tabs: Hợp đồng / Báo cáo / Cá nhân
- Nếu U2 blocked → skip step này, mark defer với TODO comment

### Step 6: Profile role-aware sections (3 giờ)

Mỗi role thấy section khác nhau — dùng `switch (displayedRole)` để build list section:
- Common: Cá nhân, Đổi mật khẩu, Đăng xuất
- Guest: Yêu thích, Đặt lịch
- Host: Nhà trọ, Doanh thu, Duyệt tin, Ủy thác quản lý (delegation)
- Admin: Duyệt tin, Kiểm toán, Cấu hình hệ thống
- Operator: Portfolio, Lời mời, Chuyển đổi chủ
- Tenant: Hợp đồng, Báo cáo lạm quyền

### Step 7: Role badge fix (30 phút)

```dart
final label = context.watch<DisplayedRoleProvider>().current.vietnameseLabel;
```
Line 333 profile_screen.dart — thay `isAdmin` check.

### Step 8: Role switcher (2 giờ — nếu câu hỏi 10 = có multi-role user)

Nếu user vừa là host vừa là operator → cần switcher trong profile (persist choice qua SharedPreferences).
```dart
class RoleSwitcher extends StatelessWidget {
  // dropdown chuyển giữa các displayed role user có
}
```
Nếu câu hỏi 10 = không có → defer, note trong TODO.

### Step 9: Notification routing per shell (3 giờ — new v2, from C3)

Tạo `lib/core/lifecycle/notification_router.dart`:
```dart
class NotificationRouter {
  static void handleTap(RemoteMessage message, BuildContext ctx) {
    final category = message.data['category']; // 'booking', 'contract', 'invoice', 'delegation', 'approval'
    final targetRole = _categoryToRole(category);
    final currentRole = ctx.read<DisplayedRoleProvider>().current;
    
    if (targetRole == currentRole) {
      // Route to correct tab in current shell
      ctx.go(_categoryToRoute(category));
    } else {
      // Wrong role — behavior per câu hỏi 6:
      // Option A (discard): silent ignore + log
      // Option B (defer): store in pending queue, prompt user
      // Option C (force switch): show dialog "Chuyển sang chế độ X để xem"
      _handleWrongRole(ctx, category, targetRole);
    }
  }
  
  static DisplayedRole _categoryToRole(String cat) => switch (cat) {
    'booking' => DisplayedRole.host,
    'contract' => DisplayedRole.tenant, // or host tùy direction
    'invoice' => DisplayedRole.host,
    'delegation' => DisplayedRole.operator_,
    'approval' => DisplayedRole.admin,
    _ => DisplayedRole.guest,
  };
}
```
Wire vào `NotificationProvider` onMessageOpenedApp handler.

### Step 10: Persona toggle request cancel (1 giờ — new v2, from F6)

Trong `guest_shell.dart` khi persona toggle:
```dart
void _onPersonaToggle(String newPersona) {
  ApiClient.instance.cancelPendingRequests(); // add method vào api_client
  setState(() => _selectedPersona = newPersona);
}
```
Thêm `cancelPendingRequests()` vào ApiClient (dùng CancelToken hoặc AbortController).

### Step 11: Analytics events (1 giờ — new v2, from M2)

Nếu có analytics wired (câu hỏi 8):
```dart
// Trong mỗi shell initState
analytics.logEvent('screen_view', parameters: {
  'shell': 'AdminShell',
  'displayed_role': 'admin',
});
// Trên persona toggle:
analytics.logEvent('persona_toggle', parameters: {
  'from': oldPersona, 'to': newPersona, 'user_role': userRole,
});
```
Nếu không có analytics → note TODO cho future.

## Testing

**Unit tests:**
- `test/core/lifecycle/notification_router_test.dart` — category → targetRole mapping
- `test/core/config/feature_flags_test.dart` — flag default false, override via dart-define

**Widget tests:**
- Root gate shell selection với 5 DisplayedRole × 2 flag state (v2 on/off)
- Profile section list matches DisplayedRole
- Role badge label đúng cho 5 role

**Smoke tests (manual):**
1. Admin login → AdminShell, không thấy persona toggle
2. Operator login (có active delegation) → OperatorShell
3. Host login → GuestShell với persona toggle
4. Guest login → GuestShell không toggle
5. Mỗi shell có logout accessible từ profile
6. Profile section list match displayed role
7. Flag off → tất cả về GuestShell (rollback test)
8. Notification tap sai role → behavior theo câu 6 (discard/defer/force)
9. Persona toggle mid-request → request cancel, không update sai cache

## TODO checklist

- [ ] Feature flag `role_shells_v2_enabled` implement
- [ ] Root gate refactor (behind flag)
- [ ] `AdminShell` tạo + wire
- [ ] `OperatorShell` tạo + `ActingAsBanner` integration
- [ ] `TenantShell` (nếu U2 unblocked, else defer)
- [ ] Profile section list role-aware
- [ ] Role badge dùng `DisplayedRole.vietnameseLabel`
- [ ] Logout button trong AdminShell, OperatorShell profile
- [ ] Role switcher (nếu multi-role user exists)
- [ ] **Notification routing per shell (`notification_router.dart`)**
- [ ] **Persona toggle request cancel**
- [ ] **Analytics events per shell**
- [ ] Unit test `notification_router` + `feature_flags`
- [ ] Widget test root gate 5 role × 2 flag state
- [ ] Smoke test 9 scenario
- [ ] Không flash sai shell khi role change mid-session (leverage Phase 02 bootstrap)

## Success criteria

- Admin login (flag on) → AdminShell, không thấy persona toggle
- Operator login (flag on) → OperatorShell
- Flag off → GuestShell fallback cho mọi role (rollback verified)
- Notification tap → land đúng shell hoặc handled per policy khi wrong role
- Persona toggle không tạo race condition cache
- 0 layout leak giữa các shell
- Widget test coverage cho root gate ≥ 90%

## Risk

- **User có nhiều displayed role đồng thời** (host + operator + admin) → cần role switcher hoặc quy tắc priority. Mitigation: mặc định priority admin > operator > host > guest; user có thể toggle trong profile (câu hỏi 10 quyết định urgency).
- **Cold-start flash:** đã mitigate ở Phase 02 (bootstrap ordering).
- **Regression cho host user:** đổi shell logic có thể vỡ persona toggle. Mitigation: manual test host guest→host toggle sau refactor + flag off fallback.
- **Tenant U2 blocker:** TenantShell defer, note trong roadmap.
- **Notification wrong role behavior:** phụ thuộc câu 6 answer. Nếu chưa answer → default "discard + log" (safest).
- **Analytics infra không có:** noop analytics, không block feature.

## Out of scope

- Không rebuild admin_home_screen internal — chỉ wrap trong shell
- Không đổi delegation UX
- Không multi-role account merging
- Không thay đổi FCM plugin
