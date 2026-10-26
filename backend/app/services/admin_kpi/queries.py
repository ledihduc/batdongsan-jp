"""Admin KPI queries — 5 parameterized metrics for JP market analytics.

All functions take (org_id, prefecture, start, end) and return a scalar or dict.
Direct queries with indexes — no materialized views for MVP.

Indexes required (added in migration 0156+):
  jp_tenant_applications (org_id, created_at)
  jp_property_infos (org_id, prefecture, created_at)
  contracts (org_id, region, created_at)

Security: all parameters are bound params — no string interpolation.
Role enforcement: admin scope required at route level (not here).
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def _to_utc_str(dt: datetime) -> str:
    """Normalize datetime to UTC ISO string for SQL binding."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc).isoformat()
    return dt.astimezone(timezone.utc).isoformat()


def application_count(
    db: Session,
    *,
    org_id: str,
    prefecture: Optional[str] = None,
    start: datetime,
    end: datetime,
) -> int:
    """Count of tenant applications submitted in the period.

    Args:
        db:          SQLAlchemy session.
        org_id:      Broker org ID.
        prefecture:  JP prefecture filter (e.g. '東京都'). None = all.
        start:       Period start (inclusive).
        end:         Period end (exclusive).

    Returns:
        Integer count.
    """
    if prefecture:
        result = db.execute(
            text(
                "SELECT COUNT(a.id) FROM jp_tenant_applications a "
                "JOIN jp_property_infos p ON p.listing_id = a.listing_id "
                "WHERE a.org_id = :org_id "
                "  AND a.created_at >= :start AND a.created_at < :end "
                "  AND p.prefecture = :prefecture "
                "  AND a.region = 'jp'"
            ),
            {
                "org_id": org_id,
                "start": _to_utc_str(start),
                "end": _to_utc_str(end),
                "prefecture": prefecture,
            },
        )
    else:
        result = db.execute(
            text(
                "SELECT COUNT(id) FROM jp_tenant_applications "
                "WHERE org_id = :org_id "
                "  AND created_at >= :start AND created_at < :end "
                "  AND region = 'jp'"
            ),
            {"org_id": org_id, "start": _to_utc_str(start), "end": _to_utc_str(end)},
        )
    row = result.fetchone()
    return int(row[0]) if row and row[0] is not None else 0


def success_rate(
    db: Session,
    *,
    org_id: str,
    prefecture: Optional[str] = None,
    start: datetime,
    end: datetime,
) -> float:
    """Ratio of approved applications to total submitted applications.

    Returns 0.0 if no applications in period.
    """
    if prefecture:
        result = db.execute(
            text(
                "SELECT "
                "  COUNT(CASE WHEN a.status = 'approved' THEN 1 END) AS approved, "
                "  COUNT(a.id) AS total "
                "FROM jp_tenant_applications a "
                "JOIN jp_property_infos p ON p.listing_id = a.listing_id "
                "WHERE a.org_id = :org_id "
                "  AND a.created_at >= :start AND a.created_at < :end "
                "  AND p.prefecture = :prefecture "
                "  AND a.region = 'jp'"
            ),
            {
                "org_id": org_id,
                "start": _to_utc_str(start),
                "end": _to_utc_str(end),
                "prefecture": prefecture,
            },
        )
    else:
        result = db.execute(
            text(
                "SELECT "
                "  COUNT(CASE WHEN status = 'approved' THEN 1 END) AS approved, "
                "  COUNT(id) AS total "
                "FROM jp_tenant_applications "
                "WHERE org_id = :org_id "
                "  AND created_at >= :start AND created_at < :end "
                "  AND region = 'jp'"
            ),
            {"org_id": org_id, "start": _to_utc_str(start), "end": _to_utc_str(end)},
        )
    row = result.fetchone()
    if not row or not row[1]:
        return 0.0
    approved, total = int(row[0] or 0), int(row[1])
    return round(approved / total, 4) if total > 0 else 0.0


def avg_review_days(
    db: Session,
    *,
    org_id: str,
    prefecture: Optional[str] = None,
    start: datetime,
    end: datetime,
) -> float:
    """Average days from application submission to final review decision.

    Measures: decided_at - submitted_at for reviews with terminal decisions.
    Returns 0.0 if no reviewed applications in period.
    """
    if prefecture:
        result = db.execute(
            text(
                "SELECT AVG(EXTRACT(EPOCH FROM (r.decided_at - a.submitted_at)) / 86400.0) "
                "FROM jp_application_reviews r "
                "JOIN jp_tenant_applications a ON a.id = r.application_id "
                "JOIN jp_property_infos p ON p.listing_id = a.listing_id "
                "WHERE r.org_id = :org_id "
                "  AND r.decision IN ('approved', 'rejected') "
                "  AND r.decided_at >= :start AND r.decided_at < :end "
                "  AND p.prefecture = :prefecture "
                "  AND a.region = 'jp' "
                "  AND a.submitted_at IS NOT NULL"
            ),
            {
                "org_id": org_id,
                "start": _to_utc_str(start),
                "end": _to_utc_str(end),
                "prefecture": prefecture,
            },
        )
    else:
        result = db.execute(
            text(
                "SELECT AVG(EXTRACT(EPOCH FROM (r.decided_at - a.submitted_at)) / 86400.0) "
                "FROM jp_application_reviews r "
                "JOIN jp_tenant_applications a ON a.id = r.application_id "
                "WHERE r.org_id = :org_id "
                "  AND r.decision IN ('approved', 'rejected') "
                "  AND r.decided_at >= :start AND r.decided_at < :end "
                "  AND a.region = 'jp' "
                "  AND a.submitted_at IS NOT NULL"
            ),
            {"org_id": org_id, "start": _to_utc_str(start), "end": _to_utc_str(end)},
        )
    row = result.fetchone()
    if not row or row[0] is None:
        return 0.0
    return round(float(row[0]), 2)


def guarantor_approval_rate(
    db: Session,
    *,
    org_id: str,
    prefecture: Optional[str] = None,
    start: datetime,
    end: datetime,
) -> float:
    """Ratio of applications with approved guarantor (保証会社) to total reviewed.

    Approximation: approved applications that had a guarantor_name set.
    Returns 0.0 if no reviewed applications in period.
    """
    if prefecture:
        result = db.execute(
            text(
                "SELECT "
                "  COUNT(CASE WHEN a.status = 'approved' AND a.guarantor_name IS NOT NULL THEN 1 END) AS hoshou_approved, "
                "  COUNT(CASE WHEN a.status IN ('approved','rejected') THEN 1 END) AS total_reviewed "
                "FROM jp_tenant_applications a "
                "JOIN jp_property_infos p ON p.listing_id = a.listing_id "
                "WHERE a.org_id = :org_id "
                "  AND a.created_at >= :start AND a.created_at < :end "
                "  AND p.prefecture = :prefecture "
                "  AND a.region = 'jp'"
            ),
            {
                "org_id": org_id,
                "start": _to_utc_str(start),
                "end": _to_utc_str(end),
                "prefecture": prefecture,
            },
        )
    else:
        result = db.execute(
            text(
                "SELECT "
                "  COUNT(CASE WHEN status = 'approved' AND guarantor_name IS NOT NULL THEN 1 END) AS hoshou_approved, "
                "  COUNT(CASE WHEN status IN ('approved','rejected') THEN 1 END) AS total_reviewed "
                "FROM jp_tenant_applications "
                "WHERE org_id = :org_id "
                "  AND created_at >= :start AND created_at < :end "
                "  AND region = 'jp'"
            ),
            {"org_id": org_id, "start": _to_utc_str(start), "end": _to_utc_str(end)},
        )
    row = result.fetchone()
    if not row or not row[1]:
        return 0.0
    hoshou, total = int(row[0] or 0), int(row[1])
    return round(hoshou / total, 4) if total > 0 else 0.0


def vacancy_rate(
    db: Session,
    *,
    org_id: str,
    prefecture: Optional[str] = None,
    start: datetime,
    end: datetime,
) -> float:
    """空室率 — ratio of listings with no active application to total listings.

    Uses jp_listings snapshot for the period.
    Returns 0.0 if no listings for org in period.
    """
    if prefecture:
        result = db.execute(
            text(
                "SELECT "
                "  COUNT(CASE WHEN l.status = 'available' THEN 1 END) AS vacant, "
                "  COUNT(l.id) AS total "
                "FROM jp_listings l "
                "JOIN jp_property_infos p ON p.listing_id = l.id "
                "WHERE l.org_id = :org_id "
                "  AND l.created_at <= :end "
                "  AND (l.archived_at IS NULL OR l.archived_at >= :start) "
                "  AND p.prefecture = :prefecture "
                "  AND l.region = 'jp'"
            ),
            {
                "org_id": org_id,
                "start": _to_utc_str(start),
                "end": _to_utc_str(end),
                "prefecture": prefecture,
            },
        )
    else:
        result = db.execute(
            text(
                "SELECT "
                "  COUNT(CASE WHEN status = 'available' THEN 1 END) AS vacant, "
                "  COUNT(id) AS total "
                "FROM jp_listings "
                "WHERE org_id = :org_id "
                "  AND created_at <= :end "
                "  AND (archived_at IS NULL OR archived_at >= :start) "
                "  AND region = 'jp'"
            ),
            {"org_id": org_id, "start": _to_utc_str(start), "end": _to_utc_str(end)},
        )
    row = result.fetchone()
    if not row or not row[1]:
        return 0.0
    vacant, total = int(row[0] or 0), int(row[1])
    return round(vacant / total, 4) if total > 0 else 0.0


def compute_all_kpis(
    db: Session,
    *,
    org_id: str,
    prefecture: Optional[str] = None,
    start: datetime,
    end: datetime,
) -> dict[str, Any]:
    """Compute all 5 KPIs in one call.

    Returns:
        Dict with keys:
          application_count, success_rate, avg_review_days,
          guarantor_approval_rate, vacancy_rate, computed_at.
    """
    computed_at = datetime.now(timezone.utc).isoformat()

    kwargs: dict[str, Any] = {
        "org_id": org_id,
        "prefecture": prefecture,
        "start": start,
        "end": end,
    }

    try:
        app_count = application_count(db, **kwargs)
        s_rate = success_rate(db, **kwargs)
        review_days = avg_review_days(db, **kwargs)
        hoshou_rate = guarantor_approval_rate(db, **kwargs)
        vac_rate = vacancy_rate(db, **kwargs)
    except Exception as exc:
        logger.error("KPI computation failed: org=%s err=%s", org_id, exc)
        raise

    return {
        "application_count": app_count,
        "success_rate": s_rate,
        "avg_review_days": review_days,
        "guarantor_approval_rate": hoshou_rate,
        "vacancy_rate": vac_rate,
        "computed_at": computed_at,
    }
