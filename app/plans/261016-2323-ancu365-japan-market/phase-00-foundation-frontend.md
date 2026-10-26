# Phase 00 — Frontend Foundation (JP)

**Priority:** P0 blocker · **Status:** 📋 Ready · **Est:** 1.5 weeks FE
**Context:** [Gap matrix §2.1 + §3](../../../plans/261016-2323-ancu365-japan-market/research/gap-matrix.md) · [FE scout](../../../plans/261016-2323-ancu365-japan-market/research/researcher-03-frontend-scout.md)

## Overview

Add JP locale, Noto Sans JP font, region flag, currency/timezone/date formatting for Japan, postal-code address widget, and gate VN-only screens. Must commit i18n Rounds 1-9 FIRST.

## Key insights

- Feature-first architecture at `lib/features/<feature>/`. All JP additions go in existing feature folders using `region=jp` guards.
- Design System: use `Ds*` widgets + `lib/core/theme/design_tokens.dart` ONLY for colors.
- Routing: screens that need URL/deep-link → `GoRoute` + `context.go`; sub-flows → `Navigator.push`.
- **`web/` is publicly served** — never place docs there; add new assets to `WEB_ALLOW` in `check.sh`.
- i18n Rounds 1-9 (1834 keys vi/en/zh) are UNCOMMITTED due to permission stream bug — ⚠️ **commit before this phase** or rebase hell.
- Permission priming copy at `permissions/copy/priming_copy.dart` is 130 lines of hardcoded Vietnamese const-data — must extract.

## Requirements

**Functional**
- `FeatureFlags.region = String.fromEnvironment('REGION', defaultValue: 'vn')`.
- `supportedLocales` includes `Locale('ja')`; `app_ja.arb` bootstrapped.
- Noto Sans JP bundled, applied via Ds theme when region=jp.
- Currency formatter honors locale (¥ for ja_JP, no decimals, ₫ for vi_VN).
- Date/time: `DateFormat.yMMMd('ja_JP')` + JST timezone when region=jp.
- `JpPostalCodeField` widget — enter 3-4 digits → auto-fill prefecture+city+town via BE lookup.
- VN-only screens (planning, construction, sale) hidden from router when region=jp.

**Non-functional**
- `flutter analyze` no new warnings/errors.
- `flutter test` 1049 pass still green.
- Web build size delta < 500 KB after font subset.

## Architecture

```
lib/
  core/
    config/
      feature_flags.dart          ← add region getter
    i18n/
      app_ja.arb                  ← NEW
    theme/
      design_tokens.dart          ← no change (colors stable)
      app_fonts.dart              ← NEW: Noto Sans JP wiring
    router/
      app_router.dart             ← gate VN routes by region
    widgets/
      jp_postal_code_field.dart   ← NEW
  features/
    permissions/
      copy/
        priming_copy.dart         ← extract to ARB
assets/
  fonts/
    NotoSansJP-Regular.otf        ← NEW
    NotoSansJP-Bold.otf           ← NEW
```

## Related code files

**Modify**
- `pubspec.yaml` — add `fonts:` section for Noto Sans JP; add `assets/fonts/` path
- `lib/main.dart` — register ja locale, apply JST timezone
- `lib/core/config/feature_flags.dart` — add `region` getter
- `lib/core/router/app_router.dart` — gate VN routes
- `lib/features/permissions/copy/priming_copy.dart` — replace const strings with `AppLocalizations.of(context).priming_*`
- `l10n.yaml` — add `ja` to arb-dir
- `lib/l10n/app_vi.arb`, `app_en.arb`, `app_zh.arb` — add new priming keys
- `tools/nen_gz.py` won't need change

**Create**
- `assets/fonts/NotoSansJP-Regular.otf` + `NotoSansJP-Bold.otf` (OFL)
- `lib/l10n/app_ja.arb`
- `lib/core/theme/app_fonts.dart`
- `lib/core/widgets/jp_postal_code_field.dart`
- `lib/core/format/currency.dart` — locale-aware formatter wrapper
- `test/widget/jp_postal_code_field_test.dart`
- `test/i18n/ja_locale_test.dart`

## Implementation steps

1. **PRECONDITION** — ensure i18n Rounds 1-9 committed. If not, STOP and raise with user.
2. Download Noto Sans JP OFL fonts, place under `assets/fonts/`, add to `pubspec.yaml` under `fonts:`.
3. Add `ja` to `l10n.yaml` locales list.
4. Generate `app_ja.arb` seeded from `app_en.arb` with placeholder `TODO:JA` markers.
5. Add `region` getter to `FeatureFlags` using `String.fromEnvironment`.
6. Register `Locale('ja')` in `supportedLocales` in `MaterialApp`.
7. Wire `tz.initializeTimeZones()` + default to 'Asia/Tokyo' when region=jp.
8. Create `app_fonts.dart` — returns `TextTheme.apply(fontFamily: 'NotoSansJP')` when region=jp.
9. Create `currency.dart`: `formatPrice(num amount, {String? locale})` → `¥X,XXX` for ja_JP, `X.XXX ₫` for vi_VN.
10. Extract priming_copy to ARB keys (6-8 new keys), update all 4 ARB files.
11. Build `JpPostalCodeField` widget — TextField w/ regex formatter `###-####`, calls `GET /api/jp/address/lookup` on 7-digit entry, debounce 300ms.
12. In `app_router.dart`: wrap VN `GoRoute`s with `redirect` that returns `/not-available` when region=jp.
13. Add `WEB_ALLOW` entry for new font files if `check.sh` complains.
14. Run build: `--dart-define=REGION=jp` → verify route gating + font rendering.

## Todo list

- [ ] ⚠️ User-action: commit i18n Rounds 1-9
- [ ] Noto Sans JP fonts added + pubspec configured
- [ ] `app_ja.arb` bootstrap + l10n.yaml updated
- [ ] `FeatureFlags.region` wired
- [ ] JST timezone defaulted when region=jp
- [ ] `app_fonts.dart` applied in Ds theme
- [ ] Currency formatter locale-aware
- [ ] Priming copy extracted to ARB
- [ ] `JpPostalCodeField` widget + tests
- [ ] VN routes gated by region
- [ ] `flutter analyze` clean
- [ ] `flutter test` green (≥1049)
- [ ] Web build + `nen_gz.py` + size check

## Success criteria

- `flutter run -d chrome --dart-define=REGION=jp --dart-define=API_BASE_URL=https://ancu365-dev.ddns.net` → UI in JA, ¥ formatting, Noto Sans JP glyphs, postal lookup works.
- `--dart-define=REGION=vn` → VN behavior unchanged, planning/construction/sale screens accessible.
- Both regions build to web without errors.

## Risk assessment

- **Font bundle size** — use OFL subset (JIS Level 1+2) if full bundle exceeds budget.
- **ARB migration conflict** — if Rounds 10-12 (89 files pending) also land, coordinate merge order.
- **Permission priming copy breaking change** — add tests that render in all 4 locales.

## Security considerations

- Postal lookup field: regex-validate input client-side, trust BE for sanitization.
- Font files: verified OFL source, no runtime font loading from untrusted URLs.

## Next steps

- Unblocks: Phase 01 (JP listing UX, 内見 scheduler, chat JA).
- Verify VN regression with a `--dart-define=REGION=vn` smoke pass before closing.
