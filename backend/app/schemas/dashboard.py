"""Pydantic v2 schemas for the host dashboard 'cần action' payload."""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


class ExpiringContractRow(BaseModel):
    contract_id: int
    room_id: int
    end_date: str
    monthly_rent: float


class OverdueInvoiceRow(BaseModel):
    invoice_id: int
    invoice_number: str
    contract_id: int
    due_date: str
    total_amount: float
    paid_amount: float = 0


class OverdueKhaiBaoRow(BaseModel):
    khai_bao_id: int
    tenant_id: int
    contract_id: Optional[int] = None
    check_in_at: str  # ISO datetime


class MaintenanceRoomRow(BaseModel):
    room_id: int
    room_code: str
    building_id: int
    building_name: str
    maintenance_start: Optional[str] = None
    maintenance_end: Optional[str] = None


class ActionItemsSummary(BaseModel):
    expiring_count: int = 0
    overdue_invoice_count: int = 0
    overdue_khai_bao_count: int = 0
    maintenance_count: int = 0


class ActionItemsResponse(BaseModel):
    expiring_contracts: list[ExpiringContractRow] = Field(default_factory=list)
    overdue_invoices: list[OverdueInvoiceRow] = Field(default_factory=list)
    overdue_khai_bao: list[OverdueKhaiBaoRow] = Field(default_factory=list)
    maintenance_rooms: list[MaintenanceRoomRow] = Field(default_factory=list)
    summary: ActionItemsSummary = Field(default_factory=ActionItemsSummary)


class ZaloReminderRequest(BaseModel):
    """Optional override of recipient phone (e.g. roommate)."""

    phone_override: Optional[str] = None


class ZaloReminderResponse(BaseModel):
    zalo_link: str
    phone: str
    message: str
