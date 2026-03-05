"""StatusBar widget - GPS status, coordinates, speed, bearing, time display."""

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QFrame, QHBoxLayout, QLabel


# Cardinal direction labels
_CARDINALS = [
    "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
]


class StatusBar(QFrame):
    """Top status bar (40px height).

    Displays GPS signal status, coordinates, speed, bearing, and time.
    """

    HEIGHT = 40

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedHeight(self.HEIGHT)
        self.setObjectName("StatusBar")
        self._setup_ui()

    def _setup_ui(self):
        layout = QHBoxLayout(self)
        layout.setContentsMargins(8, 0, 8, 0)

        self._gps_label = QLabel("[GPS--]")
        self._gps_label.setObjectName("gpsStatus")

        self._coord_label = QLabel("---.--N ---.--E")
        self._coord_label.setObjectName("coordinates")

        self._speed_label = QLabel("-- km/h")
        self._speed_label.setObjectName("speed")

        self._bearing_label = QLabel("---")
        self._bearing_label.setObjectName("bearing")

        self._time_label = QLabel("--:--")
        self._time_label.setObjectName("time")
        self._time_label.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)

        for w in (self._gps_label, self._coord_label, self._speed_label, self._bearing_label):
            layout.addWidget(w)

        layout.addStretch()
        layout.addWidget(self._time_label)

    def update_position(self, lat: float, lon: float, speed_kmh: float, course: float):
        """Update the displayed position information."""
        self._gps_label.setText("[SIM]")

        ns = "N" if lat >= 0 else "S"
        ew = "E" if lon >= 0 else "W"
        self._coord_label.setText(f"{abs(lat):.4f}{ns} {abs(lon):.4f}{ew}")

        self._speed_label.setText(f"{speed_kmh:.0f} km/h")

        cardinal_idx = round(course / 22.5) % 16
        cardinal = _CARDINALS[cardinal_idx]
        self._bearing_label.setText(f"{cardinal} ({course:.0f}\u00b0)")

    def update_time(self, time_str: str):
        """Update the displayed time."""
        self._time_label.setText(time_str)
