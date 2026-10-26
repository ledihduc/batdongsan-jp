"""booking_availability

- houses.availability_config (JSON nullable) — cấu hình khung giờ chủ nhà mở
  nhận xem nhà: {"version":1,"weekdays":[0..6],"slots":["08:00-09:00",...]}. null = mở mặc định.
- Chuẩn hoá viewing_appointments.booking_time (bỏ khoảng trắng: '09:00 - 10:00' → '09:00-10:00').
- Dedup slot trùng đang active (giữ bản sớm nhất, còn lại → 'rejected') để tạo được unique index.
- Partial unique index (house_id, booking_date, booking_time) WHERE status active → chống đặt trùng slot (kể cả pending).

Revision ID: 0041_booking_availability
Revises: 0040_houses_legal_status
Create Date: 2026-07-04
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0041_booking_availability"
down_revision: Union[str, Sequence[str], None] = "0040_houses_legal_status"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_ACTIVE = "('pending','approved','locked')"


def upgrade() -> None:
    op.add_column("houses", sa.Column("availability_config", sa.JSON(), nullable=True))

    # 1) Chuẩn hoá booking_time: bỏ MỌI khoảng trắng → canonical 'HH:MM-HH:MM'.
    op.execute(
        "UPDATE viewing_appointments SET booking_time = REPLACE(booking_time, ' ', '')"
    )

    # 1b) Chuẩn hoá status legacy 'confirmed' → 'approved' (code hiện không dùng
    #     'confirmed'; nó tương đương đã duyệt và PHẢI khoá slot). Làm trước dedup
    #     để 'confirmed' + 'approved' trùng slot được gộp đúng.
    op.execute(
        "UPDATE viewing_appointments SET status='approved' WHERE status='confirmed'"
    )

    # 2) Dedup slot trùng đang active: giữ bản sớm nhất, còn lại → rejected.
    op.execute(
        f"""
        UPDATE viewing_appointments SET status='rejected'
         WHERE id IN (
           SELECT id FROM (
             SELECT id, ROW_NUMBER() OVER (
               PARTITION BY house_id, booking_date, booking_time
               ORDER BY created_at, id
             ) AS rn
             FROM viewing_appointments
             WHERE status IN {_ACTIVE}
           ) t WHERE rn > 1
         )
        """
    )

    # 3) Partial unique index — hàng rào chống trùng slot (chỉ tính slot đang chiếm).
    op.execute(
        f"""
        CREATE UNIQUE INDEX ix_viewing_active_slot
          ON viewing_appointments (house_id, booking_date, booking_time)
          WHERE status IN {_ACTIVE}
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_viewing_active_slot")
    op.drop_column("houses", "availability_config")
