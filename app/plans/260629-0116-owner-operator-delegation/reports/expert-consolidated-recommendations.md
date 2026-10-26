# Expert Consolidated Recommendations — Decision Matrix

**Prepared for:** ancu365 owner (project sponsor)
**Date:** 2026-06-29
**Status:** AWAITING USER APPROVAL
**Source reports (4 experts, 928 lines total):**
- `expert-legal-answers.md` — VN Legal/Compliance (200 lines)
- `expert-ops-answers.md` — Property Mgmt Industry SME (237 lines)
- `expert-strategy-zalo-answers.md` — Product Strategy + Zalo Ops (184 lines)
- `expert-pricing-answers.md` — SaaS Pricing/Monetization (307 lines)

**Purpose:** Single scannable matrix mapping all 10 open questions to a recommended default + 1-line trade-off + confidence. Use this to approve/override before Tech Lead Phase 3 plan starts.

---

## How to Read

| Column | Meaning |
|---|---|
| **#** | Question ID. Maps to BA v3 §13 Decisions Log (D1–D8) + Q1 Pricing BLOCKER. |
| **Question** | Plain-VN restatement |
| **Recommended** | Expert's default answer |
| **Why** | One-line rationale (legal/ops/market evidence) |
| **Trade-off** | What you give up vs. alternative |
| **Confidence** | HIGH / MED-HIGH / MED / LOW |
| **Source** | Which expert report |
| **Action** | What user must do |

---

## Decision Matrix (10 questions)

| # | Question | Recommended | Why | Trade-off | Confidence | Source | Action |
|---|---|---|---|---|---|---|---|
| **D1** | KB04 SLA owner duyệt? (3h / 6h / 12h) | **6h** + pre-file | Luật Cư Trú Art 23 → 12h là deadline tenant move-in, không phải owner approval. 6h cho buffer 6h filing | 3h quá gắt (owner ban đêm miss); 12h thiếu buffer | **HIGH** | Legal §Q1 + Ops §Q3 | Confirm OK |
| **D2** | Owner chết/mất NL hành vi → kênh nào? | **Manual admin upload** (death cert + POA của heir, SLA 24h) | Không có API Bộ Tư Pháp; self-attestation = fraud risk (72% expat report rental fraud) | High friction cho heir (gather docs 1-2 biz days); chậm hơn API tự động (không khả thi) | **MED-HIGH** | Legal §Q2 | Confirm + clarify admin team & SLA |
| **D3** | KB04 cần công chứng POA? | **Digital consent default (FastCA/VinaCA); notary optional** | Luật Cư Trú 2020 không yêu cầu notary; Luật GDĐT 2023 Art 8 công nhận digital sig | ~15% police từ chối ở vùng quê → owner phải đi notary backup | **HIGH** | Legal §Q3 | Pre-launch check với 1-3 phường HN/HCM |
| **D4** | Tài sản đồng sở hữu (vợ chồng, đồng thừa kế) — v1 cho phép? | **REFUSE v1, defer v2 Org model** | Bộ Luật Dân Sự Art 218, 212 yêu cầu **mọi** đồng sở hữu đồng ý → unilateral delegation = void | Mất segment "vợ chồng cùng đứng tên" (~30% red book có 2 tên) → defer doanh thu | **HIGH** | Legal §Q4 | Define UX message "v1 chỉ hỗ trợ chính chủ; co-owned launching v2" |
| **D5** | AC-43 30-day lockdown — scope? | **MODIFY: keep 30d, FLIP logic** — allow KB04 pre-file + fraud termination (24h owner approval SLA); block raise threshold + change banking + new operator invite | Current AC-43 quá cứng → operator không termin được tenant gian lận; phá compliance KB04 | Nếu operator không trust-worthy, allow pre-file = surface cho fraud (mitigated bởi 24h approval + audit log) | **MED-HIGH** (75%) | Ops §Q1 | Re-write AC-43 với 3-tier table |
| **D6** | Scope nesting (1 building-op + 1 room-op cùng lúc)? | **DEFER behavior to v2** nhưng **schema scope-ready ngay v1** (add `scope_id` FK, AC-08 unique constraint là per-scope) | 80% PMC VN <20 units (1 pháp nhân OK). Nhưng schema không scope-aware → v2 migration tốn 2-3 weeks | Lose ~10-15% PMC early adopters (Y1). Nhưng tránh được migration cost v2 | **MED** (65%) | Ops §Q2 | Tech Lead xác nhận schema design |
| **D7** | PMC multi-user RBAC v1? | **CONFIRM defer v2** — v1 = 1 pháp nhân đại diện duy nhất per operator-doanh nghiệp + shared login + audit disclosure | Buildium/AppFolio cũng defer RBAC post-launch; 80% PMC VN <20 units không cần. Cost: 5 dev-weeks save | Shared login = audit attribution kém (~70% accuracy); password rotation khi staff nghỉ | **HIGH** | Strategy §Q1 | Confirm + add 2 mitigation: notarized POA update workflow + audit disclosure UI |
| **D8** | Zalo ZNS budget + setup time? | **DEFER ZNS to v1.1** (Q4 2026). v1 dùng in-app notification + email only. v1.1 thêm Zalo ZNS (200-300 VND/msg, 5-8 days approval) + SMS fallback | v1 cost = $0 messaging; v1.1 cost = ~$0.54/month pilot scale (~$70-100/mo at 1000 deleg). Zalo ZNS approval 5-8 ngày (CCKD đã có sẵn → fast-track) | v1 owner ngoại tuyến miss notification (mitigated bởi email) | **HIGH** | Strategy §Q2 | Confirm + plan v1.1 Zalo Business Solutions account setup Sep 2026 |
| **D9** (PDPL) | Data retention policy operator audit logs? | **4-tier per BA v3 §10.5** (đã có default): hot 90d / warm 2y / cold 5y / legal hold per case | Decree 13/2023 PDPL yêu cầu minimization + retention chính sách rõ ràng | Storage cost ~minimal; complexity ở tier transitions (tự động hóa cron jobs) | **HIGH** | Cross-cut §Legal + BA v3 §10.5 | Confirm tier durations |
| **Q1 BLOCKER** | Pricing model v1? (FREE / Freemium / Commission / Subscription) | **FREE v1** → Freemium v1.5 ($50-99K/mo optional operator features) → 0.5% commission v2 (Nov-Dec 2026, owner transparent) → Full SaaS v3 ($99-499K/mo + 2-3%) | Vietnam SaaS adoption chưa proven; zero dominant competitor → first-mover window 12-18 tháng; NHNN intermediary license = blocker cho auto-commission v1 | v1 = $0 revenue, only validation. Risk: free competitor enter. Mitigated by KPI gates (50+ deleg + NPS≥55 → v1.5) | **HIGH** | Pricing §All | Confirm phased pricing + plan WTP interviews July 2026 |

---

## Cross-Cutting Insights (worth highlighting)

1. **VN context flips global playbook:** Zalo ZNS *cheaper + faster* than SMS (200 VND vs 300-500 VND). Lean into "Zalo-first" as VN-optimized feature.
2. **Trust vs SLA:** Segment A/B (~80%) chạy trên trust (Zalo/WhatsApp); SLA enforcement là cho Segment C absentee owners (~20%, ARPU 2-3× cao). Đừng over-engineer SLA cho A/B.
3. **Pre-file KB04 unblocks D1+D5:** Operator có thể submit CT01 trước khi tenant move-in → không có race condition giả định trước đó. Quan trọng: tech lead phải confirm với police 1-3 phường rằng pre-file submission được chấp nhận.
4. **D6 schema vs UI split:** Defer **behavior** (UI, approval workflow) sang v2 OK, nhưng **schema** phải scope-aware từ v1 để không phải migrate. Cost 2-3 ngày dev extra → tiết kiệm 2-3 tuần v2.
5. **D7 legal serendipity:** VN luật thực ra **bắt buộc** shared authority (notarized POA cho 1 pháp nhân) → defer RBAC = compliance win, không phải product shortcut. Đưa vào sales pitch.
6. **Pricing BLOCKER không phải BLOCKER kỹ thuật:** Defer monetization v2 không ảnh hưởng v1 phase-01 schema (không cần commission tracking table v1). Có thể greenlight phase-01 ngay sau khi confirm D1-D9.

---

## Confidence Distribution

| Confidence | Count | Decisions |
|---|---|---|
| HIGH (80%+) | 6 | D1, D3, D4, D7, D8, D9, Q1 |
| MED-HIGH (70-80%) | 2 | D2, D5 |
| MED (60-70%) | 1 | D6 |

**No LOW confidence decisions.** Safe to proceed with all 10 as defaults.

---

## Remaining Open Follow-ups (Require Human Validation)

These 7 items expert reports flagged as **needing local legal counsel or pilot validation** — NOT blockers for phase-01 but should be addressed before public launch:

| # | Item | Who | When |
|---|---|---|---|
| O1 | KB04 pre-emptive filing — police có chấp nhận CT01 submission *trước* tenant arrival không? | Pre-launch: 1-3 phường HN/HCM check | Before phase-04 (KB04 workflow) |
| O2 | Notarization requirement variance — có phường nào *bắt buộc* công chứng POA không? | Legal counsel + 5 phường sampling | Before phase-04 |
| O3 | Owner death + in-flight KB04 — auto-reject hay escalate to heir? | Legal counsel | Before phase-04 |
| O4 | NHNN intermediary license scope — semi-auto commission (suggested transfer) có trigger license không? | Corporate counsel (LS Đặng Hoàng Liêu hoặc tương đương) | Oct 2026, before v2 commission |
| O5 | Operator WTP survey — n=15 freelancer + n=15 SME | Product team interviews | July 2026, before v1.5 planning |
| O6 | Owner Segment C WTP survey — n=20 high-value owners | Product team interviews | July 2026 |
| O7 | Churn A/B test design (commission sensitivity) | Product analytics | Sep 2026, before v2 |

---

## Recommended User Action

### Approve All 10 Defaults (Recommended Path)

> "Approve tất cả 10 default từ expert recommendation. Proceed Tech Lead Phase 3 plan."

→ Tech Lead bắt đầu Phase 3 (research + planner) ngay → output: `plan.md` + `phase-XX-*.md`
→ Phase-01 schema freeze trong 1-2 ngày tới
→ Pre-launch validation (O1-O3) chạy song song trong Phase 4 implementation

### Override Specific Decisions

Nếu muốn override decision nào (ví dụ D6 — bạn muốn nesting full v1, không defer), reply:

> "Override Dx: <decision của bạn>. Lý do: <ngắn gọn>."

Tôi sẽ update BA v3 §13 + ping Tech Lead với thay đổi trước khi plan.

### Defer Decisions for Discussion

Nếu chưa quyết được decision nào, reply:

> "Cần thảo luận thêm Dx, Dy. Tôi muốn deep-dive [legal/ops/pricing/strategy]."

Tôi sẽ spawn focused follow-up agent hoặc đặt câu hỏi clarifying.

---

## Decision Log (for §13 BA v3 sync)

Sau khi user confirm, các default sau sẽ được lock vào BA v3 §13 Decisions Log:

```yaml
decisions:
  D1: { topic: "KB04 SLA", default: "6h owner approval + pre-file", confidence: HIGH, source: Legal Q1 + Ops Q3 }
  D2: { topic: "Owner death channel", default: "Manual admin upload, 24h SLA", confidence: MED-HIGH, source: Legal Q2 }
  D3: { topic: "KB04 POA format", default: "Digital consent default; notary optional escalation", confidence: HIGH, source: Legal Q3 }
  D4: { topic: "Co-owned property v1", default: "REFUSE v1, defer v2 Org model", confidence: HIGH, source: Legal Q4 }
  D5: { topic: "AC-43 lockdown scope", default: "MODIFY 3-tier: pre-file + fraud-term ALLOWED with 24h approval", confidence: MED-HIGH, source: Ops Q1 }
  D6: { topic: "Scope nesting", default: "DEFER UI behavior v2; schema scope-ready v1", confidence: MED, source: Ops Q2 }
  D7: { topic: "PMC multi-user RBAC", default: "CONFIRM defer v2; v1 = 1 pháp nhân + shared login + audit disclosure", confidence: HIGH, source: Strategy Q1 }
  D8: { topic: "Zalo ZNS rollout", default: "DEFER v1.1 (Q4 2026); v1 = in-app + email", confidence: HIGH, source: Strategy Q2 }
  D9: { topic: "PDPL retention", default: "4-tier: hot 90d / warm 2y / cold 5y / legal hold", confidence: HIGH, source: BA v3 §10.5 + Legal cross-cut }
  Q1: { topic: "Pricing v1", default: "FREE v1 → Freemium v1.5 → 0.5% commission v2 → Full SaaS v3", confidence: HIGH, source: Pricing all }
```

---

**Prepared by:** Main Claude (consolidating 4 expert subagent reports)
**Next gate:** User approves → Tech Lead Phase 3 begins.
