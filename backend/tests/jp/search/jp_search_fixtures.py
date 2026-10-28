"""Fixture dùng chung cho test tìm kiếm / seed JP (plan 20261027-1102, Phase 03).

SQLite in-memory, chỉ tạo 8 bảng cần — `Base.metadata.create_all` toàn bộ có
thể vấp kiểu riêng Postgres. Phase 04 dùng lại `seed_station_fixture`.
"""

from __future__ import annotations

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base
from app.domain.jp.property_info import JpPropertyInfo
from app.domain.jp.rental_terms import JpRentalTerms
from app.domain.jp.transit import Station, TrainLine, TransitAccess
from app.models import Category, House, User

_TABLES = [
    User.__table__, Category.__table__, House.__table__,
    TrainLine.__table__, Station.__table__, TransitAccess.__table__,
    JpRentalTerms.__table__, JpPropertyInfo.__table__,
]


def make_sqlite_session(all_tables: bool = False) -> Session:
    """`all_tables=True` khi gọi route thật (`/api/houses`, `/api/search` cần thêm bảng)."""
    import app.models  # noqa: F401,PLC0415 — đăng ký mọi ORM class trước create_all

    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine, tables=None if all_tables else _TABLES)
    return sessionmaker(bind=engine)()


def seed_station_fixture(db: Session) -> dict[str, int]:
    """2 tuyến (山手線, 銀座線) + 4 ga; 渋谷 có 2 dòng (F19). Trả khoá → jp_stations.id."""
    yamanote = TrainLine(name_ja="山手線", name_en="Yamanote Line", operator="JR東日本", ekidata_line_cd=11302)
    ginza = TrainLine(name_ja="東京メトロ銀座線", name_en="Ginza Line", operator="東京メトロ", ekidata_line_cd=28001)
    db.add_all([yamanote, ginza])
    db.flush()
    rows = {
        "shibuya_yamanote": Station(line_id=yamanote.id, name_ja="渋谷", name_en="Shibuya", prefecture="東京都",
                                    latitude=35.658, longitude=139.7016, ekidata_station_cd=1130201),
        "shibuya_ginza": Station(line_id=ginza.id, name_ja="渋谷", name_en="Shibuya", prefecture="東京都",
                                 latitude=35.658, longitude=139.7016, ekidata_station_cd=2800105),
        "ebisu": Station(line_id=yamanote.id, name_ja="恵比寿", name_en="Ebisu", prefecture="東京都",
                         latitude=35.6467, longitude=139.7101, ekidata_station_cd=1130208),
        "shinjuku": Station(line_id=yamanote.id, name_ja="新宿", name_en="Shinjuku", prefecture="東京都",
                            latitude=35.6896, longitude=139.7006, ekidata_station_cd=1130202),
    }
    db.add_all(rows.values())
    db.commit()
    return {k: s.id for k, s in rows.items()}
