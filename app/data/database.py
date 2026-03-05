"""SQLite database manager for Michi-Navi."""

import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parents[2] / "data" / "poi.db"

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS roadside_stations (
  id            TEXT PRIMARY KEY,  -- 登録番号 (5桁)
  name          TEXT NOT NULL,     -- 道の駅名
  prefecture    TEXT NOT NULL,     -- 都道府県
  municipality  TEXT,              -- 市町村
  latitude      REAL NOT NULL,     -- 緯度
  longitude     REAL NOT NULL,     -- 経度
  road_name     TEXT,              -- 登録路線名
  features      TEXT,              -- 特色・概要 (JSON)
  hours         TEXT,              -- 営業時間
  holidays      TEXT,              -- 定休日
  url           TEXT,              -- 公式サイトURL
  image_url     TEXT               -- 画像URL
);

CREATE VIRTUAL TABLE IF NOT EXISTS stations_rtree USING rtree(
  id,
  min_lat, max_lat,
  min_lon, max_lon
);

CREATE TABLE IF NOT EXISTS tourism_spots (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT NOT NULL,     -- スポット名
  municipality  TEXT NOT NULL,     -- 市町村
  prefecture    TEXT NOT NULL,     -- 都道府県
  latitude      REAL NOT NULL,
  longitude     REAL NOT NULL,
  category      TEXT,              -- カテゴリ(温泉/神社/景観等)
  description   TEXT,              -- ワンポイント説明
  source        TEXT               -- データソース
);
"""


def get_connection(db_path: Path | None = None) -> sqlite3.Connection:
    """Open a connection to the POI database."""
    path = db_path or DB_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db(db_path: Path | None = None) -> sqlite3.Connection:
    """Create tables and indexes if they don't exist."""
    conn = get_connection(db_path)
    conn.executescript(SCHEMA_SQL)
    conn.commit()
    return conn
