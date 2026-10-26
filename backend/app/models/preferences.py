from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types

class UserPreferences(Base):
    """Sở thích/mục đích người dùng (khảo sát phân loại — redesign v2 P1).
    1 dòng / user. interests/provinces/service_slugs = list[str] (JSONList).
    default_world ∈ {realestate, construction}. Migration 0049."""
    __tablename__ = "user_preferences"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, index=True, unique=True)
    interests: Mapped[list] = mapped_column(JSONList, default=list)
    provinces: Mapped[list] = mapped_column(JSONList, default=list)
    service_slugs: Mapped[list] = mapped_column(JSONList, default=list)
    default_world: Mapped[str] = mapped_column(String(20), default="realestate")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
