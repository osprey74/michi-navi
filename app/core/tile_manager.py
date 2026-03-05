"""TileManager - Two-tier cached OSM tile provider.

L1: In-memory LRU cache (max 512 QPixmap tiles, ~50 MB)
L2: Disk cache (tiles/{z}/{x}/{y}.png, capacity-based eviction, max 8 GB)
Background download via QThreadPool when both caches miss.
"""

import os
import time
from collections import OrderedDict
from pathlib import Path

from PySide6.QtCore import QObject, QRunnable, QThreadPool, Signal
from PySide6.QtGui import QPixmap

import requests

# Defaults
DEFAULT_TILE_DIR = Path(__file__).resolve().parents[2] / "tiles"
TILE_SIZE = 256
MAX_MEMORY_TILES = 512
MAX_DISK_BYTES = 8 * 1024 * 1024 * 1024  # 8 GB
TILE_URL_TEMPLATE = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
USER_AGENT = "Michi-Navi/1.0 (PySide6; https://github.com/michi-navi)"

# Rate limiting: minimum interval between network requests (seconds)
_MIN_REQUEST_INTERVAL = 0.05  # 20 req/s max


class _DownloadSignals(QObject):
    """Signals emitted by background tile download workers."""

    tile_loaded = Signal(int, int, int)  # z, x, y


class _DownloadWorker(QRunnable):
    """Background runnable that downloads a single tile to disk."""

    def __init__(self, z: int, x: int, y: int, tile_dir: Path, signals: _DownloadSignals):
        super().__init__()
        self.z, self.x, self.y = z, x, y
        self._tile_dir = tile_dir
        self._signals = signals
        self.setAutoDelete(True)

    def run(self):
        tile_path = self._tile_dir / str(self.z) / str(self.x) / f"{self.y}.png"
        if tile_path.exists():
            self._signals.tile_loaded.emit(self.z, self.x, self.y)
            return

        url = TILE_URL_TEMPLATE.format(z=self.z, x=self.x, y=self.y)
        try:
            resp = requests.get(url, timeout=10, headers={"User-Agent": USER_AGENT})
            if resp.status_code == 200 and resp.content:
                tile_path.parent.mkdir(parents=True, exist_ok=True)
                tile_path.write_bytes(resp.content)
                self._signals.tile_loaded.emit(self.z, self.x, self.y)
        except Exception:
            pass  # Silently fail; tile will be retried on next request


class TileManager(QObject):
    """Two-tier cached tile manager with background downloads.

    Usage:
        tm = TileManager()
        tm.tile_ready.connect(on_tile_available)
        pixmap = tm.get_tile(z, x, y)
        # Returns QPixmap immediately if cached, else None and downloads in BG.
    """

    tile_ready = Signal(int, int, int)

    def __init__(
        self,
        tile_dir: Path | None = None,
        max_memory: int = MAX_MEMORY_TILES,
        max_disk_bytes: int = MAX_DISK_BYTES,
        parent: QObject | None = None,
    ):
        super().__init__(parent)
        self._tile_dir = tile_dir or DEFAULT_TILE_DIR
        self._tile_dir.mkdir(parents=True, exist_ok=True)

        self._max_memory = max_memory
        self._max_disk_bytes = max_disk_bytes

        # L1: Memory cache (LRU via OrderedDict)
        self._mem_cache: OrderedDict[tuple[int, int, int], QPixmap] = OrderedDict()

        # Pending downloads (avoid duplicate requests)
        self._pending: set[tuple[int, int, int]] = set()

        # Thread pool for background downloads
        self._pool = QThreadPool()
        self._pool.setMaxThreadCount(4)

        # Shared signals for workers
        self._dl_signals = _DownloadSignals()
        self._dl_signals.tile_loaded.connect(self._on_downloaded)

        # Rate limiting
        self._last_request_time = 0.0

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def get_tile(self, z: int, x: int, y: int) -> QPixmap | None:
        """Get a tile pixmap. Returns None if not yet available.

        Checks L1 memory, then L2 disk, then schedules background download.
        """
        key = (z, x, y)

        # L1: Memory cache hit
        if key in self._mem_cache:
            self._mem_cache.move_to_end(key)
            return self._mem_cache[key]

        # L2: Disk cache hit
        tile_path = self._tile_path(z, x, y)
        if tile_path.exists():
            pm = QPixmap(str(tile_path))
            if not pm.isNull():
                self._mem_put(key, pm)
                return pm

        # Cache miss -> schedule download
        self._schedule_download(z, x, y)
        return None

    def clear_memory_cache(self):
        """Clear the L1 memory cache."""
        self._mem_cache.clear()

    def disk_cache_size(self) -> int:
        """Return total size of disk cache in bytes."""
        total = 0
        for dirpath, _dirnames, filenames in os.walk(self._tile_dir):
            for f in filenames:
                if f.endswith(".png"):
                    total += os.path.getsize(os.path.join(dirpath, f))
        return total

    def evict_disk_cache(self):
        """Remove oldest tiles until disk usage is under the limit."""
        if self._max_disk_bytes <= 0:
            return

        # Collect all tile files with mtime
        tiles: list[tuple[float, str, int]] = []
        for dirpath, _dirnames, filenames in os.walk(self._tile_dir):
            for f in filenames:
                if f.endswith(".png"):
                    full = os.path.join(dirpath, f)
                    stat = os.stat(full)
                    tiles.append((stat.st_mtime, full, stat.st_size))

        total = sum(s for _, _, s in tiles)
        if total <= self._max_disk_bytes:
            return

        # Sort by mtime ascending (oldest first)
        tiles.sort()
        for _mtime, path, size in tiles:
            if total <= self._max_disk_bytes:
                break
            try:
                os.remove(path)
                total -= size
            except OSError:
                pass

    @property
    def memory_cache_count(self) -> int:
        return len(self._mem_cache)

    @property
    def pending_count(self) -> int:
        return len(self._pending)

    # ------------------------------------------------------------------
    # Internals
    # ------------------------------------------------------------------

    def _tile_path(self, z: int, x: int, y: int) -> Path:
        return self._tile_dir / str(z) / str(x) / f"{y}.png"

    def _mem_put(self, key: tuple[int, int, int], pm: QPixmap):
        """Add pixmap to L1 cache, evicting LRU entries if full."""
        self._mem_cache[key] = pm
        self._mem_cache.move_to_end(key)
        while len(self._mem_cache) > self._max_memory:
            self._mem_cache.popitem(last=False)

    def _schedule_download(self, z: int, x: int, y: int):
        key = (z, x, y)
        if key in self._pending:
            return

        # Rate limiting
        now = time.monotonic()
        if now - self._last_request_time < _MIN_REQUEST_INTERVAL:
            return
        self._last_request_time = now

        self._pending.add(key)
        worker = _DownloadWorker(z, x, y, self._tile_dir, self._dl_signals)
        self._pool.start(worker)

    def _on_downloaded(self, z: int, x: int, y: int):
        """Called when a background download completes."""
        key = (z, x, y)
        self._pending.discard(key)

        # Load into L1
        tile_path = self._tile_path(z, x, y)
        if tile_path.exists():
            pm = QPixmap(str(tile_path))
            if not pm.isNull():
                self._mem_put(key, pm)

        # Notify listeners (MapWidget will repaint)
        self.tile_ready.emit(z, x, y)
