# Phase 12 — Rollout (Release 1)

**Priority:** P0 (last step of Release 1)
**Depends on:** Phase 11 DONE (46/46 tests pass, analyze 0 errors, code review APPROVED)
**Status:** READY FOR STAGING — awaiting deploy authorization

## Context

- Plan overview: `plan.md` §12
- Remediation report: `reports/remediation-h1-m1-m7.md`
- Verification: `reports/code-review-remediation-verification.md` (APPROVED)
- Phase 11 report: `phase-11-tests-qa.md`

## Pre-flight (already verified 2026-07-04)

| Check | Command | Result |
|-------|---------|--------|
| Backend tests | `.venv/bin/python -m pytest tests/test_houses_transaction_type.py tests/test_admin_trusted.py -q` | 21/21 pass |
| Flutter Phase 11 tests | `flutter test test/data/models/house_model_v2_test.dart test/widgets/ds_trusted_badge_test.dart` | 20/20 pass |
| Flutter analyze | `flutter analyze lib/` | 0 errors (209 pre-existing info/warnings, none new) |
| Migration reversible | Code review of `alembic/versions/0039_listing_v2.py` | Dialect guards ✓, downgrade drops in reverse order ✓ |
| Feature flag killswitch | Trace `kListingV2Enabled` call-sites | Post form gated; **guest home selector NOT gated** — see Known Gaps |

## Migration to run on staging

```
DATABASE_URL="postgresql://…staging…" alembic upgrade head
```

Expected: applies `0039_listing_v2` which
- Adds 6 columns: `transaction_type`, `is_trusted`, `trusted_at`, `trusted_by_admin_id`, `ward_slug`, `ward_slug_legacy`
- Adds 6 single-column indices + 1 composite (`ix_houses_tx_status_trusted`)
- Data migration: `UPDATE houses SET status='published' WHERE status='approved'`

**Reversible:** `alembic downgrade 0038_houses_rejection_reason` reverses everything including the `approved → published` data step.

## Staging deploy sequence

### Step 1 — Backend

1. Pull main to staging box.
2. Apply migration:
   ```bash
   DATABASE_URL="$STAGING_DB_URL" alembic upgrade head
   ```
3. Restart FastAPI process.
4. Smoke-check health endpoint returns 200.

### Step 2 — Flutter app

Build with flag ON (default):
```bash
flutter build apk --dart-define=LISTING_V2_ENABLED=true --dart-define=API_BASE_URL="$STAGING_API"
# or ipa / web equivalent
```

Distribute to internal testers via Firebase App Distribution / TestFlight.

### Step 3 — Staging smoke test (5 minutes)

Manual walkthrough on staging build:

| # | Path | Expected |
|---|------|----------|
| S1 | Guest home loads | Shows "Cho thuê" tab active by default, listings render |
| S2 | Tap "Mua bán" pill | Filter switches to `transaction_type=sale`, list may be empty on fresh staging |
| S3 | Host post: pick "Đăng bán", submit | 201 Created, house immediately visible on guest home Mua bán tab |
| S4 | Host post: pick "Đăng cho thuê", submit | 201 Created, appears on Cho thuê tab |
| S5 | Admin login → `Đánh dấu uy tín` tab | Two lists load (published + legacy approved), no duplicates |
| S6 | Admin toggle trusted on a house | Optimistic ON, badge appears on guest card within 1 refresh |
| S7 | Admin toggle trusted OFF | Optimistic OFF, badge disappears; refresh confirms |
| S8 | Simulate PUT with `status=published` on a rejected house (via curl or Postman) | 200 OK but DB row remains `rejected` (H1 fix) |
| S9 | Host tries to edit own published house title | Title updates, `status` unchanged |

### Step 4 — Killswitch verification (Q3 from remediation)

Rebuild app with flag OFF:
```bash
flutter build apk --dart-define=LISTING_V2_ENABLED=false --dart-define=API_BASE_URL="$STAGING_API"
```

Verify:
- Post form: No "Đăng bán / Đăng cho thuê" picker visible → all new posts default to `transaction_type=rent`.
- Guest home: Selector still visible (known gap — see below) — sale tab shows empty for legacy data.
- Existing rent listings display normally.

**Rebuild with flag ON to continue rollout.**

## Beta rollout (10 users)

**Duration:** 48h minimum, up to 1 week.

**Target group:** 10 internal + trusted host users. Send app build via Firebase App Distribution.

**Ask them to:**
1. Post at least 1 rent + 1 sale listing.
2. Toggle wishlist on a trusted-badge house.
3. Report any crash/UX issue.

**Monitor via SQL** (see `monitoring-queries.sql` in this same folder).

**Success gate to prod:**
- 0 crash reports involving new fields
- Sale post ratio ≥5% (D-level, R6 mitigation)
- Trusted PATCH audit count matches admin's manual actions (audit integrity)
- No support tickets about "tin bị mất" (auto-publish confusion)

## Prod deploy

Only after beta gate passes.

1. Same migration on prod:
   ```bash
   DATABASE_URL="$PROD_DB_URL" alembic upgrade head
   ```
2. Build prod app with flag ON:
   ```bash
   flutter build apk --release --dart-define=LISTING_V2_ENABLED=true --dart-define=API_BASE_URL="$PROD_API"
   ```
3. Submit to Play Store / App Store review.

**Rollout cadence:**
- Play Store: staged rollout 10% → 25% → 50% → 100% over 3 days
- App Store: phased release (Apple's default 7-day ramp)

## Post-deploy monitoring (first 48h)

Run every 12h — see `monitoring-queries.sql`:

1. **Publish latency** — POST→visible on guest home (should be <5s p95)
2. **Sale post ratio** — `transaction_type='sale'` count / total posts (target ≥10%, floor ≥1%)
3. **Trusted flag coverage** — houses with `is_trusted=true` / total published (target ≥30% top-viewed)
4. **Status regression** — `SELECT COUNT(*) FROM houses WHERE status='approved'` should trend to 0 after 4 weeks

## Rollback playbook

### Rollback via flag flip (fastest, ~10 min)

If UX bug found, no DB damage:
1. Rebuild app with `--dart-define=LISTING_V2_ENABLED=false`
2. Distribute new build (users still on old build stay on v2 UI until they update)
3. Backend unchanged — sale posts still work but new posts from flag-off users default to rent

### Rollback via migration downgrade (data-touching)

If schema/data corruption:
1. Take app offline (503 static page)
2. Downgrade DB:
   ```bash
   DATABASE_URL="$PROD_DB_URL" alembic downgrade 0038_houses_rejection_reason
   ```
   - Reverts `status='published' → 'approved'` for ALL rows (including originally-published ones — accept the noise)
   - Drops 6 columns
3. Deploy prior app build (pre-Release 1).
4. Bring app back online.

**DO NOT downgrade if:**
- Users have posted sale listings — the `transaction_type='sale'` data would be dropped
- Admin has flagged any house — `is_trusted`, `trusted_at` data would be dropped

If sale/trusted data exists and downgrade is needed: manually export those rows first, downgrade, then decide what to do with export.

## Known gaps (accepted for Release 1)

| # | Gap | Impact | Mitigation |
|---|-----|--------|-----------|
| G1 | Guest home `_TransactionTypeSelector` not gated by `kListingV2Enabled` | With flag OFF, sale tab still visible but empty | Users default to rent tab; no functional break. Fix in follow-up PR when private widget is extracted (Phase 11 deferred item). |
| G2 | Admin `HouseProvider` `fetchHousesByStatus('published')` merges `approved` client-side | Extra HTTP call to legacy status | Remove after data migration bakes in for 2 weeks (per remediation M1 follow-up). |
| G3 | Rate-limit deferred (D5) | Potential spam risk | Manual admin "Ẩn tin" 1-click available; audit log tracks abuse; report abuse in v2. |
| G4 | No ward picker (F5 defer) | Legacy address-only inputs | Not blocking Release 1; ward picker is Release 2. |

## Open questions after rollout

- Q1 (from remediation) — Backend allowlist ownership for `houses.py` PUT: **decide before Release 2** which team owns it.
- Q2 — Server-side `approved → published` alias on admin GET: **evaluate after G2 removed** whether client-merge should be permanent or moved server-side.
- **Q4 (new) — G1 fix priority:** ship in same sprint as Phase 11 follow-up widget extraction, or wait for user report?

## Definition of Done

- [ ] Staging migration applied, no errors
- [ ] S1–S9 smoke tests pass on staging build
- [ ] Killswitch verified with flag OFF build
- [ ] Beta group notified, feedback window open ≥48h
- [ ] Beta success gate met (see "Beta rollout" section)
- [ ] Prod migration applied
- [ ] Prod app build submitted to stores
- [ ] Monitoring queries scheduled every 12h for 48h
- [ ] Rollback playbook printed / linked in on-call runbook
