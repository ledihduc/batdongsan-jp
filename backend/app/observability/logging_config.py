"""
Cấu hình logging có cấu trúc (JSON lines) cho backend.

- Ghi ra `storage/logs/app.jsonl` (rotating) + stdout.
- Mỗi bản ghi là 1 dòng JSON: ts, level, logger, msg, request_id, và mọi
  `extra=` field (method, path, status, latency_ms, user_hash, error_code,
  fingerprint, exc_type…).
- RedactionFilter chạy TRƯỚC formatter → PII/secret không bao giờ chạm đĩa.

Không thêm dependency mới: dùng logging chuẩn + json.
"""

from __future__ import annotations

import json
import logging
import logging.config
import os
import time
from typing import Any

from app.observability.context import request_id_var, route_var, user_hash_var
from app.observability.redaction import redact_obj, redact_text

# Thuộc tính chuẩn của LogRecord — mọi key khác coi là "extra" do caller thêm.
_STD_ATTRS = frozenset(
    logging.makeLogRecord({}).__dict__.keys()
) | {"message", "asctime", "taskName"}


class RedactionFilter(logging.Filter):
    """Redact message + args + mọi extra field trước khi format."""

    def filter(self, record: logging.LogRecord) -> bool:
        try:
            if isinstance(record.msg, str):
                record.msg = redact_text(record.msg)
            if record.args:
                if isinstance(record.args, dict):
                    record.args = redact_obj(record.args)
                else:
                    record.args = tuple(redact_obj(a) for a in record.args)
            for key, val in list(record.__dict__.items()):
                if key in _STD_ATTRS:
                    continue
                record.__dict__[key] = redact_obj(val)
        except Exception:  # noqa: BLE001 — không để logging chết
            pass
        return True


class JsonFormatter(logging.Formatter):
    """Định dạng mỗi record thành 1 dòng JSON."""

    def format(self, record: logging.LogRecord) -> str:
        base: dict[str, Any] = {
            "ts": time.strftime(
                "%Y-%m-%dT%H:%M:%S", time.gmtime(record.created)
            )
            + f".{int(record.msecs):03d}Z",
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        # Contextvars (nếu middleware đã set).
        rid = request_id_var.get()
        if rid:
            base["request_id"] = rid
        uh = user_hash_var.get()
        if uh:
            base["user_hash"] = uh
        rt = route_var.get()
        if rt and "route" not in record.__dict__:
            base["route"] = rt

        # Extra fields do caller truyền qua logger.x(..., extra={...}).
        for key, val in record.__dict__.items():
            if key in _STD_ATTRS or key in base:
                continue
            base[key] = val

        if record.exc_info:
            base["exc_type"] = getattr(record.exc_info[0], "__name__", "Exception")
            # traceback đã được caller redact + đưa vào extra khi cần; ở đây
            # chỉ ghi dạng text đã redact để không lộ path tuyệt đối chứa PII.
            base.setdefault("traceback", redact_text(self.formatException(record.exc_info)))

        try:
            return json.dumps(base, ensure_ascii=False, default=str)
        except Exception:  # noqa: BLE001
            return json.dumps(
                {"ts": base["ts"], "level": "ERROR", "logger": "logging",
                 "msg": "log-serialize-failed"}
            )


def setup_logging() -> None:
    """Khởi tạo logging — gọi 1 lần khi app start (đầu main.py)."""
    from app.config import settings

    log_dir = getattr(settings, "log_dir", "./storage/logs")
    log_level = getattr(settings, "log_level", "INFO").upper()
    os.makedirs(log_dir, exist_ok=True)
    log_file = os.path.join(log_dir, "app.jsonl")

    config = {
        "version": 1,
        "disable_existing_loggers": False,
        "filters": {"redact": {"()": RedactionFilter}},
        "formatters": {"json": {"()": JsonFormatter}},
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "formatter": "json",
                "filters": ["redact"],
                "level": log_level,
            },
            "file": {
                "class": "logging.handlers.RotatingFileHandler",
                "filename": log_file,
                "maxBytes": 25 * 1024 * 1024,  # 25MB
                "backupCount": 10,
                "encoding": "utf-8",
                "formatter": "json",
                "filters": ["redact"],
                "level": log_level,
            },
        },
        "root": {"level": log_level, "handlers": ["console", "file"]},
        # uvicorn.access rất ồn và chứa query string thô → tắt, ta tự log qua middleware.
        "loggers": {
            "uvicorn.access": {"level": "WARNING", "handlers": ["console", "file"], "propagate": False},
            "uvicorn.error": {"level": "INFO", "handlers": ["console", "file"], "propagate": False},
        },
    }
    logging.config.dictConfig(config)
    logging.getLogger("app.observability").info(
        "logging initialized", extra={"log_file": log_file, "log_level": log_level}
    )
