# Pre-launch Gates Checklist — Owner-Operator Delegation v1

**Plan:** `plans/260629-0116-owner-operator-delegation/`
**Generated:** 2026-06-29
**Owner:** Tech Lead + Legal + Ops
**Source:** BA v4 §14 + plan.md "Pre-launch validation gates"

---

## Gate Status Legend

| Symbol | Meaning |
|--------|---------|
| OPEN | Not started — awaiting external action |
| IN_PROGRESS | External party engaged, awaiting response |
| CLOSED | Evidence received and verified |
| BLOCKED | Blocked on dependency |
| N/A | Not applicable to v1 scope |

---

## Gate Table

| Gate ID | Description | Owner | Blocks | Current Status | Evidence Required | Escalation Path |
|---------|-------------|-------|--------|----------------|-------------------|-----------------|
| **O1** | Police pre-file CT01 acceptance — confirm ≥1 phường in HCMC and ≥1 in Hà Nội accept CT01 submission BEFORE tenant move-in (4 districts: HCMC Q1, Q7; HN Hoàn Kiếm, Cầu Giấy) | Legal + Ops | AC-55b (KB04 pre-file pathway); phase-04 merge freeze | OPEN — awaiting evidence | Written confirmation from ≥2 district police stations (1 HCMC + 1 HN min). Email or physical letterhead accepted. | Legal lead → Product sponsor → defer pre-file pathway to v1.1 patch |
| **O2** | Police digital POA acceptance — confirm which districts accept FastCA/VinaCA digital signature on KB04 authorization | Legal | AC-55d (POA format default); phase-05 freeze | OPEN — awaiting evidence | Written confirmation from same districts as O1. If rejected: O2=CLOSED with fallback=notarized. | Legal lead → default all POA to notarized if no district accepts digital → close O2 as N/A |
| **O3** | Legal counsel sign-off on AC-58d executor exception — in-flight approvals may be decided by heir/executor within 7d pause | Legal counsel (external) | AC-58d; phase-06 merge freeze; `ENABLE_EXECUTOR_DECIDE_EXCEPTION` feature flag | OPEN — awaiting evidence | Written sign-off memo from legal counsel on file. Memo states: (a) executor may act on pending approvals during 7d pause window, (b) liability exposure acceptable, (c) suggested indemnity clause. | If sign-off refused → flag stays OFF; executor exception path disabled permanently for v1; note in product roadmap |
| **O4** | NHNN intermediary license scope confirmation for v2 auto-commission transfer | Corporate counsel (external) | v2 auto-transfer commission (NOT v1 blocker) | OPEN — v2 gate; not required for v1 launch | Corporate counsel memo on: (a) whether auto-commission transfer requires payment intermediary NHNN license, (b) safe-harbor pathway if any, (c) recommended v2 implementation mode. | If license required → v2 commission auto-transfer blocked; manual transfer only (already v1 approach) |
| **AS-14** | FastCA OR VinaCA vendor contract signed — digital signature vendor for KB04 POA (AC-55d) | Procurement | Phase-05 digital POA path; if unsigned by phase-05 mid → ship notarized-only + patch v1.0.1 | OPEN — awaiting evidence | Signed contract PDF + API credentials received. FastCA preferred (lower per-sig cost ~50K VND). | If FastCA contract delayed → switch to VinaCA fallback. If both delayed → ship phase-05 with notarized-only; digital sig in v1.0.1 |
| **Vendor: AWS SES** | AWS SES production access — move from sandbox to production for email delivery | Ops | Phase-08 launch; NFR-14 email deliverability ≥95% | OPEN — awaiting evidence | AWS SES production account confirmed (console screenshot). SPF/DKIM/DMARC records set on domain. Test email from production SES to external inbox confirmed delivered. | If SES production denied → switch to Sendgrid (pre-evaluated alternative). Escalate to AWS account team. |
| **Vendor: eSMS/FPT.AI** | eSMS.vn (or FPT.AI) account active + DLT brand registered for SMS OTP/notifications | Ops | Phase-08 launch; SMS escalation ladder | OPEN — awaiting evidence | Account ID + API key received. DLT brand registration confirmed (eSMS/VNPT DLT portal). Test SMS delivered to VN mobile number. | If DLT registration delayed (typically 3-5 business days) → launch with email-only ladder; SMS in v1.0.1 |
| **Q-DD5** | Sponsor written acceptance of cumulative ~30-40% Segment C TAM defer (D4 + D6 + D7 combined: no multi-user PMC, no sub-property scope UI, no auto-commission) | Product sponsor | Phase-04 kickoff (must be accepted BEFORE phase-04 begins, not phase-by-phase) | OPEN — awaiting evidence | Written or email confirmation from sponsor. Document: which TAM segments are deferred, which KPIs are accepted as v1 success metrics (≥50 delegations, NPS≥55, churn≤10%/mo, approval rate≥85%). | If sponsor refuses defer → scope must expand (add PMC/sub-property to v1) or timeline extends significantly. Escalate to CTO. |

---

## Pre-launch Readiness Summary

```
Status:   [ ]O1  [ ]O2  [ ]O3  [ ]O4(v2)  [ ]AS-14  [ ]SES  [ ]SMS  [ ]Q-DD5
          OPEN   OPEN   OPEN   OPEN        OPEN      OPEN   OPEN    OPEN

v1 HARD BLOCKERS (all must be CLOSED before ship):
  O1, O2, O3, AS-14, SES, SMS, Q-DD5

v2 gates (tracked but not v1 blockers):
  O4
```

---

## Evidence Log

_Populate as gates close:_

| Gate | Closed Date | Evidence File | Closed By |
|------|-------------|---------------|-----------|
| O1 | — | — | — |
| O2 | — | — | — |
| O3 | — | — | — |
| AS-14 | — | — | — |
| Vendor: SES | — | — | — |
| Vendor: SMS | — | — | — |
| Q-DD5 | — | — | — |

---

## Timeline Reference (from plan.md)

| Gate | Due Date | Notes |
|------|----------|-------|
| Q-DD5 | Before phase-04 starts | Earliest hard gate |
| O1 | Phase-04 mid-point | 2-3 week lead time; start now |
| O2 | Phase-05 freeze | Concurrent with AS-14 |
| AS-14 | Phase-05 mid | FastCA sales lead time 1-2 weeks |
| Vendor: SES | Phase-08 launch | AWS production approval ~1 week |
| Vendor: SMS | Phase-08 launch | DLT registration ~3-5 business days |
| O3 | Phase-06 freeze | Legal counsel engagement required |
| O4 | Before v2 (Q4 2026) | Not blocking v1 |

---

## Risk Flags

- **O1/O2 calendar risk (R3):** Police office visits require physical presence; budget 2-3 weeks for 4 districts. Start at phase-04 kickoff (not at phase-11).
- **AS-14 lead time:** FastCA has 1-2 week sales cycle. Engage immediately when phase-03 is ready.
- **AWS SES production:** AWS reviews sandbox→production requests; typically 1 business day but can be longer. Do not wait until phase-08 to request.
- **DLT registration:** Vietnamese DLT brand registration via eSMS takes 3-5 business days. Must be filed in parallel with development.
