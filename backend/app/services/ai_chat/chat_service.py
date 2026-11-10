"""Một lượt chat: vòng lặp tool thủ công với Claude (Phase 08, research Q1, Q2).

Mỗi `tool_use` chạy `call_fixed_tool` — cùng hàm MCP dùng (X2, K6). Nối `assistant`
(nguyên văn `response.content`) rồi `user` với các `tool_result` đứng đầu. Không
`temperature`, không `tool_choice` (đổi model bằng env không vỡ, D8). Không log nội dung chat.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Callable, ContextManager

from sqlalchemy.orm import Session

from app.ai_capabilities.action_runner import encode_tool_result
from app.ai_capabilities.context import ActionContext
from app.ai_capabilities.fixed_tools import RUN_ACTION, call_fixed_tool, local_tz
from app.ai_capabilities.loader import Registry
from app.database import SessionLocal
from app.services.ai_chat.chat_tools import build_system_blocks, to_anthropic_tools
from app.services.ai_chat.listing_cards import detail_to_item, select_cards, to_card

logger = logging.getLogger(__name__)

FALLBACK_REPLIES: dict[str, str] = {
    "ja": "条件に合う物件をうまく絞り込めませんでした。条件を変えてもう一度お試しください。",
    "vi": "Chưa lọc được tin phù hợp. Hãy đổi điều kiện và thử lại.",
    "en": "I couldn't narrow down matching listings. Please change the conditions and try again.",
}
REFUSAL_REPLIES: dict[str, str] = {
    "ja": "申し訳ありませんが、このご質問にはお答えできません。",
    "vi": "Xin lỗi, tôi không thể trả lời câu hỏi này.",
    "en": "Sorry, I can't answer this question.",
}
REPLY_MAX_CHARS = 2000  # = trần content của AiChatMessage: client gửi lại reply làm lịch sử không bị 422 (L1)
_ENCODE_FAILED = {"error": "upstream_error", "message": "tool result could not be encoded"}


@dataclass(frozen=True)
class ChatTurnResult:
    reply: str
    listings: list[dict]
    tool_rounds: int
    tool_calls: list[dict]
    tool_payloads: list[dict]  # payload `run_action` theo thứ tự (Phase 09 đọc pending)


def reply_for(table: dict[str, str], lang: str) -> str:
    return table.get(lang) or table["en"]


def _text_of(content) -> str:
    return "".join(getattr(b, "text", "") or "" for b in content if getattr(b, "type", None) == "text").strip()


def _encode(payload: dict) -> tuple[bool, str]:
    try:
        return False, encode_tool_result(payload)
    except (TypeError, ValueError):  # vd Decimal trong payload — không lộ chi tiết cho model
        return True, encode_tool_result(_ENCODE_FAILED)


class _ToolItems:
    """Gom tin do `run_action` trả: mọi tin (để lọc trích dẫn) + kết quả `search_listings` cuối."""

    def __init__(self) -> None:
        self.all: list[dict] = []
        self.last_search: list[dict] = []

    def add(self, action: str, payload: dict) -> None:
        if action == "search_listings" and isinstance(payload.get("items"), list):
            items = [i for i in payload["items"] if isinstance(i, dict)]
            self.all.extend(items)
            self.last_search = items
        elif action == "get_listing" and payload.get("listing_id") is not None:
            self.all.append(detail_to_item(payload))


async def _run_tool_block(block, registry: Registry, ctx: ActionContext, session_scope, items: _ToolItems,
                          tool_calls: list[dict], payloads: list[dict]) -> dict:
    arguments = block.input if isinstance(block.input, dict) else {}
    is_error, payload = await call_fixed_tool(registry, block.name, block.input, ctx, session_scope=session_scope)
    encode_failed, content = _encode(payload)
    is_error = is_error or encode_failed
    tool_calls.append({"name": block.name, "arguments": arguments, "is_error": is_error})
    if block.name == RUN_ACTION:
        payloads.append(payload)
        if not is_error:
            items.add(str(arguments.get("action")), payload)
    return {"type": "tool_result", "tool_use_id": block.id, "content": content, "is_error": is_error}


async def run_chat_turn(
    client, registry: Registry, messages: list[dict], *, lang: str, ctx: ActionContext, model: str,
    max_rounds: int, max_tokens: int, max_tool_calls: int, session_scope: Callable[[], ContextManager[Session]] = SessionLocal,
) -> ChatTurnResult:
    system = build_system_blocks(registry, lang, datetime.now(local_tz()))
    tools = to_anthropic_tools()
    convo: list[dict] = [dict(m) for m in messages]
    items, tool_calls, payloads = _ToolItems(), [], []
    rounds, reply, refused = 0, "", False
    while True:
        response = await client.messages.create(
            model=model, max_tokens=max_tokens, system=system, tools=tools, messages=convo,
        )
        tool_blocks = [b for b in response.content if getattr(b, "type", None) == "tool_use"]
        # stop_reason tool_use mà không có block tool ⇒ coi như kết thúc, không gửi lượt user rỗng (QA L6).
        if response.stop_reason != "tool_use" or not tool_blocks:
            refused = response.stop_reason == "refusal"
            reply = "" if refused else _text_of(response.content)
            break
        # Vòng thứ max_rounds+1 vẫn đòi tool, hoặc vượt trần tool_call của lượt ⇒ dừng, trả câu dự phòng (T4, QA M3).
        if rounds >= max_rounds or len(tool_calls) + len(tool_blocks) > max_tool_calls:
            break
        rounds += 1
        convo.append({"role": "assistant", "content": response.content})
        results = [
            await _run_tool_block(b, registry, ctx, session_scope, items, tool_calls, payloads)
            for b in tool_blocks
        ]
        convo.append({"role": "user", "content": results})
    # Câu dự phòng/từ chối không phải lời model ⇒ không kèm thẻ, tránh "không lọc được" mà vẫn hiện tin (QA L1).
    cards = [to_card(i) for i in select_cards(reply, items.all, items.last_search)] if reply else []
    if refused:
        reply = reply_for(REFUSAL_REPLIES, lang)
    reply = (reply or reply_for(FALLBACK_REPLIES, lang))[:REPLY_MAX_CHARS]
    logger.info("ai_chat_tools", extra={
        "event": "ai_chat_tools", "actions": registry.names(), "registry_version": registry.version,
        "market": registry.market, "tool_rounds": rounds, "model": model, "lang": lang,
    })
    return ChatTurnResult(reply=reply, listings=cards, tool_rounds=rounds, tool_calls=tool_calls, tool_payloads=payloads)
