from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.services import rental_journey_policy as policy


class ViewingResultIn(BaseModel):
    outcome: Literal["INTERESTED", "NOT_INTERESTED"]
    reason: str | None = Field(default=None, max_length=500)


class ContractIn(BaseModel):
    urls: list[str]
    total_deposit: int = Field(gt=0, le=100_000_000_000)
    note: str | None = Field(default=None, max_length=1000)

    @field_validator("urls")
    @classmethod
    def validate_urls(cls, value: list[str]) -> list[str]:
        return policy.validate_evidence_paths(value)


class PaymentProofIn(BaseModel):
    urls: list[str]

    @field_validator("urls")
    @classmethod
    def validate_urls(cls, value: list[str]) -> list[str]:
        return policy.validate_evidence_paths(value)


class CancelJourneyIn(BaseModel):
    reason: str = Field(min_length=3, max_length=500)


class ReportJourneyIn(BaseModel):
    reported_user_id: int = Field(gt=0)
    reason_code: Literal[
        "CUSTOMER_LATE",
        "CUSTOMER_NO_SHOW",
        "SALE_LATE",
        "SALE_NO_SHOW",
        "OWNER_LATE",
        "OWNER_NO_SHOW",
        "WRONG_INFORMATION",
        "UNAUTHORIZED_CLOSE",
        "PAYMENT_ISSUE",
        "OTHER",
    ]
    detail: str = Field(min_length=3, max_length=1000)
    evidence_urls: list[str] = Field(default_factory=list)

    @field_validator("evidence_urls")
    @classmethod
    def validate_evidence(cls, value: list[str]) -> list[str]:
        if not value:
            return []
        return policy.validate_evidence_paths(value)
