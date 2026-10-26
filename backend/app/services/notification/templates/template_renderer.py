"""Jinja2 template renderer for notification content.

Resolves template from the templates/ directory using naming convention:
    {notification_type}.{channel}.{lang}.j2

Falls back: lang 'en' → 'vi' if English template is missing.
Falls back: channel 'sms' → inline minimal content if template missing.

Security: HTML channel uses autoescape=True to prevent XSS in email bodies.
SMS channel uses autoescape=False (SMS is plain text — no HTML injection risk).
"""

from __future__ import annotations

import logging
import os
from functools import lru_cache

from jinja2 import (
    Environment,
    FileSystemLoader,
    TemplateNotFound,
    select_autoescape,
)

logger = logging.getLogger(__name__)

_TEMPLATES_DIR = os.path.dirname(__file__)


@lru_cache(maxsize=1)
def _get_html_env() -> Environment:
    """HTML Jinja2 environment with autoescape — used for email bodies."""
    return Environment(
        loader=FileSystemLoader(_TEMPLATES_DIR),
        autoescape=select_autoescape(["html", "j2"]),
        trim_blocks=True,
        lstrip_blocks=True,
    )


@lru_cache(maxsize=1)
def _get_text_env() -> Environment:
    """Plain text Jinja2 environment — used for SMS and plain-text email."""
    return Environment(
        loader=FileSystemLoader(_TEMPLATES_DIR),
        autoescape=False,
        trim_blocks=True,
        lstrip_blocks=True,
    )


def render_email_subject(notification_type: str, context: dict, lang: str = "vi") -> str:
    """Render the email subject line from a minimal inline template map.

    Subjects are NOT loaded from .j2 files to keep them short and controllable.
    NEVER include PII in subjects (visible in lock-screen notifications).
    """
    subjects_vi: dict[str, str] = {
        "delegation_invited": "[ancu365] Bạn được mời làm Operator",
        "delegation_accepted": "[ancu365] Operator đã chấp nhận ủy thác",
        "delegation_paused": "[ancu365] Ủy thác tạm dừng",
        "delegation_terminated": "[ancu365] Ủy thác đã kết thúc",
        "approval_requested": "[ancu365] Cần phê duyệt",
        "approval_decided": "[ancu365] Phê duyệt đã có kết quả",
        "kyc_expiring_soon": "[ancu365] KYC sắp hết hạn",
        "owner_death_delegation_paused": "[ancu365] Ủy thác tạm dừng - cần xử lý",
        "heir_onboarding_initiated": "[ancu365] Bắt đầu quy trình thừa kế",
        "gpkd_revoked_delegation_paused": "[ancu365] GPKD hết hạn - ủy thác tạm dừng",
        "weekly_digest": "[ancu365] Tổng kết tuần",
        "approval_reminder_24h": "[ancu365] Nhắc nhở: Cần phê duyệt (24h)",
        "approval_reminder_48h": "[ancu365] Nhắc nhở cuối: Cần phê duyệt (48h)",
        "approval_auto_rejected": "[ancu365] Yêu cầu đã bị từ chối tự động (72h)",
    }
    subjects_en: dict[str, str] = {
        "delegation_invited": "[ancu365] You are invited as an Operator",
        "delegation_accepted": "[ancu365] Operator accepted the delegation",
        "delegation_paused": "[ancu365] Delegation paused",
        "delegation_terminated": "[ancu365] Delegation terminated",
        "approval_requested": "[ancu365] Approval required",
        "approval_decided": "[ancu365] Approval decision made",
        "kyc_expiring_soon": "[ancu365] KYC expiring soon",
        "owner_death_delegation_paused": "[ancu365] Delegation paused - action required",
        "heir_onboarding_initiated": "[ancu365] Heir onboarding initiated",
        "gpkd_revoked_delegation_paused": "[ancu365] Business license expired - delegation paused",
        "weekly_digest": "[ancu365] Weekly digest",
        "approval_reminder_24h": "[ancu365] Reminder: Approval needed (24h)",
        "approval_reminder_48h": "[ancu365] Final reminder: Approval needed (48h)",
        "approval_auto_rejected": "[ancu365] Request auto-rejected (72h)",
    }
    subjects = subjects_vi if lang == "vi" else subjects_en
    # High-value approvals get a prefix for urgency (NFR-14)
    subject = subjects.get(notification_type, "[ancu365] Thông báo")
    amount = context.get("monthly_rent_vnd", 0)
    if notification_type.startswith("approval") and isinstance(amount, (int, float)) and amount >= 20_000_000:
        subject = "QUAN TRỌNG: " + subject
    return subject


def render_template(
    notification_type: str,
    channel: str,
    context: dict,
    lang: str = "vi",
) -> str:
    """Render a notification template to string.

    Args:
        notification_type: e.g. 'approval_requested'
        channel: 'email' | 'sms'
        context: template variables (must never include full CCCD)
        lang: 'vi' | 'en'

    Returns:
        Rendered string. Falls back to minimal inline content on TemplateNotFound.
    """
    env = _get_html_env() if channel == "email" else _get_text_env()
    template_name = f"{notification_type}.{channel}.{lang}.j2"

    try:
        tmpl = env.get_template(template_name)
        return tmpl.render(**context)
    except TemplateNotFound:
        # Try fallback language
        if lang != "vi":
            fallback_name = f"{notification_type}.{channel}.vi.j2"
            try:
                tmpl = env.get_template(fallback_name)
                logger.debug("Template %s not found, using vi fallback", template_name)
                return tmpl.render(**context)
            except TemplateNotFound:
                pass

        logger.warning(
            "Template %s not found — using inline fallback content", template_name
        )
        return _inline_fallback(notification_type, channel, context, lang)


def _inline_fallback(
    notification_type: str, channel: str, context: dict, lang: str
) -> str:
    """Minimal inline fallback when template file is missing.

    This ensures notifications are never silently dropped — a minimal message
    is always better than no message.
    """
    title = context.get("title", notification_type.replace("_", " ").title())
    body = context.get("body", "")
    app_url = context.get("app_url", "https://ancu365.com")

    if channel == "sms":
        if lang == "vi":
            return f"[ancu365] {title}. {body} Xem app: {app_url}"
        return f"[ancu365] {title}. {body} See app: {app_url}"
    else:
        # email — minimal HTML
        if lang == "vi":
            return (
                f"<p>{title}</p><p>{body}</p>"
                f'<p><a href="{app_url}">Mở ứng dụng ancu365</a></p>'
            )
        return (
            f"<p>{title}</p><p>{body}</p>"
            f'<p><a href="{app_url}">Open ancu365 app</a></p>'
        )
