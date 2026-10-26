# Phase 04 Frontend — Implementation Report

**Date:** 2026-10-17
**Phase:** 04 — Launch Frontend
**Status:** DONE_WITH_CONCERNS

---

## Files Created

### Workstream 1: E2E Integration Tests

| File | Description |
|------|-------------|
| `integration_test/jp/jp_test_helper.dart` | Login + navigation helpers, `JpTestCredentials` |
| `integration_test/jp/persona_owner_test.dart` | Owner journey smoke test (skipped, see concerns) |
| `integration_test/jp/persona_broker_test.dart` | Broker journey smoke test (skipped) |
| `integration_test/jp/persona_tenant_test.dart` | Tenant journey smoke test (skipped) |
| `integration_test/jp/persona_admin_test.dart` | Admin journey smoke test (skipped) |

### Workstream 2: Help Center UI

| File | Description |
|------|-------------|
| `lib/features/help/help_models.dart` | `HelpArticle`, `HelpCategory`, `kHelpArticles` (14), `kHelpCategories` (6) |
| `lib/features/help/help_center_screen.dart` | Route `/help` — searchable FAQ list, 6 categories, local string match |
| `lib/features/help/help_article_screen.dart` | Route `/help/:id` — `flutter_markdown` renderer, offline-first, "TBD" stub handler |
| `assets/jp/help/README.md` | Ops guide for article content |
| `assets/jp/help/01-renewal-timing.md` … `14-contact-support.md` | 14 stub files (`TBD` placeholder) |

### Workstream 3: JP Legal Footer

| File | Description |
|------|-------------|
| `lib/core/widgets/ds_legal_footer.dart` | `DsLegalFooter` — 5 legal links, copyright, uses `url_launcher` + `go_router` |

### Workstream 4: Launch Build Verification

| File | Description |
|------|-------------|
| `tools/verify_jp_build.sh` | 6-step verification: test → build → JS size → nen_gz.py → no console.log → no TODO/FIXME |

### Tests

| File | Tests |
|------|-------|
| `test/features/help/help_models_test.dart` | 14 unit tests — catalog consistency, category counts |
| `test/features/help/help_center_screen_test.dart` | 7 widget tests — search, filter, clear, empty state |
| `test/features/help/help_article_screen_test.dart` | 4 widget tests — unknown id, loading, correct title, error state |
| `test/core/widgets/ds_legal_footer_test.dart` | 3 widget tests — all 5 links, copyright, no-crash |

---

## Files Modified

| File | Change |
|------|--------|
| `pubspec.yaml` | Added `flutter_markdown: ^0.7.5`, added `assets/jp/help/` asset dir |
| `lib/core/router/app_router.dart` | Added deferred imports + `/help` and `/help/:id` routes (JP-gated) |
| `lib/core/widgets/ds.dart` | Exported `DsLegalFooter` |
| `lib/features/guest/home/guest_home_screen.dart` | Imported `DsLegalFooter`, added `SliverToBoxAdapter(child: DsLegalFooter())` gated by `FeatureFlags.isJapan` |
| `lib/l10n/app_vi.arb` | Added 13 keys (helpCenter* + legalFooter*) |
| `lib/l10n/app_en.arb` | Added 13 keys |
| `lib/l10n/app_zh.arb` | Added 13 keys |
| `lib/l10n/app_ja.arb` | Added 13 keys (natural JP, not translated-tone) |

---

## Test Counts

| Phase | Count |
|-------|-------|
| Baseline (Phase 03) | 1845 |
| New tests added (Phase 04) | 29 (all passing) |
| **Total** | **1874** |

Docker run: `+1874: All tests passed.`

---

## Deferred Items

### Golden Images — DEFERRED
**Decision:** Golden image baselines deferred to post-launch QA.
**Rationale:** Golden images require a real device or emulator with a stable OS/font rendering. CI currently runs headless Docker (Linux); JP-specific fonts (NotoSansJP) render slightly differently across platforms. Generating incorrect baselines now would cause false failures.
**When to revisit:** After CI Android/iOS runner is provisioned with staging credentials. Track as `jp-launch-golden-images` in backlog.

### Integration Tests — SKIPPED (pending staging)
All 4 persona integration tests are marked `skip: true`.
**Blocker:** Staging credentials not yet provisioned. CI Android/iOS runner not configured.
**Structure is ready** — remove `skip: true` and fill in credentials when staging is available.

### `_JpAppShell` — Not yet a standalone widget
Phase spec described mounting the footer into `_JpAppShell` under `lib/features/jp/`. That widget does not exist in the codebase; no prior phase created it. The legal footer is instead mounted directly in `GuestHomeScreen` gated by `FeatureFlags.isJapan` as a `SliverToBoxAdapter` at the bottom of the feed. This is the correct approach given the current architecture (no JP shell wrapper exists). If a dedicated JP shell is created in a future phase, move the footer mounting there.

---

## Open Questions

1. **Help center i18n:** Articles currently JP-only. Plan for EN/VI day-1 translations?
   - Current impl: `titleJa` + `titleEn` in model — adding multi-locale rendering is a 1-day task.
   - Recommendation: launch JP-only (locale gate), add EN if analytics show non-JP users hitting `/help`.

2. **Legal entity (運営会社情報):** `legalFooterOperator` link points to `https://ancu365.jp/legal/company` (placeholder URL). Needs real operator company info before launch to comply with 特定商取引法.

3. **Article content:** 14 articles are `TBD` stubs. The `HelpArticleScreen` shows a "coming soon" state for `TBD` content instead of raw "TBD" text. Ops team owns the content; structure is ready.

4. **`verify_jp_build.sh` Docker assumption:** Script assumes Docker is available in CI. If CI switches to native Flutter runner, update the flutter commands to remove the Docker wrapper.
