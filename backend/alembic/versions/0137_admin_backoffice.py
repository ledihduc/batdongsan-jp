"""Backoffice quản trị V2: RBAC, phiên admin, nhật ký append-only, case, outbox
sự kiện, maker-checker, chứng từ riêng tư.

Additive: chỉ thêm bảng mới. Cấp sẵn SUPER_ADMIN cho mọi tài khoản đang có
`users.role='admin'` để không ai mất quyền khi deploy.

Revision ID: 0137_admin_backoffice
Revises: 0136_cach_tinh_theo_nguoi
"""

from datetime import datetime

from alembic import op
import sqlalchemy as sa

revision = "0137_admin_backoffice"
down_revision = "0136_cach_tinh_theo_nguoi"
branch_labels = None
depends_on = None

_TABLES = [
    "admin_roles", "admin_permissions", "admin_role_permissions", "admin_user_roles",
    "admin_sessions", "admin_action_logs", "admin_cases", "admin_case_events",
    "admin_change_requests", "admin_events", "private_documents",
]


def upgrade() -> None:
    bind = op.get_bind()
    have = set(sa.inspect(bind).get_table_names())
    is_pg = bind.dialect.name == "postgresql"
    uid = lambda name, nullable=True, ondelete="SET NULL": sa.Column(  # noqa: E731
        name, sa.Integer(), sa.ForeignKey("users.id", ondelete=ondelete), nullable=nullable
    )

    if "admin_roles" not in have:
        op.create_table(
            "admin_roles",
            sa.Column("code", sa.String(40), primary_key=True),
            sa.Column("name", sa.String(120), nullable=False),
            sa.Column("description", sa.Text(), nullable=False, server_default=""),
            sa.Column("created_at", sa.DateTime(), nullable=True),
        )
    if "admin_permissions" not in have:
        op.create_table(
            "admin_permissions",
            sa.Column("code", sa.String(80), primary_key=True),
            sa.Column("module", sa.String(40), nullable=False, index=True),
            sa.Column("description", sa.Text(), nullable=False, server_default=""),
        )
    if "admin_role_permissions" not in have:
        op.create_table(
            "admin_role_permissions",
            sa.Column("role_code", sa.String(40), sa.ForeignKey("admin_roles.code", ondelete="CASCADE"), primary_key=True),
            sa.Column("permission_code", sa.String(80), sa.ForeignKey("admin_permissions.code", ondelete="CASCADE"), primary_key=True),
        )
    if "admin_user_roles" not in have:
        op.create_table(
            "admin_user_roles",
            sa.Column("id", sa.Integer(), primary_key=True),
            uid("user_id", nullable=False, ondelete="CASCADE"),
            sa.Column("role_code", sa.String(40), sa.ForeignKey("admin_roles.code", ondelete="RESTRICT"), nullable=False),
            uid("granted_by"),
            sa.Column("granted_at", sa.DateTime(), nullable=True),
            sa.Column("grant_reason", sa.String(500), nullable=False, server_default=""),
            uid("revoked_by"),
            sa.Column("revoked_at", sa.DateTime(), nullable=True),
            sa.Column("revoke_reason", sa.String(500), nullable=True),
        )
        op.create_index("ix_admin_user_roles_user_id", "admin_user_roles", ["user_id"])
        op.create_index("ix_admin_user_roles_role_code", "admin_user_roles", ["role_code"])
        op.create_index(
            "uq_admin_user_roles_active", "admin_user_roles", ["user_id", "role_code"],
            unique=True,
            postgresql_where=sa.text("revoked_at IS NULL"),
            sqlite_where=sa.text("revoked_at IS NULL"),
        )
    if "admin_sessions" not in have:
        op.create_table(
            "admin_sessions",
            sa.Column("id", sa.String(36), primary_key=True),
            uid("user_id", nullable=False, ondelete="CASCADE"),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.Column("expires_at", sa.DateTime(), nullable=False),
            sa.Column("last_seen_at", sa.DateTime(), nullable=True),
            sa.Column("reauth_at", sa.DateTime(), nullable=True),
            sa.Column("revoked_at", sa.DateTime(), nullable=True),
            uid("revoked_by"),
            sa.Column("revoke_reason", sa.String(300), nullable=True),
            sa.Column("ip_hash", sa.String(64), nullable=True),
            sa.Column("user_agent", sa.String(300), nullable=True),
        )
        op.create_index("ix_admin_sessions_user_id", "admin_sessions", ["user_id"])
        op.create_index("ix_admin_sessions_expires_at", "admin_sessions", ["expires_at"])
    if "admin_action_logs" not in have:
        op.create_table(
            "admin_action_logs",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("request_id", sa.String(64), nullable=True),
            uid("actor_user_id", nullable=False, ondelete="RESTRICT"),
            sa.Column("admin_session_id", sa.String(36), nullable=True),
            sa.Column("action", sa.String(80), nullable=False),
            sa.Column("permission", sa.String(80), nullable=True),
            sa.Column("entity_type", sa.String(40), nullable=True),
            sa.Column("entity_id", sa.String(64), nullable=True),
            sa.Column("reason", sa.Text(), nullable=True),
            sa.Column("before_json", sa.JSON(), nullable=True),
            sa.Column("after_json", sa.JSON(), nullable=True),
            sa.Column("response_json", sa.JSON(), nullable=True),
            sa.Column("idempotency_key", sa.String(128), nullable=True),
            sa.Column("result", sa.String(20), nullable=False, server_default="success"),
            sa.Column("ip_hash", sa.String(64), nullable=True),
            sa.Column("user_agent", sa.String(300), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.UniqueConstraint("actor_user_id", "action", "idempotency_key", name="uq_admin_action_logs_actor_action_key"),
        )
        op.create_index("ix_admin_action_logs_actor_user_id", "admin_action_logs", ["actor_user_id"])
        op.create_index("ix_admin_action_logs_action", "admin_action_logs", ["action"])
        op.create_index("ix_admin_action_logs_created_at", "admin_action_logs", ["created_at"])
        op.create_index("ix_admin_action_logs_entity", "admin_action_logs", ["entity_type", "entity_id", "created_at"])
        if is_pg:
            # Append-only ở tầng DB: không API nào (kể cả lỗi code) sửa/xoá được.
            op.execute(
                """
                CREATE OR REPLACE FUNCTION admin_action_logs_append_only() RETURNS trigger AS $$
                BEGIN
                  RAISE EXCEPTION 'admin_action_logs is append-only';
                END;
                $$ LANGUAGE plpgsql;
                """
            )
            op.execute(
                "CREATE TRIGGER trg_admin_action_logs_append_only BEFORE UPDATE OR DELETE "
                "ON admin_action_logs FOR EACH ROW EXECUTE FUNCTION admin_action_logs_append_only();"
            )
    if "admin_cases" not in have:
        op.create_table(
            "admin_cases",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("source_type", sa.String(40), nullable=False),
            sa.Column("source_id", sa.String(64), nullable=False),
            uid("assignee_user_id"),
            sa.Column("priority", sa.String(10), nullable=False, server_default="normal"),
            sa.Column("sla_due_at", sa.DateTime(), nullable=True),
            sa.Column("status", sa.String(20), nullable=False, server_default="open"),
            sa.Column("internal_note", sa.Text(), nullable=True),
            sa.Column("title", sa.String(200), nullable=True),
            sa.Column("description", sa.Text(), nullable=True),
            uid("created_by"),
            sa.Column("done_at", sa.DateTime(), nullable=True),
            sa.Column("legal_hold", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.Column("updated_at", sa.DateTime(), nullable=True),
            sa.UniqueConstraint("source_type", "source_id", name="uq_admin_cases_source"),
        )
        op.create_index("ix_admin_cases_source_type", "admin_cases", ["source_type"])
        op.create_index("ix_admin_cases_assignee_user_id", "admin_cases", ["assignee_user_id"])
        op.create_index("ix_admin_cases_status", "admin_cases", ["status"])
    if "admin_case_events" not in have:
        op.create_table(
            "admin_case_events",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("case_id", sa.Integer(), sa.ForeignKey("admin_cases.id", ondelete="CASCADE"), nullable=False),
            uid("actor_user_id"),
            sa.Column("kind", sa.String(40), nullable=False),
            sa.Column("payload", sa.JSON(), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
        )
        op.create_index("ix_admin_case_events_case_id", "admin_case_events", ["case_id"])
    if "admin_change_requests" not in have:
        op.create_table(
            "admin_change_requests",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("kind", sa.String(40), nullable=False),
            sa.Column("payload", sa.JSON(), nullable=False),
            sa.Column("reason", sa.Text(), nullable=False),
            sa.Column("status", sa.String(20), nullable=False, server_default="PENDING"),
            uid("requested_by", nullable=False, ondelete="RESTRICT"),
            sa.Column("requested_at", sa.DateTime(), nullable=True),
            uid("decided_by"),
            sa.Column("decided_at", sa.DateTime(), nullable=True),
            sa.Column("decision_note", sa.Text(), nullable=True),
            sa.Column("result_json", sa.JSON(), nullable=True),
        )
        op.create_index("ix_admin_change_requests_kind", "admin_change_requests", ["kind"])
        op.create_index("ix_admin_change_requests_status", "admin_change_requests", ["status"])
        op.create_index("ix_admin_change_requests_requested_by", "admin_change_requests", ["requested_by"])
    if "admin_events" not in have:
        op.create_table(
            "admin_events",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("event_type", sa.String(60), nullable=False),
            sa.Column("entity_type", sa.String(40), nullable=True),
            sa.Column("entity_id", sa.String(64), nullable=True),
            sa.Column("status", sa.String(40), nullable=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
        )
        op.create_index("ix_admin_events_event_type", "admin_events", ["event_type"])
        op.create_index("ix_admin_events_created_at", "admin_events", ["created_at"])
    if "private_documents" not in have:
        op.create_table(
            "private_documents",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("object_key", sa.String(200), nullable=False, unique=True),
            uid("owner_user_id"),
            sa.Column("category", sa.String(40), nullable=False),
            sa.Column("source_type", sa.String(40), nullable=True),
            sa.Column("source_id", sa.String(64), nullable=True),
            sa.Column("content_type", sa.String(80), nullable=False, server_default="application/octet-stream"),
            sa.Column("size_bytes", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("sha256", sa.String(64), nullable=True),
            sa.Column("legacy_upload_name", sa.String(200), nullable=True, unique=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
        )
        op.create_index("ix_private_documents_owner_user_id", "private_documents", ["owner_user_id"])
        op.create_index("ix_private_documents_category", "private_documents", ["category"])

    _seed_catalog(bind)


def _seed_catalog(bind) -> None:
    from app.services.admin_v2.permissions import PERMISSIONS, ROLES

    now = datetime.utcnow()
    roles = sa.table("admin_roles", sa.column("code"), sa.column("name"), sa.column("description"), sa.column("created_at"))
    perms = sa.table("admin_permissions", sa.column("code"), sa.column("module"), sa.column("description"))
    rp = sa.table("admin_role_permissions", sa.column("role_code"), sa.column("permission_code"))
    have_roles = {r[0] for r in bind.execute(sa.text("SELECT code FROM admin_roles"))}
    have_perms = {r[0] for r in bind.execute(sa.text("SELECT code FROM admin_permissions"))}
    have_rp = {(r[0], r[1]) for r in bind.execute(sa.text("SELECT role_code, permission_code FROM admin_role_permissions"))}
    new_perms = [{"code": c, "module": m, "description": d} for c, (m, d) in PERMISSIONS.items() if c not in have_perms]
    if new_perms:
        op.bulk_insert(perms, new_perms)
    new_roles = [{"code": c, "name": n, "description": d, "created_at": now} for c, (n, d, _p) in ROLES.items() if c not in have_roles]
    if new_roles:
        op.bulk_insert(roles, new_roles)
    new_rp = [
        {"role_code": c, "permission_code": p}
        for c, (_n, _d, ps) in ROLES.items() for p in ps if (c, p) not in have_rp
    ]
    if new_rp:
        op.bulk_insert(rp, new_rp)

    # Quản trị viên kiểu cũ → SUPER_ADMIN (để không ai mất quyền khi deploy).
    bind.execute(
        sa.text(
            """
            INSERT INTO admin_user_roles (user_id, role_code, granted_at, grant_reason)
            SELECT u.id, 'SUPER_ADMIN', :now, 'migration 0137: users.role=admin'
            FROM users u
            WHERE u.role = 'admin'
              AND NOT EXISTS (
                SELECT 1 FROM admin_user_roles r
                WHERE r.user_id = u.id AND r.role_code = 'SUPER_ADMIN' AND r.revoked_at IS NULL
              )
            """
        ),
        {"now": now},
    )


def downgrade() -> None:
    bind = op.get_bind()
    have = set(sa.inspect(bind).get_table_names())
    if bind.dialect.name == "postgresql" and "admin_action_logs" in have:
        op.execute("DROP TRIGGER IF EXISTS trg_admin_action_logs_append_only ON admin_action_logs")
        op.execute("DROP FUNCTION IF EXISTS admin_action_logs_append_only()")
    for name in reversed(_TABLES):
        if name in have:
            op.drop_table(name)
