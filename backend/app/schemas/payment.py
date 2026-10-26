"""Pydantic v2 schemas for Payment responses (creation goes via Invoice.pay endpoint)."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class PaymentResponse(BaseModel):
    id: int
    host_id: int
    invoice_id: int
    amount: float
    method: str
    paid_at: datetime
    note: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
