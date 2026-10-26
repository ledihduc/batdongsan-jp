"""Import + kiểu dùng chung cho package app/models — JSONList, now_utc, Base + sqlalchemy."""

import json
from datetime import date, datetime
from typing import Optional

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    JSON,
    Numeric,
    String,
    Text,
    Index,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import TypeDecorator

from app.database import Base


class JSONList(TypeDecorator):
    """Lưu list[str] dưới dạng TEXT JSON, đọc ra list. Cross-DB."""

    impl = Text
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is None:
            return "[]"
        return json.dumps(value, ensure_ascii=False)

    def process_result_value(self, value, dialect):
        if not value:
            return []
        try:
            return json.loads(value)
        except Exception:
            return []


def now_utc() -> datetime:
    return datetime.utcnow()


