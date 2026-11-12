"""Chấm tham số trong script eval chat: chuỗi kỳ vọng khớp theo ranh giới từ (Phase 13, QA F2)."""

from __future__ import annotations

import importlib.util
import pathlib

import pytest

_PATH = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "eval_ai_chat_multilang.py"
_spec = importlib.util.spec_from_file_location("eval_ai_chat_multilang", _PATH)
evalmod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(evalmod)


@pytest.mark.parametrize(("expected", "actual", "ok"), [
    (["Quận 1"], "Quận 10", False),
    (["Quận 1"], "Quận 1", True),
    (["Quận 1"], "Quận 1, Hồ Chí Minh", True),
    (["Hà Nội"], "Thành phố Hà Nội", True),
    (["Cầu Giấy"], "cầu giấy", True),
    (["Ba Đình"], "Ba Đình2", False),
    (["中目黒"], "中目黒駅", True),  # CJK không có ranh giới từ (code review M1)
    (["渋谷"], "東京都渋谷区", True),
])
def test_ai_chat_eval_value_ok_location_word_boundary(expected, actual, ok):
    # Act / Assert
    assert evalmod._value_ok(expected, actual) is ok
