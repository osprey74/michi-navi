"""InfoPanel widget - roadside station list and tourism information."""

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QFrame, QLabel, QScrollArea, QVBoxLayout, QWidget


# Cardinal direction labels
_CARDINALS = [
    "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
]


def _bearing_to_cardinal(deg: float) -> str:
    idx = round(deg / 22.5) % 16
    return _CARDINALS[idx]


class InfoPanel(QFrame):
    """Right-side information panel (280px width).

    Shows nearby roadside stations and local tourism info.
    """

    WIDTH = 280

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedWidth(self.WIDTH)
        self.setObjectName("InfoPanel")
        self._station_labels: list[QLabel] = []
        self._setup_ui()

    def _setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(8, 8, 8, 8)
        layout.setSpacing(4)

        header = QLabel("道の駅")
        header.setObjectName("infoPanelHeader")
        header.setAlignment(Qt.AlignmentFlag.AlignLeft)
        layout.addWidget(header)

        # Scrollable station list
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setObjectName("stationScroll")

        self._list_widget = QWidget()
        self._list_layout = QVBoxLayout(self._list_widget)
        self._list_layout.setContentsMargins(0, 0, 0, 0)
        self._list_layout.setSpacing(2)
        self._list_layout.addStretch()

        scroll.setWidget(self._list_widget)
        layout.addWidget(scroll, 1)

        # Status footer
        self._footer = QLabel("")
        self._footer.setObjectName("infoPanelFooter")
        self._footer.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self._footer)

    def update_stations(self, stations: list[tuple[str, float, float, float, float]]):
        """Update the station list.

        Args:
            stations: list of (name, lat, lon, distance_km, bearing_deg)
        """
        # Clear existing labels
        for label in self._station_labels:
            self._list_layout.removeWidget(label)
            label.deleteLater()
        self._station_labels.clear()

        # Insert before the stretch
        for i, (name, _lat, _lon, dist_km, brg) in enumerate(stations):
            cardinal = _bearing_to_cardinal(brg)
            short_name = name.replace("道の駅", "").strip()

            text = (
                f"<b>{name}</b><br>"
                f"<span style='color:#555'>"
                f"  {dist_km:.1f} km {cardinal}"
                f"</span>"
            )
            label = QLabel(text)
            label.setWordWrap(True)
            label.setObjectName("stationItem")
            label.setStyleSheet(
                "QLabel {"
                "  background: #FFFFFF;"
                "  border: 1px solid #E0E0E0;"
                "  border-radius: 4px;"
                "  padding: 6px 8px;"
                "  font-size: 12px;"
                "}"
            )
            self._station_labels.append(label)
            self._list_layout.insertWidget(i, label)

        count = len(stations)
        self._footer.setText(f"前方 {count} 件" if count else "前方に道の駅なし")
