"""CCCD (national ID card) secure storage service.

Security design (D7 sealed):
- Files stored in storage/cccd/ with directory chmod 0700
- Filenames are UUIDv4 (no PII in path)
- CCCD number stored as one-way bcrypt hash (compare-only, never plaintext)
- All file reads/writes logged to cccd_access_logs with actor_id, ip, timestamp
- No direct file URL exposed — only via authenticated /api/host/cccd/{id}
"""

from __future__ import annotations

import os
import stat
import uuid
from datetime import datetime
from typing import Optional

import bcrypt
from fastapi import UploadFile
from sqlalchemy.orm import Session

from app import models

# Storage root — relative to backend project root
_CCCD_DIR = os.path.realpath(
    os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "storage", "cccd")
)

# Max file size: 10 MB
_MAX_SIZE_BYTES = 10 * 1024 * 1024

# Allowed MIME types
_ALLOWED_MIME = {"image/jpeg", "image/png", "image/webp"}

# Magic-byte signatures for content sniffing (defense against MIME spoofing).
# Key = MIME, value = list of acceptable starting byte sequences.
_MAGIC_BYTES: dict[str, list[bytes]] = {
    "image/jpeg": [b"\xff\xd8\xff"],
    "image/png": [b"\x89PNG\r\n\x1a\n"],
    "image/webp": [b"RIFF"],  # followed by 4-byte size then b"WEBP" at offset 8
}


def _detect_mime_by_magic(content: bytes) -> str | None:
    """Return the detected MIME type by inspecting magic bytes, or None."""
    for mime, signatures in _MAGIC_BYTES.items():
        for sig in signatures:
            if content.startswith(sig):
                if mime == "image/webp":
                    # WebP: RIFF????WEBP — must verify the "WEBP" marker at offset 8
                    if len(content) >= 12 and content[8:12] == b"WEBP":
                        return mime
                else:
                    return mime
    return None


def _is_path_inside_cccd_dir(path: str) -> bool:
    """Verify a path resolves to a file inside _CCCD_DIR (no path traversal)."""
    try:
        resolved = os.path.realpath(path)
        return resolved.startswith(_CCCD_DIR + os.sep) or resolved == _CCCD_DIR
    except (OSError, ValueError):
        return False


def _ensure_cccd_dir() -> str:
    """Create storage/cccd/ with chmod 0700 if missing. Return path."""
    os.makedirs(_CCCD_DIR, exist_ok=True)
    # 0700 = owner rwx only — group and others get no access
    os.chmod(_CCCD_DIR, stat.S_IRWXU)
    return _CCCD_DIR


def hash_cccd_number(plain: str) -> str:
    """One-way bcrypt hash of raw CCCD number. Cannot be reversed."""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt(12)).decode("utf-8")


def verify_cccd_number(plain: str, hashed: str) -> bool:
    """Compare raw CCCD number against stored hash."""
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False


async def save_cccd(
    upload: UploadFile,
    host_id: int,
    db: Session,
    ip_address: Optional[str] = None,
) -> str:
    """Save a CCCD image upload. Returns stored file path.

    Args:
        upload: FastAPI UploadFile from multipart form
        host_id: user.id of the host (used for audit log actor)
        db: SQLAlchemy session (for CCCDAccessLog write)
        ip_address: client IP for audit log

    Raises:
        ValueError: if file is too large or wrong MIME type
    """
    # Validate client-declared content type (first line of defense)
    declared_type = upload.content_type or ""
    if declared_type not in _ALLOWED_MIME:
        raise ValueError(f"Loại file không được phép: {declared_type}. Chỉ chấp nhận JPEG/PNG/WebP.")

    # Read content
    content = await upload.read()
    if len(content) > _MAX_SIZE_BYTES:
        raise ValueError("File quá lớn. Tối đa 10 MB.")

    # Verify magic bytes match — defends against MIME spoofing (declared JPEG but actually .exe)
    detected_type = _detect_mime_by_magic(content)
    if detected_type is None:
        raise ValueError("Nội dung file không hợp lệ. Chỉ chấp nhận ảnh JPEG/PNG/WebP.")
    if detected_type != declared_type:
        raise ValueError(
            f"Nội dung file không khớp định dạng khai báo ({declared_type} vs {detected_type})."
        )

    # Generate UUIDv4 filename — no PII in path. Use detected MIME, not the declared one.
    ext = _ext_from_mime(detected_type)
    filename = f"{uuid.uuid4()}{ext}"
    dir_path = _ensure_cccd_dir()
    file_path = os.path.join(dir_path, filename)

    # Write with restrictive permissions: 0600 (owner read/write only)
    with open(file_path, "wb") as f:
        f.write(content)
    os.chmod(file_path, stat.S_IRUSR | stat.S_IWUSR)

    # Audit log + commit immediately: the file is now on disk, the audit trace
    # MUST persist independently of whether the subsequent profile-path update
    # succeeds (PDPL: every upload logged).
    _log_access(db, host_id, file_path, "upload", ip_address)
    db.commit()

    return file_path


def read_cccd(
    file_path: str,
    actor_id: int,
    db: Session,
    ip_address: Optional[str] = None,
) -> bytes:
    """Read a CCCD file and write an access log entry before returning bytes.

    Args:
        file_path: Absolute path returned by save_cccd
        actor_id: user.id of requester (for audit log)
        db: SQLAlchemy session
        ip_address: client IP for audit log

    Raises:
        FileNotFoundError: if the file does not exist on disk
        PermissionError: if the path escapes the CCCD storage directory (traversal)
    """
    # Defense in depth: reject any path that doesn't resolve inside _CCCD_DIR,
    # even if the DB-supplied path was somehow corrupted (insider tampering).
    if not _is_path_inside_cccd_dir(file_path):
        raise PermissionError(f"CCCD path outside allowed storage: {file_path}")

    if not os.path.isfile(file_path):
        raise FileNotFoundError(f"CCCD file not found: {file_path}")

    # Audit log BEFORE reading and COMMIT — so even a server crash mid-read
    # leaves a durable PDPL trace (AC6: every read logged).
    _log_access(db, actor_id, file_path, "read", ip_address)
    db.commit()

    with open(file_path, "rb") as f:
        return f.read()


def delete_cccd(
    file_path: str,
    actor_id: int,
    db: Session,
    ip_address: Optional[str] = None,
) -> None:
    """Delete a CCCD file and write an audit log entry.

    Raises:
        PermissionError: if the path escapes the CCCD storage directory.
    """
    if not _is_path_inside_cccd_dir(file_path):
        raise PermissionError(f"CCCD path outside allowed storage: {file_path}")
    _log_access(db, actor_id, file_path, "delete", ip_address)
    db.commit()
    if os.path.isfile(file_path):
        os.remove(file_path)


def _log_access(
    db: Session,
    actor_id: int,
    file_path: str,
    action: str,
    ip_address: Optional[str],
) -> None:
    """Write CCCDAccessLog row. Committed immediately for PDPL compliance."""
    log = models.CCCDAccessLog(
        user_id=actor_id,
        file_path=file_path,
        action=action,
        accessed_at=datetime.utcnow(),
        ip_address=ip_address,
    )
    db.add(log)
    # Flush so the audit row is persisted even if outer transaction rolls back
    # (caller is responsible for committing)
    db.flush()


def _ext_from_mime(content_type: str) -> str:
    """Map MIME type to file extension."""
    mapping = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
    }
    return mapping.get(content_type, ".bin")
