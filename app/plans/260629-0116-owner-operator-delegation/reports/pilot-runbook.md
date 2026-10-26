# Pilot Launch Runbook — Owner-Operator Delegation v1

**Plan:** `plans/260629-0116-owner-operator-delegation/`
**Version:** 1.0
**Date:** 2026-06-29
**Audience:** Ops, BE on-call, Product

---

## Pre-flight Checklist (10 items — must be 10/10 GREEN before deploy)

Execute this list in order on staging (same config as production):

| # | Check | Command / Action | Expected Result | Status |
|---|-------|-----------------|-----------------|--------|
| 1 | All pre-launch gates CLOSED | Review `reports/pre-launch-gates-checklist.md` | All 7 hard gates = CLOSED | [ ] |
| 2 | Backend tests green | `pytest tests/ -x -q --tb=short` | 1086+ tests, 0 failures | [ ] |
| 3 | Regression smoke green | `./scripts/regression_smoke.sh` | Exit 0, all GREEN | [ ] |
| 4 | AC-52 guard passes | `python scripts/check_no_host_id_alter.py` | Exit 0, PASS | [ ] |
| 5 | Feature flags verified | `grep -r "EXECUTOR_DECIDE_EXCEPTION" app/` | `_EXECUTOR_EXCEPTION_ENABLED = False` | [ ] |
| 6 | SES email delivery test | Send test email via SES production endpoint | Received in inbox within 60s | [ ] |
| 7 | SMS delivery test | Send test SMS via eSMS/FPT.AI production | Received on VN mobile within 30s | [ ] |
| 8 | DB migration applied | `alembic current` + verify migration version | Latest migration HEAD applied | [ ] |
| 9 | APScheduler jobs wired | Check scheduler logs on startup | All 6 cron jobs registered (approval expiry, KB04 6h, fraud 24h, lockdown 30d, death 7d, retention) | [ ] |
| 10 | pilot user accounts ready | Confirm 5-10 pilot owner accounts onboarded | Users have host_profile + KYC verified | [ ] |

---

## Day-1 Monitoring Metrics

Monitor these for 48h post-launch. Check dashboards every 2h on Day 1.

### Delegation Funnel

| Metric | Query / Source | Baseline | Alert Threshold |
|--------|---------------|----------|-----------------|
| Invitations sent | `SELECT COUNT(*) FROM delegation_invitations WHERE created_at > now()-interval '24h'` | 0 (new feature) | Alert if > 100 in first hour (bot?) |
| Invitations accepted | `SELECT COUNT(*) FROM delegations WHERE activated_at > now()-interval '24h'` | 0 | Alert if accept rate < 10% after 24h |
| Approval requests created | `SELECT COUNT(*) FROM delegation_approvals WHERE created_at > now()-interval '24h'` | 0 | Alert if > 1000 in first hour |
| Approval rate | `SELECT status, COUNT(*) FROM delegation_approvals WHERE created_at > now()-interval '24h' GROUP BY status` | N/A | Alert if rejected > 50% |

### Error Rates

| Metric | Source | Alert Threshold |
|--------|--------|-----------------|
| 5xx on `/api/delegations/*` | APM / nginx logs | > 5 per minute |
| 5xx on `/api/approvals/*` | APM / nginx logs | > 5 per minute |
| Scheduler job failures | Python log (ERROR level) | Any failure in critical jobs |
| JWT decode errors | Auth logs | > 50/min spike |

### Performance

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| `resolve_actor_context()` p95 | < 50ms | > 50ms sustained |
| API p95 response time | < 500ms | > 1s sustained |
| DB connection pool utilization | < 80% | > 90% |

### Email / SMS Delivery

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| SES bounce rate | < 2% | > 5% |
| SES complaint rate | < 0.1% | > 0.5% |
| SMS delivery rate | ≥ 90% | < 80% |

---

## Escalation Triggers

Trigger escalation immediately if any of these occur:

1. **Data corruption:** `on_behalf_of_user_id` written with wrong owner_id (cross-tenant leak)
   - Action: Stop all operator sessions, audit ChangeLog for last 1h, hotfix required
   - Contact: BE lead + CTO

2. **Scheduler failure:** 72h auto-reject job fails → pending approvals never expire
   - Action: Manually run `ApprovalService.auto_reject_expired()` + fix scheduler
   - Contact: BE on-call

3. **Commission math error:** Commission computed incorrectly (off by > 1 VND)
   - Action: Disable commission display for operators; audit all snapshots since launch
   - Contact: BE lead + Finance

4. **Death flow triggered:** `OwnerDeathCertificate` row created in production
   - Action: Immediate legal + ops review; do NOT auto-archive within 7d without manual confirmation
   - Contact: Legal + CTO

5. **Fraud flag surge:** > 10 fraud termination approvals in 1h
   - Action: Suspect bot/abuse; pause fraud report endpoint; investigate
   - Contact: Trust & Safety + BE lead

---

## Rollback Procedure

If critical failure detected in first 24h:

### Step 1: Disable delegation feature (soft rollback)

```python
# Set environment variable to disable delegation endpoints
DELEGATION_FEATURE_ENABLED=false
```

All `/api/delegations/*` and `/api/approvals/*` routes return 503 Service Unavailable.
Existing delegations frozen in current state.

### Step 2: Notify pilot users

Send email via SES: "Chúng tôi đang tạm dừng tính năng ủy thác để cải thiện. Dữ liệu của bạn được bảo toàn."

### Step 3: DB rollback (only if migration caused data corruption)

```bash
# Check alembic current
alembic current

# Rollback to pre-delegation migration (migration 0020)
alembic downgrade 0020  # adjust to actual previous migration ID

# CAUTION: This drops delegation tables — only if absolutely necessary
# All delegation data will be lost after downgrade
```

### Step 4: Post-incident

- Write incident report within 24h
- Root cause analysis within 72h
- Fix + re-launch plan presented to sponsor before re-enabling

---

## KPI Sampling Schedule

| KPI | Target | Measurement Method | Frequency |
|-----|--------|--------------------|-----------|
| Active delegations | ≥ 50 (v1→v1.5 gate) | `SELECT COUNT(*) FROM delegations WHERE status='active'` | Weekly (Day 7, 14, 30, 60, 90) |
| NPS | ≥ 55 | In-app survey (7-day post-activation) | After Day 30 (enough activations) |
| Churn rate | ≤ 10%/mo | `SELECT COUNT(*) FROM delegations WHERE status IN ('terminated','archived') AND terminated_at > now()-interval '30d'` / total | Monthly |
| Approval rate | ≥ 85% approved vs rejected | `SELECT status, COUNT(*) FROM delegation_approvals WHERE created_at > now()-interval '30d' GROUP BY status` | Weekly |
| KB04 SLA breach | 0 (or track) | `SELECT COUNT(*) FROM delegation_approvals WHERE sla_class='kb04_fast_track_6h' AND status='expired' AND deadline_at > now()-interval '30d'` | Weekly |

### v1 → v1.5 Gate Review (at Day 90)

1. Pull all 4 KPI metrics
2. Compare against targets
3. If ≥3/4 KPIs meet target → proceed to v1.5 freemium pricing
4. If < 3/4 → investigate root cause (D4/D6/D7 defers or product gap?)
5. Report to sponsor within 1 week of Day 90

---

## Contact List

| Role | Contact | For |
|------|---------|-----|
| BE Lead | TBD | All backend/DB issues |
| FE Lead | TBD | Flutter app issues |
| Ops | TBD | Infrastructure, SES, SMS vendor |
| Legal | TBD | Death cert, police pre-file, O1-O3 |
| Product Sponsor | TBD | Scope/business decisions |
| CTO | TBD | Critical escalations only |
