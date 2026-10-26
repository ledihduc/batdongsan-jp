# Remediation — Code Review Findings (H1 + M1–M7)

**Date:** 2026-07-04
**Author:** Developer (follow-up to `code-review-phase-04-07.md`)
**Scope:** Fix HIGH + MEDIUM findings from the phase-04-07 review.
**Status:** DONE — 21/21 backend tests pass, 26/26 Flutter unit tests pass, `dart analyze` clean (0 errors).

## Post-rebase note (2026-07-05)

After rebase onto main which advanced significantly (backend commits `593a348..a5a60b4`
adding legal_status + guardrail + status vocabulary `pending_review`; app commits
`41cd1df..39f569f` reshaping post form + booking availability), the following
subset of this remediation was RE-APPLIED and PUSHED:

| ID | Re-applied? | Reason |
|----|-------------|--------|
| H1 backend  | YES | Remote regressed `status` back into PUT allowlist |
| H1 client   | YES | Remote's `updateHouse` still sends `status` in body |
| M3          | YES | Remote's HouseModel still defaults to legacy `'pending'` |
| M4          | YES | Remote's revert rebuilds row, losing server `trustedAt` |
| M5          | YES | Remote's admin trusted row still shows raw `wardSlug` |
| M6          | YES | Remote still spells "Huỷ" (pre-1999) |
| M7          | YES | Remote still uses raw ApiClient in AdminTrustedMarkScreen |
| M1          | SKIP | Remote's tab set `['pending_review','published','rejected']` supersedes ours |
| M2          | SKIP | Remote fixed `moderate approve → published` at source — client-merge no longer needed |
| H1 comment (post_house_screen) | SKIP | Remote heavily reworked the file (adaptive form + legal chip); cosmetic marker not worth the merge risk |

## Summary

| ID | Severity | Status | Fix |
|----|----------|--------|-----|
| H1 | HIGH | FIXED | Backend PUT strips `status` from auto-applied keys + client strips `status` from PUT body + 2 regression tests |
| M1 | MEDIUM | FIXED | Admin tabs `[published, pending, rejected]`; `approved` folded into published (client-merge in `HouseProvider.fetchHousesByStatus`); `Gỡ tin` action available on both `published`/`approved` |
| M2 | MEDIUM | FIXED | `AdminTrustedMarkScreen._loadHouses` fetches both `published`+`approved` and dedupes by id |
| M3 | MEDIUM | FIXED | `HouseModel.status` default → `'published'` (constructor + `fromMap` fallback) |
| M4 | MEDIUM | FIXED | Optimistic revert restores original row object → `trustedAt` preserved exactly. Success path replaces row with server response (authoritative timestamp) |
| M5 | MEDIUM | FIXED | Row `locationText` now shows `district · city` (both display names); raw `wardSlug` dropped until ward-name join lands |
| M6 | MEDIUM | FIXED | `Huỷ` → `Hủy` (1999 orthography) |
| M7 | MEDIUM | FIXED | New `ApiHouseRepository.setTrusted(house, value) → HouseModel`; screen calls repo, no raw `ApiClient` |

## Files touched

### Backend
- `ancu365-backend/app/routers/houses.py` — H1: removed `status` from PUT auto-applied keys + explanatory comment.
- `ancu365-backend/tests/test_houses_transaction_type.py` — H1 regression tests: `TestPutStatusIgnored` (2 tests).

### Flutter
- `lib/data/models/house_model.dart` — M3.
- `lib/data/repositories/api_house_repository.dart` — H1 client (strip `status` from PUT body) + M7 (`setTrusted` method).
- `lib/features/host/post/post_house_screen.dart` — H1 comment (status is server-owned).
- `lib/features/admin/admin_trusted_mark_screen.dart` — M2, M4, M5, M7 + `debugPrint` on catch.
- `lib/features/admin/admin_home_screen.dart` — M1 (tab set + labels + `Gỡ tin` on published/approved) + M6.
- `lib/providers/house_provider.dart` — M1 (`fetchHousesByStatus('published')` merges legacy `approved`).

## Test results

Backend:
```
21 passed, 109 warnings in 0.46s
```
(19 prior tests + 2 new H1 regression tests)

Flutter (targeted):
```
26 tests passed — user_scope_cleanup_test + destructive_role_guard_test
```

`dart analyze` on all changed files: 0 errors (23 pre-existing warnings/info — pre-existing print/withOpacity/etc.).

## Follow-up items (deferred, tracked here)

- **M1 follow-up:** after `approved → published` data migration lands on prod and legacy `pending` tab count reads 0 for 2 weeks, remove `pending` tab from admin_home_screen and the `approved` client-side merge in `HouseProvider.fetchHousesByStatus`.
- **Ward display name join (server-side):** when Phase 08–10 (ward picker) ship, join ward display name at admin GET so `AdminTrustedMarkScreen` row can show ward name.
- **M5 upgrade path:** `LocationInputService` slug→name map is available; consider using it before Phase 08–10 if admin feedback flags the missing ward context.
- **L1–L7:** batched into a future cleanup PR (not blocking Release 1).

## Unresolved questions

1. Original review Q1: which team owns future backend hardening around `houses.py` PUT filtering? (recommend backend team owns the allowlist going forward)
2. Original review Q2: should we alias `status=approved → published` in admin GET too, not just public GET? Currently addressed with client-side merge in `HouseProvider.fetchHousesByStatus` and `AdminTrustedMarkScreen._loadHouses`. Server-side alias would simplify — worth a follow-up.
3. Original review Q5: staging smoke test of `LISTING_V2_ENABLED=false` flag flip — not verified in this remediation pass; recommend before rollout.
