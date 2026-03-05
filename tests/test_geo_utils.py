"""Unit tests for app.core.geo_utils."""

import math
import pytest

from app.core.geo_utils import bearing, deg2tile, haversine, is_ahead, tile2deg


# ---------------------------------------------------------------------------
# deg2tile / tile2deg
# ---------------------------------------------------------------------------

class TestDeg2Tile:
    """Test OSM tile coordinate conversion."""

    def test_known_tile_tokyo(self):
        """Tokyo Station at zoom 15 should map to the correct tile."""
        x, y = deg2tile(35.6812, 139.7671, 15)
        assert x == 29105
        assert y == 12903

    def test_zoom_zero(self):
        """At zoom 0 the whole world is one tile."""
        x, y = deg2tile(0, 0, 0)
        assert x == 0
        assert y == 0

    def test_negative_longitude(self):
        """New York (negative lon) should produce valid tiles."""
        x, y = deg2tile(40.7128, -74.0060, 10)
        assert 0 <= x < 1024
        assert 0 <= y < 1024


class TestTile2Deg:
    """Test tile coordinate to lat/lon conversion."""

    def test_roundtrip(self):
        """deg2tile -> tile2deg should return a point near the original."""
        lat, lon = 35.6812, 139.7671
        zoom = 15
        tx, ty = deg2tile(lat, lon, zoom)
        rlat, rlon = tile2deg(tx, ty, zoom)
        # Tile covers ~0.005 degrees at zoom 15
        assert abs(rlat - lat) < 0.02
        assert abs(rlon - lon) < 0.02

    def test_origin_tile(self):
        """Tile (0, 0) at zoom 0 should be near (-180, 85.05)."""
        lat, lon = tile2deg(0, 0, 0)
        assert abs(lon - (-180.0)) < 0.01
        assert lat > 80  # Mercator limit ~85.05


# ---------------------------------------------------------------------------
# haversine
# ---------------------------------------------------------------------------

class TestHaversine:
    """Test great-circle distance calculation."""

    def test_same_point(self):
        """Distance from a point to itself is 0."""
        assert haversine(35.0, 139.0, 35.0, 139.0) == 0.0

    def test_tokyo_to_osaka(self):
        """Tokyo to Osaka is approximately 400 km."""
        dist = haversine(35.6812, 139.7671, 34.6937, 135.5023)
        assert 390 < dist < 410

    def test_equator_one_degree(self):
        """One degree of longitude at equator ≈ 111.32 km."""
        dist = haversine(0, 0, 0, 1)
        assert 110 < dist < 113

    def test_symmetric(self):
        """haversine(A, B) == haversine(B, A)."""
        d1 = haversine(35.0, 139.0, 43.0, 141.0)
        d2 = haversine(43.0, 141.0, 35.0, 139.0)
        assert abs(d1 - d2) < 1e-10


# ---------------------------------------------------------------------------
# bearing
# ---------------------------------------------------------------------------

class TestBearing:
    """Test initial bearing calculation."""

    def test_due_north(self):
        """Moving north: bearing should be ~0 degrees."""
        b = bearing(35.0, 139.0, 36.0, 139.0)
        assert abs(b) < 1 or abs(b - 360) < 1

    def test_due_east(self):
        """Moving east at equator: bearing should be ~90 degrees."""
        b = bearing(0, 0, 0, 1)
        assert abs(b - 90) < 1

    def test_due_south(self):
        """Moving south: bearing should be ~180 degrees."""
        b = bearing(36.0, 139.0, 35.0, 139.0)
        assert abs(b - 180) < 1

    def test_due_west(self):
        """Moving west at equator: bearing should be ~270 degrees."""
        b = bearing(0, 1, 0, 0)
        assert abs(b - 270) < 1

    def test_range_0_360(self):
        """Bearing should always be in [0, 360)."""
        b = bearing(35.0, 139.0, 34.0, 138.0)
        assert 0 <= b < 360


# ---------------------------------------------------------------------------
# is_ahead
# ---------------------------------------------------------------------------

class TestIsAhead:
    """Test forward-cone direction filter."""

    def test_same_direction(self):
        """POI at exactly the course direction is ahead."""
        assert is_ahead(90, 90) is True

    def test_within_threshold(self):
        """POI within ±45° is ahead."""
        assert is_ahead(90, 120) is True
        assert is_ahead(90, 60) is True

    def test_outside_threshold(self):
        """POI outside ±45° is not ahead."""
        assert is_ahead(90, 180) is False
        assert is_ahead(90, 350) is False

    def test_wrap_around_360(self):
        """Wrap-around: course=350, POI bearing=10 (diff=20)."""
        assert is_ahead(350, 10) is True

    def test_wrap_around_not_ahead(self):
        """Wrap-around: course=350, POI bearing=200 is behind."""
        assert is_ahead(350, 200) is False

    def test_boundary_exactly_threshold(self):
        """POI at exactly the threshold angle is ahead (<=)."""
        assert is_ahead(0, 45) is True
        assert is_ahead(0, 315) is True

    def test_custom_threshold(self):
        """Custom threshold of 30 degrees."""
        assert is_ahead(0, 25, threshold=30) is True
        assert is_ahead(0, 35, threshold=30) is False
