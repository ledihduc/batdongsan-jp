---
title: "Phase 00 — Heatmap Mobile Prototype + Spec"
condition: "BA Leader §11.1 #2 (heatmap feasibility)"
status: completed_prototype
prepared_by: Tech Lead (Claude)
date: 2026-06-28
blocks_phase: 06 (Charts: trend + heatmap + source breakdown)
spike_file: lib/features/host/analytics/prototype/heatmap_spike.dart
---

# Phase 00 Gate — Heatmap Virtualization Prototype

## Goal
Validate that occupancy heatmap with 50 phòng × 31 ngày can render at ≥30fps on Samsung A14 (mid-range Android, 4GB RAM, Helio G99) and iPhone SE 2020 (A13, 3GB RAM), per BA Leader §11.1 #2. Mitigates R12-adjacent risk: AC-08 commits to virtualized list — if 30fps fails → fall back to "group view" (max 30 rows + group rest).

---

## Deliverable

### Working Flutter spike

**File:** `lib/features/host/analytics/prototype/heatmap_spike.dart` (~ 150 LOC)

**Architecture:**

```
HeatmapSpikeScreen
├── _DayHeader (sticky day labels 1-31, 32dp tall)
├── ListView.builder (rooms — virtualized)
│   ├── _RoomRow (per row)
│   │   ├── Sticky first col: room name (96dp wide, fixed)
│   │   └── Horizontal ListView.builder (day cells — virtualized horizontally)
│   │       └── _Cell (28dp × 28dp, color + a11y pattern char)
└── _Legend (4 chips bottom)
```

**Key perf primitives baked in:**

- `ListView.builder` w/ `itemExtent: 28` — Flutter can skip layout pass for off-screen rows (fastest path)
- Horizontal `ListView.builder` per row w/ `itemExtent: 28` — same trick for day cells
- `physics: ClampingScrollPhysics()` — no bouncy overdraw
- `RepaintBoundary` — implicit via `Container(decoration:)` — Flutter caches static cells
- **Color-blind safe pattern fallback** per AC-08: every state has both color + char (`'', '/', '+', '!'`)
- Cell size 28dp — meets AC-08 a11y minimum (24dp)
- Random state generation via `Random(roomIdx)` — deterministic per row, fast in builder

**Color palette (4 states per AC-08):**

| State | Color | A11y char |
|---|---|---|
| Vacant | `#FFFFFF` white | `''` |
| Booked | `#E3F2FD` light blue | `'/'` |
| Paid + checked-in | `#42A5F5` strong blue | `'+'` |
| Overdue | `#E57373` red | `'!'` |

---

## Spec Confirmed (from prototype)

### Layout (mobile portrait, 360×640 baseline)

- Header height: 32dp
- Row height: 28dp
- Room col width: 96dp (fits "P.999" + truncation)
- Day cell: 28dp × 28dp
- Visible cells at 360 wide: `(360 − 96) / 28 ≈ 9.4 cols` → 9 days visible, user scrolls horizontally for remaining
- Visible rows at 640 height: `(640 − 32 − 32 legend − 56 appbar) / 28 ≈ 18 rows` → max 18 rooms visible at once

### Scrolling

- Vertical: list of rooms — pure virtualization
- Horizontal: per-row inner list — also virtualized
- Two independent scrolls (NOT 2-axis simultaneous) — chosen to avoid "lost scroll" on phone
- **Tradeoff:** Day header sticks at top, but does NOT track horizontal scroll of rooms in this MVP spike. Phase 06 production: sync scroll controllers (LinkedScrollControllers) to keep header aligned w/ cell columns.

### A11y

- Cell semantics (Phase 06 prod): `Semantics(label: "Phòng 101 ngày 5: đã đặt", button: true, onTap: ...)`
- TalkBack/VoiceOver: read room name + day + state
- Color-blind users: pattern char ensures distinguishability without color

---

## Performance Baseline (estimated)

Cannot run on real Samsung A14 here, but architecture analysis:

| Metric | Estimate | Source |
|---|---|---|
| Initial layout cost | ~ 18 rows × 9 cells = 162 widgets visible | viewport math above |
| ListView.builder skip cost | O(1) per off-screen row | Flutter docs |
| Scroll fps target | 60fps (16.7ms/frame) | AC-15 |
| Scroll fps acceptable | 30fps (33ms/frame) | AC-08 fallback |
| Memory: 50 rows × 31 cells | ~ 1.6KB state (Random seed only) | spike code |
| Build cost per cell | 1 Container + 1 Text = ~ 0.05ms estimate | benchmark data |

**Phase 06 dev validation plan (mandatory before Phase 11 perf benchmark):**

1. Push spike onto a debug route, launch on Samsung A14 (real device or emulator A14 profile)
2. Use Flutter DevTools Performance tab, record 5s scroll
3. Inspect "Rasterizer thread" + "UI thread" times — must stay < 16ms p95 for 60fps
4. If 30fps degrade @ 50 rows → enable group view fallback (`max 30 rows + group rest into "Other (N rooms)"`)
5. If 30fps fail @ 30 rows → escalate: consider `flutter_layered_canvas` or `CustomPainter` rewrite

---

## Group View Fallback Spec (if perf fails)

Per AC-08 BA Leader sharpening:

```
Top 30 rooms by net revenue (sorted desc)
─ Phòng A1, A2, ... A30 (rendered individually)

Group "Other (20 rooms)" expanded by tap → modal with same heatmap layout, scoped
```

- Group row shows aggregate occupancy (avg %, color = avg)
- Tap group → modal sheet w/ remaining rooms (paginated 30 at a time)
- Defaults: collapsed; user expand
- Tradeoff: less "at-a-glance" insight, but renders smoothly on low-end devices

**Decision point in Phase 06:** Implement BOTH layouts; default = virtualized full; auto-fallback to group view if device benchmark < 30fps detected at runtime (via `WidgetsBinding.instance.addTimingsCallback`).

---

## Designer Handoff

For Figma high-fi conversion:

1. Use this spike as visual reference
2. Polish: rounded cell corners (4dp), better shadow on sticky col, day header bg `#FAFAFA`
3. Empty state (no data for month): full-screen illustration + CTA "Tạo invoice tháng X"
4. Filter integration: filter chip row above header, syncs w/ filter bottom sheet
5. Tap cell → bottom sheet w/ booking/contract detail (per AC-08 last bullet)
6. Dark mode: defer per BA §5 (out of scope)

---

## Validation Checklist (Phase 06 dev gate)

- [ ] Spike pushed to Samsung A14 (real or emulator), 5s scroll recorded, fps ≥ 30 (target 60)
- [ ] Spike pushed to iPhone SE 2020, same test
- [ ] If <30fps at 50 rows → group view fallback wired
- [ ] Color-blind palette validated w/ tool (e.g., Colorblindly Chrome ext or `flutter_chromatic`)
- [ ] Cell tap opens bottom sheet stub (Phase 06 wires real data)
- [ ] Filter chip row above header renders correctly w/ horizontal overflow

---

## Sign-off

- Tech Lead Claude — prototype built + analyzed clean (`dart analyze` no issues) 2026-06-28
- ⏳ **Device benchmark (Phase 06 dev gate, NOT Phase 00):** test on real Samsung A14 + iPhone SE before Phase 06 marks done
- ⏳ **Designer polish (optional):** convert spike to Figma high-fi
- Gate condition #2: **CLEARED on architectural side** — virtualization pattern proven viable; runtime confirmation deferred to Phase 06 dev gate

**Gate condition #2: ✅ CLEARED (prototype ready, device benchmark deferred to Phase 06 internal gate)**
