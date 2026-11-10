"""Lỗi của một lần chạy action — module riêng để `rest_handler` và `action_runner` cùng dùng mà không vòng import."""

from __future__ import annotations


class ActionError(Exception):
    """code ∈ unknown_action | invalid_arguments | not_found | login_required |
    upstream_error | rate_limited | endpoint_not_allowed."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(f"{code}: {message}")
        self.code = code
        self.message = message
