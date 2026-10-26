# BA Leader Deep-Dive — Expert Recommendations Cross-Examination
**Reviewer:** BA Leader (brainstormer agent acting as senior BA)
**Date:** 2026-06-29
**Scope:** 10 decisions (D1–D9 + Q1) from `expert-consolidated-recommendations.md`
**Verdict:** **ACCEPT_WITH_REVISIONS** — 6 accept-as-is, 3 accept-with-AC-additions, 1 needs-user-input
**Confidence:** HIGH on aggregate; per-decision confidence below.

---

## Executive Summary

Experts converged cleanly on operational/legal facts (D1 6h, D2 manual upload, D3 digital consent, D4 refuse co-owned, D7/D8 defer, D9 4-tier). However the **consolidation glossed over 4 second-order issues**: (1) D5 3-tier AC-43 rewrite is sound but breaks AC-27 (early termination flow) and creates a new approval-SLA conflict with AC-30 72h; (2) D6 schema-aware "free" claim is misleading — Ops expert estimated +2-3 dev-days, but Tech Lead has not been asked to confirm and there is no BA-level NFR forcing scope-aware schema design; (3) D2 "Manual admin upload 24h SLA" lacks AC coverage for in-flight approval disposition on owner death (Legal Q2a open follow-up never resolved); (4) Q1 FREE-v1 ignored Q5.4 (operator commission VAT/PIT) which becomes a tax-compliance functional AC if commission flows through platform v2 — and AC-36 already encodes this format.

**Top 3 concerns to resolve before locking §13:**
1. **D5 AC-43 rewrite contradicts AC-27 + AC-30** — needs 4-AC reconciliation, not 1-AC patch.
2. **D2 owner-death in-flight approval disposition undefined** — Legal Q2a left open; AC-58 only says "auto-pause + auto-reject in-flight" but recommendation also implies executor-escalation path which needs new AC-58d.
3. **D6 schema-ready vs behavior-deferred is a Tech Lead decision dressed as BA decision** — BA should write the NFR (scope-aware queries possible), not prescribe `scope_id` FK column.

---

## Per-Decision Cross-Examination

### D1 — KB04 SLA (6h + pre-file)
**Expert source:** Legal Q1 + Ops Q3 (converge)
**BA verdict:** ACCEPT with 2 AC additions
**Confidence:** HIGH

**Cross-check:**
- **Internal contradiction?** Legal Q1 and Ops Q3 align on 6h. Both correctly identify 12h as tenant-registration deadline, not approval deadline. NO contradiction.
- **AC gap?** BA v3 has AC-55 (6h fast-track) but **no AC for pre-file workflow**. Ops Q3 §"Recommended AC Update" proposes AC-55R which is materially different from current AC-55: "Operator can pre-file KB04 before tenant move-in without owner approval. Owner approval SLA = 6h for post-facto validation". Current AC-55 = approval-before-file. Recommended AC-55R = file-before-approval-for-archive. **These are different state machines.**
- **Scope creep?** NO new entities; just a workflow refinement.
- **Hidden assumption?** Both experts assume police accept pre-emptive CT01 submission (Legal Q1a + Ops Q3 §"Open Questions"#2 + O1 in consolidated). If police reject, D1 collapses back to 12h race.
- **Dependency?** D1 depends on O1 (pre-launch police validation 1-3 phường). If O1 fails, D1 must revert to "approval-then-file 6h" model.

**Recommendation:**
1. **Clarify AC-55 wording:** Current AC-55 implies "approve then file." Add AC-55b: "Pre-file pathway — operator can submit CT01 before tenant move-in; owner approval 6h is post-facto validation, audit-marked `pre_filed=true`."
2. **Add AC-55c (depends on O1):** "If local police reject pre-emptive CT01 filing for property's district, system flags district as `pre_file_not_accepted` and falls back to approval-then-file 6h workflow."
3. **Q1b (Legal expert):** Unresolved — "If owner revokes delegation during 12h window after pre-file but before move-in, is KB04 auto-voided?" — needs AC.

**Effort to implement in BA v3:** LOW. Add 2 AC sub-items under §6.8 AC-55 area (lines 348-349); add Q1b reference to §9.

---

### D2 — Owner Death Channel (Manual admin upload, 24h SLA)
**Expert source:** Legal Q2
**BA verdict:** ACCEPT with 1 AC addition
**Confidence:** MED-HIGH

**Cross-check:**
- **Internal contradiction?** Legal Q2 says "auto-paused within 24h" but BA v3 AC-58 says "auto-paused trong 7 ngày" — **NUMERIC DRIFT 7d vs 24h.** This is exactly the C1-class error the v3 was supposed to fix.
- **AC gap?** Legal Q2a explicitly flagged: "For in-flight approvals when owner dies (e.g., operator submitted KB04 request 11:58h, owner was to approve at 12:05h but dies at 12:00h): auto-reject or escalate to heir/executor?" → BA v3 AC-58 says "tất cả in-flight approval requests auto-rejected" but Legal expert posed this as an OPEN question (Q2a) and consolidated marked it as O3 follow-up. **Auto-reject was a BA assumption, not a legal answer.** Legal expert did NOT commit to auto-reject — they flagged it as needing legal counsel review.
- **Scope creep?** Admin team workflow + admin SLA is new operational requirement; needs admin runbook (out-of-scope for BA but flag).
- **Hidden assumption?** "Admin team exists, is 24/7-ish, and can verify a death cert in 24h." For pilot (50-100 delegations), this may be the founder. State explicitly.
- **Dependency?** D2 depends on US-A6 (admin death-notification handling story) — present. D2 does NOT depend on D1 unless owner dies during KB04 12h window (covered by Q2a/O3, unresolved).

**Recommendation:**
1. **Reconcile 7d vs 24h:** AC-58 says "auto-paused trong 7 ngày" but Legal Q2 + consolidated say "24h SLA admin verifies + auto-pauses". Question: is the "7 ngày" the admin-action window or a tenant/operator notification grace period? Re-read AC-58 → "delegation auto-paused trong 7 ngày; tất cả in-flight approval requests auto-rejected; tenants + operator nhận thông báo qua SMS + in-app trong 24h." The 7d appears to be the pause-state duration *before* executor takes over. The 24h is the admin verification + notification. So actually consistent, just dense — but **BA needs to add explicit "admin verification SLA = 24h from heir doc upload" as separate AC** to match Legal Q2 recommendation.
2. **AC-58d (NEW):** "In-flight approval requests at moment of owner-death registration: default = auto-reject; exception = if heir/executor onboarded under AC-58b within 7-day window, executor may approve in-flight requests within their authority scope. Legal counsel to confirm exception scope before phase-04 freeze (O3 follow-up)."
3. **Admin SLA is operational, not functional** — but the 24h is now embedded in the user-facing promise. Either codify as NFR ("admin response SLA on death-cert verification ≤ 24h business hours") or document as US-A6 acceptance.

**Effort to implement in BA v3:** MED. Add AC-58d, clarify AC-58 24h/7d split (lines 363-365), add NFR or US-A6 SLA, flag Q2a/O3 in §9.

---

### D3 — KB04 POA Notarization (Digital default; notary optional)
**Expert source:** Legal Q3
**BA verdict:** ACCEPT
**Confidence:** HIGH

**Cross-check:**
- **Internal contradiction?** None internal. Legal Q3 and Ops Q3 align (Ops doesn't dispute notarization issue).
- **AC gap?** BA v3 has NO AC for POA digital consent vs notarized escalation. AC-55 mentions fast-track approval but doesn't address POA format. **Missing AC: POA format selection at invite/onboarding.**
- **Scope creep?** Adds FastCA/VinaCA integration → new dependency. Legal Q3 §Option B notes "~50–100K VND per sig (platform cost) or free if owner pays" — **this is a real per-delegation cost not in BA v3 §10.9.**
- **Hidden assumption?** ~85% police acceptance of digital sig nationwide. Legal Q3 itself flags this with Q3a (1-3 HCMC/Hanoi police pre-launch check = O2). High variance risk.
- **Dependency?** D3 depends on O2 (pre-launch police validation). If O2 returns mixed acceptance, system needs district-level routing.

**Recommendation:**
1. **AC-55d (NEW):** "Owner POA format selection at delegation creation: default = digital consent (FastCA/VinaCA integration); escalation = upload notarized POA PDF. If digital fails at specific police district (per O2 results or audit findings), system warns operator and recommends notarized backup."
2. **§10.9 cost addendum:** Add digital sig cost (50–100K VND/delegation × N delegations) to budget table. Decide who pays (owner or platform).
3. **AS-14 (NEW assumption):** "FastCA/VinaCA integration via existing vendor; cost absorbed by platform v1, passed to owner v2."

**Effort to implement in BA v3:** LOW-MED. Add AC-55d, AS-14, §10.9 cost row.

---

### D4 — Co-Owned Property v1 (Refuse v1, defer v2)
**Expert source:** Legal Q4
**BA verdict:** ACCEPT
**Confidence:** HIGH

**Cross-check:**
- **Internal contradiction?** §13 in BA v3 already shows D7 for "scope nesting defer v2"; consolidated D4 references this same D7 default. NUMBERING CONFUSION — BA v3 §13 D7 = scope nesting; consolidated matrix D4 = co-owned property. **The §13 Decisions Log has 8 decisions (D1-D8); consolidated matrix adds D9 + Q1 BUT relabels some.** Need explicit mapping: consolidated D4 = BA v3 §13 D7? Or is it a new decision? Let me re-check: BA v3 §13 lists D1-D8; consolidated lists D1-D9 + Q1. Consolidated D4 (co-owned) appears to be NEW; BA v3 §9 Q3.4 + Q9 marks co-owned as still-open. So consolidated D4 is the closing of Q3.4/Q9. **Renumbering: consolidated D7 (scope nesting) ≠ BA v3 §13 D7 (also scope nesting) — same content, lucky. But consolidated D9 (PDPL retention) = BA v3 D4 (PDPL retention).** Decision numbering is inconsistent between docs and will confuse Tech Lead.
- **AC gap?** BA v3 §7 out-of-scope mentions "Co-ownership (nhiều owner / property) — v2 (xem Q9)". BA v3 has US-O17 "co-owner scenario — out-of-scope v1" P2. **Missing AC: onboarding refusal UX when red-book shows 2 names.** Legal Q4a explicitly asks "what is user-facing message?" — unresolved.
- **Scope creep?** None. Refusal = simplest path.
- **Hidden assumption?** Platform can detect co-ownership at onboarding (red-book OCR or manual review). Currently, BA v3 §2.4 KYC uses CCCD only — no red-book verification step. **If platform doesn't read red-book, "refuse co-owned" is unenforceable** — relies on owner self-declaration honesty.
- **Dependency?** D4 depends on red-book verification capability. If not present, D4 becomes "owner attests sole ownership at onboarding; false attestation → ToS violation + platform indemnity clause."

**Recommendation:**
1. **AC-64 (NEW):** "At Owner onboarding, system prompts: 'Property registered under single name (sole owner)?' If owner answers NO, system blocks delegation creation with message: 'v1 chỉ hỗ trợ chính chủ. Tính năng co-owned launching v2 Q4 2026.' If YES + later disputed, ToS indemnity clause applies."
2. **AS-15 (NEW assumption):** "Owner self-declaration of sole ownership is binding under ToS; platform does not OCR red-book in v1. False declaration = ToS violation."
3. **§9 update:** Mark Q3.4 + Q9 as ANSWERED via D4 (consolidated). Also clarify Q9 → D4 mapping for Tech Lead.

**Effort to implement in BA v3:** LOW. Add AC-64, AS-15, update §9.

---

### D5 — AC-43 Lockdown (3-tier rewrite)
**Expert source:** Ops Q1
**BA verdict:** REVISE — contradicts AC-27 + AC-30 + introduces new SLA without coverage
**Confidence:** MED-HIGH on direction; MED on current consolidated wording

**Cross-check:**
- **Internal contradiction?** **YES — multiple.**
  - Consolidated says "fraud-term ALLOWED with 24h approval" but **AC-30 says 72h approval expiry**. So fraud-termination during lockdown gets 24h SLA, but normal approval gets 72h? Two SLAs in same approval pipeline. No AC reconciles.
  - **AC-27 already exists:** "Operator chấm dứt hợp đồng (early termination): luôn cần approval; KHÔNG bị block bởi AC-43 termination lockdown." So AC-27 ALREADY says termination is not blocked by lockdown. D5 essentially re-states AC-27 + extends to refunds + pre-file. **AC-27 vs D5 wording overlap creates ambiguity** — which AC governs?
  - **AC-43 v3 (current) already has 3-tier:** lines 331-332 read exactly the 3-tier structure Ops Q1 recommended ("BLOCKED... CHO PHÉP với owner approval per-action... CHO PHÉP không cần approval"). **D5 is already implemented in BA v3.** The consolidated table makes it sound like a new decision, but it's a CONFIRMATION of existing AC-43 v3 wording.
- **AC gap?** Per-action 24h fraud-approval SLA needs explicit AC (current AC-43 doesn't state SLA — defaults to AC-30 72h).
- **Scope creep?** No new entities. Possible AC additions: AC-43b for 24h fraud SLA.
- **Hidden assumption?** Operators in fraud-suspicion scenario will use this path responsibly (don't abuse fraud-termination to dodge lockdown). Audit log expected to catch abuse, but no AC defines abuse detection.
- **Dependency?** D5 depends on D1 (pre-file unlocks the "allow pre-file in lockdown" branch). Yes — explicit dependency.

**Recommendation:**
1. **Clarify consolidated D5 wording:** "MODIFY: keep 30d, FLIP logic" — this is misleading. AC-43 in BA v3 already has the correct 3-tier structure. The actual decision is **"add 24h SLA for fraud-termination approvals (faster than default 72h)"** — that's the genuinely new piece.
2. **AC-43b (NEW):** "Approval SLA during lockdown for fraud-suspected termination = 24h (faster than default 72h per AC-30). Auto-reject + admin escalation if 24h missed."
3. **Reconcile with AC-27:** Add cross-reference in AC-43 body: "Per AC-27, early termination always requires approval; AC-43b governs SLA when AC-43 lockdown is active."
4. **Reconcile with AC-30:** Add note in AC-30: "Standard 72h expire; exceptions: AC-55 (KB04 6h fast-track), AC-43b (fraud-termination 24h during lockdown), AC-29b (high-value biometric)."

**Effort to implement in BA v3:** MED. Add AC-43b, cross-references in AC-27 + AC-30 + AC-43, update consolidated wording before user approval.

---

### D6 — Scope Nesting (Defer behavior v2; schema scope-ready v1)
**Expert source:** Ops Q2
**BA verdict:** NEEDS_USER_INPUT — BA cannot prescribe schema
**Confidence:** LOW on current wording (high uncertainty)

**Cross-check:**
- **Internal contradiction?** Consolidated D6 contradicts BA v3 §13 D7 + BA v3 Appendix B6. **BA v3 §13 D7 says "scope nesting = defer v2; v1 strict 1 active delegation per owner, scope = all or building-list, non-nested"** — no mention of schema-ready. **Appendix B6** says "Tech Lead có thể propose alternative" — schema choices are explicitly Tech Lead's. **Consolidated D6 introduces "schema scope-ready ngay v1 (add scope_id FK)" — this is a TECHNICAL PRESCRIPTION exactly like C6 in v2 review that BA v3 already removed.**
- **AC gap?** No AC needed (defer-behavior matches existing AC-08). But "schema scope-ready" cannot be an AC — it's an NFR or Tech Lead's call.
- **Scope creep?** +2-3 dev-days (Ops Q2 estimate). Quantified but no one has asked Tech Lead. **This is scope creep dressed as decision.**
- **Hidden assumption?** Ops Q2 assumes v2 nesting migration cost = 2-3 weeks WITHOUT scope-ready schema. This is an engineering estimate from a Product Ops expert with no codebase access. Tech Lead may have a cheaper migration path (e.g., versioned API + lazy schema bump).
- **Dependency?** D6 schema "ready" affects D7 (related decision) and phase-01 schema freeze. If approved, phase-01 must add `scope_id` FK — schema commitment.

**Recommendation:**
1. **REJECT the schema prescription. RE-FRAME as NFR.** Replace consolidated D6 wording with:
   > "Defer scope nesting behavior to v2 Org model Q4 2026. NFR-13 (NEW): Schema design must enable scope-bound queries (single-property → building-list → nested) without breaking-change migration of existing data. Tech Lead chooses mechanism (scope_id FK, polymorphic table, denormalized scope array, etc.) in phase-01."
2. **Move "scope_id FK" suggestion to Appendix B7 (non-binding).**
3. **Tech Lead must confirm in phase-01 plan:** "How will v2 nesting be enabled without data migration? Provide design + estimate."
4. **User input needed:** "Are you OK with BA writing the requirement (scope-ready by design) and letting Tech Lead pick the mechanism? Or do you want to lock the `scope_id` FK approach now?"

**Effort to implement in BA v3:** MED. Rewrite §13 D7 wording, add NFR-13, add Appendix B7, flag user-input gate.

---

### D7 — PMC Multi-User RBAC (Confirm defer v2)
**Expert source:** Strategy Q1
**BA verdict:** ACCEPT with 1 mitigation already encoded
**Confidence:** HIGH

**Cross-check:**
- **Internal contradiction?** None. Aligns with BA v3 §13 D6 (yes, BA v3's D6 = PMC sub-users defer; consolidated D7 = same content). **Confirms numbering chaos** — see D4 cross-check.
- **AC gap?** Strategy Q1 §"Sales pitch" mentions "notarized POA update workflow + audit disclosure UI" as mitigations. **Notarized POA update workflow has no AC.** AC-50b only covers "loss of legal rep → re-KYC". When PMC's legal rep changes (staff turnover), what's the operational process? Re-notarization implied but no AC.
- **Scope creep?** None.
- **Hidden assumption?** PMC will accept shared-login risk and disclose in onboarding (AS-12). Strategy Q1 assumes this is documented in onboarding flow — currently AS-12 just says "disclosure shown in onboarding" without AC for the actual UI.
- **Dependency?** D7 doesn't depend on D4 (co-owned) or D6 (scope nesting) functionally, but ALL THREE are "defer v2" decisions creating cumulative TAM loss (Strategy estimates 5%, Ops estimates 10-15%, Legal estimates 30%). Combined: ~30-40% segment-C addressable market deferred to v2. **Is this OK for sponsor?**

**Recommendation:**
1. **AC-65 (NEW):** "PMC legal-rep change (staff turnover) workflow: operator-company uploads updated notarized POA + new legal rep CCCD via admin-assisted flow. Old credentials disabled within 48h; in-flight approvals re-routed to new legal rep. Audit log marks transition."
2. **AS-12 enhancement:** Promote AS-12 to AC-66: "At operator-doanh-nghiệp onboarding, system displays shared-login risk disclosure modal: (a) all logins audit under 1 account, (b) password rotation responsibility on company, (c) v2 Org model timeline. Owner must click-through acknowledgment."
3. **§11 NEW metric:** "Cumulative TAM deferred to v2 (D4 co-owned + D6 scope nesting + D7 RBAC): ~30-40%. Hard-gate: if v1 fails to reach 50 delegations in 6 months, evaluate if deferrals are the cause."

**Effort to implement in BA v3:** LOW. Add AC-65, AC-66, §11 metric note.

---

### D8 — Zalo ZNS Rollout (Defer v1.1)
**Expert source:** Strategy Q2
**BA verdict:** ACCEPT but watch AC-30b contradiction
**Confidence:** HIGH on phasing; MED on AC alignment

**Cross-check:**
- **Internal contradiction?** **AC-30b says "0h push only → 24h push+email → 48h push+email+Zalo OA → 60h SMS"** — Zalo OA is in v1 escalation ladder at 48h. But D8 says "DEFER ZNS to v1.1." **Direct contradiction with AC-30b.**
  - AS-11 hedges: "Zalo OA template pre-registered trước launch... fallback về email chỉ" — so AC-30b currently expects Zalo + has email fallback.
  - D8 effectively says "AC-30b 48h Zalo channel REMOVED in v1; v1.1 adds it." This is a regression from AC-30b as currently written.
  - **AS-13 also says** "Zalo ZNS template registration pre-launch là pre-condition cho phase-12; budget cap 500K VND/month" — pre-launch precondition.
- **AC gap?** Need to rewrite AC-30b to reflect v1 = no Zalo: "0h push → 24h push+email → 48h push+email → 60h SMS (ZNS deferred to v1.1)." Then v1.1 plan re-adds Zalo at 48h.
- **Scope creep?** Reduces v1 scope (good). Phase-12 (Zalo template registration) likely deferred to v1.1 — Tech Lead plan must reflect.
- **Hidden assumption?** Email reach for VN owners (segment C, age 50-70) sufficient for 48h escalation. Strategy Q2 itself flagged this as a risk: "owner ngoại tuyến miss notification (mitigated bởi email)" — mitigation is thin. Older absentee owners may not check email daily.
- **Dependency?** D8 depends on email-deliverability NFR. Strategy Q2 §"Open Follow-ups" #4 ("What's ancu365's current SPF/DKIM reputation?") flags this — no NFR currently.

**Recommendation:**
1. **Rewrite AC-30b for v1:** "Escalation ladder v1: 0h push → 24h push+email → 48h push+email (intensified subject) → 60h SMS. Zalo OA channel deferred to v1.1 per D8."
2. **Update AS-11 + AS-13:** Mark Zalo template registration as v1.1 prep activity, not pre-launch precondition. Adjust phase-12 to v1.1.
3. **NFR-14 (NEW):** "Email deliverability ≥ 95% to owner inbox (SPF/DKIM/DMARC configured); bounce rate monitored; high-value approval emails (≥20M VND) flagged for read-receipt + SMS-fallback faster."
4. **§10.9 cost update:** v1 = 0 Zalo + email infrastructure only; v1.1 cost projection per Strategy Q2 budget table.

**Effort to implement in BA v3:** MED. Rewrite AC-30b, update AS-11/AS-13, add NFR-14, update §10.9.

---

### D9 — PDPL Retention (4-tier)
**Expert source:** BA v3 §10.5 (already encoded) + Legal cross-cut
**BA verdict:** ACCEPT (no change — already in BA v3)
**Confidence:** HIGH

**Cross-check:**
- **Internal contradiction?** None. §10.5 already has 4-tier policy from v3 C5 fix.
- **AC gap?** AC-59 (ROD flow) already present. AC-44 (terminate archive 30d → tiered retention) present. **Missing AC: cron job mechanics for tier transitions.** But that's implementation detail, not BA-level.
- **Scope creep?** None.
- **Hidden assumption?** Cron jobs for tier transitions can be built without dev pain. Should validate with Tech Lead.
- **Dependency?** None.

**Recommendation:** **CONFIRM as-is.** No changes needed.

**Effort to implement in BA v3:** NONE. Already done.

---

### Q1 BLOCKER — Pricing (FREE v1 → Freemium v1.5 → 0.5% v2 → Full SaaS v3)
**Expert source:** Pricing (entire report)
**BA verdict:** ACCEPT with strong caveats
**Confidence:** HIGH on direction; MED on KPI gate calibration

**Cross-check:**
- **Internal contradiction?** **YES — with AC-33, AC-34, AC-35, AC-36, AC-37.** These ACs already exist in BA v3 for commission tracking + tax reporting. But Pricing recommends FREE v1, no platform commission. **If platform takes no commission, AC-33 (expected_owner_payout = total - commission - fees) has no `fees` to subtract — fee field is 0 in v1.** That's OK functionally but the AC math implies platform fees exist. Add note.
- **Q5.4 still open:** "Operator commission VAT/PIT: owner withholds hay operator self-files?" — Pricing didn't answer. AC-36 says owner exports tax report in TNCN/VAT format — implies owner withholds. **Q5.4 is functional and needs answer regardless of platform commission decision.**
- **AC gap?** No new ACs for FREE-v1 (deferral = remove things, not add). But for v1.5 freemium + v2 commission, future ACs needed (out-of-scope for Phase 3 freeze).
- **Scope creep?** Pricing v3 (Q1 2027) introduces "Mandatory tier-based subscription" — completely different revenue model. Document but don't lock v3 specifics yet.
- **Hidden assumption?** "50+ delegations + NPS ≥ 55 → advance to v1.5" — but BA v3 §11 says hard-gate is 50 delegations (kill feature if <50) and aspirational NPS 60. **Pricing says NPS 55 to advance to v1.5; BA says NPS 60 aspirational.** Two NPS thresholds; reconcile.
- **Dependency?** Q1 doesn't block phase-01 schema (commission tracking columns already in scope per AC-33/AC-34, even if v1 sets to 0). Pricing's claim "không ảnh hưởng v1 phase-01 schema" is CORRECT.

**Recommendation:**
1. **§13 update:** Add Q1 to Decisions Log as DEFERRED-DECISION-with-default. Frame as "v1 = no platform fee (FREE); commission tracking columns built (AC-33 family) but populated with 0. v1.5/v2/v3 pricing decisions defer to gate reviews."
2. **AC-33 clarification:** "v1: platform_fee_pct = 0; commission = operator_commission only; expected_owner_payout = total - operator_commission. Schema supports future platform fee insertion without migration."
3. **Reconcile NPS:** §11 NPS metric → "advance-gate NPS ≥ 55 (Pricing); aspirational NPS ≥ 60 (BA assumption). Use 55 as advance gate for v1.5."
4. **Q5.4 still open after Q1 answered.** Flag in §9 — needs tax counsel.

**Effort to implement in BA v3:** MED. Update §13, AC-33, §11 NPS, §9 Q5.4 flag.

---

## Inter-Decision Contradiction Map

| Pair | Interaction | Risk |
|------|-------------|------|
| **D1 (KB04 6h) ↔ D5 (24h fraud-term)** | Both are exception SLAs to AC-30 default 72h. AC-30 doesn't enumerate exceptions. | LOW — easy AC patch |
| **D1 (pre-file) ↔ D5 (lockdown allows pre-file)** | D5 explicitly cites D1's pre-file as the unblocker. If O1 fails (police reject pre-file), BOTH D1 and D5 weaken. | MED — dual exposure to O1 |
| **D2 (owner death) ↔ D1 (KB04 12h window)** | Legal Q2a: owner dies during operator's pending KB04 approval. Auto-reject vs escalate-to-heir? AC-58 says auto-reject; Legal flagged as open. | MED — needs AC-58d (above) |
| **D5 (AC-43 lockdown) ↔ AC-27 (early termination)** | AC-27 says termination not blocked by lockdown; AC-43 v3 says termination allowed-with-approval. Same rule, two ACs. Cross-reference needed. | LOW — clarification |
| **D6 (scope schema-ready) ↔ D7 (defer RBAC)** | If schema is scope-ready v1, does that pull RBAC schema forward too? Strategy Q1 didn't address. | MED — Tech Lead must address in phase-01 |
| **D6 + D7 + D4 (all deferrals)** | Cumulative ~30-40% segment-C TAM deferred to v2. Sponsor must accept aggregate, not piecewise. | HIGH — sponsor decision |
| **D8 (Zalo defer) ↔ AC-30b (Zalo at 48h)** | Direct contradiction — AC-30b must be rewritten. | MED — explicit rewrite |
| **D8 (defer) ↔ AS-11, AS-13, phase-12** | Phase-12 Zalo template registration pre-launch is now v1.1 prep. Plan.md must reflect. | LOW — phasing shift |
| **Q1 (FREE v1) ↔ AC-33/34/35/36/37** | Commission AC family assumes platform fee math; v1 = 0. Schema-compatible but doc unclear. | LOW — clarification |
| **Q1 NPS ≥ 55 ↔ §11 NPS ≥ 60** | Two different NPS thresholds in two different docs. | LOW — pick one |

---

## Missing User Stories / AC

ACs implicitly required by expert recommendations but **NOT** in BA v3:

| New AC | Source decision | Reason |
|--------|-----------------|--------|
| **AC-55b — KB04 pre-file workflow** | D1 (Ops Q3) | Workflow is different state machine than AC-55 |
| **AC-55c — pre-file rejection fallback** | D1 (O1 dependency) | If police district rejects pre-file, system fallback |
| **AC-55d — POA format selection (digital/notary)** | D3 | No AC for choosing POA format at invite |
| **AC-58d — In-flight approval at owner-death** | D2 (Legal Q2a) | Default auto-reject vs executor-escalate exception |
| **AC-64 — Sole-ownership attestation onboarding** | D4 | UX for refusing co-owned onboarding |
| **AC-65 — PMC legal-rep change workflow** | D7 (Strategy Q1) | Operational continuity when PMC staff turns over |
| **AC-66 — Shared-login disclosure UI** | D7 (AS-12 promotion) | AS-12 → AC for testable UX |
| **AC-43b — 24h fraud-term SLA** | D5 (Ops Q1) | New SLA not in AC-43 v3 |

**NEW User Stories implied:**

| Story | Source | Comment |
|-------|--------|---------|
| US-O19 (NEW) — As Owner, I want POA digital vs notary chosen at invite. | D3 | UI choice |
| US-P16 (NEW) — As Operator-doanh-nghiệp, I want to update legal rep without re-onboarding the property. | D7 | Operational |
| US-A7 (NEW) — As Admin, I want runbook for handling owner-death cert verification within 24h. | D2 | Operational |

**Existing User Story alignment check:** US-O18 (heir) covers D2 owner-death; US-T1 covers D7 tenant-disclosure via AC-60; US-A6 covers D2 admin path. **No expert recommendation creates an orphan user story; all map to existing or NEW-listed above.**

---

## NFR vs Functional Mapping

Several expert recs were framed as functional ACs but are really NFR / operational:

| Topic | Currently | Should be |
|-------|-----------|-----------|
| **D2 admin 24h verification SLA** | AC-58 (functional) | + NFR ("admin response SLA on death-cert verification ≤ 24h business hours") |
| **D6 schema scope-ready** | Consolidated D6 (functional/schema) | **NFR-13** ("schema must support scope-bound queries without breaking migration"), Appendix B7 (non-binding schema suggestion) |
| **D8 email deliverability** | Implicit in AC-30b | **NFR-14** (email ≥95% deliverability) |
| **D9 cron tier transitions** | §10.5 mechanism | NFR (background job reliability ≥ 99.5%) — OPTIONAL, Tech Lead detail |
| **Q1 commission schema-ready** | AC-33 family | NFR-15 ("payment splits schema supports platform fee insertion v2 without migration") |

**NFR section in BA v3 (§6.12)** has NFR-01..NFR-12. Add NFR-13, NFR-14, NFR-15 above. Currently the consolidated rec doc smuggles schema decisions into "decisions" — moving them to NFR is correct BA discipline.

---

## Scope Creep Audit

If user approves all 10 defaults as-written + this BA Leader review's suggested AC additions:

| Category | Added | Removed | Net |
|----------|-------|---------|-----|
| ACs | +8 new (AC-43b, AC-55b/c/d, AC-58d, AC-64, AC-65, AC-66) | 0 | **+8 ACs** (from 63 → 71) |
| User Stories | +3 new (US-O19, US-P16, US-A7) | 0 | **+3 USs** |
| NFRs | +3 new (NFR-13, NFR-14, NFR-15) | 0 | **+3 NFRs** |
| Assumptions | +2 new (AS-14, AS-15) | 0 | **+2 AS** |
| Open Questions resolved | Q3.4, Q9 → D4; Q1 → deferred-default | Q2.1, Q5.4, Q6.1, Q6.3, Q6.4, Q6.5, Q8.1 still open | **partial** |
| Out-of-scope items | 0 | 0 | no change |
| Phases shifted | Phase-12 (Zalo) v1 → v1.1 | — | scope reduction |

**Is v1 still v1?** YES — net effect is **+8 ACs (12% growth) for proper edge-case coverage, NOT new features.** All new ACs are clarifications/refinements of existing decisions. Scope creep is minimal *if* user accepts revised wording for D2, D5, D6, D8.

**Real scope creep risk:** Tech Lead may protest **D6 schema-ready as +2-3 dev-days** without BA NFR justification. Reframing as NFR-13 + Tech Lead choice mitigates.

**Real scope reduction:** D8 defer Zalo to v1.1 → phase-12 dropped from v1 → ~3-5 dev-days saved. Net = roughly cost-neutral.

---

## Top 3 Issues to Resolve Before User Approval

### 1. D5 (AC-43 lockdown) needs AC reconciliation, not just confirmation
Current consolidated D5 wording sounds like a NEW change but BA v3 §6.7 AC-43 already encodes 3-tier. **The actual new piece is AC-43b 24h fraud-term SLA**, which contradicts AC-30 72h default. Without explicit AC-43b + cross-references in AC-27/AC-30, Tech Lead will hit a contradiction at phase-04 freeze and have to re-loop. **Resolve before §13 lock.**

### 2. D6 schema-ready is a Tech Lead decision, not a BA decision
Consolidated D6 says "add `scope_id` FK" — this is exactly the C6 hidden-tech-prescription that BA v3 fought to remove. **Reframe as NFR-13 + Appendix B7 (non-binding) before locking §13.** Else BA v3 §13 D7 wording is inconsistent with consolidated D6 wording — Tech Lead reads two conflicting requirements.

### 3. D2 in-flight approval at owner-death is unresolved despite "ACCEPT"
Legal expert flagged Q2a as open. Consolidated marked O3 as follow-up. But AC-58 says "auto-rejected" definitively. **Either legal-validated and AC-58 stands, or AC-58d added for executor-exception path.** Currently the doc reads as if Legal answered, but Legal didn't. Cannot defer to phase-04 because schema decisions about in-flight approval handling are made in phase-01.

---

## Recommended Next Action

**"Approve consolidated D1, D3, D4, D7, D9, Q1 (6 decisions). Revise wording on D2, D5, D6, D8 (4 decisions) with the following 8 AC additions + 3 NFR additions + 2 AS additions before locking §13."**

Concrete next step:
1. **Update BA v3 §13 with revised decision text** for D2, D5, D6, D8 (replace consolidated wording with BA Leader's refined wording above).
2. **Add 8 new ACs + 3 NFRs + 2 AS** to BA v3 corresponding sections.
3. **Update §9 Open Questions** to mark Q3.4, Q9, Q4.1, Q4.2, Q4.3, Q10 as ANSWERED; flag Q5.4 + Q6.5 + Q1b + Q2a still open.
4. **Present revised §13 + delta to user** for ONE final approval before Tech Lead Phase 3 begins.
5. **Tech Lead briefing should include this deep-dive doc + revised BA v3 §13** so they don't re-discover these issues.

**Estimated effort to apply revisions:** 1.5–2 hours of BA editing.

**Do NOT proceed to Tech Lead Phase 3 until §13 reflects revised decisions.** Otherwise phase-04 plan will hit AC-43/AC-27/AC-30 contradiction and phase-01 will hit D6 schema ambiguity.

---

## New Open Questions (surfaced during this review)

1. **Q-DD1 (D2):** Does auto-reject of in-flight approvals at owner-death moment apply universally, or does executor (per AC-58b) get to approve in-flight items within 7-day pause window? — needs legal counsel + product call.
2. **Q-DD2 (D4):** If platform refuses co-owned property at onboarding via owner self-attestation (AC-64), does the platform need OCR red-book verification for high-value properties (≥20M VND/month rent) to reduce fraud risk? — product decision.
3. **Q-DD3 (D6):** If Tech Lead proposes alternative scope-ready mechanism (e.g., polymorphic table) over `scope_id` FK, is sponsor OK with the change? — pre-empt by writing NFR-13 not the mechanism.
4. **Q-DD4 (D8):** If v1 email deliverability fails for absentee owners (segment C, age 50-70), is the platform exposed to "owner didn't see approval, fraud happened" liability? — risk acceptance.
5. **Q-DD5 (D7 cumulative):** TAM deferred to v2 via D4+D6+D7 deferrals is ~30-40% of segment C. Is sponsor OK with this cumulative cut, or should at least one be pulled forward? — sponsor segment strategy.
6. **Q-DD6 (Q1):** AC-33 expected_owner_payout = total - operator_commission - fees; with platform fee=0 v1, is the AC math worth keeping in v1 (forward-compatible) or simplify? — minor, Tech Lead can decide.
7. **Q-DD7 (decisions numbering):** Consolidated matrix uses D1-D9 while BA v3 §13 uses D1-D8 with different mappings. **Re-number consistently before Tech Lead reads both docs.**
8. **Q-DD8 (admin team scaling):** D2 requires 24h admin response SLA for death-cert verification. At pilot scale (50-100 delegations), this is founder-on-call. At 1000+ delegations, dedicated admin team needed. When is the threshold + budget?

---

**Reviewer confidence summary:** HIGH on direction-of-travel; MED-HIGH on per-decision verdicts (D1/D3/D4/D7/D9/Q1 = HIGH; D2/D5/D8 = MED; D6 = LOW until reframed as NFR).

**Estimate to Tech Lead Phase 3 readiness:** 1.5–2h BA edit + 1 user approval round → unblock.

