"""resolve_station_ids — gom ga cùng tên + tỉnh (D11), plan 20261027-1102 Phase 04."""

from __future__ import annotations

import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from app.services.jp_search.station_resolver import resolve_station_ids, search_stations
from tests.jp.search.jp_search_fixtures import make_sqlite_session, seed_station_fixture


def test_jp_station_resolver_station_id_expands_same_name_other_line():
    # Arrange
    db = make_sqlite_session()
    st = seed_station_fixture(db)
    # Act
    ids = resolve_station_ids(db, station_id=st["shibuya_yamanote"])
    # Assert
    assert sorted(ids) == sorted([st["shibuya_yamanote"], st["shibuya_ginza"]])


def test_jp_station_resolver_station_name_with_eki_suffix_resolves():
    # Arrange
    db = make_sqlite_session()
    st = seed_station_fixture(db)
    # Act
    ids = resolve_station_ids(db, station_name="渋谷駅")
    # Assert
    assert sorted(ids) == sorted([st["shibuya_yamanote"], st["shibuya_ginza"]])


def test_jp_station_resolver_unknown_station_id_returns_empty_list():
    # Arrange
    db = make_sqlite_session()
    seed_station_fixture(db)
    # Act / Assert
    assert resolve_station_ids(db, station_id=99999) == []


def test_jp_station_resolver_unknown_station_name_returns_empty_list():
    # Arrange
    db = make_sqlite_session()
    seed_station_fixture(db)
    # Act / Assert
    assert resolve_station_ids(db, station_name="大阪") == []


def test_jp_station_resolver_no_params_returns_none():
    # Arrange
    db = make_sqlite_session()
    seed_station_fixture(db)
    # Act / Assert
    assert resolve_station_ids(db) is None


def test_jp_station_resolver_station_id_wins_over_name():
    # Arrange
    db = make_sqlite_session()
    st = seed_station_fixture(db)
    # Act
    ids = resolve_station_ids(db, station_id=st["ebisu"], station_name="渋谷")
    # Assert
    assert ids == [st["ebisu"]]


def test_jp_station_resolver_search_stations_returns_line_name():
    # Arrange
    db = make_sqlite_session()
    seed_station_fixture(db)
    # Act
    rows = search_stations(db, "渋谷")
    # Assert
    assert {r["line_name_ja"] for r in rows} == {"山手線", "東京メトロ銀座線"}
    assert set(rows[0]) == {"id", "name_ja", "name_en", "line_name_ja", "prefecture"}
