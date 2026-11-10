"""Loader + handler `rest`: whitelist, mode read ⇒ GET, cấm /api/ai/, tham số path (Phase 06, AC5, AC15)."""

from __future__ import annotations

import pytest

import tests.ai.ai_registry_test_utils  # noqa: F401 — đặt env test trước khi import app

from app.ai_capabilities.loader import HandlerSpec, RegistryError, load_registry
from app.ai_capabilities.rest_handler import parse_rest_whitelist
from tests.ai.ai_registry_test_utils import make_rest_action, write_registry

WL = parse_rest_whitelist(["GET /api/jp/stations/search", "GET /api/ai/chat", "POST /api/jp/stations/search",
                           "GET /api/jp/listings/{listing_id}"])
_LISTING_PARAMS = {"type": "object", "required": [], "properties": {"q": {"type": "string"}}}


def test_ai_registry_loader_rest_whitelisted_get_loads(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_rest_action("GET", "/api/jp/stations/search", name="find_station")])
    # Act
    reg = load_registry(path, rest_whitelist=WL)
    # Assert
    assert reg.get("find_station").handler == HandlerSpec(type="rest", method="GET", path="/api/jp/stations/search")
    assert reg.get("find_station").func is None


def test_ai_registry_loader_rest_outside_whitelist_raises(tmp_path):
    # Arrange
    path = write_registry(tmp_path, [make_rest_action("DELETE", "/api/houses/{house_id}", mode="write",
                                                      requires_login=True)])
    # Act / Assert
    with pytest.raises(RegistryError, match="whitelist"):
        load_registry(path, rest_whitelist=WL)


def test_ai_registry_loader_rest_read_with_post_method_raises(tmp_path):
    # Act / Assert
    with pytest.raises(RegistryError, match="GET"):
        load_registry(write_registry(tmp_path, [make_rest_action("POST", "/api/jp/stations/search")]),
                      rest_whitelist=WL)


def test_ai_registry_loader_rest_ai_path_rejected(tmp_path):
    # Act / Assert
    with pytest.raises(RegistryError, match="/api/ai/"):
        load_registry(write_registry(tmp_path, [make_rest_action("GET", "/api/ai/chat")]), rest_whitelist=WL)


def test_ai_registry_loader_rest_path_param_missing_in_params_raises(tmp_path):
    # Arrange
    action = make_rest_action("GET", "/api/jp/listings/{listing_id}", params=_LISTING_PARAMS)
    # Act / Assert
    with pytest.raises(RegistryError, match="listing_id"):
        load_registry(write_registry(tmp_path, [action]), rest_whitelist=WL)
