-- ═══════════════════════════════════════════════════════════════════════
-- Release 1 (listing v2) — Post-deploy monitoring queries
-- Run every 12h for first 48h after prod rollout, then daily for 4 weeks.
-- Target DB: PostgreSQL prod / staging.
-- ═══════════════════════════════════════════════════════════════════════

-- ─── M1. Publish latency ───────────────────────────────────────────────
-- Auto-publish flow: newly-created house should be visible immediately.
-- Check that the created→visible gap is <5s p95 (DoD success metric).
-- For DoD purposes, "publish latency" ≈ 0 because default is 'published'.
-- Sanity check: no rows stuck in 'pending' after 5 minutes.
SELECT COUNT(*) AS stuck_in_pending
FROM houses
WHERE status = 'pending'
  AND created_at < NOW() - INTERVAL '5 minutes';
-- Expected: 0 (auto-publish removes the pending gate). Alert if >0.


-- ─── M2. Transaction type distribution (last 24h) ──────────────────────
-- Track sale post adoption. DoD target: sale ≥10% of new posts.
-- Beta gate: sale ≥5%. Alert if sale=0 after beta launch (killswitch stuck?).
SELECT
  transaction_type,
  COUNT(*) AS posts_24h,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM houses
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY transaction_type
ORDER BY posts_24h DESC;


-- ─── M3. Trusted flag coverage ─────────────────────────────────────────
-- DoD: ≥30% of top-viewed houses should be trusted after 4 weeks.
-- Sanity: total trusted count grows over time; admin PATCH audit lines up.
SELECT
  COUNT(*) FILTER (WHERE is_trusted) AS trusted_total,
  COUNT(*) FILTER (WHERE NOT is_trusted) AS untrusted_total,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE is_trusted) / NULLIF(COUNT(*), 0),
    2
  ) AS trusted_pct
FROM houses
WHERE status = 'published';


-- ─── M4. Status distribution — approved should trend to 0 ──────────────
-- After migration, `approved` should be 0 (all promoted to 'published').
-- If admin re-writes to 'approved' by mistake, count reappears.
SELECT status, COUNT(*) FROM houses GROUP BY status ORDER BY status;
-- Expected after migration: {published: N, rejected: M, hidden: K, pending: 0, approved: 0}.
-- Alert if approved > 0 more than 24h after migration.


-- ─── M5. Trusted PATCH audit integrity ─────────────────────────────────
-- Every trusted PATCH should leave a row in audit_logs (or equivalent).
-- Compare trusted_at deltas vs audit event count for a 24h window.
-- Requires an audit table with event='HOUSE_TRUSTED_TOGGLED'.
-- Adjust table/column names per actual schema.
SELECT
  COUNT(*) FILTER (WHERE trusted_at > NOW() - INTERVAL '24 hours') AS trusted_toggles_last_24h,
  (
    SELECT COUNT(*) FROM audit_logs
    WHERE event = 'HOUSE_TRUSTED_TOGGLED'
      AND created_at > NOW() - INTERVAL '24 hours'
  ) AS audit_events_last_24h;
-- Expected: audit_events ≥ trusted_toggles (audit also records OFF toggles).
-- Alert if audit_events < trusted_toggles.


-- ─── M6. H1 regression check — no host-driven status escalation ────────
-- Sanity: no house should transition from 'rejected' → 'published' without
-- an admin audit event within 10s of the change.
-- Requires status_change_log or equivalent — skip if not available.
-- Alternative: sample check of rejected houses and confirm status stable.
SELECT id, status, updated_at
FROM houses
WHERE status = 'rejected'
  AND updated_at > NOW() - INTERVAL '24 hours'
LIMIT 20;
-- Manual spot-check: none of these should have flipped to published.


-- ─── M7. Ward slug coverage (for Release 2 baseline) ───────────────────
-- Not blocking Release 1, but track as leading indicator for ward picker demand.
SELECT
  COUNT(*) FILTER (WHERE ward_slug IS NOT NULL) AS with_ward_slug,
  COUNT(*) FILTER (WHERE ward_slug_legacy IS NOT NULL) AS with_ward_slug_legacy,
  COUNT(*) FILTER (WHERE ward_slug IS NULL AND ward_slug_legacy IS NULL) AS neither,
  COUNT(*) AS total
FROM houses
WHERE status = 'published';


-- ─── M8. Legacy 'approved' cleanup progress ────────────────────────────
-- After migration + client-merge, existing 'approved' rows should be 0.
-- Track over time to know when to remove client-side merge in HouseProvider.
SELECT COUNT(*) AS legacy_approved_remaining
FROM houses
WHERE status = 'approved';
-- Expected: 0 for 2 consecutive weeks → safe to remove M1 client-merge.
