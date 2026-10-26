"""Unit tests cho sanitizer thuộc tính BĐS công nghiệp (P3, migration 0046).

_clean_industrial_attrs là chốt validate input KHÔNG tin từ client trước khi ghi
vào cột houses.industrial_attrs. Bỏ field lạ, ép kiểu, chặn giá trị âm."""

from __future__ import annotations

from app.routers.houses import _clean_industrial_attrs


class TestCleanIndustrialAttrs:
    def test_valid_full_payload(self) -> None:
        out = _clean_industrial_attrs(
            {"area_ha": 2.5, "power_mva": 3.2, "fire_safety": True, "kcn_legal": "KCN X"}
        )
        assert out == {
            "area_ha": 2.5,
            "power_mva": 3.2,
            "fire_safety": True,
            "kcn_legal": "KCN X",
        }

    def test_coerces_int_to_float(self) -> None:
        out = _clean_industrial_attrs({"area_ha": 3})
        assert out == {"area_ha": 3.0}
        assert isinstance(out["area_ha"], float)

    def test_drops_unknown_keys(self) -> None:
        out = _clean_industrial_attrs({"area_ha": 1.0, "evil": "x", "__proto__": 1})
        assert out == {"area_ha": 1.0}

    def test_rejects_negative_numbers(self) -> None:
        assert _clean_industrial_attrs({"area_ha": -5}) is None

    def test_non_bool_fire_safety_dropped(self) -> None:
        # "true" (string) không phải bool → bỏ.
        assert _clean_industrial_attrs({"fire_safety": "true"}) is None

    def test_empty_or_wrong_type_returns_none(self) -> None:
        assert _clean_industrial_attrs({}) is None
        assert _clean_industrial_attrs(None) is None
        assert _clean_industrial_attrs("not a dict") is None
        assert _clean_industrial_attrs([1, 2]) is None

    def test_legal_string_trimmed_and_capped(self) -> None:
        out = _clean_industrial_attrs({"kcn_legal": "  " + "x" * 400 + "  "})
        assert out is not None
        assert len(out["kcn_legal"]) == 200

    def test_blank_legal_dropped(self) -> None:
        assert _clean_industrial_attrs({"kcn_legal": "   "}) is None
