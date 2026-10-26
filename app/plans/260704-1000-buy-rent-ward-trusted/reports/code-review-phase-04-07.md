# Code Review — Phase 04-07 (Guest Home Tabs · Post Transaction Picker · Admin Trusted-Mark · Trusted Badge)

**Date:** 2026-07-04
**Reviewer:** code-reviewer (Staff Engineer, production-readiness)
**Scope:** Flutter UI/UX changes ONLY. Files listed in review request.
**Verdict:** **CONDITIONAL** — 1 HIGH must be fixed before merge; several MEDIUM to fix soon.

---

## Scope

Files reviewed:
- `lib/features/guest/home/guest_home_screen.dart` (added `_TransactionTypeSelector` + `DsTrustedBadge` on card image)
- `lib/features/host/post/post_house_screen.dart` (`_transactionType` state + picker gated by `kListingV2Enabled` + status override change)
- `lib/core/config/feature_flags.dart` (added `listingV2Enabled` + `kListingV2Enabled` alias)
- `lib/features/admin/admin_trusted_mark_screen.dart` (new — PATCH `/api/admin/houses/{id}/trusted` + optimistic UI)
- `lib/features/admin/admin_home_screen.dart` (added `_trustedMarkTile()` → nav to new screen)
- `lib/core/widgets/ds_trusted_badge.dart` (new widget)
- `lib/features/guest/house_detail/house_detail_screen.dart` (badge overlay on hero image)
- `lib/features/host/profile/my_listings_screen.dart` (badge overlay on card)

Cross-checked (read-only for context):
- `lib/data/models/house_model.dart` (fields, defaults)
- `lib/providers/house_provider.dart` (`setTransactionType`, filter forwarding)
- `lib/data/repositories/api_house_repository.dart` (`getAdminHouses`)
- `lib/data/services/api_client.dart` (`patch()` method)
- `lib/core/router/app_router.dart` + `lib/core/router/route_guards.dart` (admin guard)
- `ancu365-backend/app/routers/houses.py` (PUT handler — D3 status concern)
- `ancu365-backend/app/routers/admin_houses.py` (PATCH trusted + admin GET)

Focus areas as requested: correctness, feature-flag safety, VN microcopy (1999 orthography), a11y, error handling, security/IDOR, no regressions, D3 status concern.

---

## Overall Assessment

The UI implementation is solid: clean widget structure, thoughtful use of `RepaintBoundary` / `Consumer` scoping, Semantics on interactive controls, optimistic UI with revert on the trusted toggle. Feature flag `kListingV2Enabled` is well-plumbed. Vietnamese microcopy is 95% correct.

However, one HIGH-severity issue slipped in around the post-edit status behavior (D3), and admin_home_screen still ships the legacy `pending / approved / rejected` moderation UI alongside the new trusted tile — creating a confusing dual admin flow and a stale-badge counter that will always read zero once auto-publish is live.

---

## Critical Issues

**None.** No security or data-loss issues found in the client. Backend PATCH endpoint is properly guarded by `require_admin`; router-level `/admin` prefix guard protects `AdminTrustedMarkScreen` (navigated from `AdminHomeScreen` inside the `/admin` shell).

---

## High Priority

### H1 · Edit flow can re-publish a `rejected` listing (D3 concern confirmed)

**File:** `lib/features/host/post/post_house_screen.dart:355` — `status: editing?.status ?? 'published'`
**Backend:** `ancu365-backend/app/routers/houses.py:320-343`

The review brief flagged this and asked to verify the backend PUT handler ignores client status. **It does NOT.**

```python
# ancu365-backend/app/routers/houses.py:334
for key in [
    "title", "description", "address", "city", "district",
    "status",                                # <-- client-supplied status is applied
]:
    if key in body and body[key] is not None:
        setattr(h, key, body[key])
```

The PUT handler runs `require_host`, checks ownership, then blindly applies whatever `status` the client sends. Combined with the client change (`editing?.status ?? 'published'`), the current flow means:

- **Benign case:** Host edits a `published` listing → sends `status: 'published'` → backend applies same value. No change.
- **Benign case:** Host edits a `rejected` listing via the form → sends `status: 'rejected'` (from `editing.status`) → status preserved. OK.
- **DANGEROUS case:** A host can craft a raw PUT request (or intentionally edit `HouseModel.status` in a fork of the code) with `status: 'published'` on a `rejected` listing they own → backend re-publishes it, bypassing admin moderation.

Even without malicious intent, this defeats the "rejected listings stay rejected" invariant that admin moderation relies on. And it will bite the moment `admin_home_screen.dart` "Gỡ tin" (which sets rejected) is used — host can undo it silently.

**Fix (server-side, preferred):**
```python
# In update_house — remove "status" from the auto-applied keys list.
# If clients need to signal "re-submit for review", accept it as a distinct action
# and only allow certain transitions (rejected → pending), never anything → published.
for key in [
    "title", "description", "address", "city", "district",
    # "status",  # REMOVED — status transitions must go through moderate_house
]:
    ...
```

**Fix (client belt-and-suspenders):**
```dart
// lib/features/host/post/post_house_screen.dart:353-355
// Don't send status at all on edit — backend must own the field.
// (Requires HouseModel.toMap to skip the field or a dedicated updateHouse payload.)
```

Either fix alone would close the hole; both is best. This is **HIGH** because the client-side change actively broadens an existing gap the backend already had.

---

## Medium Priority

### M1 · `admin_home_screen.dart` still ships legacy `pending / approved / rejected` moderation tabs

**File:** `lib/features/admin/admin_home_screen.dart:26-27, 47-55, 71-72, 91-107, 118-121, 367-416`

Plan Phase 06 spec: *"admin_home_screen.dart — thay tab 'Duyệt tin' bằng 'Đánh dấu uy tín'"* (replace, not add).

Current code: kept ALL three moderation tabs (`Chờ duyệt`, `Đã duyệt`, `Đã từ chối`) and only *added* a new tile `_trustedMarkTile()` above them. Consequences:

- With D3 auto-publish live, `pending` count will always be **0** for new listings → the pending badge on line 97-100 becomes dead UI.
- Admins get a confusing dual flow: "should I duyệt this listing, or đánh dấu uy tín?"
- `getAdminHouses('published')` in `AdminTrustedMarkScreen` and `getAdminHouses('approved')` in `AdminHomeScreen` may return disjoint sets during migration, making it hard for admin to know which screen shows what.

**Recommendation:** either (a) actually replace the tabs per plan (nuke the moderation UI, keep only trusted-mark), or (b) explicitly document in the plan/report that the moderation flow is preserved during the D3 rollout window (with a follow-up ticket to remove it after `approved → published` migration lands). Also update `_statuses`/`_statusLabels` to include `published` as a first-class tab if you keep both.

### M2 · Admin trusted screen fetches only `status='published'` — misses legacy `approved`

**File:** `lib/features/admin/admin_trusted_mark_screen.dart:41`

```dart
final houses = await _repo.getAdminHouses('published');
```

And the backend admin GET does an **exact** match (`admin_houses.py:35`: `models.House.status == status`), NOT the aliasing that `houses.py:54` does for the public GET.

Result: any legacy listing whose status is still `'approved'` (pre-migration) is invisible in the trusted-mark screen. Admin can't mark them trusted until migration runs. If migration hasn't run in staging/prod, the screen will look empty even though there are eligible listings.

**Fix options:**
1. Fetch both statuses client-side: `Future.wait([getAdminHouses('published'), getAdminHouses('approved')])`, merge, dedupe by id.
2. Have `admin_list_houses` accept `status='published'` as an alias for both `published` and `approved` during the migration window.
3. Ensure migration runs before this UI ships and document it.

### M3 · `HouseModel.status` default is still `'pending'` (contradicts D3)

**File:** `lib/data/models/house_model.dart:72`

```dart
this.status = 'pending',
```

D3 says the new default is `'published'`. Every existing call-site now passes `status` explicitly, so no runtime bug — but the default is a footgun for any future call-site. Ship a lint-safe fix now.

**Fix:** `this.status = 'published',` — matches backend default in `houses.py:263`.

### M4 · `admin_trusted_mark_screen.dart` — `_buildUpdated` copies `trustedAt` on toggle-off but callsite passes `isTrusted: house.isTrusted` for revert (correct) — however trustedAt is not preserved on revert

**File:** `lib/features/admin/admin_trusted_mark_screen.dart:83-92`

```dart
} catch (_) {
  if (mounted) {
    setState(() {
      _houses[index] = _buildUpdated(house, isTrusted: house.isTrusted);
      //                                     ^^^^^^^ closure captured before optimistic write
    });
```

The `house` variable was captured at the top of `_toggleTrusted` (line 59) BEFORE the optimistic write. So `house.isTrusted` still reflects the pre-toggle value → revert restores the correct boolean. Good.

But `_buildUpdated` derives `trustedAt` from the new `isTrusted` param (`isTrusted ? DateTime.now() : null`) rather than preserving the original `house.trustedAt`. So even on revert-to-true, the trustedAt jumps to "now" instead of the original historical timestamp shown by the server. Admin doesn't see this timestamp in the UI, so it's cosmetic today — but the model now lies about when the flag was set.

**Fix:** on revert, use `_buildUpdated(house, isTrusted: house.isTrusted).copyWith(trustedAt: house.trustedAt)` — or add a parameter `trustedAt: house.trustedAt` to `_buildUpdated`.

### M5 · `_TrustedMarkRow.locationText` shows raw `wardSlug` if present

**File:** `lib/features/admin/admin_trusted_mark_screen.dart:204-206`

```dart
final locationText = house.wardSlug != null
    ? '${house.wardSlug} · ${house.district}'
    : house.district;
```

`wardSlug` is a machine slug like `"phuong-ba-dinh-ha-noi"`, not a display name. Admin will see raw slugs.

**Fix:** either drop wardSlug from the row (district+city is enough) until the ward display name is joined server-side, or map slug→name via `LocationInputService` before rendering.

### M6 · Vietnamese microcopy — "Huỷ" in admin_home_screen (1999 orthography)

**File:** `lib/features/admin/admin_home_screen.dart:440`

```dart
child: const Text('Huỷ'),
```

Reviewer brief: 1999 orthography ("hủy" not "huỷ"). Should be `'Hủy'`. Note: this file was not in scope of the phase-04-07 edit but was touched (added `_trustedMarkTile`). Fix while you're here.

### M7 · `AdminTrustedMarkScreen` uses raw `ApiClient()` instead of repository → PATCH not covered by repo tests, no audit tracing

**File:** `lib/features/admin/admin_trusted_mark_screen.dart:20, 73-76`

```dart
final _apiClient = const ApiClient();
...
await _apiClient.patch('/api/admin/houses/$id/trusted', body: {'is_trusted': newValue});
```

Every other admin action in this codebase goes through `ApiHouseRepository` (`moderateHouse`, `getAdminHouses`). Bypassing the repo means: (a) no interface to mock in widget tests; (b) inconsistent error handling — repo methods throw `ApiException` and callers can `catch (ApiException)`, here you catch bare `_`; (c) telemetry / retry policies added at repo level get skipped.

**Fix:** add `Future<HouseModel> setTrusted(int id, bool value)` to `ApiHouseRepository`; call that from the screen.

---

## Low Priority

### L1 · `_TransactionTypeSelector` semantic label is stale under screen-reader re-focus

**File:** `lib/features/guest/home/guest_home_screen.dart:885-886`

The `Semantics(label: value == 'rent' ? 'Bộ lọc: Cho thuê' : 'Bộ lọc: Mua bán')` is set on the outer container. The two child segments have no individual semantics, so TalkBack reads the whole cluster as one label. Fine for now; consider giving each segment its own `Semantics(button: true, selected: ...)` for finer-grained screen-reader UX.

### L2 · `_TransactionTypeSelector` `_options` uses `null as IconData?` — verbose

**File:** `lib/features/guest/home/guest_home_screen.dart:879-881`

```dart
static const _options = [
  (value: 'rent', label: 'Cho thuê', icon: null as IconData?),
```

Works but readability nit — extract a proper typedef record or drop `icon` altogether since it's never used. Minor style.

### L3 · `_transactionDefaultSet` guard forces a redundant `fetchHouses` on every fresh mount

**File:** `lib/features/guest/home/guest_home_screen.dart:49-53`

`setTransactionType('rent')` calls `notifyListeners()` + `fetchHouses()` even when the current value is already `'rent'`. On re-entry from house detail this triggers an extra network round-trip.

**Fix:** short-circuit inside `setTransactionType` if `value == _transactionType`. Or gate the call: `if (provider.transactionType != 'rent') provider.setTransactionType('rent');`.

### L4 · `DsTrustedBadge` uses hardcoded amber `0xFFB45309` outside the HD design tokens

**File:** `lib/core/widgets/ds_trusted_badge.dart:24`

The rest of the codebase pulls colors from `HD.*`. Consider adding `HD.trusted` / `HD.gold` and referencing that so future re-theming doesn't miss this badge. Purely cosmetic.

### L5 · `AdminTrustedMarkScreen._loadHouses` swallows the exception message

**File:** `lib/features/admin/admin_trusted_mark_screen.dart:48-55`

```dart
} catch (e) {
  ...
  _errorMessage = 'Không tải được danh sách';
```

The `e` is discarded — no logger call. When this fails in prod there's no signal to trace. Add `debugPrint('AdminTrustedMarkScreen load error: $e')` at minimum, or wire through the app's real logger.

### L6 · `PostHouseScreen._transactionType` state has no user feedback when `kListingV2Enabled=false`

**File:** `lib/features/host/post/post_house_screen.dart:438-441, 362`

When the flag is off, the picker is hidden but `_transactionType` still initializes to `'rent'` (line 85) and is still sent to the backend (line 362). If backend has the migration but flag is off client-side, host effectively cannot post `sale` listings — silently locked to rent. This is intentional per the flag semantics but worth a comment: "flag=false → always 'rent'; backend defaults to 'rent' when field absent". No fix needed, just documentation.

### L7 · `_buildUpdated` — long positional/named copy is duplicated logic (already exists in HouseModel?)

**File:** `lib/features/admin/admin_trusted_mark_screen.dart:96-132`

If `HouseModel` had `copyWith`, this 30-line manual copy would be one line. Consider adding `HouseModel.copyWith` and refactoring. Not blocking.

---

## Edge Cases Found by Scout

- **Rejected listing re-published on edit** — see H1 above. Actionable.
- **Legacy `approved` listings invisible in trusted screen** — see M2 above.
- **`_transactionType` state resets on every screen re-entry** — semi-intentional per D6 default, but if user was on sale tab and drills into details then back, they lose their selection. Acceptable per plan, but should be documented for QA test plan.
- **Optimistic toggle + rapid taps** — `_pending.contains(id)` guard on line 62 correctly blocks double-taps. Good.
- **Backend PATCH returns `{is_trusted, trusted_at, trusted_by_admin_id}` subset** — client currently discards the response body and reconstructs `trustedAt: DateTime.now()`. Server clock could differ; if audit relies on this timestamp, the client display will drift. Minor.
- **Feature flag off + edit existing sale listing** — `_transactionType` initializes from `editing.transactionType` (line 122) but there's no UI to change it because the picker is hidden. Host can't switch back to rent even if they want. Acceptable during rollout, worth noting for QA.

---

## Positive Observations

- **`RepaintBoundary` wrap on `_buildPropertyCard`** (line 525) is exactly right — insulates cards from wishlist / loading-more repaints.
- **`Consumer<HouseProvider>` scoping in guest_home body** (line 223) prevents AppBar rebuilds on list updates. Careful thinking.
- **Optimistic UI with proper revert on failure + in-flight guard** in `AdminTrustedMarkScreen._toggleTrusted`. Textbook pattern.
- **Semantics labels present** on trusted badge (`'Tin uy tín'`), transaction segments (`'Bộ lọc: ...'`, `'Loại tin: ...'`), and admin switch (`'Đánh dấu uy tín: <title>'`). Good a11y discipline.
- **`_ownerUserId` capture + auth-change detection** in `PostHouseScreen.build` (line 417-423) — solid defense against session-swap during a long form. Not new in this diff but worth acknowledging.
- **Trusted badge palette + position** (top-left, image overlay, white border + shadow) matches D7 spec and stays clear of wishlist button (top-right) — verified in code.
- **`kListingV2Enabled` gate** cleanly wraps only the picker, not the field state, so backend gets `transactionType` regardless — allows dark-launch of data collection without UI exposure.
- **Feature flag docstring** (`feature_flags.dart:37-46`) explains the toggle mechanism precisely. Good doc discipline.

---

## Recommended Actions (Prioritized)

1. **[HIGH]** Fix H1: server-side — remove `status` from PUT-accepted keys in `houses.py:334-343`; add a dedicated `resubmit` action if hosts need to re-enter moderation. Client-side — stop sending `status` on edit at all.
2. **[MEDIUM]** M1: decide on the admin flow — either fully retire the `pending/approved/rejected` tabs per plan, or explicitly document the interim dual flow with a follow-up ticket.
3. **[MEDIUM]** M2: fetch both `published` and `approved` in trusted screen during the migration window (or backend alias).
4. **[MEDIUM]** M3: change `HouseModel.status` default to `'published'`.
5. **[MEDIUM]** M4: preserve `trustedAt` on revert instead of setting `DateTime.now()`.
6. **[MEDIUM]** M5: fix `_TrustedMarkRow.locationText` — don't display raw ward slug.
7. **[MEDIUM]** M6: fix "Huỷ" → "Hủy".
8. **[MEDIUM]** M7: route trusted PATCH through `ApiHouseRepository`.
9. **[LOW]** L1-L7: nice-to-haves; batch into a cleanup PR.

---

## Feature-Flag Safety

- `kListingV2Enabled = true` (default) → picker visible, `_transactionType` sent → verified path.
- `kListingV2Enabled = false` → picker hidden, `_transactionType` still initialized to `'rent'` and still sent → backend defaults to `'rent'` anyway, so equivalent. No crash.
- Guest home tab is NOT gated by the flag — it always shows. If backend hasn't migrated (`transaction_type` column missing), the GET query with `transactionType='rent'` would 500. But per plan phase 01-03 the backend migration has landed, so this is fine. If you want extra safety, add `if (kListingV2Enabled)` around the `_TransactionTypeSelector` in guest_home too.

---

## Security / IDOR

- **`/admin` shell**: `guardAdminRoutes` in `route_guards.dart:31-39` redirects non-admins to `/`. `AdminTrustedMarkScreen` is `Navigator.push`ed from inside `/admin`, so it inherits the guard. OK.
- **PATCH `/api/admin/houses/{id}/trusted`**: backend uses `Depends(auth.require_admin)` — server-side authz enforced. Client-side guard is UX-only, correctly.
- **PATCH body validation**: server checks `if "is_trusted" not in body: raise 422` — good input validation. Client always sends `bool`, no crafting risk.
- **No PII leaks** in the diff — badge / picker / row display title, price, location. All already-public.

---

## Metrics (from static reading)

- Files touched: 8
- Net new LOC: ~450
- New public widgets: 2 (`DsTrustedBadge`, `_TransactionTypeSelector`)
- New screens: 1 (`AdminTrustedMarkScreen`)
- Semantics labels added: 4 (badge, 2 transaction pickers on both surfaces, admin switch)
- Feature flags: 1 new (`listingV2Enabled`)
- No new dependencies

---

## Unresolved Questions

1. **Q1 — H1 fix ownership**: is the client team OR backend team on the hook for the H1 status-override fix? Recommend both, but the backend fix is the actual safety net. Please assign.
2. **Q2 — M1 decision**: keep the legacy moderation tabs during D3 rollout, or nuke them now? Depends on whether legacy `pending` listings still exist in prod after migration. Product call.
3. **Q3 — M4 trustedAt display**: does any surface show `trustedAt` to the user? If not, M4 is purely a data-integrity concern and can be deferred. Please confirm.
4. **Q4 — Test coverage**: no widget or integration tests for `_TransactionTypeSelector` or `AdminTrustedMarkScreen` in the diff. Plan Phase 11 covers tests separately, but confirm those cover these files before Release 1 ships.
5. **Q5 — feature flag rollback drill**: has the flip-to-false path been smoke-tested on staging? The picker code path is safe, but I did not verify with a live build.

---

**Final verdict:** **CONDITIONAL** — fix H1 (status re-publish) before merge. M1-M7 should be scheduled before Release 1 rollout but do not block merge. Nice work on optimistic UI, a11y, and Consumer scoping.
