# Phase 03 — Scale Frontend

**Priority:** P2 · **Status:** 🏗️ In Progress · **Est:** 2 weeks FE · **Depends on:** P2 FE + P3 BE
**Context:** [Gap matrix §2.4, §2.5, §2.8](../../../plans/261016-2323-ancu365-japan-market/research/gap-matrix.md)

> **Scope change 2026-10-17:** AI search chat UI **CUT** (BE NLU cut too — defer to post-launch).
> Add: enhanced facet search (ペット可 / 駅徒歩分 / 間取り range) + account deletion UI + DSR download UI.

## Overview

更新 renewal notification + confirmation UI · 敷金精算 settlement UI (owner itemize + tenant review) · admin KPI dashboard JP · DSR real export download UI · account deletion schedule UI · enhanced facet search chips.

## Requirements

**Functional**
- Renewal screen: tenant sees upcoming renewal, 更新料 breakdown, confirm/renegotiate button.
- Deposit settlement — owner: itemize deductions with photo per line, running net refund display.
- Deposit settlement — tenant: review itemized breakdown, accept or dispute action.
- Admin KPI dashboard: 5 cards + prefecture dropdown + date range picker.
- DSR export: tap "個人情報をエクスポート" → downloads real JSON (via BE blob response).
- Account deletion: schedule 30d countdown screen + cancel button; show warning + email reconfirm.
- Enhanced facets on guest search: pets_ok toggle, walk_min slider, layout chips (1K / 1DK / 1LDK / 2LDK+).

## Architecture

```
lib/features/
  renewal/
    renewal_detail_screen.dart
    renewal_confirm_sheet.dart
    data/renewal_repository.dart
  deposit_settlement/
    owner_itemize_screen.dart      ← owner persona
    tenant_review_screen.dart      ← tenant persona
    data/settlement_repository.dart
  admin/
    jp_kpi_dashboard_screen.dart
    widgets/jp_kpi_card.dart
    data/admin_kpi_repository.dart
  consent/
    account_deletion_screen.dart   ← NEW (schedule + cancel)
    (settings_screen.dart updated — wire real export + deletion CTA)
  guest/search/
    jp_search_facets_drawer.dart   ← add pets_ok, walk_min, layout chips
```

## Implementation steps

1. **Renewals**
   - Model `JpRenewal` + repo (mock + real).
   - `renewal_detail_screen` — fetches by renewal_id, shows contract summary + 更新料 line items + confirm sheet.
   - Wire into `features/guest/notifications` list — tap renewal notification → push screen.
2. **Deposit settlement**
   - Model `JpDepositSettlement` + `DeductionLine` + repo.
   - Owner screen: `DsFormSection` per line (title / amount / photo via `ImageGridUploader`), live running total card at bottom, submit → tenant_review state.
   - Tenant screen: read-only itemize list + accept CTA (triggers refund invoice) OR dispute sheet with free-text reason.
3. **Admin KPI dashboard**
   - 5 `JpKpiCard` widgets (icon + metric + delta vs prev period).
   - Prefecture dropdown (reuse `JpPrefectureSelector` from P1).
   - Date range picker (`DsDateRangePicker` — reuse or create).
   - **No chart library** for MVP — simple metric cards only. Add charts post-launch.
4. **DSR export + deletion**
   - Settings screen: existing "個人情報をエクスポート" button → real BE call → trigger browser download (web: `html.AnchorElement` with blob URL; mobile: share sheet).
   - "アカウント削除" button → push `account_deletion_screen` → shows 30d scheduled countdown + cancel CTA.
   - Warning copy + 2-step confirm (type email to confirm).
5. **Enhanced facets**
   - Add 3 facet widgets to `jp_search_facets_drawer`:
     - `pets_ok` toggle switch
     - `walk_min` slider (0-30 min)
     - `layout` multi-select chips (1K / 1DK / 1LDK / 2LDK / 3LDK+)
   - Pass to listing query repo.
6. **ARB keys** — ~40 new keys (renewal, settlement, KPI, deletion, facets) × 4 locales.
7. **Tests** — unit (repos), widget (each new screen), i18n (JA keys present).

## Related code files

**Create**
- `lib/data/models/jp/{renewal,deposit_settlement,admin_kpi}.dart`
- `lib/data/repositories/jp/{renewal,settlement,admin_kpi}_repository.dart` (+ `_mock_` variants)
- `lib/domain/repositories/jp/{i_renewal_repository,i_settlement_repository,i_admin_kpi_repository}.dart`
- `lib/features/renewal/{renewal_detail_screen,renewal_confirm_sheet}.dart`
- `lib/features/deposit_settlement/{owner_itemize_screen,tenant_review_screen}.dart`
- `lib/features/admin/{jp_kpi_dashboard_screen,widgets/jp_kpi_card}.dart`
- `lib/features/consent/account_deletion_screen.dart`
- `test/widget/jp/{renewal,settlement_owner,settlement_tenant,admin_kpi,account_deletion}_test.dart`
- `test/i18n/ja_p3_keys_test.dart`

**Modify**
- `lib/features/consent/settings_screen.dart` — wire real DSR + deletion CTA
- `lib/features/guest/search/jp_search_facets_drawer.dart` — 3 new facets
- `lib/core/router/app_router.dart` — add 5 routes
- `lib/l10n/app_{vi,en,zh,ja}.arb` — ~40 keys each

## Todo list

- [ ] Renewal screen + repo + tests
- [ ] Deposit settlement owner screen + tests
- [ ] Deposit settlement tenant screen + tests
- [ ] Admin KPI dashboard + tests
- [ ] Account deletion screen + wire into settings + tests
- [ ] DSR real download wired
- [ ] Enhanced facet widgets in drawer + wired to repo
- [ ] ARB keys × 4 locales + i18n test
- [ ] `flutter analyze` clean · full `flutter test` pass
- [ ] VN region smoke — no JP strings leak into VN mode

## Success criteria

- Renewal notification → tap → detail → confirm → BE invoice created.
- Owner itemizes 3 deductions → tenant accepts → refund invoice shown.
- Admin selects 東京都 + last 30d → sees 5 KPI cards populated.
- Settings "エクスポート" downloads real JSON blob.
- Account deletion schedules + displays countdown, cancellable.
- Facet drawer with pets/walk/layout filters results.

## Risk

- **Mobile download UX** — Flutter mobile DSR download = share sheet (not direct DL); set expectations in UI copy.
- **Chart library** avoided — if PM pushes for visuals, add in P4 or post-launch.
- **Dispute flow depth** — MVP: free-text reason only; no 3-way mediation UI (owner/tenant/admin triage comes post-launch).

## Security

- Account deletion confirm = email re-type (not just checkbox).
- DSR download goes via BE route (auth-gated); never serialize PII client-side.
- Admin KPIs: route-guard requires `role=admin` + `org_id` scope (BE enforces; FE just shows link).

## Next steps

- Unblocks: P4 Launch.
