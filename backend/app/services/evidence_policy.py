"""Shared validation for user supplied evidence references.

Only references produced by the internal upload API or HTTPS object storage are
accepted.  This prevents javascript/file schemes and oversized payloads from
being persisted in workflow/audit JSON.
"""
from urllib.parse import urlparse

from fastapi import HTTPException

MAX_EVIDENCE_ITEMS = 10
MAX_URL_LENGTH = 500


def validate_url(value: object) -> str:
    text = str(value or "").strip()
    if not text or len(text) > MAX_URL_LENGTH:
        raise HTTPException(422, "Đường dẫn chứng từ không hợp lệ")
    parsed = urlparse(text)
    if parsed.scheme:
        if parsed.scheme != "https" or not parsed.netloc:
            raise HTTPException(422, "Chứng từ ngoài hệ thống phải dùng HTTPS")
    elif not text.startswith("/uploads/"):
        raise HTTPException(422, "Chứng từ nội bộ phải nằm trong /uploads/")
    return text


def validate_urls(values: object) -> list[str]:
    if values is None:
        return []
    if not isinstance(values, list) or len(values) > MAX_EVIDENCE_ITEMS:
        raise HTTPException(422, f"Tối đa {MAX_EVIDENCE_ITEMS} chứng từ")
    return [validate_url(value) for value in values]
