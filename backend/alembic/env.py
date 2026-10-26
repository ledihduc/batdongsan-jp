"""
Alembic env.py — cấu hình migration environment cho ancu365-backend.

Target metadata: Base.metadata (public schema) + PlanningBase.metadata (planning schema).
Multi-metadata list cho phép autogenerate generate cả 2 schema trong 1 migration file.

Chạy migration:
    alembic upgrade head
    alembic revision --autogenerate -m "describe_your_change"
"""

import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

# ---------------------------------------------------------------------------
# Alembic Config object — gives access to values in alembic.ini
# ---------------------------------------------------------------------------
config = context.config

# Interpret the config file for Python logging (nếu config file tồn tại).
#
# `disable_existing_loggers=False` là BẮT BUỘC: mặc định fileConfig() TẮT mọi
# logger đã tồn tại mà không được khai báo trong alembic.ini. Chạy migration
# trong cùng tiến trình với app sẽ giết luôn các logger nghiệp vụ như
# `app.client` — chúng im lặng vĩnh viễn sau đó, không báo lỗi gì.
#
# Đây từng là nguyên nhân thật của một test "chập chờn": test kiểm che thông
# tin nhạy cảm ở /api/client-logs xanh khi chạy lẻ nhưng đỏ khi chạy full suite,
# vì bộ test migration chạy trước đã vô hiệu hoá logger `app.client`.
if config.config_file_name is not None:
    fileConfig(config.config_file_name, disable_existing_loggers=False)

# ---------------------------------------------------------------------------
# Metadata — Phase 01: enable multi-metadata autogenerate.
# Base (public schema): users, houses, bookings, categories, amenities, etc.
# PlanningBase (planning schema): parcels, etl_runs, reports.
# IMPORTANT: app.models MUST be imported to register subclasses onto Base.metadata.
# IMPORTANT: app.planning_models MUST be imported to register PlanningBase subclasses.
# ---------------------------------------------------------------------------
from app.database import Base  # noqa: E402
from app import models  # noqa: E402, F401 — registers all Base subclasses onto Base.metadata
# Import delegation domain models so they register onto Base.metadata for autogenerate.
# This import must come AFTER app.models (which defines the tables these FKs reference).
# NOTE: Package is named 'domain' to avoid shadowing app/models.py (Python prefers
# package directories over .py files with the same name when both exist).
import app.domain  # noqa: E402, F401 — registers all delegation ORM classes

# Planning schema CHƯA dựng ở prod (ETL chưa chạy) → mặc định LOẠI khỏi so sánh
# autogenerate/check để cổng `alembic check` là THẬT (không luôn-đỏ). Bật lại khi
# đã dựng: ALEMBIC_INCLUDE_PLANNING=1.
# Phase-04 Session 1: `app.planning_models` module was removed during Phase-03
# orphan sweep. Gate the import so default path (planning disabled) works again.
_INCLUDE_PLANNING = os.getenv("ALEMBIC_INCLUDE_PLANNING") == "1"
if _INCLUDE_PLANNING:
    from app import planning_models  # noqa: E402, F401 — registers PlanningBase models
    from app.planning_models import PlanningBase  # noqa: E402
    target_metadata = [Base.metadata, PlanningBase.metadata]
else:
    target_metadata = [Base.metadata]

# ---------------------------------------------------------------------------
# Schema/table filter — exclude PostGIS extension schemas and tables.
# Only manage 'public' (core app tables) and 'planning' (planning module).
# Excludes: tiger, tiger_data, topology (PostGIS geocoder extensions).
# Excludes: spatial_ref_sys (PostGIS built-in, not managed by Alembic).
# ---------------------------------------------------------------------------
_MANAGED_SCHEMAS = {"public", "planning"} if _INCLUDE_PLANNING else {"public"}
_EXCLUDED_TABLES = {"spatial_ref_sys"}

# include_schemas=True qualifies bảng phản chiếu là 'public.x', trong khi model
# dùng schema=None → autogenerate coi MỌI bảng public là "added" (cổng luôn đỏ).
# CHỈ bật khi cần so đa-schema (planning). Mặc định public-only → so đúng.
_INCLUDE_SCHEMAS = _INCLUDE_PLANNING


def include_name(name: str, type_: str, parent_names: dict) -> bool:
    """Filter callback to include only app-owned schemas and tables."""
    if type_ == "schema":
        return name in _MANAGED_SCHEMAS
    if type_ == "table":
        if parent_names.get("schema_name") not in _MANAGED_SCHEMAS:
            return False
        return name not in _EXCLUDED_TABLES
    return True


# ---------------------------------------------------------------------------
# Database URL — inject từ env var, không hardcode
# ---------------------------------------------------------------------------


def get_url() -> str:
    url = os.getenv("DATABASE_URL", "")
    if not url:
        raise RuntimeError(
            "DATABASE_URL env var is required for alembic migrations. "
            "Example: postgresql://postgres:secret@localhost:5432/postgres"
        )
    return url


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode (generate SQL scripts without DB connection)."""
    url = get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_schemas=_INCLUDE_SCHEMAS,
        include_name=include_name,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode (connect to DB and apply migrations)."""
    # Override sqlalchemy.url từ alembic.ini với env var
    configuration = config.get_section(config.config_ini_section) or {}
    configuration["sqlalchemy.url"] = get_url()

    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            include_schemas=_INCLUDE_SCHEMAS,
            include_name=include_name,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
