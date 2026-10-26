# ancu365 — UI/UX Audit Synthesis (Designer + BA)

**Date:** 2026-07-12 · Trigger: reviewer feedback "không trực quan".
**Method:** live screenshots (onboarding, login, home, leaderboard, community, block) + current prod code + DB/API checks.
**Detail reports:** `designer-review.md` (visual/heuristic), `ba-review.md` (product/IA/flow).

## Verdict
App isn't broken, it *reads* broken. Two layers of problem:
- **Product/IA (BA):** fails the "what is this + what do I do first" test. Onboarding says *find a house*, login tagline says *operations newspaper for landlords*, home says *6-in-1 super-app* → 3 identities in 30s, no dominant CTA, empty hero.
- **Visual (Designer):** monotone red/pink flood erases hierarchy; empty states look like errors; no web adaptation; decorative serif-italic used as UI titles.

## Confirmed defect (was "unknown: data or bug?")
- DB: **16 published houses (15 rent)**; API `/api/houses?transaction_type=rent` returns them fine.
- Home still shows "Không tìm thấy căn hộ phù hợp".
- Root cause: `providers/house_provider.dart` `fetchHouses()` wraps the call in `try/catch` that only `print`s the error and leaves `_houses` empty → any transient fetch failure renders a dead hero. No loading/error state distinct from "empty".
- → Finding #1 is a **code fix**, not an inventory problem.

## P0 — do now (no strategic decision needed)
1. **Empty/error state on home hero** — never render bare "không tìm thấy"; distinguish loading / error(retry) / truly-empty; default hero to newest listings; surface fetch errors instead of swallowing. (`house_provider.dart` fetch, `guest_home_screen.dart:494`)
2. **Remove 6 demo-role login buttons from prod** (esp. **Quản trị/admin** — exposure + confusion). Gate behind debug flag. (`login_screen.dart:255`)
3. **Purge junk/test images** in live community feed (app-screenshot, cemetery photo). (seed/data)
4. **De-flood red:** neutral page bg `#FAFAF8`, drop `HDGradientBackground` page-flood; red as accent ≤10% viewport. (`design_tokens.dart:17,60`)
5. **FAB bottom padding** so "Đăng tin" stops overlapping the promo banner. (`guest_home_screen.dart` scroll padding)
6. **Empty avatar/thumbnail placeholders** → initials avatar + branded caption placeholder (stop reading as broken images). (`:591`, `property_listing_screen.dart:176`)
7. **Serif-italic only for logo + numerals**, not screen/list titles. (`ds_app_bar.dart`)

## P1 — needs a product decision first
- **App identity** (unblocks everything): rental marketplace *with* community, or landlord/community app *with* rentals?
- **"Thuê nhà" vs "Cho thuê"** duplicate tiles → collapse to one "Nhà cho thuê" browse + separate "Đăng tin".
- **One taxonomy used 3 ways** (home tiles / community chips / leaderboard tabs) → distinct labels per context.
- **Login wall** before any content → allow browse-without-login, gate only save/contact/post.
- **Newspaper tagline** ("Nhật báo vận hành cho chủ nhà thuê") → replace with a transaction-verb value prop.
- **6-block scope**: focus rental first, phase in construction/industrial once liquidity exists (recommend).
- **Leaderboard credibility**: hide rankings below a review threshold (currently 1–6 reviews).

## P2 — structural / responsive
- Web `contentMaxWidth 1080` / `formMaxWidth 440`; grid cols 2/3/4 by breakpoint; center shell body.
- Full palette/semantic-color system (success/warning/danger decoupled from brand red); type scale; spacing rules.

## Proposed palette/hierarchy (designer)
- Ground neutral: bg `#FAFAF8`, surface `#FFFFFF`, sunken `#F3F2EF`, hairline `#E7E5E1`, inkMuted `#626873`.
- Red = accent only: `#DC2626` CTA/price/brand/active-nav; `#B91C1C` icon-on-tint/hover; `#FEF2F2` selected/focus only (never full-page).
- Semantics: success `#15803D`, warning `#B45309`, danger `#B91C1C`.
- Rules: bg always neutral; ≤1 primary red CTA/screen; tinted discs on white; destructive ≠ brand red.

## Open questions for owner
1. Identity: rental+community or community+rentals? 2. Primary v1 user: tenant or landlord? 3. Keep all 6 blocks or focus rental first? 4. Keep newspaper brand metaphor? 5. Login wall deliberate (lead capture) or removable? 6. Prod seed-data: reset vs moderation?
