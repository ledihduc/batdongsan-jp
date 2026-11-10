"""RegistryStore — nạp lại nóng theo (mtime_ns, size) (plan 20261027-1102 Phase 06, AC5)."""

from __future__ import annotations

import pytest

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from app.ai_capabilities.loader import RegistryError, load_registry
from app.ai_capabilities.registry_store import RegistryStore
from tests.ai.ai_registry_test_utils import bump_mtime, make_action, write_registry


def test_ai_registry_store_changed_file_reloads_new_action(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(name="a_one")])
    store = RegistryStore(path)
    write_registry(tmp_path, [make_action(name="a_one"), make_action(name="a_two")])
    bump_mtime(path)
    # Act
    reg = store.current()
    # Assert
    assert reg.names() == ["a_one", "a_two"] and store.last_error is None


def test_ai_registry_store_initial_invalid_file_raises(tmp_path):
    # Arrange
    path = tmp_path / "registry.jp.yaml"
    path.write_text("version: 9\n", encoding="utf-8")
    # Act / Assert
    with pytest.raises(RegistryError):
        RegistryStore(path)


def test_ai_registry_store_invalid_change_keeps_old_and_logs(tmp_path, caplog):
    # Arrange
    path = write_registry(tmp_path, [make_action(name="a_one")])
    store = RegistryStore(path)
    path.write_text("actions: [unclosed\n", encoding="utf-8")
    bump_mtime(path)
    # Act
    with caplog.at_level("WARNING", logger="app.ai_capabilities.registry_store"):
        reg = store.current()
    # Assert
    assert reg.names() == ["a_one"] and store.last_error
    assert any(r.getMessage() == "ai_registry_reload_failed" for r in caplog.records)


def test_ai_registry_store_fixed_after_invalid_reloads(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(name="a_one")])
    store = RegistryStore(path)
    path.write_text("version: 9\n", encoding="utf-8")
    bump_mtime(path)
    store.current()
    write_registry(tmp_path, [make_action(name="a_fixed")])
    bump_mtime(path)
    # Act
    reg = store.current()
    # Assert
    assert reg.names() == ["a_fixed"] and store.last_error is None


def test_ai_registry_store_unchanged_file_does_not_reparse(tmp_path):
    # Arrange
    calls = []

    def counting_loader(p):
        calls.append(p)
        return load_registry(p)

    store = RegistryStore(write_registry(tmp_path, [make_action()]), loader=counting_loader)
    # Act
    for _ in range(3):
        store.current()
    # Assert
    assert len(calls) == 1


def test_ai_registry_store_deleted_file_keeps_old(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(name="a_one")])
    store = RegistryStore(path)
    path.unlink()
    # Act
    reg = store.current()
    # Assert
    assert reg.names() == ["a_one"] and store.last_error
