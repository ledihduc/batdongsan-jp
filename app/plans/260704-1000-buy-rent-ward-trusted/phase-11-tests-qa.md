# Phase 11 — Tests + QA (Release 1)

**Priority:** P0 (blocks Release 1 rollout)
**Depends on:** Phases 01–07 (backend + Flutter UI)
**Status:** IN PROGRESS

## Context

- Plan overview: `plan.md` §11
- Prior code review: `reports/code-review-phase-04-07.md`
- Remediation report: `reports/remediation-h1-m1-m7.md`
- Verification review: `reports/code-review-remediation-verification.md` — verdict APPROVED

## Scope of this phase

Cover the units and widgets introduced or modified in Phases 01–07 that are NOT already covered by the backend pytest suite (which already has 21/21 passing after remediation).

### In scope
- Backend: 21 tests already exist in `test_houses_transaction_type.py` (13) and `test_admin_trusted.py` (8). Phase 01+02 remediation added 2 H1 regression tests. **DONE.**
- Flutter model: `HouseModel` new fields + defaults + getters.
- Flutter widget: `DsTrustedBadge` — semantics, structure, tokens.

### Out of scope (deferred, with rationale)
- **`_TransactionTypeSelector` widget test** (private class in `guest_home_screen.dart`).
  - Reason: private widget, would require extracting to a public file. Adds risk to Release 1 scope. Follow-up: extract to `lib/features/guest/home/widgets/transaction_type_selector.dart` and add widget test.
- **`_buildTransactionTypePicker` widget test** (private method in `post_house_screen.dart`).
  - Reason: not extractable to a widget without refactoring the enclosing screen. Same follow-up as above.
- **`HouseProvider` v2 tests** (`setTransactionType`, `fetchHousesByStatus('published')` merge).
  - Reason: `HouseProvider` internally constructs `ApiHouseRepository()` — no DI hook to inject a fake. Testing requires a small refactor to accept `IHouseRepository`. Follow-up ticket.
- **`AdminTrustedMarkScreen` widget test** with mocked repo.
  - Reason: same DI problem — hard-coded `ApiHouseRepository()`. Follow-up ticket.
- **Ward endpoint tests** (`test_wards_endpoint.py`) → Release 2 (Phase 09–10).

## Files to create

| # | File | Purpose |
|---|------|---------|
| 1 | `test/data/models/house_model_v2_test.dart` | `HouseModel` fromMap/toMap for transaction_type, is_trusted, trusted_at, ward_slug, ward_slug_legacy. Defaults. `isForRent/isForSale/priceLabel/pricePeriodSuffix`. New `status='published'` default. |
| 2 | `test/widgets/ds_trusted_badge_test.dart` | Renders icon + label; semantics label 'Tin đã được ancu365 kiểm chứng'. |

## Files NOT modified

- `pubspec.yaml` — no new deps needed.
- Source files (`lib/`) — no product changes in this phase.

## Success criteria

- All new tests pass (`flutter test test/data/models/house_model_v2_test.dart test/widgets/ds_trusted_badge_test.dart`).
- No regressions in existing tests.
- `dart analyze test/data/models/house_model_v2_test.dart test/widgets/ds_trusted_badge_test.dart` clean.

## Follow-up tickets (post-Release 1)

1. **DI refactor for HouseProvider** — accept `IHouseRepository` via constructor to enable unit tests; migrate existing call sites (`main.dart` factory, tests).
2. **Extract `_TransactionTypeSelector` and picker widget** to public files; add widget tests.
3. **Refactor `AdminTrustedMarkScreen`** to accept repo via constructor for testability.
