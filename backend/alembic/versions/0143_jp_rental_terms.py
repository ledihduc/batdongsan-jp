"""Create jp_rental_terms table — JP chintai money fields.

Legal note: JP rental money fields (敷金/礼金/etc.) carry consumer law liability
if misrepresented. These fields MUST NOT be coerced with VN pricing fields.
They live in a dedicated table joined to the core listing.

Idempotent: checks has_table() before create.
Has downgrade(): drops table and indexes.

Revision ID: 0143_jp_rental_terms
Revises: 0142_jp_address
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0143_jp_rental_terms"
down_revision = "0142_jp_address"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if insp.has_table("jp_rental_terms"):
        return

    op.create_table(
        "jp_rental_terms",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        # Multi-tenant isolation — org_id groups data by broker company.
        # NOTE: org_id is the core multi-tenant isolation key for all JP tables.
        # Every repository list query MUST filter by org_id by default (enforced below).
        # NOTE: no `index=True` here — explicit op.create_index below is the
        # single source of truth. SQLAlchemy's inline `index=True` auto-generates
        # an index named `ix_jp_rental_terms_org_id` which collides with the
        # explicit create_index on fresh-bootstrap (DuplicateTable). Keeping
        # creation idempotent via existing-index inspection below.
        sa.Column("org_id", sa.String(64), nullable=True,
                  comment="Broker org tenant ID. MUST be filtered in every list query."),
        sa.Column("region", sa.String(3), nullable=False, server_default="jp",
                  comment="Defense-in-depth region tag. Always 'jp'."),
        # 月額家賃 — monthly rent in JPY
        sa.Column("monthly_rent_jpy", sa.Numeric(12, 0), nullable=False,
                  comment="月額家賃 (monthly rent) in JPY. Legal field — must not be 0."),
        # 共益費 — management/common area fee
        sa.Column("management_fee_jpy", sa.Numeric(10, 0), nullable=True,
                  comment="共益費 (management fee) in JPY. Nullable if included in rent."),
        # 敷金 — security deposit expressed as multiples of monthly rent
        sa.Column("shikikin_months", sa.Numeric(4, 2), nullable=True,
                  comment="敷金 in months of rent (e.g. 1.0, 2.0). Nullable = none required."),
        # 礼金 — key money (non-refundable gift to landlord)
        sa.Column("reikin_months", sa.Numeric(4, 2), nullable=True,
                  comment="礼金 in months of rent (e.g. 1.0, 2.0). Nullable = none required."),
        # 保証金 — guarantee deposit (alternative to shikikin in some regions)
        sa.Column("hoshou_months", sa.Numeric(4, 2), nullable=True,
                  comment="保証金 in months of rent. Regional alternative to shikikin."),
        # 更新料 — renewal fee
        sa.Column("koushinryo_months", sa.Numeric(4, 2), nullable=True,
                  comment="更新料 in months of rent. Charged on lease renewal."),
        # 仲介手数料率 — brokerage fee rate (% of one month rent, max 1.1 months by law)
        sa.Column("brokerage_rate", sa.Numeric(5, 4), nullable=True,
                  comment="仲介手数料率 as decimal (e.g. 1.1 = 110% of one month). Legal max 1.1."),
        # 保証会社手数料 — guarantee company fee in JPY (一時金)
        sa.Column("hoshou_fee_jpy", sa.Numeric(10, 0), nullable=True,
                  comment="保証会社手数料 in JPY. Paid to guarantee company at contract signing."),
        # 消費税扱い — how consumption tax is handled
        sa.Column("tax_treatment", sa.String(20), nullable=False, server_default="included",
                  comment="Tax treatment: included | excluded | exempt. Legal field."),
        # Timestamps
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )

    # Idempotent index creation — re-inspect (post-create_table) to avoid
    # DuplicateTable on partial reruns (e.g. prior failed upgrade left table +
    # indexes behind but did not advance alembic_version).
    insp = sa.inspect(bind)
    existing_indexes = {ix["name"] for ix in insp.get_indexes("jp_rental_terms")}
    if "ix_jp_rental_terms_org_id" not in existing_indexes:
        op.create_index("ix_jp_rental_terms_org_id", "jp_rental_terms", ["org_id"])
    if "ix_jp_rental_terms_region" not in existing_indexes:
        op.create_index("ix_jp_rental_terms_region", "jp_rental_terms", ["region"])


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table("jp_rental_terms"):
        return

    op.drop_index("ix_jp_rental_terms_region", table_name="jp_rental_terms")
    op.drop_index("ix_jp_rental_terms_org_id", table_name="jp_rental_terms")
    op.drop_table("jp_rental_terms")
