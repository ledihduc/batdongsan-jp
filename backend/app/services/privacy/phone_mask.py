"""Phone number masking service — extracted from construction/serializers.py.

Single responsibility: mask phone numbers with locale-aware rules.
No PII in logs — this module never logs the raw phone number.

Extraction note:
  Original implementation lives in app/services/construction/serializers.py
  (function `mask_phone`). That function is kept as a thin wrapper importing
  from here for backward compatibility. Remove the wrapper after all callers
  are confirmed migrated (grep for `from app.services.construction.serializers import mask_phone`).

Signature: mask(phone: str, region: str) -> str

Region-specific behavior:
  - 'vn': mask all but last 3 digits (existing behavior, matching PDPL).
    Example: '0912345678' → '•••••••678'
  - 'jp': mask all but last 4 digits (common JP privacy convention).
    Example: '09012345678' → '•••••••5678'
  - unknown region: falls back to VN masking (safe default).
"""

from __future__ import annotations

import re


def mask(phone: str, region: str = "vn") -> str:
    """Mask a phone number according to regional privacy rules.

    Strips all non-digit characters before masking, so hyphens and spaces
    in the input are handled transparently.

    Args:
        phone: Raw phone string (may contain +, -, spaces, etc.).
        region: Region code ('vn' or 'jp'). Case-insensitive. Defaults to 'vn'.

    Returns:
        Masked string with bullet characters replacing hidden digits.
        Returns empty string if phone has no digits.

    Examples:
        >>> mask('0912345678', 'vn')
        '•••••••678'
        >>> mask('09012345678', 'jp')
        '•••••••5678'
        >>> mask('', 'vn')
        ''
    """
    digits = re.sub(r"\D", "", phone or "")
    if not digits:
        return ""

    # Determine how many trailing digits to reveal.
    region_lower = (region or "vn").lower()
    if region_lower == "jp":
        visible_count = 4
    else:
        # VN default (PDPL) — and safe fallback for unknown regions.
        visible_count = 3

    hidden_count = max(0, len(digits) - visible_count)
    return "•" * hidden_count + digits[-visible_count:]
