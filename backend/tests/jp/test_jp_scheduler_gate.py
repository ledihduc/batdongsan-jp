import os

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from app.core.jp_scheduler_gate import should_start_jp_scheduler  # noqa: E402


def test_jp_scheduler_gate_region_jp_disabled_returns_false():
    # Arrange / Act
    result = should_start_jp_scheduler("jp", False)
    # Assert
    assert result is False


def test_jp_scheduler_gate_region_jp_enabled_returns_true():
    assert should_start_jp_scheduler("JP", True) is True


def test_jp_scheduler_gate_region_vn_enabled_returns_false():
    assert should_start_jp_scheduler("vn", True) is False


def test_settings_jp_scheduler_enabled_default_true(monkeypatch):
    monkeypatch.delenv("JP_SCHEDULER_ENABLED", raising=False)
    from app.config import Settings

    assert Settings(_env_file=None).jp_scheduler_enabled is True
