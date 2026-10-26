from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field


class SupportCreate(BaseModel):
    category: Literal["REPAIR", "UTILITY", "BILLING", "CONTRACT", "SAFETY", "OTHER"]
    priority: Literal["LOW", "NORMAL", "HIGH", "URGENT"] = "NORMAL"
    title: str = Field(min_length=3, max_length=200)
    description: str = Field(min_length=1, max_length=5000)
    evidence_urls: list[str] = Field(default_factory=list, max_length=10)


class SupportUpdate(BaseModel):
    status: Optional[Literal["OPEN", "IN_PROGRESS", "WAITING_CUSTOMER", "RESOLVED", "CLOSED"]] = None
    assignee_user_id: Optional[int] = None
    note: str = Field(default="", max_length=3000)
    evidence_urls: list[str] = Field(default_factory=list, max_length=10)


class ChangeRequestCreate(BaseModel):
    request_type: Literal["RENEWAL", "MOVE_OUT"]
    proposed_end_date: Optional[str] = Field(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$")
    note: str = Field(default="", max_length=3000)


class ChangeRequestReview(BaseModel):
    decision: Literal["APPROVED", "REJECTED"]
    review_note: str = Field(default="", max_length=3000)
