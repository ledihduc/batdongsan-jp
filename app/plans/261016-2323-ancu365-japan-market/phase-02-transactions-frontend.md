# Phase 02 — Transactions Frontend

**Priority:** P1 · **Status:** 📋 Ready · **Est:** 3 weeks FE · **Depends on:** P1 FE + P2 BE
**Context:** [Gap matrix §2.5-2.6, §2.2](../../../plans/261016-2323-ancu365-japan-market/research/gap-matrix.md)

## Overview

Checkout UX (card/konbini/bank), 審査 review screens for sales/owner, APPI consent banners + settings, IT重説 join screen, eContract signing screen.

## Requirements

**Functional**
- Checkout screen with payment method tabs (card / konbini / bank-transfer); konbini → voucher display + instructions.
- Payment status screen with real-time poll + push on webhook arrival.
- Sales/owner 審査 screens: application detail view + approve/reject buttons with reason.
- APPI consent capture at register: scrollable text + checkboxes per purpose + "同意する" required.
- Settings → 個人情報の取扱い page: view current consents, revoke, request export, request deletion.
- IT重説 join screen: 宅建士 info, Zoom join link, consent re-affirm checkbox before entering.
- eContract signing screen: embedded CloudSign widget (or deep link out) + status pill.

## Architecture

```
lib/features/
  checkout/
    jp_checkout_screen.dart
    konbini_voucher_screen.dart
    payment_status_screen.dart
  sales/
    application_review_screen.dart   ← extends P1 queue
  consent/
    consent_banner_sheet.dart        ← shown at register
    consent_settings_screen.dart     ← settings page
    data_export_request_screen.dart
    data_delete_confirmation_sheet.dart
  it_session/
    it_session_join_screen.dart
  econtract/
    econtract_signing_screen.dart
```

## Related code files

**Modify**
- `lib/features/auth/register_screen.dart` — mount APPI consent step
- `lib/features/guest/application/*` — on submit, route to payment setup
- `lib/features/profile/profile_screen.dart` — add "個人情報の取扱い" entry
- `lib/core/router/app_router.dart` — add /checkout, /viewings/:id/it-session, /econtracts/:id

**Create** — see Architecture

## Implementation steps

1. Payment method tabs widget; wire to BE `/api/jp/payments`.
2. Konbini voucher screen (store list, barcode, deadline, copy-paste number).
3. Payment polling + FCM topic subscription per invoice.
4. 審査 screen for sales/owner — show application fields, upload docs, decision form.
5. APPI consent sheet — multiple purposes, require all before continue; store consent IDs.
6. Settings consent page — list + revoke + export job trigger + delete confirmation modal with cooling-off.
7. IT重説 join screen — show 宅建士 name/number, re-affirm checkbox, launch Zoom.
8. eContract — WebView embed CloudSign iframe OR url_launcher external, status pill polls BE.

## Todo list

- [ ] Checkout + 3 payment methods
- [ ] Konbini voucher UI
- [ ] Payment status polling
- [ ] 審査 approve/reject UI
- [ ] APPI consent at register
- [ ] Consent settings + DSR flows
- [ ] IT重説 join screen
- [ ] eContract signing screen
- [ ] ARB keys all 4 locales
- [ ] Tests green, VN smoke pass

## Success criteria

- Tenant pays via konbini voucher → polling turns status to paid.
- Sales approves application → tenant sees approved status → IT重説 slot → signs eContract → invoice issued.
- APPI consent captured at register; user can view/revoke/export/delete from settings.

## Risk assessment

- CloudSign iframe may not work in Flutter WebView — fallback to external browser via url_launcher.
- Konbini copy must match Komoju's exact JA labels — pull from provider docs, not translate.
- Consent copy = legal text — must come from legal review, not engineering.

## Security

- Payment status WebSocket/polling uses short-lived JWT.
- WebView whitelists Komoju + CloudSign domains only.
- Consent snapshot stored with policy version at time of acceptance.

## Next steps

- Unblocks: P3 FE (AI search), P4 (end-to-end persona scripts).
