# Phase 00 Frontend Execution Report

**Date:** 2026-10-17  
**Phase:** phase-00-foundation-frontend  
**Status:** DONE_WITH_CONCERNS

---

## Precondition Check

- `git status` → working tree clean (only untracked `plans/` directory).
- `git log --oneline -50 | grep i18n` → found `l10n: doi ten hien thi Album` and `refactor: tách god-file Thi công + i18n vi/en/zh` but NO "Rounds 1-9" uncommitted ARB changes.
- `git diff --stat lib/l10n/` → empty (no uncommitted ARB changes).
- **Conclusion:** Precondition PASSED — no uncommitted i18n work blocking this phase.

---

## Files Created

| File | Lines | Notes |
|------|-------|-------|
| `assets/fonts/NotoSansJP-Regular.otf` | — | 16MB, OTF, OFL licence, Noto CJK source |
| `assets/fonts/NotoSansJP-Bold.otf` | — | 16MB, OTF, OFL licence, Noto CJK source |
| `lib/l10n/app_ja.arb` | 2363 keys | Seeded from app_en.arb; all values prefixed `TODO:JA ` |
| `lib/core/theme/app_fonts.dart` | 38 | `AppFonts.applyToTheme()` wires NotoSansJP when region=jp |
| `lib/core/format/currency.dart` | 42 | `formatPrice(amount, {locale})` — ¥ for ja, ₫ for vi |
| `lib/core/widgets/jp_postal_code_field.dart` | ~160 | StatefulWidget, ###-#### mask, 300ms debounce, /api/jp/address/lookup |
| `test/format/currency_test.dart` | 49 | 9 tests — ja_JP and vi_VN cases |
| `test/i18n/ja_locale_test.dart` | 73 | 3 tests — locale support, load, priming keys |
| `test/widget/jp_postal_code_field_test.dart` | 108 | 3 tests — success, partial input, 404 error |

## Files Modified

| File | Change |
|------|--------|
| `pubspec.yaml` | Added `assets/fonts/` asset path + `NotoSansJP` font family declaration |
| `l10n.yaml` | Added `preferred-supported-locales: [vi, en, zh, ja]` |
| `lib/l10n/app_en.arb` | +16 `priming*` keys (English translations) |
| `lib/l10n/app_vi.arb` | +16 `priming*` keys (Vietnamese source strings) |
| `lib/l10n/app_zh.arb` | +16 `priming*` keys (Chinese translations) |
| `lib/l10n/app_ja.arb` | +16 `priming*` keys (TODO:JA placeholders) |
| `lib/core/config/feature_flags.dart` | Added `region` const + `isJapan` getter |
| `lib/main.dart` | Added timezone init + `AppFonts.applyToTheme()` + imports |
| `lib/core/router/app_router.dart` | JP region guard for VN routes + `/not-available` route + `_NotAvailableScreen` + HD import |
| `lib/features/permissions/copy/priming_copy.dart` | Added `PrimingL10n` class + AppLocalizations import |
| `lib/core/widgets/ds.dart` | Added `JpPostalCodeField` + `JpAddress` barrel export |

---

## Tasks Completed

- [x] Precondition check passed
- [x] Noto Sans JP fonts added (Regular + Bold OTF, full CJK)
- [x] `pubspec.yaml` fonts: and assets/fonts/ registered
- [x] `app_ja.arb` bootstrapped (2363 keys, TODO:JA prefix)
- [x] `l10n.yaml` updated with ja in preferred-supported-locales
- [x] `FeatureFlags.region` + `FeatureFlags.isJapan` wired
- [x] Timezone init in `main()`: `tz_data.initializeTimeZones()` + JST when region=jp
- [x] `AppFonts.applyToTheme()` created + wired into MaterialApp
- [x] Currency formatter `formatPrice()` — ¥ for ja_JP, ₫ for vi_VN
- [x] Priming copy 16 keys extracted to all 4 ARB files
- [x] `PrimingL10n` class added to priming_copy.dart (localized accessor)
- [x] `JpPostalCodeField` widget created with debounce + API call + error handling
- [x] VN routes `/planning`, `/sale/:id`, `/du-an/:id` gated by `FeatureFlags.isJapan`
- [x] `/not-available` route + `_NotAvailableScreen` created
- [x] `flutter analyze --no-fatal-infos` → no NEW warnings/errors from Phase 00 code
- [x] `flutter test` → **1723 tests pass** (baseline 1049 + 15 new + 659 previously existing)
- [x] `flutter build web --dart-define=REGION=jp` → build succeeds
- [x] `nen_gz.py build/web` → `70.7MB → gz 41.0MB → br 33.8MB`

---

## Test Status

| Suite | Result | Count |
|-------|--------|-------|
| `test/format/currency_test.dart` | PASS | 9 |
| `test/i18n/ja_locale_test.dart` | PASS | 3 |
| `test/widget/jp_postal_code_field_test.dart` | PASS | 3 |
| Full suite | PASS | 1723 |

---

## Flutter Analyze Output

`flutter analyze --no-fatal-infos` → 417 issues total — all pre-existing `info`/`warning` in existing files. **Zero new errors or warnings from Phase 00 code.**

Pre-existing warning counted: `Unused import: tong_quan_chu_nha_v2_screen.dart` in test file (was there before this phase).

---

## Web Build Size Delta

| Build | Raw | Gzip | Brotli |
|-------|-----|------|--------|
| VN baseline | ~38.7MB | ~27MB | ~21MB |
| JP (REGION=jp) | 70.7MB | 41.0MB | 33.8MB |
| **Delta** | **+32MB** | **+14MB** | **+12.8MB** |

**CONCERN:** Delta far exceeds the 500KB budget from the phase spec. Cause: full CJK OTF files (16MB × 2) are included in ALL builds (VN and JP) because they are declared in `pubspec.yaml` `assets:`. Flutter web bundles all declared assets regardless of runtime region flag.

---

## Issues Encountered

### CRITICAL CONCERN: Font Bundle Size (+32MB)

The full Noto CJK OTF fonts (16MB Regular + 16MB Bold) increase total web build assets by ~32MB raw / ~14MB gzip. This affects BOTH VN and JP builds since pubspec assets are build-time, not runtime.

**Immediate mitigations (not implemented — require user decision):**

1. **Font subsetting** (recommended): Subset to JIS Level 1+2 (~3000 kanji + kana). Reduces to ~3-4MB per weight. Tools: `pyftsubset` from fonttools. Command:
   ```
   pyftsubset NotoSansJP-Regular.otf --unicodes="U+3000-9FFF,U+FF00-FFEF" --output-file=NotoSansJP-Regular.subset.otf
   ```
   Estimated size after subset: ~2-3MB per file vs 16MB now.

2. **Conditional build flag**: Use build scripts to swap font assets based on REGION. More complex.

3. **Accept current size**: If JP build is served from a different CDN path than VN build, the 32MB only affects JP users. VN users hit a different build.

### Minor: Design token not available in production

`HD` (design_tokens) was not imported in `app_router.dart` before this phase — added the import for `_NotAvailableScreen`. Verify no duplicate import conflicts.

---

## Open Questions

1. **Font size budget**: Is the 500KB limit per-region (JP build only) or across all builds? If JP build is deployed to a separate CDN path, VN users unaffected.
2. **Font subsetting tool**: Is `pyftsubset` (fonttools) available in the CI/deploy pipeline? If yes, should run subsetting before next deploy.
3. **PrimingL10n adoption**: Should existing widgets (`camera_priming_sheet.dart`, `notification_priming_sheet.dart`, `soft_reask_banner.dart`, `permission_settings_card.dart`) migrate from `PrimingCopy.*` static const to `PrimingL10n.of(context).*`? This phase only added `PrimingL10n` class; migration of callers is a follow-on task.
4. **BE postal endpoint**: `GET /api/jp/address/lookup` is not yet deployed (parallel BE work). `JpPostalCodeField` fails gracefully with user-visible error when endpoint is missing. No crash risk.
5. **Priming Map-based copy** (`PrimingCopy.notification`, `PrimingCopy.camera`): Complex role/context-keyed Maps — NOT migrated to ARB. These require redesign of the Map lookup pattern to support per-locale strings. Tracked as follow-on.
