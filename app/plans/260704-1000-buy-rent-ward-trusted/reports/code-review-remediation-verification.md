# Code Review — Remediation Verification (H1 + M1–M7)

**Date:** 2026-07-04
**Reviewer:** code-reviewer (Staff Engineer, production-readiness re-pass)
**Prior verdict:** CONDITIONAL — 1 HIGH + 7 MEDIUM
**Verdict:** **APPROVED**

## Verification Summary

| ID | Claim | Verified | Evidence |
|----|-------|----------|----------|
| H1 | Backend `update_house` no longer auto-applies `status` | YES | `houses.py:334-346` — allowlist is exactly `title/description/address/city/district`; explicit `SECURITY (H1)` comment; no `status` write elsewhere in handler (checked through line 404) |
| H1 | Client `updateHouse` strips `status` from PUT body | YES | `api_house_repository.dart:79-91` — `Map.from(house.toMap())..remove('status')` |
| H1 | Regression tests pass | YES | `pytest ... TestPutStatusIgnored` → 2 passed. Ran locally: `rejected` stays rejected after PUT `status: published`; title still editable when rejected |
| M1 | Admin tabs `[published, pending, rejected]`, labels `[Đang đăng, Chờ duyệt, Đã từ chối]` | YES | `admin_home_screen.dart:34-35` |
| M1 | Badge on tab 1 (pending) not tab 0 | YES | `admin_home_screen.dart:106` — `_tabController.index == 1 && pendingCount > 0` |
| M1 | "Gỡ tin" available on both `published` and legacy `approved` | YES | `admin_home_screen.dart:417` — `if (status == 'published' \|\| status == 'approved')` |
| M2 | Trusted screen fetches both `published`+`approved`, dedupes | YES | `admin_trusted_mark_screen.dart:41-54` — `Future.wait([...])` + `seen<int>` set |
| M2 | Same merge in `fetchHousesByStatus('published')` | YES | `house_provider.dart:412-431` — identical merge pattern |
| M3 | `HouseModel.status` default `'published'` (ctor + fromMap) | YES | `house_model.dart:72, 129` |
| M4 | Optimistic revert restores `original` row (isTrusted AND trustedAt preserved) | YES | `admin_trusted_mark_screen.dart:73` captures `original` BEFORE optimistic write on line 84; catch at line 102 does `_houses[index] = original` |
| M4 | Success path replaces row with server response | YES | `admin_trusted_mark_screen.dart:92-94` — `serverHouse = await _repo.setTrusted(...)`; row replaced with it |
| M5 | Raw `wardSlug` no longer displayed | YES | `admin_trusted_mark_screen.dart:230-232` — `'${house.district} · ${house.city}'`; `wardSlug` not referenced in row build |
| M6 | `'Hủy'` (1999) at line 450 | YES | Only remaining `huỷ` is in code comment at line 475 (not user-facing) |
| M7 | `ApiHouseRepository.setTrusted(HouseModel, bool) → HouseModel` exists | YES | `api_house_repository.dart:136-183` — PATCHes `/api/admin/houses/{id}/trusted`, parses `trusted_at` from server response (`DateTime.tryParse`), returns rebuilt `HouseModel` |
| M7 | Screen uses repo, not raw `ApiClient` | YES | `admin_trusted_mark_screen.dart:18` — `_repo = ApiHouseRepository()`; no `ApiClient` import or field remains |

## New Issues Introduced

**None.** No new correctness, security, or a11y regressions found. The client-side merge for `approved+published` is O(n+m) with a `Set<int>` dedupe — no unbounded queries, no N+1. Error paths on both `_loadHouses` and `_toggleTrusted` log via `debugPrint` and preserve UI state.

## Analyzer / Tests

- `flutter analyze` on all 6 remediated files: **0 errors** (23 pre-existing infos/warnings — deprecated `withOpacity`, `avoid_print` in provider, etc. All pre-date this remediation.)
- Backend `TestPutStatusIgnored`: 2/2 pass locally.
- Remediation report claim of 21/21 backend and 26/26 Flutter targeted tests is consistent with what I ran.

## Prior Findings — Closure Status

- **H1** — CLOSED (server allowlist tightened + regression tests + client belt-and-suspenders).
- **M1** — CLOSED as documented interim dual flow. Follow-up ticket noted for post-migration cleanup.
- **M2** — CLOSED via client-side merge in both surfaces. Server-side alias remains an optional simplification (Q2 in remediation report), non-blocking.
- **M3** — CLOSED.
- **M4** — CLOSED. Revert semantics are now cleaner than the original review suggested (whole-object restore beats field-level copyWith).
- **M5** — CLOSED. Deferred ward-name display is captured as a follow-up.
- **M6** — CLOSED.
- **M7** — CLOSED. Server timestamp is now authoritative on success; client `DateTime.now()` used only for provisional optimistic display and always replaced/reverted.

## Feature-Flag Safety

No regressions. `kListingV2Enabled` behavior unchanged by remediation. Q5 (staging flag-flip smoke test) remains open from prior review — not a code issue.

## Residual Notes (non-blocking)

- `admin_home_screen.dart` retains the legacy moderation code path (`_setStatus('approved', ...)` on lines 397/412 → `setHouseStatus` → backend `moderate` with `approve`). This is intentional per the documented interim dual-flow decision. Once the `approved → published` data migration ships and pending count reads 0 for the two-week grace window, both the `_setStatus('approved', ...)` calls and the `HouseProvider.fetchHousesByStatus` merge branch should be removed. Recommend tracking as a follow-up ticket now while context is fresh.
- L1–L7 (prior low-severity items) intentionally deferred — not re-reviewed.

## Unresolved Questions

1. Should the `approved → published` server-side alias be added to `admin_houses.py` GET (parity with public GET in `houses.py:54-56`)? Currently mitigated by client-side merge in two spots. Server alias would collapse both.
2. Is the `LISTING_V2_ENABLED=false` rollback path smoke-tested on staging? Carried over from prior review; not a code change.

**Final verdict:** **APPROVED**. All 8 prior findings (H1 + M1–M7) are closed with evidence. No new critical/high/medium issues introduced. Safe to proceed to Phase 5 finalization.
