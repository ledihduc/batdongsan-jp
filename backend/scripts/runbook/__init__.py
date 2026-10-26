"""CLI runbook scripts for Owner-Operator Delegation admin operations — Phase 10.

Scripts:
  process_death_cert_queue.py   — list/process pending death certificates (US-A7)
  kyc_review_queue.py           — list/process pending KYC submissions (US-A3)
  fraud_alert_review.py         — list 24h-window fraud reports (US-A5 / AC-45)
  pdpl_retention_audit.py       — PDPL tier counts + dry-run transitions (AC-59)
  delegation_health_check.py    — at-risk delegations dashboard (AC-09/50)

Usage:
  python -m scripts.runbook.<script_name> [--dry-run | --apply]

All scripts:
  - Use app.database.SessionLocal for DB connection (same as FastAPI app).
  - Log human-readable output to stderr.
  - Print JSON summary to stdout for piping.
  - Default to --dry-run (no mutations without explicit --apply).
  - NEVER prompt for credentials.
"""
