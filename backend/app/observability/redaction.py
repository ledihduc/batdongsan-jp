"""
Redaction PII/secret — CHỐT AN TOÀN cho toàn bộ pipeline observability.

Mọi log đi qua đây trước khi ghi ra đĩa, vì log sẽ được:
  1. gom lại bởi collect_errors.py, và
  2. gửi cho Claude phân tích (headless).
Nếu không redact, dữ liệu thật (email, SĐT, CCCD, số tài khoản, JWT, secret)
sẽ rò rỉ ra model → vi phạm nguyên tắc "không đụng dữ liệu thật".

Nguyên tắc: thà over-redact còn hơn để lọt. Các hàm ở đây phải KHÔNG raise
(logging path không được phép chết vì lỗi redact).
"""

from __future__ import annotations

import re
from typing import Any

_PLACEHOLDER = "«redacted»"

# Khoá (key) mà nếu xuất hiện trong dict/log → giá trị bị thay hoàn toàn.
_SENSITIVE_KEYS = frozenset(
    {
        "password",
        "passwd",
        "pwd",
        "secret",
        "token",
        "access_token",
        "refresh_token",
        "authorization",
        "auth",
        "jwt",
        "api_key",
        "apikey",
        "api_secret",
        "cookie",
        # Lưu dạng normalized (dấu "-" → "_") vì _is_sensitive_key chuẩn hoá key
        # đầu vào trước khi tra; entry "set-cookie" cũ không bao giờ khớp.
        "set_cookie",
        "otp",
        "cccd",
        "cmnd",
        "national_id",
        "id_number",
        "bank_account",
        "account_number",
        "card_number",
        "cvv",
        "pin",
        "ssn",
        "jwt_secret",
        "esms_secret_key",
        "fastca_api_secret",
        # Token bot Telegram báo yêu cầu dịch vụ cho admin: lộ ra là người lạ
        # nhắn được vào đúng luồng admin đang tin tưởng.
        "telegram_bot_token",
        "telegram_admin_chat_id",
        "vinaca_api_secret",
    }
)

# ── Pattern-based redaction (áp lên free text) ────────────────────────────────
_EMAIL_RE = re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}")
# JWT: 3 đoạn base64url ngăn bởi dấu chấm.
_JWT_RE = re.compile(r"\beyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+")
# Bearer token trong header.
_BEARER_RE = re.compile(r"(?i)bearer\s+[A-Za-z0-9._\-]+")
# Chuỗi số dài 9-19 chữ số (CCCD 12, số tài khoản, thẻ) — có ranh giới.
_LONGNUM_RE = re.compile(r"(?<!\d)\d{9,19}(?!\d)")
# SĐT VN: +84 hoặc 0, theo sau 9-10 chữ số (có thể có khoảng trắng/gạch).
_PHONE_RE = re.compile(r"(?<!\w)(?:\+?84|0)(?:[\s\-.]?\d){8,10}(?!\w)")

_TEXT_PATTERNS = (_EMAIL_RE, _JWT_RE, _BEARER_RE, _PHONE_RE, _LONGNUM_RE)

_MAX_DEPTH = 8


def redact_text(value: str) -> str:
    """Redact PII/secret trong một chuỗi tự do."""
    try:
        out = value
        for pat in _TEXT_PATTERNS:
            out = pat.sub(_PLACEHOLDER, out)
        return out
    except Exception:  # noqa: BLE001 — logging path không được chết
        return _PLACEHOLDER


def _is_sensitive_key(key: str) -> bool:
    k = key.strip().lower().replace("-", "_")
    return k in _SENSITIVE_KEYS


def redact_obj(obj: Any, _depth: int = 0) -> Any:
    """
    Redact đệ quy trên cấu trúc JSON-like (dict/list/scalar).
    - Key nhạy cảm → giá trị bị thay hoàn toàn.
    - String → chạy pattern redaction.
    """
    try:
        if _depth > _MAX_DEPTH:
            return _PLACEHOLDER
        if isinstance(obj, str):
            return redact_text(obj)
        if isinstance(obj, dict):
            out: dict[Any, Any] = {}
            for k, v in obj.items():
                if isinstance(k, str) and _is_sensitive_key(k):
                    out[k] = _PLACEHOLDER
                else:
                    out[k] = redact_obj(v, _depth + 1)
            return out
        if isinstance(obj, (list, tuple)):
            return [redact_obj(v, _depth + 1) for v in obj]
        return obj
    except Exception:  # noqa: BLE001
        return _PLACEHOLDER
