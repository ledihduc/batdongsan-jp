"""PricingRuleRepository — homestay nightly pricing rules (Phase 07)."""

from __future__ import annotations

from typing import Optional

from sqlalchemy import or_

from app import models
from app.repositories.base import HostScopedRepository


class PricingRuleRepository(HostScopedRepository[models.PricingRule]):
    model_class = models.PricingRule
    host_field_name = "host_id"

    def list_filtered(
        self,
        room_id: Optional[int] = None,
        house_id: Optional[int] = None,
        rule_type: Optional[str] = None,
    ) -> list[models.PricingRule]:
        q = self._base_query()
        if room_id is not None:
            q = q.filter(models.PricingRule.room_id == room_id)
        if house_id is not None:
            q = q.filter(models.PricingRule.house_id == house_id)
        if rule_type is not None:
            q = q.filter(models.PricingRule.rule_type == rule_type)
        return q.order_by(models.PricingRule.priority.desc()).all()

    def list_applicable(
        self, room_id: int, date: str
    ) -> list[models.PricingRule]:
        """Rules that may apply to (room_id, date), ordered by priority desc.

        Rule applies if room_id OR house_id matches; date in [start, end].
        """
        return (
            self._base_query()
            .filter(
                or_(
                    models.PricingRule.room_id == room_id,
                    models.PricingRule.room_id.is_(None),
                )
            )
            .filter(models.PricingRule.start_date <= date)
            .filter(models.PricingRule.end_date >= date)
            .order_by(models.PricingRule.priority.desc())
            .all()
        )
