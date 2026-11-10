"""Nạp + kiểm skill hệ thống `registry.<region>.yaml` (D19, AC5, T2).

Lỗi bất kỳ ⇒ `RegistryError`; `main.py` gọi `get_registry()` lúc import để app
không khởi động với registry hỏng. Handler python bị chặn 3 lớp: tiền tố module
trong `ALLOWED_HANDLER_PREFIXES`, tên hàm `tool_*`, đối tượng callable. Handler rest
(P06): `(method, path)` thuộc whitelist, read ⇒ GET, cấm `/api/ai/`, `{x}` phải required.
"""

from __future__ import annotations

import hashlib
import importlib
import inspect
import logging
import pathlib
from dataclasses import dataclass
from typing import Callable, Optional

import yaml
from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError

from app.ai_capabilities.registry_file_schema import REGISTRY_FILE_SCHEMA
from app.ai_capabilities.rest_handler import PATH_PARAM_RE, parse_rest_whitelist, rest_path_allowed
from app.config import settings

logger = logging.getLogger(__name__)

# Có dấu chấm cuối ⇒ chặn module trùng tiền tố như `app.services.jp_search_evil`.
ALLOWED_HANDLER_PREFIXES: tuple[str, ...] = ("app.services.jp_search.", "app.services.vn_search.")
PACKAGED_REGISTRY_DIR = pathlib.Path(__file__).parent / "registry"
DEFAULT_REGISTRY_PATH = PACKAGED_REGISTRY_DIR / "registry.jp.yaml"

_FILE_VALIDATOR = Draft202012Validator(REGISTRY_FILE_SCHEMA)


class RegistryError(Exception):
    """File registry không hợp lệ hoặc cấu hình thư mục registry sai."""


@dataclass(frozen=True)
class HandlerSpec:
    type: str
    target: str = ""
    method: str = ""  # handler rest (P06)
    path: str = ""  # handler rest (P06)


@dataclass(frozen=True)
class Action:
    name: str
    title: dict
    description: dict
    params: dict
    mode: str
    requires_login: bool
    handler: HandlerSpec
    func: Optional[Callable] = None  # chỉ handler python: (db, params, ctx) -> dict


@dataclass(frozen=True)
class Registry:
    version: str
    market: str
    default_lang: str
    guide: dict
    actions: tuple[Action, ...]

    def get(self, name: str) -> Optional[Action]:
        return next((a for a in self.actions if a.name == name), None)

    def names(self) -> list[str]:
        return [a.name for a in self.actions]


def registry_path_for(region: str) -> pathlib.Path:
    base = pathlib.Path(settings.ai_registry_dir) if settings.ai_registry_dir else PACKAGED_REGISTRY_DIR
    return base / f"registry.{region}.yaml"


def ai_enabled_for_region(region: str) -> bool:
    """AI bật khi có file registry của region (T8). Thư mục đặt rõ mà thiếu file ⇒ lỗi cấu hình."""
    path = registry_path_for(region)
    if path.is_file():
        return True
    if settings.ai_registry_dir:
        raise RegistryError(f"AI_REGISTRY_DIR đặt nhưng thiếu {path}")
    return False


def _resolve_python_handler(name: str, target: str) -> Callable:
    module_name, func_name = target.split(":", 1)
    if not module_name.startswith(ALLOWED_HANDLER_PREFIXES):
        raise RegistryError(f"{name}: handler {target} ngoài whitelist {ALLOWED_HANDLER_PREFIXES}")
    if not func_name.startswith("tool_"):
        raise RegistryError(f"{name}: hàm handler phải bắt đầu tool_ ({target})")
    try:
        func = getattr(importlib.import_module(module_name), func_name)
    except (ImportError, AttributeError) as exc:
        raise RegistryError(f"{name}: không import được handler {target}: {exc}") from exc
    if not callable(func) or inspect.iscoroutinefunction(func):
        raise RegistryError(f"{name}: handler {target} phải là hàm đồng bộ callable")
    return func


RestWhitelist = frozenset[tuple[str, str]]


def _check_rest_handler(name: str, mode: str, spec: HandlerSpec, params: dict, whitelist: RestWhitelist) -> None:
    if not rest_path_allowed(spec.path):
        raise RegistryError(f"{name}: path rest phải dưới /api/ và không dưới /api/ai/ ({spec.path})")
    if (spec.method, spec.path) not in whitelist:
        raise RegistryError(f"{name}: {spec.method} {spec.path} ngoài rest whitelist (AI_REST_WHITELIST)")
    if mode == "read" and spec.method != "GET":
        raise RegistryError(f"{name}: mode read chỉ dùng method GET ({spec.method})")
    required = set(params.get("required", []))
    for key in PATH_PARAM_RE.findall(spec.path):
        if key not in params.get("properties", {}) or key not in required:
            raise RegistryError(f"{name}: tham số path {{{key}}} phải có trong params.properties và params.required")


def _build_action(raw: dict, rest_whitelist: RestWhitelist) -> Action:
    name = raw["name"]
    # Thứ tự kiểm: luật write → params → whitelist → import (lỗi whitelist không bị che bởi lỗi import).
    if raw["mode"] == "write" and raw["requires_login"] is not True:
        raise RegistryError(f"{name}: mode write bắt buộc requires_login: true")
    params = raw["params"]
    try:
        Draft202012Validator.check_schema(params)
    except SchemaError as exc:
        raise RegistryError(f"{name}: params không phải JSON Schema hợp lệ: {exc.message}") from exc
    if params.get("type") != "object":
        raise RegistryError(f"{name}: params gốc phải type: object")
    spec = HandlerSpec(**raw["handler"])
    if spec.type == "rest":
        _check_rest_handler(name, raw["mode"], spec, params, rest_whitelist)
        func = None
    else:
        func = _resolve_python_handler(name, spec.target)
    return Action(
        name=name, title=raw["title"], description=raw["description"], params=params,
        mode=raw["mode"], requires_login=raw["requires_login"], handler=spec, func=func,
    )


def load_registry(path, *, rest_whitelist: Optional[RestWhitelist] = None) -> Registry:
    path = pathlib.Path(path)
    if rest_whitelist is None:
        rest_whitelist = parse_rest_whitelist(settings.ai_rest_whitelist)
    try:
        raw_bytes = path.read_bytes()
        doc = yaml.safe_load(raw_bytes)  # safe_load: chặn tag Python
    except (OSError, yaml.YAMLError) as exc:
        raise RegistryError(f"không đọc được registry {path}: {exc}") from exc
    errors = sorted(_FILE_VALIDATOR.iter_errors(doc), key=lambda e: list(e.absolute_path))
    if errors:
        where = "/".join(str(p) for p in errors[0].absolute_path) or "<gốc>"
        raise RegistryError(f"registry {path.name} sai cấu trúc tại {where}: {errors[0].message}")
    seen: set[str] = set()
    for raw in doc["actions"]:
        if raw["name"] in seen:
            raise RegistryError(f"trùng tên action {raw['name']}")
        seen.add(raw["name"])
    # Entry tắt vẫn phải hợp lệ (bật lại không làm hỏng khởi động) nhưng không vào danh sách.
    built = [(_build_action(raw, rest_whitelist), raw["enabled"]) for raw in doc["actions"]]
    registry = Registry(
        version=hashlib.sha256(raw_bytes).hexdigest()[:12],
        market=doc["market"], default_lang=doc["default_lang"], guide=doc["guide"],
        actions=tuple(a for a, enabled in built if enabled),
    )
    logger.info("ai_registry_loaded", extra={
        "event": "ai_registry_loaded", "market": registry.market,
        "actions": registry.names(), "version": registry.version, "path": str(path),
    })
    return registry


def load_region_registry(path) -> Registry:
    """`load_registry` + kiểm file đúng thị trường của REGION (QA M3) — loader của RegistryStore."""
    registry = load_registry(path)
    if registry.market != settings.region:
        raise RegistryError(f"registry market {registry.market} khác REGION {settings.region}")
    return registry


def get_registry() -> Registry:
    """Bản registry hiện hành (nạp lại nóng theo mtime, P06). Lần nạp đầu lỗi ⇒ RegistryError."""
    from app.ai_capabilities.registry_store import get_registry_store  # noqa: PLC0415 — tránh vòng import

    return get_registry_store().current()
