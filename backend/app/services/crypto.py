"""Symmetric encryption helpers for sensitive provider configs stored in DB.

Encryption choice: cryptography.fernet (AES-128-CBC + HMAC-SHA256).
Key derivation: Fernet requires a 32-byte base64url key derived from
settings.secret_key via PBKDF2-HMAC-SHA256 (100k iterations).

Why Fernet over raw AES:
  - Built-in MAC prevents tampering (authenticated encryption).
  - Timestamp embedded → easy future key rotation (decrypt old → encrypt new).
  - Single import from the 'cryptography' package already in requirements.

Usage:
  >>> from app.services.crypto import encrypt_config, decrypt_config
  >>> ciphertext = encrypt_config({"api_key": "sk-xxx"})
  >>> plaintext  = decrypt_config(ciphertext)
  >>> plaintext["api_key"]
  'sk-xxx'

Key rotation: bump CRYPTO_SALT env var and re-encrypt all OrgProviderConfig rows.
"""

from __future__ import annotations

import base64
import hashlib
import json
import logging
from typing import Any

from cryptography.fernet import Fernet, InvalidToken

from app.config import settings

logger = logging.getLogger(__name__)

# Derivation constants — change CRYPTO_SALT to trigger key rotation
_CRYPTO_SALT = b"ancu365-provider-config-v1"
_PBKDF2_ITERATIONS = 100_000


def _derive_fernet_key() -> bytes:
    """Derive a 32-byte Fernet key from settings.secret_key.

    Uses PBKDF2-HMAC-SHA256 so the raw secret never hits the DB layer.
    Result is cached in module scope after first call.
    """
    raw = settings.jwt_secret.encode("utf-8")
    key_bytes = hashlib.pbkdf2_hmac(
        "sha256", raw, _CRYPTO_SALT, _PBKDF2_ITERATIONS, dklen=32
    )
    return base64.urlsafe_b64encode(key_bytes)


# Module-level singleton — derived once per process
_FERNET: Fernet | None = None


def _get_fernet() -> Fernet:
    global _FERNET  # noqa: PLW0603 — intentional module singleton
    if _FERNET is None:
        _FERNET = Fernet(_derive_fernet_key())
    return _FERNET


def encrypt_config(plaintext: dict[str, Any]) -> dict[str, str]:
    """Encrypt a provider config dict to a storable JSON-safe dict.

    Returns:
        {"ciphertext": "<base64url Fernet token>"}
    Raise:
        ValueError: if plaintext is not serialisable.
    """
    try:
        raw_json = json.dumps(plaintext, ensure_ascii=False).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise ValueError(f"Provider config is not JSON-serialisable: {exc}") from exc

    token = _get_fernet().encrypt(raw_json)
    return {"ciphertext": token.decode("ascii")}


def decrypt_config(stored: dict[str, str]) -> dict[str, Any]:
    """Decrypt a stored provider config dict back to plaintext.

    Args:
        stored: dict with key "ciphertext" as returned by encrypt_config().

    Returns:
        Original plaintext dict.

    Raises:
        ValueError: if decryption fails (bad key, tampered data, wrong format).
    """
    ciphertext = stored.get("ciphertext")
    if not ciphertext:
        raise ValueError("stored config missing 'ciphertext' key")

    try:
        raw_json = _get_fernet().decrypt(ciphertext.encode("ascii"))
    except InvalidToken as exc:
        logger.error("Provider config decryption failed — possible key mismatch or tampering")
        raise ValueError("Provider config decryption failed") from exc

    result: dict[str, Any] = json.loads(raw_json.decode("utf-8"))
    return result
