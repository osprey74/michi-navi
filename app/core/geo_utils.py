"""Geographic utility functions for Michi-Navi.

Provides tile coordinate conversion, distance/bearing calculations,
and direction filtering for the map engine and POI search.
"""

import math

# Earth radius in km (mean)
_EARTH_RADIUS_KM = 6371.0


def deg2tile(lat_deg: float, lon_deg: float, zoom: int) -> tuple[int, int]:
    """Convert latitude/longitude to OSM slippy-map tile coordinates.

    Args:
        lat_deg: Latitude in degrees.
        lon_deg: Longitude in degrees.
        zoom: Zoom level (0-18).

    Returns:
        (x, y) tile coordinates.
    """
    lat_rad = math.radians(lat_deg)
    n = 2.0 ** zoom
    x = int((lon_deg + 180.0) / 360.0 * n)
    y = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return x, y


def tile2deg(x: int, y: int, zoom: int) -> tuple[float, float]:
    """Convert tile coordinates to the north-west corner lat/lon.

    Args:
        x: Tile x coordinate.
        y: Tile y coordinate.
        zoom: Zoom level (0-18).

    Returns:
        (lat_deg, lon_deg) of the tile's north-west corner.
    """
    n = 2.0 ** zoom
    lon_deg = x / n * 360.0 - 180.0
    lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * y / n)))
    lat_deg = math.degrees(lat_rad)
    return lat_deg, lon_deg


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the great-circle distance between two points (km).

    Uses the Haversine formula with a spherical Earth model.

    Args:
        lat1, lon1: First point in degrees.
        lat2, lon2: Second point in degrees.

    Returns:
        Distance in kilometres.
    """
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )
    return _EARTH_RADIUS_KM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the initial bearing from point 1 to point 2.

    Args:
        lat1, lon1: Origin point in degrees.
        lat2, lon2: Destination point in degrees.

    Returns:
        Bearing in degrees (0-360, clockwise from north).
    """
    dlon = math.radians(lon2 - lon1)
    x = math.sin(dlon) * math.cos(math.radians(lat2))
    y = (
        math.cos(math.radians(lat1)) * math.sin(math.radians(lat2))
        - math.sin(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.cos(dlon)
    )
    return (math.degrees(math.atan2(x, y)) + 360) % 360


def is_ahead(course: float, bearing_to_poi: float, threshold: float = 45) -> bool:
    """Check whether a POI is within the forward cone of travel.

    Args:
        course: Current heading in degrees (0-360).
        bearing_to_poi: Bearing from current position to the POI (0-360).
        threshold: Half-angle of the forward cone in degrees.

    Returns:
        True if the POI is within ±threshold of the course.
    """
    diff = abs(course - bearing_to_poi)
    if diff > 180:
        diff = 360 - diff
    return diff <= threshold
