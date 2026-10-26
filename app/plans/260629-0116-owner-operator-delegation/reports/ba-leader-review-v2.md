# BA Leader Review v2 — Owner-Operator Delegation
**Reviewer:** BA Leader (independent second pass)
**Date:** 2026-06-29
**Doc reviewed:** phase-00-ba-requirements.md (v2, 569 lines)
**Verdict:** NEEDS_REVISION
**Confidence:** high

---

## 1. Verdict summary

- **Core strength:** §3 architecture trade-off (Model A vs B) is decisive and YAGNI-correct; AC matrix is unusually concrete for a BA doc (56 numbered ACs with test hooks). v1 review *did* genuinely tighten the doc — most CRITICAL fixes are real, not cosmetic.
- **Biggest remaining risk:** Doc still smuggles **technical design** into BA artifact (request-scoped headers, partial unique indexes, scope_hash, partition strategy, JWT caching). Tech Lead's freedom of action constrained without justification.
- **Critical gap:** **TL;DR claims 3h SLA for KB04, AC-55 also says 3h, §4 terminology table says 6h, §12 changelog C1 fix says "6h" — three numbers, one fact.** Same drift on "12h Luật Cư trú" — research 03 §2.1 actually says 12h is *tenant move-in declaration deadline*, not *operator approval deadline*. Re-read carefully: 12h is when tenant must be registered, not when owner must approve. Conflating these = legal AC built on misreading.
- **Owner-death/incapacity scenario completely missing** — for absentee owner segment (group C ~20%, high net worth), this is the #1 inheritance/dispute generator and not addressed anywhere. v1 review missed it too.
- **AC-43 "lockdown" creates a 30-day operational paralysis** that makes the feature unusable in any real conflict — operator can't terminate a fraudulent tenant during the very window when fraud is being investigated. Logic-inverted.

**Recommendation:** Fix the 6 CRITICAL items below; doc is otherwise close to READY. Estimate 2–4 hours of BA revision.

---

## 2. Findings by severity

### CRITICAL (must fix before Phase 3)

**C1. [Numeric inconsistency] [TL;DR / §4 / AC-55 / §12 C1]** KB04 SLA stated as **3h** in TL;DR + AC-55, **6h** in §4 terminology and §12 changelog C1. v1 review explicitly says "Added AC-55 fast-track 6h" — but the AC body now reads 3h. Either v2 silently changed 6→3 without updating §12, or §4/§12 weren't updated when AC was tightened.
- Why it matters: Tech Lead will pick one arbitrarily; operations team will SLA against another; legal review will quote a third. Single source-of-truth required.
- Fix: Pick one number, justify against research 03 §2.1 (12h tenant deadline minus realistic operator processing buffer), update all 4 locations.

**C2. [Legal misreading] [§1.2 TL;DR / AC-55 / §10.6]** "Luật Cư trú yêu cầu submit trong **12h** — conflict với 72h approval." This is a misreading of research 03 §2.1. The 12h deadline applies to **tenant residency registration** (after tenant moves in); it does NOT mean owner approval must happen within 12h. Operator can pre-emptively file KB04 the moment lease is signed (before tenant moves in) — no approval race needed. The "conflict" the BA invented may not exist.
- Why it matters: If research 03 is right, fast-track carve-out (AC-55) may be over-engineered. If BA is right, research 03 is mis-summarized. Either way, the doc is internally incoherent on its single most-cited legal fact.
- Fix: Re-read research 03 §2.1–2.3 with legal counsel; document timeline precisely (move-in trigger T0 → tenant must be registered by T0+12h → who must do what by when). If fast-track survives this, justify the 3/6h number from this timeline, not from "12h deadline".

**C3. [Missing critical edge case] [§5 / §6 / §10.6]** Owner death / loss of mental capacity is not addressed anywhere. For segment C (absentee owners, often 50–70 y/o investors), this is statistically certain over a 6-month window with 100+ delegations. Questions left unanswered: does delegation auto-pause? Who handles in-flight approvals? Heir authentication? Estate executor onboarding? Tax authority frozen-account scenario?
- Why it matters: Reputation-destroying class of failure; "platform took rent after our father died" is a press story.
- Fix: Add at minimum 1 user story (US-O18 Heir/Estate), 2 ACs (auto-pause on death certificate upload + admin escalation path; in-flight transaction handling), 1 open question (Q9: legal channel for receiving death notice — heir self-attestation vs notarized).

**C4. [Logic inversion] [AC-43]** "Trong 30 ngày: ALL operator mutations ≥ 0 VND require owner approval; refunds + contract terminations: BLOCKED hoàn toàn." This means an operator who suspects tenant fraud cannot terminate a contract during the 30-day notice window — exactly the window when termination would be needed. Also breaks AC-27 (operator can request approval for early termination) and US-O11 (graceful 30-day wind-down).
- Why it matters: Makes the feature unusable in the conflict scenarios that motivated termination in the first place. Operator + owner both blocked from acting; tenant in legal limbo.
- Fix: Re-state: "Lockdown applies only to NEW commitments (new contracts, new tenant onboarding, raising thresholds). Operator may still complete in-flight invoices, terminate fraud-suspected contracts with mandatory owner approval, and continue maintenance. Owner can override block per-action."

**C5. [Audit retention vs PDPL contradiction] [§10.5 / §10.6]** "Retention: 7 năm online (legal accounting req VN), sau đó cold storage" but PDPL Decree 13/2023 §3.4 (research 03 §3.4) requires "storage period must be no longer than necessary." 7-year blanket retention of CCCD/financial PII conflicts with PDPL minimization principle. Tax-record retention applies to financial records, not to all audit fields.
- Why it matters: PDPL breach exposure; regulator could mandate data deletion the platform isn't designed to support.
- Fix: Tier retention by data category: (a) financial transactions 10y per accounting law, (b) audit metadata 7y, (c) PII-rich payloads (CCCD numbers, addresses, photos) 12–24 months post-relationship-end then redacted, (d) operational logs 90d. Document deletion mechanism (right-to-be-forgotten request handling).

**C6. [Hidden scope creep — design baked into BA] [§3 / §10.1 / §10.2 / §10.5]** BA doc commits Tech Lead to: (a) partition `audit_logs` monthly from day 1 (§10.5), (b) partial unique constraint syntax (AC-08), (c) `scope_hash` SHA-256 mechanism (§4), (d) `X-Acting-As` HTTP header (§10.2 / AC-15), (e) "no JWT caching" (AC-15), (f) "16+ bảng" exact count (plan.md), (g) `acted_via_delegation_id` column (§10.1). These are implementation choices, not requirements. BA's job is to state "delegation must be revocable within 1 API call latency"; Tech Lead picks the mechanism.
- Why it matters: Tech Lead Phase 3 plan literally re-states these as if they were requirements ("Plan picks Option C... if reverted to Option A..." — but reversion is foreclosed by BA prescription). Loses architectural exploration.
- Fix: Move §3.1/3.2 + technical mechanisms in §4/§10 into a separate "BA recommendations to Tech Lead (non-binding)" appendix or strip them entirely. Replace with NFRs: "Revocation propagates in ≤ next request" / "Audit log query at 10M rows must return p95 < 1s".

---

### MAJOR

**M1. [Personas — Operator-company employees missing] [§5.2]** v1 review claimed "Operator employees if PMC" coverage. US-P1–P15 all treat operator as monolithic single user. AS-06 explicitly says "Operator-doanh nghiệp = 1 user pháp nhân; no sub-user v1" — but US-P4 mentions GPKD + legal rep, which is the *exact* PMC case where 1 user = 1 receptionist + 1 manager + 1 accountant in real life. Either drop B2B operator-company support from v1 (and drop US-P4), or add stories for shared-login risk (audit attribution, password sharing, off-boarding).
- Fix: Either remove operator-company support from v1 scope explicitly, or add US-P16 "shared account warning" + AC for audit attribution under shared login.

**M2. [Tenant agency confusion — partial fix only] [US-T1 / AC-54]** AC-54 dual-disclosure on PDF is good, but tenant in-app experience (US-T1 "biết ai có thẩm quyền") has no AC. How does tenant *in the app* see operator authority? Where? At what touchpoints (contract sign, monthly invoice, maintenance request)? PDF-only disclosure means tenant sees authority *once at signing* then forgets; ongoing operator interactions look identical to owner interactions.
- Fix: Add AC for in-app tenant-facing badge "Liên hệ đại diện chủ nhà: [Operator name] | Chủ: [Owner name]" on tenant home + contract detail + invoice + every chat thread initiated by operator.

**M3. [Concurrent operator conflict on same property — undefined] [AC-08]** "1 owner có tối đa 1 delegation active per scope-domain" — but what if Owner A delegates Property 1 to Operator X (scope=building_42) and to Operator Y at the same time (scope=room_101 inside building_42)? AC-08 says "partial unique on `(owner_id) WHERE status='active'`" = only 1 active per owner total. This kills the entire reason to have scoped delegations.
- Fix: Decide: (a) v1 strict "1 active delegation per owner, scope = `all` or building-list" — no nesting; or (b) "1 active delegation per property" — needs different constraint. Pick one explicitly. Current AC-08 contradicts US-O2 "phạm vi từng phòng".

**M4. [Operator company bankruptcy — undefined] [§10.6]** AC-50b handles loss of legal rep. Company bankruptcy / dissolution is different: GPKD revoked, no successor, all operator credentials orphaned. Who freezes the delegation? In what state are in-flight approvals? Who notifies tenants the operator is gone?
- Fix: Add AC: "If operator-company GPKD detected as revoked (admin trigger or annual re-verification), delegation auto-paused, owner + tenants notified within 24h."

**M5. [Offline operations not addressed] [§10.3]** Field operator collects cash, takes meter reading in basement (no signal), takes photo of tenant CCCD on flaky 3G. Doc assumes always-online. Cash payment AC-32b requires "location-stamp + photo" — but doesn't address sync conflicts, offline drafts, or fraud via clock manipulation (operator backdates a receipt to before delegation start).
- Fix: Add AC: "All operator-recorded actions carry server-stamped `recorded_at` (when synced) and client-claimed `acted_at`; mismatches > 24h flagged in audit. Cash receipts pre-delegation-active are blocked."

**M6. [Conflicting Tenant disputes ownership/agency mid-rental] [missing]** Tenant calls owner directly to pay rent (skip operator); owner accepts. Or tenant complains to platform "this isn't my landlord". No AC covers tenant-side dispute trigger.
- Fix: Add AC: "Tenant can flag 'unauthorized operator' through in-app channel → admin review within 48h → temporary pause if prima facie." Link to Q8 liability.

**M7. [Data deletion vs PDPL retention contradiction — see C5] [§10.5]** Already CRITICAL above. M-level note: terminate doesn't archive PII fields; PDPL ROD (right of deletion) request handling missing. AC-46 "operator vẫn xem read-only history trong 90 ngày" — but tenant may have ROD request that demands deletion *before* 90 days. Hierarchy unclear.

**M8. [Quantitative claims still un-sourced] [§1.1 / §11]**
- "~55%/~25%/~20% market split" still uncited (v1 should have flagged this; v2 didn't fix). Mark as "BA assumption, needs validation via Q7.1 pilot."
- "ARPU 2-3× nhóm A" uncited.
- §11 "100+ delegations, NPS ≥ 60" — these are aspirational. State which is hard gate (kill feature if missed) vs aspirational.
- Fix: Tag every metric: source = research / BA assumption / pilot to validate.

**M9. [Mobile-first NFR missing] [§10 / §11]** VN audience is ≥ 90% mobile (research not cited here but well-established). No NFR on mobile p95 latency, offline-tolerant UI, low-bandwidth (3G) image upload size limits, Android version coverage. Especially critical for operators in field (rural Đà Lạt, Phú Quốc).
- Fix: Add §10.x NFR: target Android ≥ 7.0; portfolio screen p95 ≤ 2.5s on 3G; image upload ≤ 800KB after client compression.

**M10. [In-flight transactions on revocation] [partial fix in US-O16, AC-9, AC-16b — but incomplete]** US-O16 says "in-flight approval auto-cancel + báo lý do" but doesn't address: (a) in-flight contract signing (tenant has signed, operator hasn't countersigned), (b) in-flight money movement (operator initiated transfer, not landed yet — but commission v1 is manual, so moot for now), (c) scheduled notifications (weekly digest about to send referencing operator who is now gone). Spell out per artifact category.

**M11. [Vietnamese diacritics / name handling — i18n not addressed] [§4 / AC-54]** Operator names with full diacritics (Nguyễn Thị Phương Thảo) on PDF, contract signing fields, audit log search. Search by name with/without diacritics. Sort order. v1 review missed this entirely; mobile keyboard input on operator-company GPKD field with parentheses, slashes, ampersands.
- Fix: Add AC: "All name/identifier fields normalize via NFC; search accepts diacritic-insensitive match (LOWER(unaccent(...))); PDF renders full diacritics correctly across iOS/Android viewers."

**M12. [Approval delivery — Zalo OA not validated] [AC-30b]** AC-30b mentions Zalo OA at 48h. Zalo OA approval requires Zalo registered template (ZNS), takes 2–3 weeks to register, costs ~600đ/msg. Has the platform registered? Is there a fallback if template rejected? Cost forecast at scale?
- Fix: Add AS-11 "Zalo OA template pre-registered before launch" + cost estimate in §10.9.

---

### MINOR

**N1. [§0 TL;DR] "Target ship: TBD"** appears in BA doc *and* plan.md *and* status line. Decision should be product/biz, not deferred indefinitely. Acceptable to leave TBD but flag as Q1.3.

**N2. [§4 Terminology]** Missing key terms used elsewhere: `heir`, `estate executor`, `power of attorney scope`, `KYC expiry grace period`. Add for consistency.

**N3. [AC-29b] "biometric/PIN confirmation ≥ 50M VND"** — biometric on iOS is FaceID (binary) but Android varies widely (fingerprint reliability uneven on cheap devices common in VN). May force PIN-only fallback path. Out-of-scope for BA but flag.

**N4. [AC-40] "export max 12 months"** — fine for owner self-export, but Q8.2 mentions legal evidence package (court request). Court evidence may need 36+ months. State both: self-export 12mo cap, court-evidence export via admin-only path unlimited.

**N5. [AC-32b] "location-stamp + photo"** — what if location service off? What if photo fails to upload? Workflow doesn't degrade gracefully.

**N6. [§6.7 AC-44] "archive (không hard-delete)"** — define what "archive" means. Soft-delete with `archived_at`? Move to cold table? PDPL implications differ.

**N7. [US-O15 / AC-18 "Mình mode read-only"]** Vietnamese owners' mental model = "tài sản của tôi mà phải hỏi xin?" This is *correct* BA decision but UX rollout needs framing in onboarding. Note for Phase 3, not a BA fix.

**N8. [§12 Changelog]** Says "7 CRITICAL fixes" applied. Counting in §12 body, C1–C7 listed = correct. MAJOR count says 12, body lists M1–M12 = correct. MINOR says 7, body lists N1–N7 = correct. Math passes; one of few clean parts of the doc.

---

## 3. v1 fix verification audit

| v1 claim (from §12) | Location | Actually fixed? | Evidence |
|---|---|---|---|
| C1 KB04 fast-track | AC-55, §4 | **PARTIAL** | AC-55 says 3h SLA; §4 terminology says 6h; §12 says "6h". Numeric drift unresolved (see C1 finding). Auto-approve in `operator_full` is present. |
| C2 Approval expire 72h auto-REJECT + SMS | AC-30 | **Y** | "AC-30: Approval expire 72h: fallback = auto-REJECT + escalate qua SMS owner. KHÔNG có option auto-approve" — clean. |
| C3 Request-scoped context + push deep-link | AC-15, AC-15b, AC-16b | **Y** | All three ACs present. Note: this is design creep (see C6) but the fix as claimed is there. |
| C4 Overlapping scope | AC-08 | **PARTIAL** | "Partial unique on `(owner_id) WHERE status='active'`" but this kills scoped delegation (see M3). Fixed the constraint but introduced new contradiction with US-O2. |
| C5 "Mình mode" reframe | US-O15, AC-18 | **Y** | US-O15 reworded "read-only + send instruction"; AC-18 explicit. Clean. |
| C6 PDPL bank mask | AC-53 | **Y** | "Bank account = `****1234`... reveal owner one-time consent, log vào `CCCDAccessLog`-equivalent". Clean. |
| C7 Marketplace booking routing | AC-51 | **Y** | "Payout vẫn route đến `host_id = owner_id` (immutable)... payout destination KHÔNG đổi được." Clean. |
| M1 Mid-contract transition | AC-49 | **Y** | "KHÔNG modify existing contract/tenant/khaibao... optional opt-in transfer contact". Clean. |
| M2 KYC expiry | AC-50, US-P14, AC-50b | **Y** | Three ACs present. Auto-pause + 30-day re-KYC window. Clean. |
| M3 Self-owner-self-operator | AC-56 | **Y** | "1 user có thể đồng thời là chủ VÀ active operator cho owner khác". Clean. |
| M4 Race / double-invite | AC-10b | **Y** | "HTTP 409 Conflict + offer revoke prior invite" + token single-use in AC-01. Clean. |
| M5 Cash payment | AC-32b, AC-37 | **PARTIAL** | AC-32b "location-stamp + photo" present, but no offline degradation path (M5 finding). Commission-loss alignment AC-37 present. |
| M6 SMS escalation ladder | AC-30b | **Y** | Channel ladder 0/24/48/60h fully specified. Clean. |
| M7 Termination lockdown | AC-43 | **N** | Lockdown present, but logic inverted (see C4). Fixed-but-broken. |
| M8 No-default threshold | AC-31b | **Y** | "Owner phải chủ động set 5 threshold... Validation 400 if missing". Clean. |
| M9 Dual-disclosure PDF | AC-54, AS-07 reversed | **Y** | AS-07 struck-through, AC-54 hard-coded. Clean (but missing in-app tenant view — M2). |
| M10 Pricing Q1 BLOCKER | §9 Q1 + plan.md Open BLOCKERs | **Y** | Marked explicitly. Clean. |
| M11 Audit partition day-1 | §10.5 | **PARTIAL** | Decided correctly but this is design creep (C6) and conflicts with PDPL retention (C5). |
| M12 Operator vacation | AC-57/58, US-P15 | **Y** | OoO behavior + emergency escalation defined. Clean. |
| N1–N7 (minor) | various | **Y mostly** | Spot-checked AC-06 (KYC partial), AC-29b (biometric), AC-40 (12mo cap), §11 (flag/comment metric). All present. |

**Summary:** 16/19 claimed fixes are clean; 3 are partial/broken (C1 numeric drift, C4 scope constraint contradicts US-O2, M7 lockdown inversion). The first BA Leader review was thorough; v2 author largely executed but missed second-order effects on 3 changes.

---

## 4. Dimensional scores

| # | Dimension | Score | Note |
|---|---|---|---|
| 1 | Problem statement clarity | PASS | §1 clean, segment-targeted, pain points crisp |
| 2 | User stories completeness | WEAK | Tenant covered (US-T1/T2), heir/estate missing, operator-company sub-users dodged (AS-06) |
| 3 | AC testability | WEAK | Mostly testable, but C1 numeric drift + C4 logic inversion make 2 ACs un-implementable as written |
| 4 | Out-of-scope explicit | PASS | §7 comprehensive; "operator damage claims" and "fiscal tax split" added in v2 |
| 5 | Hidden scope creep | FAIL | Doc embeds DB partition strategy, HTTP header name, hash algorithm, exact column names — see C6 |
| 6 | Contradictions | FAIL | C1 (3h vs 6h), C2 (12h misreading), C4 (AC-43 vs AC-27/US-O11), M3 (AC-08 vs US-O2) — 4 internal contradictions |
| 7 | Edge cases coverage | WEAK | Owner death missing, company bankruptcy partial, offline ops missing, tenant unauthorized-operator flag missing |
| 8 | Assumptions labelled | PASS | AS-01..10 numbered; struck-through AS-07/AS-08 clearly visible |
| 9 | Quantitative claims sourced | WEAK | 55/25/20% market split + 2-3× ARPU uncited; commission % cited to research 03 (good); §11 metrics aspirational, hard-vs-soft gates unclear |
| 10 | Risk & Impact section | PASS | §10 covers schema/auth/UI/notification/audit/legal/UX/perf/SMS; mitigation tied to AC IDs |
| 11 | Non-functional requirements | WEAK | Performance partial (§10.8), mobile-first absent, i18n diacritics absent, accessibility absent, PDPL retention contradictory |
| 12 | v1 fix verification | PASS (with caveats) | 16/19 clean, 3 partial/broken — see §3 |
| 13 | Tech Lead handoff readiness | WEAK | Tech Lead can start, but will hit C1/C4/M3 contradictions in Phase 3 plan and have to re-loop with user. Better to fix now than mid-plan. |

**Tally:** 4 PASS / 6 WEAK / 2 FAIL → overall NEEDS_REVISION.

---

## 5. Open questions for the user

1. **KB04 SLA: which number is canonical — 3h or 6h?** Tied to legal reading of Luật Cư trú 12h deadline (C1, C2). Recommend legal counsel confirm operator can pre-emptively file at lease-signing time before tenant move-in.
2. **Owner death scenario (C3):** What is the platform's intended position — auto-pause on death certificate upload by heir, or require notarized estate executor onboarding? Affects 1 user story + 2–3 ACs.
3. **AC-43 lockdown (C4):** Confirm: during 30-day termination notice, should operator be able to (a) terminate fraud-suspected tenant contracts with owner approval, (b) complete in-flight invoices, (c) only handle maintenance? Current AC-43 blocks all three.
4. **Scoped delegation reality (M3):** Will v1 actually support "1 owner → 1 operator for building A + 1 operator for building B simultaneously"? US-O2 implies yes; AC-08 says no. Choose.
5. **Operator-company sub-users (M1):** Hard scope decision — accept shared login risk in v1, or defer B2B operator entirely to v2 Org model?
6. **PDPL data tiered retention (C5):** Is the platform prepared to support right-of-deletion requests on PII fields while keeping financial records 10y? Affects archive design.
7. **Zalo OA budget & registration timeline (M12):** Has the ZNS template been registered? If not, AC-30b 48h escalation channel may not exist at launch.
8. **Pricing (Q1, already a BLOCKER):** Still unresolved. Tech Lead is proceeding on "v1 = no platform fee" assumption per plan.md.
9. **Co-owned property (Q3.4):** Research 03 §10 says joint consent required for delegation. Doc dodges with "v2 Org model". Is platform OK refusing to onboard any co-owned property until v2?

---

## 6. Recommendation

**Revise BA doc in parallel with Tech Lead reviewing the v2-as-is plan.** The plan.md and dependencies.md are well-structured and the contradictions in the BA doc (C1, C4, M3) do not block Tech Lead from starting phase-01 schema work — they affect business rules in phase-04 (approval workflow) and phase-09 (delegation management UI) which are mid-DAG. By the time those phases need the disputed ACs, the BA revision will be ready.

However, **C3 (owner death), C5 (PDPL retention), and C6 (hidden tech prescription)** should be resolved *before* phase-01 freezes the schema, because schema is committed early and migration cost rises sharply once data exists. Recommend a 2–4 hour BA revision session with user input on §5 open questions (especially Q1, Q3, Q5, Q9) before phase-01 finalizes.

The doc is **80% ready**. First reviewer did real work. Second-pass findings are second-order effects + 1 misreading + 1 missing-but-critical scenario. After revision, expect READY verdict in next pass.

---

**End of review.**
