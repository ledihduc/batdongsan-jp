"""Kiểm duyệt phía người dùng — CHẶN NGƯỜI DÙNG (block).

BẮT BUỘC cho app có nội dung do người dùng tạo (Apple Guideline 1.2): người
dùng phải chặn được người quấy rối, và không còn thấy nội dung của họ. `UserBlock`
là quan hệ một chiều: `blocker` không còn thấy bài/reel/bình luận của `blocked`.
Bản đồ bảng: docs/model_tables.txt.
"""

from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types


class UserBlock(Base):
    __tablename__ = "user_blocks"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # Người thực hiện chặn (viewer). Không thấy nội dung của blocked_id nữa.
    blocker_id: Mapped[int] = mapped_column(Integer, index=True)
    # Người bị chặn.
    blocked_id: Mapped[int] = mapped_column(Integer, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)
    __table_args__ = (
        UniqueConstraint("blocker_id", "blocked_id", name="uq_user_block_pair"),
    )
