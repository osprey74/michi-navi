#!/usr/bin/env python3
"""Import roadside station data from LOD Turtle file into SQLite.

Data source: https://it-social.net/roadside_station/roadside_station.ttl
"""

import json
import re
import sys
from pathlib import Path

import requests

# Add project root to path
PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from app.data.database import DB_PATH, init_db

TTL_URL = "https://it-social.net/roadside_station/roadside_station.ttl"
TTL_CACHE = PROJECT_ROOT / "data" / "roadside_station.ttl"

# Facility flag predicates -> JSON key mapping
FACILITY_KEYS = {
    "ATM": "atm",
    "ベビーベッド": "baby_bed",
    "レストラン": "restaurant",
    "軽食喫茶": "cafe",
    "宿泊施設": "hotel",
    "温泉施設": "onsen",
    "キャンプ場等": "camp",
    "公園": "park",
    "展望台": "observation",
    "美術館博物館": "museum",
    "ガソリンスタンド": "gas_station",
    "EV充電施設": "ev_charger",
    "無線LAN": "wifi",
    "シャワー": "shower",
    "体験施設": "experience",
    "観光案内": "tourist_info",
    "身障者トイレ": "accessible_toilet",
    "ショップ": "shop",
}


def download_ttl() -> str:
    """Download TTL file, using local cache if available."""
    if TTL_CACHE.exists():
        print(f"Using cached TTL: {TTL_CACHE}")
        return TTL_CACHE.read_text(encoding="utf-8")

    print(f"Downloading from {TTL_URL} ...")
    resp = requests.get(TTL_URL, timeout=30, headers={"User-Agent": "Michi-Navi/1.0"})
    resp.raise_for_status()
    # Force UTF-8 decoding (server may report wrong charset)
    text = resp.content.decode("utf-8")
    TTL_CACHE.parent.mkdir(parents=True, exist_ok=True)
    TTL_CACHE.write_text(text, encoding="utf-8")
    print(f"Saved to {TTL_CACHE} ({len(text)} bytes)")
    return text


def _join_split_lines(text: str) -> str:
    """Join lines that were split mid-character in the TTL file.

    The source TTL wraps at a fixed byte width, often splitting
    multi-byte UTF-8 characters or values across lines.  We rejoin
    continuation lines (those that don't start with whitespace followed
    by a known predicate prefix, a subject URI, or a directive).
    """
    lines = text.splitlines()
    joined: list[str] = []
    for line in lines:
        stripped = line.strip()
        # A new statement/triple line starts with: <uri>, @prefix, prefix:pred, or is empty
        is_new = (
            not stripped
            or stripped.startswith("@prefix")
            or stripped.startswith("#")
            or stripped.startswith("<")
            or re.match(r"^[\w]+:", stripped)
        )
        if is_new or not joined:
            joined.append(line)
        else:
            # Continuation of previous line
            joined[-1] += stripped
    return "\n".join(joined)


def parse_ttl(text: str) -> list[dict]:
    """Parse Turtle file into a list of station dicts.

    Simple parser tailored to the roadside_station.ttl format.
    Each station block starts with a <URI> subject line, followed by
    indented predicate-object pairs separated by `;`, ending with `.`.
    """
    text = _join_split_lines(text)

    stations = []
    current_subject = None
    current_triples: dict[str, list[str]] = {}

    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("@prefix") or line.startswith("#"):
            continue

        # Subject line: <full-uri> on its own (no predicate)
        if line.startswith("<") and line.endswith(">") and " " not in line:
            # Save previous block
            if current_subject and current_triples:
                station = _build_station(current_triples)
                if station:
                    stations.append(station)
            current_subject = line
            current_triples = {}
            continue

        # Predicate-object line (may have multiple objects separated by ,)
        # Pattern: prefix:localname "value"@ja ; or <uri> ; or "val"^^xsd:type .
        po_match = re.match(r"^([\w]+:\S+)\s+(.+?)\s*([;.])\s*$", line)
        if po_match:
            pred = po_match.group(1)
            obj_str = po_match.group(2)
            # Handle multiple objects: "val1"@ja, "val2"@ja
            for obj in re.split(r",\s*(?=<|\")", obj_str):
                obj = obj.strip()
                if obj:
                    current_triples.setdefault(pred, []).append(obj)

    # Last block
    if current_subject and current_triples:
        station = _build_station(current_triples)
        if station:
            stations.append(station)

    return stations


def _extract_literal(value: str) -> str:
    """Extract literal value from Turtle object string."""
    # "value"@ja or "value"^^xsd:type or "value"
    m = re.match(r'"([^"]*)"', value)
    return m.group(1) if m else value.strip("<>")


def _extract_uri(value: str) -> str:
    """Extract URI from <uri> or return as-is."""
    m = re.match(r"<([^>]+)>", value)
    return m.group(1) if m else value


def _build_station(triples: dict[str, list[str]]) -> dict | None:
    """Convert parsed triples into a station dict."""
    def get(pred: str) -> str | None:
        vals = triples.get(pred)
        if vals:
            return _extract_literal(vals[0])
        return None

    station_id = get("iclt:ID")
    name = get("iclt:名称")
    lat_str = get("geo:lat")
    lon_str = get("geo:long")

    if not all([station_id, name, lat_str, lon_str]):
        return None

    # Build features JSON from facility flags
    features = {}
    for ttl_key, json_key in FACILITY_KEYS.items():
        val = get(f"rsst:{ttl_key}")
        if val and val == "1":
            features[json_key] = True

    # First website URL
    urls = triples.get("iclt:Webサイト", [])
    url = _extract_uri(urls[0]) if urls else None

    # Image URL
    images = triples.get("rsst:画像", [])
    image_url = _extract_uri(images[0]) if images else None

    # Description as fallback for features text
    description = get("iclt:説明")
    if description:
        features["description"] = description

    return {
        "id": station_id,
        "name": name,
        "prefecture": get("iclt:都道府県") or "",
        "municipality": get("iclt:市区町村"),
        "latitude": float(lat_str),
        "longitude": float(lon_str),
        "road_name": get("rsst:登録路線"),
        "features": json.dumps(features, ensure_ascii=False) if features else None,
        "hours": None,  # Not available in TTL
        "holidays": None,
        "url": url,
        "image_url": image_url,
    }


def import_stations(stations: list[dict]) -> int:
    """Insert stations into SQLite database. Returns count of inserted rows."""
    conn = init_db()

    # Clear existing data for re-import
    conn.execute("DELETE FROM stations_rtree")
    conn.execute("DELETE FROM roadside_stations")

    insert_sql = """
        INSERT OR REPLACE INTO roadside_stations
        (id, name, prefecture, municipality, latitude, longitude,
         road_name, features, hours, holidays, url, image_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """
    rtree_sql = """
        INSERT INTO stations_rtree (id, min_lat, max_lat, min_lon, max_lon)
        VALUES (?, ?, ?, ?, ?)
    """

    count = 0
    for s in stations:
        conn.execute(insert_sql, (
            s["id"], s["name"], s["prefecture"], s["municipality"],
            s["latitude"], s["longitude"], s["road_name"],
            s["features"], s["hours"], s["holidays"], s["url"], s["image_url"],
        ))
        # R-Tree uses numeric id; use hash of station id string
        rtree_id = int(s["id"])
        conn.execute(rtree_sql, (
            rtree_id, s["latitude"], s["latitude"],
            s["longitude"], s["longitude"],
        ))
        count += 1

    conn.commit()
    conn.close()
    return count


def main():
    print("=== Michi-Navi Station Importer ===")
    print()

    ttl_text = download_ttl()
    stations = parse_ttl(ttl_text)
    print(f"Parsed {len(stations)} stations from TTL")

    # Filter out discontinued stations (廃止)
    active = [s for s in stations if "廃止" not in (s.get("name") or "")]
    if len(active) < len(stations):
        print(f"  ({len(stations) - len(active)} discontinued stations skipped)")

    count = import_stations(active)
    print(f"Imported {count} stations into {DB_PATH}")
    print()

    # Verify
    conn = init_db()
    row = conn.execute("SELECT COUNT(*) as cnt FROM roadside_stations").fetchone()
    print(f"Verification: {row['cnt']} stations in database")

    row = conn.execute("SELECT COUNT(*) as cnt FROM stations_rtree").fetchone()
    print(f"Verification: {row['cnt']} R-Tree entries")

    # Sample
    sample = conn.execute(
        "SELECT id, name, prefecture, municipality, latitude, longitude "
        "FROM roadside_stations ORDER BY id LIMIT 3"
    ).fetchall()
    print("\nSample entries:")
    for r in sample:
        print(f"  [{r['id']}] {r['name']} ({r['prefecture']} {r['municipality']}) "
              f"{r['latitude']:.4f}N {r['longitude']:.4f}E")

    conn.close()
    print("\nDone.")


if __name__ == "__main__":
    main()
