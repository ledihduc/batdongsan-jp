# Phase 03 — Role Model Architecture Decision

**Priority:** P0 design | **Status:** pending — needs user call | **Estimate:** 0.5 ngày spec + 1 ngày impl
**Depends on:** — (spec blocks Phase 02 impl; impl blocks Phase 04)

## Context

Auth model chỉ recognize 3 role: `guest|host|admin` (auth_provider.dart:159–171). Nhưng codebase có feature dir `operator/`, `tenant/` với route riêng. Kết quả: không có nơi nào centralized để check "user này có phải operator không" — phải hỏi `DelegationProvider.myDelegationsAsOperator.isNotEmpty`.

**Đây là kiến trúc quyết định, không phải bug fix.** Cần user chốt trước.

**v2 correction (from H5 Tech Lead review):** Spec phase (0.5 ngày) **PHẢI chạy trước Phase 02 impl** để `DisplayedRole` enum ready cho route_guards.dart. Impl phase (1 ngày) chạy sau Phase 02 (khi cleanup + router đã stable).

**v3 DECISION LOCKED (2026-07-02):**
- **Q1: Option A (delegation scope)** — không đổi backend
- **Q3: Admin persona toggle disable hoàn toàn** — AdminShell không có toggle, admin muốn xem UX user → logout dùng test account
- **Q10: Multi-role assumed YES** — DisplayedRoleProvider priority `admin > operator (nếu hasActiveDelegation) > host > guest`; role switcher trong Profile chỉ show khi user có > 1 displayed role available.
- **Q2: Tenant model = email deep-link + backend U2** — DisplayedRole.tenant default không detect được cho đến khi backend ready. TenantShell defer.

## Two options

### Option A — Giữ nguyên (Operator = delegation scope, Tenant = contract role)

- **Operator:** user vẫn có role `guest`/`host`, nhưng có thể "acting as owner X" qua delegation
- **Tenant:** không phải user; nhận email deep-link + JWT ngắn hạn (**BLOCKED bởi U2** — backend chưa issue tenant JWT)
- **Ưu:** không đổi backend, không đổi auth schema, đơn giản cho MVP
- **Nhược:** phải nhớ 3 khái niệm (role vs persona vs actor); guard cho operator phức tạp (`hasActiveDelegation` từ DelegationProvider); tenant không có notification/history

### Option B — Nâng operator, tenant lên role trong auth

- **Operator:** thêm `role='operator'` trong auth. User đã accept delegation → backend đổi role
- **Tenant:** thêm `role='tenant'`. Tenant tự tạo account (email + password) hoặc login qua deep-link OTP
- **Ưu:** thống nhất 1 chiều (chỉ role); guard đơn giản; tenant có notification/home riêng
- **Nhược:** backend phải đổi enum + migration; user có thể có nhiều role (host + operator chồng chéo → phải chọn "primary role"); phức tạp hơn về data model
- **Backend cost (verified):** U3 confirm — backend `User.role` **không có enum constraint** hiện tại, migration chỉ là add value + update rows. ~0.5 ngày backend work.

### Recommendation

**Option A cho MVP** (đang gần với thực tế hiện tại, ít refactor). Ghi rõ trade-off và có exit path nếu sau này cần Option B.

## Decision points cần user chốt

1. **Chọn A hay B?** (Câu 1 trong plan.md decision list)
2. **Nếu A:** operator/tenant có cần thấy trong Profile screen như "role hiển thị" (label riêng: "Đại lý quản lý" cho operator, "Người thuê" cho tenant) mặc dù user.role vẫn là `guest`/`host`?
3. **Nếu A:** admin có được phép toggle host persona (rủi ro tự-duyệt) hay disable? **(Câu 3 plan.md — backend U4 confirm chưa có server-side check tự-duyệt)**
4. **Nếu B:** ai migrate existing users? Backend team tự làm hay cần frontend feature flag?
5. **Multi-role user reality:** production có user vừa host vừa operator không? **(Câu 10 plan.md — impact role switcher trong Phase 04)**

## Deliverables (assume Option A được chọn)

### Spec doc (0.5 ngày — **blocks Phase 02 impl**)

- `docs/role-model.md` — document 3-dimension model với diagram
- Định nghĩa: **displayed role** (label UI) vs **auth role** vs **persona** vs **actor context**
- Enum `DisplayedRole { guest, host, admin, operator_, tenant }` — derived từ auth + delegation + JWT claim
- Ma trận: mỗi displayed role thấy shell nào, section profile nào, nav nào
- Getter tiện dụng:
  ```dart
  extension DisplayedRoleAccess on DisplayedRole {
    bool get canAccessHost => this == host || this == admin;
    bool get canAccessAdmin => this == admin;
    bool get canAccessOperator => this == operator_;
    bool get canAccessTenant => this == tenant;
    String get vietnameseLabel => switch (this) {
      DisplayedRole.admin => 'Quản trị',
      DisplayedRole.host => 'Chủ nhà',
      DisplayedRole.operator_ => 'Đại lý quản lý',
      DisplayedRole.tenant => 'Người thuê',
      DisplayedRole.guest => 'Khách thuê',
    };
  }
  ```

### Impl (1 ngày — sau Phase 02)

- Tạo `lib/providers/displayed_role_provider.dart` — computed provider từ auth + delegation
  ```dart
  class DisplayedRoleProvider extends ChangeNotifier {
    DisplayedRole _current = DisplayedRole.guest;
    // Recompute khi auth/delegation change
    // Priority: admin > operator (if hasActiveDelegation) > host > guest
    // Tenant: derive từ tenant JWT claim (nếu backend U2 ready) — else defer
  }
  ```
- Update `route_guards.dart` (từ Phase 02) dùng `DisplayedRole` — thay tạm string check
- Update Profile screen role badge dùng `DisplayedRole.vietnameseLabel` (thay cho `isAdmin` check line 333)

## Testing (new v2 — from H1)

**Unit tests cho `DisplayedRoleProvider` — 5×N permutation matrix:**

| auth.role | delegation.hasActive | tenant JWT | Expected DisplayedRole |
|---|---|---|---|
| admin | any | any | admin |
| host | true | any | operator_ |
| host | false | any | host |
| guest | true | any | operator_ |
| guest | false | valid | tenant |
| guest | false | none | guest |
| null | any | any | guest |

- File: `test/providers/displayed_role_provider_test.dart`
- Coverage target: 100% (đây là pure function of state)

**Widget tests:**
- Profile screen role badge hiển thị đúng label với 5 role

## Related files

**Đọc:**
- `lib/providers/auth_provider.dart:159–171` — role enum hiện tại
- `lib/providers/actor_context_provider.dart`
- `lib/providers/delegation_provider.dart`

**Tạo mới (Option A):**
- `docs/role-model.md`
- `lib/providers/displayed_role_provider.dart`
- `lib/core/models/displayed_role.dart` — enum

**Modify (Option A):**
- `lib/features/guest/profile/profile_screen.dart:333` — dùng DisplayedRole
- `lib/main.dart` — provider tree add `DisplayedRoleProvider`
- `lib/core/router/app_router.dart` — refreshListenable include DisplayedRoleProvider
- `lib/core/router/route_guards.dart` — dùng DisplayedRole (từ Phase 02)

**Modify (Option B — chỉ nếu chọn B):**
- Backend `app/models.py` — role enum (~0.5 ngày backend)
- Backend `alembic/versions/` — migration
- Frontend auth_provider `_parseUserRole` — thêm cases
- 5 màn onboarding operator/tenant

## TODO checklist

**Spec (blocks Phase 02 impl):**
- [ ] User chốt Option A hay B (blocker)
- [ ] Nếu A: quyết định operator/tenant displayed role labels
- [ ] Nếu A: admin toggle persona — cho phép hay disable
- [ ] Nếu A: role switcher trong Profile (dựa vào câu hỏi 10 multi-role user)
- [ ] Nếu B: kế hoạch backend migration
- [ ] `docs/role-model.md` với diagram + matrix

**Impl (Option A, sau Phase 02):**
- [ ] `DisplayedRole` enum + extension
- [ ] `DisplayedRoleProvider` computed
- [ ] Wire vào provider tree (main.dart)
- [ ] Refactor route_guards.dart dùng DisplayedRole
- [ ] Profile screen role badge
- [ ] Unit test `displayed_role_provider_test.dart` — 100% coverage
- [ ] Widget test role badge display

## Success criteria

- User confirm option chọn
- Doc `role-model.md` published, các phase sau reference tới
- (Nếu A) `DisplayedRoleProvider` return đúng cho 5 role × 3 state axes trong test matrix
- Guards refactor dùng DisplayedRole thay string check

## Risk

- **User không chốt được** → escalate với product spec question, không tự quyết
- **Option B đi vào rồi thấy cost quá lớn** → exit path: revert Option A code, giữ backend migration đã làm (không mất data, chỉ mất time)
- **Multi-role user (host + operator concurrent)** → priority admin > operator > host > guest; user có thể toggle trong profile settings (Phase 04)
- **Tenant JWT chưa ra (U2)** → DisplayedRoleProvider default `DisplayedRole.tenant` không detect được, tenant vẫn xem như guest. Phase 04 TenantShell defer đến khi backend ready.

## Out of scope

- Không impl Option B trong phase này (nếu chọn B thì tách plan riêng)
- Không refactor DelegationProvider
- Không backend work (kể cả Option B — backend team tự làm parallel)
