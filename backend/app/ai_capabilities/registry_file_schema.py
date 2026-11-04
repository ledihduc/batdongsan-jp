"""JSON Schema của file `registry.<market>.yaml` (v2). Loader kiểm file theo schema này trước mọi luật khác."""

from __future__ import annotations

# Pattern dùng \Z, không $: `$` cho lọt tên có "\n" cuối (block scalar YAML `|`).
# Mọi text hiển thị cho model/người dùng phải đủ ja, vi, en (D18); cho phép thêm ngôn ngữ khác.
LOCALIZED_TEXT: dict = {
    "type": "object",
    "required": ["ja", "vi", "en"],
    "propertyNames": {"pattern": "^[a-z]{2}\\Z"},
    "additionalProperties": {"type": "string", "minLength": 1, "maxLength": 2000},
}

HANDLER_PYTHON: dict = {
    "type": "object",
    "required": ["type", "target"],
    "additionalProperties": False,
    "properties": {
        "type": {"const": "python"},
        "target": {"type": "string", "pattern": "^[a-z_][a-z0-9_.]*:[a-z_][a-z0-9_]*\\Z"},
    },
}

_ACTION: dict = {
    "type": "object",
    "required": ["name", "title", "description", "params", "mode", "requires_login", "enabled", "handler"],
    "additionalProperties": False,
    "properties": {
        "name": {"type": "string", "pattern": "^[a-z][a-z0-9_]{0,63}\\Z"},
        "title": LOCALIZED_TEXT,
        "description": LOCALIZED_TEXT,
        "params": {"type": "object"},
        "mode": {"enum": ["read", "write"]},
        "requires_login": {"type": "boolean"},
        "enabled": {"type": "boolean"},
        "handler": {"oneOf": [HANDLER_PYTHON]},  # P06 thêm HANDLER_REST
    },
}

REGISTRY_FILE_SCHEMA: dict = {
    "type": "object",
    "required": ["version", "market", "default_lang", "guide", "actions"],
    "additionalProperties": False,
    "properties": {
        "version": {"const": 2},
        "market": {"enum": ["jp", "vn"]},
        "default_lang": {"enum": ["ja", "vi", "en"]},
        "guide": LOCALIZED_TEXT,
        "actions": {"type": "array", "minItems": 1, "items": _ACTION},
    },
}
