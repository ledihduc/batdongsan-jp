"""Scope sale links to buildings; preserve ambiguous legacy links as NULL.

Backfill only active links with exactly one matching building, or a sole owned
building with no sale assigned. Never guess between buildings or overwrite an
existing scoped link. Upgrade is idempotent. Downgrade retains every history
row and keeps the lowest-id active link per owner, ending the others before
restoring owner uniqueness. Building and room assignments are left intact.

Revision ID: 0102_building_sale_links
Revises: 0101_hang_doi_push
"""

from alembic import op
import sqlalchemy as sa

revision = "0102_building_sale_links"
down_revision = "0101_hang_doi_push"
branch_labels = None
depends_on = None

_TABLE = "sale_owner_links"
_FK = "fk_sale_owner_links_building_id"
_INDEX = "ix_sale_owner_links_building_id"
_UNIQUE = "uq_sale_owner_links_building_active"
_OLD_UNIQUE = "uq_sale_owner_links_owner_active"


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if "building_id" not in {c["name"] for c in inspector.get_columns(_TABLE)}:
        op.add_column(_TABLE, sa.Column("building_id", sa.Integer(), nullable=True))
    if not any(
        fk["constrained_columns"] == ["building_id"]
        for fk in sa.inspect(bind).get_foreign_keys(_TABLE)
    ):
        with op.batch_alter_table(_TABLE) as batch:
            batch.create_foreign_key(
                _FK, "buildings", ["building_id"], ["id"], ondelete="CASCADE"
            )

    indexes = {i["name"] for i in sa.inspect(bind).get_indexes(_TABLE)}
    if _INDEX not in indexes:
        op.create_index(_INDEX, _TABLE, ["building_id"])

    # Calculate all candidates before mutating: conflicting candidates remain
    # unscoped too, including on databases that already lack the old index.
    links = (
        bind.execute(
            sa.text(
                "SELECT id, owner_id, sale_id FROM sale_owner_links "
                "WHERE building_id IS NULL AND status = 'active'"
            )
        )
        .mappings()
        .all()
    )
    candidates: dict[int, list[dict]] = {}
    for link in links:
        buildings = (
            bind.execute(
                sa.text("SELECT id, sale_id FROM buildings WHERE host_id = :owner_id"),
                {"owner_id": link["owner_id"]},
            )
            .mappings()
            .all()
        )
        matching = [b for b in buildings if b["sale_id"] == link["sale_id"]]
        if len(matching) == 1:
            target = matching[0]["id"]
        elif len(buildings) == 1 and buildings[0]["sale_id"] is None:
            target = buildings[0]["id"]
        else:
            continue
        candidates.setdefault(target, []).append(link)

    for building_id, matches in candidates.items():
        if len(matches) != 1:
            continue
        if bind.execute(
            sa.text(
                "SELECT id FROM sale_owner_links WHERE building_id = :building_id "
                "AND status = 'active'"
            ),
            {"building_id": building_id},
        ).first():
            continue
        link = matches[0]
        params = {"building_id": building_id, "id": link["id"], "sale_id": link["sale_id"]}
        bind.execute(
            sa.text("UPDATE sale_owner_links SET building_id = :building_id WHERE id = :id"),
            params,
        )
        bind.execute(
            sa.text("UPDATE buildings SET sale_id = :sale_id WHERE id = :building_id"), params
        )
        bind.execute(
            sa.text(
                "UPDATE rooms SET managed_by_sale_id = :sale_id WHERE building_id = :building_id"
            ),
            params,
        )

    # Install the new invariant before removing the old one.
    if _UNIQUE not in indexes:
        op.create_index(
            _UNIQUE,
            _TABLE,
            ["building_id"],
            unique=True,
            postgresql_where=sa.text("status = 'active'"),
            sqlite_where=sa.text("status = 'active'"),
        )
    if _OLD_UNIQUE in indexes:
        op.drop_index(_OLD_UNIQUE, table_name=_TABLE)


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        # Keep writers out between reducing active links and restoring the index.
        bind.execute(sa.text("LOCK TABLE sale_owner_links IN ACCESS EXCLUSIVE MODE"))

    bind.execute(
        sa.text(
            "UPDATE sale_owner_links SET status = 'ended', "
            "ended_at = COALESCE(ended_at, CURRENT_TIMESTAMP), "
            "end_reason = COALESCE(end_reason, 'Downgrade 0102: retained lowest-id active link per owner') "
            "WHERE status = 'active' AND id NOT IN ("
            "SELECT MIN(id) FROM sale_owner_links WHERE status = 'active' GROUP BY owner_id)"
        )
    )
    indexes = {i["name"] for i in sa.inspect(bind).get_indexes(_TABLE)}
    if _OLD_UNIQUE not in indexes:
        op.create_index(
            _OLD_UNIQUE,
            _TABLE,
            ["owner_id"],
            unique=True,
            postgresql_where=sa.text("status = 'active'"),
            sqlite_where=sa.text("status = 'active'"),
        )
    for index in (_UNIQUE, _INDEX):
        if index in indexes:
            op.drop_index(index, table_name=_TABLE)
    if "building_id" in {c["name"] for c in sa.inspect(bind).get_columns(_TABLE)}:
        foreign_keys = sa.inspect(bind).get_foreign_keys(_TABLE)
        with op.batch_alter_table(
            _TABLE, naming_convention={"fk": "fk_%(table_name)s_%(column_0_name)s"}
        ) as batch:
            for fk in foreign_keys:
                if fk["constrained_columns"] == ["building_id"]:
                    batch.drop_constraint(fk["name"] or _FK, type_="foreignkey")
            batch.drop_column("building_id")
