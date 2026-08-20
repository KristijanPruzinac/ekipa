#!/usr/bin/env python3
"""Turn an Overpass extract into the compact basemap the app paints.

**Intention — a real map of a real city, in our palette, with no tile server.**
The reveal screen has to show where four strangers are meeting. Three ways to
do that were considered:

  * **Raster tiles from OSM** (`flutter_map` + tile.openstreetmap.org). Needs a
    package, a network round-trip at exactly the moment somebody is walking to a
    place, an attribution overlay, and the tiles arrive in somebody else's
    colours — a colour filter over a light basemap is a grey mush, not a theme.
  * **A commercial SDK** (Google, Mapbox). Both need an API key attached to a
    billing account, which the no-company / no-paid-infrastructure decision
    forecloses outright.
  * **Ship the geometry.** OSM's vector data for one city centre, simplified,
    quantised, and painted by us. No package, no key, no network, no cost, and
    the map is in Zar's colours because we drew it.

The third is the only one that survives the constraints, and it happens to be
the best-looking of the three. Its cost is that a city has to be built before it
launches — which is already true (venue ingestion, cluster derivation), so this
is one more step in a pipeline that exists.

Licence: OpenStreetMap contributors, ODbL. Attribution ships on the map surface
itself, not in a settings page.

Usage:
    python tools/cartography/build_basemap.py \
        --roads roads.json --area area.json \
        --out apps/mobile/assets/basemap/osijek.ekmap
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import struct

MAGIC = b"EKMAP1"

# Layer kinds, in paint order. The painter walks them in this order, so water
# under green under roads is a property of the file rather than of the widget.
WATER, GREEN, ROAD_MAJOR, ROAD_MINOR, ROAD_PATH, RAIL = range(6)

MAJOR = {"motorway", "trunk", "primary", "secondary"}
MINOR = {"tertiary", "residential", "unclassified", "living_street"}
PATH = {"pedestrian", "footway", "path", "cycleway"}


def simplify(points: list[tuple[float, float]], tolerance: float) -> list[tuple[float, float]]:
    """Douglas-Peucker.

    A city centre at phone scale is about 900 device pixels across. Anything
    finer than a couple of metres is invisible and still costs bytes on every
    install, so it is dropped here rather than being decoded and discarded on
    the phone forever.
    """
    if len(points) < 3:
        return points
    ax, ay = points[0]
    bx, by = points[-1]
    dx, dy = bx - ax, by - ay
    span = math.hypot(dx, dy)
    worst, index = -1.0, 0
    for i in range(1, len(points) - 1):
        px, py = points[i]
        if span == 0:
            distance = math.hypot(px - ax, py - ay)
        else:
            distance = abs(dy * px - dx * py + bx * ay - by * ax) / span
        if distance > worst:
            worst, index = distance, i
    if worst <= tolerance:
        return [points[0], points[-1]]
    left = simplify(points[: index + 1], tolerance)
    right = simplify(points[index:], tolerance)
    return left[:-1] + right


def classify(tags: dict[str, str]) -> int | None:
    if tags.get("natural") == "water" or tags.get("waterway") in {"riverbank", "river"}:
        return WATER
    if tags.get("leisure") in {"park", "pitch", "garden"} or tags.get("landuse") == "grass":
        return GREEN
    if tags.get("railway"):
        return RAIL
    highway = tags.get("highway")
    if highway in MAJOR:
        return ROAD_MAJOR
    if highway in MINOR:
        return ROAD_MINOR
    if highway in PATH:
        return ROAD_PATH
    return None


def collect(paths: list[pathlib.Path]) -> dict[int, list[list[tuple[float, float]]]]:
    layers: dict[int, list[list[tuple[float, float]]]] = {k: [] for k in range(6)}
    for path in paths:
        document = json.loads(path.read_text(encoding="utf-8"))
        for element in document["elements"]:
            geometry = element.get("geometry")
            if not geometry:
                continue
            kind = classify(element.get("tags", {}))
            if kind is None:
                continue
            layers[kind].append([(node["lon"], node["lat"]) for node in geometry])
    return layers


def build(layers, bounds, tolerance_metres: float) -> bytes:
    min_lon, min_lat, max_lon, max_lat = bounds
    span_lon = max_lon - min_lon
    span_lat = max_lat - min_lat
    # One degree of latitude is ~111 km; longitude shrinks with the cosine. The
    # tolerance arrives in metres so the number in the CLI means something.
    tolerance = tolerance_metres / 111_320.0

    chunks: list[bytes] = []
    kept = dropped = 0
    for kind in range(6):
        shapes: list[bytes] = []
        for shape in layers[kind]:
            clipped = [
                (lon, lat)
                for lon, lat in shape
                if min_lon <= lon <= max_lon and min_lat <= lat <= max_lat
            ]
            if len(clipped) < 2:
                dropped += 1
                continue
            reduced = simplify(clipped, tolerance)
            if len(reduced) < 2 or len(reduced) > 0xFFFF:
                dropped += 1
                continue
            kept += 1
            points = bytearray()
            for lon, lat in reduced:
                x = round((lon - min_lon) / span_lon * 0xFFFF)
                y = round((max_lat - lat) / span_lat * 0xFFFF)
                points += struct.pack("<HH", max(0, min(0xFFFF, x)), max(0, min(0xFFFF, y)))
            shapes.append(struct.pack("<H", len(reduced)) + bytes(points))
        chunks.append(struct.pack("<BI", kind, len(shapes)) + b"".join(shapes))

    header = MAGIC + struct.pack("<dddd", min_lat, min_lon, max_lat, max_lon)
    header += struct.pack("<H", 6)
    print(f"  shapes kept {kept}, dropped {dropped}")
    return header + b"".join(chunks)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", action="append", required=True, type=pathlib.Path)
    parser.add_argument("--out", required=True, type=pathlib.Path)
    parser.add_argument("--bounds", required=True, help="minLat,minLon,maxLat,maxLon")
    parser.add_argument("--tolerance", type=float, default=6.0, help="metres")
    args = parser.parse_args()

    min_lat, min_lon, max_lat, max_lon = (float(v) for v in args.bounds.split(","))
    layers = collect(args.source)
    for kind, name in enumerate(
        ["water", "green", "road_major", "road_minor", "path", "rail"]
    ):
        print(f"  {name}: {len(layers[kind])} ways")
    blob = build(layers, (min_lon, min_lat, max_lon, max_lat), args.tolerance)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(blob)
    print(f"wrote {args.out} — {len(blob) / 1024:.0f} KB")


if __name__ == "__main__":
    main()
