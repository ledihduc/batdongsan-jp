"""Pydantic v2 schemas cho revenue source endpoints.

Phase 02 concern #1: archived sources có name suffix '__archived_{id}'.
SourceResponse dùng @model_validator để strip suffix thành display_name.
"""

from __future__ import annotations

import re
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

_ARCHIVED_SUFFIX_RE = re.compile(r"__archived_\d+$")


class SourceCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)
    color_hex: str = Field(..., pattern=r"^#[0-9A-Fa-f]{6}$")


class SourceUpdate(BaseModel):
    """PATCH semantics — tất cả fields Optional."""

    name: Optional[str] = Field(None, min_length=1, max_length=50)
    color_hex: Optional[str] = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")


class SourceResponse(BaseModel):
    """Response model cho một revenue source.

    display_name là giá trị hiển thị cho UI — suffix '__archived_{id}' đã được strip
    khi source đang ở trạng thái archived (Phase 02 concern #1).
    """

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str          # raw DB value (có thể chứa __archived_{id} suffix)
    display_name: str = ""   # stripped — UI sử dụng field này
    color_hex: str
    is_archived: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    @model_validator(mode="after")
    def _compute_display_name(self) -> "SourceResponse":
        """Strip __archived_{id} suffix từ name để lấy display_name."""
        self.display_name = _ARCHIVED_SUFFIX_RE.sub("", self.name)
        return self


class SourceListResponse(BaseModel):
    items: list[SourceResponse]
