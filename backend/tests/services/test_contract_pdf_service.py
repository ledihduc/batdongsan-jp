"""AC-54: Unit tests for ContractPDFService — dual-disclosure PDF generation.

Test strategy:
  - All tests mock weasyprint.HTML so they run without system cairo/pango libraries.
  - NFR-12 golden test checks that Vietnamese diacritics survive the Jinja2 → HTML
    render path (bytes-level assertion; does not require a real PDF reader).
  - tmp_path pytest fixture is used for output file paths.

Run: pytest tests/services/test_contract_pdf_service.py -v
"""

from __future__ import annotations

import importlib
import types
from pathlib import Path
from typing import Optional
from unittest.mock import MagicMock, patch

import pytest


# ---------------------------------------------------------------------------
# Fixtures — lightweight fake ORM objects (no DB required)
# ---------------------------------------------------------------------------


def _make_contract(
    id: int = 42,
    room_id: int = 7,
    start_date: str = "2026-01-01",
    end_date: str = "2026-12-31",
    monthly_rent: float = 5_000_000,
) -> MagicMock:
    c = MagicMock()
    c.id = id
    c.room_id = room_id
    c.start_date = start_date
    c.end_date = end_date
    c.monthly_rent = monthly_rent
    return c


def _make_user(
    id: int = 1,
    name: str = "Nguyễn Văn A",
    cccd_number: Optional[str] = "012345678901",
    id_number: Optional[str] = None,
) -> MagicMock:
    u = MagicMock()
    u.id = id
    u.name = name
    # Simulate either cccd_number (custom) or id_number (User model field)
    u.cccd_number = cccd_number
    u.id_number = id_number
    return u


def _make_delegation(
    id: str = "aaaa-1111-bbbb-2222",
    poa_format: str = "notarized",
    poa_document_path: Optional[str] = "/secure/poa/aaaa.pdf",
) -> MagicMock:
    d = MagicMock()
    d.id = id
    d.poa_format = poa_format
    d.poa_document_path = poa_document_path
    return d


# ---------------------------------------------------------------------------
# Helper — build a fake weasyprint module for injection
# ---------------------------------------------------------------------------


def _fake_weasyprint(pdf_bytes: bytes = b"%PDF-1.4 fake") -> types.ModuleType:
    """Return a minimal fake weasyprint module that writes deterministic bytes."""
    mod = types.ModuleType("weasyprint")

    class _FakeHTML:
        def __init__(self, string: str, **kwargs):
            self._string = string

        def write_pdf(self) -> bytes:
            return pdf_bytes

    mod.HTML = _FakeHTML
    return mod


# ---------------------------------------------------------------------------
# Test: owner-only mode (operator=None)
# ---------------------------------------------------------------------------


class TestOwnerOnlyGeneration:
    """AC-54: When operator is None only the owner block appears."""

    def test_pdf_file_written(self, tmp_path: Path) -> None:
        """PDF file is created at output_path."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        contract = _make_contract()
        owner = _make_user()
        output = str(tmp_path / "owner_only.pdf")

        with patch.dict("sys.modules", {"weasyprint": _fake_weasyprint()}):
            result = svc.generate(contract, owner, operator=None, output_path=output)

        assert result == output
        assert Path(output).exists()
        assert Path(output).stat().st_size > 0

    def test_html_contains_owner_name(self, tmp_path: Path) -> None:
        """Rendered HTML includes the owner's name."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        contract = _make_contract()
        owner = _make_user(name="Trần Thị Bích")

        html = svc._render_html(contract, owner, operator=None, delegation=None)

        assert "Trần Thị Bích" in html

    def test_html_no_operator_block(self, tmp_path: Path) -> None:
        """When operator is None, the operator disclosure section heading is absent."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        contract = _make_contract()
        owner = _make_user()

        html = svc._render_html(contract, owner, operator=None, delegation=None)

        # The operator disclosure block heading is inside a {% if has_operator %} guard
        assert "Đại diện được ủy quyền (Operator)" not in html

    def test_html_no_operator_signature_col(self) -> None:
        """Signature column for operator is absent in owner-only mode."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        html = svc._render_html(_make_contract(), _make_user(), operator=None, delegation=None)

        # The operator sig-role label is inside {% if has_operator %} block
        assert "Operator ký thay mặt" not in html

    def test_owner_cccd_fallback_to_id_number(self) -> None:
        """If cccd_number is None, id_number is used as fallback."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        owner = _make_user(cccd_number=None, id_number="079200012345")

        html = svc._render_html(_make_contract(), owner, operator=None, delegation=None)

        assert "079200012345" in html

    def test_owner_cccd_none_shows_placeholder(self) -> None:
        """If both cccd_number and id_number are None, placeholder text is shown."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        owner = _make_user(cccd_number=None, id_number=None)

        html = svc._render_html(_make_contract(), owner, operator=None, delegation=None)

        assert "chưa cung cấp" in html


# ---------------------------------------------------------------------------
# Test: dual-disclosure mode (operator set)
# ---------------------------------------------------------------------------


class TestDualDisclosureGeneration:
    """AC-54: When operator is set, both owner and operator blocks appear."""

    def test_pdf_file_written(self, tmp_path: Path) -> None:
        """PDF file is created at output_path in dual-disclosure mode."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        contract = _make_contract()
        owner = _make_user(id=1, name="Lê Văn C")
        operator = _make_user(id=2, name="Phạm Thị D", cccd_number="098765432109")
        delegation = _make_delegation()
        output = str(tmp_path / "dual_disclosure.pdf")

        with patch.dict("sys.modules", {"weasyprint": _fake_weasyprint()}):
            result = svc.generate(
                contract, owner, operator=operator, output_path=output, delegation=delegation
            )

        assert result == output
        assert Path(output).exists()

    def test_html_contains_both_names(self) -> None:
        """Rendered HTML includes both owner and operator names."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        owner = _make_user(name="Nguyễn Chủ Sở Hữu")
        operator = _make_user(name="Trần Đại Diện")
        delegation = _make_delegation()

        html = svc._render_html(_make_contract(), owner, operator=operator, delegation=delegation)

        assert "Nguyễn Chủ Sở Hữu" in html
        assert "Trần Đại Diện" in html

    def test_html_contains_operator_disclosure_heading(self) -> None:
        """Dual-disclosure block heading is present."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        html = svc._render_html(
            _make_contract(), _make_user(), operator=_make_user(), delegation=_make_delegation()
        )

        assert "Đại diện được ủy quyền" in html

    def test_html_contains_delegation_id(self) -> None:
        """Delegation UUID is embedded in the rendered HTML."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        delegation = _make_delegation(id="dead-beef-1234-5678")

        html = svc._render_html(
            _make_contract(), _make_user(), operator=_make_user(), delegation=delegation
        )

        assert "dead-beef-1234-5678" in html

    def test_html_poa_notarized_label(self) -> None:
        """'Công chứng' label appears for notarized POA format."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        delegation = _make_delegation(poa_format="notarized")

        html = svc._render_html(
            _make_contract(), _make_user(), operator=_make_user(), delegation=delegation
        )

        assert "Công chứng" in html

    def test_html_poa_digital_label(self) -> None:
        """'Điện tử' label appears for digital POA format."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        delegation = _make_delegation(poa_format="digital")

        html = svc._render_html(
            _make_contract(), _make_user(), operator=_make_user(), delegation=delegation
        )

        assert "Điện tử" in html

    def test_html_operator_cccd_present(self) -> None:
        """Operator CCCD number appears in the rendered HTML."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        operator = _make_user(cccd_number="111222333444")

        html = svc._render_html(
            _make_contract(), _make_user(), operator=operator, delegation=_make_delegation()
        )

        assert "111222333444" in html

    def test_html_delegation_none_degrades_gracefully(self) -> None:
        """When delegation is None (not loaded), operator block still renders."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        html = svc._render_html(
            _make_contract(), _make_user(), operator=_make_user(), delegation=None
        )

        # Operator disclosure heading present
        assert "Đại diện được ủy quyền" in html
        # Delegation ID shows placeholder
        assert "chưa liên kết" in html

    def test_operator_signature_col_present(self) -> None:
        """Signature column for operator appears in dual-disclosure mode."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        html = svc._render_html(
            _make_contract(), _make_user(), operator=_make_user(), delegation=_make_delegation()
        )

        assert "Đại diện ủy quyền" in html


# ---------------------------------------------------------------------------
# Test: NFR-12 — Vietnamese diacritics (golden test)
# ---------------------------------------------------------------------------


class TestNFR12VietnameseDiacritics:
    """NFR-12: Vietnamese diacritics must be preserved through the render pipeline.

    This test operates at the HTML bytes level (not PDF extraction) because
    weasyprint is mocked. The assertion confirms that the Jinja2 render step does
    NOT corrupt Vietnamese Unicode characters. The template uses UTF-8 charset and
    DejaVu Sans font — this test verifies the charset contract.

    Golden strings chosen to cover multiple diacritic categories:
      - Tone marks: sắc, huyền, nặng, hỏi, ngã
      - Vowel modifications: ă, â, ê, ô, ơ, ư, đ
    """

    def test_diacritic_string_cam_doan_in_html(self) -> None:
        """'Tôi cam đoan' (tone + vowel mod) appears intact in rendered HTML."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        html = svc._render_html(_make_contract(), _make_user(), operator=None, delegation=None)

        # NFR-12 golden string: includes tonal diacritics ô and đ
        assert "Tôi cam đoan" in html

    def test_page_header_diacritics_preserved(self) -> None:
        """Vietnamese header strings (CỘNG HOÀ, Độc lập…) survive render."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        html = svc._render_html(_make_contract(), _make_user(), operator=None, delegation=None)

        assert "CỘNG HOÀ XÃ HỘI CHỦ NGHĨA VIỆT NAM" in html
        assert "Độc lập" in html
        assert "Tự do" in html
        assert "Hạnh phúc" in html

    def test_section_titles_diacritics(self) -> None:
        """Section titles with diacritics render correctly."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        html = svc._render_html(_make_contract(), _make_user(), operator=None, delegation=None)

        assert "Bên cho thuê" in html
        assert "Bên thuê" in html
        assert "Điều khoản hợp đồng" in html
        assert "Ký xác nhận" in html

    def test_html_bytes_utf8_encoded(self) -> None:
        """HTML output encodes Vietnamese characters correctly as UTF-8 bytes."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        html = svc._render_html(_make_contract(), _make_user(), operator=None, delegation=None)

        html_bytes = html.encode("utf-8")
        # 'Độc' encoded in UTF-8 starts with 0xC4 0x90 for 'Đ'
        assert "Độc lập".encode("utf-8") in html_bytes

    def test_owner_name_with_diacritics_preserved(self) -> None:
        """Owner names containing Vietnamese diacritics pass through unescaped (autoescape safe)."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        owner = _make_user(name="Nguyễn Thị Ánh Nguyệt")

        html = svc._render_html(_make_contract(), owner, operator=None, delegation=None)

        # Jinja2 autoescape HTML-encodes special chars but NOT Unicode letters;
        # Vietnamese diacritics are not HTML special chars, so they must pass through
        # as-is (not as &#....; entities).
        assert "Nguyễn Thị Ánh Nguyệt" in html

    def test_operator_name_with_diacritics_in_dual_disclosure(self) -> None:
        """Operator names with diacritics render correctly in dual-disclosure mode."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        operator = _make_user(name="Phạm Thị Hương Giang")

        html = svc._render_html(
            _make_contract(), _make_user(), operator=operator, delegation=_make_delegation()
        )

        assert "Phạm Thị Hương Giang" in html


# ---------------------------------------------------------------------------
# Test: error handling
# ---------------------------------------------------------------------------


class TestErrorHandling:
    def test_missing_weasyprint_raises_runtime_error(self, tmp_path: Path) -> None:
        """If weasyprint is not installed, RuntimeError is raised with helpful message."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        output = str(tmp_path / "out.pdf")

        # Simulate weasyprint not installed
        with patch.dict("sys.modules", {"weasyprint": None}):
            with pytest.raises((RuntimeError, ImportError)):
                svc.generate(_make_contract(), _make_user(), operator=None, output_path=output)

    def test_output_dir_created_automatically(self, tmp_path: Path) -> None:
        """Output directory is created if it does not exist."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        nested = str(tmp_path / "a" / "b" / "c" / "contract.pdf")

        with patch.dict("sys.modules", {"weasyprint": _fake_weasyprint()}):
            result = svc.generate(_make_contract(), _make_user(), operator=None, output_path=nested)

        assert Path(result).exists()

    def test_generate_returns_output_path(self, tmp_path: Path) -> None:
        """generate() returns the same output_path passed in."""
        from app.services.contract_pdf_service import ContractPDFService

        svc = ContractPDFService()
        output = str(tmp_path / "ret.pdf")

        with patch.dict("sys.modules", {"weasyprint": _fake_weasyprint()}):
            result = svc.generate(_make_contract(), _make_user(), operator=None, output_path=output)

        assert result == output
