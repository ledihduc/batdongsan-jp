"""Unit tests cho redaction PII/secret — chốt an toàn của pipeline log.

Nguyên tắc kiểm thử: over-redact chấp nhận được, để-lọt là fail. Mọi hàm phải
KHÔNG raise dù input dị dạng (logging path không được chết).
"""

from __future__ import annotations

from app.observability.redaction import _PLACEHOLDER, redact_obj, redact_text


class TestRedactText:
    def test_email_redacted(self) -> None:
        out = redact_text("liên hệ nguyen.van.a@example.com nhé")
        assert "nguyen.van.a@example.com" not in out
        assert _PLACEHOLDER in out

    def test_jwt_redacted(self) -> None:
        jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.s5-abcDEF_012"
        out = redact_text(f"token={jwt}")
        assert jwt not in out
        assert _PLACEHOLDER in out

    def test_bearer_redacted(self) -> None:
        out = redact_text("Authorization: Bearer abc.def-123_XYZ")
        assert "abc.def-123_XYZ" not in out
        assert _PLACEHOLDER in out

    def test_vn_phone_redacted(self) -> None:
        for phone in ("0901234567", "+84901234567"):
            out = redact_text(f"gọi {phone} gấp")
            assert phone not in out, phone
            assert _PLACEHOLDER in out

    def test_long_number_redacted(self) -> None:
        # CCCD 12 số / số tài khoản dài.
        out = redact_text("CCCD 012345678912 của khách")
        assert "012345678912" not in out
        assert _PLACEHOLDER in out

    def test_plain_text_untouched(self) -> None:
        msg = "Không tìm thấy phòng trống trong tòa nhà"
        assert redact_text(msg) == msg

    def test_short_number_kept(self) -> None:
        # 4 chữ số (mã lỗi, phòng) KHÔNG bị redact.
        assert "404" in redact_text("lỗi 404 not found")

    def test_never_raises_on_non_str(self) -> None:
        # redact_text khai báo str nhưng phải nuốt lỗi nếu bị gọi sai kiểu.
        assert redact_text(None) == _PLACEHOLDER  # type: ignore[arg-type]


class TestRedactObj:
    def test_sensitive_key_value_replaced_entirely(self) -> None:
        out = redact_obj({"password": "hunter2", "keep": "ok"})
        assert out["password"] == _PLACEHOLDER
        assert out["keep"] == "ok"

    def test_sensitive_key_case_and_dash_insensitive(self) -> None:
        out = redact_obj({"Set-Cookie": "sid=123", "Access_Token": "t"})
        assert out["Set-Cookie"] == _PLACEHOLDER
        assert out["Access_Token"] == _PLACEHOLDER

    def test_nested_structure_redacted(self) -> None:
        out = redact_obj(
            {"user": {"email": "a@b.com", "tokens": [{"jwt": "x"}]}}
        )
        assert "a@b.com" not in out["user"]["email"]
        assert out["user"]["tokens"][0]["jwt"] == _PLACEHOLDER

    def test_list_of_strings_redacted(self) -> None:
        out = redact_obj(["mail me a@b.com", "plain"])
        assert "a@b.com" not in out[0]
        assert out[1] == "plain"

    def test_non_string_scalars_kept(self) -> None:
        out = redact_obj({"count": 3, "ok": True, "ratio": 1.5})
        assert out == {"count": 3, "ok": True, "ratio": 1.5}

    def test_depth_limit_returns_placeholder(self) -> None:
        # Lồng sâu hơn _MAX_DEPTH (8) → cắt bằng placeholder, không đệ quy vô tận.
        deep: dict = {"v": "x"}
        for _ in range(12):
            deep = {"v": deep}
        out = redact_obj(deep)
        flat = repr(out)
        assert _PLACEHOLDER in flat

    def test_never_raises(self) -> None:
        class Weird:
            def __iter__(self):  # noqa: ANN204
                raise RuntimeError("boom")

        # Không được ném — trả về chính object (scalar path) là chấp nhận được.
        redact_obj(Weird())
