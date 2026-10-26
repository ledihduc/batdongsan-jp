# Phase 01 — Core Chintai Frontend

**Priority:** P1 · **Status:** 📋 Ready · **Est:** 3 weeks FE · **Depends on:** P0 FE + P0 BE merged
**Context:** [Gap matrix §2.3-2.7](../../../plans/261016-2323-ancu365-japan-market/research/gap-matrix.md) · [FE scout §4](../../../plans/261016-2323-ancu365-japan-market/research/researcher-03-frontend-scout.md)

## Overview

Japanify the listing/search/booking UX for all 4 personas (入居者, 仲介, オーナー, 管理者). Add 内見 scheduler screens, 申込 multi-step form, chat JA presets. Reuse existing feature folders; gate by `region=jp`.

## Key insights

- Follow existing `features/guest/booking/booking_detail_screen.dart` pattern for long screens — extract section widgets.
- Form submit sticky; use `DsFormSection` + `DsTextField` + `ImageGridUploader`.
- `context.go` only for URL-worthy screens; sub-flows (申込 steps, 内見 slot picker sheet) use `Navigator.push`.
- 4 personas = 4 mental models — do NOT reuse host screens blindly for owner/sales.

## Requirements

**Functional**
- Listing form (owner/sales): adds JP fields (間取り picker, 面積 input, 築年数, 構造, 階数, 向き, availability, 敷/礼/更/保/仲 money matrix).
- Listing detail (tenant): displays all JP terms with legally-correct labels (ja), transit chips with walk-time.
- Search: facet drawer with 間取り multi-select, 家賃 range, 面積 range, 築年数 max, 駅徒歩 max, flags (ペット可, 保証会社不要, etc.).
- 内見 request flow: pick ≤3 slots from calendar → send → status screen → push on confirmation.
- 入居申込: 5-step wizard (基本情報 → 勤務先 → 保証人 → 書類アップロード → 確認).
- Chat: JA quick-reply chips, honorific toggle (丁寧語 default on for 仲介→入居者).
- Agent dashboard: 担当物件 list, 内見リクエスト inbox, 申込待ち queue.

## Architecture

```
lib/features/
  guest/
    search/
      jp_search_facets_drawer.dart       ← NEW
      transit_filter_chip.dart           ← NEW
    listing/
      jp_terms_section.dart              ← NEW section widget
      jp_property_info_section.dart      ← NEW
    viewing/
      viewing_request_sheet.dart         ← NEW
      viewing_status_screen.dart         ← NEW
    application/
      application_wizard_screen.dart     ← NEW (routes to 5 steps)
      steps/*.dart                       ← NEW
  host/
    listing_edit/
      jp_terms_edit_section.dart         ← NEW
      jp_money_matrix_input.dart         ← NEW
  sales/                                 ← NEW persona folder
    dashboard_screen.dart
    viewing_inbox_screen.dart
    application_queue_screen.dart
  chat/
    jp_quick_reply_chips.dart            ← NEW
```

## Related code files

**Modify**
- `lib/features/guest/search/search_screen.dart` — mount JP facet drawer when region=jp
- `lib/features/guest/listing/listing_detail_screen.dart` — mount JP sections
- `lib/features/host/listing_edit/listing_edit_screen.dart` — mount JP edit sections
- `lib/features/chat/chat_screen.dart` — mount JA presets
- `lib/core/router/app_router.dart` — add sales persona routes, 内見 + 申込 routes
- `lib/l10n/app_ja.arb` (+ vi/en/zh) — ~150 new keys

**Create**
- All files listed in Architecture above
- `lib/features/sales/` folder (new persona)
- Widget tests for new section widgets

## Implementation steps

1. ARB keys first (parallel-friendly, no code dependency): JP terms, facet labels, 内見 copy, 申込 copy, chat presets.
2. Build JP data models + repositories (consume BE JSON).
3. Section widgets for listing detail (tenant view) — compose with existing scaffold.
4. Edit sections for host/sales listing form.
5. Search facet drawer — ensure state persists across result paging.
6. 内見 request sheet (push-based) + status screen (GoRoute `/viewings/:id`).
7. Application wizard — 5 steps as separate screens inside parent GoRoute `/applications/:id`.
8. Sales persona dashboard + inbox + queue screens.
9. Chat JA quick-reply + honorific toggle setting in profile.
10. Verify VN build still works (gate everything behind region check).
11. `flutter analyze` + `flutter test` + web build.

## Todo list

- [ ] ARB keys added in all 4 locales
- [ ] JP data models + repositories
- [ ] Listing detail JP sections render correctly
- [ ] Listing edit JP sections validate properly
- [ ] Search facet drawer wired to BE query
- [ ] 内見 request end-to-end
- [ ] 申込 wizard with document upload
- [ ] Sales persona screens routable
- [ ] Chat JA presets usable
- [ ] VN region smoke pass
- [ ] All tests green

## Success criteria

- Tenant can search by 間取り+駅徒歩, open listing, see all JP terms, request 内見, submit 申込.
- Sales agent sees 内見 inbox, confirms a slot, reviews 申込 queue.
- Owner creates JP listing with full money matrix without errors.
- VN build untouched.

## Risk assessment

- Scope spread — resist adding renewal/screening UI here (that's P2/P3).
- Legal labeling of money fields — ask BA for exact JA wording per spec doc 03.

## Security

- Document upload reuses existing signed-URL flow; 申込 PII flows don't surface to shared chat.

## Next steps

- Unblocks: P2 FE (screening UI, IT重説 join screen, eContract signing).
