"""Zalo deep-link builder.

Zalo accepts `zalo.me/{phone}?body=...` for chat deep-link. We normalise phone
to `+84` format and URL-encode the message.
"""

from __future__ import annotations

from urllib.parse import quote


def normalize_vn_phone(phone: str) -> str:
    """Convert any Vietnamese phone format to '+84XXXXXXXXX'."""
    p = phone.strip().replace(" ", "").replace("-", "").replace(".", "")
    if p.startswith("+84"):
        return p
    if p.startswith("84"):
        return "+" + p
    if p.startswith("0"):
        return "+84" + p[1:]
    return "+84" + p


def build_zalo_share_link(phone: str, message: str) -> str:
    """Return a `zalo.me/{phone}?body=...` deep-link string."""
    norm = normalize_vn_phone(phone)
    return f"https://zalo.me/{norm}?body={quote(message)}"


# ── Template messages (Phase 06) ────────────────────────────────────────────


def _fmt_vnd(amount: float) -> str:
    """Format 12345678.0 → '12.345.678 VND' (Vietnamese thousands separator)."""
    return f"{int(round(amount)):,}".replace(",", ".") + " VND"


def template_invoice_reminder(
    tenant_name: str,
    amount: float,
    due_date: str,
    public_link: str = "",
) -> str:
    """Polite Vietnamese reminder host can send via Zalo for an unpaid invoice."""
    msg = (
        f"Anh/chị {tenant_name}, hoá đơn tháng này: {_fmt_vnd(amount)}, "
        f"hạn {due_date}."
    )
    if public_link:
        msg += f" Xem chi tiết: {public_link}"
    return msg


def template_contract_expiring(tenant_name: str, end_date: str) -> str:
    """Nudge tenant about an upcoming contract end-date."""
    return (
        f"Anh/chị {tenant_name}, hợp đồng thuê hết hạn {end_date}. "
        f"Báo lại nếu gia hạn nhé."
    )


def template_khai_bao_reminder(tenant_name: str, public_link: str) -> str:
    """Ask tenant to complete the temporary residence declaration form."""
    return (
        f"Anh/chị {tenant_name}, vui lòng khai báo tạm trú trong vòng 12h "
        f"theo Nghị định 144/2021. Phiếu khai báo: {public_link}"
    )
