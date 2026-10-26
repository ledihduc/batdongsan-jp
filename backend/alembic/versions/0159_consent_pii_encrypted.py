"""Add encrypted PII columns to jp_user_consents — Fernet at-rest encryption.

Adds ip_address_encrypted BYTEA and user_agent_encrypted BYTEA columns.
Backfills from existing plaintext columns (batched 1000 rows).
Plaintext columns kept for 1 release (drop in P4).

Idempotent: inspects before adding.
Has downgrade(): drops encrypted columns.

Revision ID: 0159_consent_pii_encrypted
Revises: 0158_users_deletion_scheduled
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

revision = "0159_consent_pii_encrypted"
down_revision = "0158_users_deletion_scheduled"
branch_labels = None
depends_on = None

_BATCH_SIZE = 1000


def upgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)

    if not insp.has_table("jp_user_consents"):
        return

    existing_cols = {c["name"] for c in insp.get_columns("jp_user_consents")}

    if "ip_address_encrypted" not in existing_cols:
        op.add_column(
            "jp_user_consents",
            sa.Column(
                "ip_address_encrypted",
                sa.LargeBinary(),
                nullable=True,
                comment="Fernet-encrypted ip_address. Replaces plaintext ip_address in P4.",
            ),
        )

    if "user_agent_encrypted" not in existing_cols:
        op.add_column(
            "jp_user_consents",
            sa.Column(
                "user_agent_encrypted",
                sa.LargeBinary(),
                nullable=True,
                comment="Fernet-encrypted user_agent. Replaces plaintext user_agent in P4.",
            ),
        )

    # Backfill: encrypt existing plaintext values in batches of 1000
    # Import crypto lazily to avoid mapper config issues during migration
    try:
        from app.services.crypto import _get_fernet
        fernet = _get_fernet()

        # Get all rows with plaintext data that need backfilling
        result = bind.execute(
            text(
                "SELECT id, ip_address, user_agent FROM jp_user_consents "
                "WHERE (ip_address IS NOT NULL OR user_agent IS NOT NULL) "
                "AND ip_address_encrypted IS NULL "
                "ORDER BY id"
            )
        )
        rows = result.fetchall()

        total = len(rows)
        processed = 0
        for i in range(0, total, _BATCH_SIZE):
            batch = rows[i : i + _BATCH_SIZE]
            for row in batch:
                row_id, ip_addr, user_agent = row[0], row[1], row[2]
                ip_enc = fernet.encrypt(ip_addr.encode("utf-8")) if ip_addr else None
                ua_enc = fernet.encrypt(user_agent.encode("utf-8")) if user_agent else None
                bind.execute(
                    text(
                        "UPDATE jp_user_consents SET "
                        "ip_address_encrypted = :ip_enc, "
                        "user_agent_encrypted = :ua_enc "
                        "WHERE id = :row_id"
                    ),
                    {"ip_enc": ip_enc, "ua_enc": ua_enc, "row_id": row_id},
                )
            processed += len(batch)
            import logging
            logging.getLogger(__name__).info(
                "Consent PII backfill: %d/%d rows encrypted", processed, total
            )

    except Exception as exc:
        # If crypto not available (e.g. during offline migration), log and skip backfill.
        # The consent_pii_encrypt service encrypts on next write.
        import logging
        logging.getLogger(__name__).warning(
            "Consent PII backfill skipped (crypto unavailable): %s", exc
        )


def downgrade() -> None:
    bind = op.get_bind()
    insp = sa.inspect(bind)
    if insp.has_table("jp_user_consents"):
        existing_cols = {c["name"] for c in insp.get_columns("jp_user_consents")}
        if "ip_address_encrypted" in existing_cols:
            op.drop_column("jp_user_consents", "ip_address_encrypted")
        if "user_agent_encrypted" in existing_cols:
            op.drop_column("jp_user_consents", "user_agent_encrypted")
