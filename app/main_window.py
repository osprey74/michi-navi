"""Main application window for Michi-Navi."""

import math
from datetime import datetime

from PySide6.QtCore import Qt, QEvent, QTimer
from PySide6.QtWidgets import QHBoxLayout, QMainWindow, QVBoxLayout, QWidget

from app.core.geo_utils import bearing, haversine, is_ahead
from app.data.database import init_db
from app.widgets.info_panel import InfoPanel
from app.widgets.map_widget import MapWidget
from app.widgets.status_bar import StatusBar


class MainWindow(QMainWindow):
    """Main window with 3-area layout for 800x480 touchscreen.

    Layout:
        ┌──────────────────────────────────────────┐
        │ StatusBar (40px)                         │
        ├──────────────────────┬───────────────────┤
        │ MapWidget            │ InfoPanel (280px) │
        │ (expanding)          │                   │
        └──────────────────────┴───────────────────┘
    """

    WINDOW_WIDTH = 800
    WINDOW_HEIGHT = 480
    TITLE = "Michi-Navi ミチナビ"

    # Simulation defaults: near Mikasa, Hokkaido
    _DEFAULT_LAT = 43.25
    _DEFAULT_LON = 141.80
    _DEFAULT_COURSE = 45.0

    # Movement step in degrees (~0.005 deg ≈ 500m)
    _MOVE_STEP = 0.005
    _ROTATE_STEP = 15.0
    _SEARCH_RADIUS_KM = 50.0

    def __init__(self):
        super().__init__()
        self.setWindowTitle(self.TITLE)
        self.setFixedSize(self.WINDOW_WIDTH, self.WINDOW_HEIGHT)

        # Simulated state
        self._lat = self._DEFAULT_LAT
        self._lon = self._DEFAULT_LON
        self._course = self._DEFAULT_COURSE
        self._speed = 60.0  # km/h

        self._setup_ui()
        self._apply_style()
        self._init_db()

        # Grab all keyboard input at the window level
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.grabKeyboard()

        # Clock timer
        self._clock_timer = QTimer(self)
        self._clock_timer.timeout.connect(self._update_clock)
        self._clock_timer.start(1000)

        # Initial update
        self._refresh()

    def _setup_ui(self):
        central = QWidget()
        self.setCentralWidget(central)

        root_layout = QVBoxLayout(central)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)

        # StatusBar (top, 40px)
        self.status_bar = StatusBar()
        root_layout.addWidget(self.status_bar)

        # Bottom area: MapWidget (left, expanding) + InfoPanel (right, 280px)
        body = QWidget()
        body_layout = QHBoxLayout(body)
        body_layout.setContentsMargins(0, 0, 0, 0)
        body_layout.setSpacing(0)

        self.map_widget = MapWidget()
        self.info_panel = InfoPanel()

        body_layout.addWidget(self.map_widget, 1)
        body_layout.addWidget(self.info_panel, 0)

        root_layout.addWidget(body, 1)

    def _init_db(self):
        """Open the station database."""
        try:
            self._db = init_db()
        except Exception:
            self._db = None

    def _apply_style(self):
        self.setStyleSheet("""
            QMainWindow, QWidget {
                background-color: #FFFFFF;
                color: #2C3E50;
            }
            #StatusBar {
                background-color: #3C7B91;
                color: #FFFFFF;
                font-size: 13px;
            }
            #StatusBar QLabel {
                color: #FFFFFF;
                background: transparent;
                padding: 0 6px;
            }
            #InfoPanel {
                background-color: #F5F7FA;
                border-left: 1px solid #D5D8DC;
            }
            #infoPanelHeader {
                font-size: 15px;
                font-weight: bold;
                color: #2C3E50;
            }
            #infoPanelFooter {
                color: #888888;
                font-size: 11px;
                padding-top: 4px;
            }
            #stationScroll {
                background: transparent;
            }
        """)

    # ------------------------------------------------------------------
    # Keyboard controls
    # ------------------------------------------------------------------

    def keyPressEvent(self, event):
        key = event.key()
        moved = True

        if key == Qt.Key.Key_Up:
            rad = math.radians(self._course)
            self._lat += self._MOVE_STEP * math.cos(rad)
            self._lon += self._MOVE_STEP * math.sin(rad)
        elif key == Qt.Key.Key_Down:
            rad = math.radians(self._course)
            self._lat -= self._MOVE_STEP * math.cos(rad)
            self._lon -= self._MOVE_STEP * math.sin(rad)
        elif key == Qt.Key.Key_Left:
            rad = math.radians(self._course - 90)
            self._lat += self._MOVE_STEP * math.cos(rad)
            self._lon += self._MOVE_STEP * math.sin(rad)
        elif key == Qt.Key.Key_Right:
            rad = math.radians(self._course + 90)
            self._lat += self._MOVE_STEP * math.cos(rad)
            self._lon += self._MOVE_STEP * math.sin(rad)
        elif key == Qt.Key.Key_Q:
            self._course = (self._course - self._ROTATE_STEP) % 360
        elif key == Qt.Key.Key_E:
            self._course = (self._course + self._ROTATE_STEP) % 360
        elif key == Qt.Key.Key_Plus or key == Qt.Key.Key_Equal:
            self.map_widget.set_zoom(self.map_widget.zoom + 1)
        elif key == Qt.Key.Key_Minus:
            self.map_widget.set_zoom(self.map_widget.zoom - 1)
        elif key == Qt.Key.Key_Space:
            self.map_widget.return_to_gps()
        else:
            moved = False
            super().keyPressEvent(event)

        if moved:
            # Keyboard movement = simulated GPS, re-enable auto-follow
            self.map_widget.return_to_gps()
            self._refresh()

    # ------------------------------------------------------------------
    # Data & display refresh
    # ------------------------------------------------------------------

    def _query_nearby(self) -> list[tuple[str, float, float, float, float]]:
        """Query all nearby stations from database (no direction filter)."""
        if not self._db:
            return []

        delta = 0.5  # ~50km
        rows = self._db.execute(
            """
            SELECT s.name, s.latitude, s.longitude
            FROM roadside_stations s
            JOIN stations_rtree r ON r.id = CAST(s.id AS INTEGER)
            WHERE r.min_lat >= ? AND r.max_lat <= ?
              AND r.min_lon >= ? AND r.max_lon <= ?
            """,
            (
                self._lat - delta, self._lat + delta,
                self._lon - delta, self._lon + delta,
            ),
        ).fetchall()

        results = []
        for row in rows:
            name, slat, slon = row["name"], row["latitude"], row["longitude"]
            dist = haversine(self._lat, self._lon, slat, slon)
            if dist > self._SEARCH_RADIUS_KM:
                continue
            brg = bearing(self._lat, self._lon, slat, slon)
            results.append((name, slat, slon, dist, brg))

        results.sort(key=lambda x: x[3])
        return results

    def _refresh(self):
        """Refresh all widgets with current state."""
        all_nearby = self._query_nearby()
        ahead = [(n, la, lo, d, b) for n, la, lo, d, b in all_nearby
                 if is_ahead(self._course, b)][:10]

        self.status_bar.update_position(self._lat, self._lon, self._speed, self._course)
        self.map_widget.set_position(self._lat, self._lon, self._course)
        self.map_widget.set_stations(all_nearby)  # All stations on map
        self.info_panel.update_stations(ahead)     # Only ahead in list

    def _update_clock(self):
        self.status_bar.update_time(datetime.now().strftime("%H:%M:%S"))
