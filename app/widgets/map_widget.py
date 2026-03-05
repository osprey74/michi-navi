"""MapWidget - OSM tile-based map display area.

Rendering pipeline (Phase 2.2):
  1. Tile range calculation based on widget size and center coordinates
  2. Tile retrieval via TileManager (L1 memory → L2 disk → BG download)
  3. QPainter tile drawing with subpixel offset for smooth scrolling
  4. Overlay layers: forward cone → station pins → position marker → scale bar → attribution

Touch operations (Phase 2.3):
  - Pinch in/out: zoom level change (8-18)
  - Drag: pan map (auto-follow pauses)
  - Double tap: return to GPS position (resume auto-follow)
"""

import math

from PySide6.QtCore import Qt, QPointF, QRectF, Signal
from PySide6.QtGui import QPainter, QColor, QFont, QPen, QPolygonF, QBrush
from PySide6.QtWidgets import QWidget

from app.core.tile_manager import TileManager, TILE_SIZE

# Zoom limits per design spec (touch zoom 8-18, keyboard allows 5-18)
ZOOM_MIN = 5
ZOOM_MAX = 18

# Touch zoom limits (narrower range for pinch gestures)
TOUCH_ZOOM_MIN = 8
TOUCH_ZOOM_MAX = 18


class MapWidget(QWidget):
    """Main map display area (520x440 minimum).

    Renders OpenStreetMap tiles via TileManager with position and station overlays.
    Supports subpixel-accurate smooth scrolling via fractional tile offsets.

    Touch/mouse interactions:
      - Drag to pan (pauses auto-follow)
      - Pinch to zoom (touch) or mouse wheel
      - Double-tap/double-click to re-center on GPS position
    """

    # Emitted when user drags the map (auto-follow should pause)
    auto_follow_paused = Signal()
    # Emitted when user double-taps (auto-follow should resume)
    auto_follow_resumed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("MapWidget")
        self.setMinimumSize(520, 440)
        self.setAttribute(Qt.WidgetAttribute.WA_AcceptTouchEvents, True)

        # Current GPS position and heading (from GPS/simulation)
        self._gps_lat = 0.0
        self._gps_lon = 0.0
        self._course = 0.0
        self._zoom = 10

        # View center (may differ from GPS when panned)
        self._view_lat = 0.0
        self._view_lon = 0.0
        self._auto_follow = True

        # TileManager (L1 memory + L2 disk + BG download)
        self._tile_mgr = TileManager(parent=self)
        self._tile_mgr.tile_ready.connect(lambda *_: self.update())

        # Nearby stations: list of (name, lat, lon, distance_km, bearing_deg)
        self._stations: list[tuple[str, float, float, float, float]] = []

        # Drag state (mouse or single-finger touch)
        self._dragging = False
        self._drag_last: QPointF | None = None

        # Pinch zoom state
        self._pinch_active = False
        self._pinch_start_dist = 0.0
        self._pinch_start_zoom = 0

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def set_position(self, lat: float, lon: float, course: float):
        """Update GPS position. View follows if auto-follow is active."""
        self._gps_lat = lat
        self._gps_lon = lon
        self._course = course
        if self._auto_follow:
            self._view_lat = lat
            self._view_lon = lon
        self.update()

    def set_stations(self, stations: list[tuple[str, float, float, float, float]]):
        self._stations = stations
        self.update()

    def set_zoom(self, zoom: int):
        self._zoom = max(ZOOM_MIN, min(ZOOM_MAX, zoom))
        self.update()

    def return_to_gps(self):
        """Re-center the view on the current GPS position."""
        self._view_lat = self._gps_lat
        self._view_lon = self._gps_lon
        self._auto_follow = True
        self.auto_follow_resumed.emit()
        self.update()

    @property
    def zoom(self) -> int:
        return self._zoom

    @property
    def auto_follow(self) -> bool:
        return self._auto_follow

    @property
    def tile_manager(self) -> TileManager:
        return self._tile_mgr

    # ------------------------------------------------------------------
    # Coordinate conversion
    # ------------------------------------------------------------------

    @staticmethod
    def _geo_to_tile_frac_at(lat: float, lon: float, zoom: int) -> tuple[float, float]:
        """Convert lat/lon to fractional tile coordinates at given zoom."""
        n = 2.0 ** zoom
        tx = (lon + 180.0) / 360.0 * n
        ty = (1.0 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2.0 * n
        return tx, ty

    def _geo_to_tile_frac(self, lat: float, lon: float) -> tuple[float, float]:
        """Convert lat/lon to fractional tile coordinates at current zoom."""
        return self._geo_to_tile_frac_at(lat, lon, self._zoom)

    def _geo_to_pixel(self, lat: float, lon: float) -> QPointF:
        """Convert lat/lon to widget pixel coordinates.

        Uses the view center (which may differ from GPS position when panned).
        """
        w, h = self.width(), self.height()
        cx, cy = self._geo_to_tile_frac(self._view_lat, self._view_lon)
        tx, ty = self._geo_to_tile_frac(lat, lon)
        px = w / 2.0 + (tx - cx) * TILE_SIZE
        py = h / 2.0 + (ty - cy) * TILE_SIZE
        return QPointF(px, py)

    def _pixel_to_geo(self, px: float, py: float) -> tuple[float, float]:
        """Convert widget pixel coordinates back to lat/lon."""
        w, h = self.width(), self.height()
        n = 2.0 ** self._zoom
        cx, cy = self._geo_to_tile_frac(self._view_lat, self._view_lon)

        tx = cx + (px - w / 2.0) / TILE_SIZE
        ty = cy + (py - h / 2.0) / TILE_SIZE

        lon = tx / n * 360.0 - 180.0
        lat = math.degrees(math.atan(math.sinh(math.pi * (1.0 - 2.0 * ty / n))))
        return lat, lon

    # ------------------------------------------------------------------
    # Paint
    # ------------------------------------------------------------------

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        w, h = self.width(), self.height()

        # Clip to widget bounds for clean edges
        painter.setClipRect(0, 0, w, h)

        # Rendering pipeline: tiles → overlays → HUD
        self._draw_tiles(painter, w, h)
        self._draw_forward_cone(painter, w, h)
        self._draw_stations(painter, w, h)
        self._draw_position_marker(painter, w, h)
        self._draw_scale(painter, w, h)
        self._draw_attribution(painter, w, h)
        self._draw_hud(painter)

        painter.end()

    # ------------------------------------------------------------------
    # Layer 1: Tile grid
    # ------------------------------------------------------------------

    def _draw_tiles(self, painter: QPainter, w: int, h: int):
        """Draw OSM tiles with subpixel offset for smooth scrolling.

        The center of the widget maps to the fractional tile position of
        the current lat/lon.  Each tile is placed at a float pixel offset,
        ensuring smooth panning without snapping to integer boundaries.
        """
        z = self._zoom
        n = 2.0 ** z
        n_int = int(n)

        # Fractional tile position of view center
        cx, cy = self._geo_to_tile_frac(self._view_lat, self._view_lon)

        # How many tiles we need in each direction to cover the widget
        half_x = w / TILE_SIZE / 2 + 1
        half_y = h / TILE_SIZE / 2 + 1

        tx_min = int(math.floor(cx - half_x))
        tx_max = int(math.ceil(cx + half_x))
        ty_min = int(math.floor(cy - half_y))
        ty_max = int(math.ceil(cy + half_y))

        placeholder_color = QColor("#E8EDF2")
        grid_pen = QPen(QColor("#D0D0D0"), 0.5)

        for tx in range(tx_min, tx_max + 1):
            for ty in range(ty_min, ty_max + 1):
                # Skip tiles outside the valid Y range
                if ty < 0 or ty >= n_int:
                    continue

                # Wrap X for world wraparound
                wrapped_tx = tx % n_int

                # Subpixel position: the fractional part of (tx - cx) gives
                # the subpixel offset, enabling smooth scrolling
                px = w / 2.0 + (tx - cx) * TILE_SIZE
                py = h / 2.0 + (ty - cy) * TILE_SIZE

                # Quick reject: skip tiles entirely outside the widget
                if px + TILE_SIZE < 0 or px > w or py + TILE_SIZE < 0 or py > h:
                    continue

                pm = self._tile_mgr.get_tile(z, wrapped_tx, ty)
                if pm:
                    painter.drawPixmap(QPointF(px, py), pm)
                else:
                    # Placeholder for tiles still loading
                    painter.fillRect(QRectF(px, py, TILE_SIZE, TILE_SIZE), placeholder_color)
                    painter.setPen(grid_pen)
                    painter.drawRect(QRectF(px, py, TILE_SIZE, TILE_SIZE))

    # ------------------------------------------------------------------
    # Layer 2: Forward direction cone
    # ------------------------------------------------------------------

    def _draw_forward_cone(self, painter: QPainter, w: int, h: int):
        """Draw a translucent ±45° cone showing the forward direction."""
        gps_pt = self._geo_to_pixel(self._gps_lat, self._gps_lon)
        cx, cy = gps_pt.x(), gps_pt.y()
        radius = min(w, h) * 0.45

        # Convert heading to math angle (clockwise from north → CCW from east)
        a1 = math.radians(90 - self._course - 45)
        a2 = math.radians(90 - self._course + 45)

        cone = QPolygonF([
            QPointF(cx, cy),
            QPointF(cx + radius * math.cos(a1), cy - radius * math.sin(a1)),
            QPointF(cx + radius * math.cos(a2), cy - radius * math.sin(a2)),
        ])
        painter.setBrush(QBrush(QColor(60, 123, 145, 25)))
        painter.setPen(QPen(QColor(60, 123, 145, 60), 1, Qt.PenStyle.DashLine))
        painter.drawPolygon(cone)

    # ------------------------------------------------------------------
    # Layer 3: Station pins
    # ------------------------------------------------------------------

    def _draw_stations(self, painter: QPainter, w: int, h: int):
        """Draw roadside station pins with labels on the map."""
        pin_color = QColor("#27AE60")
        label_color = QColor("#1E8449")
        label_font = QFont("sans-serif", 8)
        painter.setFont(label_font)

        for name, lat, lon, dist_km, _brg in self._stations:
            pt = self._geo_to_pixel(lat, lon)

            # Skip stations outside visible area (with margin for label)
            if pt.x() < -20 or pt.x() > w + 20 or pt.y() < -20 or pt.y() > h + 20:
                continue

            # Shadow
            painter.setBrush(QBrush(QColor(0, 0, 0, 40)))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(pt + QPointF(1.5, 1.5), 7, 7)

            # Pin circle
            painter.setBrush(QBrush(pin_color))
            painter.setPen(QPen(QColor("#FFFFFF"), 1.5))
            painter.drawEllipse(pt, 6, 6)

            # Label with distance
            short_name = name.replace("道の駅", "").strip()
            label_text = f"{short_name} ({dist_km:.1f}km)"
            fm = painter.fontMetrics()
            tr = fm.boundingRect(label_text)
            lx = pt.x() + 10
            ly = pt.y() - 2

            # Label background
            bg = QRectF(lx - 2, ly - tr.height() + 2, tr.width() + 4, tr.height() + 2)
            painter.fillRect(bg, QColor(255, 255, 255, 210))
            painter.setPen(label_color)
            painter.drawText(QPointF(lx, ly), label_text)

    # ------------------------------------------------------------------
    # Layer 4: Current position marker
    # ------------------------------------------------------------------

    def _draw_position_marker(self, painter: QPainter, w: int, h: int):
        """Draw current GPS position: white circle with red directional arrow.

        When auto-follow is active the marker is at center; when panned,
        the marker shows the actual GPS position relative to the view.
        """
        gps_pt = self._geo_to_pixel(self._gps_lat, self._gps_lon)
        cx, cy = gps_pt.x(), gps_pt.y()

        # Skip if GPS position is far off-screen
        if cx < -50 or cx > w + 50 or cy < -50 or cy > h + 50:
            return

        # Heading angle (north=0°, clockwise) → math angle (east=0°, CCW)
        angle = math.radians(90 - self._course)

        # Directional arrow (isoceles triangle, ±25° spread)
        arrow_len = 16
        spread = math.radians(25)
        tip = QPointF(
            cx + arrow_len * math.cos(angle),
            cy - arrow_len * math.sin(angle),
        )
        left = QPointF(
            cx + (arrow_len * 0.4) * math.cos(angle + spread),
            cy - (arrow_len * 0.4) * math.sin(angle + spread),
        )
        right = QPointF(
            cx + (arrow_len * 0.4) * math.cos(angle - spread),
            cy - (arrow_len * 0.4) * math.sin(angle - spread),
        )

        # Arrow fill
        painter.setBrush(QBrush(QColor("#E74C3C")))
        painter.setPen(QPen(QColor("#FFFFFF"), 1.5))
        painter.drawPolygon(QPolygonF([tip, left, right]))

        # Center dot (position)
        painter.setBrush(QBrush(QColor("#E74C3C")))
        painter.setPen(QPen(QColor("#FFFFFF"), 2))
        painter.drawEllipse(QPointF(cx, cy), 7, 7)

    # ------------------------------------------------------------------
    # Layer 5: Scale bar
    # ------------------------------------------------------------------

    def _draw_scale(self, painter: QPainter, w: int, h: int):
        """Draw a scale bar in the bottom-right corner."""
        # km per pixel at current zoom and latitude
        km_pp = (40075.016 * math.cos(math.radians(self._lat))) / (
            2 ** self._zoom * TILE_SIZE
        )
        if km_pp <= 0:
            return

        target_km = 80 * km_pp  # target bar width ~80px
        nice_values = [0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50, 100, 200]
        scale_km = min(nice_values, key=lambda v: abs(v - target_km))
        bar_px = int(scale_km / km_pp)
        if bar_px <= 0:
            return

        x0 = w - bar_px - 20
        y = h - 28

        # Background
        painter.fillRect(
            QRectF(x0 - 4, y - 16, bar_px + 8, 26), QColor(255, 255, 255, 180)
        )

        # Bar and end caps
        bar_pen = QPen(QColor("#333333"), 2)
        painter.setPen(bar_pen)
        painter.drawLine(QPointF(x0, y), QPointF(x0 + bar_px, y))
        painter.drawLine(QPointF(x0, y - 4), QPointF(x0, y + 4))
        painter.drawLine(QPointF(x0 + bar_px, y - 4), QPointF(x0 + bar_px, y + 4))

        # Label
        painter.setFont(QFont("sans-serif", 8))
        label = f"{scale_km:.0f} km" if scale_km >= 1 else f"{scale_km * 1000:.0f} m"
        painter.drawText(
            QRectF(x0, y - 16, bar_px, 14), Qt.AlignmentFlag.AlignCenter, label
        )

    # ------------------------------------------------------------------
    # Layer 6: OSM attribution (required by tile usage policy)
    # ------------------------------------------------------------------

    def _draw_attribution(self, painter: QPainter, w: int, h: int):
        """Draw '© OpenStreetMap contributors' attribution text.

        Required by OSM tile usage policy:
        https://operations.osmfoundation.org/policies/tiles/
        """
        text = "\u00a9 OpenStreetMap contributors"
        painter.setFont(QFont("sans-serif", 8))
        fm = painter.fontMetrics()
        text_width = fm.horizontalAdvance(text) + 8
        text_height = fm.height() + 4

        rx = w - text_width - 4
        ry = h - text_height - 2

        painter.fillRect(QRectF(rx, ry, text_width, text_height), QColor(255, 255, 255, 190))
        painter.setPen(QColor("#333333"))
        painter.drawText(
            QRectF(rx, ry, text_width, text_height),
            Qt.AlignmentFlag.AlignCenter,
            text,
        )

    # ------------------------------------------------------------------
    # Layer 7: HUD (zoom level, controls hint)
    # ------------------------------------------------------------------

    def _draw_hud(self, painter: QPainter):
        """Draw heads-up display with zoom level and auto-follow status."""
        painter.setFont(QFont("sans-serif", 9))
        follow_icon = "\u25ce" if self._auto_follow else "\u25cb"  # ◎ or ○
        hud_text = (
            f"Z{self._zoom}  {follow_icon}"
            f"  \u2190\u2191\u2192\u2193:Move  Q/E:Rotate  +/-:Zoom"
        )
        fm = painter.fontMetrics()
        text_width = fm.horizontalAdvance(hud_text) + 12

        painter.fillRect(QRectF(4, 4, text_width, 18), QColor(255, 255, 255, 170))
        painter.setPen(QColor(0, 0, 0, 160))
        painter.drawText(
            QRectF(10, 4, text_width, 18),
            Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft,
            hud_text,
        )

    # ------------------------------------------------------------------
    # Touch & mouse input (Phase 2.3)
    # ------------------------------------------------------------------

    def _pause_auto_follow(self):
        """Pause auto-follow when user manually pans the map."""
        if self._auto_follow:
            self._auto_follow = False
            self.auto_follow_paused.emit()

    def _pan_by_pixels(self, dx: float, dy: float):
        """Pan the view by the given pixel delta."""
        n = 2.0 ** self._zoom
        cx, cy = self._geo_to_tile_frac(self._view_lat, self._view_lon)
        cx -= dx / TILE_SIZE
        cy -= dy / TILE_SIZE
        self._view_lon = cx / n * 360.0 - 180.0
        self._view_lat = math.degrees(
            math.atan(math.sinh(math.pi * (1.0 - 2.0 * cy / n)))
        )
        self.update()

    # -- Mouse events (also work for single-finger touch on desktop) ----

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self._dragging = True
            self._drag_last = event.position()
            event.accept()
        else:
            super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self._dragging and self._drag_last is not None:
            pos = event.position()
            dx = pos.x() - self._drag_last.x()
            dy = pos.y() - self._drag_last.y()
            self._drag_last = pos
            self._pause_auto_follow()
            self._pan_by_pixels(dx, dy)
            event.accept()
        else:
            super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self._dragging = False
            self._drag_last = None
            event.accept()
        else:
            super().mouseReleaseEvent(event)

    def mouseDoubleClickEvent(self, event):
        """Double-click/double-tap: return to GPS position."""
        if event.button() == Qt.MouseButton.LeftButton:
            self.return_to_gps()
            event.accept()
        else:
            super().mouseDoubleClickEvent(event)

    def wheelEvent(self, event):
        """Mouse wheel: zoom in/out."""
        delta = event.angleDelta().y()
        if delta > 0:
            self.set_zoom(self._zoom + 1)
        elif delta < 0:
            self.set_zoom(self._zoom - 1)
        event.accept()

    # -- Touch events (pinch zoom) --------------------------------------

    def event(self, event):
        """Handle touch events for pinch-to-zoom."""
        if event.type() == event.Type.TouchBegin:
            event.accept()
            return True
        elif event.type() == event.Type.TouchUpdate:
            self._handle_touch_update(event)
            return True
        elif event.type() == event.Type.TouchEnd:
            self._handle_touch_end(event)
            return True
        return super().event(event)

    def _handle_touch_update(self, event):
        points = event.points()

        if len(points) == 2:
            # Pinch gesture
            p1 = points[0].position()
            p2 = points[1].position()
            dist = math.hypot(p2.x() - p1.x(), p2.y() - p1.y())

            if not self._pinch_active:
                self._pinch_active = True
                self._pinch_start_dist = dist
                self._pinch_start_zoom = self._zoom
            else:
                if self._pinch_start_dist > 0:
                    ratio = dist / self._pinch_start_dist
                    # Each 2x distance change = 1 zoom level
                    zoom_delta = round(math.log2(max(ratio, 0.01)))
                    new_zoom = self._pinch_start_zoom + zoom_delta
                    new_zoom = max(TOUCH_ZOOM_MIN, min(TOUCH_ZOOM_MAX, new_zoom))
                    if new_zoom != self._zoom:
                        self._zoom = new_zoom
                        self.update()

        elif len(points) == 1 and not self._pinch_active:
            # Single-finger drag
            pt = points[0]
            if self._drag_last is not None:
                dx = pt.position().x() - self._drag_last.x()
                dy = pt.position().y() - self._drag_last.y()
                self._pause_auto_follow()
                self._pan_by_pixels(dx, dy)
            self._drag_last = pt.position()

    def _handle_touch_end(self, event):
        self._pinch_active = False
        self._pinch_start_dist = 0.0
        self._drag_last = None
        self._dragging = False
