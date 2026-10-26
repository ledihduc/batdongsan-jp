# Phase 07 — Modularize Files > 500 Lines

**Priority:** P2 | **Status:** pending | **Estimate:** 1.5 ngày | **Depends on:** Phase 01 (post_house move đã xong), **Phase 05a (DsAppBar retrofit trước khi split — tránh double edit AppBar khi tách file)**

## Context

5 file > 500 dòng làm audit / add role guard / debug khó. Từ researcher-02:
- `host_home_screen.dart` — 767 dòng (2 tab: Tin đăng + Nhà trọ)
- `room_detail_screen.dart` — 654 dòng
- `analytics_home_screen.dart` — 545 dòng
- `occupancy_heatmap_screen.dart` — 599 dòng
- `contract_form_screen.dart` — 502 dòng

Global convention (CLAUDE.md): < 200 dòng/file. Nới ra 300 cho screen file có justification.

**v2 note (from M4):** Phase 07 depends on Phase 05a — DsAppBar retrofit phải xong trước để tránh split file rồi Phase 05a lại phải edit từng file split ra. Order: 05a AppBar → 07 split → 05b state pattern (không đụng AppBar).

## Requirements

**Functional:**
- Không đổi behavior — pure refactor
- Public API (constructor, exported class) không đổi

**Non-functional:**
- Mỗi file mới < 300 dòng
- Naming kebab-case, descriptive
- Import path clear

## Split strategy per file

### `host_home_screen.dart` (767 → target 4 file × ~200 dòng)
- `host_home_screen.dart` — shell + tab controller (< 150 dòng)
- `host_home_tin_dang_tab.dart` — "Tin đăng" tab content
- `host_home_nha_tro_tab.dart` — "Nhà trọ" tab content
- `host_home_dialogs.dart` — confirm delete, edit, share dialogs

### `room_detail_screen.dart` (654 → 3 file)
- `room_detail_screen.dart` — layout + provider wire (< 200 dòng)
- `room_detail_editorial_widgets.dart` — `_EditorialDialog`, `_StatusStamp`, `_FactSheet`
- `room_detail_contracts_section.dart` — contracts list + drilldown

### `analytics_home_screen.dart` (545 → 3 file)
- `analytics_home_screen.dart` — main layout (< 200)
- `analytics_kpi_cards.dart` — KPI grid + tokens
- `analytics_filters_bar.dart` — date range + filter chips

### `occupancy_heatmap_screen.dart` (599 → 2 file)
- `occupancy_heatmap_screen.dart` — layout + state (< 250)
- `occupancy_heatmap_widgets.dart` — heatmap cell + legend + tooltip

### `contract_form_screen.dart` (502 → 3 file)
- `contract_form_screen.dart` — main form + validation (< 200)
- `contract_form_billing_section.dart` — billing fields
- `contract_form_parties_section.dart` — host/tenant/witness fields

## Related files

**Modify:** 5 file trên
**Tạo mới:** 13 file split ra
**Cẩn thận:** update tất cả import (rất nhiều consumer nếu là widget public)

## Implementation steps

Cho mỗi file:
1. Đọc toàn bộ file, identify sections (comment `// ────── Section X ──────` giúp scan)
2. Copy section ra file mới với private class/method (`_HostHomeDialogs` etc.)
3. Cập nhật main file import + delegate xuống file mới
4. Chạy `flutter analyze` sau mỗi file — catch import broken
5. Manual smoke test màn tương ứng
6. Diff visual before/after — must identical

## TODO checklist

- [ ] Split `host_home_screen.dart` — 4 file
- [ ] Split `room_detail_screen.dart` — 3 file
- [ ] Split `analytics_home_screen.dart` — 3 file
- [ ] Split `occupancy_heatmap_screen.dart` — 2 file
- [ ] Split `contract_form_screen.dart` — 3 file
- [ ] `flutter analyze` clean after each
- [ ] Manual smoke test 5 màn

## Success criteria

- Mỗi file mới < 300 dòng
- 0 behavior change
- 0 analyze issues mới
- Diff visual identical

## Risk

- **Private helper leak:** file split có thể lộ private helper ra public. Mitigation: giữ tất cả trong cùng library qua `part of` nếu muốn true private, hoặc rename `_X` → `X` chấp nhận exposed.
- **Import cycle:** 2 file mới cùng import nhau. Mitigation: dependency chỉ đi 1 chiều (main file → widget files, không ngược).

## Out of scope

- Không refactor logic (chỉ move code)
- Không đổi state management (Provider giữ nguyên)
- Không optimize performance
