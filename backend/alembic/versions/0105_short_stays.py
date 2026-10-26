"""Precise short stays; preserve all original date columns and legacy ranges."""

from alembic import op
import sqlalchemy as sa

revision = "0105_short_stays"
down_revision = "0104_dien_nuoc_dich_vu_phong"
branch_labels = None
depends_on = None

TABLE_COLUMNS = {
    "reservations": [
        ("booking_mode", sa.String(20)),
        ("check_in_at", sa.DateTime()),
        ("check_out_at", sa.DateTime()),
        ("booking_code", sa.String(32)),
        ("price_snapshot", sa.Text()),
    ],
    "room_chiem_dung": [("tu_luc", sa.DateTime()), ("den_luc", sa.DateTime())],
    "room_kenh": [
        ("loai_phong", sa.String(100)),
        ("gia_theo_gio", sa.Float()),
        ("gia_qua_dem", sa.Float()),
        ("gia_theo_ngay", sa.Float()),
    ],
}
RANGES = [
    (
        "reservations",
        "excl_reservations_room_overlap",
        "check_in_date",
        "check_out_date",
        "check_in_at",
        "check_out_at",
        " WHERE (status IN ('pending','approved','checked_in'))",
    ),
    (
        "room_chiem_dung",
        "excl_room_chiem_dung_trung",
        "tu_ngay",
        "den_ngay",
        "tu_luc",
        "den_luc",
        "",
    ),
]


def upgrade():
    for table, columns in TABLE_COLUMNS.items():
        for name, kind in columns:
            op.add_column(table, sa.Column(name, kind, nullable=True))
    for name, default in [
        ("huy_truoc_gio", "1"),
        ("huy_truoc_dem", "2"),
        ("huy_truoc_ngay", "12"),
    ]:
        op.add_column(
            "room_kenh",
            sa.Column(name, sa.Integer(), nullable=False, server_default=default),
        )
    op.create_unique_constraint(
        "uq_reservations_booking_code", "reservations", ["booking_code"]
    )
    if op.get_bind().dialect.name != "postgresql":
        return
    for table, constraint, ci, co, start, end, predicate in RANGES:
        op.execute(f"ALTER TABLE {table} DROP CONSTRAINT IF EXISTS {constraint}")
        op.execute(
            f"""ALTER TABLE {table} ADD CONSTRAINT {constraint}
            EXCLUDE USING gist (room_id WITH =,
            tsrange(COALESCE({start}, {ci}::timestamp), COALESCE({end}, {co}::timestamp), '[)') WITH &&){predicate}"""
        )
        op.create_check_constraint(
            f"ck_{table}_precise_time",
            table,
            f"({start} IS NULL AND {end} IS NULL) OR "
            f"({start} IS NOT NULL AND {end} IS NOT NULL AND {end} > {start})",
        )
    op.create_check_constraint(
        "ck_reservations_booking_mode",
        "reservations",
        "(booking_mode IS NULL AND check_in_at IS NULL AND check_out_at IS NULL) OR "
        "(booking_mode IS NOT NULL AND booking_mode IN ('theo_gio','qua_dem','theo_ngay') AND check_in_at IS NOT NULL AND check_out_at IS NOT NULL AND booking_code IS NOT NULL)",
    )
    for col in ("gia_theo_gio", "gia_qua_dem", "gia_theo_ngay"):
        op.create_check_constraint(
            f"ck_room_kenh_{col}",
            "room_kenh",
            f"{col} IS NULL OR ({col} > 0 AND {col} < 1000000000)",
        )
    for col in ("huy_truoc_gio", "huy_truoc_dem", "huy_truoc_ngay"):
        op.create_check_constraint(
            f"ck_room_kenh_{col}", "room_kenh", f"{col} BETWEEN 0 AND 720"
        )


def downgrade():
    if op.get_bind().dialect.name == "postgresql":
        # Refuse loss of precise occupancy/booking information that the old
        # date-only exclusions cannot represent. Entire migration rolls back.
        for table, constraint, ci, co, start, end, predicate in RANGES:
            active = (
                " AND a.status IN ('pending','approved','checked_in') AND b.status IN ('pending','approved','checked_in')"
                if table == "reservations"
                else ""
            )
            conflict = (
                op.get_bind()
                .execute(
                    sa.text(
                        f"SELECT 1 FROM {table} a JOIN {table} b ON a.id < b.id AND a.room_id=b.room_id WHERE a.{ci}<b.{co} AND b.{ci}<a.{co}{active} LIMIT 1"
                    )
                )
                .first()
            )
            if conflict:
                raise RuntimeError(
                    "Không thể hạ phiên bản: còn lịch trong ngày trùng khoảng ngày cũ. Hãy hoàn tất/gỡ các lịch ngắn hạn liên quan trước."
                )
        op.drop_constraint("ck_reservations_booking_mode", "reservations")
        for table, constraint, ci, co, start, end, predicate in RANGES:
            op.drop_constraint(f"ck_{table}_precise_time", table)
            op.execute(f"ALTER TABLE {table} DROP CONSTRAINT {constraint}")
            op.execute(
                f"ALTER TABLE {table} ADD CONSTRAINT {constraint} EXCLUDE USING gist (room_id WITH =, daterange({ci}, {co}, '[)') WITH &&){predicate}"
            )
        for col in (
            "gia_theo_gio",
            "gia_qua_dem",
            "gia_theo_ngay",
            "huy_truoc_gio",
            "huy_truoc_dem",
            "huy_truoc_ngay",
        ):
            op.drop_constraint(f"ck_room_kenh_{col}", "room_kenh")
    op.drop_constraint("uq_reservations_booking_code", "reservations", type_="unique")
    for col in ("huy_truoc_gio", "huy_truoc_dem", "huy_truoc_ngay"):
        op.drop_column("room_kenh", col)
    for table, columns in reversed(list(TABLE_COLUMNS.items())):
        for name, _ in reversed(columns):
            op.drop_column(table, name)
