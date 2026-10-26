"""Tests for Nominatim geocoding client and resolver.

All tests mock the HTTP layer — no real Nominatim calls.
"""

from __future__ import annotations

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import pytest


class TestNominatimClient:
    """Tests for nominatim_client.geocode_address()."""

    def test_returns_none_on_empty_address(self):
        from app.services.geocoding.nominatim_client import geocode_address

        result = asyncio.get_event_loop().run_until_complete(geocode_address(""))
        assert result is None

    def test_returns_none_on_whitespace_only(self):
        from app.services.geocoding.nominatim_client import geocode_address

        result = asyncio.get_event_loop().run_until_complete(geocode_address("   "))
        assert result is None

    def test_returns_none_on_no_results(self):
        """Mock Nominatim returning empty list."""
        from app.services.geocoding.nominatim_client import geocode_address

        mock_response = MagicMock()
        mock_response.json.return_value = []
        mock_response.raise_for_status.return_value = None

        with patch("httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client.get = AsyncMock(return_value=mock_response)
            mock_client_cls.return_value = mock_client

            result = asyncio.get_event_loop().run_until_complete(
                geocode_address("nonexistent-address-xyz")
            )
        assert result is None

    def test_returns_lat_lon_on_hit(self):
        """Mock Nominatim returning a result."""
        from app.services.geocoding.nominatim_client import geocode_address

        mock_response = MagicMock()
        mock_response.json.return_value = [
            {
                "lat": "35.6762",
                "lon": "139.6503",
                "display_name": "東京都渋谷区神南",
                "address": {
                    "state": "東京都",
                    "city": "渋谷区",
                    "suburb": "神南",
                    "postcode": "1500041",
                },
            }
        ]
        mock_response.raise_for_status.return_value = None

        with patch("httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client.get = AsyncMock(return_value=mock_response)
            mock_client_cls.return_value = mock_client

            result = asyncio.get_event_loop().run_until_complete(
                geocode_address("東京都渋谷区神南")
            )

        assert result is not None
        assert result["lat"] == pytest.approx(35.6762)
        assert result["lon"] == pytest.approx(139.6503)
        assert "display_name" in result
        assert "address" in result

    def test_returns_none_on_timeout(self):
        """Timeout returns None (caller decides fallback)."""
        import httpx
        from app.services.geocoding.nominatim_client import geocode_address

        with patch("httpx.AsyncClient") as mock_client_cls:
            mock_client = AsyncMock()
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client.get = AsyncMock(side_effect=httpx.TimeoutException("timeout"))
            mock_client_cls.return_value = mock_client

            result = asyncio.get_event_loop().run_until_complete(
                geocode_address("some address")
            )
        assert result is None


class TestGeocodingResolver:
    """Tests for resolver.lookup()."""

    def test_lookup_empty_address_returns_none(self):
        from app.services.geocoding.resolver import lookup

        db = MagicMock()
        result = asyncio.get_event_loop().run_until_complete(
            lookup("", db)
        )
        assert result is None

    def test_postal_code_detected_by_regex(self):
        """Resolver routes 7-digit postal code to postal lookup first."""
        from app.services.geocoding import resolver
        from app.services.geocoding.resolver import lookup

        db = MagicMock()
        db.query.return_value.filter.return_value.order_by.return_value.first.return_value = None

        with patch.object(resolver, "lookup_postal", return_value=None) as mock_postal:
            with patch("app.services.geocoding.nominatim_client.geocode_address", new=AsyncMock(return_value=None)):
                asyncio.get_event_loop().run_until_complete(lookup("150-0001", db))
                mock_postal.assert_called_once_with("150-0001", db)

    def test_cache_fresh_within_ttl(self):
        from datetime import datetime, timedelta, timezone
        from app.services.geocoding.resolver import _cache_fresh

        updated_at = datetime.now(timezone.utc) - timedelta(days=3)
        assert _cache_fresh(updated_at) is True

    def test_cache_stale_outside_ttl(self):
        from datetime import datetime, timedelta, timezone
        from app.services.geocoding.resolver import _cache_fresh

        updated_at = datetime.now(timezone.utc) - timedelta(days=8)
        assert _cache_fresh(updated_at) is False

    def test_cache_none_returns_false(self):
        from app.services.geocoding.resolver import _cache_fresh

        assert _cache_fresh(None) is False
