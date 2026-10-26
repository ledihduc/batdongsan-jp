"""Tests for user deletion cron — soft-anonymization logic.

Tests the anonymization helpers. Cron scheduling is integration-level.
"""

from __future__ import annotations

import pytest


class TestAnonymizeEmail:
    """Tests for deletion_cron._anonymize_email()."""

    def test_produces_unique_results(self):
        from app.services.privacy.deletion_cron import _anonymize_email

        email = "test@example.com"
        a1 = _anonymize_email(email)
        a2 = _anonymize_email(email)
        # Each call produces different salt → different hash
        assert a1 != a2

    def test_output_ends_with_suffix(self):
        from app.services.privacy.deletion_cron import _anonymize_email, _ANON_EMAIL_SUFFIX

        result = _anonymize_email("user@domain.com")
        assert result.endswith(_ANON_EMAIL_SUFFIX)

    def test_output_starts_with_anon(self):
        from app.services.privacy.deletion_cron import _anonymize_email

        result = _anonymize_email("user@domain.com")
        assert result.startswith("anon-")

    def test_original_email_not_in_output(self):
        from app.services.privacy.deletion_cron import _anonymize_email

        original = "very.specific.user@company.co.jp"
        result = _anonymize_email(original)
        assert "very.specific.user" not in result
        assert "company.co.jp" not in result

    def test_empty_email_still_produces_output(self):
        from app.services.privacy.deletion_cron import _anonymize_email

        result = _anonymize_email("")
        assert result.startswith("anon-")


class TestDeletionCronStart:
    """Tests that start_deletion_cron() registers the job correctly."""

    def test_registers_job_with_scheduler(self):
        from app.services.privacy.deletion_cron import start_deletion_cron

        mock_scheduler = type("Scheduler", (), {"add_job": lambda self, *a, **kw: None})()
        calls = []

        def record_add_job(*args, **kwargs):
            calls.append((args, kwargs))

        mock_scheduler.add_job = record_add_job

        start_deletion_cron(mock_scheduler)
        assert len(calls) == 1
        _, kwargs = calls[0]
        assert kwargs["id"] == "jp_deletion_daily"
        assert kwargs["replace_existing"] is True
        assert kwargs["misfire_grace_time"] == 3600
