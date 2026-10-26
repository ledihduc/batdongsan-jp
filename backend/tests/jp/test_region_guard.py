"""Tests for require_region FastAPI dependency.

Covers:
  - require_region('vn') returns 404 when settings.region = 'jp'
  - require_region('jp') returns 404 when settings.region = 'vn'
  - require_region('vn') allows request through when settings.region = 'vn'
  - require_region('jp') allows request through when settings.region = 'jp'
  - Case-insensitive comparison
"""

from __future__ import annotations

import os
import sys

import pytest

# ── Minimal isolated environment — do NOT import main.py ─────────────────────
os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.deps.require_region import require_region


def _make_test_app(region: str) -> FastAPI:
    """Build a minimal test app with two gated endpoints."""
    # Patch settings.region for this app instance.
    from app import config as _cfg
    _cfg.settings.region = region  # type: ignore[assignment]

    test_app = FastAPI()

    @test_app.get("/vn-only", dependencies=[])
    async def vn_endpoint(_: None = None) -> dict:
        require_region("vn")()
        return {"region": "vn"}

    @test_app.get("/jp-only", dependencies=[])
    async def jp_endpoint(_: None = None) -> dict:
        require_region("jp")()
        return {"region": "jp"}

    return test_app


# ---------------------------------------------------------------------------
# Tests using FastAPI TestClient — dependency called directly (no HTTP mock needed)
# ---------------------------------------------------------------------------

class TestRequireRegionDep:
    """Unit tests for the require_region dependency logic."""

    def _call_dep(self, expected: str, actual_region: str) -> None:
        """Call the dependency directly and let it raise or pass."""
        from app import config as _cfg
        _cfg.settings.region = actual_region  # type: ignore[assignment]
        require_region(expected)()

    def test_vn_allowed_when_region_is_vn(self) -> None:
        """No exception raised when expected == actual region."""
        self._call_dep("vn", "vn")  # must not raise

    def test_jp_allowed_when_region_is_jp(self) -> None:
        """No exception raised when expected == actual region."""
        self._call_dep("jp", "jp")  # must not raise

    def test_vn_raises_404_when_region_is_jp(self) -> None:
        """require_region('vn') raises HTTP 404 when region=jp."""
        from fastapi import HTTPException

        from app import config as _cfg
        _cfg.settings.region = "jp"  # type: ignore[assignment]
        with pytest.raises(HTTPException) as exc_info:
            require_region("vn")()
        assert exc_info.value.status_code == 404

    def test_jp_raises_404_when_region_is_vn(self) -> None:
        """require_region('jp') raises HTTP 404 when region=vn."""
        from fastapi import HTTPException

        from app import config as _cfg
        _cfg.settings.region = "vn"  # type: ignore[assignment]
        with pytest.raises(HTTPException) as exc_info:
            require_region("jp")()
        assert exc_info.value.status_code == 404

    def test_case_insensitive_vn(self) -> None:
        """require_region is case-insensitive for both sides."""
        from app import config as _cfg
        _cfg.settings.region = "VN"  # type: ignore[assignment]
        require_region("vn")()  # must not raise

    def test_case_insensitive_jp(self) -> None:
        """require_region is case-insensitive for both sides."""
        from app import config as _cfg
        _cfg.settings.region = "JP"  # type: ignore[assignment]
        require_region("jp")()  # must not raise


class TestRequireRegionViaHttpClient:
    """Integration tests via HTTP client — verify 200 vs 404 responses."""

    def test_vn_endpoint_200_when_region_vn(self) -> None:
        from app import config as _cfg
        _cfg.settings.region = "vn"  # type: ignore[assignment]

        app = FastAPI()

        @app.get("/test")
        async def endpoint() -> dict:
            require_region("vn")()
            return {"ok": True}

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get("/test")
        assert resp.status_code == 200

    def test_vn_endpoint_404_when_region_jp(self) -> None:
        from app import config as _cfg
        _cfg.settings.region = "jp"  # type: ignore[assignment]

        app = FastAPI()

        @app.get("/test")
        async def endpoint() -> dict:
            require_region("vn")()
            return {"ok": True}

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get("/test")
        assert resp.status_code == 404

    def test_jp_endpoint_200_when_region_jp(self) -> None:
        from app import config as _cfg
        _cfg.settings.region = "jp"  # type: ignore[assignment]

        app = FastAPI()

        @app.get("/test")
        async def endpoint() -> dict:
            require_region("jp")()
            return {"ok": True}

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get("/test")
        assert resp.status_code == 200

    def test_jp_endpoint_404_when_region_vn(self) -> None:
        from app import config as _cfg
        _cfg.settings.region = "vn"  # type: ignore[assignment]

        app = FastAPI()

        @app.get("/test")
        async def endpoint() -> dict:
            require_region("jp")()
            return {"ok": True}

        with TestClient(app, raise_server_exceptions=False) as client:
            resp = client.get("/test")
        assert resp.status_code == 404
