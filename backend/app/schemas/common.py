"""Shared response envelopes and base schemas. Pydantic v2 syntax."""

from typing import Any, Optional
from pydantic import BaseModel


class SuccessResponse(BaseModel):
    success: bool = True


class ErrorDetail(BaseModel):
    code: str
    message: str


class PaginatedMeta(BaseModel):
    total: int
    limit: int
    offset: int
