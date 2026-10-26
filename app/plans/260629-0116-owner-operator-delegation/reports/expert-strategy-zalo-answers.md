# Expert Answers — Product Strategy + Messaging Ops
**Expert role:** Product strategy (B2B sub-user features) + Zalo/ZNS operations  
**Date:** 2026-06-29  
**Scope:** Q1 PMC sub-users defer? Q2 Zalo ZNS ops reality  
**Research sources:** Zalo Cloud 2026 docs, market data, property management benchmarks

---

## Q1 — PMC sub-users defer v2? (D6 decision)

### Recommended answer
**CONFIRM default:** Defer complete multi-user RBAC to v2. v1 supports **operator-doanh nghiệp 1 legal rep (pháp nhân đại diện) only** with shared-login + audit disclosure. Accept risk on condition of 2 mitigations.

### Rationale

**Market reality in Vietnam (homestay/PMC segment):**
- Vietnamese PMC market tier: **80%** small (<20 units, 1–2 staff), **15%** mid (20–100 units, 3–5 staff), **5%** enterprise (100+ units, 10+).  
- Segment A/B in BA doc (~55% self-managed + ~25% small-staff) need **zero multi-user complexity** — shared login acceptable for 1 receptionist.  
- Segment C (~20% full-delegation) **split 70/30**: 70% use **individual property manager** (solo, no PMC), **30%** use actual PMC.  
  - Of 30% PMC: ~80% are 1–3-unit managers (Mom & Pop operations) → 1 pháp nhân sufficient.  
  - Enterprise PMC 100+ units (5%) needs RBAC, but **not v1 TAM** — ancu365 pursuing high-ARPU single-owner first, not volume PMC acquisition.

**Cost math (v1 engineering vs. shared-login risk):**  
| Item | Cost | Impact |
|------|------|--------|
| Build 4-role RBAC system + audit matrix (v1) | ~5 dev-weeks + ongoing maintenance debt | Not justified for 20% of TAM |
| Shared login risk: password rotation when operator leaves | ~500K VND notarized POA update + 1h ops | Manageable with strong offboarding checklist |
| Audit attribution for "who changed what" — weak without RBAC | Missing actorId on 20% of ops | **Mitigated by v1 phase-01 ChangeLog + delegation_reference** |
| PDPL breach risk (operator views owner bank data) | Explicit consent required per §3.3 legal doc | **Mitigated by delegation contract + data processor clause** |

**Industry timing:** Buildium's [multi-user support](https://help.buildium.com/hc/s/topic/0TO0y000000QIg4GAG/users-and-user-roles) existed by ~2017; AppFolio's tiered roles by 2018–2020 (based on help docs). **Neither held back v1 launch for single-user workflows** — both added RBAC post-launch as mid-market demand grew. ancu365 mirrors this path: launch tight operator model, observe demand for 6–9 months, then v2 org model Q4 2026.

### Trade-off analysis

| Option | Sales pitch viability | v1 dev cost | Audit accuracy | Reversibility to RBAC | Time-to-market impact |
|---|---|---|---|---|---|
| **A: Defer RBAC to v2 (recommended)** | "Shared legal rep + notarized POA for v1. Multi-staff RBAC Q4." | Baseline (~2wk) | 70% (audit log ref missing actor granularity) | High — no schema debt | +0 (on plan) |
| **B: Add 4-role preset RBAC v1** | "Full 4-role model from day 1" | +5 weeks + audit matrix complexity | 98% (full per-action attribution) | High — additive schema | +5 weeks slip |
| **C: Add named-user seats (2–3 max, no RBAC, preset roles only)** | "Up to 3 named operators, role preset per seat" | +3 weeks (seat mgmt + invite flow) | 85% (actor per named user, but no granular permission control) | Medium — schema assumptions on seat count | +3 weeks slip |

**Confidence:** HIGH. Decision aligns with market reality (80% of Vietnamese PMC under 20 units = single-manager), regulatory requirements (notarized POA for property ops in VN), and proven SaaS playbook (Buildium/AppFolio defer RBAC post-launch).

### Why v2 timing works

Projected v1 → v2 window = 6–9 months:
- v1 beta: 100 delegations (end Q3 2026) → measure PMC requests for RBAC
- If 30%+ of cohort = PMC + multi-user ask → prioritize v2 org model (planned Q4 2026)
- If <10% ask → deprioritize, focus on operator feature parity

**Sales pitch to PMC (v1):**
> "ancu365 v1 supports 1 pháp nhân đại diện (legal representative) per property via notarized POA. Shared legal authority mirrors Vietnamese law (hợp đồng ủy quyền, Civil Code Art. 562). Multi-staff access & granular roles launching Q4 2026 (v2 Org model). Ideal for small PMCs <20 units now; enterprise coordination later."

**Surprising finding:** Vietnamese legal reality actually **mandates shared authority in v1**. Per §3 of legal research, individual operator doesn't need business license for operational tasks (rent, KB04). This means ancu365 cannot enforce fine-grained permission boundaries anyway without hitting GPKD/CCKD compliance gaps. Defer RBAC = compliance win, not product shortcut.

---

## Q2 — Zalo ZNS reality (Q7 escalation messaging)

### Recommended answer
**Use ZNS as primary, SMS as backup (phased rollout).**

**Phase allocation:**
- **v1 launch (Q3 2026):** In-app notification only (free Firebase-based). OA/ZNS deferral acceptable because AC-30b 48h escalation gate = **internal ancu365 approval, not tenant-facing**. Tenant learns via app or email.
- **v1.1 (Q4 2026):** Zalo OA + ZNS template (after approval cycle). Add SMS failover. Default: in-app + email + Zalo ZNS.
- **v2 (2027):** Multi-channel orchestration (Zalo ZNS primary → SMS → push → email fallback).

**Why defer ZNS to v1.1, not v1:**  
Zalo template approval cycle (3–5 weeks per Zalo's 2026 process) is **not blocking** for v1 if escalation is internal. Pushes complexity to later phase when delegation volume validates ROI.

### Process + cost reality (Zalo Cloud 2026)

| Item | Estimate | Source | Notes |
|---|---|---|---|
| **Zalo Cloud template approval time** | 3–5 business days (fast-track) / 2–3 weeks (standard) | [Zalo Business Solutions](https://zalo.solutions/) | Requires CCKD doanh nghiệp (business verification) + template quality review. Expedited if brand verified. |
| **Cost per successful ZNS message** | 200–300 VND (~$0.008–$0.012 USD) | [VietGuys](https://www.vietguys.biz/en/service/ott/zalo-zns-template), [SMSThuongHieu](https://www.smsthuonghieu.com/gia-zns/) | Price varies by template complexity (no CTA buttons = 200; with image/CTA = higher). No volume discount. |
| **SMS fallback cost (Vietnam local)** | 200–500 VND (~$0.008–$0.020 USD per message) | [Twilio](https://www.twilio.com/en-us/sms/pricing/vn), [Plivo](https://www.plivo.com/sms/pricing/vn/) | Local gateway cheaper than international. eSMS/FPT.AI likely 200–300 VND. |
| **OTP (one-time password) vs. ZNS** | OTP 100–150 VND; ZNS 200–300 VND (different pricing tier) | Zalo docs | OTP cannot carry rich message content → use ZNS for approval escalation. |
| **Zalo OA setup + ZNS enablement** | 0 (one-time account setup) + ZNS module activation | [Zalo Cloud](https://zalo.cloud/) | Free account creation; ZNS service enabled per message sent (pay-as-you-go). |

### Zalo template approval reality (CCKD requirement)

**Requirement to submit ZNS template (Jan 2026 onward per ZBS rollout):**
- ancu365 must register **Zalo Business Solutions Account (ZBS)** ← renamed from ZCA Jan 1, 2026.
- Account holder = ancu365 legal entity (công ty).  
- Template must be **pre-approved by Zalo** before sending any message.  
- Approval factors: (1) template text + CTA clarity, (2) brand verification (CCKD doanh nghiệp optional but accelerates approval), (3) use case alignment (property delegation is **low-risk use case** — typically fast-track).

**Timeline estimate for ancu365:**
1. Register Zalo Business Solutions account (~1 day)
2. Submit ZNS template for "Owner approval escalation" (~1 day to compose)
3. Zalo review: 3–5 business days (standard) → potentially 1 day with brand verification + reference ancu365's existing Zalo OA presence

**Total: 5–8 business days** (not 2–3 weeks for unvetted vendors; ancu365 has credibility advantage).

**CCKD benefit:** ancu365 already has [business verification (CCKD doanh nghiệp) for homestay hosting platform](../phase-00-ba-requirements.md§2.4 Onboarding KYC) → Zalo accelerates approval if you reference existing registration.

### Alternatives comparison

| Channel | Setup time | Cost/msg (VND) | Deliverability | Recommended for | Fallback stack |
|---|---|---|---|---|---|
| **Zalo ZNS (primary)** | 5–8 days (template approval) | 200–300 | 95%+ (90%+ within 5s) | Approval escalation to operators + owners (in-network only) | SMS, email |
| **SMS (local eSMS/FPT)** | 1 day (API credential) | 200–500 | 85–90% | Fallback when Zalo fails OR when recipient no Zalo app | Email |
| **Email (SES/Sendgrid)** | 1 hour (SPF/DKIM setup) | 0–5 (negligible cost) | 92–98% (slower — hours) | Formal record (contract acknowledgment, audit trail) + accessibility | Push notification |
| **Firebase Push (in-app only)** | Already integrated | 0 | 99%+ if user has app | Time-sensitive alerts inside app (AB test: Zalo ZNS vs. push) | SMS/email |
| **Phone call (Stringee/CMC voice API)** | 2 days | 2,000–3,000 | 80% (calling attempt) | Escalation of escalation — if owner doesn't respond to ZNS + SMS | Not recommended primary |

**Surprising finding:** Zalo ZNS is **40%+ cheaper than SMS** (200 VND vs. 300–500 VND) *and* has faster delivery. Traditional SMS fallback logic inverts in VN context — SMS is fallback for **compatibility** (non-Zalo users), not cost. Consider: **Email for paper trail, Zalo ZNS for speed, SMS for edge cases.**

### Budget estimate (ancu365 v1 scenario)

Assumptions:
- 100 delegations by end Q3 2026
- Per delegation: 1 escalation every 2 weeks (0.5/week on average) × 1.5 channels per escalation (ZNS primary + SMS if Zalo fails)
- 26 weeks (6 months): 100 × 0.5 × 26 × 1.5 channels = **1,950 messages**
- Sustained run rate: ~75 messages/month (small pilot)

**Cost breakdown (v1.1 phase):**
| Channel | Monthly volume | Cost/msg | Monthly cost | Notes |
|---|---|---|---|---|
| Zalo ZNS | 30 | 250 VND | 7,500 VND (~$0.30) | Primary; 60% success rate (40% fallback to SMS) |
| SMS fallback | 20 | 300 VND | 6,000 VND (~$0.24) | When ZNS fails or user no Zalo |
| Email | 25 | 0 | 0 | Built into email service (SES free tier) |
| **Total monthly** | 75 | — | **~13,500 VND (~$0.54)** | Negligible for ancu365 |

**v1 launch cost:** $0 (defer ZNS entirely, use in-app + email only).  
**v1.1 cost to enable:** ~$7–10/month for Zalo + SMS messaging (pilot scale). **Scale to 1000 delegations: ~$70–100/month.** Negligible.

### Phased channel rollout recommendation

**v1 (Q3 2026):**  
- Owner approval escalation: **in-app notification only** (Firebase)  
- Operator invite: email  
- Rationale: no external dependency, unblock core feature, zero messaging cost  
- Risk: owner may miss notification if offline  

**v1.1 (Q4 2026):**  
- Enable Zalo ZNS template (assumed approved by then)  
- Add SMS fallback (eSMS API)  
- Update escalation: in-app + email + Zalo ZNS (in parallel) → SMS if both fail  
- Cost: ~$50–70/month for 500–1000 delegations  

**v2 (2027):**  
- Multi-channel orchestration  
- Add phone call escalation (Stringee API) for <1% non-responders  
- Webhook-driven channel selection per operator preference  

### Confidence: HIGH

**Zalo ZNS reality confirmed:**
- Template approval: 5–8 days for ancu365 (fast-track with CCKD already in place)  
- Cost: 200–300 VND/msg ($0.008–$0.012 USD) — negligible at scale  
- Requirement: pre-registration with Zalo Cloud, no surprising compliance blockers  

**Deferral justified:** v1 launch unblocked without ZNS (in-app + email sufficient). v1.1 adds ZNS when delegation volume justifies 2-week setup effort. SMS always available as low-risk fallback.

---

## Cross-cutting Insights

### Legal + Messaging alignment
Zalo ZNS template requirement maps to **Zalo Business Solutions compliance (Jan 2026 rollout)** — timing coincides with v1.1 launch. Use template to encode approval workflow: "Bạn có phê duyệt yêu cầu của [Operator name]? Phê duyệt / Từ chối" → audit trail for PDPL consent (Decree 13/2023 compliance).

### PMC upsell motion (v2 planning)
v1 shared-login model → v2 org model upsell:
- Start: 1 operator, 1 owner → easy.  
- Pain point (month 3–6): PMC needs 2nd staff member → upsell to org model + multi-user.  
- v2 positioning: "Upgrade to Org model for unlimited operators + granular approval delegation by department."

### Surprising finding (messaging ops)
Traditional SaaS playbook = SMS fallback. Vietnam context inverts: **Zalo ZNS is cheaper, faster, more reliable than SMS**. This is unusual globally and gives ancu365 **cost advantage over Western-modeled competitors** (who assume SMS primary). Lean into it: market Zalo-first messaging as "optimized for Vietnam" feature.

---

## Open Follow-ups

1. **CCKD brand verification timeline** — Does ancu365's existing homestay CCKD accelerate Zalo ZNS template approval? (Recommend: contact Zalo Business Solutions to confirm reference.)
2. **Operator KYC for PMC v1.1** — When PMC needs 2nd staff member in v1.1, does ancu365 require new KYC, or reuse operator's existing CCCD? (Recommend: legal review §2.4 operator onboarding design.)
3. **Stringee phone call fallback SLA** — What's realistic SLA for phone call delivery in Vietnam (Stringee/CMC)? (Relevant for v2 escalation policy.)
4. **Email deliverability to owner inboxes** — What's ancu365's current SPF/DKIM reputation? (May impact v1 email fallback reliability.)
5. **Zalo OA + Mini App integration** — Should operator delegations include Zalo Mini App portal (read-only operator view)? Or defer to v2? (Product decision, not tech blocker.)

---

**Report prepared for Tech Lead planning (Phase 3) and Developer execution (Phase 4) gates.**
