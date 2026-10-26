# APPI Compliance Runbook — Ancu365 JP Operations

**Maintained by:** Ops & Compliance Team  
**Last Updated:** 2026-10-17  
**Review Cycle:** Quarterly

This runbook documents standard procedures for maintaining APPI 2022 compliance during live operations.

---

## Table of Contents

1. [Monthly: Compliance Evidence Snapshot](#monthly-compliance-evidence-snapshot)
2. [Quarterly: Encryption Key Rotation](#quarterly-encryption-key-rotation)
3. [Annual: Privacy Impact Assessment (PIA)](#annual-privacy-impact-assessment-pia)
4. [Incident: Data Breach Notification (72h Window)](#incident-data-breach-notification-72h-window)

---

## Monthly: Compliance Evidence Snapshot

**Owner:** Compliance Officer  
**Frequency:** 1st business day of each month  
**Duration:** 30 minutes  
**Trigger:** Automated reminder in Slack

### Purpose

Archive a monthly snapshot of compliance evidence (encryption key status, audit log summary, retention status) to demonstrate continuous APPI compliance to regulators.

### Procedure

#### Step 1: Connect to Production Database
```bash
# SSH into Ancu365 ops server
ssh ops@ancu365-prod.internal

# Connect to Postgres via psql
export PGPASSWORD="$PROD_DB_PASSWORD"
psql -h prod-db.internal -U ancu_prod -d ancu_jp_prod
```

#### Step 2: Generate Audit Log Summary
```sql
-- Run this query to get monthly audit stats
SELECT
  DATE_TRUNC('month', timestamp)::date as month,
  COUNT(*) as total_events,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(CASE WHEN action = 'READ' THEN 1 END) as read_events,
  COUNT(CASE WHEN action = 'WRITE' THEN 1 END) as write_events,
  COUNT(CASE WHEN action = 'DELETE' THEN 1 END) as delete_events
FROM audit_log
WHERE timestamp >= DATE_TRUNC('month', NOW() - INTERVAL '1 month')
  AND timestamp < DATE_TRUNC('month', NOW())
GROUP BY 1
ORDER BY 1 DESC;

-- Result example (save to file):
-- month | total_events | unique_users | read | write | delete
-- 2026-09-01 | 42850 | 127 | 38000 | 4200 | 650
```

#### Step 3: Verify Encryption Key Status
```bash
# Check that FERNET_KEY env var is set (do NOT print the key itself)
if [ -z "$FERNET_KEY" ]; then
  echo "ERROR: FERNET_KEY not set in production environment"
  exit 1
else
  echo "✅ FERNET_KEY is configured"
  echo "Last rotated: $(grep -r "FERNET_KEY_ROTATED_AT" /etc/ancu365/config.yml || echo 'TBD')"
fi
```

#### Step 4: Check Retention Compliance
```sql
-- Count records marked for deletion and their age
SELECT
  'to_delete' as status,
  COUNT(*) as record_count,
  MIN(marked_at) as oldest_marked,
  MAX(marked_at) as newest_marked
FROM tenant
WHERE is_deleted = true
  AND marked_at IS NOT NULL
GROUP BY 1;

-- Result should show: oldest marked record is < 40 days old (allow 30d + 10d buffer)
-- If any older: investigate why deletion cron hasn't run
```

#### Step 5: Verify No Unexpected Data Leaks
```sql
-- Check for large exports or unusual access patterns
SELECT
  user_id,
  COUNT(*) as access_count,
  MAX(timestamp) as last_access
FROM audit_log
WHERE action = 'READ'
  AND timestamp >= NOW() - INTERVAL '1 day'
GROUP BY user_id
HAVING COUNT(*) > 1000  -- Alert if single user read >1000 records in 24h
ORDER BY access_count DESC
LIMIT 10;

-- If results found: escalate to ops; may indicate breach attempt or export misconfiguration
```

#### Step 6: Archive Snapshot
```bash
# Create monthly archive directory
SNAPSHOT_DIR="/var/ancu365/compliance-snapshots/$(date +%Y-%m)"
mkdir -p "$SNAPSHOT_DIR"

# Save all data to timestamped files
psql -h prod-db.internal -U ancu_prod -d ancu_jp_prod \
  -c "COPY (SELECT * FROM audit_log WHERE timestamp >= DATE_TRUNC('month', NOW() - INTERVAL '1 month') LIMIT 10000) TO STDOUT CSV" \
  > "$SNAPSHOT_DIR/audit_log_summary_$(date +%Y-%m-%d).csv"

# Generate compliance report
cat > "$SNAPSHOT_DIR/compliance_report_$(date +%Y-%m-%d).txt" <<EOF
Ancu365 APPI Compliance Snapshot — $(date +%Y-%m-%d)

Audit Log Summary:
[INSERT query results from Step 2]

Encryption Key Status:
[INSERT key status from Step 3]

Retention Status:
[INSERT retention check from Step 4]

Anomalies Detected:
[INSERT large export check from Step 5, or "None"]

Reviewed by: [REVIEWER NAME]
Date: $(date)
EOF

# Compress and backup
tar czf "$SNAPSHOT_DIR/snapshot_$(date +%Y-%m-%d).tar.gz" "$SNAPSHOT_DIR"
cp "$SNAPSHOT_DIR/snapshot_$(date +%Y-%m-%d).tar.gz" /backup/ancu365-compliance/

echo "✅ Monthly snapshot archived to $SNAPSHOT_DIR"
```

#### Step 7: Slack Notification
```bash
# Notify compliance team
slack-send \
  --channel "#ancu365-compliance" \
  --message "Monthly snapshot complete: $(date +%Y-%m). No issues detected." \
  --color "good"
```

---

## Quarterly: Encryption Key Rotation

**Owner:** DevOps / Security Team  
**Frequency:** End of Q1, Q2, Q3, Q4  
**Duration:** 2–3 hours (includes testing & verification)  
**Downtime Risk:** None (zero-downtime procedure)  
**Trigger:** Calendar reminder; do NOT skip rotations

### Purpose

Rotate the Fernet encryption key used for PII at rest. This limits exposure if a key is accidentally compromised.

### Important Notes

- **Do NOT lose the old key.** Retain it for 6 months for decryption of historical records.
- **Test on staging first.** Never rotate directly in production.
- **Backup before rotating.** Have a restore procedure ready.

### Procedure

#### Pre-Rotation (Day Before)

**Step 1: Backup Production Database**
```bash
ssh ops@ancu365-prod.internal

# Full backup
pg_dump -h prod-db.internal -U ancu_prod -d ancu_jp_prod \
  --file=/backup/ancu365_pre_key_rotation_$(date +%Y-%m-%d).sql.gz \
  --format=custom \
  --compress=9

# Verify backup integrity
pg_restore -l /backup/ancu365_pre_key_rotation_$(date +%Y-%m-%d).sql.gz > /dev/null \
  && echo "✅ Backup verified" \
  || echo "❌ Backup corrupt; abort rotation"

# Secure backup location (AES-256 encryption)
gpg --symmetric --cipher-algo AES256 /backup/ancu365_pre_key_rotation_$(date +%Y-%m-%d).sql.gz
ls -lh /backup/ancu365_pre_key_rotation_$(date +%Y-%m-%d).sql.gz.gpg
```

**Step 2: Notify Stakeholders**
```bash
# Send message to ops, compliance, exec team
cat > /tmp/key_rotation_notice.txt <<EOF
🔐 ENCRYPTION KEY ROTATION SCHEDULED

Date: [ROTATION DATE]
Time: 02:00–05:00 JST (after-hours to minimize impact)
System: Ancu365 production DB
Action: Fernet key rotation (encryption at rest)
Expected Impact: Minimal; no downtime expected

If any issues: page @oncall-ops

Questions? Reply to this thread.
EOF

# Send via Slack
slack-send --channel "#ancu365-ops" --file /tmp/key_rotation_notice.txt
```

#### Rotation Day (Early Morning, After-Hours)

**Step 3: Test on Staging**
```bash
# Spin up staging from production snapshot (or use latest staging DB)
ssh ops@ancu365-staging.internal

# Set NEW key in staging .env
export FERNET_NEW_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
echo "Generated new key: $FERNET_NEW_KEY"

# Update .env (staging only)
sed -i.bak "s/^FERNET_KEY=.*/FERNET_KEY=$FERNET_NEW_KEY/" /etc/ancu365/.env.staging

# Restart staging app
systemctl restart ancu365-api-staging

# Run decryption test: verify old records still readable with new key rotation script
python3 /opt/ancu365/scripts/test_key_rotation.py \
  --old-key "$FERNET_OLD_KEY" \
  --new-key "$FERNET_NEW_KEY" \
  --db ancu_jp_staging \
  --sample-size 100

# Expected output: "✅ All 100 sample records decrypted and re-encrypted successfully"
```

**Step 4: Generate New Production Key**
```bash
# On production ops server (NOT accessible to developers)
# Use HSM (Hardware Security Module) or secure key vault to generate
# Example: HashiCorp Vault

vault write -f transit/keys/ancu365-pii/rotate

# Get the new key ID
FERNET_KEY_NEW=$(vault read transit/keys/ancu365-pii | grep -i "latest" | awk '{print $NF}')
echo "✅ Generated new key; version: $FERNET_KEY_NEW"

# Store key version in audit log for compliance record
psql -h prod-db.internal -U ancu_prod -d ancu_jp_prod \
  -c "INSERT INTO encryption_key_audit (key_version, rotated_at, rotated_by, reason) VALUES ('$FERNET_KEY_NEW', NOW(), 'automated_rotation', 'quarterly_scheduled_rotation');"
```

**Step 5: Rotate in Production**
```bash
# 1. Put application in "read-only" mode (no writes) for 5 minutes
curl -X POST http://localhost:8000/admin/maintenance/read-only \
  --header "Authorization: Bearer $ADMIN_TOKEN" \
  --data '{"duration_minutes": 5}'

# Monitor: no new writes should be accepted

# 2. Rotate key in environment
# Use secure deployment tool (e.g., Ansible with vault, not bash history)
# Pseudo-code:
ansible-playbook /opt/playbooks/rotate-fernet-key.yml \
  --extra-vars "new_key=$FERNET_KEY_NEW" \
  --vault-password-file /secure/vault-pass

# 3. Verify app reloaded with new key
curl http://localhost:8000/health | grep -i "fernet_key_version"
# Expected: {"status": "ok", "fernet_key_version": "3"}

# 4. Re-encrypt all PII records in DB with new key
# This script: reads old PII with old key, writes with new key
python3 /opt/ancu365/scripts/reencrypt_all_pii.py \
  --old-key "$FERNET_OLD_KEY" \
  --new-key "$FERNET_KEY_NEW" \
  --db ancu_jp_prod \
  --batch-size 1000 \
  --log-file /var/log/ancu365/reencrypt_$(date +%Y-%m-%d-%H%M%S).log

# Monitor progress:
tail -f /var/log/ancu365/reencrypt_*.log
# Expected completion: "Reencrypted 8342 records in 45 minutes"

# 5. Exit read-only mode
curl -X POST http://localhost:8000/admin/maintenance/read-only \
  --header "Authorization: Bearer $ADMIN_TOKEN" \
  --data '{"duration_minutes": 0}'
```

**Step 6: Verification**
```bash
# Verify all records still accessible
psql -h prod-db.internal -U ancu_prod -d ancu_jp_prod <<EOF
-- Spot-check: sample 50 random tenant records
-- Decrypt each with new key to verify re-encryption worked
SELECT COUNT(*) as total_records,
       COUNT(CASE WHEN pii_encrypted IS NOT NULL THEN 1 END) as encrypted_records
FROM tenant
WHERE created_at > NOW() - INTERVAL '1 month';

-- Expected: encrypted_records = total_records (all re-encrypted successfully)
EOF

# Test DSR export (decryption) with new key
curl -X GET "http://localhost:8000/api/tenant/$TEST_TENANT_ID/dsr/export" \
  --header "Authorization: Bearer $TEST_TENANT_TOKEN" \
  --header "X-OTP: $TEST_OTP" \
  > /tmp/dsr_test.json

if [ -s /tmp/dsr_test.json ]; then
  echo "✅ DSR export successful with new key"
else
  echo "❌ DSR export failed; abort rotation"
  exit 1
fi
```

**Step 7: Archive Old Key Safely**
```bash
# OLD key is still needed for audit trail (can't decrypt historical logs with new key yet)
# Store in secure location for 6 months, then destroy

# Encrypt old key with separate GPG key
echo "$FERNET_OLD_KEY" | gpg --symmetric --cipher-algo AES256 \
  --output /secure-vault/fernet_old_keys/fernet_key_$(date +%Y_Q%q).gpg.asc \
  --passphrase-file /secure-vault/key-rotation-passphrase.txt

# Remove from production memory/config
unset FERNET_OLD_KEY

# Log completion
echo "Archived old key to /secure-vault/fernet_old_keys/"
```

**Step 8: Post-Rotation Report**
```bash
# Compile report for compliance
cat > /var/ancu365/compliance-snapshots/key_rotation_report_$(date +%Y-%m-%d).md <<EOF
# Encryption Key Rotation Report

**Date:** $(date)
**Quarter:** Q$((($(date +%m)-1)/3+1)))
**Status:** ✅ SUCCESS

## Summary
- Old key: v2 (expires [6 months from today])
- New key: v3
- Records re-encrypted: 8342
- Duration: 47 minutes
- Downtime: 5 minutes (maintenance window)

## Verification Results
- ✅ Staging test passed
- ✅ Re-encryption completed
- ✅ DSR export working
- ✅ Audit logs accessible
- ✅ No tenant impact

## Next Actions
- Old key archived: /secure-vault/fernet_old_keys/fernet_key_$(date +%Y_Q%q).gpg.asc
- Scheduled destruction: $(date -d "+6 months" +%Y-%m-%d)
- Next rotation: $(date -d "+3 months" +%Y-%m-%d)

Completed by: [OPERATOR NAME]
Verified by: [COMPLIANCE OFFICER]
EOF

# Notify team
slack-send --channel "#ancu365-compliance" \
  --message "✅ Q$((($(date +%m)-1)/3+1)) key rotation complete. No issues. New key: v3" \
  --color "good"
```

---

## Annual: Privacy Impact Assessment (PIA)

**Owner:** Compliance Officer & Privacy Team  
**Frequency:** Annually (e.g., Q4 each year)  
**Duration:** 1–2 weeks  
**Scope:** Review all data handling, identify new risks

### Purpose

Formally assess APPI compliance, identify new risks (e.g., new integrations, feature changes), and document mitigations.

### Template

```markdown
# Privacy Impact Assessment (PIA) — Ancu365

**Conducted:** [DATE]
**Covering Period:** [YYYY-01-01 to YYYY-12-31]
**Conducted by:** [NAMES]
**Review Status:** ⏳ Draft | ✅ Final

## Executive Summary

### Key Findings
1. [Finding 1: Status + Risk Level + Mitigation]
2. [Finding 2]
...

### Overall Assessment
- ✅ Compliant (no material risks)
- ⚠️ Compliant with caveats (identified mitigations)
- ❌ Non-compliant (critical fixes required)

---

## 1. Data Collection & Purpose

### Current Data Flows
- [ ] Tenant signup (consent capture, encryption)
- [ ] Broker invite (minimal PII)
- [ ] Renewal processing (document upload, email)
- [ ] Deposit settlement (transaction history)
- [ ] DSR export (full data dump)
- [ ] Account deletion (30-day marking, auto-delete)

### Changes Since Last PIA
- Added feature: [Feature name] — collects [data type]
- Removed feature: [Feature name]
- Integrated service: [Partner] — accesses [data scope]

### Risk Assessment
| Data Flow | Risk Level | Mitigation | Status |
|---|---|---|---|
| [Flow] | Medium | [Mitigation] | ✅ |

---

## 2. Data Security

### Encryption Status
- At rest: ✅ Fernet (AES-128 CBC), last rotated [DATE]
- In transit: ✅ TLS 1.3 on all API endpoints
- Database: ✅ Postgres encrypted volumes

### Access Control
- Authentication: OAuth 2.0 + 2FA for sensitive operations
- Authorization: Role-based (tenant, broker, admin)
- Audit logging: ✅ All PII access logged with timestamp + user + action

### Incident Response
- Breach notification procedure: ✅ Documented (72-hour PPC window)
- Last drill: [DATE]
- Awareness training: [% of team trained] in last [PERIOD]

### Findings
- [ ] No issues
- [ ] Issue: [Description] → Risk: [Severity] → Mitigation: [Plan]

---

## 3. Third-Party Vendors (Sub-Processors)

### Current Sub-Processors
| Service | Purpose | DPA Status | Risk |
|---|---|---|---|
| AWS (RDS) | Database hosting | ✅ AWS DPA signed | Low |
| SendGrid | Email delivery | ⚠️ Terms reviewed; no formal DPA | Medium |
| Twilio | SMS 2FA | ✅ Twilio DPA signed | Low |
| [New vendor] | [Purpose] | ❌ DPA pending | High |

### Findings
- Sub-processor [Name]: Access scope is [data types] — appropriate / over-broad / under-specified
- Missing DPA: [Vendor] — Action: negotiate DPA or migrate by [DATE]

---

## 4. Data Retention & Deletion

### Current Policy
- Tenant PII: Retained 2 years post-renewal; auto-deleted after 30-day marking
- Broker data: Retained while account active; deleted 30 days after account closure
- Documents: Same as tenant retention
- Audit logs: Retained 7 years (regulatory requirement)

### Testing
- [ ] Manual test: Mark record for deletion → verify deleted after 30 days
- [ ] Batch test: Run deletion cron; verify count matches expectation
- [ ] Restore test: Recover from backup; verify old deletion marks are handled correctly

### Findings
- Retention policy: [Is appropriate / needs adjustment] because [Reason]
- Deletion success rate: [%] in last [Period]

---

## 5. Consent & Data Subject Rights

### Consent Mechanism
- Method: Checkbox + email confirmation at signup
- Retention: Records stored in `TenantConsent` table (7-year archive)
- Testing: [ ] Can verify consent for random sample of tenants

### Data Subject Rights (APPI Article 34)
- Export (DSR): ✅ Endpoint functional, tested
- Correction: ✅ Endpoint exists, partial workflow
- Deletion: ✅ Implemented (30-day marking + auto-delete)
- Cease processing: ⚠️ Opt-out function not implemented

### Findings
- Gap: Opt-out (cease processing without deletion) not implemented — Plan: implement by [DATE]
- UX: Consent notice is [clear / confusing] — Action: [Plan]

---

## 6. Regulatory & Legal Status

### APPI Compliance
- Compliance checklist: [# items ✅ / # items ⚠️ / # items ❌]
- Legal counsel review: [Last reviewed DATE]
- Unresolved counsel questions: [# outstanding]

### Broker Agreements
- Broker Terms of Service: ✅ Includes APPI data handling clauses
- Signed agreements: [#] brokers
- Enforcement: [Process for monitoring compliance]

### Findings
- [Finding]

---

## 7. Emerging Risks

### New Features in Pipeline
- Feature: [Name] — will collect [data] — needs [ ] consent update / [ ] DPA / [ ] retention rule
- Feature: [Name]

### External Changes
- Regulatory: [New law or guidance from PPC]
- Market: [Competitor action or industry shift]
- Technology: [New platform dependency]

---

## 8. Recommendations & Action Items

| Priority | Action | Owner | Deadline | Status |
|---|---|---|---|---|
| P0 | [Critical fix] | [Team] | [DATE] | ⏳ |
| P1 | [High priority] | [Team] | [DATE] | ⏳ |
| P2 | [Medium] | [Team] | [DATE] | ⏳ |
| P3 | [Nice to have] | [Team] | [DATE] | ⏳ |

---

## 9. Sign-Off

- Compliance Officer: _________________ Date: _______
- Legal Counsel (external): _________________ Date: _______
- CTO / VP Ops: _________________ Date: _______

---

## Appendices

- A. Detailed compliance checklist (from `appi-compliance-checklist.md`)
- B. Data flow diagrams (from `legal-review-packet.md`)
- C. Breach incident log (last 12 months)
- D. Audit log sample (random 50 records)
```

### Execution Steps

1. **Schedule PIA kickoff:** Q4, 1-week notice to team
2. **Gather evidence:** 
   - Pull compliance checklist (appi-compliance-checklist.md)
   - Extract audit logs (past 365 days)
   - List all third-party integrations + DPA status
   - Collect incident reports (if any)
3. **Conduct review meeting:** Compliance + legal + product + ops
4. **Document findings:** Fill template above
5. **Sign-off:** Get sign-offs from compliance officer, external counsel, CTO
6. **Publish:** Share with [運営会社名: TBD] leadership + regulatory file
7. **Track actions:** Use project management tool to monitor P0/P1 fixes

---

## Incident: Data Breach Notification (72-Hour Window)

**Owner:** On-Call Incident Commander  
**Trigger:** DB intrusion, unauthorized PII export, data corruption detected  
**Response Time:** First action within 30 minutes  
**Escalation:** Page @oncall-ops immediately

### Severity Levels

| Level | Examples | Response Time | PPC Notice? |
|---|---|---|---|
| **CRITICAL** | 10K+ tenant records exposed | Immediate | ✅ Within 72h |
| **HIGH** | 1K–10K records; likely re-identifiable | < 2 hours | ✅ Within 72h |
| **MEDIUM** | <1K records; anonymized or low-risk data | < 8 hours | ❓ Assess |
| **LOW** | Isolated record; minimal PII; quickly contained | < 24 hours | ❌ No notice needed |

### 30-Minute Response (Immediate)

#### Step 1: Confirm the Breach
```bash
# On-call ops verifies incident is real (not false alarm)
# Run diagnostics:
- Check DB access logs (any unauthorized connections?)
- Check API logs (mass export attempts?)
- Check file system (ransomware, file exfiltration?)
- Run antivirus/IDS scan

# Example:
tail -1000 /var/log/postgresql/postgresql.log | grep "FATAL\|ERROR"
curl http://localhost:8000/health  # Check app is up
```

#### Step 2: Isolate the Problem
```bash
# Do NOT shut down (loses forensic evidence)
# Instead: quarantine affected data
- If DB compromise: put app in read-only mode
- If single compromised user: revoke their OAuth token
- If ransomware: isolate network segment (don't unplug; keep logs)

# Example:
curl -X POST http://localhost:8000/admin/maintenance/read-only \
  --header "Authorization: Bearer $ADMIN_TOKEN" \
  --data '{"duration_minutes": 120}'
```

#### Step 3: Page Incident Commander + Compliance Officer
```bash
# Alert via PagerDuty / Slack
pagerduty-trigger --service "ancu365-breach-response" \
  --urgency "high" \
  --title "Potential APPI Data Breach Detected" \
  --description "DB anomaly detected. Isolating. ETA for severity assessment: 15 min."

slack-send --channel "@ancu365-incident-commander" \
  --message "🚨 BREACH ALERT: DB anomaly. Page: Incident Commander, Compliance Officer"
```

#### Step 4: Collect Evidence
```bash
# Preserve logs before anything is deleted (forensic principle)
cp /var/log/postgresql/postgresql.log* /secure-backup/forensics/
cp /var/log/ancu365/api.log* /secure-backup/forensics/
tar czf /secure-backup/forensics/system_logs_$(date +%Y-%m-%d_%H%M%S).tar.gz /var/log/
chmod 600 /secure-backup/forensics/
ls -lh /secure-backup/forensics/
```

### 2-Hour Assessment (Before 3-Hour Mark)

#### Step 5: Determine Breach Severity

**Breach Scope Query:**
```sql
-- Determine number & type of records exposed
SELECT
  COUNT(DISTINCT tenant_id) as tenants_exposed,
  COUNT(DISTINCT broker_id) as brokers_exposed,
  COUNT(*) as total_pii_fields_accessed
FROM audit_log
WHERE timestamp >= (NOW() - INTERVAL '24 hours')
  AND (
    action = 'UNAUTHORIZED_READ'
    OR (action = 'READ' AND ip_address NOT IN (SELECT ip_address FROM authorized_ips))
  );

-- Result example:
-- tenants_exposed | brokers_exposed | total_pii_fields
-- 8420            | 3               | 42100
```

**Severity Assessment:**
- 8420 tenants → CRITICAL (>1000 + re-identifiable)
- Notification: ✅ YES (PPC within 72h)

#### Step 6: Determine Root Cause
```bash
# Possible causes:
# 1. SQL injection (review API logs for suspicious queries)
# 2. Compromised employee account (check SSH login logs)
# 3. Ransomware / malware (run security scan)
# 4. Third-party breach (compromised Sendgrid/Twilio key)
# 5. Misconfigured S3 / public DB exposure

# Example: check for SQL injection patterns
grep -i "'; DROP\|UNION SELECT\|' OR '1'='1" /var/log/ancu365/api.log

# Example: check for compromised AWS keys
grep -r "AKIAIOSFODNN7EXAMPLE" /var/ancu365/config/ /etc/ancu365/
```

#### Step 7: Contain the Breach
```bash
# Depending on root cause:

# If employee account compromised:
- Reset password (if not yet done)
- Revoke SSH keys
- Revoke OAuth tokens issued to that account

# If API vulnerability (SQL injection):
- Deploy hotfix to production (restart app)
- Review other endpoints for similar vulnerability

# If third-party key leaked:
- Rotate API key immediately
- Notify third-party provider
- Check logs for unauthorized usage

# If DB exposed:
- Rotate DB password
- Restart Postgres
- Verify firewall rules (DB should not be public)
```

#### Step 8: Notify Legal & Compliance
```bash
# Call emergency meeting
pagerduty-trigger --escalation "legal-counsel-on-call" \
  --message "APPI breach confirmed. Assessment: CRITICAL. Tenants affected: 8420. Notify PPC within 72h."

# Prepare breach notification template (see below)
```

### 24-Hour Preparation (Before 72-Hour Mark)

#### Step 9: Prepare Breach Notification Document

**Template (in Japanese):**
```markdown
# データ侵害通知 — 個人情報保護委員会 (PPC) へ

【報告日】 2026-10-XX
【侵害日】 2026-10-XX (detected on)
【事業者】 [運営会社名: TBD]
【代表者】 [氏名]

## 1. 侵害の概要

**侵害の種類:** データベースへの不正アクセス
**影響を受けた個人:** 約8,420名
**対象データ:** 氏名、電話番号、メールアドレス、住所

## 2. 侵害の原因

**根本原因:** [SQL injection / Compromised key / etc.]
**発見:** 不正アクセス検知システムが自動検出
**検出日時:** 2026-10-XX HH:MM JST

## 3. 実施した対応

- ✅ システムの隔離 (read-only mode)
- ✅ ログの保存 (forensic evidence)
- ✅ 当該アクセスキーの無効化 / パスワード変更
- ✅ 法執行機関への相談 (TBD)

## 4. 本人への通知予定

- **通知方法:** メール + SMS
- **送信日:** 2026-10-XX
- **内容:**
  - 侵害の事実
  - 対象データの種類
  - 実施した対応
  - 本人の対応方法 (無料クレジット監視登録、連絡先)

## 5. 予防措置

- ✅ 脆弱性パッチの適用
- ✅ アクセス制御の強化
- ✅ セキュリティ監査の実施予定

---

報告者: [担当者名]
署名: ________________________
```

#### Step 10: Draft Notification Email (to Affected Tenants)

**Subject:** 重要: あなたの個人情報についてのお知らせ

**Body:**
```
【Ancu365】  ご登録いただいた個人情報に関するお知らせ

[氏名] 様

平素はAncu365をご利用いただきありがとうございます。

この度、弊社システムへの不正アクセスが発生し、ご登録いただいた個人情報の一部が
影響を受けた可能性があることをお知らせいたします。

【影響を受けた情報】
- お名前
- 電話番号
- メールアドレス
- ご住所

【弊社の対応】
1. 不正アクセスを即座に遮断し、システムを隔離いたしました
2. 法執行機関に報告いたしました
3. 個人情報保護委員会に報告いたしました

【ご本人への対応】
ご心配をおかけして申し訳ございません。
以下の対応をお勧めしています:

1. クレジット監視サービスへの登録 (無料 12ヶ月)
   → [登録リンク]

2. 定期的なクレジットレポート確認
   → [各信用情報機関へのリンク]

3. 本件についてのご質問
   → support@ancu365.jp (営業時間内)

ご質問やご不明な点は、お気軽にお問い合わせください。

今後、このようなご迷惑をおかけしないよう、セキュリティ体制の強化に全力で
取り組んでまいります。

よろしくお願いいたします。

Ancu365 運営チーム
```

#### Step 11: Deliver PPC Notification (Before 72-Hour Window)

```bash
# PPC contact form: https://www.ppc.go.jp/
# Submission method: Web form (Japanese) or certified mail

# Required info:
# - Business name, address, contact
# - Description of breach (date, type, scope)
# - Number of affected individuals
# - Root cause analysis
# - Remediation steps

# Example delivery:
curl -X POST https://www.ppc.go.jp/form/report-breach/ \
  --form "company_name=[運営会社名: TBD]" \
  --form "breach_date=2026-10-XX" \
  --form "affected_count=8420" \
  --form "data_types=name,phone,email,address" \
  --form "report_text=@/tmp/breach_report.txt"

# Verify delivery receipt
echo "✅ Breach notification submitted to PPC at $(date)"
```

#### Step 12: Post-Incident Follow-Up (Day 4–7)

```bash
# Day 4: Forensic analysis complete
- Prepare detailed incident report
- Identify all system changes needed
- Assign fix owners + deadlines

# Day 5: Remediation begins
- Deploy security patches
- Upgrade access controls
- Rotate all credentials (API keys, DB passwords)

# Day 7: Retrospective
- Incident review meeting (what went wrong, how to prevent)
- Post-mortem document shared with team
- Action items tracked in project management tool

# Example retrospective topics:
- Early warning signs we missed?
- Was alert automation working?
- How quickly did we isolate?
- How clear was the runbook?
```

---

## Related Documents

- **Legal Review Packet:** `legal-review-packet.md` (10 questions for counsel; data flows)
- **Compliance Checklist:** `appi-compliance-checklist.md` (20-item audit; evidence links)
- **Help Center:** `../launch-comms/` (customer comms templates)

---

## Contact List (Update Quarterly)

| Role | Name | Contact | Escalation |
|---|---|---|---|
| Compliance Officer | [Name] | [Email] | CTO |
| Legal Counsel (external) | [Law firm] | [Phone] | CEO |
| On-Call Ops | Pagerduty | oncall@ancu365.jp | Compliance Officer |
| PPC Liaison | [TBD] | TBD | Legal Counsel |

---

**Document Owner:** Ancu365 Operations & Compliance  
**Last Reviewed:** 2026-10-17  
**Next Review:** Quarterly (2026-12-17)  
**Emergency Contact:** [On-call number, Slack channel]
