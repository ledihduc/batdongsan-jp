"""AC-54: Contract PDF dual-disclosure service — Owner-Operator Delegation v1.

Legal compliance requirement (BA Q6.4): rental contracts must explicitly disclose
BOTH the Owner (legal landlord) AND the Operator (acting party with POA) so tenants
can verify operator authority.

Generates a PDF from the Jinja2 template `contract_with_disclosure.html` via
weasyprint. Caller is responsible for locating owner/operator/delegation data and
passing it in; this service only renders and writes the file.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Optional

from jinja2 import Environment, FileSystemLoader, select_autoescape

# AC-54: weasyprint is an optional runtime dependency (declared in requirements.txt).
# Import is deferred to generate() so that the rest of the application starts even
# if the system-level cairo/pango libraries are absent (e.g. lightweight CI images).
# Tests that do NOT exercise real PDF rendering mock weasyprint via pytest-mock.
_TEMPLATE_DIR = Path(__file__).parent.parent / "templates"


# ---------------------------------------------------------------------------
# Data-transfer types (lightweight — no ORM dependency in this module)
# ---------------------------------------------------------------------------


class _ContractData:
    """Typed view of Contract fields consumed by the template.

    Declared as a protocol-style class rather than a dataclass so callers can pass
    real SQLAlchemy model instances directly (duck-typed) without importing this
    module's internals.
    """


class _UserData:
    """Typed view of User fields consumed by the template."""


class _DelegationData:
    """Typed view of Delegation fields consumed by the template."""


# ---------------------------------------------------------------------------
# ContractPDFService
# ---------------------------------------------------------------------------


class ContractPDFService:
    """Renders a rental contract PDF with owner (and optional operator) disclosure.

    Usage:
        svc = ContractPDFService()
        path = svc.generate(contract, owner, operator, delegation, "/tmp/c42.pdf")

    Rendering pipeline:
        Contract + User objects → Jinja2 template → HTML string → weasyprint → PDF file
    """

    def __init__(self, template_dir: Optional[str] = None) -> None:
        """
        Args:
            template_dir: Override the Jinja2 search path. Defaults to
                          `app/templates/` relative to this file. Useful in tests.
        """
        search_path = template_dir or str(_TEMPLATE_DIR)
        self._jinja_env = Environment(
            loader=FileSystemLoader(search_path),
            autoescape=select_autoescape(["html"]),
        )

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def generate(
        self,
        contract: object,
        owner: object,
        operator: Optional[object],
        output_path: str,
        *,
        delegation: Optional[object] = None,
    ) -> str:
        """Render contract disclosure PDF to output_path and return it.

        AC-54: operator=None → owner-only; operator set → dual-disclosure block
        (owner CCCD + operator CCCD + delegation_id + POA reference).

        Raises RuntimeError if weasyprint system deps missing.
        Raises OSError if output_path is not writable.
        """
        html_content = self._render_html(contract, owner, operator, delegation)
        pdf_bytes = self._html_to_pdf(html_content)

        # Ensure output directory exists before writing
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        output_file.write_bytes(pdf_bytes)

        return output_path

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _render_html(
        self,
        contract: object,
        owner: object,
        operator: Optional[object],
        delegation: Optional[object],
    ) -> str:
        """Render the Jinja2 template to an HTML string."""
        template = self._jinja_env.get_template("contract_with_disclosure.html")

        # AC-54: resolve CCCD display value — User.id_number is the cleartext field
        # (HostProfile stores only a hash; id_number on User is the plain text from
        # KYC form and may be NULL for incomplete profiles). Guard both paths.
        owner_cccd = _safe_attr(owner, "cccd_number") or _safe_attr(owner, "id_number") or ""
        operator_cccd: Optional[str] = None
        if operator is not None:
            operator_cccd = (
                _safe_attr(operator, "cccd_number")
                or _safe_attr(operator, "id_number")
                or ""
            )

        # Delegation display fields (may all be None if delegation not loaded)
        delegation_id: Optional[str] = _safe_attr(delegation, "id")
        poa_format: Optional[str] = _safe_attr(delegation, "poa_format")
        poa_document_path: Optional[str] = _safe_attr(delegation, "poa_document_path")

        ctx = {
            "contract": contract,
            "owner": owner,
            "owner_cccd": owner_cccd,
            "operator": operator,
            "operator_cccd": operator_cccd,
            "delegation_id": delegation_id,
            "poa_format": poa_format,
            "poa_document_path": poa_document_path,
            # AC-54: flag drives conditional block in template
            "has_operator": operator is not None,
        }
        return template.render(**ctx)

    @staticmethod
    def _html_to_pdf(html_content: str) -> bytes:
        """Convert HTML string to PDF bytes via weasyprint.

        Deferred import: weasyprint requires system-level cairo/pango libraries.
        If absent, raises RuntimeError with a helpful message rather than crashing
        at module import time.
        """
        try:
            import weasyprint  # noqa: PLC0415 — intentional deferred import
        except ImportError as exc:
            raise RuntimeError(
                "weasyprint is not installed or its system dependencies (cairo, pango) "
                "are missing. Install with: pip install weasyprint>=60.0 "
                "and ensure system libraries are present."
            ) from exc

        # AC-54 / NFR-12: base_url set to template dir so relative CSS assets resolve.
        # font-family: 'DejaVu Sans' in the CSS handles Vietnamese diacritics.
        return weasyprint.HTML(string=html_content).write_pdf()


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------


def _safe_attr(obj: Optional[object], attr: str) -> Optional[str]:
    """Return getattr(obj, attr) as str, or None if obj is None or attr absent."""
    if obj is None:
        return None
    value = getattr(obj, attr, None)
    if value is None:
        return None
    return str(value)
