"""Hành động ghi AI chờ người dùng xác nhận (plan 20261027-1102 Phase 09, P6, PD8).

Table: ai_pending_actions (migration 0168_ai_pending_actions)

- Token chỉ lưu SHA-256 (`token_sha256`); token gốc chỉ nằm trong link/thẻ gửi người dùng.
- Một lần dùng: claim bằng UPDATE có điều kiện `status='pending' AND expires_at > now`.
- `result` giữ id dòng đã ghi (wishlists / jp_viewings) để `undo_service` gỡ được (K12).
- Thời gian lưu naive UTC (như JpViewing).
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from sqlalchemy import JSON, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

PENDING_STATUS_VALUES = ("pending", "executed", "failed", "undone")


def _now_utc() -> datetime:
    return datetime.utcnow()


class AiPendingAction(Base):
    __tablename__ = "ai_pending_actions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    token_sha256: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    action: Mapped[str] = mapped_column(String(64), nullable=False)
    params: Mapped[Any] = mapped_column(JSON, nullable=False)
    channel: Mapped[str] = mapped_column(String(10), nullable=False)
    # Pending tạo trong chat gắn người tạo ⇒ người khác bấm ⇒ 403. MCP không có user ⇒ NULL.
    owner_user_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(12), nullable=False, default="pending")
    error_code: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    result: Mapped[Optional[Any]] = mapped_column(JSON, nullable=True)
    executed_by_user_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=_now_utc)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    executed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
