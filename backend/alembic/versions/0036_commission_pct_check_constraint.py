"""add CHECK constraints enforcing commission_pct fraction convention (0 < x <= 1)

Revision ID: 0036_commission_pct_check_constraint
Revises: 0035_extend_notifications_channels
Create Date: 2026-06-30

Enforces the fraction convention at the database layer:
  - delegations.commission_pct: NULL or in (0, 1]
  - delegation_invitations.proposed_commission_pct: NULL or in (0, 1]

These constraints match the production code in commission_snapshot.py which treats
commission_pct as a fraction (e.g. 0.05 = 5%), not a percentage (5.00 ≠ 5%).
"""

from alembic import op
from sqlalchemy import text

# revision identifiers, used by Alembic
revision = "0036_commission_pct_check_constraint"
down_revision = "0035_extend_notifications_channels"
branch_labels = None
depends_on = None


def _assert_no_out_of_range_rows() -> None:
    """Bail out if any pre-existing row violates the fraction convention.

    Pre-phase-11 fixtures used `commission_pct=Decimal("5.00")` (percent form)
    when the code already treated the value as a fraction (0.05 = 5%). That
    means rows with commission_pct > 1 are clearly the wrong unit and would
    compute commission = 500% of total at payment time.

    We refuse to apply the CHECK constraint until the operator inspects + fixes
    these rows manually. Auto-dividing by 100 is unsafe: a row stored as
    `0.50` is legitimately 50% in fraction form, not 0.5%.
    """
    bind = op.get_bind()

    bad_delegations = bind.execute(
        text(
            "SELECT id, commission_pct FROM delegations "
            "WHERE commission_pct IS NOT NULL "
            "AND (commission_pct <= 0 OR commission_pct > 1)"
        )
    ).fetchall()
    bad_invitations = bind.execute(
        text(
            "SELECT id, proposed_commission_pct FROM delegation_invitations "
            "WHERE proposed_commission_pct IS NOT NULL "
            "AND (proposed_commission_pct <= 0 OR proposed_commission_pct > 1)"
        )
    ).fetchall()

    if bad_delegations or bad_invitations:
        msg = [
            "Cannot apply CHECK constraint: existing rows violate the fraction convention.",
            "commission_pct must be a fraction in (0, 1]; values like 5.00 are the wrong unit.",
            "Fix these rows manually (e.g. 5.00 → 0.05) before re-running this migration:",
        ]
        for row in bad_delegations:
            msg.append(f"  delegations.id={row[0]} commission_pct={row[1]}")
        for row in bad_invitations:
            msg.append(
                f"  delegation_invitations.id={row[0]} proposed_commission_pct={row[1]}"
            )
        raise RuntimeError("\n".join(msg))


def upgrade() -> None:
    _assert_no_out_of_range_rows()

    op.create_check_constraint(
        "ck_delegations_commission_pct_fraction",
        "delegations",
        "commission_pct IS NULL OR (commission_pct > 0 AND commission_pct <= 1)",
    )
    op.create_check_constraint(
        "ck_delegation_invitations_proposed_commission_pct_fraction",
        "delegation_invitations",
        "proposed_commission_pct IS NULL OR (proposed_commission_pct > 0 AND proposed_commission_pct <= 1)",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_delegation_invitations_proposed_commission_pct_fraction",
        "delegation_invitations",
    )
    op.drop_constraint(
        "ck_delegations_commission_pct_fraction",
        "delegations",
    )
