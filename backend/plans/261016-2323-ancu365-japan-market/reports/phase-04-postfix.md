# P4 Launch — Post-Fix Report

Date: 2026-10-17

## Agent orchestration outcome

- **Ops agent** (educational-copywriter): DONE — 21 files (3 legal docs + 4 comms templates + 14 help articles + 1 report).
- **BE agent** (fullstack-developer): DONE_WITH_CONCERNS — seed script, 4 E2E persona tests, Tokyo deploy configs, compliance evidence endpoint. 14/14 unit tests pass under Python 3.11.
- **FE agent** (fullstack-developer): DONE_WITH_CONCERNS — help center UI, legal footer, build verify script, 4 persona integration tests scaffolded. 1874 FE unit tests pass.

## Orchestration bug + fix (this session)

**Issue:** FE agent wrote 14 numbered TBD stub files (`01-renewal-timing.md` … `14-contact-support.md`) and wired `help_models.dart` to load them. Ops agent independently wrote 14 real-content files with semantic slugs (`renewal-overview.md`, `settlement-dispute.md`, etc.). Agent completion order (Ops → BE → FE) left both file sets co-existing, with the loader pointing at the empty stubs.

**Fix applied:**
1. Rewrote `lib/features/help/help_models.dart` — remapped all 14 article IDs + asset paths to Ops's semantic slugs; aligned category keys (`settlement` not `deposit`, `appi` not `privacy`, `inquiry` not `support`).
2. Deleted 14 stub files from `assets/jp/help/`.
3. Updated `test/features/help/help_models_test.dart` + `help_article_screen_test.dart` to use new slug IDs + category keys.
4. Added `_stripFrontmatter()` in `help_article_screen.dart` so YAML `---` blocks don't render as hr+text in the markdown view.

## Verification

- `flutter test`: **1874 / 1874 passed** (0 failing).
- BE module AST parse: all P4 new files parse clean.
- BE compliance endpoint: 14/14 unit tests pass per agent report (Python 3.11 required — local Python 3.9 has pre-existing `Mapped[date]` typing issue in unrelated `short_inventory.py`).

## Deferred for human/ops handoff

1. **Legal review** — `docs/jp/legal-review-packet.md` ready for 弁護士 consultation. 10 numbered questions flagged.
2. **Tokyo infra deploy** — runbook in `deploy/jp/runbook-tokyo-deploy.md`; needs AWS creds + manual approval to execute.
3. **Seed script staging run** — BE agent flagged: `organizations` + `jp_listings` schema assumptions need validation against actual Alembic migration history before running on staging DB.
4. **E2E persona tests** — both BE (pytest) and FE (integration_test) marked skipped pending staging URL + credentials.
5. **Legal footer operator entity** — placeholder URL `ancu365.jp/legal/company` until legal entity confirmed (Synora KK or offshore + JP rep).
6. **Help center i18n** — launched JP-only; EN deferred.

## Open questions (for user)

1. Osaka DR (ap-northeast-3): post-launch or part of initial deploy?
2. RDS sizing for staging: Multi-AZ (recommended) or single-AZ (cost)?
3. Help center English translations: launch day 1 or post-launch?
4. Operator legal entity name — needed before legal footer goes live.
