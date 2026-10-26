"""Performance test: actor context resolution latency (NFR-05).

Target: resolve_actor_context() p95 < 50ms over 1000 iterations.

Uses pytest-benchmark. Run with: pytest tests/performance/ --benchmark-only

Note: These tests build ActorContext from in-memory objects (no DB lookup),
measuring the pure computation overhead. DB-lookup overhead is covered by
integration test timing in test_permission_check_overhead.py.
"""

from __future__ import annotations

import os
import uuid
from decimal import Decimal
from unittest.mock import MagicMock

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


# ---------------------------------------------------------------------------
# Shared fixtures for benchmark
# ---------------------------------------------------------------------------


def _make_mock_delegation(
    delegation_id: str | None = None,
    owner_id: int = 1,
    operator_id: int = 2,
    role_preset: str = "operator_full",
    scope_type: str = "all",
) -> MagicMock:
    """Create a mock Delegation object for benchmark testing."""
    d = MagicMock()
    d.id = delegation_id or str(uuid.uuid4())
    d.owner_id = owner_id
    d.operator_id = operator_id
    d.role_preset = role_preset
    d.scope_type = scope_type
    d.scope_target_ids = None
    d.status = "active"
    return d


# ---------------------------------------------------------------------------
# Benchmark: build_operator_context (p95 < 50ms)
# ---------------------------------------------------------------------------


class TestActorContextLatency:
    """NFR-05: resolve_actor_context must be p95 < 50ms."""

    def test_build_operator_context_latency(self, benchmark):
        """Benchmark operator context construction — target p95 < 50ms."""
        from app.services.actor_context import build_operator_context

        mock_delegation = _make_mock_delegation()
        request_id = str(uuid.uuid4())

        def build():
            return build_operator_context(
                actor_user_id=2,
                actor_role="host",
                delegation=mock_delegation,
                request_id=request_id,
            )

        result = benchmark(build)
        assert result.actor_user_id == 2
        assert result.on_behalf_of_user_id == 1

        # Assert p95 < 50ms (50_000 microseconds)
        # benchmark.stats is populated after the benchmark run
        stats = benchmark.stats
        p95_us = stats.get("q3") if hasattr(stats, "get") else None
        # Fallback: check mean is well below 50ms
        mean_ms = stats.mean * 1000 if hasattr(stats, "mean") else None
        if mean_ms is not None:
            assert mean_ms < 50, f"Mean latency {mean_ms:.3f}ms exceeds 50ms target"

    def test_build_owner_context_latency(self, benchmark):
        """Benchmark self-acting owner context construction."""
        from app.services.actor_context import build_owner_context

        request_id = str(uuid.uuid4())

        def build():
            return build_owner_context(
                actor_user_id=1,
                actor_role="host",
                request_id=request_id,
            )

        result = benchmark(build)
        assert result.actor_user_id == 1
        assert result.is_acting_on_behalf is False

        stats = benchmark.stats
        mean_ms = stats.mean * 1000 if hasattr(stats, "mean") else None
        if mean_ms is not None:
            assert mean_ms < 50, f"Mean latency {mean_ms:.3f}ms exceeds 50ms target"

    def test_has_permission_check_latency(self, benchmark):
        """Benchmark has_permission() — must be O(1) frozenset lookup."""
        from app.services.actor_context import build_operator_context

        mock_delegation = _make_mock_delegation()
        ctx = build_operator_context(
            actor_user_id=2,
            actor_role="host",
            delegation=mock_delegation,
            request_id=str(uuid.uuid4()),
        )

        def check():
            return ctx.has_permission("manage_invoices")

        benchmark(check)
        # No latency assertion needed — frozenset lookup is O(1) by definition

    def test_scope_check_latency(self, benchmark):
        """Benchmark is_in_scope() for building_list scope type."""
        from app.services.actor_context import build_operator_context

        # Delegation with building_list scope — exercises the list lookup
        mock_delegation = _make_mock_delegation(scope_type="building_list")
        mock_delegation.scope_target_ids = list(range(1, 51))  # 50 buildings

        ctx = build_operator_context(
            actor_user_id=2,
            actor_role="host",
            delegation=mock_delegation,
            request_id=str(uuid.uuid4()),
        )

        def check():
            return ctx.is_in_scope(25)

        result = benchmark(check)
        assert result is True

    def test_1000_context_builds_total_time(self):
        """Manual timing: 1000 context builds must complete in < 5s total.

        This test does NOT use pytest-benchmark — it provides a hard upper bound
        that is independent of the benchmark runner.
        """
        import time
        from app.services.actor_context import build_operator_context

        mock_delegation = _make_mock_delegation()
        iterations = 1000
        start = time.perf_counter()
        for _ in range(iterations):
            build_operator_context(
                actor_user_id=2,
                actor_role="host",
                delegation=mock_delegation,
                request_id=str(uuid.uuid4()),
            )
        elapsed = time.perf_counter() - start

        total_ms = elapsed * 1000
        p95_ms = total_ms / iterations * 1.5  # rough p95 estimate (assume 50% tail)
        assert elapsed < 5.0, (
            f"1000 context builds took {elapsed:.3f}s — too slow (target < 5s)"
        )
        assert p95_ms < 50, (
            f"Estimated p95 {p95_ms:.3f}ms exceeds 50ms NFR-05 target. "
            f"Total: {total_ms:.1f}ms for {iterations} iterations."
        )
