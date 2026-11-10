"""Request/Response của `POST /api/ai/chat` (plan 20261027-1102 Phase 08, F-1, F-2)."""

from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator, model_validator


# Trần tổng ký tự cả lịch sử: mỗi vòng tool gửi lại toàn bộ lịch sử (≤7 lần/lượt), không cache (QA M3).
MAX_TOTAL_CHARS = 8000


class AiChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=2000)

    @field_validator("content")
    @classmethod
    def _not_blank(cls, value: str) -> str:
        # Messages API trả 400 cho text toàn khoảng trắng ⇒ chặn ở 422 thay vì 502 (QA M1).
        if not value.strip():
            raise ValueError("content must not be blank")
        return value


class AiChatRequest(BaseModel):
    """Không trạng thái: client gửi lại lịch sử mỗi lượt; phần tử cuối phải là user."""

    messages: list[AiChatMessage] = Field(min_length=1, max_length=20)
    lang: Optional[str] = Field(None, pattern=r"^[a-z]{2}$")  # None ⇒ registry.default_lang

    @model_validator(mode="after")
    def _check_history(self) -> "AiChatRequest":
        if self.messages[-1].role != "user":
            raise ValueError("last message must have role 'user'")
        if sum(len(m.content) for m in self.messages) > MAX_TOTAL_CHARS:
            raise ValueError(f"total content must be at most {MAX_TOTAL_CHARS} characters")
        return self


class AiChatToolCall(BaseModel):
    name: str
    arguments: dict
    is_error: bool


class AiChatResponse(BaseModel):
    reply: str
    listings: list[dict]  # thẻ trung tính thị trường (CARD_KEYS, T15)
    tool_rounds: int
    tool_calls: list[AiChatToolCall]
    model: str
