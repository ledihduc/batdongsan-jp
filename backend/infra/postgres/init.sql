-- ancu365 PostGIS init script
-- Loaded by postgis container on FIRST start via /docker-entrypoint-initdb.d/
-- NOTE: Only runs once when the volume is empty (new cluster).

-- ── Extensions ────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- ── Schema ────────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS planning;

-- ── Permissions ───────────────────────────────────────────────────────────────
-- POSTGRES_USER (from env) owns the schema; grant usage to others if needed.
-- Tables are created later by alembic upgrade head + planning_models.py.
GRANT USAGE ON SCHEMA planning TO PUBLIC;

-- Grant full control on schema to the app user (same as POSTGRES_USER here)
-- Using a DO block to reference the current_user dynamically.
DO $$
BEGIN
  EXECUTE format('GRANT ALL ON SCHEMA planning TO %I', current_user);
  EXECUTE format('GRANT ALL ON ALL TABLES IN SCHEMA planning TO %I', current_user);
  EXECUTE format(
    'ALTER DEFAULT PRIVILEGES IN SCHEMA planning GRANT ALL ON TABLES TO %I',
    current_user
  );
  EXECUTE format(
    'ALTER DEFAULT PRIVILEGES IN SCHEMA planning GRANT USAGE, SELECT ON SEQUENCES TO %I',
    current_user
  );
END
$$;
