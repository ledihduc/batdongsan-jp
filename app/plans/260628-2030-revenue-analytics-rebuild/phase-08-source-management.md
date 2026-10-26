---
title: "Phase 08 — Source Management CRUD Screen"
status: pending
priority: P0
estimated_effort: 2-3d
blocked_by: [phase-04]
owner: TBD
---

## Context Links
- BA: US-08 (filter by source), AC-07 (CRUD validation), AC-17 (concurrent archive), Q2 (custom source)

## Overview
- Priority: P0
- Status: pending
- Brief: Source management screen — list / add / edit (rename, color) / archive / hard-delete (only count=0). Entry from analytics settings or via filter "Manage sources".

## Key Insights (from research)
- Phase 01 already provides `revenue_sources` schema + 3 defaults seeded.
- Phase 03 exposes 4 CRUD endpoints.
- Phase 04 already wired `ReportProvider.createSource/updateSource/archiveSource/deleteSource`.

## Requirements
### Functional
- List screen: active sources first, then archived (collapsed section).
- Each row: color swatch + name + linked count + action menu (edit, archive, delete).
- Add dialog: name (required, unique per host), color hex picker (10 preset swatches).
- Edit dialog: same as Add + delete option.
- Archive: confirm dialog "Vẫn giữ data lịch sử, ẩn khỏi dropdown mới"; backend toggles `is_archived=true`.
- Hard-delete: only enabled if `linked_count == 0`; confirm dialog warning; if linked, show 409 message "Đang dùng ở X reservation — chỉ có thể archive".
- Validation: name `length 1-50`, unique (partial unique `WHERE is_archived=false` enforced backend; client validates active).

### Non-functional
- Inline error display per AC-13.
- Optimistic UI update; revert on backend error.

## Architecture / Design
- StatefulWidget for list filtering.
- Color picker: simple 10-swatch grid (no third-party).
- Confirm dialogs via `showDialog`.

### Key decisions
- **Preset palette:** 10 hex swatches from `ColorPalette` (Phase 06).
- **Linked count badge:** small chip "X reservation, Y contract".
- **Archive vs Delete UX:** Archive is primary action; Delete buried under menu w/ disabled-tooltip when linked.

## Files
### Modify
- `lib/core/router/app_router.dart` — add deferred route `/host/analytics/sources`
- `lib/features/host/analytics/widgets/filter_bottom_sheet.dart` — "Manage sources" link (Phase 07 already created; add CTA here)

### Create
- `lib/features/host/analytics/screens/source_management_screen.dart`
- `lib/features/host/analytics/widgets/source_list_tile.dart`
- `lib/features/host/analytics/widgets/source_edit_dialog.dart`
- `lib/features/host/analytics/widgets/color_swatch_picker.dart`
- `lib/features/host/analytics/widgets/archive_confirm_dialog.dart`
- `lib/features/host/analytics/widgets/delete_confirm_dialog.dart`
- `test/widgets/source_management_screen_test.dart`
- `test/widgets/source_edit_dialog_test.dart`

### Delete
- none

## Implementation Steps
1. Add route + deferred import.
2. Build `SourceManagementScreen` w/ Consumer<ReportProvider> + ListView.
3. Build `SourceListTile` w/ swatch + name + linked count + popup menu (edit/archive/delete).
4. Build `SourceEditDialog` (used for both Add + Edit) w/ name input + color picker.
5. Build `ColorSwatchPicker` — 10 preset colors as tap targets.
6. Build confirm dialogs for archive + delete; show 409 message on delete-blocked.
7. Add CTA in `FilterBottomSheet` linking to source mgmt screen.
8. Implement optimistic UI: update local list immediately, revert on backend error.

## Todo List
- [x] Route added
- [x] `SourceManagementScreen` w/ provider Consumer
- [x] `SourceListTile` + popup menu
- [x] `SourceEditDialog` + `ColorSwatchPicker`
- [x] Archive + Delete confirm dialogs
- [x] CTA in `FilterBottomSheet`
- [x] Optimistic UI + revert on error
- [x] Widget tests pass (27/27)

## Test Strategy
### Unit
- `SourceEditDialog` validates name length + non-empty.
- Delete button disabled if linked_count > 0.

### Integration
- Add source → list refreshes.
- Archive → moves to archived section.
- Delete w/ linked → 409 message shown; source remains in active list.
- Delete w/ count=0 → row removed.

### E2E
- Phase 11.

## Success Criteria
- All CRUD operations functional.
- Validation per AC-07 enforced (archive vs hard-delete).
- `flutter analyze` clean.

## Risk Assessment
- **Race condition: two devices archive same source** → backend last-write-wins; client refresh shows truth.
- **Color picker UX** → 10 preset swatches simpler than full color picker; future enhancement if needed.

## Security Considerations
- All CRUD endpoints already auth-gated + IDOR-tested in Phase 03.
- No PII.

## Acceptance Criteria Coverage
- AC-07 (full CRUD validation incl. archive vs delete, partial unique constraint, hard-delete count=0) ✓
- AC-17 (archived source still in historical reports — backend handles, this screen just reflects) ✓
- Q2 (custom source) ✓

## Definition of Done
- Screen functional + tests pass.
- Code reviewed.
- Entry from filter sheet works.
