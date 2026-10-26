# ancu365 — BA / User-Journey Review (business & flow, not visual styling)

**Reviewer role:** Senior Business Analyst / Product-UX Lead
**Trigger:** External reviewer feedback "không trực quan" (not intuitive)
**Scope:** Mental model, information architecture, task flows, onboarding/login friction, prioritized recommendations. Visual styling handled separately.
**Evidence:** 7 real rendered screens (onboarding desktop/mobile, login, home, leaderboard, community, industrial listing).

---

## 0. TL;DR verdict

The app is not "not intuitive" because of visuals — it is **not intuitive because it has no single answer to "what is this app for and what do I do first?"** Three products (rental marketplace + construction-services directory + social feed) are stapled together with **three overlapping taxonomies**, and the **primary screen greets the first-time user with an empty house list ("Không tìm thấy căn hộ phù hợp")**. The value proposition is contradicted between onboarding ("find a house") and the tagline ("operating newspaper for landlords"). Diagnosis: **strategic identity crisis surfaced as an IA problem.**

---

## 1. First-impression / mental-model analysis

**Journey observed:** Onboarding carousel → forced login → home.

**What each step tells the user the app IS:**
| Touchpoint | Signal sent | Implied audience |
|---|---|---|
| Onboarding slide 1 "Tìm nhà nhanh chóng — hàng ngàn căn hộ, nhà phố, biệt thự... lọc theo giá, diện tích, vị trí" | This is a **property search app for a house-SEEKER** | Tenant / buyer |
| Login tagline "Nhật báo vận hành cho chủ nhà thuê" + "Số 273 • Phát hành Thứ Hai" | This is an **operations newspaper for LANDLORDS** | Landlord/operator |
| Home: 6 service tiles across rental + construction + a social feed + a leaderboard | This is a **super-app / marketplace** | Everyone |

**Problem — three different mental models in the first 30 seconds.** The onboarding says "you find a home," the login says "you operate rentals as a landlord," the home says "you can do six unrelated things." A new user cannot form a stable mental model, which is exactly what "không trực quan" describes.

**On the "Nhật báo" (newspaper) metaphor — verdict: HURTS more than helps.**
- "Số 273 • Phát hành Thứ Hai" (Issue #273, published Monday) is clever brand poetry but **communicates nothing about the job the app does**. A first-timer does not want to "read an issue," they want to find/list/manage a property.
- The metaphor also **narrows to landlords** ("cho chủ nhà thuê") while the front door (onboarding + tiles) is aimed at tenants and service-buyers. It actively contradicts the acquisition funnel.
- Benchmark: Batdongsan / Chợ Tốt / Marketplace all lead with the **transaction verb** ("mua bán, cho thuê", "đăng tin", "tìm kiếm"), never a publishing metaphor. Users pattern-match to a verb, not a magazine.

**Is the primary action clear?** No. On home there are ~10 competing tap targets (6 tiles, leaderboard card, search, "Đăng tin" FAB, 4 nav tabs) and the one hero list ("Nhà nổi bật") is **empty**. There is no dominant call-to-action, so the eye has nowhere obvious to land.

---

## 2. Information Architecture critique

### 2.1 The core defect: one taxonomy, reused in three places with three different meanings

The same 6 concepts (Thuê nhà, Cho thuê, BĐS công nghiệp, Thiết kế, Xây dựng, Nội thất) appear as:

| Surface | What it lists | Concepts shown |
|---|---|---|
| **Home service tiles** | Marketplace entry points | all 6 (rental 3 + construction 3) |
| **Cộng đồng chips** | Social-feed filters | Thuê nhà / Cho thuê / BĐS công nghiệp |
| **Leaderboard tabs** | Contractor rankings | Thiết kế / Xây dựng / Nội thất / BĐS công nghiệp |
| **Bottom nav** | App-level sections | Khám phá / Yêu thích / Cộng đồng / Cá nhân |

**Overlap map:**
- "Thuê nhà / Cho thuê / BĐS CN" lives in BOTH tiles and community chips → user cannot tell whether tapping means "browse listings" or "filter social posts."
- "Thiết kế / Xây dựng / Nội thất / BĐS CN" lives in BOTH tiles and leaderboard tabs → is it a category to browse, or a ranking?
- Same word = different behavior depending on where tapped. This is the classic recipe for "không trực quan."

### 2.2 "Thuê nhà" vs "Cho thuê" as separate tiles — confusing for VN users

- To a Vietnamese user, **"Cho thuê" is the standard label for browsing rental listings** (Batdongsan "Nhà đất cho thuê", Chợ Tốt "Cho thuê"). "Thuê nhà" (I-want-to-rent) and "Cho thuê" (I-list-for-rent) are **role perspectives, not content categories**, but they are presented side-by-side as if they were different inventories.
- A tenant will hesitate: "Do I tap Thuê nhà or Cho thuê to see apartments?" A landlord will hesitate the same way. **Two doors to (essentially) one inventory** = decision friction with zero benefit.
- Recommendation preview: collapse to a **single "Nhà cho thuê" browse entry** + a separate, clearly-labeled **"Đăng tin cho thuê"** action for landlords. Role should be inferred/toggled, not split into two ambiguous tiles.

### 2.3 Is the industrial/design/build/interior expansion diluting the core?

Yes — and the screens prove it painfully:
- The **core rental home list is EMPTY** ("Không tìm thấy căn hộ phù hợp") while the **BĐS công nghiệp block has 2 real listings** and the leaderboard has 2 verified contractors. The **non-core blocks currently look more alive than the core product.** That inverts the intended hierarchy and tells users the rental core is dead.
- 6 blocks means 6 supply-side liquidity problems to solve at once. A marketplace lives or dies on liquidity in ONE vertical first. Spreading thin guarantees every block feels empty.
- The construction trades (Thiết kế/Xây dựng/Nội thất) serve a **different user with a different intent and buying cycle** (project, weeks-to-months) than rental search (transaction, days). Bolting them onto the rental home dilutes the "find a home now" clarity.

### 2.4 Leaderboard data credibility

- #1 "Kiến An Xây Dựng" 5.0 from **1 review**; #2 4.8 from 6 reviews. A "Bảng xếp hạng uy tín" built on 1–6 reviews is **not credible** and can erode trust rather than build it. Also observed: leaderboard opened on the **"Thiết kế" tab but #1 is a "Xây Dựng" company** — a category/label mismatch.

---

## 3. Task-flow gaps (top 3 journeys)

### Journey A — Tenant finds a house to rent (THE core journey)
1. Onboarding (good: promises house search) → 2. **Forced login wall** (friction, see §4) → 3. Home → 4. Choose between "Thuê nhà" vs "Cho thuê" (ambiguous, §2.2) → 5. Hero "Nhà nổi bật" is **EMPTY**.
- **Break point:** Step 5. The very first content a user sees on the primary screen is "no results." **Damage: severe.** In a marketplace, an empty core inventory on the landing screen reads as "abandoned app / no supply here" and is one of the strongest trust-killers possible. On Batdongsan/Chợ Tốt the first screen is always full of live listings. This single empty state probably drives much of the "không trực quan / không dùng được" reaction.
- Note: emptiness may be a **filter/geo default** (only showing near an unset location) rather than truly zero inventory — either way, the default state must never render "không tìm thấy" as the hero.

### Journey B — Browse/post in a community block
1. Bottom nav "Cộng đồng" → 2. Chips duplicate the marketplace taxonomy (§2.1) → 3. Feed shows **1 post** ("xin chào nhé", a screenshot of the app itself + an unrelated education-program image) then "Hết bài đăng."
- **Break point:** No seeded, relevant content; the one post is noise. A social feed with 1 low-value post signals a **dead community** and gives no reason to return. Users expect Marketplace-style utility (listings + light social), not an empty Facebook clone.
- **Confusion:** Is Cộng đồng for **finding listings** (chips say Thuê/Cho thuê) or for **chatting**? The composer ("Bạn đang nghĩ gì?") says social, the chips say marketplace. Mixed purpose.

### Journey C — Find a contractor
1. Home → "Bảng xếp hạng đối tác" OR a construction tile (Thiết kế/Xây dựng/Nội thất) — **two entry points, unclear which** → 2. Leaderboard with thin review data (§2.4).
- **Break point:** User cannot tell whether tiles = "browse contractors" and leaderboard = "ranked contractors," or whether they are the same list. Redundant doors again. Ranking credibility is low with 1–6 reviews.

---

## 4. Onboarding & login friction

- **Onboarding carousel (3 slides):** Slide 1 is on-message for rental search. Low harm, but it sets a **tenant** expectation that the landlord tagline then contradicts. Keep it short; make sure it matches the actual primary action. Standard "Bỏ qua / Tiếp theo" is fine.
- **Forced login before ANY content — the biggest funnel leak.** Users must authenticate before seeing a single listing. VN benchmarks (Batdongsan, Chợ Tốt, Marketplace) let you **browse freely and gate only on contact/post/save.** A hard login wall in front of an (empty) marketplace maximizes drop-off and prevents the app from ever proving value. **Strongly recommend: let users browse listings first; gate only save/contact/post.**
- **6 demo-role buttons visible to real users** (Khách thuê, Chủ nhà, Quản trị, ĐV Thiết kế/Xây dựng/Nội thất): **This is a defect, not a feature.** For real users it is (a) confusing ("which am I?"), (b) unprofessional (looks like a staging build), and (c) a **security/exposure risk** — a public "Quản trị" (admin) quick-login must never ship to production. **Remove from production build; keep behind a dev/QA flag only.**

---

## 5. Prioritized recommendations

### Quick wins (days, no redesign)
| Prio | Issue | User impact | Recommendation (scope-bounded) |
|---|---|---|---|
| **P0** | Home hero "Nhà nổi bật" renders EMPTY ("Không tìm thấy căn hộ phù hợp") | Reads as dead/broken app; kills trust on first screen | Never show a zero-result hero. Default to newest/all listings ignoring restrictive geo/filter; if truly zero, show a seeded "coming soon" + a "Đăng tin" prompt, not "không tìm thấy". |
| **P0** | 6 demo-role buttons (incl. "Quản trị" admin) exposed to real users | Confusion + unprofessional + admin-exposure risk | Remove from production; gate behind dev/QA build flag. |
| **P1** | Forced login before any content | Max funnel drop-off; value never demonstrated | Allow browse-without-login; gate only save/contact/post. |
| **P1** | "Thuê nhà" vs "Cho thuê" as two ambiguous tiles | Decision friction, wrong taps | Collapse to one "Nhà cho thuê" browse tile + separate "Đăng tin" action; infer role instead of splitting. |
| **P2** | Leaderboard credibility (1–6 reviews) + tab/label mismatch (Thiết kế tab shows a Xây Dựng company) | Erodes trust in rankings | Hide ranking until N≥ threshold reviews; show "Đối tác đã thẩm định" list instead of "#1/#2"; fix category tagging. |

### Needs redesign / product decision
| Prio | Issue | User impact | Recommendation |
|---|---|---|---|
| **P0** | No single clear "what is this app + primary action" | Root cause of "không trực quan" | Pick ONE hero job (recommend: rental search/browse) and make it the dominant, always-populated element; demote everything else. |
| **P1** | One taxonomy reused across tiles / community chips / leaderboard with different meanings | Same label behaves differently → confusion | Define one canonical category set + distinct labels per context; community filters should not mirror marketplace tiles verbatim. |
| **P1** | "Nhật báo vận hành cho chủ nhà thuê" contradicts the tenant-facing funnel | Mixed positioning | Replace tagline with a transaction-verb value prop aligned to the chosen hero job; drop the newspaper metaphor from the front door (can survive as internal brand flavor). |
| **P2** | 6 service blocks diluting core; construction = different user/intent | Thin liquidity everywhere, core looks dead | Sequence, don't parallelize: nail rental liquidity first; move construction/interior behind a secondary "Dịch vụ" section until core is healthy. |
| **P2** | Community purpose ambiguous (social vs marketplace) + empty | Dead-feed signal, no return reason | Decide community's job (Q&A / neighborhood / listing-discovery); seed content; or defer until core has users. |

---

## 6. Open questions / decisions for the Product Owner

1. **Identity (the one that unblocks everything else):** Is ancu365 a **rental marketplace with a community**, or a **community/operations app for landlords with rentals attached**? Onboarding, tagline, and home currently answer this three different ways. Pick one.
2. **Primary user:** Tenant (house-seeker) or Landlord (operator)? The funnel targets tenants; the tagline targets landlords. Who is the North-Star user for v1?
3. **Scope of the 6 blocks:** Keep all 6 now, or **focus on rental** and phase construction/interior/industrial in later once core liquidity exists? (Recommendation: focus.)
4. **Newspaper metaphor:** Is "Nhật báo / Số 273 / Phát hành Thứ Hai" a brand pillar worth keeping, or acquisition-funnel friction to drop from the front door?
5. **Login wall:** Is there a business reason (lead capture?) to force login before browse, or can we open browsing to lift the funnel?
6. **Community intent:** What job does Cộng đồng do that the marketplace doesn't? (Q&A, neighborhood, deal-discovery?) — needed before investing in it.
7. **Empty core — supply or filter?** Is "Không tìm thấy căn hộ" a real supply shortage or a default-filter/geo bug? Determines whether the P0 fix is code or supply/ops.

---

## Unresolved questions (need product-owner input before a redesign plan)
- Same as §6 items 1–3 and 7 — these are strategic/liquidity calls a BA cannot decide unilaterally. Everything in §5 "Needs redesign" is contingent on the identity answer (§6.1).
