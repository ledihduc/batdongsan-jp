"""McpRateLimiter: cửa sổ cố định 60 s, tổng + theo khoá, không theo IP (plan 20261027-1102 Phase 07, T9, AC11)."""

from __future__ import annotations

from app.mcp.rate_limit import McpRateLimiter


def _limiter(total: int = 10, per_key: int = 10):
    now = [0.0]
    return now, McpRateLimiter(total_per_min=total, per_key_per_min=per_key, clock=lambda: now[0])


def test_mcp_rate_limiter_total_exceeded_returns_false():
    # Arrange
    _, lim = _limiter(total=2)
    # Act
    results = [lim.allow_request() for _ in range(3)]
    # Assert
    assert results == [True, True, False]


def test_mcp_rate_limiter_window_resets_after_sixty_seconds():
    # Arrange
    now, lim = _limiter(total=1)
    assert lim.allow_request() is True
    assert lim.allow_request() is False
    # Act
    now[0] = 61.0
    # Assert
    assert lim.allow_request() is True


def test_mcp_rate_limiter_per_key_counts_separately():
    # Arrange
    _, lim = _limiter(per_key=1)
    # Act / Assert
    assert lim.allow_key("run_action:a") is True
    assert lim.allow_key("run_action:a") is False
    assert lim.allow_key("run_action:b") is True


def test_mcp_rate_limiter_per_key_window_resets_after_sixty_seconds():
    # Arrange
    now, lim = _limiter(per_key=1)
    assert lim.allow_key("get_system_skills") is True
    assert lim.allow_key("get_system_skills") is False
    # Act
    now[0] = 60.5
    # Assert
    assert lim.allow_key("get_system_skills") is True
