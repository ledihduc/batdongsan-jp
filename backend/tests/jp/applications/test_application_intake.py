"""Tests for JP application intake service — status transitions.

Uses mock repositories — no DB connection required.
"""

from __future__ import annotations

import os
from datetime import datetime
from decimal import Decimal
from unittest.mock import MagicMock

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("REGION", "jp")

import pytest
from fastapi import HTTPException

from app.services.jp.application.intake import (
    record_review_decision,
    start_review,
    submit_application,
)


def _make_app(**kwargs):
    """Create a mock JpTenantApplication."""
    app = MagicMock()
    app.id = kwargs.get("id", 1)
    app.org_id = kwargs.get("org_id", "org-001")
    app.listing_id = kwargs.get("listing_id", "listing-001")
    app.applicant_user_id = kwargs.get("applicant_user_id", 42)
    app.status = kwargs.get("status", "draft")
    app.submitted_at = kwargs.get("submitted_at", None)
    return app


class TestSubmitApplication:
    """Tests for the draft → submitted transition."""

    def test_applicant_can_submit_own_draft(self) -> None:
        app = _make_app(status="draft", applicant_user_id=42)
        mock_repo = MagicMock()
        mock_repo.update_status.return_value = app

        result = submit_application(mock_repo, app=app, actor_user_id=42)
        mock_repo.update_status.assert_called_once()
        call_kwargs = mock_repo.update_status.call_args.kwargs
        assert call_kwargs["status"] == "submitted"

    def test_non_applicant_cannot_submit(self) -> None:
        app = _make_app(status="draft", applicant_user_id=42)
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            submit_application(mock_repo, app=app, actor_user_id=99)
        assert exc_info.value.status_code == 403

    def test_already_submitted_cannot_submit_again(self) -> None:
        app = _make_app(status="submitted", applicant_user_id=42)
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            submit_application(mock_repo, app=app, actor_user_id=42)
        assert exc_info.value.status_code == 400
        assert "submitted" in str(exc_info.value.detail)

    def test_approved_cannot_be_submitted(self) -> None:
        app = _make_app(status="approved", applicant_user_id=42)
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            submit_application(mock_repo, app=app, actor_user_id=42)
        assert exc_info.value.status_code == 400


class TestStartReview:
    """Tests for the submitted → in_review transition."""

    def test_reviewer_starts_review(self) -> None:
        app = _make_app(status="submitted", org_id="org-001")
        mock_repo = MagicMock()
        mock_repo.update_status.return_value = app

        start_review(mock_repo, app=app, reviewer_user_id=99, org_id="org-001")
        call_kwargs = mock_repo.update_status.call_args.kwargs
        assert call_kwargs["status"] == "in_review"

    def test_draft_cannot_go_to_in_review(self) -> None:
        app = _make_app(status="draft", org_id="org-001")
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            start_review(mock_repo, app=app, reviewer_user_id=99, org_id="org-001")
        assert exc_info.value.status_code == 400

    def test_wrong_org_rejected(self) -> None:
        app = _make_app(status="submitted", org_id="org-001")
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            start_review(mock_repo, app=app, reviewer_user_id=99, org_id="org-002")
        assert exc_info.value.status_code == 403


class TestRecordReviewDecision:
    """Tests for review decision recording — approved/rejected/needs_info."""

    def test_approve_decision(self) -> None:
        app = _make_app(status="in_review", org_id="org-001")
        mock_app_repo = MagicMock()
        mock_app_repo.update_status.return_value = app
        mock_review_repo = MagicMock()
        review = MagicMock()
        mock_review_repo.create.return_value = review

        updated_app, returned_review = record_review_decision(
            mock_app_repo,
            mock_review_repo,
            app=app,
            reviewer_user_id=99,
            org_id="org-001",
            decision="approved",
        )
        # Application status should be updated
        mock_app_repo.update_status.assert_called_once()
        call_kwargs = mock_app_repo.update_status.call_args.kwargs
        assert call_kwargs["status"] == "approved"
        assert returned_review == review

    def test_reject_decision(self) -> None:
        app = _make_app(status="in_review", org_id="org-001")
        mock_app_repo = MagicMock()
        mock_app_repo.update_status.return_value = app
        mock_review_repo = MagicMock()
        mock_review_repo.create.return_value = MagicMock()

        record_review_decision(
            mock_app_repo,
            mock_review_repo,
            app=app,
            reviewer_user_id=99,
            org_id="org-001",
            decision="rejected",
            notes="Income verification failed",
        )
        call_kwargs = mock_app_repo.update_status.call_args.kwargs
        assert call_kwargs["status"] == "rejected"

    def test_needs_info_does_not_change_app_status(self) -> None:
        """needs_info keeps application in in_review state."""
        app = _make_app(status="in_review", org_id="org-001")
        mock_app_repo = MagicMock()
        mock_review_repo = MagicMock()
        mock_review_repo.create.return_value = MagicMock()

        record_review_decision(
            mock_app_repo,
            mock_review_repo,
            app=app,
            reviewer_user_id=99,
            org_id="org-001",
            decision="needs_info",
        )
        # update_status should NOT be called for needs_info
        mock_app_repo.update_status.assert_not_called()

    def test_invalid_decision_rejected(self) -> None:
        app = _make_app(status="in_review", org_id="org-001")
        mock_app_repo = MagicMock()
        mock_review_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            record_review_decision(
                mock_app_repo,
                mock_review_repo,
                app=app,
                reviewer_user_id=99,
                org_id="org-001",
                decision="maybe",
            )
        assert exc_info.value.status_code == 422

    def test_draft_cannot_be_reviewed(self) -> None:
        app = _make_app(status="draft", org_id="org-001")
        mock_app_repo = MagicMock()
        mock_review_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            record_review_decision(
                mock_app_repo,
                mock_review_repo,
                app=app,
                reviewer_user_id=99,
                org_id="org-001",
                decision="approved",
            )
        assert exc_info.value.status_code == 400

    def test_wrong_org_rejected(self) -> None:
        app = _make_app(status="in_review", org_id="org-001")
        mock_app_repo = MagicMock()
        mock_review_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            record_review_decision(
                mock_app_repo,
                mock_review_repo,
                app=app,
                reviewer_user_id=99,
                org_id="org-002",  # wrong org
                decision="approved",
            )
        assert exc_info.value.status_code == 403
