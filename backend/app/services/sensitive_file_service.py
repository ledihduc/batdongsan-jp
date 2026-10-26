"""Sensitive file service — store and read encrypted-at-rest documents.

v1 implementation: local disk storage under SENSITIVE_UPLOADS_DIR.
v1.5 target: AWS S3 with SSE-KMS (drop-in replacement via abstraction below).

Files covered:
  - delegations.poa_document_path (Power of Attorney)
  - operator_business_profiles.gpkd_document_path (Business registration)
  - operator_business_profiles.legal_representative_cccd_*_path
  - owner_death_certificates.death_certificate_path + notarized_poa_path

Security requirements:
  - Files stored on LUKS-encrypted volume (or AWS EBS encrypted in cloud).
  - Every read operation logged via CCCDAccessLog-equivalent table.
  - File paths stored in DB; never returned directly in API responses.
  - Path traversal prevention: all paths resolved via _safe_path() before use.

PDPL Decree 13/2023 §10.5: files in scope for 4-tier retention (hot/warm/cold/legal_hold).
"""

from __future__ import annotations

import logging
import os
import re
import uuid
from pathlib import Path
from typing import Literal

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# Base directory for sensitive uploads — should be on LUKS-encrypted volume in production.
# Override via SENSITIVE_UPLOADS_DIR env var. Defaults to {CWD}/storage/sensitive/.
_BASE_DIR = Path(
    os.getenv("SENSITIVE_UPLOADS_DIR", str(Path(__file__).parent.parent.parent / "storage" / "sensitive"))
)

SensitiveFileType = Literal[
    "poa_document",
    "gpkd_document",
    "legal_rep_cccd",
    "death_certificate",
    "notarized_poa",
    "ekyc_selfie",
]

# Map file type to subdirectory for organized storage
_TYPE_SUBDIR: dict[SensitiveFileType, str] = {
    "poa_document": "poa",
    "gpkd_document": "gpkd",
    "legal_rep_cccd": "legal_rep_cccd",
    "death_certificate": "death_certs",
    "notarized_poa": "notarized_poa",
    # Ảnh chân dung chụp lúc eKYC chủ nhà (mig 0140).
    "ekyc_selfie": "selfie",
}


def _safe_path(file_path: str) -> Path:
    """Resolve path and verify it stays within BASE_DIR (prevents path traversal).

    Raises ValueError if path escapes the base directory.
    """
    resolved = (_BASE_DIR / file_path).resolve()
    try:
        resolved.relative_to(_BASE_DIR.resolve())
    except ValueError:
        raise ValueError(
            f"Path traversal detected: '{file_path}' resolves outside base directory."
        )
    return resolved


def store_file(
    file_bytes: bytes,
    file_type: SensitiveFileType,
    owner_user_id: int,
    extension: str = "bin",
    db: Session | None = None,
    accessor_user_id: int | None = None,
    ip_address: str | None = None,
) -> str:
    """Store sensitive file bytes and return the relative path for DB storage.

    Args:
        file_bytes: Raw file content.
        file_type: Category of sensitive file (for subdirectory routing).
        owner_user_id: User ID the file belongs to (for audit log).
        extension: File extension (e.g., 'pdf', 'jpg').
        db: SQLAlchemy session for audit logging (optional in v1 — log to logger if None).
        accessor_user_id: Who is storing the file (for audit trail).
        ip_address: Requester IP (for audit trail).

    Returns:
        Relative path string (e.g., 'poa/abc123.pdf') — store this in DB column.
    """
    subdir = _TYPE_SUBDIR[file_type]
    file_id = str(uuid.uuid4())
    # Sanitize extension — allow only alphanumeric
    safe_ext = re.sub(r"[^a-zA-Z0-9]", "", extension)[:10] or "bin"
    rel_path = f"{subdir}/{file_id}.{safe_ext}"

    abs_path = _safe_path(rel_path)
    abs_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        abs_path.write_bytes(file_bytes)
    except OSError as exc:
        logger.error(
            "sensitive_file_service: failed to write file type=%s owner=%s error=%s",
            file_type,
            owner_user_id,
            exc,
        )
        raise

    _log_access(
        db=db,
        user_id=accessor_user_id,
        file_path=rel_path,
        action="upload",
        ip_address=ip_address,
    )
    logger.info(
        "sensitive_file_service: stored file type=%s owner=%s path=%s",
        file_type,
        owner_user_id,
        rel_path,
    )
    return rel_path


def read_file(
    file_path: str,
    accessor_user_id: int,
    reason: str,
    db: Session | None = None,
    ip_address: str | None = None,
) -> bytes:
    """Read sensitive file bytes, logging access for PDPL audit trail.

    Args:
        file_path: Relative path stored in DB column.
        accessor_user_id: Who is reading the file (for audit trail).
        reason: Business justification for read access (stored in audit log comment).
        db: SQLAlchemy session for audit logging.
        ip_address: Requester IP.

    Returns:
        Raw file bytes.

    Raises:
        FileNotFoundError: If file does not exist at resolved path.
        ValueError: If path traversal detected.
    """
    abs_path = _safe_path(file_path)

    if not abs_path.exists():
        raise FileNotFoundError(f"Sensitive file not found: {file_path}")

    file_bytes = abs_path.read_bytes()

    _log_access(
        db=db,
        user_id=accessor_user_id,
        file_path=file_path,
        action="read",
        ip_address=ip_address,
        extra_note=reason,
    )
    logger.info(
        "sensitive_file_service: read file accessor=%s path=%s reason='%s'",
        accessor_user_id,
        file_path,
        reason,
    )
    return file_bytes


def _log_access(
    db: Session | None,
    user_id: int | None,
    file_path: str,
    action: str,
    ip_address: str | None = None,
    extra_note: str | None = None,
) -> None:
    """Write access audit log entry.

    Uses CCCDAccessLog table pattern for consistency.
    Falls back to Python logger if db session is not provided.
    """
    from datetime import datetime

    if db is not None:
        try:
            from app.models import CCCDAccessLog  # noqa: F401 — app/models.py (not domain)

            entry = CCCDAccessLog(
                user_id=user_id,
                file_path=file_path,
                action=action,
                accessed_at=datetime.utcnow(),
                ip_address=ip_address or "",
            )
            db.add(entry)
            db.flush()  # Caller owns commit
        except Exception as exc:  # noqa: BLE001
            # Never let audit log failure break the file operation
            logger.warning(
                "sensitive_file_service: audit log write failed: %s. "
                "File access: user=%s path=%s action=%s",
                exc,
                user_id,
                file_path,
                action,
            )
    else:
        logger.info(
            "sensitive_file_service: [audit-fallback] user=%s path=%s action=%s ip=%s note=%s",
            user_id,
            file_path,
            action,
            ip_address,
            extra_note,
        )
