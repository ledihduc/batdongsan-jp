# Code Review — Bottom Nav Persona-Switching Refactor

**Reviewer:** code-reviewer (Opus 4.7)
**Date:** 2026-06-28
**Scope:** 6 files (guest_shell, profile_screen, host_appointments_screen, become_host_intro_screen, user_prefs_service, step3_bank_screen)
**Plan:** `plans/260628-1022-bottom-nav-optimization/plan.md`
**Verdict:** **CONDITIONAL** — 2 HIGH issues should be fixed before ship; remainder are quality/polish.

---

## Critical (Block merge)

_None._

---

## High (Should fix before merge)

### H1 — `last_active_mode` persists across user logout / account switch
**File:** `lib/providers/auth_provider.dart:94-98`, `lib/data/services/user_prefs_service.dart:29-33`

`AuthProvider.logout()` clears `_currentUser` and calls `_authRepository.logout()` (which clears the token), but **never calls `UserPrefsService.instance.clearLastMode()`**. The plan/spec explicitly notes this (Section 5.2 of plan: "Khi user logout → reset về 'guest'"), and `clearLastMode()` exists for this purpose but is unused anywhere in the codebase (verify: `grep -rn "clearLastMode" lib/` → 1 hit, the definition itself).

**Concrete leak scenarios:**
1. Host A logs out on a shared device → `last_active_mode = 'host'` remains in secure storage.
2. Guest B logs in on same device → `_bootstrapMode` reads `'host'`, but `canHost` is false (role='member'), so guard at `guest_shell.dart:55` correctly forces `kModeGuest`. **No functional leak today** because the role gate fires.
3. BUT — if Guest B later upgrades to host via onboarding, the stored `'host'` value (left over from User A) drives the initial mode pick, which is a privacy/UX surprise (mode "remembered" from a different user).
4. Edge: any future code path that reads `last_active_mode` without the role gate (e.g., analytics, deeplinks) would inherit the wrong value.

**Severity rationale:** It's defense-in-depth today (the role gate catches it), but it's a trust-boundary violation against the stated requirement and is one refactor away from being a real leak. Cheap fix.

**Fix:**
```dart
// auth_provider.dart logout()
Future<void> logout() async {
  await _authRepository.logout();
  await UserPrefsService.instance.clearLastMode();   // ← add
  _currentUser = null;
  notifyListeners();
}
```

---

### H2 — `_bootstrapMode` race against initial build + provider notifications
**File:** `lib/features/guest/guest_shell.dart:44-59`, `61-66`

`initState` fires `_bootstrapMode()` (async) and a `postFrameCallback(_refreshBadges)` in parallel. Two issues:

1. **First-frame flash.** Shell builds with `_mode = kModeGuest` (default), renders the guest tab bar + guest screen, then ~1 frame later `setState(() => _mode = resolved)` flips to host with a slide animation triggered by `ValueKey(_mode)` change in `AnimatedSwitcher`. For users who closed app in host mode, every cold start shows a brief Guest→Host transition. The `_slideForward` flag is never set in this bootstrap path (only `_setMode` sets it), so direction is whatever was last (`true` by default → host slides in from right, which is fine, but the visual flash is still wrong).

2. **`_setMode`'s `_slideForward` is not initialized for the bootstrap transition.** When `_bootstrapMode` runs `setState(() => _mode = resolved)`, it does NOT update `_slideForward`. If the user happened to switch modes and then quickly relaunch, you could end up with the wrong slide direction on cold-start animation.

3. **`Provider.of<AuthProvider>(context, listen: false)` inside `_bootstrapMode` after `await`** — context might be re-parented across hot reload / route changes; the `if (!mounted) return;` guard handles unmount but not the underlying issue that `currentUser` could still be null on first run (e.g., AuthWrapper hasn't bootstrapped). In that case `canHost = false`, so saved `'host'` mode is silently downgraded — when AuthProvider then loads the user, the shell does NOT re-evaluate. Result: host user briefly logged-in via cached token, but lands in guest mode until they kill+reopen the app.

**Fix:**
```dart
// 1. Make bootstrap synchronous-feeling: skip the visible flash
// Option A — show a tiny loading placeholder while bootstrapping
// Option B — set _mode = kModeGuest *only* after we know canHost is false

// Minimum viable fix: gate the AnimatedSwitcher child with bootstrap state
bool _bootstrapped = false;
// ...
Future<void> _bootstrapMode() async {
  final saved = await UserPrefsService.instance.getLastMode();
  if (!mounted) return;
  final user = context.read<AuthProvider>().currentUser;
  final canHost = user?.role == 'host' || user?.role == 'admin';
  final resolved = (saved == kModeHost && canHost) ? kModeHost : kModeGuest;
  setState(() {
    _mode = resolved;
    _bootstrapped = true;
  });
}

// In build, suppress the slide on initial bootstrap:
AnimatedSwitcher(
  duration: _bootstrapped ? const Duration(milliseconds: 320) : Duration.zero,
  ...
)
```

Plus: also react to `AuthProvider` updates so a late-arriving user doesn't get stranded in guest mode. Either watch `context.watch<AuthProvider>()` in build and re-resolve mode if `canHost` flips false→true, or wire a one-shot listener.

---

## Medium (Quality / maintainability)

### M1 — Circular import between `guest_shell.dart` ↔ `profile_screen.dart`
**Files:** `guest_shell.dart:8` (imports profile_screen), `profile_screen.dart:3-4` (imports `kModeGuest`/`kModeHost` from guest_shell)

Dart tolerates this because both sides use `show` filters and the constants are top-level, but it's a code smell — the persona constants are a shared domain concept, not "guest_shell internals". Two follow-on costs: (a) any tool that linearizes imports (golden tests, code-gen) gets confused; (b) future refactor extracting a `HostShell` will have to untangle this.

**Fix (small):** Extract to `lib/features/shell/persona_mode.dart`:
```dart
/// Persona modes for the bottom-nav shell.
const String kModeGuest = 'guest';
const String kModeHost = 'host';
```
Both files import that. Removes the cycle and signals these are first-class domain constants. ~10 LOC change, no behavior change.

---

### M2 — `_HostBuildingsTab` double-nests `Scaffold` around `BuildingListScreen`
**File:** `guest_shell.dart:276-300`, `building_list_screen.dart:1-15`

`BuildingListScreen` is documented as "chrome-less … parent Scaffold provides the surface" (header comment line 8-9), but it internally calls `ScaffoldMessenger.of(context).showSnackBar(...)` at line ~45 (after create dialog). When wrapped in a new `Scaffold` by `_HostBuildingsTab`, the SnackBar is hosted by the **inner** Scaffold (the wrapper), so:

1. SnackBar appears **above** the bottom NavigationBar (correct, since wrapper Scaffold knows about the bar via the outer Scaffold's bottom inset propagation? — actually no, the wrapper Scaffold has NO `bottomNavigationBar`, so the SnackBar will float at the wrapper's bottom, which is **above** the real NavigationBar). Visually fine.
2. **However**, any FAB defined on the wrapper Scaffold (none today) would overlap. Since current code has no FAB inside this tab, it works — but the pattern is fragile for the next person.
3. `MediaQuery.padding.bottom` will be applied by the inner Scaffold's `body` even though the outer Scaffold also accounts for it → potential double bottom inset. Worth quick visual verification on iPhone notch/home-indicator devices.

**Recommendation:** Either:
- (a) Lift the AppBar styling into `BuildingListScreen` itself (acceptable if the screen is only used here), removing the wrapper Scaffold entirely; or
- (b) Add a doc comment to `_HostBuildingsTab` warning future devs about the double-scaffold pattern and pass `bottomInset: false` via `MediaQuery.removePadding` if needed.

---

### M3 — `_currentIndex` reset to 0 on mode switch — intentional but undocumented
**File:** `guest_shell.dart:68-77`

`_setMode` resets `_currentIndex = 0`. This is correct (host tab indices don't map to guest tab indices) but it discards user position when toggling — e.g., guest on "Đặt lịch" tab toggles to host, comes back, lands on "Khám phá" not "Đặt lịch". The plan accepts this implicitly ("IndexedStack giữ state riêng cho mỗi mode"). The IndexedStack key is `ValueKey(_mode)` so the **stack widget itself is replaced** on mode flip → child state for the OTHER mode's tabs is **fully discarded**, not just deselected.

That means: switch guest→host→guest causes guest tabs to lose all scroll positions, in-flight provider fetches, BookingHistoryScreen filter state, etc. The plan says "IndexedStack giữ state riêng cho mỗi mode" — currently it does NOT preserve state across mode flips because the keyed switch tears down the subtree.

**Decision needed:** If preserving state across flips is desired (Airbnb does — switching personas is cheap), keep two IndexedStacks alive simultaneously inside an `Offstage`/`Visibility` wrapper. If discarding is fine ("entering a different mode is like a fresh context"), document it.

**Suggested doc fix at minimum:**
```dart
// Mode flip replaces the IndexedStack — child states for the OTHER mode are
// discarded (acceptable: a persona flip is conceptually a fresh entry into
// that mode). Within a mode, IndexedStack preserves per-tab state.
```

---

### M4 — `AnimatedSwitcher` keyed on `_mode` only, but `_currentIndex` also drives child changes
**File:** `guest_shell.dart:133-153`

Tap a tab inside the same mode → `_currentIndex` changes → `IndexedStack` swaps shown child internally → `AnimatedSwitcher`'s child has the same key `ValueKey(_mode)` → no transition (correct, what we want). But the slide-fade transition was wired to fire **only** on mode switches; if you ever decide to animate tab swaps too, the current key strategy will require rework. Not a bug today, just a constraint to flag.

---

### M5 — `BecomeHostIntroScreen` uses `pushReplacement` to step into onboarding — back-stack quirk
**File:** `become_host_intro_screen.dart:43-48`

`Navigator.pushReplacement` to `HostOnboardingStep1Screen`. If the user backs out from step 1 → lands directly in the previous route (Profile tab), **not** in the intro screen they just saw. UX is fine, but the intro is then unreachable from the back stack until they re-tap the CTA. That's intentional ("intro is one-shot") but worth confirming with design.

Also: if onboarding flow has its own multi-step back navigation, a `pushReplacement` here may interact oddly with `Navigator.pop()` chains. Verify by stepping Step1 → tap back arrow → expect to land on Profile (not blank route).

---

### M6 — `clearLastMode` is dead code today
**File:** `user_prefs_service.dart:29-33`

It's defined but no caller. Once H1 is fixed, this becomes alive. Leaving as-is for now is fine; flagged so reviewer doesn't think it's unused-on-purpose.

---

### M7 — `_PersonaSwitcher` tap targets borderline below 48dp minimum
**File:** `profile_screen.dart:480-501` (`_Segment.build`)

Each segment uses `padding: EdgeInsets.symmetric(vertical: 10)` — text height ~14-16px + 20px padding = ~34-36px total. **Below the 48dp Material accessibility minimum** for touch targets. The InkWell extends to the parent's `Expanded` width so horizontal is fine, but vertical fails.

**Fix:**
```dart
padding: const EdgeInsets.symmetric(vertical: 14), // ~14×2 + 16 = 44px
// or wrap with constrainedBox(minHeight: 48)
```

Same applies to `_BecomeHostCta` (vertical: `HD.s12` = 12 → ~36px height). Bump to `HD.s14` or `HD.s16`.

---

### M8 — Persona switcher contrast: white text on `HD.ink` (selected) — need to verify ratio
**File:** `profile_screen.dart:494` — `HD.eyebrow(color: selected ? HD.paperRaised : HD.ink)`

Without seeing the token values, `HD.paperRaised` on `HD.ink` (dark) is presumably high-contrast and fine, but eyebrow style at `fontSize: 11` is below WCAG comfortable reading size for low-vision users. The 11pt size at letterSpacing 1.4 was a deliberate editorial choice for the HD design system, so flagging as info — but consider bumping to 12 for the segmented control specifically (where it's interactive UI, not editorial decoration).

---

## Low (Style / nits)

### L1 — `final myListings = hp.myHouses.isNotEmpty ? hp.myHouses.length : hp.houses.where((h) => h.hostId == user.id).length;`
**File:** `profile_screen.dart:45-47`

This fallback hides intent — if `myHouses` is empty, we scan ALL houses to count user's listings. That's O(n) on every Profile rebuild, and `n` could be large. Provider should expose a single accurate `myHousesCount`. Not refactor-now, but flag as tech debt the next time `HouseProvider` is touched.

### L2 — Hard-coded color literals in profile_screen.dart (`0xFFB71C1C`, `0xFFEFF4FF`, etc.)
**File:** `profile_screen.dart` throughout

These are pre-existing in the file, but new code added in this refactor (the persona switcher) uses HD tokens correctly. Recommend migrating the rest opportunistically next pass — mixing palette systems within one screen is a known smell.

### L3 — `_BecomeHostCta` is not const-constructible
**File:** `profile_screen.dart:503` — `class _BecomeHostCta extends StatelessWidget`

No `const` constructor declared → `_BecomeHostCta()` rebuilds on every profile rebuild. Trivial impact (small widget) but cheap fix:
```dart
class _BecomeHostCta extends StatelessWidget {
  const _BecomeHostCta();
  ...
}
```

### L4 — `kModeGuest`/`kModeHost` as string constants, not enum
**File:** `guest_shell.dart:17-18`

String constants are not type-safe — typo `kModeHsot` compiles. An `enum PersonaMode { guest, host }` would be safer. Pre-existing call sites are few (4 files), so refactor is cheap. Aligns with TypeScript/React rule "Prefer string literal unions over enum" — but in Dart, enums ARE the idiomatic type-safe choice (no string-literal-union equivalent).

### L5 — `HostAppointmentsScreen` initial fetch via `postFrameCallback` — race with bottom-nav tab-change fetch
**File:** `host_appointments_screen.dart:21-31`, `guest_shell.dart:84-95`

When user toggles into Host mode then taps the Yêu cầu tab, BOTH paths fire `fetchAppointments(userId, 'host')`:
1. `HostAppointmentsScreen.initState` → `postFrameCallback` → `_refresh()`
2. `_GuestShellState._onTabChanged(2)` in host mode → fires `fetchAppointments`

Two near-simultaneous network calls for the same data — wasteful and possible UI flicker if responses arrive out of order. Provider should debounce or the shell-level call should be removed (let the screen own its data load).

### L6 — `_refreshBadges` called from 3 places (initState, mode flip, every tab change)
**File:** `guest_shell.dart:47, 76, 94`

Same call, often redundant. Calling it inside `_onTabChanged` means switching from tab 0 ↔ tab 1 fires a badge refresh — likely unintended. Consider gating to only call when the mode changes or when the appointments tab specifically is visited.

### L7 — `withOpacity` warnings — out of scope
Per instructions, ignored.

---

## Positive Observations

- **Clear separation of state ownership.** `GuestShell` owns `_mode` and `_currentIndex`; `ProfileScreen` is a controlled component via `mode`/`onModeChanged`. Good unidirectional flow.
- **Smart fallback in `UserPrefsService`.** All read/write/delete wrapped in try/catch returning sane defaults — failure is non-fatal, matches the existing `SessionService` pattern.
- **Defensive `initialTab` clamp** at `guest_shell.dart:39-40` — old deeplinks with `initialTab=5` correctly clamp to 0 with a comment explaining why. Good citizen of legacy deeplinks.
- **`_HostBuildingsTab` separation** — keeping `BuildingListScreen` chrome-less is the right call for reusability, even if the wrapper has the M2 nits.
- **Editorial design consistency.** `BecomeHostIntroScreen` is tight: masthead + 4 numbered benefits + single accent CTA. Eyebrow + accent strip motifs match the HD token system used elsewhere.
- **`_setMode` early-return on no-op** at line 69 prevents wasted rebuilds and stuck slide direction.
- **FAB visibility gate** (`_mode == kModeGuest && _currentIndex == 0 && canHost`) is exactly what was specified — clean boolean.
- **HostAppointmentsScreen filter pills** with counts in `[N]` brackets is a small editorial touch that matches HD aesthetic.

---

## Edge Cases Found (scout-style)

| # | Scenario | Outcome | Severity |
|---|---|---|---|
| EC1 | User logs out as Host A, logs in as Guest B same device | `last_active_mode='host'` persists; role-gate downgrades — but stored value is wrong identity (H1) | HIGH |
| EC2 | App cold-start while AuthProvider still bootstrapping `currentUser` | `canHost=false` → forced to guest; no re-evaluation when user loads (H2.3) | HIGH |
| EC3 | Switch guest→host→guest rapidly | Loses guest tabs' scroll state, in-flight fetches (M3) | MEDIUM |
| EC4 | Tap "Trở thành chủ nhà" intro, complete onboarding, press back from Step1 | Lands on Profile, not Intro (pushReplacement) — intentional but verify (M5) | LOW |
| EC5 | Open Host mode → tap Yêu cầu tab cold | 2 parallel fetchAppointments calls fire (L5) | LOW |
| EC6 | Host with 0 buildings switches into Host mode → "Nhà trọ" tab | `_HostBuildingsTab` wrapper Scaffold renders empty state from inner screen; SnackBar after creating building floats above NavBar (M2) | LOW |
| EC7 | Web platform (`_session_storage_web.dart`) — last_active_mode stored in localStorage | Not encrypted; low-sensitivity data so acceptable, but document the difference | LOW |
| EC8 | `initialTab` passed as 0 but user was last on host tab 2 → boots into guest tab 0 (wrong slot) | Bootstrap doesn't restore last-tab-within-mode, only mode — acceptable, but flag if "remember last tab" was implied | LOW |

---

## Security & Privacy

- **`last_active_mode` is non-sensitive** (just a string `'guest'`/`'host'`) — being stored in `FlutterSecureStorage` is overkill but harmless. localStorage on web is fine.
- **No PII or secrets** introduced in any of the new files.
- **No injection / XSS / SQL surfaces** in this diff.
- **No new external API calls.** Existing endpoints (`fetchAppointments`, `refreshBadgeCounts`) reused.
- **Auth check on FAB:** `showFab` gates on `canHost` — host check is client-side only. Backend must independently enforce that only hosts can POST to `/listings` when "Đăng phòng" submits. Verify `PostHouseScreen` submission goes through a protected endpoint. (Not in scope of this diff, just a note.)
- **H1 above** is the only real privacy concern in scope.

---

## API Contract / Backwards Compatibility

- `GuestShell({super.key, this.initialTab = 0})` — same constructor signature as before. The clamp behavior is the breaking-but-graceful change (old `initialTab=4` previously meant "Tin đăng tab", now silently clamps to "Khám phá"). Document this in the changelog if any external deeplinks depended on it.
- `ProfileScreen` constructor gained 3 new optional named params with defaults — backwards compatible.
- No DB schema, no API endpoint, no provider public-interface changes.

---

## Metrics

- **Files changed/added:** 6
- **LOC added:** ~700 (incl. profile_screen which is mostly pre-existing)
- **New widgets:** `_PersonaSwitcher`, `_Segment`, `_BecomeHostCta`, `_HostBuildingsTab`, `_FilterStrip`, `_Pill`, `BecomeHostIntroScreen`, `_Masthead`, `_BenefitsSection`, `_BenefitRow`, `_CtaSection`
- **Cyclomatic complexity hotspot:** `_GuestShellState.build` (~50 LOC) and `ProfileScreen.build` (long ListView). Both readable; no extraction needed yet.
- **Flutter analyze:** clean (per request, not re-run).

---

## Recommended Actions (Prioritized)

1. **[H1]** Add `await UserPrefsService.instance.clearLastMode();` in `AuthProvider.logout()` before `notifyListeners()`. ~1 line.
2. **[H2]** Add `_bootstrapped` flag + zero-duration AnimatedSwitcher on first build to eliminate cold-start guest→host flash; also re-evaluate mode when `AuthProvider.currentUser` arrives late. ~15 lines.
3. **[M7]** Bump persona switcher segment vertical padding from 10 to 14, and `_BecomeHostCta` vertical padding from `s12` to `s14`/`s16`. ~2 lines.
4. **[M1]** Extract `kModeGuest`/`kModeHost` into `lib/features/shell/persona_mode.dart`; update 2 imports. Removes cycle.
5. **[M3]** Document IndexedStack state-discard behavior on mode flip OR refactor to keep both mode stacks alive in `Offstage`. Decision pending design call.
6. **[L5/L6]** Remove redundant `fetchAppointments` call in `_onTabChanged` (let screen own its load), and gate `_refreshBadges` to mode-change/tab-2 only.
7. **[L3]** Add `const _BecomeHostCta();` constructor.

---

## Verdict

**CONDITIONAL** — solid refactor with clear intent and good adherence to plan. Two HIGH issues (logout leak + cold-start mode flash) should land before ship. Everything else is polish or future-proofing.

**Score:** 7.5 / 10
- Correctness: 8/10 (H1, H2 caveats)
- Design adherence to plan: 9/10
- Code clarity: 8/10
- Accessibility: 6/10 (M7 below WCAG)
- Test coverage in this diff: N/A (no tests added — Flutter widget tests recommended for shell + switcher; not blocking for this PR)

---

## Unresolved Questions

1. **State preservation across mode flips** (M3) — discard or keep both stacks alive? Need PM/design call.
2. **`BecomeHostIntroScreen` reachability after onboarding back** (M5) — confirm with design that intro is one-shot.
3. **Widget tests** — is the team expecting widget tests for shell mode switching + segmented control in this PR, or as a follow-up?
4. **Web vs native storage divergence** — should `last_active_mode` on web go through `flutter_secure_storage`'s web fallback explicitly, or is current localStorage acceptable? (Low priority; non-sensitive value.)
