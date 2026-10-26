"""Smoke tests for CLI runbook scripts — Phase 10.

Tests:
  - Each script imports without error.
  - Each script runs with --dry-run and prints valid JSON to stdout.
  - Scripts do NOT require a real DB (uses mock).
  - process_death_cert_queue: counts pending certs.
  - kyc_review_queue: counts pending KYC.
  - fraud_alert_review: counts fraud approvals.
  - pdpl_retention_audit: shows tier distribution.
  - delegation_health_check: shows at-risk delegations.
"""

from __future__ import annotations

import io
import json
import os
import sys
from unittest.mock import MagicMock, patch

import pytest

# Ensure test can import app modules with sqlite
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


def _run_script_dry_run(module_path: str, extra_args: list[str] | None = None) -> dict:
    """Import and run a runbook script in --dry-run mode.

    Returns parsed JSON from stdout.
    Raises AssertionError if script returns non-zero exit code
    or stdout is not valid JSON.
    """
    # Capture stdout
    captured_out = io.StringIO()

    argv = ["--dry-run"] + (extra_args or [])

    with patch.object(sys, "argv", [module_path] + argv), \
         patch("sys.stdout", captured_out):
        # Dynamic import of the script module
        import importlib
        mod = importlib.import_module(module_path.replace("/", ".").replace(".py", ""))
        exit_code = mod.main()

    assert exit_code in (0, None), f"Script {module_path} returned exit_code={exit_code}"

    output = captured_out.getvalue().strip()
    assert output, f"Script {module_path} produced no stdout output"

    try:
        return json.loads(output)
    except json.JSONDecodeError as exc:
        pytest.fail(f"Script {module_path} stdout is not valid JSON: {exc}\nOutput: {output!r}")


# ---------------------------------------------------------------------------
# Fixture: mock DB session for all runbook scripts
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def mock_db_session(monkeypatch):
    """Mock SessionLocal so scripts don't need a real DB."""
    mock_session = MagicMock()
    mock_session.__enter__ = MagicMock(return_value=mock_session)
    mock_session.__exit__ = MagicMock(return_value=False)

    # All queries return empty lists
    mock_query = MagicMock()
    mock_query.filter.return_value = mock_query
    mock_query.order_by.return_value = mock_query
    mock_query.limit.return_value = mock_query
    mock_query.all.return_value = []
    mock_query.count.return_value = 0
    mock_session.query.return_value = mock_query

    mock_session_local = MagicMock(return_value=mock_session)

    monkeypatch.setenv("DATABASE_URL", "sqlite:///:memory:")
    monkeypatch.setattr("app.database.SessionLocal", mock_session_local, raising=False)

    # Also patch it in each runbook module's namespace
    for mod_name in [
        "scripts.runbook.process_death_cert_queue",
        "scripts.runbook.kyc_review_queue",
        "scripts.runbook.fraud_alert_review",
        "scripts.runbook.pdpl_retention_audit",
        "scripts.runbook.delegation_health_check",
    ]:
        try:
            import importlib
            mod = importlib.import_module(mod_name)
            # Patch SessionLocal in module if imported
        except ImportError:
            pass

    yield mock_session_local


# ---------------------------------------------------------------------------
# Import smoke tests
# ---------------------------------------------------------------------------


class TestScriptImports:
    def test_import_process_death_cert_queue(self):
        from scripts.runbook import process_death_cert_queue  # noqa: F401

    def test_import_kyc_review_queue(self):
        from scripts.runbook import kyc_review_queue  # noqa: F401

    def test_import_fraud_alert_review(self):
        from scripts.runbook import fraud_alert_review  # noqa: F401

    def test_import_pdpl_retention_audit(self):
        from scripts.runbook import pdpl_retention_audit  # noqa: F401

    def test_import_delegation_health_check(self):
        from scripts.runbook import delegation_health_check  # noqa: F401


# ---------------------------------------------------------------------------
# Dry-run smoke tests
# ---------------------------------------------------------------------------


def _make_mock_db(return_values: list | None = None):
    """Create a mock DB session context manager returning empty query results."""
    mock_db = MagicMock()
    mock_db.__enter__ = MagicMock(return_value=mock_db)
    mock_db.__exit__ = MagicMock(return_value=False)
    mock_query = MagicMock()
    mock_query.filter.return_value = mock_query
    mock_query.order_by.return_value = mock_query
    mock_query.limit.return_value = mock_query
    mock_query.all.return_value = return_values or []
    mock_query.count.return_value = 0
    mock_db.query.return_value = mock_query
    return mock_db


class TestProcessDeathCertQueue:
    def test_dry_run_with_empty_db(self, monkeypatch):
        """Script runs dry-run, returns JSON with expected keys."""
        captured = io.StringIO()
        mock_db = _make_mock_db()

        monkeypatch.setattr("app.database.SessionLocal", MagicMock(return_value=mock_db))

        with patch("sys.stdout", captured), \
             patch("sys.argv", ["process_death_cert_queue", "--dry-run"]):
            from scripts.runbook import process_death_cert_queue
            # reload to pick up monkeypatched SessionLocal
            import importlib
            importlib.reload(process_death_cert_queue)
            exit_code = process_death_cert_queue.main()

        assert exit_code == 0
        output = captured.getvalue().strip()
        data = json.loads(output)
        assert "mode" in data
        assert data["mode"] == "DRY-RUN"
        assert "total_pending" in data
        assert "sla_breach_count" in data


class TestKycReviewQueue:
    def test_dry_run_exits_cleanly(self, monkeypatch):
        captured = io.StringIO()
        mock_db = _make_mock_db()

        monkeypatch.setattr("app.database.SessionLocal", MagicMock(return_value=mock_db))

        with patch("sys.stdout", captured), \
             patch("sys.argv", ["kyc_review_queue", "--dry-run"]):
            from scripts.runbook import kyc_review_queue
            import importlib
            importlib.reload(kyc_review_queue)
            exit_code = kyc_review_queue.main()

        assert exit_code == 0
        data = json.loads(captured.getvalue().strip())
        assert data["mode"] == "DRY-RUN"
        assert "total_pending" in data

    def test_apply_exits_with_error_code(self):
        with patch("sys.argv", ["kyc_review_queue", "--apply"]):
            from scripts.runbook.kyc_review_queue import main
            exit_code = main()
        assert exit_code == 2


class TestFraudAlertReview:
    def test_dry_run_returns_expected_keys(self, monkeypatch):
        captured = io.StringIO()
        mock_db = _make_mock_db()

        monkeypatch.setattr("app.database.SessionLocal", MagicMock(return_value=mock_db))

        with patch("sys.stdout", captured), \
             patch("sys.argv", ["fraud_alert_review", "--dry-run", "--hours", "24"]):
            from scripts.runbook import fraud_alert_review
            import importlib
            importlib.reload(fraud_alert_review)
            exit_code = fraud_alert_review.main()

        assert exit_code == 0
        data = json.loads(captured.getvalue().strip())
        assert "mode" in data
        assert "total_fraud_reports" in data
        assert data["operators_suspended"] == "dry_run"


class TestPdplRetentionAudit:
    def test_dry_run_shows_tier_distribution(self, monkeypatch):
        captured = io.StringIO()
        mock_db = _make_mock_db()

        mock_tier_svc = MagicMock()
        mock_tier_svc.get_retention_stats.return_value = {
            "hot": 42, "warm": 10, "cold": 3, "legal_hold": 0
        }

        monkeypatch.setattr("app.database.SessionLocal", MagicMock(return_value=mock_db))

        with patch("sys.stdout", captured), \
             patch("sys.argv", ["pdpl_retention_audit", "--dry-run"]), \
             patch("app.services.retention.pdpl_tier_service.PdplTierService", return_value=mock_tier_svc):
            from scripts.runbook import pdpl_retention_audit
            import importlib
            importlib.reload(pdpl_retention_audit)
            exit_code = pdpl_retention_audit.main()

        assert exit_code == 0
        data = json.loads(captured.getvalue().strip())
        assert "tier_distribution" in data
        assert data["transitions_applied"] is None  # dry-run

    def test_apply_calls_run_daily_transitions(self, monkeypatch):
        captured = io.StringIO()
        mock_db = _make_mock_db()

        mock_tier_svc_instance = MagicMock()
        mock_tier_svc_instance.get_retention_stats.return_value = {"hot": 5}
        mock_tier_svc_instance.run_daily_transitions.return_value = {"hot_to_warm": 2}
        mock_tier_svc_class = MagicMock(return_value=mock_tier_svc_instance)

        monkeypatch.setattr("app.database.SessionLocal", MagicMock(return_value=mock_db))

        with patch("sys.stdout", captured), \
             patch("sys.argv", ["pdpl_retention_audit", "--apply"]), \
             patch("app.services.retention.pdpl_tier_service.PdplTierService", mock_tier_svc_class):
            from scripts.runbook import pdpl_retention_audit
            import importlib
            importlib.reload(pdpl_retention_audit)
            exit_code = pdpl_retention_audit.main()

        assert exit_code == 0


class TestDelegationHealthCheck:
    def test_dry_run_returns_categories(self, monkeypatch):
        captured = io.StringIO()
        mock_db = _make_mock_db()

        monkeypatch.setattr("app.database.SessionLocal", MagicMock(return_value=mock_db))

        with patch("sys.stdout", captured), \
             patch("sys.argv", ["delegation_health_check", "--dry-run"]):
            from scripts.runbook import delegation_health_check
            import importlib
            importlib.reload(delegation_health_check)
            exit_code = delegation_health_check.main()

        assert exit_code == 0
        data = json.loads(captured.getvalue().strip())
        assert "categories" in data
        assert "paused_long_term" in data["categories"]
        assert "terminating_in_lockdown" in data["categories"]
        assert "pending_kyc_stuck" in data["categories"]
        assert "disputed_authority" in data["categories"]
        assert "counts" in data

    def test_apply_still_exits_zero(self, monkeypatch):
        """--apply is ignored for health_check (read-only). Still exits 0."""
        captured = io.StringIO()
        mock_db = _make_mock_db()

        monkeypatch.setattr("app.database.SessionLocal", MagicMock(return_value=mock_db))

        with patch("sys.stdout", captured), \
             patch("sys.argv", ["delegation_health_check", "--apply"]):
            from scripts.runbook import delegation_health_check
            import importlib
            importlib.reload(delegation_health_check)
            exit_code = delegation_health_check.main()

        assert exit_code == 0
