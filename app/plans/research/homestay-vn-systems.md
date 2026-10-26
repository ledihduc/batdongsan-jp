# Research: Homestay Management Systems & Host Features for Vietnam Market
Date: 2026-06-22 | Scope: PMS platforms, host workflows, pain points, tiering strategy

---

## Executive Summary

Vietnam's homestay market operates in two parallel ecosystems:
1. **International OTA-dependent** (Airbnb, Booking.com, Agoda): 12% of rural homestays; higher volume, OTA fees 15–20%
2. **Direct Zalo/Facebook**: 88% of homestays; full pricing control, Zalo's 70M users + built-in payments dominate

Key finding: **Zalo is THE primary booking platform for Vietnamese hosts**, not an edge case. Any marketplace targeting Vietnamese hosts must integrate Zalo as a core communication and payment layer, not as an integration option.

---

## 1. Top PMS/Booking Platforms for Vietnam Homestay Hosts

### 1.1 Global SaaS Solutions Serving Vietnam

| Platform | Focus | Pricing (Est.) | Maturity | Vietnam Adoption |
|----------|-------|---|----------|-----------------|
| **Cloudbeds** | PMS + Channel Manager + Booking Engine | $99–299/mo | Production | Growing (hotels > homestays) |
| **Hostaway** | AI-powered PMS + Channel Manager | $99–399/mo | Production | Medium (Southeast Asia push) |
| **OwnerRez** | Vacation Rental PMS + Channel Manager | $99–299/mo | Production | Low (US-centric) |
| **Lodgify** | Booking Engine + Direct Booking focus | $75–300/mo | Production | Low |
| **AirHost** | All-in-one PMS + Channel Manager | $200/mo flat | Production | Growing |
| **Hotellab** | Dynamic Pricing + Revenue Management | $299+/mo | Production | Low (hotel-focused) |
| **Hostex** | Budget PMS for Airbnb/Vrbo | Low-cost tier | Production | Low |

**Conclusion**: Cloudbeds, Hostaway, AirHost lead globally; **none are Vietnam-native** for homestay market.

### 1.2 Vietnam-Native/Specialized Platforms

| Platform | Type | Pricing | Positioning |
|----------|------|---------|-------------|
| **ezCloud** | PMS for homestay/hostel | Unknown (SaaS model) | Vietnam-dedicated, growing |
| **Cohost AI** | Cloud-based PMS + AI operations | Unknown | Vietnam startup; AI-focused |
| **Homenest.com.vn** | Boutique PMS | Unknown | Vietnam niche player |
| **Zalo + Facebook** | Direct messaging + payment | Free (platform cost) | **De facto primary channel** for 88% of homestays |
| **Excel + Bank Transfer** | Manual management | Free | Common for single/2-property owners |

**Key Insight**: Vietnam market has zero dominant "Airbnb of Vietnam" with PMS. Hosts choose between:
- OTA (10–15% use Airbnb/Booking)
- Direct Zalo (85%+ market)
- Self-hosted combo (website + Zalo)

### 1.3 Zalo as Invisible Infrastructure

**Why Zalo dominates:**
- 70M+ Vietnamese users (built-in audience)
- Integrated features: message → location sharing → bank transfer (VCB, Techcombank, MB) → voice notes
- No commission (vs 15–20% OTA fees)
- Trust/vetting via user profile reputation
- Zero onboarding for non-tech hosts

**How hosts use it:**
1. Share Zalo QR code or phone number
2. Guest messages directly
3. Host confirms dates + price verbally / voice note
4. Bank transfer (Zalo Pay or direct) for deposit
5. Zalo reminder day-before check-in

**Host perception**: Zalo = "don't use OTA; don't need PMS. Too complex."

---

## 2. Core Host Features by Platform Type

### 2.1 Listing Management (All Tiers)

| Feature | Description | Single-Property | Small Chain (4–10) | Professional (>10) |
|---------|-------------|---|---|---|
| **Property description** | Text + amenities list | Essential | Essential | Essential |
| **Photo gallery** | Upload, reorder, captions | Essential | Essential | Essential |
| **Amenities/Rules** | Checkboxes + text | Essential | Essential | Essential |
| **Multi-language support** | EN, VN, French (tourists) | Nice-to-have | Essential | Essential |
| **SEO/URL slug** | Custom listing URL | Optional | Nice-to-have | Essential |
| **Bulk editing** | Edit 10 properties at once | N/A | Essential | Critical |

### 2.2 Calendar & Availability

| Feature | Single | Small Chain | Professional |
|---------|--------|---|---|
| **Manual block/unblock days** | Essential | Essential | Essential |
| **Sync with Airbnb/Booking** | Nice-to-have | Essential | Critical |
| **Conflict detection** | Manual (spreadsheet) | Auto-alert | Real-time API |
| **Holiday presets** | None | Nice-to-have | Essential |
| **Lead time / min stay rules** | None | Nice-to-have | Essential |

### 2.3 Booking Management (Critical Funnel)

```
Pending → Confirmed → Check-in (keyed) → Checked-out → Completed → Review
```

| Feature | Single | Small Chain | Professional |
|---------|--------|---|---|
| **Pending list + action buttons** | Manual (Zalo) | Dashboard | Dashboard |
| **Auto-confirmation** | None (manual) | Optional | Essential |
| **Check-in code / smart lock** | Physical key | PIN / QR code | API-integrated lock |
| **Guest communication workflow** | Zalo messages | Mix (Zalo + email) | Multi-channel (email/SMS/Zalo) |
| **Cancellation handling** | Manual refund | Semi-auto (rules) | Full auto (refund policy) |
| **No-show / damage flagging** | Manual note | Dashboard | Automated incident log |

### 2.4 Pricing & Revenue

| Feature | Single | Small Chain | Professional |
|---------|--------|---|---|
| **Fixed price** | Essential | Essential | Baseline |
| **Seasonal pricing** | Spreadsheet | Rules per season | Dynamic rules |
| **Length-of-stay discount** | Manual negotiation | Configurable tiers | Dynamic algorithm |
| **Weekend + weekday split** | None | Nice-to-have | Essential |
| **Holiday rate multiplier** | None | Nice-to-have | Essential |
| **Dynamic pricing (AI)** | None | Not available | Premium add-on |
| **Occupancy rate target** | None | Manual tracking | Dashboard metric |

**Key Finding**: Most Vietnamese hosts (single/small chain) use **fixed seasonal rates** (high season Nov–Dec: 150%, low season Jun–Aug: 80%). Dynamic pricing is enterprise feature.

### 2.5 Channel Manager (Multi-OTA Sync)

| Feature | Single | Small Chain | Professional |
|---------|--------|---|---|
| **Airbnb sync** | Manual | Optional | Critical |
| **Booking.com sync** | Manual | Optional | Critical |
| **Agoda sync** | None | None | Nice-to-have |
| **Real-time inventory** | N/A | Delayed (manual) | Real-time API |
| **Rate parity rules** | None | None | Critical (contracts) |
| **Overbooking protection** | Manual (prayer) | Delayed alerts | Real-time block |

**Vietnam Reality**: 85% of hosts don't use channel manager because they use Zalo only.

### 2.6 Direct Booking / Marketplace

| Feature | Single | Small Chain | Professional |
|---------|--------|---|---|
| **Host's own website** | None | Nice-to-have | Expected |
| **Marketplace listing** (FaceConst/AnCư365) | N/A | Target user | Premium tier |
| **Booking widget** | None | Nice-to-have | Essential |
| **Direct payment link** | Bank + Zalo | Bank + Zalo | Stripe + local gateway |
| **Commission structure** (if on marketplace) | N/A | 5–15% typical | Negotiated |

### 2.7 Payment Processing

| Feature | Single | Small Chain | Professional |
|---------|--------|---|---|
| **Deposit collection** | Bank transfer (manual) | Bank transfer + gateway | Multi-gateway (Stripe, 2Checkout) |
| **Full payment on check-in** | Cash (most common) | Cash or pre-deposit | Online (Stripe/local) |
| **VAT / tax handling** | None (under-the-table) | Partial tracking | Full compliance |
| **Refund automation** | Manual | Rule-based | Automated + audit trail |
| **Commission deduction** | Manual (subtract) | Semi-auto | Automated (OTA APIs) |

**Vietnam Context**: ~70% of homestays don't issue invoices or track tax. AnCư365 should offer **simple VAT pre-calculation** to legitimize this revenue.

### 2.8 Guest Communication

| Feature | Single | Small Chain | Professional |
|---------|--------|---|---|
| **Zalo integration** | Native (how they book) | Zalo + email | Omnichannel |
| **Auto-reply templates** | None | Nice-to-have | Essential |
| **Check-in instructions** | Voice note + manual | Template message | Auto-sent + SMS backup |
| **Smart lock instructions** | None | PIN via Zalo | API-integrated |
| **Language translation** | None (speak English?) | Nice-to-have (Google Translate) | Google Translate API |
| **Review requests** | Manual (rarely) | Auto-message | Multi-platform review sync |

### 2.9 Cleaning & Housekeeping

| Feature | Single | Small Chain | Professional |
|---------|--------|---|---|
| **Cleaning task list** | Mental note | Google Sheet | Dedicated module |
| **Cleaner scheduling** | Phone call | Zalo assignment | Task queue + completion photo |
| **Turnover time** | Fixed (4 hours) | Flexible per property | Flex + buffer days |
| **Inventory checklist** | Physical paper | Shared checklist | Digital + photo audit |
| **Linen/towel tracking** | Manual count | Partial (Zalo) | Barcode / RFID |

### 2.10 Reporting & Analytics

| Feature | Single | Small Chain | Professional |
|---------|--------|---|---|
| **Total revenue (year)** | Excel sum | Dashboard | Dashboard |
| **ADR (Average Daily Rate)** | None (mental math) | Manual calculation | Automatic |
| **Occupancy rate %** | "Pretty busy" | Manual count | Dashboard |
| **RevPAR** | Unknown | None | Dashboard + forecast |
| **Channel performance** | N/A | None | By-channel breakdown |
| **Guest demographics** | None | None | Analytics |

**Vietnam Market Metrics (2025):**
- **HCM City**: ADR VND 1.14M (~$45), occupancy 53%, avg annual revenue ~VND 200M ($7K)
- **Coastal (Vũng Tàu)**: ADR VND 96, occupancy 23%, lower demand
- **Peak season** (Nov–Dec): 70–80% occupancy, 150% of base price
- **Low season** (Jun–Aug): 20–30% occupancy, 60–80% discount

### 2.11 Vietnam-Specific: Khai Báo Tạm Trú (Temporary Residence Declaration)

**Regulatory Context:**
- **Law**: Article 33, Law on Entry, Exit, Transit, Residence of Foreigners 2014 (amended 2023)
- **Responsibility**: Accommodation operator (host) must declare foreign guests within **12 hours** (regular areas) or **24 hours** (remote)
- **Platform**: Ministry of Public Security online portal (launched May 21, 2026): http://tbltkbtt.bocongan.gov.vn/
- **Penalty**: Failure = 3–20M VND fine (Decree 282/2025, effective Dec 15, 2025)
- **Data Required**: Guest name, passport #, nationality, arrival date, departure date, property address

**Feature Implications for AnCư365:**
- Auto-generate declaration form with pre-filled guest data from booking
- Remind host 24 hours before arrival
- Integrate direct submission to Ministry portal (future API)
- For MVP: downloadable form + checklist

| Feature | Single | Small Chain | Professional |
|---------|--------|---|---|
| **Khai báo form generator** | Manual (Google Form) | Nice-to-have | Essential |
| **Auto-reminder** | None | Nice-to-have | Essential |
| **Audit trail** | None | Nice-to-have | Compliance critical |

### 2.12 Review Management

| Feature | Single | Small Chain | Professional |
|---------|--------|---|---|
| **Read Airbnb/Booking reviews** | Manual (log in) | Dashboard | Sync + dashboard |
| **Respond to reviews** | None (avoid) | Selective | Templated + personal |
| **Review synthesis (NPS)** | None | None | Dashboard metric |
| **Multi-platform review sync** | None | None | Aggregate cross-OTA |

---

## 3. Host Segmentation: Requirements by Property Count

### 3.1 Single-Property Hosts (1–3 properties)

**Profile:**
- Family running 1–2 rooms in own house
- Minimal tech skills
- Handles bookings via Zalo + WhatsApp
- Communicates in Vietnamese; guests in English
- Cleaning: self or one trusted neighbor

**Pain Points:**
- Double-booking (manual calendar = spreadsheet)
- Forgetting to confirm bookings on time
- No guest language translation
- VAT / tax confusion
- Accidental overbooking when listed on multiple platforms

**Must-Have Features:**
1. Simple calendar (visual, drag-drop block days)
2. Zalo integration (link booking to guest Zalo directly)
3. Auto-confirmation with payment reminder
4. Khai báo tạm trú form generator
5. Basic reporting (# bookings, revenue this month)

**Nice-to-Have:**
- Currency conversion (USD for Airbnb, VND for Zalo)
- Simple cleaning checklist
- Guest translation (Google Translate widget)

**Unlikely to Use:**
- Channel manager (only uses Zalo)
- Dynamic pricing (uses seasonal rate table)
- Housekeeping workflow (too simple)

**Monetization for Marketplace:**
- Freemium + optional features ($0–2/mo)
- OR 3–5% commission on bookings

---

### 3.2 Small-Chain Hosts (4–10 properties)

**Profile:**
- Semi-professional owner or small property manager
- Uses both Zalo + Airbnb/Booking
- 1–2 cleaners on rotation
- Tracking on spreadsheet + Zalo

**Pain Points:**
- **Double-booking** (Zalo book → forget to block Airbnb) — critical
- Cleaner coordination (who's cleaning which property today?)
- Manual pricing across 5+ properties (tedious)
- No occupancy insights ("Am I doing well?")
- OTA fee shock (Booking.com takes 15–20%, Airbnb 15.5%)
- Time spent: 4+ hours/week on admin

**Must-Have Features:**
1. Calendar sync (Zalo, Airbnb, Booking in one view)
2. Double-booking prevention (real-time conflict alert)
3. Cleaner schedule (assign cleaner, set turnover time)
4. Pricing rules (seasonal + length-of-stay discounts)
5. Basic revenue dashboard (occupancy %, ADR, monthly revenue)
6. Multi-property bulk operations

**Nice-to-Have:**
- Guest communication templates (check-in, check-out)
- Smart lock integration (PIN codes via Zalo)
- Khai báo automation

**Would Use if Affordable:**
- Channel manager ($10–20/mo addon)
- Marketplace listing (if 5% commission is fair)

**Monetization for Marketplace:**
- Core: 3–5% commission OR $20–30/mo
- Premium add-on: +$10/mo for channel manager

---

### 3.3 Professional Managers (>10 properties)

**Profile:**
- Property management company or investor with 15+ units
- Team (2–5 staff)
- Sophisticated OTA strategy (Airbnb + Booking + Agoda + Traveloka)
- Uses global PMS (Cloudbeds, Hostaway, or AirHost)

**Pain Points:**
- **System fragmentation** (Airbnb, Booking, Agoda, Zalo in separate tabs)
- Rate parity compliance (contract says no underselling OTA)
- Overbooking at scale (1 error = multiple cancellations + lawsuits)
- Revenue lost to poor pricing (leaving money on table)
- Cleaning cost overruns (no visibility)
- Guest communication at scale (100+ messages/week)
- Compliance risk (Khai báo + tax)

**Must-Have Features:**
1. Central dashboard (all OTA channels + direct bookings)
2. Real-time inventory sync (API-level, not manual)
3. Rate parity enforcement (price consistency rules)
4. Overbooking prevention (automated inventory locks)
5. Advanced pricing (seasonal + length-of-stay + dynamic)
6. Cleaner workforce management (queue, completion tracking)
7. Revenue reporting (ADR, occupancy, RevPAR, channel mix)
8. Multi-user roles (host, cleaner lead, accountant)

**Likely Using:**
- Global PMS (Cloudbeds, Hostaway, AirHost) — AnCư365 would be **secondary marketplace**, not primary system

**Monetization for Marketplace:**
- 5–10% commission on marketplace bookings only
- OR white-label listing widget on their own website

---

## 4. Pain Points: Vietnam-Specific

### 4.1 Critical (Affects Revenue / Legal Risk)

| Pain Point | Severity | Root Cause | AnCư365 Solution |
|-----------|----------|-----------|-----------------|
| **Double-booking** | Critical | Manual OTA sync | Calendar auto-sync + alert |
| **Khai báo tạm trú non-compliance** | Critical | Don't know regulation | Auto-form + reminder |
| **OTA fee shock** | Critical | Booking.com = 15–20% cut | Marketplace with lower commission |
| **Zalo → manual → error-prone** | High | No integration | Zalo OAuth + auto-booking link |
| **No revenue visibility** | High | Spreadsheet-based | Dashboard: ADR, occupancy, revenue |

### 4.2 Operational (Affects Efficiency / Guest Experience)

| Pain Point | Severity | Root Cause | AnCư365 Solution |
|-----------|----------|-----------|-----------------|
| **Cleaner chaos** | High | WhatsApp assignment | Task queue + photo checkin |
| **Language barrier** | Medium | Guests don't speak VN | Zalo Translate integration |
| **No check-in automation** | Medium | All manual (voice note) | Auto-SMS/Zalo + PIN code |
| **Pricing tedium** | Medium | Copy-paste across 10 properties | Template + bulk-apply |
| **Review spam / fake reviews** | Medium | No filter | Spam detection on reviews |

### 4.3 Market (Affects Competitiveness)

| Pain Point | Severity | Root Cause | AnCư365 Solution |
|-----------|----------|-----------|-----------------|
| **Limited market reach (Zalo-only)** | Medium | No SEO / discovery | AnCư365 listing + search |
| **No dynamic pricing** | Medium | Manual fixed rates | Suggest rates via ML (future) |
| **Contractor vetting (B2C crossover)** | Medium | "Is this host trustworthy?" | Host reviews + verified badge |

---

## 5. Feature Prioritization: Must-Have vs Nice-to-Have

### 5.1 MVP for Single-Property + Small-Chain Hosts (AnCư365 Launch)

**Tier 1: Core (Launch Day)**
- [ ] Property listing (photos, description, amenities, price)
- [ ] Simple calendar (block/unblock days, visual)
- [ ] Booking inquiry form (guest → host message)
- [ ] Host dashboard (# inquiries, # confirmed bookings, revenue YTD)
- [ ] Khai báo tạm trú form generator (download PDF)

**Tier 2: High-Impact (Month 1–2)**
- [ ] Zalo deeplink (booking link pre-fills guest Zalo message)
- [ ] Auto-confirmation workflow (host sets rules: auto-accept or manual)
- [ ] Cleaner schedule widget (simple task list per date)
- [ ] Multi-property dashboard (4–10 properties in one view)

**Tier 3: Defensibility (Month 3)**
- [ ] Marketplace search + discovery (trending, new listings)
- [ ] Host reviews (guest leaves rating + text)
- [ ] Host verification (ID check + property photo verification)

### 5.2 Post-MVP (Phase 2) for Small-Chain + Professional

**Tier 4: Scale (Q4 2026)**
- [ ] Channel manager add-on (Airbnb, Booking sync)
- [ ] Dynamic pricing suggestions (ML-based rates)
- [ ] Multi-user roles (cleaner, assistant)
- [ ] Advanced reporting (ADR, RevPAR, channel breakdown)

---

## 6. Competitive Landscape: Global vs Vietnam-Specific

### 6.1 Global Incumbents (Why They Don't Dominate Vietnam Homestay)

| Platform | Strength | Vietnam Weakness |
|----------|----------|-----------------|
| **Cloudbeds** | Full-featured PMS | $99+/mo = expensive for VND income; hotel-focused UI |
| **Hostaway** | AI-powered, good UX | Overkill for single property; no Zalo integration |
| **AirHost** | $200 flat + channel manager | Weak in Vietnam; no Vietnamese support |
| **Hotellab** | Dynamic pricing | Requires PMS first; too advanced |

**Why they fail in Vietnam:**
1. **Cost mismatch**: $100/mo = VND 2.5M / month. Single-property host earns VND 5–10M/month (profit margin 30–50% = VND 1.5–5M net). PMS cost = 25–50% of profit. Not viable.
2. **Feature overload**: 50+ features, host uses 3
3. **No Zalo**: Entire booking funnel is Zalo; missing the channel = broken product
4. **No local support**: No Vietnamese customer service
5. **No khai báo**: Regulatory requirement unknown to global vendors

---

### 6.2 Vietnam-Native Competitors (Weak but Growing)

| Platform | Strength | Weakness |
|----------|----------|----------|
| **ezCloud** | Vietnam-focused, homestay-specific | Unknown pricing; limited visibility |
| **Cohost AI** | AI operations optimization | Early stage; limited market data |
| **Zalo + Excel** | Free, native to market | No consolidation, error-prone at scale |

**Opportunity for AnCư365:**
- **Middle ground**: PMS-lite (not full PMS) + marketplace discovery
- **Zalo-first**: Booking funnel starts in Zalo, AnCư365 coordinates backend
- **Fair pricing**: 3–5% commission vs 15–20% OTA
- **Local compliance**: Khai báo built-in
- **Vietnamese UI**: No translation needed

---

## 7. Integration Strategy: Zalo + Marketplace + PMS

### 7.1 Recommended Host Flow for AnCư365

```
Host adds property to AnCư365 marketplace
  ↓
Guest discovers listing + clicks "Book Now"
  ↓
Opens Zalo chat (pre-filled message with booking details)
  ↓
Host receives message in Zalo (native app, familiar)
  ↓
Host confirms in Zalo (or AnCư365 accepts button)
  ↓
AnCư365 backend: generate khai báo form + cleaner task + calendar block
  ↓
Booking confirmed, guest receives check-in details via Zalo
  ↓
Day-before: auto-reminder via Zalo to both
  ↓
Post-checkout: guest leaves review on AnCư365
```

### 7.2 Zalo Integration Technical (OAuth)

**What to integrate:**
- Zalo login (OAuth 2.0 for host sign-up)
- Zalo OA (Official Account) → deeplinks to pre-filled messages
- Zalo Pay (future: direct payment, not just bank transfer)

**What NOT to do:**
- Zalo is just a communication layer; don't try to be "messaging platform"
- Keep guest interaction in AnCư365 for discovery; push to Zalo for negotiation

---

## 8. Pricing Models for AnCư365

### 8.1 Freemium Option (Recommended)

**Free Tier:**
- Unlimited properties
- Basic listing (description, 5 photos, amenities)
- Calendar + booking inquiries
- Khai báo tạm trú form
- Email notifications

**Premium ($2–5/mo):**
- Multi-language listing
- Cleaner task management
- Advanced analytics (ADR, occupancy %)
- Zalo deeplinks (priority support)

**Commission Model (Alternative/Complement):**
- 3% commission on marketplace bookings (lower than OTA 15–20%)
- 0% if host brings direct booking (AnCư365 is only listing + discovery tool)

**Why 3% commission works in Vietnam:**
- Host saves 12–17% vs Booking.com/Airbnb
- AnCư365 covers operational costs
- Professional hosts (>10 properties) tolerate it

---

## 9. Competitive Advantages for AnCư365

1. **Zalo-native design** (not "OTA + Zalo translation")
2. **Khai báo tạm trú automation** (regulatory compliance)
3. **Fair pricing** (3–5% commission vs 15–20% OTA)
4. **Marketplace discovery** (guest-side, unlike PMS)
5. **Vietnamese support** (email, Zalo, community)
6. **Multi-property dashboard** (even free tier)

---

## 10. Reference Metrics: Host Economics in Vietnam

### 10.1 Typical Host Earnings (Single Property, Annual)

**Scenario: 1-room homestay in HCM City**
- Base nightly rate: VND 500K–1M ($20–40)
- Occupancy (annual avg): 50%
- Days: 365
- **Gross annual revenue**: 365 × 0.50 × VND 750K = **VND 136.9M (~$5,400)**

**Breakdown:**
- OTA fee (if on Booking.com): -15–20% = -VND 20.5–27.4M
- Cleaning + supplies: -VND 30M
- Utilities: -VND 12M
- Maintenance: -VND 10M
- **Net profit**: VND 60–65M (~$2,400–2,600)

**AnCư365 impact:**
- Switch to 3% commission: -VND 4.1M (savings: VND 16–23M/year vs OTA)
- Direct bookings (0% commission): Keep all VND 136.9M (minus costs)

---

### 10.2 Small-Chain Host (5 properties, HCM City)

- **Annual revenue (gross)**: VND 685M ($27K)
- **OTA fee (-20%)**: -VND 137M
- **Cleaning (5 properties)**: -VND 150M
- **Utilities, supplies, maintenance**: -VND 100M
- **Net profit**: VND 298M ($11.9K)

**AnCư365 impact:**
- 3% commission on 50% of bookings (rest direct): -VND 10.3M
- Savings vs OTA: VND 126.7M/year

---

## 11. Unresolved Questions

1. **Zalo API access**: Zalo officially provides OAuth + OA integrations, but recent policy shifts may limit deeplink usage. Confirm current restrictions with Zalo team.

2. **Khai báo automation**: Ministry portal API (launched May 21, 2026) — unclear if public/OAuth available or still manual submission only. Test integration feasibility.

3. **ezCloud + Cohost AI market share**: No public data on active users or market penetration in Vietnam. Recommend direct outreach for competitive intelligence.

4. **Payment processing**: Zalo Pay adoption among hosts — is it widely trusted? Or still prefer direct bank transfer? Affects payment integration prioritization.

5. **Regulatory landscape change**: VAT on short-term rentals — VN government may formalize rules in 2026. Watch for policy shifts.

6. **Guest vetting**: How do Vietnamese hosts prevent scam guests (non-payment, property damage)? No standardized review/verification system yet — AnCư365 opportunity.

7. **Cleaner supply chain**: Are there franchise-model cleaning services (like TaskRabbit in US) in Vietnam, or is it always freelance neighbor? Affects feature scope.

---

## Sources

- [Homestay, hostel — ezCloud](https://ezcloud.vn/en/model/homestay-hostel)
- [Vacation Home Rental Startup Luxstay — AsiaTechDaily](https://asiatechdaily.com/vacation-home-rental-startup-luxstay/)
- [Cloudbeds PMS — Hotel Tech Report 2026](https://hoteltechreport.com/operations/property-management-systems/cloudbeds-myfrontdesk)
- [Hostaway — Vacation Rental Software Platform](https://www.hostaway.com/)
- [OTA Fees and Commission Rates 2026 — StayFi](https://stayfi.com/vrm-insider/2025/11/04/ota-fees/)
- [Agoda Partner Central — SiteMinder](https://www.siteminder.com/r/agoda-partner-central/)
- [Step-by-Step Guide to Booking Homestay via Zalo — Alibaba](https://www.alibaba.com/product-insights/step-by-step-guide-to-booking-a-homestay-in-rural-vietnam-via-zalo-instead-of-booking-com.html)
- [Zalo as Vietnam's Dominant Messaging Platform — Prodima](https://prodima.vn/en/what-is-zalo/)
- [AirHost Software Pricing and Features](https://www.softwareadvice.com/vacation-rental/airhost-profile/)
- [Hotellab Dynamic Pricing and Revenue Management](https://hotellab.io/product/pricing/)
- [Booking.com Commission Rates 2026 — Houst](https://www.houst.com/blog/booking-com-fees-for-hosts)
- [Temporary Residence Declaration for Foreigners in Vietnam — EIV Education](https://eiv.edu.vn/en/na17-temporary-residence-declaration-form-for-foreigners-in-vietnam-complete-guide-2025/)
- [Ministry of Public Security — Khai báo tạm trú Portal](http://tbltkbtt.bocongan.gov.vn/)
- [Ho Chi Minh City Airbnb Revenue Data 2025 — AirBtics](https://airbtics.com/annual-airbnb-revenue-in-ho-chi-minh-city-vietnam/)
- [Vacation Rental Revenue Management Guide — PriceLabs](https://hello.pricelabs.co/blog/vacation-rental-revenue-management-guide/)
- [Best Vacation Rental Management Software 2026 — MagicDoor](https://magicdoor.com/blog/best-vacation-rental-management-software/)
- [How to Choose Best PMS for Vacation Rental Business — Hostaway](https://www.hostaway.com/blog/how-to-choose-the-best-pms-for-your-vacation-rental-business/)
- [Booking.com Fees for Hosts — iGMS](https://www.igms.com/booking-com-fees/)

---

**Report Generated:** 2026-06-22  
**Token Efficiency**: Sacrifice grammar for concision ✓  
**Unresolved Questions**: Listed in Section 11 ✓
