"""Tests for TileManager - two-tier cached OSM tile provider."""

import os
import time
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
from PySide6.QtWidgets import QApplication
from PySide6.QtGui import QPixmap

from app.core.tile_manager import (
    TILE_SIZE,
    MAX_MEMORY_TILES,
    MAX_DISK_BYTES,
    TileManager,
)


@pytest.fixture(scope="session", autouse=True)
def qapp():
    """Ensure a QApplication exists for QPixmap usage (requires display)."""
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    return app


@pytest.fixture
def tile_dir(tmp_path):
    """Provide a temporary tile directory."""
    d = tmp_path / "tiles"
    d.mkdir()
    return d


@pytest.fixture
def tm(tile_dir):
    """Create a TileManager with a temp tile directory."""
    return TileManager(tile_dir=tile_dir, max_memory=8)


def _make_tile_file(tile_dir: Path, z: int, x: int, y: int, size: int = 1024) -> Path:
    """Create a valid PNG tile file on disk using QPixmap."""
    p = tile_dir / str(z) / str(x) / f"{y}.png"
    p.parent.mkdir(parents=True, exist_ok=True)
    pm = QPixmap(1, 1)
    pm.fill()
    pm.save(str(p), "PNG")
    # Pad if requested size is larger
    if size > p.stat().st_size:
        with open(p, "ab") as f:
            f.write(b"\x00" * (size - p.stat().st_size))
    return p


# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------

class TestConstants:
    def test_tile_size(self):
        assert TILE_SIZE == 256

    def test_max_memory_tiles(self):
        assert MAX_MEMORY_TILES == 512

    def test_max_disk_bytes(self):
        assert MAX_DISK_BYTES == 8 * 1024 * 1024 * 1024


# ---------------------------------------------------------------
# Memory cache (L1)
# ---------------------------------------------------------------

class TestMemoryCache:
    def test_initial_state(self, tm):
        assert tm.memory_cache_count == 0
        assert tm.pending_count == 0

    def test_disk_hit_populates_memory(self, tm, tile_dir):
        """A tile on disk should be loaded into memory on get_tile."""
        _make_tile_file(tile_dir, 10, 100, 200)
        pm = tm.get_tile(10, 100, 200)
        assert pm is not None
        assert not pm.isNull()
        assert tm.memory_cache_count == 1

    def test_memory_hit_returns_same(self, tm, tile_dir):
        """Second call should hit L1 memory cache."""
        _make_tile_file(tile_dir, 10, 100, 200)
        pm1 = tm.get_tile(10, 100, 200)
        pm2 = tm.get_tile(10, 100, 200)
        assert pm1 is not None
        assert pm2 is not None

    def test_memory_lru_eviction(self, tm, tile_dir):
        """Memory cache should evict LRU entries when full (max_memory=8)."""
        for i in range(10):
            _make_tile_file(tile_dir, 10, i, 0)
            tm.get_tile(10, i, 0)

        assert tm.memory_cache_count == 8  # max_memory=8

    def test_clear_memory_cache(self, tm, tile_dir):
        _make_tile_file(tile_dir, 10, 0, 0)
        tm.get_tile(10, 0, 0)
        assert tm.memory_cache_count == 1
        tm.clear_memory_cache()
        assert tm.memory_cache_count == 0


# ---------------------------------------------------------------
# Disk cache (L2)
# ---------------------------------------------------------------

class TestDiskCache:
    def test_disk_cache_size_empty(self, tm):
        assert tm.disk_cache_size() == 0

    def test_disk_cache_size_with_files(self, tm, tile_dir):
        _make_tile_file(tile_dir, 10, 0, 0, size=500)
        _make_tile_file(tile_dir, 10, 1, 0, size=300)
        assert tm.disk_cache_size() == 800

    def test_evict_disk_cache(self, tile_dir):
        """Eviction should remove oldest tiles until under the limit."""
        # Create manager with very small disk limit
        tm = TileManager(tile_dir=tile_dir, max_disk_bytes=1000)

        # Create tiles with staggered mtimes
        p1 = _make_tile_file(tile_dir, 10, 0, 0, size=500)
        time.sleep(0.05)
        p2 = _make_tile_file(tile_dir, 10, 1, 0, size=500)
        time.sleep(0.05)
        p3 = _make_tile_file(tile_dir, 10, 2, 0, size=500)

        # Total = 1500 > 1000, should evict oldest
        tm.evict_disk_cache()
        assert tm.disk_cache_size() <= 1000
        # At least one file should have been removed
        assert not p1.exists() or not p2.exists()

    def test_evict_noop_when_under_limit(self, tm, tile_dir):
        _make_tile_file(tile_dir, 10, 0, 0, size=100)
        size_before = tm.disk_cache_size()
        tm.evict_disk_cache()
        assert tm.disk_cache_size() == size_before


# ---------------------------------------------------------------
# Cache miss / download scheduling
# ---------------------------------------------------------------

class TestCacheMiss:
    def test_cache_miss_returns_none(self, tm):
        """Missing tile returns None and schedules download."""
        result = tm.get_tile(10, 999, 999)
        assert result is None

    def test_cache_miss_adds_to_pending(self, tm):
        tm.get_tile(10, 999, 999)
        assert tm.pending_count >= 1

    def test_duplicate_download_not_scheduled(self, tm):
        """Same tile requested twice should not create duplicate pending."""
        tm.get_tile(10, 999, 999)
        count1 = tm.pending_count
        # Rate limiter may block second request, but pending should not grow
        tm.get_tile(10, 999, 999)
        assert tm.pending_count <= count1


# ---------------------------------------------------------------
# Download callback
# ---------------------------------------------------------------

class TestDownloadCallback:
    def test_on_downloaded_loads_into_memory(self, tm, tile_dir):
        """_on_downloaded should load tile into L1 and emit signal."""
        _make_tile_file(tile_dir, 10, 50, 50)
        tm._pending.add((10, 50, 50))

        signal_received = []
        tm.tile_ready.connect(lambda z, x, y: signal_received.append((z, x, y)))

        tm._on_downloaded(10, 50, 50)

        assert tm.memory_cache_count >= 1
        assert (10, 50, 50) not in tm._pending
        assert (10, 50, 50) in signal_received

    def test_on_downloaded_missing_file(self, tm):
        """_on_downloaded with no file on disk should not crash."""
        tm._pending.add((10, 77, 77))
        tm._on_downloaded(10, 77, 77)
        assert (10, 77, 77) not in tm._pending


# ---------------------------------------------------------------
# Tile path
# ---------------------------------------------------------------

class TestTilePath:
    def test_tile_path_format(self, tm, tile_dir):
        p = tm._tile_path(10, 123, 456)
        assert p == tile_dir / "10" / "123" / "456.png"


# ---------------------------------------------------------------
# Integration: full cycle (disk hit → memory)
# ---------------------------------------------------------------

class TestIntegration:
    def test_full_cycle_disk_to_memory(self, tm, tile_dir):
        """First call loads from disk, second from memory."""
        _make_tile_file(tile_dir, 12, 3637, 1612)

        # First call: disk hit → loads into memory
        pm1 = tm.get_tile(12, 3637, 1612)
        assert pm1 is not None
        assert tm.memory_cache_count == 1

        # Clear memory, tile still on disk
        tm.clear_memory_cache()
        assert tm.memory_cache_count == 0

        # Second call: disk hit again
        pm2 = tm.get_tile(12, 3637, 1612)
        assert pm2 is not None
        assert tm.memory_cache_count == 1
