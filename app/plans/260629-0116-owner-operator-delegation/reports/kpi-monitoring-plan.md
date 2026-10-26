# KPI Monitoring Plan — Owner-Operator Delegation v1

**Plan:** `plans/260629-0116-owner-operator-delegation/`
**Date:** 2026-06-29
**Gates source:** BA v4 §11 (Success Metrics) + §13 Q1 + plan.md KPI gates

---

## v1 → v1.5 (Freemium) Gate KPIs

All 4 KPIs must be met within 90 days of pilot launch to unlock v1.5 freemium pricing.

| KPI | Target | Measurement Window |
|-----|--------|--------------------|
| Active delegations | ≥ 50 | Day 90 snapshot |
| NPS (from delegating owners) | ≥ 55 | Day 60–90 survey responses |
| Monthly churn rate | ≤ 10%/mo | Rolling 30d at Day 90 |
| Approval rate (approved / total decided) | ≥ 85% | Rolling 30d at Day 90 |

---

## SQL Queries

### 1. Active delegations count

```sql
-- v1→v1.5 gate: ≥50 active delegations at Day 90
SELECT COUNT(*) AS active_delegations
FROM delegations
WHERE status = 'active';

-- Trend: week-over-week growth
SELECT
  DATE_TRUNC('week', activated_at) AS week,
  COUNT(*) AS activations
FROM delegations
WHERE activated_at >= NOW() - INTERVAL '90 days'
GROUP BY 1
ORDER BY 1;
```

### 2. NPS approximation (from approval interaction events)

```sql
-- NPS survey responses stored in a hypothetical nps_responses table (to be built)
-- Interim proxy: count owners who have been active (approved/rejected) in last 30d
SELECT COUNT(DISTINCT d.owner_id) AS engaged_owners
FROM delegation_approvals da
JOIN delegations d ON d.id = da.delegation_id
WHERE da.decided_at >= NOW() - INTERVAL '30 days'
  AND da.status IN ('approved', 'rejected');
```

NPS collection: implement in-app survey triggered 7 days after first delegation activation.
Store in `nps_responses(user_id, score INT 0-10, comment TEXT, created_at TIMESTAMP)`.

```sql
-- Real NPS once survey table exists
SELECT
  SUM(CASE WHEN score >= 9 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) -
  SUM(CASE WHEN score <= 6 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS nps
FROM nps_responses
WHERE created_at >= NOW() - INTERVAL '30 days'
  AND user_type = 'owner'
  AND feature_tag = 'delegation';
```

### 3. Monthly churn rate

```sql
-- Churn = delegations terminated in last 30d / total delegations (active + terminated)
WITH base AS (
  SELECT COUNT(*) AS total
  FROM delegations
  WHERE activated_at <= NOW() - INTERVAL '30 days'
),
churned AS (
  SELECT COUNT(*) AS count
  FROM delegations
  WHERE status IN ('terminated', 'archived')
    AND terminated_at >= NOW() - INTERVAL '30 days'
)
SELECT
  c.count::FLOAT / NULLIF(b.total, 0) * 100 AS churn_rate_pct
FROM base b, churned c;

-- Target: ≤ 10% (v1→v1.5), ≤ 5% (v1.5→v2)
```

### 4. Approval rate (approved vs total decided)

```sql
-- Approval rate: ≥85% of decided approvals are approved
SELECT
  COUNT(*) FILTER (WHERE status = 'approved') AS approved,
  COUNT(*) FILTER (WHERE status = 'rejected') AS rejected,
  COUNT(*) FILTER (WHERE status = 'expired') AS expired,
  COUNT(*) AS total_decided,
  ROUND(
    COUNT(*) FILTER (WHERE status = 'approved') * 100.0
    / NULLIF(COUNT(*) FILTER (WHERE status IN ('approved', 'rejected')), 0),
    1
  ) AS approval_rate_pct
FROM delegation_approvals
WHERE decided_at >= NOW() - INTERVAL '30 days'
  AND status IN ('approved', 'rejected', 'expired');

-- Target: ≥85% approval_rate_pct
```

### 5. KB04 SLA adherence (supplementary)

```sql
-- KB04 fast-track: how many expired without owner approval (SLA breach)
SELECT
  COUNT(*) FILTER (WHERE status = 'approved') AS approved_in_time,
  COUNT(*) FILTER (WHERE status = 'expired') AS sla_breached,
  COUNT(*) AS total,
  ROUND(
    COUNT(*) FILTER (WHERE status = 'expired') * 100.0 / NULLIF(COUNT(*), 0),
    1
  ) AS breach_rate_pct
FROM delegation_approvals
WHERE sla_class = 'kb04_fast_track_6h'
  AND created_at >= NOW() - INTERVAL '30 days';
```

### 6. Commission snapshot coverage (supplementary)

```sql
-- What % of paid invoices have a commission snapshot
SELECT
  COUNT(*) FILTER (WHERE commission_amount IS NOT NULL) AS with_commission,
  COUNT(*) FILTER (WHERE commission_amount IS NULL) AS without_commission,
  COUNT(*) AS total_paid
FROM invoices
WHERE paid_at >= NOW() - INTERVAL '30 days'
  AND paid_at IS NOT NULL;
```

### 7. Delegation duration (health signal)

```sql
-- Average days active before termination (higher = healthier)
SELECT
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (terminated_at - activated_at)) / 86400) AS median_days,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (terminated_at - activated_at)) / 86400) AS p95_days
FROM delegations
WHERE status IN ('terminated', 'archived')
  AND activated_at IS NOT NULL
  AND terminated_at IS NOT NULL
  AND terminated_at >= NOW() - INTERVAL '90 days';
```

---

## Dashboard Recommendations

Build the following Grafana / Metabase panels:

| Panel | Query | Refresh |
|-------|-------|---------|
| Active delegations (count gauge) | Query 1 — active count | Daily |
| Weekly delegation activations (bar chart) | Query 1 — trend | Weekly |
| Approval rate (gauge %) | Query 4 | Daily |
| Churn rate (line chart, rolling 30d) | Query 3 | Weekly |
| KB04 SLA breach rate (gauge %) | Query 5 | Daily |
| Commission coverage (%) | Query 6 | Daily |

---

## Alerting Rules

Set up PagerDuty / OpsGenie alerts:

| Rule | Condition | Severity | Action |
|------|-----------|----------|--------|
| Approval rate drops | approval_rate_pct < 70% for 3 consecutive days | HIGH | Review: are thresholds set too low? Ops review owners |
| Churn spike | churn_rate_pct > 15% in any 7-day window | HIGH | Exit interview for churned operators; product review |
| KB04 SLA breach surge | breach_rate_pct > 20% in 24h | MEDIUM | Review owner responsiveness; consider extending SLA |
| Zero activations (Day 15+) | 0 new delegations in 7 days | HIGH | Product + sales: cold pilot; activation incentive needed |

---

## v1.5 → v2 Gate KPIs

| KPI | Target | Notes |
|-----|--------|----|
| Active delegations | ≥ 100 | From plan.md |
| Churn | ≤ 5%/mo | Tighter than v1.5 |
| NHNN license | CLOSED (O4) | Blocks auto-commission |

## Hard-fail Review Trigger

Per plan.md + BA v4 §13 Q1:

> If < 50 delegations in 6 months → mandatory product review: did D4/D6/D7 defers cause TAM gap (per Q-DD5)?

```sql
-- Hard-fail trigger check (run at Day 180)
SELECT COUNT(*) AS ever_activated
FROM delegations
WHERE activated_at <= NOW() - INTERVAL '6 months'
   OR activated_at IS NOT NULL;
-- If < 50 → trigger sponsor review meeting
```
