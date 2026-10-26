"""PlatformFeeCalculator — NFR-15 forward-compat platform fee computation.

v1 FREEMIUM: platform_fee_pct defaults to 0.0 (FREE tier).

Design intent:
  - v1   (2026 Q1-Q3): always 0, no charge to owners.
  - v1.5 (Freemium):    reads PLATFORM_FEE_DEFAULT_PCT env var (non-zero, e.g. 0.005 = 0.5%).
  - v2   (2026 Q4):     per-delegation negotiated rate stored on Delegation model.
                         NHNN intermediary license required before auto-transfer (O4).

IMPORTANT: Auto-transfer is explicitly OUT OF SCOPE for v1 + v1.5.
  Commission tracking (this module) only computes amounts for reporting.
  No bank API is called here or anywhere in this service chain (AC-35).
"""

from __future__ import annotations

import os
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional


# ── Environment-driven config (v1 → v1.5 migration path) ────────────────────
# v1 default = 0.  Override with PLATFORM_FEE_DEFAULT_PCT=0.005 for 0.5% in v1.5.
_DEFAULT_PCT_STR = os.getenv("PLATFORM_FEE_DEFAULT_PCT", "0")

try:
    PLATFORM_FEE_DEFAULT_PCT: Decimal = Decimal(_DEFAULT_PCT_STR)
    if PLATFORM_FEE_DEFAULT_PCT < 0 or PLATFORM_FEE_DEFAULT_PCT > 1:
        raise ValueError("PLATFORM_FEE_DEFAULT_PCT must be in [0, 1]")
except Exception:
    # Fail-safe: revert to 0 if env var is malformed (never fail app startup)
    PLATFORM_FEE_DEFAULT_PCT = Decimal("0")


class PlatformFeeCalculator:
    """Compute platform fee snapshot values for an invoice at generation time.

    Usage:
        calc = PlatformFeeCalculator()
        pct, amount = calc.compute(total_amount=3_000_000)

    Returns (pct, amount) both as Decimal (whole VND for amount).
    pct is in [0, 1] — e.g., Decimal('0.005') = 0.5%.

    Thread-safe: stateless (all state comes from env + optional delegation arg).
    """

    def compute(
        self,
        total_amount: float | Decimal,
        *,
        delegation_commission_pct: Optional[Decimal] = None,
    ) -> tuple[Decimal, Decimal]:
        """Return (platform_fee_pct, platform_fee_amount) as Decimal.

        Args:
            total_amount: Invoice total in VND.
            delegation_commission_pct: For v2 forward-compat — reads delegation rate
                if platform-level fee is keyed to operator tier. Ignored in v1.

        Returns:
            (pct, amount): pct in [0,1] decimal fraction; amount in whole VND.

        Note:
            In v1, always returns (0, 0). The delegation_commission_pct param is
            accepted but unused — reserved for v2 per-delegation platform fee tiers.
        """
        total = Decimal(str(total_amount))
        # v1: PLATFORM_FEE_DEFAULT_PCT is 0; env override enables v1.5 testing.
        pct: Decimal = PLATFORM_FEE_DEFAULT_PCT

        if pct == Decimal("0"):
            return Decimal("0"), Decimal("0")

        # v1.5+: compute whole-VND amount (round half-up per VN convention)
        raw_amount = total * pct
        amount = raw_amount.quantize(Decimal("1"), rounding=ROUND_HALF_UP)
        return pct, amount
