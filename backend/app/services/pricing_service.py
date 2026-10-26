"""Pricing resolution — given (room, date), return effective nightly price.

Resolution order (highest priority wins):
    manual (1000) > holiday (500) > weekend (200) > base (100)

Weekend rule applies only if date weekday matches weekday_mask
(default 0b1100000 = Fri+Sat). Holiday rule simply applies on its date range.
Manual rule always wins inside its range. Base rule is the floor when no other
rule applies. Falls back to Room.base_price when even base rule is missing.
"""

from __future__ import annotations

from datetime import date as date_cls, datetime
from typing import Optional

from sqlalchemy.orm import Session

from app import models
from app.repositories.pricing_rule_repository import PricingRuleRepository

DEFAULT_PRIORITY = {
    "base": 100,
    "weekend": 200,
    "holiday": 500,
    "manual": 1000,
}
# Default weekend = Friday + Saturday (most homestay demand in VN).
DEFAULT_WEEKEND_MASK = (1 << 4) | (1 << 5)


def _parse_iso(d: str) -> date_cls:
    return datetime.strptime(str(d), "%Y-%m-%d").date()


def _weekday_bit(d: date_cls) -> int:
    """Mon=0..Sun=6 — matches Python datetime.weekday()."""
    return 1 << d.weekday()


def _rule_applies_on(rule: models.PricingRule, when: date_cls) -> bool:
    """Whether a rule's type-specific predicate matches the given date."""
    if rule.rule_type == "weekend":
        mask = rule.weekday_mask if rule.weekday_mask is not None else DEFAULT_WEEKEND_MASK
        return bool(mask & _weekday_bit(when))
    # base, holiday, manual: any day inside the range qualifies
    return True


def resolve_price(
    db: Session,
    host_id: int,
    room: models.Room,
    when: date_cls,
) -> float:
    """Resolve nightly price for a room on a specific date."""
    iso = when.isoformat()
    repo = PricingRuleRepository(db, host_id)
    candidates = repo.list_applicable(room_id=room.id, date=iso)
    for rule in candidates:  # already ordered priority desc
        if _rule_applies_on(rule, when):
            return float(rule.price_per_night)
    # Legacy nightly API may coexist with monthly channels. Its explicit nightly
    # channel price takes precedence over the ambiguous historical base_price.
    nightly = db.query(models.RoomKenh).filter_by(
        room_id=room.id, kenh="ngan_han", don_vi="dem", dang_bat=True
    ).first()
    if nightly is not None and nightly.gia > 0:
        return float(nightly.gia)
    return float(room.base_price or 0)


def resolve_default_priority(rule_type: str) -> int:
    return DEFAULT_PRIORITY.get(rule_type, 100)


def parse_iso_date(s: str) -> date_cls:
    """Re-exported helper so router doesn't need to import datetime directly."""
    return _parse_iso(s)
