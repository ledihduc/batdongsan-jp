"""Pydantic v2 schemas for CreditNote responses."""

from datetime import datetime

from pydantic import BaseModel


class CreditNoteResponse(BaseModel):
    id: int
    host_id: int
    original_invoice_id: int
    amount: float
    reason: str
    issued_date: str
    created_at: datetime

    model_config = {"from_attributes": True}
