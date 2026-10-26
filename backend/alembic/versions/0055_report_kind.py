"""Tách báo-sai (feedback) khỏi tố-cáo-vi-phạm (violation)

Revision ID: 0055_report_kind
Revises: 0054_saved_posts_reports

Lỗi ở 0054: khoá unique (target, reporter) khiến một người đã "báo sai thông
tin" thì KHÔNG tố cáo vi phạm được nữa. Hai hành vi khác hẳn nhau về mục đích
nên phải tách bằng cột `kind`.
"""

from alembic import op
import sqlalchemy as sa

revision = "0055_report_kind"
down_revision = "0054_saved_posts_reports"
branch_labels = None
depends_on = None


def _cols(t: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(t)}


def upgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "content_reports" not in tables:
        return
    if "kind" not in _cols("content_reports"):
        op.add_column(
            "content_reports",
            sa.Column("kind", sa.String(length=12), nullable=False,
                      server_default="violation"),
        )
        op.create_index("ix_content_reports_kind", "content_reports", ["kind"])
        # Dữ liệu cũ: suy ra kind từ reason.
        op.execute(
            "UPDATE content_reports SET kind='feedback' WHERE reason='wrong_info'"
        )
    try:
        op.drop_constraint(
            "uq_content_report_target_reporter", "content_reports", type_="unique"
        )
    except Exception:  # noqa: BLE001 — có thể đã bị gỡ
        pass
    op.create_unique_constraint(
        "uq_content_report_target_reporter_kind",
        "content_reports",
        ["target_type", "target_id", "reporter_id", "kind"],
    )


def downgrade() -> None:
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if "content_reports" not in tables:
        return
    try:
        op.drop_constraint(
            "uq_content_report_target_reporter_kind",
            "content_reports", type_="unique",
        )
    except Exception:  # noqa: BLE001
        pass
    if "kind" in _cols("content_reports"):
        try:
            op.drop_index("ix_content_reports_kind", table_name="content_reports")
        except Exception:  # noqa: BLE001
            pass
        op.drop_column("content_reports", "kind")
