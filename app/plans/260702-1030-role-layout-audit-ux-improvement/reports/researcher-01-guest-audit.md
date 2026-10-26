# Guest Role Audit — Flutter House Booking App

**Date:** 2026-07-02  
**Scope:** `lib/features/guest/**/*.dart` (16 files)  
**Role Focus:** `guest` (5-role system: guest, host, admin, operator, tenant)

---

## Summary

✅ **Persona-mode gating works correctly** — `GuestShell` restricts host-mode toggle to `role == 'host' || role == 'admin'`.

⚠️ **CRITICAL CROSS-ROLE LEAK FOUND** — `guest/post/post_house_screen.dart` and `guest/profile/my_listings_screen.dart` are host-exclusive but placed under guest feature folder with no role guards.

✅ **No sneaky host/admin UI in guest views** — Booking, wishlist, detail, review screens show zero host-specific widgets.

⚠️ **Minor UX gaps** — Some screens missing empty states, no role-aware CTA text, and missing loading indicators.

---

## Findings — Role Leaks & Cross-Role Issues

### CRITICAL Severity

**1. `post_house_screen.dart` — Guest folder, host-exclusive logic**
- **File:** `lib/features/guest/post/post_house_screen.dart:1–910`
- **Leak:** Screen is nestled under guest feature tree but implements full house posting (create + edit listings), which is **host-only feature**.
- **Root cause:** No `AuthProvider` role check before rendering form or on mount.
- **Evidence:**
  - Line 250: `hostId: editing?.hostId ?? user.id!` — assigns current user as host without verification
  - Line 286: Returns new JWT token on first listing (guest→host upgrade): `if (ok && newToken != null)` — auto-promoting guest to host
  - Line 276: `registerNewHouse()` call assumes user has host privilege
- **Impact:** A guest-role user who navigates here (e.g., deep link) can post houses and auto-upgrade to host mid-session without explicit permission flow.
- **Fix:** Move to `lib/features/host/post/` OR add guard at screen entry:
  ```dart
  final user = context.read<AuthProvider>().currentUser;
  if (user?.role != 'host' && user?.role != 'admin') {
    Navigator.pop(context);
    return const Scaffold(body: SizedBox.shrink());
  }
  ```

**2. `my_listings_screen.dart` — Guest folder, host-exclusive screen**
- **File:** `lib/features/guest/profile/my_listings_screen.dart:1–275`
- **Leak:** Displays user's own listings with edit/delete actions. Only hosts have listings; guests shouldn't access.
- **Root cause:** No role filter; shows `hp.myHouses` for any user (guests get empty list, but feature design is host-centric).
- **Evidence:**
  - Line 52–61: FAB "Đăng phòng" routes to `PostHouseScreen()` — guest can tap this
  - Line 180: "Sửa tin" edit button — stateful host action
  - Line 187: "Xoá tin" delete button — destructive host action
- **Impact:** Low for guests (myHouses likely empty), but UX muddy: empty state says "Bạn chưa đăng tin nào" — implies guests *should* be posting houses.
- **Fix:** Move to `lib/features/host/profile/` OR skip rendering entirely if `user.role != 'host' && user.role != 'admin'`.

### MEDIUM Severity

**3. `profile_screen.dart` — Role badge accuracy**
- **File:** `lib/features/guest/profile/profile_screen.dart:332–352`
- **Issue:** Role badge only checks `isAdmin` (line 333). Guest/host roles display as "Thành viên" with accent color, no distinction.
- **Impact:** UX clarity — guest can't see they're in guest mode; host in guest shell also labeled "Thành viên".
- **Evidence:**
  ```dart
  final isAdmin = role == 'admin';
  final label = isAdmin ? 'Quản trị' : 'Thành viên';
  ```
- **Fix:** Expand badge logic:
  ```dart
  final label = role == 'admin' ? 'Quản trị' : role == 'host' ? 'Chủ nhà' : 'Khách thuê';
  ```

**4. `guest_shell.dart` FAB only guarded by canHost, not tested on mount**
- **File:** `lib/features/guest/guest_shell.dart:165–217`
- **Issue:** "Đăng tin" FAB shows on guest home if `canHost == true`, but FAB targets `PostHouseScreen()` with no re-validation inside.
- **Impact:** Tight coupling; if `canHost` stale or auth changes mid-session, FAB becomes orphaned or leaks.
- **Evidence:**
  - Line 166: `showFab = _mode == kModeGuest && _currentIndex == 0 && canHost`
  - Line 208–209: Direct route, no check inside PostHouseScreen
- **Fix:** PostHouseScreen should validate role on mount (see CRITICAL #1 above).

### LOW Severity

**5. Missing empty states in booking & wishlist under specific conditions**
- **File:** `booking_history_screen.dart:649–685` ✅ (has empty state), `wishlist_screen.dart:54–81` ✅ (has empty state)
- **Status:** Actually OK — both screens render proper empty states.

**6. `house_detail_screen.dart` — No role-aware messaging for booking**
- **File:** `lib/features/guest/house_detail/house_detail_screen.dart:381–396`
- **Issue:** "Đặt lịch xem nhà" button always visible; no messaging for already-booked or non-guest roles viewing.
- **Impact:** Cosmetic — logic prevents double-booking server-side, but UX doesn't hint at it.
- **Fix:** Add conditional text: `user.role != 'guest' ? 'Chỉ khách thuê có thể đặt lịch' : 'Đặt lịch xem nhà'`

---

## Findings — Missing Role Guards

| File | Function | Guard Status |
|------|----------|--------------|
| `guest_shell.dart:71–79` | `_applyResolvedMode()` | ✅ Checks `canHost = role in ['host', 'admin']` before kModeHost |
| `post_house_screen.dart:250` | `hostId` assignment | ❌ No check; assumes user is host |
| `my_listings_screen.dart:27` | `fetchMyHouses()` | ✅ Calls with `user.id`, but screen shown to all |
| `profile_screen.dart:148–156` | Persona switcher | ✅ Gated: `if (canSwitchToHost)` hidden if !canHost |
| `booking_history_screen.dart:77` | `fetchAppointments()` | ✅ Passes `user.role` to provider (guest/host split) |
| `house_detail_screen.dart:554–561` | Chat with host | ⚠️ No validation that peerId is valid host |

---

## Findings — UX Issues

### No load state on persona switch
- `guest_shell.dart:200` — AnimatedSwitcher fades screens but no loading indicator while host content loads.
- **Fix:** Wrap screen body in FutureBuilder or add skeleton shimmer.

### "Tin đã đăng" stat card shows in guest profile tab
- `profile_screen.dart:164–175` — Stats card "Tin đăng" (listings) tappable for guests, but list is always empty.
- **Better:** Hide stat card or swap to "Số lượng yêu cầu đặt lịch" for guest mode.

### No role context in empty states
- `wishlist_screen.dart:72–76`: "Bấm trái tim..." assumes guest mode — correct, but not labeled.
- `booking_history_screen.dart:672–681`: "Các yêu cầu đặt lịch..." — should clarify "của bạn (khách thuê)" vs host.

### Missing data validation edge case
- `house_detail_screen.dart:246–256` — PlanningBadge only renders if lat/lng != null && != 0. Fail-silent is good, but no fallback UI.
- **Minor:** Consider `PlanningBadge.shimmer()` or skip badge entirely if geo-data missing.

---

## Findings — Suspicious Patterns (Low Risk, Design Questions)

1. **Auto-host upgrade on first listing** (`post_house_screen.dart:286–290`)
   - Guest posts house → backend returns new JWT with host role → auto-bootstrap.
   - ✅ Intentional (onboarding flow), but undocumented UX. No UI toast confirming "You're now a host."
   - **Recommend:** Add success toast: "Đã nâng cấp tài khoản chủ nhà!"

2. **My Listings accessible from guest profile**
   - Guest menu shows "Tin đã đăng" tile even if guest has never posted.
   - ✅ Graceful degradation (empty state), but suggests to guests they *should* post.
   - **Recommend:** Hide tile behind `user.role == 'host' || user.role == 'admin'` check.

3. **Editing listing reverts to "pending" on re-save**
   - `post_house_screen.dart:262–264`: `status = editing == null ? 'pending' : (editing.status == 'approved' ? 'approved' : 'pending')`.
   - ✅ Intentional (unapproved edits revert for admin review), but UX doesn't explain.
   - **Recommend:** Toast: "Tin chỉnh sửa chờ duyệt lại từ Admin."

---

## Recommendations (Prioritized)

| Priority | Action | Effort | Impact |
|----------|--------|--------|--------|
| **CRITICAL** | Move `post_house_screen.dart` to `lib/features/host/` OR add role guard on mount | 30 min | Prevents guest→host jailbreak |
| **CRITICAL** | Move `my_listings_screen.dart` to `lib/features/host/` OR hide from guest profile | 20 min | Clarifies role intent |
| **HIGH** | Add role check in `PostHouseScreen.initState()` as defense-in-depth | 15 min | Layered security |
| **MEDIUM** | Expand role badge logic in ProfileScreen (guest/host distinction) | 10 min | Clarity |
| **MEDIUM** | Hide "Tin đã đăng" stat card + tile for non-host roles | 10 min | UX clarity |
| **LOW** | Add success toast on auto-host upgrade | 5 min | User awareness |
| **LOW** | Add toast on listing re-approval workflow | 5 min | UX transparency |

---

## Unresolved Questions

1. **Is `PostHouseScreen` intentionally guest-accessible for onboarding?**
   - If yes, should be guarded + documented + have explicit "Become a host?" flow.
   - If no, move to host folder immediately.

2. **Should `MyListingsScreen` show for admins managing other users' listings?**
   - Current logic doesn't distinguish — admin sees own listings only.
   - If admin panel exists elsewhere, this is fine. Otherwise, note in ADR.

3. **Who auto-approves first listing from guest→host?**
   - Backend sets status='pending' or directly 'approved' on first posting?
   - Should frontend toast differ based on approval flow?

