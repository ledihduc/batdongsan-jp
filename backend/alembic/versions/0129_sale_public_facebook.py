"""Add a validated public Facebook link for seller landing pages.

Revision ID: 0129_sale_public_facebook
Revises: 0128_buy_sell_transaction_v2
"""

import sqlalchemy as sa
from alembic import op

revision = "0129_sale_public_facebook"
down_revision = "0128_buy_sell_transaction_v2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "host_profiles", sa.Column("facebook", sa.String(500), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("host_profiles", "facebook")
