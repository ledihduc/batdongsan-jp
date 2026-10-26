# Tokyo Deploy Runbook — ancu365 JP Backend

**Region:** ap-northeast-1 (Tokyo)  
**Stack:** FastAPI + PostgreSQL RDS + nginx + Docker Compose  
**Compliance:** APPI (個人情報保護法)  
**Last updated:** 2026-10-17

---

## Pre-Deployment Checklist

- [ ] RDS instance created and accessible from EC2
- [ ] `env.jp.template` filled out as `.env.jp` on the server
- [ ] Docker image built and pushed: `ancu365-backend:jp-<tag>`
- [ ] Alembic migrations reviewed and ready
- [ ] `./check.sh` passes on the codebase
- [ ] Seed data script tested on staging DB
- [ ] PITR (Point-in-Time Recovery) enabled on RDS
- [ ] Backup strategy verified (see Backup section below)

---

## 1. RDS Setup (First Deploy Only)

### 1.1 Create RDS Instance

```bash
# Tokyo (ap-northeast-1), Multi-AZ recommended for production
aws rds create-db-instance \
  --db-instance-identifier ancu365-jp-prod \
  --db-instance-class db.t4g.medium \
  --engine postgres \
  --engine-version 16.2 \
  --master-username ancu365_admin \
  --master-user-password "$(openssl rand -base64 32)" \
  --vpc-security-group-ids sg-XXXX \
  --db-subnet-group-name ancu365-jp-subnet-group \
  --storage-type gp3 \
  --allocated-storage 100 \
  --max-allocated-storage 500 \
  --backup-retention-period 7 \
  --enable-performance-insights \
  --multi-az \
  --deletion-protection \
  --region ap-northeast-1
```

### 1.2 Enable PITR

Point-in-Time Recovery is enabled by default when `--backup-retention-period` > 0.
Verify:

```bash
aws rds describe-db-instances \
  --db-instance-identifier ancu365-jp-prod \
  --query 'DBInstances[0].BackupRetentionPeriod' \
  --region ap-northeast-1
# Must return 7 (days)
```

### 1.3 Create App DB + User

```bash
# Connect to RDS as admin
psql "postgresql://ancu365_admin:<password>@<rds-endpoint>:5432/postgres"

-- Create app database
CREATE DATABASE ancu365_jp
  WITH ENCODING 'UTF8'
  LC_COLLATE 'ja_JP.UTF-8'
  LC_CTYPE 'ja_JP.UTF-8'
  TEMPLATE template0;

-- Create app user (restricted permissions)
CREATE USER ancu365_app WITH PASSWORD '<strong-random-password>';
GRANT CONNECT ON DATABASE ancu365_jp TO ancu365_app;
GRANT USAGE ON SCHEMA public TO ancu365_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ancu365_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ancu365_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ancu365_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ancu365_app;
```

---

## 2. Initial Deploy

### 2.1 Prepare Server

```bash
# On EC2 instance (Amazon Linux 2023)
sudo yum install -y docker docker-compose-plugin git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
# Re-login for group to take effect

# Pull the repo or copy compose files
mkdir -p /opt/ancu365-jp
scp docker-compose.prod.yml deploy/jp/docker-compose.jp.yml deploy/jp/nginx.jp.conf \
    ec2-user@<jp-ec2-ip>:/opt/ancu365-jp/
```

### 2.2 Set Environment Variables

```bash
# On EC2, create .env.jp from template
cp deploy/jp/env.jp.template /opt/ancu365-jp/.env.jp
# Fill in all values (NEVER commit this file)
nano /opt/ancu365-jp/.env.jp

# Verify no placeholder values remain
grep "REPLACE_WITH" /opt/ancu365-jp/.env.jp
# Should return empty (no matches)
```

### 2.3 Run Alembic Migrations

```bash
# Run migrations against Tokyo RDS
docker run --rm \
  --env-file /opt/ancu365-jp/.env.jp \
  ancu365-backend:jp-<tag> \
  alembic upgrade head

# Verify migrations applied
docker run --rm \
  --env-file /opt/ancu365-jp/.env.jp \
  ancu365-backend:jp-<tag> \
  alembic current
```

### 2.4 Seed Launch Data (Staging Only)

```bash
# Run seed script (staging env only)
docker run --rm \
  --env-file /opt/ancu365-jp/.env.jp \
  ancu365-backend:jp-<tag> \
  python scripts/seed_jp_launch.py --env=staging
```

### 2.5 Start Services

```bash
cd /opt/ancu365-jp
docker compose \
  --env-file .env.jp \
  -f docker-compose.prod.yml \
  -f deploy/jp/docker-compose.jp.yml \
  up -d

# Verify containers are running
docker compose ps
```

---

## 3. Backup Strategy

### 3.1 RDS Automated Backups

- Automated daily backups: enabled via `--backup-retention-period 7`
- Backup window: 03:00–04:00 JST (low traffic)
- PITR: restore to any point within 7 days

### 3.2 Manual Snapshot Before Major Deploy

```bash
# Create snapshot before any major migration
aws rds create-db-snapshot \
  --db-instance-identifier ancu365-jp-prod \
  --db-snapshot-identifier ancu365-jp-pre-deploy-$(date +%Y%m%d) \
  --region ap-northeast-1

# Wait for snapshot to complete
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier ancu365-jp-pre-deploy-$(date +%Y%m%d) \
  --region ap-northeast-1
```

### 3.3 Upload Backup

Uploads (jp_uploads volume) are on a separate EBS volume. Snapshot EBS separately:

```bash
# Find EBS volume ID
aws ec2 describe-volumes \
  --filters "Name=tag:Name,Values=jp-uploads" \
  --query 'Volumes[0].VolumeId' \
  --region ap-northeast-1

# Create snapshot
aws ec2 create-snapshot \
  --volume-id vol-XXXX \
  --description "jp-uploads-$(date +%Y%m%d)" \
  --region ap-northeast-1
```

---

## 4. Cron Verification

### 4.1 Verify Deletion Cron Running

After startup, confirm APScheduler registered the deletion cron:

```bash
# Check backend logs for cron registration
docker compose logs backend | grep "Deletion cron registered"
# Expected: "Deletion cron registered: daily 03:00 JST"

docker compose logs backend | grep "Renewal cron"
# Expected: similar registration log
```

### 4.2 Verify Cron Job List (if APScheduler admin is exposed)

```bash
# Optional: if admin debug endpoint is enabled
curl -H "Authorization: Bearer <admin-token>" \
  http://localhost:3000/api/jp/admin/cron/status
```

### 4.3 Monitor Cron Execution

```bash
# Watch for cron execution logs at 03:00 JST
docker compose logs -f backend | grep "cron"
# Expected daily at 03:00 JST:
#   "Deletion cron: running at 2026-10-17T18:00:00+00:00"
#   "Deletion cron complete: purged=0 total=0"
```

---

## 5. Smoke Test

After deploy, run the smoke test checklist:

```bash
BASE_URL=http://localhost:3000

# Health check
curl -f $BASE_URL/healthz && echo "PASS: /healthz"

# JP region gate
curl -H "REGION: jp" $BASE_URL/api/jp/listings && echo "PASS: /api/jp/listings"

# Admin KPIs (requires valid admin JWT)
ADMIN_TOKEN=$(curl -s -X POST $BASE_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@ancu365.jp","password":"<admin-password>"}' \
  | jq -r '.access_token')

curl -f -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/api/jp/admin/kpis?prefecture=東京都" && echo "PASS: /api/jp/admin/kpis"

# Compliance evidence
curl -f -H "Authorization: Bearer $ADMIN_TOKEN" \
  $BASE_URL/api/jp/compliance/evidence && echo "PASS: /api/jp/compliance/evidence"
```

---

## 6. Rollback Drill

### 6.1 Rollback Docker Image

```bash
cd /opt/ancu365-jp
# Set previous tag
JP_IMAGE_TAG=ancu365-backend:jp-<previous-tag>

docker compose \
  --env-file .env.jp \
  -f docker-compose.prod.yml \
  -f deploy/jp/docker-compose.jp.yml \
  up -d --no-deps backend
```

### 6.2 Rollback Database Migration

```bash
# Rollback last migration
docker run --rm \
  --env-file /opt/ancu365-jp/.env.jp \
  ancu365-backend:jp-<previous-tag> \
  alembic downgrade -1

# Verify current migration
docker run --rm \
  --env-file /opt/ancu365-jp/.env.jp \
  ancu365-backend:jp-<previous-tag> \
  alembic current
```

### 6.3 Restore from RDS PITR

Only needed for data corruption. PITR creates a new RDS instance:

```bash
# Restore to specific timestamp
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier ancu365-jp-prod \
  --target-db-instance-identifier ancu365-jp-restore-$(date +%Y%m%d) \
  --restore-time 2026-10-17T02:00:00Z \
  --db-instance-class db.t4g.medium \
  --region ap-northeast-1

# After restore: update TOKYO_RDS_URL in .env.jp to point to restored instance
# Then redeploy using section 2.5
```

---

## 7. PII Key Rotation

Fernet keys must be rotated periodically (recommended: every 90 days) and when a key may be compromised.

### 7.1 Generate New Key

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### 7.2 Apply Rotation

```bash
# 1. Record rotation in audit log
psql $TOKYO_RDS_URL -c "
  INSERT INTO pii_key_rotation_log (rotated_at, rotated_by, reason)
  VALUES (NOW(), 'ops-team', 'scheduled 90-day rotation');
"

# 2. Update JP_FERNET_KEY in .env.jp
nano /opt/ancu365-jp/.env.jp

# 3. Re-encrypt existing PII fields (run backfill script if one exists)
# 4. Redeploy backend with new key
docker compose \
  --env-file .env.jp \
  -f docker-compose.prod.yml \
  -f deploy/jp/docker-compose.jp.yml \
  up -d --no-deps backend
```

---

## 8. APPI Compliance Evidence

For legal audits, retrieve the compliance evidence snapshot:

```bash
ADMIN_TOKEN=<admin-jwt>
curl -f -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:3000/api/jp/compliance/evidence | jq .
```

Expected response fields:
- `appi_consented_users_count`: >= 0
- `last_deletion_cron_run`: ISO datetime of last deletion cron
- `last_deletion_purged_count`: users anonymized in last run
- `pii_key_rotation_date`: ISO date of last Fernet key rotation
- `hmac_rotation_ledger`: per-org webhook secret rotation history
- `generated_at`: snapshot generation time

---

## Open Questions / Deferred Items

- Osaka DR (ap-northeast-3): evaluate after Tokyo launch stabilizes.
- RDS Multi-AZ cost: use single-AZ for staging, Multi-AZ for prod.
- Monitoring: integrate with CloudWatch + Sentry DSN before public launch.
- CDN: CloudFront for uploads (jp_uploads) — evaluate for media-heavy listings.
