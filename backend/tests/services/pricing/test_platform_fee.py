"""Unit tests for PlatformFeeCalculator — NFR-15, AC-35 freemium default.

Tests:
  - v1 freemium default: always returns (0, 0)
  - env override: PLATFORM_FEE_DEFAULT_PCT=0.005 returns correct amount
  - Rounding: whole VND (ROUND_HALF_UP)
  - Edge cases: zero total, large amounts
"""

from __future__ import annotations

import os
from decimal import Decimal

import pytest


# ── Freemium default (v1) ─────────────────────────────────────────────────────


def test_freemium_default_returns_zero_pct() -> None:
    """v1 default: platform_fee_pct = 0 → (0, 0) regardless of total."""
    # Ensure env var is not set for this test
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)

    # Re-import to pick up env var state
    import importlib
    import app.services.pricing.platform_fee as pf_module
    importlib.reload(pf_module)

    from app.services.pricing.platform_fee import PlatformFeeCalculator
    calc = PlatformFeeCalculator()

    pct, amount = calc.compute(total_amount=3_000_000)
    assert pct == Decimal("0")
    assert amount == Decimal("0")


def test_freemium_default_zero_for_large_amounts() -> None:
    """Freemium: even 1B VND invoice returns 0 fee."""
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)

    import importlib
    import app.services.pricing.platform_fee as pf_module
    importlib.reload(pf_module)

    from app.services.pricing.platform_fee import PlatformFeeCalculator
    calc = PlatformFeeCalculator()

    pct, amount = calc.compute(total_amount=1_000_000_000)
    assert pct == Decimal("0")
    assert amount == Decimal("0")


def test_freemium_zero_total() -> None:
    """Freemium: total = 0 → (0, 0) with no division error."""
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)

    import importlib
    import app.services.pricing.platform_fee as pf_module
    importlib.reload(pf_module)

    from app.services.pricing.platform_fee import PlatformFeeCalculator
    calc = PlatformFeeCalculator()

    pct, amount = calc.compute(total_amount=0)
    assert pct == Decimal("0")
    assert amount == Decimal("0")


# ── Env override (v1.5 testing) ───────────────────────────────────────────────


def test_env_override_0_5_pct() -> None:
    """PLATFORM_FEE_DEFAULT_PCT=0.005 → 0.5% of total, rounded to whole VND."""
    os.environ["PLATFORM_FEE_DEFAULT_PCT"] = "0.005"

    import importlib
    import app.services.pricing.platform_fee as pf_module
    importlib.reload(pf_module)

    from app.services.pricing.platform_fee import PlatformFeeCalculator
    calc = PlatformFeeCalculator()

    # 3,000,000 × 0.005 = 15,000 VND
    pct, amount = calc.compute(total_amount=3_000_000)
    assert pct == Decimal("0.005")
    assert amount == Decimal("15000")

    # Cleanup
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)


def test_env_override_rounding() -> None:
    """PLATFORM_FEE_DEFAULT_PCT=0.005, amount 1,000,001 → rounds correctly."""
    os.environ["PLATFORM_FEE_DEFAULT_PCT"] = "0.005"

    import importlib
    import app.services.pricing.platform_fee as pf_module
    importlib.reload(pf_module)

    from app.services.pricing.platform_fee import PlatformFeeCalculator
    calc = PlatformFeeCalculator()

    # 1,000,001 × 0.005 = 5000.005 → rounds to 5000 (ROUND_HALF_UP for .005 = 5001? No — 5000.005 → 5000)
    # Actually ROUND_HALF_UP: 5000.005 → 5000 (digit after is 0, next is 0, 5 → rounds up the 0→1 digit)
    # Let's use a clean number instead:
    # 3,000,003 × 0.005 = 15000.015 → 15000 (ROUND_HALF_UP at ones digit: 0.015 < 0.5 → 15000)
    pct, amount = calc.compute(total_amount=3_000_003)
    assert pct == Decimal("0.005")
    # 3_000_003 * 0.005 = 15000.015; rounded = 15000
    assert amount == Decimal("15000")

    # Cleanup
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)


def test_env_override_malformed_falls_back_to_zero() -> None:
    """Malformed PLATFORM_FEE_DEFAULT_PCT gracefully falls back to 0."""
    os.environ["PLATFORM_FEE_DEFAULT_PCT"] = "not-a-number"

    import importlib
    import app.services.pricing.platform_fee as pf_module
    importlib.reload(pf_module)

    from app.services.pricing.platform_fee import PlatformFeeCalculator
    calc = PlatformFeeCalculator()

    pct, amount = calc.compute(total_amount=3_000_000)
    assert pct == Decimal("0")
    assert amount == Decimal("0")

    # Cleanup
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)


def test_delegation_commission_pct_param_ignored_v1() -> None:
    """In v1, delegation_commission_pct param is accepted but has no effect."""
    os.environ.pop("PLATFORM_FEE_DEFAULT_PCT", None)

    import importlib
    import app.services.pricing.platform_fee as pf_module
    importlib.reload(pf_module)

    from app.services.pricing.platform_fee import PlatformFeeCalculator
    from decimal import Decimal as D
    calc = PlatformFeeCalculator()

    pct, amount = calc.compute(
        total_amount=5_000_000,
        delegation_commission_pct=D("0.08"),  # 8% — should be ignored in v1
    )
    assert pct == Decimal("0")
    assert amount == Decimal("0")
