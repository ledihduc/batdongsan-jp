# Bottom Nav Optimization — Plan

**Created:** 2026-06-28
**Trigger:** Menu footer hiển thị 6 mục + FAB → chật chội, label bị cắt, FAB overlap
**Reference:** `plans/visuals/bottom-nav-research.md` (case studies Airbnb, PropertyGuru, Instagram, Homedy)

---

## 1. Chẩn đoán hiện trạng

**File:** `lib/features/guest/guest_shell.dart`

```
[ Khám phá ] [ Yêu thích ] [ Quy hoạch ] [ Đặt lịch • ] [ Tin đăng • ] [ Cá nhân ]   ← 6 tabs
                                  ⊕ Đăng phòng  (FAB overlap)
```

**Vấn đề cụ thể:**
| # | Vấn đề | Tác động |
|---|---|---|
| 1 | 6 tabs vi phạm Material 3 (≤5) | Label "Khám phá" / "Yêu thích" / "Quy hoạch" / "Đặt lịch" / "Tin đăng" / "Cá nhân" bị cắt cuối, khó đọc |
| 2 | FAB "Đăng phòng" che icon tab giữa | Tap nhầm; ergonomic kém trên màn nhỏ |
| 3 | Tab "Tin đăng" hiện cả khi user chưa upgrade host | Tab "chết" với guest-only user; gây nhầm lẫn |
| 4 | "Quy hoạch" là feature niche nhưng chiếm 1/6 nav | Real estate quá đắt cho 1 feature phụ |
| 5 | 2 badge cùng lúc (Đặt lịch + Tin đăng) | Nhiễu thị giác |

---

## 2. Mục tiêu

| KPI | Hiện tại | Mục tiêu |
|---|---|---|
| Số tabs cố định | 6 | **4** |
| Label truncation | Có | Không |
| FAB overlap | Có | Không |
| Tap chính xác Đăng phòng | ~60% (ước) | >90% |
| Discovery Host mode (dual-role) | n/a | <3 giây từ Profile |

---

## 3. Hai phương án — chọn 1

### 🅰️ Phương án A — **Profile Persona Switcher** (Airbnb pattern, RECOMMENDED)

> Một bottom nav duy nhất, persona switch nằm trong tab Cá nhân.

```
GUEST MODE (default):
[ 🔍 Khám phá ] [ ♥ Yêu thích ] [ 📅 Đặt lịch • ] [ 👤 Cá nhân ]   ← 4 tabs

HOST MODE (sau khi toggle trong Cá nhân):
[ 🏠 Tổng quan ] [ 📑 Tin đăng • ] [ 📅 Yêu cầu xem • ] [ 👤 Cá nhân ]   ← 4 tabs (cùng vị trí)
```

**Cơ chế chuyển đổi:**
- Trong tab **Cá nhân**, hiển thị một row toggle lớn ở đầu trang:
  - `[ KHÁCH HÀNG | CHỦ NHÀ ]` — như iOS segmented control
  - Chỉ hiện toggle nếu `user.role == 'host'` (đã upgrade)
  - Nếu user chưa là host: hiện CTA `"Trở thành chủ nhà →"` (route sang onboarding)
- Khi switch → 4 tab slot dưới đổi nội dung (IndexedStack giữ state riêng cho mỗi mode)
- AppBar có 1 dòng status nhỏ: `MODE: KHÁCH HÀNG` hoặc `MODE: CHỦ NHÀ` (eyebrow style)

**FAB "Đăng phòng":**
- Bỏ FAB toàn cục
- Trong Guest Mode: không có FAB
- Trong Host Mode (tab Tổng quan): có 1 button primary lớn "ĐĂNG TIN MỚI" ở header (theo HD aesthetic — accent red, eyebrow)
- Trong Host Mode (tab Tin đăng): cũng có CTA tương tự

**Quy hoạch (map):**
- Bỏ khỏi bottom nav
- Move vào **Khám phá** dưới dạng:
  - Icon button "🗺️ Bản đồ quy hoạch" ở header phải của Khám phá (icon `map_outlined`)
  - Hoặc 1 quick-action chip trong row filter ngay dưới search bar
- Vẫn dùng route + `PlanningMapScreen` cũ, chỉ thay điểm vào

**Pros:**
- ✅ 4 tabs đúng Material 3, không truncate
- ✅ Pattern quen thuộc (Zalo Business toggle, Airbnb)
- ✅ Tab "chết" biến mất với guest-only user
- ✅ Code thay đổi tập trung ở `guest_shell.dart` + `profile_screen.dart`

**Cons:**
- ⚠️ Cần 1 tap thêm để vào Host từ Guest (Cá nhân → toggle)
- ⚠️ Cần lưu mode đã chọn (SharedPreferences hoặc UserProvider state)

**Effort:** 1-1.5 ngày

---

### 🅱️ Phương án B — **Dual-Shell Separation**

> Tách thành 2 shell hoàn toàn riêng (GuestShell + HostShell), switch qua route push/replace.

```
GUEST SHELL:
[ 🔍 Khám phá ] [ ♥ Yêu thích ] [ 📅 Đặt lịch • ] [ 👤 Cá nhân ]

HOST SHELL (route khác):
[ 🏠 Dashboard ] [ 🏢 Phòng/Toà ] [ 📅 Yêu cầu • ] [ 👤 Cá nhân ]
```

**Cơ chế:**
- Trong Guest's Cá nhân → button "Vào trang chủ nhà" → `Navigator.pushReplacement(HostShell())`
- Trong Host's Cá nhân → button "Về trang khách" → `Navigator.pushReplacement(GuestShell())`
- AppBar có badge mode rất nổi (như header màu accent khác)

**Pros:**
- ✅ Mỗi shell tối ưu cho 1 role, sạch sẽ
- ✅ Host Shell có thể có thêm sub-tabs riêng (Phòng, Hợp đồng, Hoá đơn, Báo cáo)
- ✅ Khả năng scale tốt khi Host features lớn lên (Phase 04-08 trong roadmap)

**Cons:**
- ⚠️ Tốn 1 file `host_shell.dart` mới
- ⚠️ Route switching = chuyển màn → animation đáng kể (user cảm nhận như rời app)
- ⚠️ Reset scroll/state khi switch (trừ khi cache)
- ⚠️ FAB "Đăng phòng" vẫn cần nơi đặt (giải pháp giống A)

**Effort:** 2-2.5 ngày

---

## 4. Khuyến nghị

**→ Chọn Phương án A** cho Phase 1 (Now):
- Đầu tư thấp, tác động lớn lên UX ngay
- Code touch tập trung, dễ review
- Đủ tốt cho Host features hiện tại (Dashboard + 1 cái Tin đăng + Yêu cầu xem)

**Khi nào nên migrate sang B (sau này):**
- Khi Host phase 04 (Invoice/Payment/Meter) + phase 05 (Khai báo tạm trú) hoàn thành → Host có >5 features cần truy cập nhanh → dual shell sẽ vượt trội

---

## 5. Chi tiết kỹ thuật — Phương án A

### 5.1 Files cần sửa
| File | Thay đổi |
|---|---|
| `lib/features/guest/guest_shell.dart` | Refactor: từ 6 tab → 4 tab; thêm `_mode` state ('guest'/'host'); IndexedStack có 2 nhánh screens; FAB bỏ |
| `lib/features/guest/profile/profile_screen.dart` | Thêm `_PersonaSwitcher` widget ở top; emit `onModeChanged(String)` callback |
| `lib/features/guest/home/guest_home_screen.dart` | Thêm icon "🗺️" trong AppBar → push `PlanningMapScreen` |
| `lib/features/host/host_home_screen.dart` | Add "ĐĂNG TIN MỚI" CTA button trong masthead/header |
| `lib/features/onboarding/onboarding_screen.dart` | Nếu user chưa host: CTA "Trở thành chủ nhà" trong Profile dẫn về đây |

### 5.2 State management
- Thêm `String _mode = 'guest'` trong `_GuestShellState`
- Persist mode vào SharedPreferences key `last_active_mode`
- Khi user logout → reset về 'guest'
- Khi user không phải host → ép `_mode = 'guest'`, hide toggle

### 5.3 Screens mapping
```dart
List<Widget> _guestScreens => [
  GuestHomeScreen(),       // 0 Khám phá
  WishlistScreen(),        // 1 Yêu thích
  BookingHistoryScreen(),  // 2 Đặt lịch
  ProfileScreen(),         // 3 Cá nhân (chứa toggle)
];

List<Widget> _hostScreens => [
  HostHomeScreen(),                    // 0 Tổng quan
  BuildingListScreen(),                // 1 Tin đăng / Quản lý
  HostAppointmentsScreen(),            // 2 Yêu cầu xem
  ProfileScreen(),                     // 3 Cá nhân (chứa toggle)
];
```

> Lưu ý: HostHomeScreen hiện tại đã có 2 sub-tabs (Tin đăng / Nhà trọ) — vẫn giữ nguyên cấu trúc đó cho tab Tổng quan.

### 5.4 Tab labels & icons (Host mode)
| Slot | Icon outline | Icon filled | Label |
|---|---|---|---|
| 0 | `dashboard_outlined` | `dashboard` | Tổng quan |
| 1 | `apartment_outlined` | `apartment` | Tin đăng |
| 2 | `event_available_outlined` | `event_available` | Yêu cầu |
| 3 | `person_outline` | `person` | Cá nhân |

### 5.5 Visual indicator mode đang chọn
Trong `GuestShell.build`, phía trên `bottomNavigationBar`:
```dart
if (_mode == 'host')
  Container(
    height: 3,
    color: HD.accent, // dải đỏ ngang cảnh báo "đang ở Host mode"
  ),
```
Hoặc dùng `BottomNavigationBar.backgroundColor` khác giữa 2 mode.

---

## 6. Phases & checklist

### Phase 1 — Reduce tabs to 4 + relocate map (Day 1)
- [ ] Bỏ tab "Quy hoạch" khỏi `guest_shell.dart`
- [ ] Bỏ tab "Tin đăng" khỏi `guest_shell.dart`
- [ ] Bỏ FAB "Đăng phòng" khỏi `guest_shell.dart`
- [ ] Thêm icon button "🗺️" vào AppBar của `guest_home_screen.dart`
- [ ] Hot reload + smoke test 4 tabs còn lại

### Phase 2 — Add persona switcher (Day 1.5)
- [ ] Tạo widget `_PersonaSwitcher` trong `profile_screen.dart`
- [ ] Thêm `_mode` state + persist
- [ ] Hook `ProfileScreen.onModeChanged → GuestShell._switchMode`
- [ ] Conditional render `screens` list theo mode
- [ ] Test: switch mode → bottom nav labels đổi, state mỗi tab giữ riêng

### Phase 3 — Host mode entry CTAs (Day 2)
- [ ] Add "ĐĂNG TIN MỚI" CTA ở `HostHomeScreen` (HD aesthetic)
- [ ] Đảm bảo `BuildingListScreen` có CTA Thêm toà (đã có)
- [ ] Add visual mode indicator (3px accent strip hoặc khác)
- [ ] Smoke test toàn bộ flow: Guest → Profile → toggle Host → Tổng quan → Đăng tin

### Phase 4 — Polish & test (Day 2.5)
- [ ] Đảm bảo badge "Đặt lịch" (guest) + "Yêu cầu" (host) đúng count
- [ ] Bỏ tab "chết" cho user chưa upgrade host (toggle ẩn, hiện CTA "Trở thành chủ nhà")
- [ ] Code review pass
- [ ] Flutter analyze sạch

---

## 7. Câu hỏi mở (cần user confirm trước khi build)

1. **"Quy hoạch" map nên đặt ở đâu chính xác?**
   - (a) Icon `🗺️` ở AppBar phải của Khám phá (1 tap từ home)
   - (b) Quick-action chip trong row filter của Khám phá (đồng cấp với "Lọc / Sắp xếp")
   - (c) Card lớn trong Khám phá ngay đầu trang (hero CTA)

2. **Mode mặc định khi login:**
   - (a) Luôn mở Guest mode → user chủ động switch
   - (b) Nhớ mode cuối user dùng (SharedPreferences)
   - (c) Nếu là host → mặc định Host mode; ngược lại Guest

3. **Toggle Host/Guest ở Profile có nên có animation chuyển mode?**
   - (a) Đổi nội dung tabs ngay lập tức (snap)
   - (b) Fade transition 200ms
   - (c) Slide ngang (giống iOS segmented)

4. **Khi guest chưa upgrade host bấm "Trở thành chủ nhà":**
   - (a) Mở luôn `Step1InfoScreen` (onboarding host hiện có)
   - (b) Hiện 1 màn intro/benefits trước → "Bắt đầu" → onboarding
   - (c) Bottom sheet giới thiệu nhanh + CTA

5. **Có nên giữ "Đăng phòng" FAB ở Khám phá luôn không** (như shortcut cho host đang ở Guest mode)?
   - (a) Không — giữ tab Cá nhân là entry duy nhất để rõ ràng
   - (b) Có — chỉ hiện nếu `user.role == 'host'` để host post nhanh

---

## 8. Anti-patterns đã tránh

- ❌ Hamburger menu cho primary nav (giảm 50% task completion speed — Airbnb A/B test)
- ❌ Long-press để switch persona (không discoverable)
- ❌ Tách thành 2 app riêng (fragments user)
- ❌ Giữ 5+ tabs (truncation)
- ❌ Center FAB (40% accidental tap — Instagram research)

---

**Next step:** User confirm phương án + trả lời 5 câu hỏi mở trên 7 → mình bắt đầu Phase 1.
