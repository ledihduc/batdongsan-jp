# JP Launch — Decisions Log

Decided 2026-10-17. Supersedes "Open questions" sections of phase-04 plans.

## 1. Infra scope — Tokyo only at launch

- **Primary region:** `ap-northeast-1` (Tokyo), single-region deploy at launch.
- **Osaka DR (`ap-northeast-3`):** **Deferred** to post-launch (quarter after launch stabilizes). RTO/RPO formal targets drafted but not implemented day 1.
- **Rationale:** Osaka DR doubles infra cost + ops surface before we have real traffic patterns. Launch with Tokyo + PITR + cross-region S3 backup; add Osaka DR only when business justifies.

## 2. RDS sizing

- **Staging:** `db.t4g.medium`, **single-AZ**, 7-day PITR.
- **Production:** `db.t4g.medium`, **Multi-AZ**, 14-day PITR, cross-region backup to `ap-northeast-3`.
- **Scale path:** vertical to `db.r6g.large` when sustained CPU > 60 % for 7 days, or storage > 70 %.

## 3. Help Center scope day 1

- **Languages shipped:** **JP only** (14 articles in `assets/jp/help/`).
- **EN translation:** Deferred to post-launch. English help routed to a static "support@" email until translated articles ship.
- **Rationale:** The JP market launch audience is JP-native. EN would be yak-shaving before validating product-market fit.

## 4. Operator legal entity

- **Working entity:** **Synora K.K.** (株式会社シノラ).
- **Status:** Working placeholder in all legal footer text + comms templates until legal entity registration confirmed by counsel.
- **Lock date:** Must be finalized before legal footer goes live on prod. If a different entity (e.g. offshore + JP representative) is selected after lawyer review, run find+replace across:
  - `lib/l10n/app_*.arb` → `legalFooterCopyright`
  - `docs/jp/launch-comms/*.md`
  - `docs/jp/legal-review-packet.md`
  - All `assets/jp/help/*.md` footers that reference the operator.

## 5. Seed script schema status

- `scripts/seed_jp_launch.py` has a **preflight schema check** that will refuse to run if required tables (`organizations`, `jp_listings`) do not exist in the DB.
- Current state (migration 0159): those tables do **not** exist. Actual listing table is `houses`; `org_id` is a soft VARCHAR tag on JP side-tables, not a dedicated `organizations` table.
- **Resolution path (pick one before staging seed run):**
  - **A.** Author a new migration (0160+) that adds `organizations` + `jp_listings` tables matching the seed script's expectations.
  - **B.** Rewrite seed's `_seed_orgs` + `_seed_listings` to target existing tables (`users` with broker role + `houses`).
- **Recommendation:** Option B. Tracked as a P4-residual task; not blocking E2E tests (they stub against mock repos) nor the compliance endpoint.

## 6. Lawyer engagement

- Packet ready: `docs/jp/legal-review-packet.md` + `docs/jp/appi-compliance-checklist.md`.
- Engagement email draft: `docs/jp/launch-comms/lawyer-engagement-email-ja.md`.
- Target: book 90-minute consultation within 2 weeks of launch intent date.
- Deliverables expected from counsel: written opinion on the 10 numbered questions + 特商法 notice template filled with Synora K.K. details.
