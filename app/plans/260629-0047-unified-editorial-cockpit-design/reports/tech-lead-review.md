# Tech Lead Review — Unified Editorial Cockpit Design System

**Reviewer:** code-reviewer (Tech Lead lens, Flutter/Dart)
**Date:** 2026-06-29
**Scope:** 12 files (foundation + 5 sample widgets + 3 migration screens + shim)
**Plan:** `plans/260629-0047-unified-editorial-cockpit-design/plan.md`

---

## 1. Verdict

**CONDITIONAL APPROVAL** — Architecture is solid, widget library is well-shaped, migration pattern is repeatable. Approve commit AFTER addressing the 2 HIGH issues (web-safety in `contract_form_screen.dart` + Google Fonts runtime fetch policy). No CRITICAL blockers in the scoped foundation/components themselves.

Tóm tắt tiếng Việt: Foundation + widget library sạch, đủ tốt để commit. Có 1 lỗi web-safety pre-existing trong `contract_form_screen.dart` (dart:io + `File()` không chạy được trên web) — nên fix luôn vì cùng đợt migration. Google Fonts runtime fetch là rủi ro về performance/bundle/offline — cần quyết định bundle vs runtime trước khi ship.

---

## 2. Severity Table

| Level    | Count | Notes                                                              |
| -------- | ----- | ------------------------------------------------------------------ |
| CRITICAL | 0     | None in scope                                                      |
| HIGH     | 4     | web break, fonts policy, GoogleFonts allocations, shim cleanup     |
| MEDIUM   | 7     | API ergonomics, equality, theming gaps, semantic labels            |
| LOW      | 6     | naming nits, const opportunities, dead aliases                     |

---

## 3. Findings

### HIGH

#### H1 — `contract_form_screen.dart:1,121,154` — Web build breaks
`import 'dart:io';` (unqualified) at file top + `File(picked.path).readAsBytes()` at L121 and L154. On `flutter build web` (`dart2js`/`dart2wasm`) this file does not compile. Even when guarded by `kIsWeb`, an unqualified `dart:io` import will fail conditional compilation.

Pre-existing (commit `af0c344`), NOT introduced by this migration — but `cccd_uploader.dart` (same author scope, same migration) already shows the correct pattern: `import 'dart:io' show File;` + `XFile.readAsBytes()` (which is web-safe). The fix is mechanical and trivial.

**Recommendation:**
```dart
// Replace top-of-file
import 'dart:io';
// With
import 'dart:io' show File;  // (optional — only if File is still needed elsewhere)

// Replace at L121 & L154
final bytes = await File(picked.path).readAsBytes();
// With
final bytes = await picked.readAsBytes();  // XFile.readAsBytes() — web-safe
```
After this, the file compiles for web. Same fix applies to any other migrated screen that pre-existed with this pattern (see also `contract_terminate_screen.dart`, `post_house_screen.dart`, `edit_profile_screen.dart` per grep — out of scope but identical issue class).

#### H2 — Google Fonts runtime fetch policy not decided (`design_tokens.dart` all type helpers)
`HD.body()`, `HD.eyebrow()`, `HD.masthead()`, `HD.tabular()`, `HD.bigNumeral()`, `HD.buttonLabel()`, `HD.navLabel()` all call `GoogleFonts.beVietnamPro()` / `instrumentSerif()` / `jetBrainsMono()` on EVERY call. Default `google_fonts` behavior is runtime HTTP fetch with disk cache. Implications:

1. **First-launch UX** — text renders in fallback (Roboto), then re-flows when font arrives. Visible flash, especially on slow networks.
2. **Offline** — until cached, fonts are missing entirely.
3. **Web** — every cold-start hits Google CDN; not GDPR-friendly in EU.
4. **Bundle size** — package will inline fonts if pubspec asset is declared; otherwise pure network.

The plan acknowledges this in "Risks" but no decision is recorded. Pick one before commit:

- **Option A (preferred for production):** bundle the 3 font families in `assets/fonts/` and let `google_fonts` resolve from disk (`GoogleFonts.config.allowRuntimeFetching = false`). Adds ~1–2 MB to APK, but eliminates flash + makes offline work.
- **Option B:** keep runtime fetch but call `GoogleFonts.config.allowRuntimeFetching = false` in tests so they don't try to hit the network (silently passes today because no asserts). Document in `README.md` as a deliberate UX trade-off.

**Recommendation:** Option A. Add a `main.dart` early-init that pre-warms `GoogleFonts.pendingFonts([...])` if you stick with runtime fetch.

#### H3 — `TextStyle` factory allocations on every rebuild (`design_tokens.dart:87-181`)
All eleven `HD.*()` helpers return a fresh `TextStyle` via `GoogleFonts.xxx(...)` per call. In a `ListView` of N rows that each call `HD.body()` once, that is N allocations of `TextStyle` (including `GoogleFonts` wrapper logic) per frame. For most screens this is fine, but `contract_detail_screen.dart` `ListView` and `contract_form_screen.dart` `ListView` of tenant rows compound.

**Recommendation:** Cache the most common variants:
```dart
class HD {
  // Cache default (no color/size override) variants — covers 80% of call sites.
  static final TextStyle bodyDefault = GoogleFonts.beVietnamPro(...);
  static final TextStyle bodyBoldDefault = GoogleFonts.beVietnamPro(...);
  static final TextStyle eyebrowDefault = GoogleFonts.beVietnamPro(...);
  // Keep helpers for the parameterized cases.
  static TextStyle body({Color? color, double size = 14}) =>
    (color == null && size == 14) ? bodyDefault : GoogleFonts.beVietnamPro(...);
}
```
Or, simpler: switch the text helpers to return `TextStyle` literals that reference `GoogleFonts.beVietnamPro().fontFamily` only — but `GoogleFonts` resolves font assets at call time so you cannot fully avoid it. The cache pattern is the cheapest path.

#### H4 — Shim `host_dashboard_tokens.dart` still referenced by 27+ files
The shim re-exports `HD` + `HDHairline` so old imports compile. Grep shows **27 files** still import via the legacy path (mostly host/homestay calendar + reservation screens — Phase 04 partial per plan). Plan says shim is deprecated and will be deleted in Phase 12.

Risk: in this commit batch, the shim is the only thing keeping those 27 files compiling. If anyone reorders imports in Phase 12 cleanup without first updating those imports, the build breaks silently for them.

**Recommendation (low-risk path):**
1. Keep shim in this commit batch.
2. Add `@Deprecated('Import from core/theme/design_tokens.dart')` to the export statement OR a runtime warning in debug.
3. Track those 27 import paths as a follow-up codemod task before Phase 12 deletion. `sed -i 's|host/dashboard/host_dashboard_tokens|core/theme/design_tokens|g'` will do most of it in seconds.

### MEDIUM

#### M1 — `HD` is on track to become a god-class
`design_tokens.dart` is currently 314 lines and `HD` has 11 type helpers + 28 color statics + 13 spacing + 5 radii + 3 shadow groups + breakpoints + motion + curves. That is fine right now, but the plan implies 76 screens will touch it. The risk: every new feature is one more `HD.xxx` constant tacked on.

**Recommendation (NOT a blocker, plan for v2):** when `HD` exceeds ~50 surface members or 400 LOC, split:
```dart
HD.color.accent     // class HDColors
HD.type.body()      // class HDType
HD.space.s16        // class HDSpace
HD.radius.r8        // class HDRadius
HD.shadow.modal     // class HDShadow
HD.motion.short     // class HDMotion
```
Or move to a `ThemeExtension<HDExt>` so it lives in `Theme.of(context).extension<HDExt>()` (idiomatic Material 3, supports interpolation for dark mode if you ever add it). Both deferrable until painful.

#### M2 — `DsTextField` ergonomics gap: `controller` + `initialValue` mutually exclusive but no assert
`ds_text_field.dart:36,58` accepts both `controller` and `initialValue`. Flutter's `TextFormField` asserts these are mutually exclusive. If a caller passes both, the error message will be deep inside Flutter framework — confusing.

**Recommendation:** Add `assert(controller == null || initialValue == null, 'Cannot provide both controller and initialValue.')` to the constructor.

#### M3 — `DsAppBar` heuristic `Navigator.of(context).canPop()` runs every build (`ds_app_bar.dart:54`)
`canPop()` walks the navigator state; called on every build. Most cases it's cheap, but in a deep nav stack with many `DsAppBar` instances on screen (e.g. shared element transition with two app bars) this can add up.

**Recommendation:** Acceptable as-is; just track. If you ever migrate to `go_router` exclusively, `context.canPop()` from `go_router` is the alternative.

#### M4 — `DsAppBar` ignores `MediaQuery.textScaler` for `preferredSize` (`ds_app_bar.dart:45-50`)
The preferred-size calculation uses hard pixel values (60/48 + 18 eyebrow + 16 subtitle). When user enables large text (accessibility), the eyebrow + subtitle text overflows the reserved height → ellipsis or clipping. `centerTitle: false` worsens this.

**Recommendation:** Multiply by `MediaQuery.of(context).textScaler.scale(1.0)` — but `preferredSize` is a getter without `BuildContext`. Workaround: expose a `textScale` parameter the caller can pass from `MediaQuery.maybeOf(context)?.textScaler` if they care. Document the limitation in the dartdoc. Cheap fix for now is to bump base heights by ~10% (60 → 66).

#### M5 — `DsButton` does not handle long labels (`ds_button.dart:50-74`)
The `Row` with `mainAxisSize.min` will overflow horizontally if label is long + `expand: false`. No `Flexible` / `Expanded` around `Text`. On narrow screens (e.g. iPhone SE width 320), a label like "Tải lên ảnh chứng minh nhân dân" can overflow.

**Recommendation:**
```dart
Flexible(child: Text(label, style: ..., maxLines: 1, overflow: TextOverflow.ellipsis)),
```
Wrap the `Text` and clamp.

#### M6 — `DsStatusPill` recomputes `_paletteFor()` on every build (`ds_chip.dart:26`)
Minor. With ~60 pills on a busy invoice list, 60 switch evaluations per frame. Cache the result with a static `Map<DsStatusTone, _Palette>` const. Micro-optimization; not blocking.

#### M7 — `contract_detail_screen.dart` — `ApiContractRepository()` instantiated on every load
At L46, `_ensureContractLoaded` creates a new `ApiContractRepository()`. If repository has its own state (HTTP client, auth interceptor), this defeats reuse. Should be injected via provider/locator.

**Recommendation:** Move the deep-link fetch responsibility into `ContractProvider.ensureLoaded(int id)` so the provider owns repository instantiation and the screen stays presentational.

### LOW

#### L1 — `design_tokens.dart:80` — `mastheadRed` is a dead alias
Comment says "kept so old code compiles; remove in cleanup". Grep to confirm no remaining call sites before removing in Phase 12.

#### L2 — `ds_app_bar.dart:82` — Lint: `use_null_aware_elements`
`flutter analyze` reports 1 info-level lint:
```
if (leadingWidget != null) leadingWidget,
```
Replace with `?leadingWidget` collection-element syntax. Non-blocking.

#### L3 — `ds_dialog.dart:17` — `padding` default uses class-level `HD.s24` which is fine, but the `Material` wrapper has `borderRadius` set in TWO places (Material widget + inner Container decoration) — only one is needed.

`ds_dialog.dart:34-39` — Material has `borderRadius`, then inner Container also has `borderRadius` in its `BoxDecoration`. The Material clips via its own. Inner radius redundant.

**Recommendation:** Drop the inner `borderRadius` and let Material clip.

#### L4 — `ds_button.dart` — no semantic label / `Semantics` wrapper
For accessibility, the button should expose `button: true` semantics. `InkWell` does some of this but `Tooltip` and `Semantics(label: ...)` would help VoiceOver/TalkBack. Acceptable to defer; the migration mentions accessibility but no concrete tests yet.

#### L5 — `contract_form_screen.dart:55` — `_nextRowId` is `int` and grows monotonically. Wrap-around at 2^53 is impossible in human use, but the comment "without needing an external uuid package" is fine. Just naming nit — call it `_nextSeq`.

#### L6 — `app_theme.dart:17-35` — legacy aliases section
Many `static const Color` mappings (`primaryColor`, `cardBgColor`, etc.) are kept for back-compat. Confirm with grep that ALL call sites have been migrated; if so, delete in Phase 12. Otherwise they will silently mask new code that should use `HD.*` directly.

---

## 4. Architecture Commentary

### The 3-layer split — solid

```
design_tokens.dart  (HD)        ← pure constants + GoogleFonts wrappers, zero widget code
app_theme.dart      (AppTheme)  ← Material ThemeData consumer of HD
ds.dart             (barrel)    ← export surface
ds_*.dart           (widgets)   ← consumers of HD (NOT of AppTheme)
```

**Coupling check:**
- `app_theme.dart` imports `design_tokens.dart` ✓
- `ds_*.dart` widgets import `design_tokens.dart` directly, NOT `app_theme.dart` ✓ — good, this means `ds_*` widgets are theme-independent. They could be lifted to a separate package.
- `ds.dart` barrel re-exports tokens + every `ds_*` widget. Clean. No transitive leaks of internals.

**Verdict:** The split is correct and will scale. The risk is creep — see M1 about `HD` god-class. Add a 16th `ds_*` widget tomorrow → follow the obvious pattern: stateless if possible, consume `HD` for styling, export from `ds.dart`. Naming + structure is consistent enough that another engineer can land a new widget without asking questions.

### Why I'd accept `HD` over `Theme.of(context).extension<T>()`

Pragmatic reasons:
1. `HD.body()` doesn't need a `BuildContext` — usable in static initializers, top-level constants, tests without `MaterialApp` wrapper.
2. The plan explicitly defers dark mode. `ThemeExtension` shines when you have multiple brightness modes; with a single light theme it's overhead.
3. Most teams I've seen do `Theme.of(context).extension<T>()` end up wrapping it in a global helper anyway. `HD` IS that helper, with one less hop.

**However**, if dark mode comes back on the table (or whitelabel/multi-brand), pre-emptively move to `ThemeExtension<HDExt>` before that work starts. The Cost of migrating 100 widgets later is real but bounded (find/replace + import shift).

### Naming

- `HD` (short) reads cleanly in code: `HD.s16`, `HD.body()`. ✓
- `Ds*` widget prefix is a defensible choice (Design System). ✓
- One inconsistency: tokens are `HD.*` but widgets are `Ds*`. This is intentional (per plan, `HD` is back-compat) but will look odd to a new dev. Either:
  - Rename `HD` to `Ds` in a future cleanup, or
  - Add a one-line note in the barrel explaining the naming difference.

### Barrel hygiene

`ds.dart` line 25-26:
```dart
export 'empty_state.dart' show EmptyState, DsEmptyState, AppFeedback;
export 'skeleton.dart' show Skeleton, DsSkeleton, DsRowSkeleton, HouseCardSkeleton;
```
Uses `show` to limit the export surface. ✓ Prevents internal helpers from leaking. Other exports are unfiltered — fine because those files only define public types.

---

## 5. Flutter-Specific Concerns

### `const` correctness
- `DsAppBar`, `DsButton`, `DsTextField`, `DsStatusPill`, `DsFilterChip`, `DsDialog` — all `const` constructors ✓
- Call sites in `contract_detail_screen` correctly use `const DsAppBar(...)` ✓
- `contract_form_screen.dart` mostly correct. Spotted L424 — `Padding(child: Text(...))` could be `const` if the text were a static string, but `primaryCount == 0 ? ... : ...` blocks it. Acceptable.

### `key` propagation
- All `Ds*` widgets forward `super.key` ✓
- `contract_form_screen.dart:439` uses `ValueKey(row.uuid)` for tenant rows — correct pattern to preserve state across reorder/remove (C4 fix mentioned in comments). ✓

### `mounted` checks
- `contract_detail_screen._activateWithConfirm` — `if (!ok || !mounted) return;` at L193 ✓ and `if (!mounted) return;` at L196 ✓. Correct.
- `contract_form_screen._pickHandoverPhoto` — `if (mounted) setState(...)` in finally + catch ✓
- `contract_form_screen._submit` — `if (!mounted) return;` after async ✓
- `cccd_uploader._pickImage:76` — `if (!mounted) return;` after `await finalFile.readAsBytes()` ✓

All async-gap discipline is correct.

### `addPostFrameCallback` in `initState`
`contract_detail_screen.dart:33` — `WidgetsBinding.instance.addPostFrameCallback((_) { _ensureContractLoaded(); });`. Correct pattern for "fetch after first frame, requires inherited widgets (Provider) available". Two notes:

1. The callback captures `this` (the State). If the State is disposed before the frame runs (unlikely but possible during fast pop), `_ensureContractLoaded` should bail early. It does — via `if (mounted)` inside.
2. Could be simpler with `Future.microtask(_ensureContractLoaded)` — same effect, no frame coupling needed since you're not measuring layout.

Either is fine.

### Provider usage
- `context.read<ContractProvider>()` for one-shot reads in event handlers ✓
- `Consumer<ContractProvider>` in `build()` for reactive rebuild ✓
- `ChangeNotifierProvider.value(value: provider)` when pushing nested route, preserving the parent's instance ✓
- `MultiProvider` at `contract_detail_screen.dart:228` for the transfer route ✓

Correct in every spot.

### Theme propagation
`Ds*` widgets read `HD.*` directly (NOT `Theme.of(context)`). This is **deliberate and documented in the plan** — Material's `ThemeData` is a fallback for legacy code, while the `Ds` family is the source of truth. The only side-effect: if a host app overrides `MaterialApp.theme.colorScheme.primary`, `DsButton` will NOT pick it up. That's the intended contract.

Recommend a 2-line comment at top of `ds.dart`:
```dart
/// Ds* widgets consume HD tokens directly and do NOT read Theme.of(context).
/// To re-skin the app, override HD tokens — not ThemeData.
```

### `MediaQuery` / `Directionality` / `Locale` awareness
- No `Directionality` handling — Vietnamese is LTR, fine.
- No `MediaQuery.textScaler` handling in widget sizing — see M4.
- `showDatePicker` in `contract_form_screen.dart:85` uses `locale: const Locale('vi')` ✓
- `intl` package + `DateFormat('dd/MM/yyyy')` ✓ — but no `MaterialLocalizations` delegate check at app root. If the host app's `MaterialApp` doesn't have `vi` in `supportedLocales` + `localizationsDelegates`, the picker will crash. Verify in `main.dart` (out of scope for this review).

### Image / web safety
- `cccd_uploader.dart` ✓ correct branching: `Image.memory` on web, `Image.file` on native, `XFile.readAsBytes()` is web-safe.
- `contract_form_screen.dart` ✗ — see H1.

### Hot-reload safety
- No static state initialized in `initState`. ✓
- `DateFormat` is `static final` — safe.
- `_nextRowId` is per-instance, reset on new screen. ✓
- `GoogleFonts` caches internally — safe across hot reload.

---

## 6. Migration Pattern Assessment

### Pattern observed (3 sample screens)
```
1. Replace AppBar          → DsAppBar(title, eyebrow, ...)
2. Replace Scaffold bg     → backgroundColor: HD.paper
3. Replace inline colors   → HD.{token}
4. Replace TextStyle()     → HD.body() / HD.bodyBold() / HD.caption() / etc.
5. Replace SizedBox(h: 16) → SizedBox(height: HD.s16)
6. Replace ElevatedButton  → DsButton(variant, size, expand, icon, isLoading)
7. Replace AlertDialog     → showDsConfirm() / showDsAlert()
8. Replace status pills    → DsStatusPill(label, tone)
9. Replace TextField       → DsTextField(controller, label, validator, ...)
10. Hairline dividers      → HDHairline()
```

### Is it repeatable for the remaining 30+ screens?
**Yes.** The pattern is mechanical enough to delegate to a codemod or a junior dev with the rule list above. The 3 sample screens all follow it consistently — no half-migrated state, no leftover `Color(0xFF...)` in the scoped screens, no raw `TextStyle()`.

### Concerns observed
- `contract_form_screen.dart:391` — `Container(decoration: BoxDecoration(color: HD.negative, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: HD.paperRaised))`. The close-button on photo thumbnails is hand-rolled. Could be `DsCloseChip` or similar; or factor into the photo strip widget. Minor.
- `contract_form_screen.dart:355-362` — inline `LinearProgressIndicator(color: HD.accent, backgroundColor: HD.hairline)`. The theme's `progressIndicatorTheme` already sets these. Redundant but harmless.
- `contract_form_screen.dart:465-502` — `_datePickerButton` is a private helper, duplicated logic with what `DsTextField(readOnly: true, onTap: ...)` could do. Consider promoting into `DsDatePickerField` if the form pattern recurs (likely).

### Variant semantics — used correctly?
- `DsButtonVariant.primary` for "Tạo hợp đồng" ✓
- `DsButtonVariant.destructive` for "Trả phòng (kết thúc)" ✓ — semantically correct: irreversible.
- `DsButtonVariant.secondary` for "Chuyển phòng" ✓ — non-primary, reversible-ish.
- `DsButtonVariant.ghost` for "+ Thêm ảnh" / "+ Thêm" ✓ — inline action, no fill.

All semantic. Pattern is clear.

### `showDsConfirm` replacing all `AlertDialog`?
In scope: yes. `contract_detail_screen.dart:185` uses it ✓. No `AlertDialog` survives in the 3 sample screens.

### Is `DsTextField` API rich enough?
Mostly yes (controller, label, validator, prefix/suffix icon, maxLines, formatters, focus node). Missing: `decoration` override, `style` override for tabular numerals (e.g. money fields). For the 80% case this is fine; expose those if needed in Phase 12.

---

## 7. Pre-Commit Blockers (Prioritized)

**Must fix before commit:**
- None in the scoped foundation/widget code.

**Should fix in same commit batch (recommended):**
1. **H1** — `contract_form_screen.dart` web-safety (10-minute fix, mechanical replace).
2. **H2** — decide & document the Google Fonts loading strategy. Even if you decide "runtime fetch for now", record it in `README.md` so the next dev doesn't relitigate.

**Can defer to follow-up commit:**
3. **H3** — `TextStyle` allocation caching. Profile first; may be a non-issue.
4. **H4** — shim deletion + codemod of 27 import paths. Phase 12.
5. All MEDIUM and LOW.

---

## 8. What to Do Next (Ordered TODO)

1. **Fix H1** — patch `contract_form_screen.dart` to use `XFile.readAsBytes()` + scoped `dart:io show File` (or drop entirely). Also audit `contract_terminate_screen.dart`, `post_house_screen.dart`, `edit_profile_screen.dart` for same pattern (out of this scope but same risk class).
2. **Decide H2** — bundle vs runtime fetch. Add a one-paragraph decision note to plan or `README.md`. If runtime, set `GoogleFonts.config.allowRuntimeFetching = false` in test setup so tests don't hit network.
3. **Address L2** — apply `?leadingWidget` lint fix in `ds_app_bar.dart` (zero-risk).
4. **Add M2** assert to `DsTextField` (zero-risk).
5. **Commit** the foundation + widget library + migrated screens in conventional commits, grouped by phase (Phase 01-02 / Phase 03 / Phase 05 / Phase 09 / Phase 10 / Phase 11 / shim).
6. **Phase 12 follow-up plan** — codemod the 27 `host_dashboard_tokens.dart` imports, delete shim, delete legacy `AppTheme` const aliases, run `flutter analyze` + boot every route once.
7. **Profile H3** — run a DevTools timeline on the busiest screen (analytics drill or contract list). If `GoogleFonts` is hot, apply the cache.
8. **Audit Phase 04 calendar screens** — per plan they're "partial". Should not block this commit but flag in plan for next iteration.
9. **Plan an accessibility pass** — text scaling support on `DsAppBar`, `Semantics` labels on `DsButton`, color contrast on warm-paper background (`HD.inkMuted` on `HD.paper` is ~3.5:1 — fails WCAG AA for body text, OK for captions only).

---

## Unresolved Questions

1. **Bundle the fonts or runtime fetch?** — needs explicit user decision. Affects APK size, offline UX, GDPR posture, test infra.
2. **Are there any other migrated screens using `dart:io` + `File()` outside this review's scope?** — grep shows 8 files total; only 2 in this review (`contract_form_screen.dart` flagged H1, `cccd_uploader.dart` clean). The other 6 are out of scope but same risk.
3. **`AppTheme` legacy color aliases (`primaryColor`, `cardBgColor`, etc.)** — confirm via grep before deleting in Phase 12. None found broken in this scope, but they may mask new code that bypasses `HD.*`.
4. **Accessibility AA conformance target** — is the team committing to AA, or "best effort"? Affects whether `HD.inkMuted` on `HD.paper` is acceptable for body copy (it currently fails AA contrast 4.5:1).
5. **`DsAppBar` text scaling** — should this be addressed in this batch or tracked as separate accessibility work?
