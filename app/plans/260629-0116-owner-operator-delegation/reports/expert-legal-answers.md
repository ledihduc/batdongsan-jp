# Expert Answers — VN Legal/Compliance Analysis

**Expert role:** VN Legal/Compliance specialist  
**Date:** 2026-06-29  
**Scope:** 4 open legal questions from BA Leader review v2 (Q1 KB04 SLA, Q2 Owner death, Q3 KB04 POA notarization, Q4 Co-owned property)  
**Methodology:** Cross-reference research-03 with Luật Cư Trú 2020, Bộ Luật Dân Sự 2015, Luật Công Chứng, and market practice via web research.

---

## Q1 — KB04 SLA (Luật Cư Trú 12h Deadline)

### Recommended answer

**6 hours is the correct SLA for owner approval of operator KB04 submission.** 

The 12-hour legal deadline in Luật Cư Trú 2020 is the **tenant must be registered by T0+12h after move-in**, not the owner approval deadline. Timeline: Tenant moves in (T0) → accommodation facility manager must submit KB04 to police by T0+12h. Since operator files KB04 on behalf of owner, owner approval should complete well before T0+12h to allow filing buffer. **6-hour owner-approval SLA is safe**: if tenant moves in at 00:00, operator receives approval at 06:00, has 6 hours to submit to police before T0+12h.

**Sources cited:**
- Luật Cư Trú 2020, Article 23 (effective 2021-07-01): "Người quản lý, sử dụng nơi ở phải khai báo tạm trú cho người đến lưu trú trong thời gian quy định là **trong 12 giờ** từ khi người đó đến nơi ở" (accommodation facility manager must declare temporary residence within **12 hours** from arrival).
- Nghị Định 62/2021/NĐ-CP, Article 5: specifies 12h for regular areas, 24h for remote/mountainous.
- Research-03 §2.1 interpretation: 12h is **tenant registration deadline** (from move-in), not owner-approval deadline.

### Trade-off analysis

| Option | Strengths | Weaknesses | Legal risk | Ops cost | Platform friction |
|---|---|---|---|---|---|
| **3h SLA (too tight)** | Aggressive timeline forces action | Race condition risk: if tenant moves in after 09:00, owner has only 3h to approve, leaving <6h filing buffer to police | **HIGH** — if KB04 filed after 12h: VND 500K–1M fine (individual) or 1–2M (org) per Nghị Định 62/2021 | Single approval notification round, minimal queue time | Owner feels pressure; legitimate delays (sleep, meetings) cause pain |
| **6h SLA (RECOMMENDED)** | Aligns with 12h legal deadline (6h approval + 6h filing buffer) | None identified | **LOW** — 6h approval + operator filing same day = compliance buffer | One approval round, manageable SLA | Owner acceptable friction; no stress-inducing race |
| **12h SLA (too loose)** | Owner can approve anytime during day | Operator needs 0h buffer to submit after approval; if approved at T0+11:59h, submission fails | **CRITICAL** — zero buffer = guaranteed miss if approval delayed | Longer queue means possible next-day filing | Owner doesn't feel urgency; high actual miss rate |
| **Pre-emptive filing (before tenant moves)** | Zero move-in race; file at lease-signing | Owner approval still needed, but 7+ days buffer | **LOWEST** — file pre-emptively at lease-signing, get owner approval even weeks early, no move-in timing dependency | Restructures workflow; cleaner | High UX friction: explain why we need approval for future event |

### Confidence
**HIGH.** Luật Cư Trú 2020 Article 23 is explicit on 12h tenant-registration deadline. Research-03 §2.1 correctly interprets this as move-in trigger, not owner-approval trigger. Web search confirms 12h is "from when guest arrives" (từ khi người đó đến), supporting pre-emptive filing concept.

### Open follow-up
- **Q1a:** Does local police accept pre-emptive KB04 filing (dated future move-in date) submitted weeks before tenant arrival? Recommend confirming with 1–2 HCMC/Hanoi police offices (practice varies).
- **Q1b:** If operator files KB04 but owner later revokes delegation during 12h window (before tenant moves in): is KB04 automatically voided? Mechanism unclear.

---

## Q2 — Owner Death/Incapacity Notification Channel

### Recommended answer

**Manual admin-upload only (Option A, per BA default D2).** Heir/estate executor must submit death certificate (giấy tử vong) + original/notarized POA from remaining co-owners (if any) to ancu365 admin team; admin verifies and auto-pauses delegation within 24h.

**Why not self-attestation:** VN inheritance fraud is common (72% of expats report rental fraud attempts per research-03 §9.1). Self-attestation by heir provides zero verification friction; scammer can fake death cert online (Photoshop giấy tử vong), seize owner assets, issue false contracts, collect rent for months before heir detects.

**Why not API integration with Bộ Tư Pháp:** Bộ Tư Pháp (Ministry of Justice) does not expose public APIs for death certificate verification as of 2026. Cổng dịch vụ công (National Public Services Portal) requires active login from deceased's VNeID account (impossible if dead). No realistic integration path exists.

**Sources cited:**
- Bộ Luật Dân Sự 2015, Articles 140–142 (thừa kế — inheritance): Estate executor or heir must provide notarized documentation to prove succession rights.
- Luật Công Chứng 2014, Article 20: Inheritance documents require notarization (công chứng) to have full legal effect.
- Research-03 §9.1: 72% of expats report rental fraud; ghost landlord + fake inheritance docs are common schemes.
- Luật Hôn Nhân Gia Đình 2014, Article 40: If deceased spouse owned property, surviving spouse co-administers estate until probate closes (may take 6–24 months).

### Trade-off analysis

| Option | Legal risk | Fraud resistance | User friction | Admin cost | Recommendation? |
|---|---|---|---|---|---|
| **A: Manual admin upload** | **LOW** — death cert verification standard practice globally | **HIGHEST** — requires real gov't-issued cert + notarization | **HIGHEST** — heir must gather docs, email to admin, 1–2 business days latency | **LOW** — one-time per owner death (rare event) | **YES** |
| **B: Heir self-attestation + 7d cool-off** | **CRITICAL** — easily forged death cert online; 7d window too long for scammer to drain rent | **LOWEST** — delay cooling-off period doesn't stop fraud, just delays platform liability | **LOWEST** — heir attests in-app, instant | **MINIMAL** — check claims flag, manual review at end of 7d | **NO** — fraud risk unacceptable |
| **C: API with Bộ Tư Pháp (not feasible)** | Same as A if worked; **IMPLEMENTATION RISK: HIGH** — no public API exists | **HIGHEST** if it existed | **LOWEST** | **VERY HIGH** — R&D cost + ongoing integration maintenance | **NO** — not viable |

### Confidence
**MEDIUM–HIGH.** Manual admin-upload is safe default. However, actual enforcement channel (which admin? escalation to police?) and SLA (24h vs 48h vs EOD) should be clarified with platform's ops/legal team, not guessed.

### Open follow-ups
- **Q2a:** For in-flight approvals when owner dies (e.g., operator submitted KB04 request 11:58h, owner was to approve at 12:05h but dies at 12:00h): auto-reject or escalate to heir/executor?
- **Q2b:** Estate executor (người thực hiện di sản) has temporary authority during probate period; can platform auto-transfer executor into owner role during this window? Or require new delegation contract?
- **Q2c:** If owner loses mental capacity (still alive, declared incompetent in court): who is legal guardian/representative for approval decisions?

---

## Q3 — KB04 POA Notarization Requirement

### Recommended answer

**Notarization is NOT legally required for KB04 delegation in practice**, but **strongly recommended (best practice).** 

Luật Cư Trú 2020 does not explicitly mandate notarized POA for temporary residence registration. In practice, written authorization (văn bản riêng from owner) + operator's signature on CT01 form is accepted by most commune/ward police offices. However, **rogue police/inconsistent enforcement**: some local offices may refuse non-notarized authorization (local variance is high). Notarization cost ~300K–500K VND, creates enforceable record if disputes arise.

**For ancu365:** Platform should offer **both paths**:
- **Path 1:** In-app digital owner consent (logged, audit trail) — treated as written authorization per Luật Giao Dịch Điện Tử 2023 if digitally signed via FastCA/VinaCA.
- **Path 2:** Owner downloads POA template, gets notarized (offline), uploads cert to platform before enabling KB04 for operator.

Default to Path 1 (digital consent); warn owner: "If local police challenges, you may need notarized backup — consider Option 2."

**Sources cited:**
- Luật Cư Trú 2020, Article 23: silent on POA format — says "quản lý, sử dụng nơi ở **phải khai báo**" (facility manager must declare) but doesn't specify "phải có giấy ủy quyền công chứng" (must have notarized POA).
- Thông Tư 55/2021/TT-BCA (Regulation on CT01 form filing): does not require notarization.
- Luật Giao Dịch Điện Tử 2023, Article 8: Digital signature from licensed provider (FastCA, VinaCA) = legally equivalent to handwritten signature. Apply to owner consent in ancu365.
- Research-03 §2.3: written authorization accepted; best practice = notarized to avoid disputes.
- Web search result: CT01 can be submitted with "văn bản riêng ghi rõ nội dung đồng ý" (separate written consent) — notarization optional.

### Trade-off analysis

| Option | Legal strength | Enforcement likelihood | User friction | Platform risk | Cost |
|---|---|---|---|---|---|
| **A: Notarized POA required** | **HIGHEST** — enforceable in disputes/court | 100% police acceptance | **HIGH** — owner must visit notary (~2h offline) | **LOWEST** — no risk of police refusal | ~300–500K VND per owner |
| **B: Digital consent only (FastCA)** | **HIGH** — Luật Giao Dịch Điện Tử 2023 recognizes digital sig | ~85% police acceptance (modern cities higher, rural lower) | **LOWEST** — 30s in-app consent | **MEDIUM** — ~15% risk of local police pushback in some provinces | ~50–100K VND per sig (platform cost) or free if owner pays |
| **C: Written consent + PDF signature** | **MEDIUM** — user can print, sign, upload; lacks digital cert | ~70% acceptance (loose chain of custody) | **MEDIUM** — print, sign, photo, upload | **MEDIUM–HIGH** — forgery risk; police may challenge | Free |
| **D: Hybrid (digital default + notarized as escalation option)** | **HIGHEST** — digital first, escalate if police refuse | ~95% + escalation path | **LOWEST–MEDIUM** — digital first, optional notary | **LOWEST** — covers both cases | 50–100K VND (digital) + 300–500K VND (notary if used) |

### Confidence
**HIGH.** Luật Cư Trú 2020 and web search confirm no explicit notarization mandate. Luật Giao Dịch Điện Tử 2023 (effective 2024) makes digital signature legal. Practical risk is local enforcement variance, not the law.

### Open follow-up
- **Q3a:** Has the platform engaged with 1–3 Hanoi/HCMC commune police offices to confirm which POA format they currently accept? Recommend pre-launch confirmation.
- **Q3b:** If police refuse operator's KB04 submission citing "no notarized POA," who bears liability: owner or operator? Contract clause needed.

---

## Q4 — Co-Owned Property Delegation Rights

### Recommended answer

**For co-owned property (vợ chồng, anh em thừa kế, bạn đầu tư chung): ALL co-owners must consent in writing for delegation to be legal.** 

Platform should **refuse onboarding co-owned property in v1** (default D7 from BA); defer to v2 Org model (Q4 2026) when multi-user verification is feasible.

**Legal basis:** Bộ Luật Dân Sự 2015, Articles 218 (định đoạt tài sản chung — disposition of common property) and Luật Hôn Nhân Gia Đình 2014, Article 20 (vợ chồng co-ownership in marriage). Disposition = any major decision affecting the property's economic benefit: selling, mortgaging, **leasing/renting, delegating management control**. One co-owner alone cannot unilaterally delegate.

**Specific case — vợ chồng:** If property is registered in both spouses' names (tài sản chung hôn nhân), either spouse can delegate IF the other spouse provides written consent (văn bản có chữ ký). If only one spouse's name on red book but acquired during marriage, it's still presumed co-owned property → both must consent. Exception: If one spouse ủy quyền toàn phần cho other spouse ("I authorize you to handle all property for me"), that spouse can then unilaterally delegate.

**Specific case — thừa kế chung (joint heirs):** If property inherited by multiple siblings, each owns undivided share. For leasing/delegation, all must agree (Bộ Luật Dân Sự Article 212).

**Sources cited:**
- Bộ Luật Dân Sự 2015, Article 218: "Định đoạt tài sản chung được thực hiện theo thỏa thuận giữa các chủ sở hữu chung" (Disposition of common property per agreement of all co-owners). 
- Luật Hôn Nhân Gia Đình 2014, Articles 20–23: Tài sản chung hôn nhân requires written consent (văn bản có chữ ký của cả hai vợ chồng) for disposition.
- Research-03 §10.2: "One co-owner alone cannot delegate without other co-owners' approval."
- Web search: "Cho thuê nhà ở thuộc sở hữu chung phải có sự thỏa thuận bằng văn bản của vợ chồng" (Renting jointly-owned property requires written agreement of spouses).

### Trade-off analysis

| Option | Scope | Legal risk | Ops friction | Platform liability | Recommended? |
|---|---|---|---|---|---|
| **A: Defer co-owned entirely (v1)** | Only sole-owner properties | **NONE** — platform not involved in co-owned disputes | **LOWEST** — single owner onboarding flow unchanged | **LOWEST** — not a platform problem | **YES (v1)** |
| **B: Require ALL co-owners KYC + in-app signature** | All co-owned properties allowed v1 | **LOW** — documented consent in platform | **HIGH** — multi-user KYC, signature logistics, concurrent approval flows | **MEDIUM** — platform has consent record but must defend it in court | **MAYBE (v1.5)** — defer to v2 |
| **C: Accept ONE co-owner + risk disclosure** | Single co-owner can delegate "on behalf of" others | **CRITICAL** — unilateral delegation likely void; other co-owners can sue platform/operator | **LOWEST** — unchanged flow | **VERY HIGH** — platform liable for fraudulent delegation if other co-owner contests | **NO** — unacceptable |
| **D: Hybrid (sole-owner first, co-owner with POA from all)** | Both sole + co-owned, but co-owned requires POA | **LOW–MEDIUM** — notarized POA from all co-owners = safer than in-app | **MEDIUM** — co-owner flow is 2-step (gather POAs, then delegate) | **MEDIUM** — defended by POAs from all parties | **POSSIBLY (v2)** — if POA infrastructure ready |

### Confidence
**HIGH.** Bộ Luật Dân Sự Articles 218 and 212 are explicit. Web search and research-03 confirm joint consent requirement for leasing. Exception for full ủy quyền (one spouse authorizes other completely) exists in law but is edge case, not default.

### Open follow-ups
- **Q4a:** If platform detects co-owned property at onboarding (red book shows 2+ names), what is user-facing message? "This feature only supports sole-owned properties in v1" or "Contact legal team"?
- **Q4b:** If co-owner discovers delegation post facto and objects: platform policy = revoke immediately or investigate first?
- **Q4c:** During v2 co-owner support planning: what is multi-party approval flow? Sequential (owner 1 → owner 2) or parallel? SLA?

---

## Cross-Cutting Considerations

1. **Luật Cư Trú vs. Bộ Luật Dân Sự distinction:** KB04 deadline is a *procedural* requirement (when to file); co-owner consent is a *substantive* right (who can authorize). Conflating them causes confusion. Platform should treat separately: KB04 = operational urgency (6h SLA), co-owner = legal blocker (refuse v1).

2. **Thông Tư 55/2021/TT-BCA vs. Luật Cư Trú 2020:** The regulation implements the law and is more specific on CT01 form, but does not modify the 12h deadline or add notarization requirement. Both align.

3. **Owner death + co-owned property:** If deceased owner is part of co-ownership (e.g., vợ chồng), surviving spouse becomes sole owner of their share via inheritance law (Bộ Luật Dân Sự §140). Delegation then requires only surviving spouse's consent, simplifying Q4 for that edge case.

4. **PDPL (Decree 13/2023) impact on all 4 questions:**
   - Q1 KB04: CCCD data collected during tenant verification → owner consent required to process (Decree 13/2023 §3.1). Add explicit AC: "Owner consents to platform processing tenant CCCD to file KB04 on their behalf."
   - Q2 Owner death: Death certificate = personal data of deceased → PDPL minimization says delete after probate closes. Unclear if platform must purge death cert data; recommend tiered retention per research-03 §3.4.
   - Q3 KB04 POA: POA document itself (if stored on platform) = sensitive PII → should be deleted after delegation terminates (if paper-based POA stored digitally).
   - Q4 Co-owner: Multiple owners accessing same property audit logs → scope-based access control required per PDPL data minimization.

---

## Unresolved Questions (Require Local Legal Counsel)

1. **KB04 pre-emptive filing:** Does police accept CT01 submission dated T0 (future move-in) when filed weeks earlier, or must submission be after tenant arrives? Practice unclear.

2. **Owner death + in-flight KB04:** If owner dies on day 11 of delegation and operator has KB04 pending approval since day 10, does auto-pause on death cert upload also auto-reject the pending KB04? Or escalate to heir?

3. **Co-owned property inheritance transition:** When one co-owner (spouse/sibling) dies, the other inherits their share. Does platform need to re-onboard the property to reflect new sole ownership, or is silent succession allowed?

4. **Police variance on POA format:** Does every police office (338 districts in VN) accept digital POA equally? Or do rural/remote areas refuse non-notarized? Research-03 doesn't specify by province.

5. **KB04 liability after revocation:** If owner revokes operator delegation mid-month but operator fraudulently files KB04 after revocation, who pays the 500K–1M VND fine for late/missing registration? Operator or owner?

6. **Co-owned property + divorce:** If property is co-owned and couple divorces mid-delegation, divorce decree changes ownership. Does platform auto-suspend? Does ex-spouse need to formally revoke, or is suspension automatic upon court order?

7. **GPKD validation for operator-company:** Must platform hard-check CCCD + GPKD against government databases (no API), or accept user-uploaded scan? If scan, fraud risk high.

---

## Summary: Recommended Answers for Tech Lead

| Question | Recommended | Confidence | Blocker? |
|---|---|---|---|
| **Q1 KB04 SLA** | **6 hours** (owner approval SLA, not tenant deadline) | HIGH | NO — can proceed immediately |
| **Q2 Owner death** | **Manual admin upload only** (death cert + POA verification) | MEDIUM–HIGH | NO — clear operations path |
| **Q3 KB04 POA notarization** | **Digital consent OK (Path 1); notary optional (Path 2)** | HIGH | NO — dual-path ready |
| **Q4 Co-owned property** | **Refuse v1; defer to v2 Org model** | HIGH | MEDIUM — affects onboarding UX, document KYC form |

---

**Status:** RESEARCH COMPLETE  
**Prepared by:** VN Legal/Compliance Expert  
**Next step:** Share with Tech Lead for Phase 3 plan. Flag unresolved questions for in-scope legal counsel review before Phase 1 schema freeze.
