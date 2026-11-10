"""Tách pending action khỏi kết quả tool chat (Phase 09, F-6).

Token xác nhận chỉ đi tới app (thẻ `pending_actions`), KHÔNG đi tới model: model chỉ biết
"đã hiện thẻ xác nhận". Lỗi `login_required` (khách chưa đăng nhập) bật cờ cho app.
"""

from __future__ import annotations

from app.ai_capabilities.loader import Registry
from app.ai_capabilities.system_skills import pick_text

CARD_SHOWN_NOTE = "確認カードを表示しました / confirmation card shown to the user; the action runs only after they confirm"


class PendingCards:
    def __init__(self, registry: Registry, lang: str) -> None:
        self._registry = registry
        self._lang = lang
        self.cards: list[dict] = []
        self.login_required = False

    def take(self, payload: dict) -> dict:
        """Trả payload gửi model; gom thẻ / cờ đăng nhập khi có."""
        if payload.get("error") == "login_required":
            self.login_required = True
            return payload
        token = payload.get("pending_token")
        if not token:
            return payload
        name = str(payload.get("action"))
        action = self._registry.get(name)
        title = pick_text(action.title, self._lang, self._registry.default_lang) if action else name
        self.cards.append({"token": token, "action": name, "title": title,
                           "params": payload.get("params") or {}, "expires_at": payload.get("expires_at")})
        to_model = {k: v for k, v in payload.items() if k != "pending_token"}
        to_model["note"] = CARD_SHOWN_NOTE
        return to_model
