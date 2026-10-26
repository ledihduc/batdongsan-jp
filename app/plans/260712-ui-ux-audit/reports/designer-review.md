# ancu365 — UI/UX Audit ("không trực quan" root-cause review)

Senior UI/UX audit of live Flutter-web super-app. Grounded in 7 real screenshots + prod code.
Verdict up front: the app is not broken — it *reads* broken. Three compounding causes: (1) a **monotone red/pink flood** that erases hierarchy, (2) **empty/placeholder states that look like errors**, (3) **zero web/desktop adaptation** + a **serif-italic used as UI titles**. Fixes are mostly token + layout level, not rewrites.

---

## 1. Heuristic evaluation per screen

### Onboarding (`home-desktop.png`, `home-mobile.png`) — `features/onboarding/onboarding_screen.dart`
- **Desktop = catastrophic empty space.** Content is a centered mobile column on a 1280px canvas; ~70% of viewport is dead pink. No `maxWidth`, no art, no 2-pane layout. Violates *aesthetic & minimalist* + basic web craft. Reviewer's "không trực quan" starts here — first screen looks unfinished.
- Icon-in-circle is `accent` (#DC2626) on `accent.withOpacity(0.1)` (line 180) — a pale red magnifier on a pale red disc. Low figure/ground; icon barely reads.
- Slide 1 uses `HD.accent` red, slide 2 `HD.positive` green, slide 3 red again — inconsistent accent per slide with no semantic reason.
- "Bỏ qua" top-right is `inkSoft` text with no affordance; fine but lonely.
- Skip/next controls OK. Dots OK. This screen's only real sin is *no responsive treatment*.

### Login (`mobile-home.png`) — `features/auth/login_screen.dart`
- **Metaphor confusion.** Masthead "Số 273 • Phát hành Thứ Hai" + "ancu365" italic serif + "Nhật báo vận hành cho chủ nhà thuê" (a *newspaper* framing) on a property-rental login. A first-time user can't tell what the product does. Violates *match between system and real world*.
- **Six demo-role quick-login chips shipped to prod** (Khách thuê / Chủ nhà / Quản trị / ĐV Thiết kế / ĐV Xây dựng / ĐV Nội thất, lines 152–207). Looks like an internal test build; erodes trust and clutters the primary auth task. Also a security smell (admin one-tap).
- Page bg is `HDGradientBackground` → pink top fading white. Pink login field (`accentSoft`) on pink page = weak separation.
- Positive: form has a real `maxWidth: 440` (line 57) — the *only* screen that does responsive right. Use it as the template.

### Guest Home / shell (`h-top.png`) — `guest_home_screen.dart` + `home_services_section.dart`
- **Empty hero.** "Nhà nổi bật" section renders `Không tìm thấy căn hộ phù hợp.` as bare centered text (lines 494–500). On the *primary* screen the main content slot is an error-looking sentence. This alone reads as "app broken."
- **FAB overlaps banner text.** Extended "Đăng tin" FAB floats bottom-right directly over the promo banner headline "Trải nghiệm sống đẳng cấp". No bottom scroll padding reserved for the FAB. Classic overlap defect.
- **Lone "Tất cả" chip.** Category pills build `categories.length + 1`; for guest, categories are empty so only a single red "Tất cả" chip shows (lines 357–396) — a filter control with nothing to filter. Reads as stub.
- **Red overload.** Service tiles: `accentTint` disc + `accent` icon ×6. "MỚI" badge red. Leaderboard shortcut `accentTint`. Search bar `accentSoft`. "KHÁM PHÁ NGAY" red. Selected chip red. Price red. Everything is a shade of red on pink gradient → **no visual hierarchy; nothing is emphasized because everything is.**
- **Redundant taxonomy.** "Thuê nhà" and "Cho thuê" tiles both call `_openListing` → same rent list (home_services_section.dart:62–65 both hit `_openListing`, and home's `_openListing` forces `'rent'`). Two tiles, one destination. Confusing.
- **Services grid vs bottom nav purpose overlap.** Top grid = Thuê/Cho thuê/BĐS CN/Thiết kế/Xây dựng/Nội thất; bottom nav = Khám phá/Yêu thích/Cộng đồng/Cá nhân. Two parallel navigation systems, neither labeled as primary. User must guess.
- Avatar in app bar loads a hardcoded `lh3.googleusercontent.com/aida-public/...` URL (line 126) — a stock placeholder that reads as "not my account."

### Leaderboard (`lg-home.png`) — `contractor_leaderboard_screen.dart` + `DsAppBar`
- **Serif-italic title kills scannability.** "Bảng xếp hạng đối tác" renders in Instrument Serif *italic* weight-400 (DsAppBar `titleAsSerif=true` default → `HD.sectionTitle` italic). At title size the slanted thin serif looks wobbly/decorative, not like a screen header. Same defect on every nested screen.
- Partner rows: empty circular avatar with a generic building glyph on pink; "#1 / #2" rank + name + rating + red "Pro"/"Nổi bật"/"Đã thẩm định" chips. Chips are OK but again all-red family. Only 2 rows → page feels thin; no empty/loading distinction.

### Community feed (`community.png`) — `social_feed_screen.dart` + `post_card.dart`
- **Junk seed data on display.** Post "xin chào nhé" attaches (a) a screenshot *of the app's own home screen* and (b) an unrelated photo of people at a cemetery. This is test data leaking to a public feed — instantly reads as unfinished/broken. Highest-impact "không trực quan" signal after the empty grid.
- **Uneven 2-image grid.** `_imageGrid` forces each of 2 images to `aspect:1` (post_card.dart:194–199). A tall infographic gets square-cropped, losing content; paired with a landscape photo the row looks mismatched.
- Empty composer avatar = pink disc, empty. Category chips row starts with a single "Tất cả" plus "Thuê nhà/Cho thuê/BĐS…" — echoes the home grid, more red.
- Like count uses `HD.negative` ox-blood heart (post_card.dart:271) while brand red is `accent` — two different reds for the same "like" concept.

### Industrial listing (`block.png`) — `property_listing_screen.dart`
- **Empty thumbnails.** Both rows show a grey box + outline house icon (lines 176–180) because listings have no images. Reads as broken cards, not "photo pending."
- Serif-italic app bar title "BĐS công nghiệp" again.
- Card layout itself is clean (118px thumb, title, location, red price). The only problem is missing imagery + it stretches full width on desktop.

---

## 2. Prioritized findings

| # | Sev | Screen | Problem | Why it hurts intuitiveness | Concrete fix (file:line) |
|---|-----|--------|---------|----------------------------|--------------------------|
| 1 | CRITICAL | Home | Empty "Nhà nổi bật" shows bare "Không tìm thấy căn hộ phù hợp." | Primary content slot looks like an error → whole app reads broken | Replace bare `Text` with real empty-state widget (illo + title + CTA); AND ensure guest actually gets listings. `guest_home_screen.dart:494–500` |
| 2 | CRITICAL | Global palette | Red accent used as page background flood via `appGradient` (#F9C9CE→white) + pink tints everywhere | No neutral ground → hierarchy collapses, everything competes | Neutralize page bg to warm-white `#FAFAF8`; delete `HDGradientBackground` page-flood usage; red = accent only. `design_tokens.dart:17,60–65` |
| 3 | CRITICAL | Community | Junk/test images (app screenshot, cemetery photo) in live feed | Public content looks like a dev build | Purge seed posts (backend), gate feed to real content; add image moderation/placeholder. `social_feed_screen.dart` (data) |
| 4 | HIGH | All nested | Serif-*italic* Instrument Serif as screen/list titles | Slanted thin serif is hard to scan, looks decorative not structural | Default `DsAppBar.titleAsSerif=false` → `HD.bodyBold` sans. Reserve serif for logo + numerals. `ds_app_bar.dart:22,67` |
| 5 | HIGH | Desktop/web | No max-width; mobile column stretched on 1280px (onboarding dead space, lists edge-to-edge) | Looks unfinished; long line-lengths hurt reading | Add `HD.contentMaxWidth=1080`; wrap shell body + onboarding in `Center>ConstrainedBox`. Copy login's `maxWidth:440` pattern. `guest_shell.dart:219`, `onboarding_screen.dart:75` |
| 6 | HIGH | Home | Extended FAB overlaps promo banner text | Overlap = defect; obscures content | Add bottom sliver padding = FAB height+safe (`~96`); or dock FAB in nav. `guest_home_screen.dart:537–540` |
| 7 | HIGH | Home / Listing | Empty avatar circles + empty thumbnails render as grey/pink boxes | Reads as "broken image," not "no photo yet" | Branded placeholder: initials avatar; thumbnail = subtle neutral + centered muted icon + `label`. `guest_home_screen.dart:591–599`, `property_listing_screen.dart:176–180` |
| 8 | HIGH | Login | Newspaper metaphor + 6 demo-role login chips in prod | User can't tell what product does; test chips look unprofessional/insecure | Replace tagline w/ plain value prop ("Thuê & cho thuê nhà — nhanh, tin cậy"); gate demo chips behind debug flag. `login_screen.dart:255,270–271,148–208` |
| 9 | MEDIUM | Home | Redundant "Thuê nhà"+"Cho thuê" tiles → same rent list; grid duplicates bottom-nav purpose | Two navs + duplicate tiles = choice paralysis | Merge to one "Thuê nhà" entry or make "Cho thuê" the host post flow; clarify grid = categories, nav = sections. `home_services_section.dart:62–65` |
| 10 | MEDIUM | Home | Lone "Tất cả" category chip when categories empty | Filter with nothing to filter = stub | Hide pills row when `categories.isEmpty`. `guest_home_screen.dart:351–438` |
| 11 | MEDIUM | Community | 2-image grid force-squares tall infographics | Cropped/uneven, loses info | For 2 imgs use `aspect:4/3` row or preserve intrinsic ratio for single tall img. `post_card.dart:194–199` |
| 12 | MEDIUM | Community | Two different reds for "like" (`negative` vs brand `accent`) | Inconsistent semantic color | Use one `accent` red for like heart everywhere. `post_card.dart:271,297` |
| 13 | MEDIUM | Contrast | `accent` icon on `accentTint`/`accentSoft` discs ≈4.3:1; muted ink on pink gradient drops below AA | Low-contrast icons/labels | Icons on tinted discs → use `accentDeep` (#B91C1C); keep tint discs on white not on gradient. `home_services_section.dart:178–180` |
| 14 | LOW | Onboarding | Per-slide accent color flips red→green→red | Arbitrary color change reads as inconsistency | Single brand accent for all slides. `onboarding_screen.dart:42,50,56` |
| 15 | LOW | Search | Pink search field on pink page | Weak separation | Search field → white surface + neutral border. `guest_home_screen.dart:263–275` |

---

## 3. Root-cause deep dive on "không trực quan"

**A. Monotone red / hierarchy collapse (biggest cause).**
The recent palette overhaul made red both the *accent* and the *environment*: `paper` is pink (#FFF5F5), `appGradient` opens at a saturated #F9C9CE, tints (`accentTint` #FDEEEE, `accentSoft` #FCDCDC) fill search bars, service discs, shortcut cards, badges. When 60–70% of pixels are red-family, the eye has no anchor; primary actions (also red) don't pop, and text hierarchy flattens. WCAG: white-on-`accent` = 4.85:1 (passes AA normal, fails AAA and fails as *large-only* comfort); `inkMuted` #586574 passes on `paper` (5.28:1) but **drops under AA on the gradient's #F9C9CE band** and on `accentSoft`. Red icons on red tints (~4.3:1) are borderline. **Rule to adopt: red ≤ ~10% of any viewport; background must be neutral.**

**B. Empty/placeholder states = perceived breakage.**
Empty house grid (bare sentence), empty avatars (grey/stock disc), empty listing thumbnails (grey box + icon), 2-row leaderboard, junk feed images. Each individually minor; together the app looks like a broken shell. The system never distinguishes *loading* vs *empty-no-data* vs *empty-filtered*, and empty states carry no illustration/CTA.

**C. No web adaptation.**
Only `login_screen.dart` constrains width. `GuestShell` body, onboarding, all `HDGradientBackground` scaffolds render full-bleed. On desktop: onboarding is an island in a pink sea; lists have absurd line lengths; 2-col grid stretches. Instant "unfinished" read.

**D. Decorative serif as functional type.**
`HD.sectionTitle`/`DsAppBar` default to Instrument Serif *italic 400*. Beautiful for a masthead logo; wrong for scannable screen/list headers. Italic + serif + thin = slow to parse, especially with Vietnamese diacritics.

---

## 4. Improvement plan

### 4.1 Revised color system (red as accent, NOT environment)

```
// Neutral ground (replaces pink flood)
bg            #FAFAF8   page background (warm near-white)
surface       #FFFFFF   cards, sheets, fields
surfaceSunken #F3F2EF   nested/disabled
hairline      #E7E5E1   1px rules (neutral, not rose)
hairlineStrong#D6D3CE

// Ink (unchanged-ish, verified on #FAFAF8)
ink           #16181D   ~15:1
inkSoft       #454A54   ~8:1
inkMuted      #626873   ~5.2:1  (AA on bg AND on white)

// Accent — RED, used sparingly
accent        #DC2626   primary CTA, price, brand mark, active nav  (white text 4.85:1)
accentHover   #B91C1C   pressed/hover, icons-on-tint
accentSurface #FEF2F2   ONLY selected chip / focus halo (never full-page)

// Semantic (decouple from red)
success #15803D  successTint #E7F3EB
warning #B45309  warningTint #FBEFDD
danger  #B91C1C  dangerTint  #FBE9E7   (distinct from brand accent for destructive)
```

**Usage rules**
1. **Background is always neutral** (`bg`/`surface`). Kill `HDGradientBackground` as a full-page wrapper; if a warm accent header is wanted, confine it to the top ~120px of *login* only.
2. **≤ 1 primary red CTA per screen.** Everything else is neutral or outline.
3. Tinted discs/badges use `accentSurface` on **white** surfaces only; icon color = `accentHover` (#B91C1C) for contrast.
4. Semantic status never borrows brand red; destructive = `danger`.
5. Price/like/active-tab may use `accent` (brand touchpoints) — but sitting on neutral ground so they actually pop.

### 4.2 Typography rules
- **Serif (Instrument Serif): brand logo + big numerals ONLY.** Nothing else.
- **All titles / app bars / list headers / section titles: Be Vietnam Pro** — `w700` 18–22 for screen titles, `w600` for list rows.
- Drop italic for functional text (diacritic legibility).
- Eyebrow labels: keep `HD.eyebrow` (11px caps, tracked) but in `inkMuted`, not red, unless it labels a red section.
- Set `DsAppBar.titleAsSerif = false` by default.

### 4.3 Responsive / max-width strategy (web)
- Add token: `HD.contentMaxWidth = 1080` (feeds/lists), `HD.formMaxWidth = 440` (auth/forms), `HD.readingMaxWidth = 680` (article/detail).
- Wrap `GuestShell` body content in `Center > ConstrainedBox(maxWidth: contentMaxWidth)`.
- Responsive grids via existing breakpoints (`bpPhone 600 / bpTablet 900 / bpDesktop 1200`): property grid `crossAxisCount` = 2 / 3 / 4.
- Onboarding: desktop → 2-pane (art left, copy+controls right, max 960) or centered 480 card. Never full-bleed mobile column.

### 4.4 Empty-state patterns
Standardize one `DsEmptyState(icon/illustration, title, subtitle, primaryCta)` and three variants:
- **Loading** → skeletons (already exist for house cards; extend to lists/leaderboard).
- **Empty (no data yet)** → friendly illo + "Chưa có tin nào" + CTA ("Đăng tin đầu tiên").
- **Empty (filtered/search)** → "Không có kết quả cho '…'" + "Xoá bộ lọc" action.
Image placeholders: neutral #F3F2EF + centered muted icon + optional "Ảnh đang cập nhật" caption — never a bare grey box that mimics a load failure. Avatars: initials-on-tint, never stock stranger photo.

### 4.5 Phased rollout

**Phase 0 — Quick wins (hours, token/flag level)**
1. Swap page backgrounds neutral: change `HD.paper`→#FAFAF8, `hairline`→#E7E5E1; stop using `HDGradientBackground` on home/listing/leaderboard/community (keep on login only). (`design_tokens.dart`)
2. `DsAppBar.titleAsSerif=false` default. (`ds_app_bar.dart:22`)
3. Reserve FAB space: add bottom padding `~96` to home scroll content. (`guest_home_screen.dart:537`)
4. Hide category pills when empty; drop duplicate "Cho thuê" tile. (`guest_home_screen.dart:351`, `home_services_section.dart:64`)
5. Gate demo-login chips behind `kDebugMode`/feature flag. (`login_screen.dart:148`)
6. Purge junk seed posts (backend/data).

**Phase 1 — Empty states & placeholders (0.5–1 day)**
7. `DsEmptyState` widget + wire into home grid, listing `_empty`, leaderboard, feed.
8. Initials avatar + branded image placeholder; remove hardcoded stock avatar URL. (`guest_home_screen.dart:126,591`)
9. One red for like; icons-on-tint → `accentHover`.

**Phase 2 — Responsive (1–2 days)**
10. `contentMaxWidth` tokens + `GuestShell` centered container.
11. Responsive grid columns; onboarding 2-pane desktop.
12. Listing/feed centered max-width.

**Phase 3 — Structural (2–4 days)**
13. Resolve dual-navigation: define home services grid = *categories*, bottom nav = *sections*; relabel and de-duplicate destinations.
14. Rethink login brand story (drop newspaper metaphor or make it deliberate & explained).
15. Palette pass across all 76 screens against new usage rules; add dark-mode tokens.

---

## 5. High-value code snippets

**5.1 Neutral tokens (design_tokens.dart)**
```dart
static const Color paper       = Color(0xFFFAFAF8); // was #FFF5F5 pink
static const Color paperRaised = Color(0xFFFFFFFF);
static const Color paperSunken = Color(0xFFF3F2EF); // was #FCE9E9
static const Color hairline    = Color(0xFFE7E5E1); // was rose
static const Color inkMuted    = Color(0xFF626873); // AA on bg + white
// accent/accentDeep unchanged (#DC2626 / #B91C1C)
static const Color accentTint  = Color(0xFFFEF2F2); // selected/focus only
static const double contentMaxWidth = 1080;
static const double formMaxWidth = 440;
```
Then **stop wrapping pages** in `HDGradientBackground`; use `ColoredBox(color: HD.paper)`.

**5.2 Sans app-bar titles (ds_app_bar.dart:22)**
```dart
this.titleAsSerif = false, // default sans; opt into serif only for masthead
```

**5.3 Reusable empty state**
```dart
class DsEmptyState extends StatelessWidget {
  const DsEmptyState({super.key, required this.icon, required this.title,
    this.subtitle, this.cta});
  final IconData icon; final String title;
  final String? subtitle; final Widget? cta;
  @override
  Widget build(BuildContext c) => Center(
    child: Padding(padding: const EdgeInsets.all(HD.s32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(color: HD.paperSunken, shape: BoxShape.circle),
          child: Icon(icon, size: 34, color: HD.inkMuted)),
        const SizedBox(height: HD.s16),
        Text(title, style: HD.bodyBold(size: 16), textAlign: TextAlign.center),
        if (subtitle != null) ...[const SizedBox(height: HD.s4),
          Text(subtitle!, style: HD.body(color: HD.inkMuted), textAlign: TextAlign.center)],
        if (cta != null) ...[const SizedBox(height: HD.s20), cta!],
      ])));
}
```
Use at `guest_home_screen.dart:494`:
```dart
: houseProvider.houses.isEmpty
  ? DsEmptyState(
      icon: Icons.home_work_outlined,
      title: 'Chưa có tin phù hợp',
      subtitle: 'Thử bỏ bộ lọc hoặc mở rộng khu vực tìm kiếm.',
      cta: DsButton(label: 'Xoá bộ lọc', variant: DsButtonVariant.secondary,
        onPressed: houseProvider.clearFilters))
```

**5.4 Centered web content (guest_shell.dart body)**
```dart
Expanded(
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: HD.contentMaxWidth),
      child: AnimatedSwitcher(/* ...existing... */),
    ),
  ),
),
```

**5.5 FAB clearance (guest_home_screen.dart, end of scroll column)**
```dart
_buildPromoBanner(context),
const SizedBox(height: 96), // clear the extended FAB
```

**5.6 Responsive property grid**
```dart
int cols(double w) => w >= HD.bpDesktop ? 4 : w >= HD.bpTablet ? 3 : 2;
// gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//   crossAxisCount: cols(MediaQuery.sizeOf(context).width), ...)
```

---

## Unresolved questions
1. Is the empty guest house grid a *data/API* issue (guest not fetching listings) or genuinely no inventory? Fix #1 differs (backend vs UI). Needs confirmation.
2. Is the newspaper/"Nhật báo" masthead an intentional brand direction to preserve, or legacy? Determines whether to reskin or remove.
3. Are the 6 demo-login chips required for reviewer/QA access in this environment? If yes, gate by env not remove.
4. Community junk images — is there a seed-data reset for prod, or is moderation the intended control?
5. Dark mode planned (tokens hint at `HDDark`)? Palette rework should land with dark variants if so.
