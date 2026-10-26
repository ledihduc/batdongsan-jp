"""Performance test: permission check overhead (Phase 11).

Target: require_actor_with_permission adds < 10ms overhead vs baseline.

Tests measure:
  - Baseline: raw dict lookup / no permission check
  - With permission check via has_permission()
  - Delta must be < 10ms

Uses pytest-benchmark. Run: pytest tests/performance/ --benchmark-only
"""

from __future__ import annotations

import os
import time
import uuid
from decimal import Decimal
from unittest.mock import MagicMock

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


def _make_operator_ctx() -> object:
    from app.services.actor_context import build_operator_context

    mock_delegation = MagicMock()
    mock_delegation.id = str(uuid.uuid4())
    mock_delegation.owner_id = 1
    mock_delegation.operator_id = 2
    mock_delegation.role_preset = "operator_full"
    mock_delegation.scope_type = "all"
    mock_delegation.scope_target_ids = None
    mock_delegation.status = "active"

    return build_operator_context(
        actor_user_id=2,
        actor_role="host",
        delegation=mock_delegation,
        request_id=str(uuid.uuid4()),
    )


# ---------------------------------------------------------------------------
# Baseline: no permission check
# ---------------------------------------------------------------------------


class TestPermissionCheckOverhead:
    """Verify permission check overhead is negligible (< 10ms vs no-op baseline)."""

    def test_baseline_noop(self, benchmark):
        """Baseline: simple attribute access with no permission gate."""
        ctx = _make_operator_ctx()

        def noop():
            _ = ctx.actor_user_id
            return True

        benchmark(noop)

    def test_with_permission_check(self, benchmark):
        """With has_permission() call — should be within 10ms of baseline."""
        ctx = _make_operator_ctx()

        def with_permission():
            return ctx.has_permission("invoice.create")

        result = benchmark(with_permission)
        assert result is True

    def test_with_scope_check(self, benchmark):
        """With is_in_scope() — building_list scope traversal."""
        from app.services.actor_context import build_operator_context

        mock_delegation = MagicMock()
        mock_delegation.id = str(uuid.uuid4())
        mock_delegation.owner_id = 1
        mock_delegation.operator_id = 2
        mock_delegation.role_preset = "operator_full"
        mock_delegation.scope_type = "building_list"
        mock_delegation.scope_target_ids = list(range(1, 51))  # 50 buildings
        mock_delegation.status = "active"

        ctx = build_operator_context(
            actor_user_id=2,
            actor_role="host",
            delegation=mock_delegation,
            request_id=str(uuid.uuid4()),
        )

        def with_scope():
            return ctx.is_in_scope(25)

        result = benchmark(with_scope)
        assert result is True

    def test_combined_permission_and_scope(self, benchmark):
        """Combined permission + scope check — most expensive realistic path."""
        from app.services.actor_context import build_operator_context

        mock_delegation = MagicMock()
        mock_delegation.id = str(uuid.uuid4())
        mock_delegation.owner_id = 1
        mock_delegation.operator_id = 2
        mock_delegation.role_preset = "accountant"
        mock_delegation.scope_type = "building_list"
        mock_delegation.scope_target_ids = list(range(100, 150))  # 50 buildings
        mock_delegation.status = "active"

        ctx = build_operator_context(
            actor_user_id=2,
            actor_role="host",
            delegation=mock_delegation,
            request_id=str(uuid.uuid4()),
        )

        def combined():
            has_perm = ctx.has_permission("view_invoices")
            in_scope = ctx.is_in_scope(125)
            return has_perm and in_scope

        benchmark(combined)

    def test_overhead_below_10ms_manual(self):
        """Manual timing: confirm permission check overhead is < 10ms vs no-op.

        Runs 10000 iterations of each path, computes per-call delta.
        """
        ctx = _make_operator_ctx()
        iterations = 10_000

        # Baseline: noop
        start = time.perf_counter()
        for _ in range(iterations):
            _ = ctx.actor_user_id
        baseline_total = time.perf_counter() - start

        # With permission check
        start = time.perf_counter()
        for _ in range(iterations):
            ctx.has_permission("invoice.create")
        check_total = time.perf_counter() - start

        delta_per_call_ms = ((check_total - baseline_total) / iterations) * 1000
        # Allow negative delta (measurement noise)
        assert delta_per_call_ms < 10, (
            f"Permission check overhead {delta_per_call_ms:.4f}ms/call exceeds 10ms target. "
            f"Baseline: {baseline_total*1000:.2f}ms, With check: {check_total*1000:.2f}ms "
            f"for {iterations} iterations."
        )
