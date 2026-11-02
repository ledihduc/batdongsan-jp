"""Add `listing_id` link column to `jp_rental_terms` and `jp_property_info`.

Plan 20261027-1102 Phase 03 (D1). Hai bảng này chưa có cách nào trỏ về tin
`houses` — chỉ `jp_transit_access` có `listing_id`. Thêm cột cùng quy ước:
`String(64)` chứa `str(houses.id)`, không FK (tránh phụ thuộc chéo schema).

Additive + nullable + idempotent (inspect trước khi thêm) — dòng cũ giữ NULL.
"""

from alembic import op
import sqlalchemy as sa


revision = "0167_jp_listing_link_columns"
down_revision = "0166_jp_payments_breakdown"
branch_labels = None
depends_on = None


_TABLES = ("jp_rental_terms", "jp_property_info")
_COLUMN = "listing_id"
_COMMENT = "houses.id dạng chuỗi (D1, mig 0167). NULL = dữ liệu cũ chưa gắn tin."


def _index_name(table: str) -> str:
    return f"ix_{table}_{_COLUMN}"


def upgrade() -> None:
    insp = sa.inspect(op.get_bind())
    for table in _TABLES:
        if not insp.has_table(table):
            raise RuntimeError(
                f"Table '{table}' missing — JP listing baseline not applied. "
                "Run earlier migrations first."
            )
        if _COLUMN not in {c["name"] for c in insp.get_columns(table)}:
            op.add_column(
                table,
                sa.Column(_COLUMN, sa.String(length=64), nullable=True, comment=_COMMENT),
            )
        if _index_name(table) not in {i["name"] for i in insp.get_indexes(table)}:
            op.create_index(_index_name(table), table, [_COLUMN])


def downgrade() -> None:
    insp = sa.inspect(op.get_bind())
    for table in reversed(_TABLES):
        if not insp.has_table(table):
            continue
        if _index_name(table) in {i["name"] for i in insp.get_indexes(table)}:
            op.drop_index(_index_name(table), table_name=table)
        if _COLUMN in {c["name"] for c in insp.get_columns(table)}:
            op.drop_column(table, _COLUMN)
