"""Client Anthropic giả cho test chat (plan 20261027-1102 Phase 08) — không gọi mạng.

Phần tử script: `fake_tool_use(...)`, `fake_text(...)` hoặc hàm async nhận `**kwargs`
(giả lời chậm / ném lỗi). `messages.calls` ghi bản sao kwargs của mỗi lần gọi.
"""

from __future__ import annotations

import copy
from types import SimpleNamespace


def fake_tool_use(name: str, input: dict, id: str, *, text: str = "") -> SimpleNamespace:
    blocks = [SimpleNamespace(type="text", text=text)] if text else []
    blocks.append(SimpleNamespace(type="tool_use", id=id, name=name, input=input))
    return SimpleNamespace(stop_reason="tool_use", content=blocks)


def fake_text(text: str, stop_reason: str = "end_turn") -> SimpleNamespace:
    content = [SimpleNamespace(type="text", text=text)] if text else []
    return SimpleNamespace(stop_reason=stop_reason, content=content)


class _FakeMessages:
    def __init__(self, script: list):
        self.script = script
        self.calls: list[dict] = []

    async def create(self, **kwargs):
        # Bản sao: service nối thêm vào `messages` sau lần gọi, test cần ảnh chụp đúng lúc gọi.
        self.calls.append(copy.deepcopy(kwargs))
        if not self.script:
            raise AssertionError("FakeAnthropic: hết script")
        step = self.script.pop(0)
        if callable(step):
            return await step(**kwargs)
        return step


class FakeAnthropic:
    def __init__(self, script: list | None = None):
        self.messages = _FakeMessages(script if script is not None else [])

    @property
    def script(self) -> list:
        return self.messages.script
