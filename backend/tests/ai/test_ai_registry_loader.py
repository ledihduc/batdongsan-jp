"""Loader registry v2: schema, whitelist handler, luật write, version (AC5, T2 — Phase 05)."""

from __future__ import annotations

import pytest

from app.ai_capabilities.loader import (
    DEFAULT_REGISTRY_PATH,
    RegistryError,
    ai_enabled_for_region,
    load_registry,
    registry_path_for,
)
from app.config import settings
from tests.ai.ai_registry_test_utils import make_action, write_registry


def test_ai_registry_loader_packaged_file_loads_three_read_actions():
    # Act
    reg = load_registry(DEFAULT_REGISTRY_PATH)
    # Assert
    assert reg.names() == ["search_listings", "get_listing", "search_stations"]
    assert all(a.mode == "read" and a.params["type"] == "object" for a in reg.actions)
    assert reg.market == "jp" and reg.default_lang == "ja"


def test_ai_registry_loader_python_handler_outside_whitelist_raises(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(handler={"type": "python", "target": "os:system"})])
    # Act / Assert
    with pytest.raises(RegistryError, match="whitelist"):
        load_registry(path)


def test_ai_registry_loader_handler_prefix_lookalike_raises(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(
        handler={"type": "python", "target": "app.services.jp_search_evil.x:tool_a"})])
    # Act / Assert
    with pytest.raises(RegistryError, match="whitelist"):
        load_registry(path)


def test_ai_registry_loader_vn_prefix_lookalike_raises(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(
        handler={"type": "python", "target": "app.services.vn_search_evil.x:tool_a"})])
    # Act / Assert
    with pytest.raises(RegistryError, match="whitelist"):
        load_registry(path)


def test_ai_registry_loader_handler_function_without_tool_prefix_raises(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(handler={
        "type": "python", "target": "app.services.jp_search.station_resolver:resolve_station_ids"})])
    # Act / Assert
    with pytest.raises(RegistryError, match="tool_"):
        load_registry(path)


def test_ai_registry_loader_write_without_requires_login_raises(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(mode="write", requires_login=False)])
    # Act / Assert
    with pytest.raises(RegistryError, match="requires_login"):
        load_registry(path)


def test_ai_registry_loader_write_with_requires_login_loads(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(mode="write", requires_login=True)])
    # Act
    reg = load_registry(path)
    # Assert
    assert reg.get("find_station").mode == "write"


def test_ai_registry_loader_missing_english_description_raises(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(description={"ja": "x"})])
    # Act / Assert
    with pytest.raises(RegistryError):
        load_registry(path)


def test_ai_registry_loader_missing_vietnamese_title_raises(tmp_path):
    # Arrange (D18: đủ ja, vi, en)
    path = write_registry(tmp_path, [make_action(title={"ja": "x", "en": "x"})])
    # Act / Assert
    with pytest.raises(RegistryError):
        load_registry(path)


def test_ai_registry_loader_invalid_params_schema_raises(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(params={"type": "objekt"})])
    # Act / Assert
    with pytest.raises(RegistryError, match="params"):
        load_registry(path)


def test_ai_registry_loader_params_root_not_object_raises(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(params={"type": "string"})])
    # Act / Assert
    with pytest.raises(RegistryError, match="object"):
        load_registry(path)


def test_ai_registry_loader_duplicate_name_raises(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(), make_action()])
    # Act / Assert
    with pytest.raises(RegistryError, match="find_station"):
        load_registry(path)


def test_ai_registry_loader_missing_required_key_raises(tmp_path):
    # Arrange
    action = make_action()
    del action["handler"]
    path = write_registry(tmp_path, [action])
    # Act / Assert
    with pytest.raises(RegistryError):
        load_registry(path)


def test_ai_registry_loader_disabled_entry_excluded(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action(), make_action(name="hidden_one", enabled=False)])
    # Act
    reg = load_registry(path)
    # Assert
    assert reg.names() == ["find_station"]


def test_ai_registry_loader_version_changes_when_file_changes(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_action()])
    before = load_registry(path).version
    write_registry(tmp_path, [make_action(title={"ja": "駅", "vi": "Ga", "en": "Station"})])
    # Act
    after = load_registry(path).version
    # Assert
    assert before != after and len(before) == len(after) == 12


def test_ai_registry_path_for_region_uses_dir_setting(tmp_path, monkeypatch):
    # Arrange
    monkeypatch.setattr(settings, "ai_registry_dir", str(tmp_path))
    # Act / Assert
    assert registry_path_for("vn") == tmp_path / "registry.vn.yaml"


def test_ai_registry_enabled_false_when_packaged_file_absent(monkeypatch):
    # Arrange
    monkeypatch.setattr(settings, "ai_registry_dir", "")
    # Act / Assert
    assert ai_enabled_for_region("xx") is False and ai_enabled_for_region("jp") is True


def test_ai_registry_explicit_dir_missing_file_raises(tmp_path, monkeypatch):
    # Arrange: cấu hình thư mục mà thiếu file region ⇒ phải lộ lỗi, không âm thầm tắt AI
    monkeypatch.setattr(settings, "ai_registry_dir", str(tmp_path))
    # Act / Assert
    with pytest.raises(RegistryError):
        ai_enabled_for_region("jp")


def test_ai_registry_loader_nested_invalid_params_schema_raises(tmp_path):
    # Arrange: gốc đúng type object, lỗi nằm ở property con (tester G1)
    params = {"type": "object", "properties": {"q": {"type": "strnig"}}}
    path = write_registry(tmp_path, [make_action(params=params)])
    # Act / Assert
    with pytest.raises(RegistryError, match="JSON Schema"):
        load_registry(path)


def test_ai_registry_loader_yaml_python_tag_rejected(tmp_path):
    # Arrange: tag Python phải bị safe_load từ chối, không được thực thi (tester G2)
    path = tmp_path / "registry.jp.yaml"
    path.write_text('version: !!python/object/apply:os.getcwd []\n', encoding="utf-8")
    # Act / Assert
    with pytest.raises(RegistryError, match="không đọc được"):
        load_registry(path)
