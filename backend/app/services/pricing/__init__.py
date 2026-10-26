"""Pricing services package — platform fee calculation for invoices.

v1 = FREE tier (platform_fee_pct = 0 by default).
v2 = commission-based pricing (requires NHNN intermediary license — see AC-35, O4).

IMPORTANT: v1 ships track-only. Commission auto-transfer is OUT OF SCOPE until v2 Q4 2026.
"""
from app.services.pricing.platform_fee import PlatformFeeCalculator

__all__ = ["PlatformFeeCalculator"]
