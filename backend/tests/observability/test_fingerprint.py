"""Unit tests cho fingerprint lỗi — chữ ký ổn định để gom nhóm (dedupe).

Yêu cầu cốt lõi: cùng LOẠI lỗi (khác id/số/uuid cụ thể) phải cho cùng
fingerprint; khác loại phải khác fingerprint.
"""

from __future__ import annotations

from app.observability.fingerprint import (
    compute_fingerprint,
    normalize_message,
    normalize_route,
    top_frame_of,
)


class TestNormalizeRoute:
    def test_numeric_segments_templated(self) -> None:
        assert normalize_route("/api/houses/42/rooms/7") == "/api/houses/{id}/rooms/{id}"

    def test_trailing_id_templated(self) -> None:
        assert normalize_route("/api/users/123") == "/api/users/{id}"

    def test_non_numeric_kept(self) -> None:
        assert normalize_route("/api/houses/search") == "/api/houses/search"

    def test_none_safe(self) -> None:
        assert normalize_route(None) == ""  # type: ignore[arg-type]


class TestNormalizeMessage:
    def test_strips_uuid_numbers_quotes_addr(self) -> None:
        msg = "User 'abc' 12345 failed at 0x1af id 550e8400-e29b-41d4-a716-446655440000"
        out = normalize_message(msg)
        assert "12345" not in out
        assert "0x1af" not in out
        assert "550e8400" not in out
        assert "<n>" in out and "<uuid>" in out and "<addr>" in out and "<str>" in out

    def test_truncated_to_300(self) -> None:
        assert len(normalize_message("x" * 500)) <= 300


class TestComputeFingerprint:
    def test_stable_across_differing_ids(self) -> None:
        a = compute_fingerprint(
            exc_type="ValueError", message="User 123 not found", route="/api/users/123"
        )
        b = compute_fingerprint(
            exc_type="ValueError", message="User 456 not found", route="/api/users/456"
        )
        assert a == b

    def test_differs_by_exc_type(self) -> None:
        a = compute_fingerprint(exc_type="ValueError", message="boom", route="/x")
        b = compute_fingerprint(exc_type="KeyError", message="boom", route="/x")
        assert a != b

    def test_differs_by_route(self) -> None:
        a = compute_fingerprint(exc_type="E", message="m", route="/api/a")
        b = compute_fingerprint(exc_type="E", message="m", route="/api/b")
        assert a != b

    def test_returns_16_hex(self) -> None:
        fp = compute_fingerprint(exc_type="E", message="m", route="/x")
        assert len(fp) == 16
        int(fp, 16)  # ném nếu không phải hex

    def test_all_none_is_deterministic(self) -> None:
        assert compute_fingerprint() == compute_fingerprint()


class TestTopFrameOf:
    def test_extracts_last_app_frame(self) -> None:
        tb = (
            'Traceback (most recent call last):\n'
            '  File "/usr/lib/python3.11/x.py", line 10, in outer\n'
            '  File "/app/app/routers/houses.py", line 88, in get_house\n'
            '    raise ValueError()\n'
            'ValueError\n'
        )
        out = top_frame_of(tb)
        # Giữ từ 'app/' đầu tiên trở đi + line + func; prefix container (/app)
        # có thể lặp 'app/app/...' nên chỉ khẳng định phần đuôi ổn định.
        assert out.endswith("routers/houses.py:88:get_house")
        assert out.startswith("app/")

    def test_empty_when_no_frames(self) -> None:
        assert top_frame_of("just a message") == ""

    def test_none_safe(self) -> None:
        assert top_frame_of(None) == ""  # type: ignore[arg-type]
