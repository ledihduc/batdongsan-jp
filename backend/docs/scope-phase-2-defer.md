# Scope Phase-2 Defer List

**Status:** Active (binding during phase-1 JP fork work)
**Owner:** Phase-01 pre-fork-hygiene (B1 scope-freeze mitigation for R-1)
**Review gate:** Phase-11 launch review MUST verify no feature outside SU §2 shipped.

---

## Why

SU §10 R-1 (HIGH): "Scope sprawl từ finish in-place" — làm in-place trên repo đang live rất dễ cám dỗ thêm feature "nhân tiện làm nốt". Scope-freeze gate ngăn phase-1 (JP go-live) ballon ra ngoài SU §2 boundary.

## Phase-1 scope boundary (shipped)

Chốt theo Shared Understanding §2:
- JA UI + master data JP (KEN_ALL, 間取り, 建物種別, 設備).
- APPI compliance (consent, DSR, breach, 相当措置, DPO).
- 特商法 Art.11, 消費税/総額表示, インボイス T番号.
- Komoju payment (card + konbini + bank_transfer + PayPay).
- 宅建業法 portal-only model (no 媒介).
- Native-JP copy pass.
- Tokyo prod deploy + 14-day stability.

## Phase-2 defer list (NOT shipped in phase-1)

1. **匿名加工情報 pipeline** — pseudonymization/anonymization pipeline cho data broker use. APPI tùy chọn, không bắt buộc cho portal rental marketplace v1.
2. **IT重説 (IT 重要事項説明)** — remote video-based explanation per 宅建業法 2017 revision. Yêu cầu 専任宅建士 — không áp dụng khi phase-1 chạy portal-only. Defer đến khi (nếu) chuyển sang 媒介 model.
3. **PostGIS planning map** — city planning overlay (用途地域, 建蔽率, 容積率) trên map. Tốt cho UX nhưng không là compliance blocker; defer.
4. **Zengin direct debit (口座振替)** — 口振代行 qua GMO PG / SMBC Finance. Komoju bank_transfer đã cover thanh toán 1 lần; Zengin phục vụ subscription/recurring. Defer đến khi có use case subscription.
5. **Z-sign / CloudSign rental contract flow** — e-sign cho hợp đồng thuê. Phase-1 giữ paper contract + email upload; e-sign full flow defer.
6. **Admin backoffice multi-locale** — admin console vẫn JA/EN single-locale phase-1; multi-locale defer.

## Enforcement

- Phase trưởng CẤM mở PR implement các mục trên trong phase-1.
- Nếu discover edge case khi làm phase khác yêu cầu mục defer → RAISE lại gate SU + lock lại (reopen Planning Council, không âm thầm add).
- Phase-11 launch gate checklist có bullet verify defer list sign-off (xem phase-11 §Launch gate check).

## Change log

- 2026-10-19 — Phase-01 publish (B1 fix in Planning Council debate round 1).
