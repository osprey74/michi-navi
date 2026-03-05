# Michi-Navi

A Raspberry Pi 4-based in-car drive assistant that displays your real-time position on an OpenStreetMap and suggests nearby roadside stations (道の駅) and local tourism spots along your route.

## Features

- **Real-time map display** — OpenStreetMap tiles rendered natively via PySide6/QPainter with current position and heading overlay
- **Roadside station suggestions** — Lists stations within ±45° of your heading, sorted by distance
- **Local tourism info** — Shows sightseeing highlights for the municipality you're currently in
- **Offline support** — Pre-cached map tiles and local POI database for use without connectivity
- **Speed / heading / altitude display** — Live GPS telemetry on a status bar
- **Touch-friendly UI** — Pinch zoom, drag pan, and tap-to-view details on a 5" touchscreen

## Tech Stack

| Component | Technology |
|-----------|------------|
| Platform | Raspberry Pi 4 Model B |
| OS | Raspberry Pi OS Lite 64-bit (Bookworm) |
| Language | Python 3.11+ |
| GUI | PySide6 (Qt 6) |
| Map tiles | OpenStreetMap raster tiles |
| GPS | gpsd + USB GPS dongle (NEO-M8N / VK-162) |
| Database | SQLite with R-Tree spatial index |

## Project Structure

```
Michi-Navi/
├── main.py                  # Entry point
├── app/
│   ├── widgets/             # MapWidget, InfoPanel, StatusBar, DetailPanel
│   ├── core/                # GPSManager, TileManager, POISearchEngine, GeoUtils
│   ├── data/                # DB manager, data importer
│   └── config/              # Settings, color themes
├── data/                    # SQLite DB & tile cache (gitignored)
├── scripts/                 # Data import, tile download, Pi setup
├── fonts/                   # Japanese fonts (gitignored)
├── resources/               # Icons, map markers
├── tests/                   # Unit tests
└── docs/                    # Design documents
```

## Development Status

| Phase | Status |
|-------|--------|
| Phase 1: Foundation | 100% |
| Phase 2: Map Engine | 100% |
| Phase 3: GPS Integration | 0% |
| Phase 4: POI Search & Display | 0% |
| Phase 5: Polish & In-Car Setup | 0% |

**Current:** Phases 1-2 complete. Interactive demo available with OSM tile rendering, roadside station markers (1,204 stations), keyboard/mouse/touch navigation, and two-tier tile cache.

## Quick Start (PC Demo)

```bash
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install PySide6 requests
python scripts/import_stations.py  # Import 1,204 roadside stations
python main.py
```

**Controls:** Arrow keys to move, Q/E to rotate, +/- to zoom, mouse drag to pan, double-click to re-center, mouse wheel to zoom.

## Requirements

```
pip install -r requirements.txt
```

## License

TBD

## Map Attribution

This application uses map tiles from [OpenStreetMap](https://www.openstreetmap.org/).
© OpenStreetMap contributors. Tiles are provided under the [ODbL](https://opendatacommons.org/licenses/odbl/) license.
