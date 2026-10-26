# Phase 04 — Launch Frontend

**Priority:** P3 · **Status:** 🚀 Starting · **Est:** 1 week FE · **Depends on:** P3 FE

## Overview

Launch readiness: E2E Flutter integration tests cho 4 personas, Help Center UI, JP legal footer compliance, launch build verification.

## Scope

### 1. E2E integration tests (4 personas)
- `integration_test/jp/` using `integration_test` package:
  - `persona_owner_test.dart` — login, create listing, approve app, trigger settlement
  - `persona_broker_test.dart` — login, invite tenant, submit app, confirm renewal
  - `persona_tenant_test.dart` — browse facets, apply, sign contract, review settlement
  - `persona_admin_test.dart` — view KPI dashboard, export DSR, schedule deletion
- Each test hits staging API via `--dart-define=API_BASE=https://staging-jp.ancu365.com`.
- Golden images cho các màn critical (home, listing detail, KPI dashboard).

### 2. Help Center UI
- `lib/features/help/help_center_screen.dart` — route `/help`
- Categories: 更新 (3 FAQ), 敷金精算 (3), APPI/プライバシー (3), 支払い (2), アカウント (2), 問い合わせ (1)
- `HelpArticleScreen` — markdown rendering with `flutter_markdown`
- Content loaded from `assets/jp/help/*.md` (bundled, offline-first)
- Search bar (local string match, no BE call)

### 3. JP legal footer compliance
- `DsLegalFooter` widget shows on all JP routes:
  - 特定商取引法に基づく表記 link (Act on Specified Commercial Transactions notice)
  - 利用規約 / プライバシーポリシー / APPI 開示請求 links
  - 運営会社情報 (Operator company info) — placeholder until legal entity confirmed
- Add to `_JpAppShell` in `lib/features/jp/jp_app_shell.dart`

### 4. Launch build verification
- `tools/verify_jp_build.sh`:
  - Runs `flutter test` (expect 1845+)
  - Runs `flutter build web --release --dart-define=REGION=jp`
  - Checks bundle size (<15 MB JS)
  - Runs `python3 tools/nen_gz.py build/web`
  - Verifies no debug prints, no TODO/FIXME in release config

## Files

**New:**
- `integration_test/jp/persona_{owner,broker,tenant,admin}_test.dart`
- `integration_test/jp/jp_test_helper.dart` (login + navigation helpers)
- `lib/features/help/help_center_screen.dart`
- `lib/features/help/help_article_screen.dart`
- `lib/features/help/help_models.dart`
- `assets/jp/help/*.md` (14 articles — delivered by ops phase)
- `lib/core/widgets/ds_legal_footer.dart`
- `tools/verify_jp_build.sh`

**Modified:**
- `lib/core/router/app_router.dart` — add `/help` + `/help/:id` routes
- `lib/features/jp/jp_app_shell.dart` — mount legal footer
- `pubspec.yaml` — add `flutter_markdown`, declare `assets/jp/help/`

## Success Criteria
- 4 persona integration tests green vs staging
- Help center loads 14 articles offline, searchable
- Legal footer visible on all JP routes
- `verify_jp_build.sh` exits 0, bundle <15 MB

## Open Questions
- Golden images: baseline from staging screenshots, or defer to post-launch QA?
- Help center i18n: launch JP-only or also provide EN translations day 1?
