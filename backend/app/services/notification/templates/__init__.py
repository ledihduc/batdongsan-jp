"""Jinja2 notification templates — email + SMS, Vietnamese + English.

Template naming convention:
    {notification_type}.{channel}.{lang}.j2

Channels: email, sms
Languages: vi (primary), en (fallback)

Example: approval_requested.email.vi.j2

Security: templates use auto-escaping in email HTML context.
NEVER include full CCCD or unmasked PII in templates.
"""
