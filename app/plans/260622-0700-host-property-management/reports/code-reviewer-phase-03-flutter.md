# Code Review — Phase 03 Flutter (Nhà trọ Core)

**Reviewer:** code-reviewer (Staff Engineer)
**Date:** 2026-06-22
**Scope:** Flutter only (backend reviewed at commit 3c419d6)
**Plan:** `plans/260622-0700-host-property-management/phase-03-nha-tro-core.md`

---

## Scope

- Files: 4 models, 4 repos, 3 providers, 8 screens, 4 widgets, 2 wiring (main.dart + host_home_screen.dart)
- LOC: ~1,800 net new
- Focus: provider lifecycle, state machine UX, form validation, async safety, AC coverage

## Overall Assessment

Solid skeleton: models/repos/providers mirror backend schema correctly and use a clean ApiClient with proper Bearer JWT handling. State machine UI (badges, color-coded grids) is functional. Vietnamese copy is consistent. However the implementation has **several CRITICAL and HIGH issues that must be fixed before merge** — most notably a broken dashboard counter, missing AC C2/C6 photo uploads, raw integer room-ID entry for transfer, missing destructive-action confirmation dialogs, multiple provider memory leaks, and a tenant-row state corruption bug when removing roommates.

---

## CRITICAL Issues (block merge)

### C1. Dashboard "Đang sửa" widget shows wrong number — fails AC10
**File:** `lib/features/host/host_home_screen.dart:137-142`
```dart
Expanded(
  child: _nhaTroDashCard(
    icon: Icons.build_outlined,
    label: 'Đang sửa',
    value: '${buildingProvider.buildings.length}',  // ← BUG: this is BUILDING count, not maintenance room count
    color: const Color(0xFFFFA000),
  ),
),
```
**Impact:** Dashboard misreports "X phòng đang sửa". A host with 3 buildings and 0 maintenance rooms will see "3 Đang sửa". Directly violates AC10 in the plan.
**Fix:** Either (a) extend backend with `GET /api/host/dashboard/stats` returning `maintenance_room_count`; or (b) eagerly fetch rooms for all buildings on host_home init and aggregate `room.isMaintenance` count. Option (a) preferred — Phase 04 will need a stats endpoint anyway.

### C2. AC C2 not implemented — no CCCD / handover photo upload in contract form
**File:** `lib/features/host/property/screens/contract_form_screen.dart` (entire file)
**Plan AC C2:** "Upload ảnh CCCD + ảnh phòng bàn giao → AC: multi-image upload, paths saved on Contract"
**Impact:** Acceptance criterion C2 missing. Backend `POST /api/host/contracts` already accepts `handover_photos`; repository (`api_contract_repository.dart:42,52`) already exposes the field, but the form never collects them. Tenant rows also lack `cccd_front_path` / `cccd_back_path`.
**Fix:** Add multi-image picker (use existing `ApiClient.uploadImage`) for handover photos and per-tenant CCCD pair. Pass uploaded URLs through `createContract(handoverPhotos: ...)` and into tenant payload.

### C3. AC C6 not implemented — no damage photo upload on terminate
**File:** `lib/features/host/property/screens/contract_terminate_screen.dart` (entire file)
**Plan AC C6 (MUST):** "Upload ảnh phòng lúc trả + note hư hại → AC: terminate request includes `damage_photos`, `damage_note`"
**Impact:** Screen captures `damage_note` only; `damage_photos` is never collected. Repository (`api_contract_repository.dart:70-79`) supports it but call site hardcodes default `[]`.
**Fix:** Add multi-image picker before the submit button. Wire `damagePhotos: <uploaded urls>` into `terminateContract` call.

### C4. Tenant rows lose data when a middle row is removed (state-corruption bug)
**File:** `lib/features/host/property/screens/contract_form_screen.dart:202-214` (combined with `widgets/tenant_input_row.dart`)
```dart
...List.generate(
  _tenantData.length,
  (i) => TenantInputRow(
    key: ValueKey(i),          // ← BUG: keyed by position, not identity
    ...
  ),
),
```
**Impact:** With 3 tenants `[A, B, C]` and `_tenantData.removeAt(1)`, the list becomes `[A, C]` but the `_TenantInputRowState` whose key was `ValueKey(1)` (held tenant B's controllers) is reused for index 1 (now intended for C). Result: row 1 still shows B's text fields and B's `_isPrimary`; only the model entry shifted. Saving will submit stale data and possibly send 2 primaries (state vs model out of sync).
**Fix:** Either:
- Keep a parallel `List<String> tenantUUIDs` and use `ValueKey(uuid)` (stable identity), or
- Lift `TextEditingController` and `isPrimary` to the parent so the State has no per-tenant local state, or
- Convert `TenantInputRow` to `StatelessWidget` driven entirely by data passed in (preferred — simplest fix).

### C5. `TenantInputRow.initState` notifies parent during build phase
**File:** `lib/features/host/property/widgets/tenant_input_row.dart:31-35`
```dart
@override
void initState() {
  super.initState();
  _isPrimary = widget.index == 0;
  _notify();  // ← calls widget.onChanged → parent setState during build
}
```
**Impact:** When the parent `_tenantData.add({...})` triggers a rebuild, the new `TenantInputRow.initState` calls `_notify()` → parent `setState(() => _tenantData[i] = data)` → "setState() or markNeedsBuild() called during build" assertion in debug; in release it can drop the update silently and the new row's data won't be reflected.
**Fix:** Defer `_notify()` via `WidgetsBinding.instance.addPostFrameCallback((_) => _notify());` in `initState`. Or remove the call entirely and rely on the parent's pre-seeded `_tenantData` entry as the source of truth.

### C6. Transfer-room screen is unusable — raw integer ID input
**File:** `lib/features/host/property/screens/contract_transfer_room_screen.dart:20-22, 71-79`
```dart
// Note: In a full implementation this would fetch buildings/rooms using RoomProvider.
// For MVP, host enters room ID directly as an integer field.
final _roomIdCtrl = TextEditingController();
```
**Impact:** Hosts cannot know room database IDs. Feature is functionally broken — AC C7 ("Transfer tenant qua phòng khác") is not testable by an actual user. Even worse, host could type an ID owned by another host; backend host_id filter will 404/403, but UX is unacceptable.
**Fix:** Replace the text field with a 2-step picker:
1. Building dropdown sourced from `BuildingProvider.buildings`.
2. Room dropdown filtered to `status == 'vacant'` rooms in that building (fetch via `RoomProvider.fetchRooms`).
   Submit the picked `room.id`.

---

## HIGH Issues (should fix before merge)

### H1. No confirmation dialog before destructive contract terminate
**File:** `lib/features/host/property/screens/contract_detail_screen.dart:96-114` and `contract_terminate_screen.dart:45-77`
**Impact:** Single tap "Trả phòng" → screen → submit → contract soft-deleted, room flipped to vacant. No "Bạn có chắc chắn..." confirmation. Required by Phase 03 review checklist item #6 (confirmation before destructive actions).
**Fix:** Wrap `_submit()` in `contract_terminate_screen.dart` with `showDialog` AlertDialog → "Bạn có chắc muốn kết thúc hợp đồng này? Thao tác không thể hoàn tác." Same pattern as `_confirmDelete` in `host_home_screen.dart:463-492`.

### H2. No confirmation dialog before activating contract (state mutation, room → occupied)
**File:** `lib/features/host/property/screens/contract_detail_screen.dart:78-94`
**Impact:** "Kích hoạt hợp đồng" tap immediately flips room to occupied — not reversible without terminating. Should confirm.
**Fix:** Add confirmation dialog before calling `provider.activateContract`.

### H3. No confirmation before setting room maintenance
**File:** `lib/features/host/property/screens/room_detail_screen.dart:41-82`
**Impact:** The "Đặt bảo trì" picker doubles as confirmation (user picks dates and taps "Xác nhận"), so this is acceptable. **However**, "Kết thúc bảo trì" at line 116-126 has zero confirmation — one tap clears the maintenance window. Mark MEDIUM if you disagree, but the plan checklist item explicitly names "maintenance" as a destructive-style action.
**Fix:** Wrap the `end_maintenance` branch in a confirmation dialog.

### H4. Confirm before transfer-room mutation
**File:** `lib/features/host/property/screens/contract_transfer_room_screen.dart:30-55`
**Impact:** Transfer mutates 2 rooms (old → vacant, new → occupied) and contract.room_id. No confirmation. (Mostly absorbed by C6 fix, but call out separately so the picker-based fix includes a "Bạn có chắc muốn chuyển hợp đồng sang phòng X?" step.)

### H5. Provider memory leak — `RoomProvider` and `ContractProvider` instantiated in State but never disposed
**File:** `lib/features/host/property/screens/building_detail_screen.dart:24-33`
```dart
late final RoomProvider _roomProvider;

@override
void initState() {
  super.initState();
  _roomProvider = RoomProvider();  // ← never disposed
  ...
}
// no dispose() override
```
Same pattern: `room_detail_screen.dart:22-31` (`_contractProvider = ContractProvider();` no dispose).
**Impact:** Each navigation in/out leaks a `ChangeNotifier` + its listeners list. Long sessions accumulate memory; also any in-flight HTTP response that completes after the screen is gone will call `notifyListeners()` on a disposed-but-not-flagged provider, which currently is silent but adds risk if any consumer attaches an external subscription.
**Fix:** Add `dispose()` override:
```dart
@override
void dispose() {
  _roomProvider.dispose();
  super.dispose();
}
```
Apply to both screens.

### H6. `ContractDetailScreen` cannot load a contract not already in provider state
**File:** `lib/features/host/property/screens/contract_detail_screen.dart:14-32`
```dart
ContractModel? _findContract(ContractProvider p) {
  try {
    return p.contracts.firstWhere((c) => c.id == contractId);
  } catch (_) {
    return null;
  }
}
```
**Impact:** When the dashboard expiring-contracts widget links straight to a contract detail (Phase 04 will surface this), the screen will show "Không tìm thấy hợp đồng" because `_contracts` was never populated for that route. There is no fallback to `repo.getContract(id)`.
**Fix:** Convert to `StatefulWidget`, fetch the contract in `initState` via `ContractProvider.fetchSingleContract(id)` (new method using `ApiContractRepository.getContract`), or merge into the existing provider state if missing.

### H7. `TenantInputRow.dispose` cascade in unstable list will dispose controllers used by remaining rows
**File:** `lib/features/host/property/widgets/tenant_input_row.dart:38-42`
**Impact:** Tied to C4. When the index-keyed list churns, Flutter may call `dispose()` on a State that the new index inherits. The internal `TextEditingController`s get disposed but the State object is reused — subsequent `onChanged` callbacks call methods on disposed controllers → "A TextEditingController was used after being disposed."
**Fix:** Resolves automatically when C4 is fixed (stable keys).

### H8. `contract_form_screen.dart` does not enforce `start_date < end_date` post-pick
**File:** `lib/features/host/property/screens/contract_form_screen.dart:42-69`
**Impact:** `_pickDate(true)` uses `firstDate: DateTime.now()`. If user picks `end = 2026-12-01` first, then picks `start = 2027-01-01`, the picker enforces `firstDate = start` only on the *next* end-pick. The currently-saved `_endDate` remains earlier than the new start. No explicit validation in `_submit()` catches this case. Plan rubric #4: "contract form rejects start ≥ end".
**Fix:** In `_submit()` after null check, parse both dates and assert `start.isBefore(end)`; show SnackBar if violated. Also when `_pickDate(true)` succeeds and resulting `start >= _endDate`, clear `_endDate` (same trick `MaintenanceDatePicker._pickDate` uses at line 58).

### H9. `building_list_screen.dart` `_showCreateDialog` leaks TextEditingControllers
**File:** `lib/features/host/property/screens/building_list_screen.dart:23-85`
**Impact:** Three local controllers (`nameCtrl`, `addressCtrl`, `cityCtrl`) are created on every dialog open and never disposed. Each "Tạo" tap allocates 3 more.
**Fix:** Either dispose them after `showDialog` resolves (in a `try/finally`), or convert the dialog body into a small `StatefulWidget` that owns and disposes its own controllers.

### H10. `ContractTerminateScreen` double-pop assumes specific navigation depth
**File:** `lib/features/host/property/screens/contract_terminate_screen.dart:70-71`
```dart
Navigator.pop(context, true);
Navigator.pop(context); // also pop contract detail
```
**Impact:** Two unconditional pops. If the route stack is `[home, list, detail, terminate]` this works. If a different entry path (e.g., deep-link from a notification → terminate) places only `[home, terminate]`, the second pop sends user back to the auth/root screen unexpectedly. Also no `mounted` guard between the two pops (the first pop tears down the route and any synchronous follow-up using the same BuildContext is on shaky ground).
**Fix:** Use `Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == 'building_detail')` with a named route, or pass a `onTerminated` callback that the parent uses to refresh + pop itself.

---

## MEDIUM Issues

### M1. Room status color mismatch with rubric
**File:** `lib/features/host/property/widgets/room_grid_card.dart:68-79` and `widgets/room_status_badge.dart:36-47`
**Rubric (from prompt):** "vacant=green, occupied=blue, maintenance=orange"
**Code:** vacant=green ✓, **occupied=red `0xFFB71C1C`** (mismatch), maintenance=orange ✓.
**Impact:** Either rubric or code is the source of truth. Visually red signals "danger / blocked" which is reasonable; but rubric explicitly says blue. Confirm with design before changing.
**Fix:** If rubric stands, change occupied color to a blue (`0xFF1976D2` or similar) in both the grid card and the badge.

### M2. `BuildingProvider` shared across the building-list and detail routes via `ChangeNotifierProvider.value` but `RoomProvider`/`ContractProvider` instantiated locally — inconsistent pattern
**File:** `lib/main.dart:44-46` registers all three at app root, yet `building_detail_screen.dart:29` and `room_detail_screen.dart:27` create *new* local instances that shadow the root ones.
**Impact:** Subtle behavior change — dashboard's `ContractProvider` (from root) and the room detail's `ContractProvider` (local) are different objects. If you call `fetchExpiringContracts` from `_refresh()` but the user is on `RoomDetailScreen`, the dashboard widget still updates because of the root provider; but if you ever assumed "same provider = same data" you'll be wrong.
**Fix:** Pick one pattern. Recommend: use root providers everywhere, drop the local instantiation in detail screens.

### M3. Empty-state CTAs missing on rooms grid for occupied/maintenance edge cases
**File:** `lib/features/host/property/screens/building_detail_screen.dart:75-80`
**Impact:** Empty-state shown only when zero rooms; reasonable. But when all rooms are occupied, there's no "All rooms full" indicator — minor UX gap.
**Fix:** Optional: a banner above the grid showing aggregate counts (e.g., "5 trống · 12 đang thuê · 1 sửa").

### M4. `ContractProvider.fetchExpiringContracts` silently swallows errors
**File:** `lib/features/host/property/providers/contract_provider.dart:47-55`
```dart
try {
  _expiringContracts = await _repo.fetchContracts(expiringWithin: days);
  notifyListeners();
} catch (_) {
  // Silent fail for dashboard widget
}
```
**Impact:** If the endpoint 500s or auth expires, the dashboard shows "0 Sắp hết hạn" indefinitely with no signal. At minimum log to a logger; the comment "Silent fail" is a code smell.
**Fix:** Keep the user-facing silent-fail but `debugPrint('fetchExpiringContracts failed: $e');` so it appears in dev logs.

### M5. `RoomProvider.maintenanceCount` is per-building, not global
**File:** `lib/features/host/property/providers/room_provider.dart:19-20`
**Impact:** Tied to C1. The getter returns count for the *currently loaded* building only. If used for a global dashboard it underreports.
**Fix:** Document that this is per-building; for dashboard add a separate `fetchMaintenanceCountAcrossBuildings` or use a stats endpoint.

### M6. `building_list_screen.dart` create dialog has no inline validation, only post-tap empty check
**File:** `lib/features/host/property/screens/building_list_screen.dart:65`
```dart
if (ok != true || nameCtrl.text.trim().isEmpty) return;
```
**Impact:** When user taps "Tạo" with empty name, dialog closes silently — user thinks save succeeded but nothing happens.
**Fix:** Use a `Form` + `TextFormField` with `validator` inside the dialog (same pattern as `RoomFormScreen`). Or show a SnackBar "Vui lòng nhập tên tòa nhà" when the empty check fires.

### M7. `RoomFormScreen` doesn't validate `base_price > 0`
**File:** `lib/features/host/property/screens/room_form_screen.dart:78-83`
**Impact:** Backend likely enforces positive price via Pydantic (`gt=0`), but the form accepts 0 or empty → API call fails with non-localized error. Plan §"Pydantic schemas validate all input (prices > 0)" suggests backend enforces it; UX should too.
**Fix:** Add validator: empty OR `<=0` → "Nhập giá thuê hợp lệ" (allow empty if "0" is treated as "set later" — confirm with PM).

---

## LOW Issues (style / minor)

### L1. `withOpacity` is deprecated in Flutter ≥3.27 (use `withValues(alpha:)`)
**Files:**
- `lib/features/host/property/widgets/room_grid_card.dart:23, 25`
- `lib/features/host/property/widgets/room_status_badge.dart:15`
- `lib/features/host/property/screens/contract_detail_screen.dart:61, 162`
- (and others in `host_home_screen.dart`, pre-existing)
**Impact:** Triggers analyzer info messages; precision loss in some color blending paths.
**Fix:** Replace `.withOpacity(0.15)` → `.withValues(alpha: 0.15)`.

### L2. `RoomModel.maintenanceStart` / `maintenanceEnd` typed as `String?` instead of `DateTime?`
**File:** `lib/data/models/room_model.dart:12-13`
**Impact:** Forces every consumer to string-format manually; misses `DateTime.parse` failures at the boundary.
**Fix:** Parse to `DateTime?` in `fromJson`; serialize via `toIso8601String` in `toJson`. Same applies to `ContractModel.startDate/endDate/terminatedAt/actualEndDate`.

### L3. `ContractModel.primaryTenant` getter returns first tenant when no primary exists — silent fallback
**File:** `lib/data/models/contract_model.dart:106-112`
**Impact:** Backend should guarantee exactly 1 primary. Fallback hides backend bugs.
**Fix:** Return `null` (no fallback) and let UI render "—". Or assert non-null at fetch boundary.

### L4. `contract_form_screen.dart` "is_primary" check allows zero primaries before submit but no inline feedback
**File:** `lib/features/host/property/screens/contract_form_screen.dart:81-89`
**Impact:** User adds 2 tenants, unticks the first's primary, taps submit → SnackBar appears. Better: real-time hint above the rows ("Vui lòng chọn 1 người đại diện").
**Fix:** Compute primaryCount in build, show inline `Text` warning when `!= 1`.

### L5. `TenantInputRow.dispose` doesn't unregister `onChanged` (callback could still fire)
**File:** `lib/features/host/property/widgets/tenant_input_row.dart:38-42`
**Impact:** Minor — `_notify` is only called from sync user gestures, no async timer. After C4/H7 fix, moot.

### L6. `ContractProvider._error` is set but never cleared on success
**File:** `lib/features/host/property/providers/contract_provider.dart:85-94`
**Impact:** Successful subsequent calls don't clear stale `_error`; UI may show outdated error message.
**Fix:** Set `_error = null;` at the start of every mutation method or on success.

### L7. `ApiClient.uploadImage` returns absolute URL but rooms/contracts/CCCD upload flow not yet exercised — confirm Phase 03 will exercise it once C2/C3 are wired
**File:** `lib/data/services/api_client.dart:104-114`
**Impact:** Once H1/C2/C3 add image pickers, validate end-to-end.

---

## Backend Contract Check ✅

Verified against actual backend (`ancu365-backend/app/routers/host_*.py`):

| Endpoint | Backend Method | Flutter Method | Match? |
|---|---|---|---|
| `/api/host/buildings` GET/POST/PATCH/DELETE | matches | matches | ✓ |
| `/api/host/buildings/{id}/rooms` GET/POST | matches | matches | ✓ |
| `/api/host/rooms/{id}` PATCH | matches | matches | ✓ |
| `/api/host/rooms/{id}/duplicate` POST | matches | matches | ✓ |
| `/api/host/rooms/{id}/maintenance` POST | matches | matches | ✓ |
| `/api/host/rooms/{id}/maintenance/end` POST | matches | matches | ✓ |
| `/api/host/contracts` GET/POST | matches | matches | ✓ |
| `/api/host/contracts/{id}/activate` **PATCH** | PATCH | PATCH | ✓ |
| `/api/host/contracts/{id}/terminate` **PATCH** | PATCH | PATCH | ✓ |
| `/api/host/contracts/{id}/transfer-room` **PATCH** | PATCH | PATCH | ✓ |
| `/api/host/contracts/batch-renew` POST | POST | POST | ✓ |
| `/api/host/tenants` GET/POST | matches | matches | ✓ |

Note: the prompt's "API contract" listed several endpoints as POST (e.g. activate/terminate/transfer) and `/maintenance/clear`, but the actual backend uses PATCH and `/maintenance/end` — Flutter matches the real backend, so this is correct. The prompt text was a paraphrase, not the canonical contract.

---

## Acceptance Criteria Coverage

| AC | Status | Notes |
|---|---|---|
| AC1 (B1: create building) | ✅ | `building_list_screen` create dialog + repo |
| AC2 (B4: set room maintenance with dates) | ✅ | `room_detail_screen._showMaintenanceDialog` |
| AC3 (Contract state machine) | ⚠️ Partial | UI exposes draft→active→terminated, but no expired display logic verified |
| AC4 (M:N tenants with 1 primary) | ⚠️ | Form supports it, **but C4/H7 bugs corrupt data with >2 tenants** |
| AC5 (C7 transfer room) | ❌ | Functionally broken — raw int ID input (C6) |
| AC6 (soft delete) | ✅ | Repo accepts `include_terminated` flag |
| AC7 (audit log) | n/a backend | |
| AC8 (cross-host isolation) | ✅ backend | |
| AC9 (duplicate room) | ✅ | `room_detail_screen` popup menu action |
| AC10 (dashboard counts) | ❌ | C1 — "Đang sửa" shows building count, not room count |
| AC C2 (CCCD + handover photos) | ❌ | Not implemented |
| AC C6 (damage photos on terminate) | ❌ | Not implemented |
| AC C4 (batch renew) | ⚠️ | Repo method exists, no UI surfaces it (acceptable for Phase 03 P1) |

---

## Edge Cases Found by Scout

- **Provider sharing inconsistency** (M2) — root `ContractProvider` vs route-local instances will diverge.
- **Stale BuildContext after double-pop** (H10) — fragile.
- **Tenant index reuse on removal** (C4) — state corruption with >2 tenants.
- **TextEditingControllers leaked in dialog** (H9) — slow drip leak.
- **`firstDate` constraint bypass when picking end before start** (H8) — date logic gap.

---

## Positive Observations

- `ApiClient` cleanly centralizes auth header + error decoding; repos stay thin.
- Providers consistently use `ApiException` catch + `_error` state — no thrown exceptions leak to UI.
- `BuildingProvider.buildings` returns `List.unmodifiable(_buildings)` — good immutability hygiene.
- `RoomGridCard` extracts color logic cleanly; status badge is reusable.
- `MaintenanceDatePicker` correctly clears `_end` when `_start` jumps past it (line 58) — should replicate in `contract_form_screen.dart`.
- Vietnamese copy is consistent and well-localized.
- `room_detail_screen.dart` correctly hides "Tạo hợp đồng" when room is not vacant — state-aware action gating.
- Backend contract mapping is accurate (PATCH for state mutations, POST for create/duplicate) — Flutter matches actual backend not the prompt's paraphrase.

---

## Recommended Actions (Priority Order)

1. **(CRITICAL)** Fix dashboard maintenance count — C1.
2. **(CRITICAL)** Implement CCCD + handover photo upload in contract form — C2.
3. **(CRITICAL)** Implement damage photo upload in terminate screen — C3.
4. **(CRITICAL)** Replace index-based tenant row keys with stable identity keys + fix `_notify()` in `initState` — C4, C5.
5. **(CRITICAL)** Replace raw room-ID input with building/room picker on transfer screen — C6.
6. **(HIGH)** Add confirmation dialogs to terminate, activate, end-maintenance, transfer — H1–H4.
7. **(HIGH)** Add `dispose()` for local providers in `BuildingDetailScreen` and `RoomDetailScreen` — H5.
8. **(HIGH)** Wire `ContractDetailScreen` to fetch contract by ID if not present — H6.
9. **(HIGH)** Validate `startDate < endDate` in contract form + clear stale `_endDate` when `_startDate` moves later — H8.
10. **(HIGH)** Fix building-create dialog controller disposal — H9.
11. **(HIGH)** Replace double-pop in terminate screen with safer navigation — H10.
12. **(MEDIUM)** Reconcile room color rubric (red vs blue) — M1.
13. **(MEDIUM)** Pick one provider pattern (root vs local) — M2.
14. **(LOW)** Migrate `withOpacity` → `withValues(alpha:)` — L1.
15. **(LOW)** Type maintenance/start/end as `DateTime?` not `String?` — L2.

---

## Metrics

- Files reviewed: 18 (4 models + 4 repos + 3 providers + 8 screens + 4 widgets + 2 wiring – 1 host_home subset)
- AC coverage: 7/13 fully met, 3 partial, 3 not implemented (C2, C6, C7 transfer UX, dashboard count)
- Critical issues: 6
- High issues: 10
- Medium issues: 7
- Low issues: 7
- Backend contract mismatches: 0 (Flutter matches actual backend at commit 3c419d6)

---

## Unresolved Questions

1. **Room color rubric:** Is occupied=blue (prompt rubric) or occupied=red (current implementation) authoritative? Need PM/design confirmation before changing.
2. **Stats endpoint:** Should the dashboard maintenance count come from a new `GET /api/host/dashboard/stats` endpoint or be aggregated client-side? Recommend backend addition.
3. **Activate confirmation:** Is "Activate" considered destructive (warrants dialog) or just a positive state advancement (no dialog)? I marked it HIGH but could be MEDIUM.
4. **Soft-delete UI surfacing:** No UI currently lets the user opt into `include_terminated=true`. Is that intentional for Phase 03, or should the contract list have a "Hiện hợp đồng đã kết thúc" toggle?
5. **Tenant reusability (autocomplete):** `ApiTenantRepository.fetchTenants(query:)` exists but no UI uses it. Was the autocomplete supposed to land in Phase 03 (per plan §"Reusable tenant list (autocomplete in contract form)") or deferred?

---

# Verdict: **CONDITIONAL**

Reasoning: skeleton is sound and backend wiring is correct, but **3 acceptance criteria (C2, C6, C7 transfer UX) are not implemented**, **AC10 dashboard is wrong**, and **a state-corruption bug (C4) breaks the multi-tenant flow** that is the headline feature of Phase 03 (C8 roommates). These are not nitpicks — they affect the demo flow described in success criteria (10-minute E2E: 3 rooms → duplicate → maintenance → 2-roommate contract → activate → terminate w/ refund).

To clear to APPROVED, the developer must address all CRITICAL items (C1–C6) and the destructive-action confirmations (H1–H4). Provider disposal (H5) and contract-fetch-on-demand (H6) are strongly recommended but not strict blockers. Re-review after fixes.
