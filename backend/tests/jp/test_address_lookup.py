"""Tests for JP address postal code lookup.

Covers:
  - GET /api/jp/address/lookup?postal_code=1500001 returns AddressLookupResponse
  - Regex validation rejects invalid formats (HTTP 422)
  - Upstream API error → 503
  - Mock httpx to verify no real network calls
  - Schema validation: AddressCandidate fields
  - Hyphenated postal code ('150-0001') accepted and normalized
"""

from __future__ import annotations

import os
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


# ---------------------------------------------------------------------------
# Test fixtures
# ---------------------------------------------------------------------------

MOCK_ZIPCLOUD_RESPONSE = {
    "message": None,
    "results": [
        {
            "address1": "東京都",
            "address2": "渋谷区",
            "address3": "神南",
            "kana1": "ﾄｳｷｮｳﾄ",
            "kana2": "ｼﾌﾞﾔｸ",
            "kana3": "ｼﾞﾝﾅﾝ",
            "prefcode": "13",
            "zipcode": "1500001",
        }
    ],
    "status": 200,
}

MOCK_ZIPCLOUD_EMPTY = {
    "message": None,
    "results": None,
    "status": 200,
}


def _make_mock_response(payload: dict, status_code: int = 200) -> MagicMock:
    """Create a mock httpx.Response-like object."""
    mock_resp = MagicMock()
    mock_resp.status_code = status_code
    mock_resp.json.return_value = payload
    mock_resp.raise_for_status.return_value = None
    return mock_resp


# ---------------------------------------------------------------------------
# Tests for jp_postal_client directly
# ---------------------------------------------------------------------------

class TestJpPostalClientValidation:
    """Unit tests for postal code regex validation."""

    def test_valid_7digit(self) -> None:
        from app.services.address.jp_postal_client import validate_postal_code
        assert validate_postal_code("1500001") is True

    def test_valid_with_hyphen(self) -> None:
        from app.services.address.jp_postal_client import validate_postal_code
        assert validate_postal_code("150-0001") is True

    def test_invalid_6digit(self) -> None:
        from app.services.address.jp_postal_client import validate_postal_code
        assert validate_postal_code("150001") is False

    def test_invalid_letters(self) -> None:
        from app.services.address.jp_postal_client import validate_postal_code
        assert validate_postal_code("ABC1234") is False

    def test_invalid_empty(self) -> None:
        from app.services.address.jp_postal_client import validate_postal_code
        assert validate_postal_code("") is False

    def test_invalid_hyphen_wrong_position(self) -> None:
        from app.services.address.jp_postal_client import validate_postal_code
        assert validate_postal_code("15-00001") is False

    def test_invalid_8_digits(self) -> None:
        from app.services.address.jp_postal_client import validate_postal_code
        assert validate_postal_code("15000012") is False


class TestJpPostalClientLookup:
    """Unit tests for lookup_postal_code with mocked httpx."""

    @pytest.mark.asyncio
    async def test_lookup_returns_candidates(self) -> None:
        from app.services.address import jp_postal_client

        # Clear cache to ensure fresh call.
        jp_postal_client._cache.clear()

        mock_resp = _make_mock_response(MOCK_ZIPCLOUD_RESPONSE)

        with patch(
            "app.services.address.jp_postal_client.httpx.AsyncClient"
        ) as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=None)

            result = await jp_postal_client.lookup_postal_code("1500001")

        assert len(result) == 1
        assert result[0]["prefecture"] == "東京都"
        assert result[0]["city"] == "渋谷区"
        assert result[0]["town"] == "神南"
        assert result[0]["prefecture_kana"] == "ﾄｳｷｮｳﾄ"

    @pytest.mark.asyncio
    async def test_lookup_empty_result(self) -> None:
        from app.services.address import jp_postal_client

        jp_postal_client._cache.clear()

        mock_resp = _make_mock_response(MOCK_ZIPCLOUD_EMPTY)

        with patch(
            "app.services.address.jp_postal_client.httpx.AsyncClient"
        ) as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=None)

            result = await jp_postal_client.lookup_postal_code("9999999")

        assert result == []

    @pytest.mark.asyncio
    async def test_lookup_invalid_code_raises_value_error(self) -> None:
        from app.services.address.jp_postal_client import lookup_postal_code

        with pytest.raises(ValueError, match="Invalid JP postal code"):
            await lookup_postal_code("INVALID")

    @pytest.mark.asyncio
    async def test_lookup_uses_cache_on_second_call(self) -> None:
        from app.services.address import jp_postal_client

        jp_postal_client._cache.clear()

        mock_resp = _make_mock_response(MOCK_ZIPCLOUD_RESPONSE)

        with patch(
            "app.services.address.jp_postal_client.httpx.AsyncClient"
        ) as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=None)

            await jp_postal_client.lookup_postal_code("1500001")
            await jp_postal_client.lookup_postal_code("1500001")  # second call

        # HTTP client should only be instantiated once (second call served from cache).
        assert mock_client_cls.call_count == 1

    @pytest.mark.asyncio
    async def test_hyphenated_code_normalized(self) -> None:
        """'150-0001' should be normalized to '1500001' before lookup."""
        from app.services.address import jp_postal_client

        jp_postal_client._cache.clear()

        mock_resp = _make_mock_response(MOCK_ZIPCLOUD_RESPONSE)

        with patch(
            "app.services.address.jp_postal_client.httpx.AsyncClient"
        ) as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=None)

            result = await jp_postal_client.lookup_postal_code("150-0001")

        assert len(result) == 1
        # Verify the API call used the normalized code without hyphen.
        call_kwargs = mock_client.get.call_args
        assert call_kwargs[1]["params"]["zipcode"] == "1500001"


# ---------------------------------------------------------------------------
# Tests for the route endpoint (HTTP level)
# ---------------------------------------------------------------------------

def _build_jp_test_app() -> FastAPI:
    """Build minimal test app mounting only the JP address router."""
    from app.api.routes.jp.address import router as jp_router
    app = FastAPI()
    app.include_router(jp_router)
    return app


class TestAddressLookupRoute:
    """HTTP-level tests for GET /api/jp/address/lookup."""

    def test_valid_postal_code_returns_200(self) -> None:
        from app.services.address import jp_postal_client

        jp_postal_client._cache.clear()

        mock_resp = _make_mock_response(MOCK_ZIPCLOUD_RESPONSE)

        with patch(
            "app.services.address.jp_postal_client.httpx.AsyncClient"
        ) as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=None)

            with TestClient(_build_jp_test_app()) as client:
                resp = client.get("/api/jp/address/lookup?postal_code=1500001")

        assert resp.status_code == 200
        data = resp.json()
        assert data["postal_code"] == "1500001"
        assert len(data["candidates"]) == 1
        assert data["candidates"][0]["prefecture"] == "東京都"

    def test_invalid_format_returns_422(self) -> None:
        with TestClient(_build_jp_test_app()) as client:
            resp = client.get("/api/jp/address/lookup?postal_code=ABCDEFG")
        assert resp.status_code == 422

    def test_6digit_code_returns_422(self) -> None:
        with TestClient(_build_jp_test_app()) as client:
            resp = client.get("/api/jp/address/lookup?postal_code=150001")
        assert resp.status_code == 422

    def test_hyphenated_code_accepted(self) -> None:
        from app.services.address import jp_postal_client

        jp_postal_client._cache.clear()

        mock_resp = _make_mock_response(MOCK_ZIPCLOUD_RESPONSE)

        with patch(
            "app.services.address.jp_postal_client.httpx.AsyncClient"
        ) as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=None)

            with TestClient(_build_jp_test_app()) as client:
                resp = client.get("/api/jp/address/lookup?postal_code=150-0001")

        assert resp.status_code == 200
        data = resp.json()
        assert data["postal_code"] == "1500001"  # normalized

    def test_upstream_error_returns_503(self) -> None:
        import httpx as _httpx

        from app.services.address import jp_postal_client

        jp_postal_client._cache.clear()

        with patch(
            "app.services.address.jp_postal_client.httpx.AsyncClient"
        ) as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(
                side_effect=_httpx.TimeoutException("timeout", request=MagicMock())
            )
            mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=None)

            with TestClient(_build_jp_test_app(), raise_server_exceptions=False) as client:
                resp = client.get("/api/jp/address/lookup?postal_code=1500001")

        assert resp.status_code == 503

    def test_not_found_postal_code_returns_empty_candidates(self) -> None:
        from app.services.address import jp_postal_client

        jp_postal_client._cache.clear()

        mock_resp = _make_mock_response(MOCK_ZIPCLOUD_EMPTY)

        with patch(
            "app.services.address.jp_postal_client.httpx.AsyncClient"
        ) as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_resp)
            mock_client_cls.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client_cls.return_value.__aexit__ = AsyncMock(return_value=None)

            with TestClient(_build_jp_test_app()) as client:
                resp = client.get("/api/jp/address/lookup?postal_code=9999999")

        assert resp.status_code == 200
        data = resp.json()
        assert data["candidates"] == []
