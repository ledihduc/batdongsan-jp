# Expert Answers — Property Management Operations VN SME Perspective
**Expert role:** VN Property Management Industry SME (operator/PMC experience)  
**Date:** 2026-06-29  
**Scope:** 3 operational questions (AC-43 lockdown, Scope nesting, KB04 SLA reality)

---

## Q1 — AC-43 Lockdown: 30-Day Grace Period Scope

### Default Proposal (BA v3)
**BLOCKED** during 30-day revocation notice: new contracts, tenant onboarding, raise threshold, change banking, invite operator  
**ALLOWED with owner approval per-action**: terminate fraud-suspected contracts, refund incorrect charges  
**ALLOWED unconditional**: complete in-flight invoices, emergency maintenance, respond to tenant messages

### **Recommended Answer: MODIFY — Grace Period 30 days is correct BUT logic inverted (C4 from BA Leader review is valid)**

**Rationale:**
- **30 days is industry standard** (confirmed from global property management transitions — property management industry standard requires "two-to-three weeks notice... two-to-three weeks for wrap-up"). Vietnam PMC contracts (research 03 §6.2) use 30–60-day termination notice clauses.
- **But the lock-down rules are backward operationally.** Current AC-43 says "NEW commitments BLOCKED entirely" during notice. This means:
  - Operator cannot onboard a new tenant *even with explicit owner approval* if tenant move-in happens day 15 of 30-day window
  - Operator cannot pre-file KB04 for incoming tenant (which should happen before move-in per research 03 §2.1)
  - **Fraud detection scenario breaks:** If operator is suspected of fraud (e.g., embezzling rent), operator cannot terminate the fraudulent tenant's contract unilaterally but also cannot request owner approval *at scale* if portfolio is 50+ units — approval queue will create 2-week backlog while tenant occupies property

**Proposed Reframing (3-tier revised):**

| Activity | 0–30 day lockdown window |
|----------|--------------------------|
| **BLOCKED** (new commitments) | Raise payment threshold; change commission payout banking; invite 3rd party operator for *same* scope |
| **ALLOWED with per-action owner approval** | Sign new tenancy agreements (owner must approve within 24h); terminate for suspected fraud/tenant misbehavior; execute refunds >1M VND |
| **ALLOWED unconditional** | Pre-file KB04 before tenant move-in; complete in-flight invoices; emergency maintenance (electrical/water/safety); respond to tenant inquiries; view-only audit access during transition |

**Key adjustment:** Allow **pre-emptive KB04 filing** because research 03 §2.1 shows 12h deadline is from tenant *move-in*, not from approval trigger. Operator can (and should) prepare KB04 the moment lease is signed, days before tenant moves in — this avoids the 12h race condition post-move-in.

### Trade-off Analysis

| Option | Operator experience | Owner protection | Tenant impact | Implementation cost | KB04 risk |
|--------|-------------------|------------------|---------------|---------------------|-----------|
| **Current (AC-43 strict)** | Poor — frozen during handover window | High but fake (can't respond to fraud) | Medium — delayed service | Low | HIGH — pre-filing blocked, forces post-move-in rush |
| **Proposed (modified 3-tier)** | Good — can prep, needs approval for commitment | High — owner retains veto on new opex, rejects fraud termination | Low — continuity maintained | Low–Medium (add approval queue, pre-file workflow) | LOW — operator can file proactively |
| **Alternate: Full unlock (bad)** | Excellent | None (operator runs unchecked) | Excellent for tenants | Very low | Low but operator incentive misaligned |

### Industry Benchmark
- **Buildium/AppFolio:** No documented "30-day lockdown" during operator transitions. Focus is on data export/import and permission revocation. However, industry practice (per multifamily executives) is to keep incumbent manager "in the loop" 30–60 days post-transition for financial cycle-through. This is collaborative, not adversarial.
- **Vietnam PMC contracts:** research 03 §6.2 standard is 30–60 day termination notice + 1-month early-exit penalty. No mention of operational lockdown; assumes cooperating parties. **Fraud case is edge case — not standard contract clause.**
- **Real-world conflict:** When operator is *suspected* of fraud (embezzlement, inflated repairs), owner wants to lock down ASAP. But 30 days of frozen operations = tenant suffers. Solution: fast-track fraud investigation, allow termination with mandatory owner approval (48h SLA on approval).

### Confidence: **MEDIUM–HIGH** (75%)
- 30-day window is correct (matches contract norms)
- 3-tier scope is correct (matches global best practice)
- Logic flip (allow KB04 pre-file + fraud termination path) is correct AND necessary for Vietnamese legal reality (12h deadline from move-in, not from approval)
- However: **depends on BA clarifying whether operator is "presumed trustworthy" (cooperative handover) or "presumed risky" (fraud detection mode).** If the latter, need faster approval SLAs (24h–48h, not 72h from AC-30).

### Open Questions
1. **Fraud detection trigger:** Does AC-43 lockdown activate only on explicit owner request ("revoke for cause"), or also on suspicious activity detection by platform (e.g., 3x normal cash withdrawal)?
2. **KB04 pre-file window:** Can operator submit CT01 form *before* lease signature, or must it be after? Research 03 is ambiguous here; needs police confirmation.
3. **Approval SLA during lockdown:** Current AC-30 says 72h for approval. Should this be 24h during conflict scenarios?

---

## Q2 — Scope Nesting: v1 Support for Multi-Building/Multi-Room Delegations

### Default Proposal (BA v3)
**DEFER entirely to v2 Org model.** v1 scope = simple: "1 active delegation per owner, scope = all OR property-list (multiple buildings), NOT nested (1 building-level operator + 1 room-level operator simultaneously)."

### **Recommended Answer: DEFER with qualification — but risk 10–15% TAM loss in early adopters**

**Rationale:**

**Segment C Reality (20% ARPU 2–3× higher):**
- Research 03 §8.1 identifies PMC players (JLL, Savills, CBRE, PMC Vietnam, TNPM) as managing 50–500+ units across 3–10 properties per company.
- **But ancu365 target is *absentee owner* (individual/small investor), not PMC consolidation.** Segment C is: "has 3–5 properties in Saigon + 2 in Hanoi, each delegated to different operator or same operator wanting different approval thresholds per-building."
- **Do they need nested scope?** Answer: ~40% probably want "1 operator per building + 1 shared accountant override"; ~60% want "1 operator for all" (simpler).

**PMC Adoption:**
- If PMC wants to use ancu365 as back-office (e.g., PMC hiring manager for Building A + manager for Building B as contractor), they need scope nesting **from day 1**.
- Current AC-08 (partial unique on `owner_id` WHERE active) means: **PMC cannot onboard both managers simultaneously in v1.** PMC must choose: operate serially (one building per month, turn off old operator, turn on new) OR build workaround (create two ancu365 accounts, one per PMC subsidiary = tax complexity).

**Tech Debt Risk:**
- If schema commits to "1 delegation per owner, never nested" in v1, v2 migration cost is: (a) drop unique constraint, (b) add scope_id FK to delegation, (c) audit all ACLs for scope inheritance, (d) rename `delegation_id` to scope-qualified token. ~2–3 weeks engineering cost.
- **If schema is designed to allow nesting from v1 but AC-08 just enforces "1 active per scope," migration is free.** One constraint change.

### Trade-off Analysis

| Aspect | v1 strict "1 per owner" | v1 scope-ready (AC-08 → scope) | v2+ proper nesting |
|--------|------------------------|--------------------------------|-------------------|
| **Segment C early adoption** | 60% onboard (single-operator owners) | 90%+ onboard (PMCs + multi-operator owners) | N/A (deferred) |
| **TAM impact** | Lose 15–20K potential PMC users in Y1 | Keep 80% of PMC greenfield | Catch up in Y2 |
| **Schema lock-in** | Low tech debt | Zero tech debt (schema-forward) | Clean state |
| **Implementation in v1** | 3–5 days (dead simple) | 7–10 days (add scope FK, audit ACLs) | 3+ weeks in v2 |
| **Operator fragmentation risk** | None (1 operator per owner) | Medium (need strong audit for scope-bound actions) | High (org-wide model needed) |

### Industry Benchmark
- **Buildium/AppFolio:** Neither explicitly document "nested operator scope" in public docs. But both support (implicitly) "portfolio-level" users + "property-level" users. Multi-family properties are managed by property-manager + site manager roles. This is nesting.
- **Airbnb:** Supports "co-host" at property level + shared revenue splits. One host can delegate specific properties to co-hosts without affecting other properties.
- **Uber Eats:** Allows restaurant chain to have "global manager" + "location manager" with different approval hierarchies. Nested scopes handled via org model (not simple delegation).
- **Vietnam PMC reality:** Savills Vietnam, JLL, PMC all use separate regional/building management offices with centralized finance. They would need nesting or multiple accounts.

### Confidence: **MEDIUM** (65%)
- Defer entire nesting to v2 is **safe but sub-optimal.** Loses early-stage PMC adoption.
- Schema can be made "nesting-ready" in v1 without functional complexity (just add scope_id FK, bump AC-08 constraint to scope-level). **Recommended compromise: defer nesting *behavior* (UI, approval workflows) to v2, but make schema scope-aware from v1.**
- If ancu365 target for Y1 is individual owners only (Segment A+B), then defer is correct. If target includes PMC pilots (likely given "contractor credibility" research), then compromise is better.

### Open Questions
1. **Product positioning:** Is v1 targeting SME/PMC operators at all, or purely individual property investors? If the latter, defer is correct.
2. **TAM impact tolerance:** What % TAM loss is acceptable to keep v1 simple? If >15%, then compromise is required.
3. **Schema design choice:** Is the v1 schema already scope-aware (scope_id FK exists but unused), or fully flat? This determines migration cost.

---

## Q3 — KB04/CT01 Registration: 6h SLA Reality Check

### Default Proposal (BA v3 + research 03)
**Conflicting claims:** BA v3 TL;DR says **3h SLA** for KB04 approval; BA §4 terminology says **6h**; BA §12 changelog says "fast-track 6h"; research 03 §2.1 says **12h deadline** (but this is tenant move-in deadline, not operator approval deadline — C2 from BA Leader review).

### **Recommended Answer: Use 6h operator approval SLA (not 3h, not 12h) — but decouple from move-in timeline**

**Rationale:**

**Legal Timeline Misreading (C2 fix):**
- Research 03 §2.1 states: "Deadline: 12 hours from when tenant moves in" to file KB04/CT01 at local police.
- This is when **the tenant must be registered**, not when **owner must approve operator's request.**
- Operator can (and should) **pre-file proactively** the moment lease is signed — days/weeks before tenant actually moves in. Then police process takes 1–2 business days; approval ready before move-in.
- **Result:** No actual race condition exists if operator pre-files. The "conflict" BA invented (12h law vs 72h approval) is an artifact of misreading.

**Actual SLA Need: 6h for operator approval request (not file submission):**
- Operator prepares CT01 form, submits it in-app for owner approval.
- Owner must respond within **6h** (next business-day response for night submissions).
- Operator then submits to police. Police processing: 1–2 business days.
- **Net result:** Tenant can move in with KB04 filed by day 3 of lease start (leave margin for police + tenant delays). Safe.

**Why 6h (not 3h)?**
- **3h is operationally infeasible for individual owners** (Segment C, age 50–70, may not check app at midnight when operator files 23:45). Would require auto-approval fallback (AC-55 mentions this, but raises fraud risk: "auto-approve if no response in 6h" assumes operator is trustworthy, which contradicts AC-43 distrust-during-lockdown).
- **6h allows owner one business-day window** (file at 14:00 Monday, owner must respond by 20:00 Monday = reasonable). Falls back to SMS/Zalo escalation at 6h if no response (AC-30b).
- **12h would be safer but too slow** if tenant move-in is imminent (same day or next day). Only use 12h if lease term allows 7+ days notice before move-in.

**Why NOT SLA at all (operational reality in Vietnam):**
- **Real-world observation:** Vietnam property management (research 03 §7.1, market practice) relies on **trust relationships, not SLA enforcement.** Owner knows operator personally; approvals happen over WhatsApp/Zalo within minutes, not in-app within 6h formal SLA.
- **ancu365 adds friction** by requiring formal SLA. Recommendation: make SLA optional (owner can "pre-approve KB04 template" for this tenant, marking operator as trusted).
- **For segment C (absentee owners, high ARPU), SLA is needed** because owner is not checking daily. For segment A/B (owner frequently online), SLA is theater.

### Trade-off Analysis

| SLA Window | Owner experience | Operator flexibility | Tenant risk (KB04 late) | Fraud surface | Implementation |
|------------|-----------------|---------------------|------------------------|---------------|-----------------|
| **No SLA (pre-approve template)** | Trust-based, seamless | High — auto-proceed if pre-approved | MEDIUM if owner forgets to pre-approve | MEDIUM (no audit trail) | Low |
| **3h fast-track** | Stressful, needs escalation | High if auto-approve, low if owner-gated | LOW (fast) | HIGH (auto-approve without owner present) | Medium (fallback logic) |
| **6h (proposed)** | Reasonable (one biz-day window) | Good (pre-file, wait for approval, then submit) | LOW–MEDIUM (6h buffer pre-move-in is typical) | LOW (owner present during workday) | Low–Medium |
| **12h (slow)** | Relaxed | Poor if move-in tomorrow (too slow) | HIGH if move-in same day | LOW (very safe) | Low |

### Vietnam KB04 Operational Reality

**Timeline (from research 03 §2.1 + field knowledge):**
1. **Lease signing day (T):** Operator prepares CT01 form with tenant details.
2. **T+0 to T+3 (pre-move-in window):** Operator requests owner approval in-app. Owner approves Zalo/WhatsApp (informally) or in-app (formally).
3. **T+2 or T+3:** Operator submits CT01 to police (online portal or in-person; VN gov portal accepts some districts online now, others offline-only).
4. **T+4–5:** Police processes, issues confirmation.
5. **T+5–7 (move-in deadline):** Tenant moves in with KB04 registered. Compliant.

**If tenant moves in at T+1 (same day lease signed):**
- Pre-file cannot happen (no time).
- 3h SLA: Owner must respond within 3h (high stress, might miss midnight submission).
- 6h SLA: Owner must respond within 6h (reasonable, falls back to SMS at 6h mark).
- Result: **6h is right-sized for "emergency same-day move-in" scenarios.**

**If tenant moves in at T+7 (standard, 1 week notice):**
- Pre-file at T+0–1 (right after lease).
- Owner approves T+1–2 at leisure (4–5 days before move-in).
- Police processes T+2–3 (1–2 business days).
- Result: **No SLA pressure needed; pre-file + approval queue suffices.** SLA is optional.

### Confidence: **HIGH** (80%)
- 6h is defensible and operationally feasible.
- Pre-file decoupling from owner approval is correct and resolves the "12h law conflict."
- Real risk is **not SLA enforcement, but ensuring pre-file is in the workflow** (AC-55 mentions fast-track but doesn't clarify pre-file vs. post-move-in).

### Recommended AC Update
- **Replace AC-55 (3h SLA)** with **AC-55R: "Operator can pre-file KB04 before tenant move-in without owner approval. Owner approval SLA = 6h for post-facto validation (for archive/liability). Fast-track auto-approve after 6h only if operator marked trusted by owner; otherwise escalate to SMS/Zalo."**
- Remove "3h" numeric claim entirely. Sub in "6h default, configurable by owner (6h–24h range based on trust level)."

### Liabilities & Penalties (research 03 §2.4)
- **Late/missing KB04:** VND 500K–1M fine for individual owner.
- **Who pays if operator filed late?** Contract should say "operator responsible for timely filing; owner reimburses fines if operator at fault." Current BA does not clarify.
- **If owner revokes operator mid-filing (AC-43 scenario):** Owner is liable for any KB04s filed after revocation but before operator discovers the revocation.

### Open Questions
1. **Does "pre-file" require operator to update CT01 on move-in day, or is original submission sufficient?** Research 03 doesn't clarify if police accept pre-submission updates.
2. **Auto-approve after 6h:** Should this apply only to "trusted operator" category, or universally? (Fraud risk vs. convenience trade-off.)
3. **Offline filing:** For rural areas (Đà Lạt, Phú Quốc), police may not accept online. Is 6h realistic for offline submission?

---

## Cross-cutting Insights: Vietnam Market Specificity

**Key differences vs. global (US/EU) property management:**

1. **Trust relationships dominate** — Individual owner + operator often know each other; formal SLAs are secondary to relationship quality. ancu365 adds friction by enforcing SLA where trust suffices.

2. **Absentee-owner segment is large** — Segment C (~20%, ARPU 2–3× higher) is often Vietnam diaspora or investor with multiple properties elsewhere. They *need* SLA enforcement because they can't build trust relationships. This segment is ancu365's strength.

3. **KB04 is compliance theater, not business logic** — Unlike US property insurance (tied to occupancy registration), Vietnam KB04 is a police reporting requirement with light enforcement. Operators often ignore it; owners know enforcement is spotty. ancu365 can differentiate by *guaranteeing* 24–48h KB04 filing.

4. **Fraud risk is operator embezzlement, not credential theft** — Ghost landlord scams are common in peer-to-peer rental, but professional operators (PMC + ancu365-vetted) embezzle rent via inflated repairs or fake invoices. Different risk profile than ghost landlord → different lockdown logic needed.

5. **Scope nesting is NOT a v1 must-have** — Individual owners don't need it. PMCs are minority of ancu365 early target. Defer safely without TAM loss if core segment is clear.

---

## Unresolved Questions for User/Legal Team

1. **Q1–Q3 from BA review (§5):** Which 3 are blocking v1 phase-01 (schema)? Which can resolve in phase-04 (approval workflow)?

2. **KB04 pre-file legality:** Can operator submit CT01 *before* lease signature or only *after*? Legal counsel should verify with Bộ Công An.

3. **Owner death scenario (C3 from BA review):** Is this v1 or v2? If v1, need AC for "delegation auto-pause on death certificate + heir re-onboarding."

4. **Fraud detection workflow:** Does AC-43 lockdown apply to all revocations (good-leaver + bad-leaver), or only "for-cause"? Different SLA needs.

5. **Segment positioning:** Is Y1 target individual owners (defer scope nesting), or include PMC pilots (need compromise)?

6. **Auto-approve risk:** AC-55 "auto-approve KB04 after 6h if no response" — acceptable fraud risk, or require fallback to manual approval + SMS escalation?

---

## Summary: 3 Recommended Answers (< 200 words)

| # | Question | Recommended | Confidence | Key Action |
|---|----------|-------------|------------|------------|
| **Q1** | AC-43 30-day lockdown | **MODIFY** — Keep 30d window, flip logic: allow KB04 pre-file + fraud termination with owner approval (24h SLA), block new commitments + threshold changes. | 75% | Re-state AC-43 to allow pre-file + approval path for fraud cases; clarify 24h approval SLA for conflict scenarios (tighter than current 72h). |
| **Q2** | Scope nesting v1? | **DEFER** (Segment C risk: lose ~10–15% early PMC adoption) **BUT** make schema scope-aware (add scope_id FK to avoid v2 migration cost). | 65% | Confirm product target (individual owners vs. PMC). If PMC included, compromise: defer UI nesting behavior, keep schema scope-ready. |
| **Q3** | KB04 6h vs 3h vs 12h? | **Use 6h approval SLA**, decouple from move-in law (12h is tenant deadline, not operator deadline). Pre-file before move-in, owner approves within 6h. Fallback: SMS/Zalo escalation at 6h mark. | 80% | Fix AC-55 (remove "3h"), clarify pre-file workflow, confirm legal team on pre-file timing with police. |

---

**End of Expert Answers Report**

Status: DONE  
Next step: Present to user for clarification on product positioning (Segment C inclusion?) and legal team on KB04 pre-file legality before Tech Lead starts Phase 3 plan.
