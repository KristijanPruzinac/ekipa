#!/usr/bin/env python3
"""Turn an Overpass extract into venues and the clusters they fall into.

**Intention — clusters are derived, never authored** (`05_PLACES.md`). A human
drawing neighbourhood boundaries is exactly the ongoing per-city labour that
directive D11 forbids, and it is also worse at the job: the thing the matcher
needs is not "which district is this" but "can these four people plausibly
converge here", and that is a question about distance, not about names.

So the clustering below is DBSCAN over the venue positions. It has two
parameters and no map:

* ``--eps`` metres, the radius within which two venues are neighbours. 300 m by
  default, which is roughly five minutes' walk — the distance at which "we're
  meeting near X" stops being useful.
* ``--min-samples``, how many venues make a cluster. Three, because two cafés
  next to each other is a coincidence and three is a place people go.

Venues that fall in no cluster are kept and left unclustered. They are still
real places, they are still choosable when a group's anchors happen to sit
near one, and discarding them would quietly shrink a small city to its centre.

*Rejected — k-means.* It needs the number of clusters up front, which is the
thing we are trying to find out, and it forces every venue into one, which
turns an isolated café on the ring road into the centre of a "cluster" of one.

**What is not derived, and is not invented either.** OpenStreetMap has no field
for "the exact spot" — the sentence the reveal screen prints so four strangers
converge on the same three metres. Writing one per venue by hand is the labour
D11 forbids. So the spot is generated from the tags that *do* exist
(``outdoor_seating``, ``covered``, ``entrance``), and it is deliberately
hedged: an honest "outside if the tables are out, otherwise just inside the
door" beats a confident sentence about a terrace that closed for winter.

Usage::

    python tools/cartography/build_venues.py \\
      --source osijek_venues.json \\
      --city 'Osijek' \\
      --out supabase/seed/osijek_venues.sql
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import uuid
from collections import defaultdict
from typing import Iterable

# Places four strangers can meet at 17:30 without ordering a meal or being
# asked to leave. Deliberately narrow: a bakery is not a meeting point, and a
# nightclub at 17:30 is a locked door.
MEETABLE = {
    "amenity": {"cafe", "restaurant", "bar", "pub", "ice_cream"},
    "leisure": {"park", "garden"},
}

EARTH_RADIUS_M = 6_371_000.0


def haversine(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Great-circle distance in metres."""
    lat1, lon1 = math.radians(a[0]), math.radians(a[1])
    lat2, lon2 = math.radians(b[0]), math.radians(b[1])
    dlat, dlon = lat2 - lat1, lon2 - lon1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * EARTH_RADIUS_M * math.asin(math.sqrt(h))


class Venue:
    """One place, as far as this product is concerned."""

    __slots__ = ("osm_id", "name", "kind", "lat", "lon", "street", "hours",
                 "outdoor", "step_free", "spot")

    def __init__(self, element: dict) -> None:
        tags = element.get("tags", {})
        self.osm_id = f"{element['type']}/{element['id']}"
        self.name = tags["name"].strip()
        self.kind = kind_of(tags)
        self.lat = element.get("lat") or element["center"]["lat"]
        self.lon = element.get("lon") or element["center"]["lon"]
        self.street = street_of(tags)
        self.hours = tags.get("opening_hours")
        self.outdoor = tags.get("outdoor_seating") == "yes"
        # `wheelchair=limited` is not step-free. Treating it as such would put
        # somebody in front of a step they were told was not there, which is
        # worse than saying nothing.
        self.step_free = tags.get("wheelchair") == "yes"
        self.spot = standing_spot(tags, self.kind, self.outdoor)


def kind_of(tags: dict) -> str | None:
    for key, values in MEETABLE.items():
        value = tags.get(key)
        if value in values:
            return value
    return None


def street_of(tags: dict) -> str:
    """The address, as somebody would say it out loud.

    Falls back to the street alone, then to nothing. An empty string is
    honest — the map and the venue name carry the screen when the address does
    not exist, and a fabricated house number sends people to the wrong door.
    """
    street = tags.get("addr:street", "").strip()
    number = tags.get("addr:housenumber", "").strip()
    if street and number:
        return f"{street} {number}"
    return street


def standing_spot(tags: dict, kind: str | None, outdoor: bool) -> str:
    """Where to actually stand, generated rather than written.

    Hedged on purpose. See the module docstring: a confident sentence about a
    terrace that is packed away for winter is worse than a sentence that
    admits it does not know which of two places you will end up.
    """
    if kind in {"park", "garden"}:
        return (
            "By the main entrance to the park. If there is more than one, "
            "the one nearest the road."
        )
    if outdoor:
        return (
            "Outside if the tables are out, otherwise just inside the door. "
            "Have a look at both before you decide nobody is there."
        )
    return (
        "Just inside, by the door. Stay where somebody walking in can see "
        "you."
    )


def cluster_id(city: str, label: int) -> str:
    """A cluster's primary key, derived rather than assigned.

    **Intention — re-running this file must be an upsert, not a churn.** A
    centroid is an output, not an identity, so the obvious idempotence is to
    delete the city's clusters and recompute; but that hands every cluster a
    new uuid on every run, and anything that ever comes to reference one — a
    console note, an outcome measurement, a future ranking weight — is
    silently orphaned by a re-run that changed nothing.

    DBSCAN's label is stable for the same input and the same ``--eps``, so
    ``uuid5`` over the city and the label gives the cluster a name that
    survives regeneration. When the input genuinely changes and a cluster
    stops existing, the seed deletes exactly the ids that are no longer
    produced — which is a real deletion, recorded as one, rather than a wipe
    that happened to be followed by a rebuild.
    """
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"ekipa:cluster:{city}:{label}"))


def read(paths: Iterable[str]) -> list[Venue]:
    venues: list[Venue] = []
    seen: set[str] = set()
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            payload = json.load(handle)
        for element in payload.get("elements", []):
            tags = element.get("tags", {})
            if "name" not in tags:
                # A place with no name cannot be a meeting point: the whole
                # mechanism is four people saying a name to each other.
                continue
            if kind_of(tags) is None:
                continue
            if element.get("lat") is None and "center" not in element:
                continue
            venue = Venue(element)
            if venue.osm_id in seen:
                continue
            seen.add(venue.osm_id)
            venues.append(venue)
    return venues


def dbscan(venues: list[Venue], eps: float, min_samples: int) -> list[int]:
    """Cluster labels, `-1` for the unclustered.

    A plain implementation over a coarse spatial grid rather than a library
    call. `scikit-learn` would be a 40 MB dependency in a build step that runs
    once per city per year, on a few hundred points.
    """
    # Grid cells one eps across, so a neighbour search touches nine cells.
    cell = eps / 111_320.0
    grid: dict[tuple[int, int], list[int]] = defaultdict(list)
    for i, v in enumerate(venues):
        grid[(int(v.lat / cell), int(v.lon / cell))].append(i)

    def neighbours(i: int) -> list[int]:
        v = venues[i]
        gy, gx = int(v.lat / cell), int(v.lon / cell)
        out = []
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                for j in grid.get((gy + dy, gx + dx), ()):
                    if haversine((v.lat, v.lon), (venues[j].lat, venues[j].lon)) <= eps:
                        out.append(j)
        return out

    labels = [-1] * len(venues)
    visited = [False] * len(venues)
    cluster = 0

    for i in range(len(venues)):
        if visited[i]:
            continue
        visited[i] = True
        pool = neighbours(i)
        if len(pool) < min_samples:
            continue  # noise, for now — may still be absorbed below
        labels[i] = cluster
        queue = list(pool)
        while queue:
            j = queue.pop()
            if not visited[j]:
                visited[j] = True
                more = neighbours(j)
                if len(more) >= min_samples:
                    queue.extend(more)
            if labels[j] == -1:
                labels[j] = cluster
        cluster += 1

    return labels


def sql_string(value: str | None) -> str:
    if value is None or value == "":
        return "null"
    return "'" + value.replace("'", "''") + "'"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", action="append", required=True)
    parser.add_argument("--city", required=True, help="the city's name")
    parser.add_argument("--eps", type=float, default=300.0)
    parser.add_argument("--min-samples", type=int, default=3)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    venues = read(args.source)
    if not venues:
        print("no venues found", file=sys.stderr)
        return 1

    labels = dbscan(venues, args.eps, args.min_samples)
    clusters = sorted({label for label in labels if label >= 0})

    centres: dict[int, tuple[float, float, int]] = {}
    for label in clusters:
        members = [v for v, l in zip(venues, labels) if l == label]
        centres[label] = (
            sum(v.lat for v in members) / len(members),
            sum(v.lon for v in members) / len(members),
            len(members),
        )

    lines: list[str] = []
    add = lines.append
    add(f"-- Venues and clusters for {args.city}. GENERATED — do not edit.")
    add("--")
    add("-- Regenerate with:")
    add("--   python tools/cartography/build_venues.py \\")
    add(f"--     --source <overpass.json> --city '{args.city}' \\")
    add(f"--     --eps {args.eps:g} --min-samples {args.min_samples} \\")
    add(f"--     --out {args.out}")
    add("--")
    add("-- Clusters are DBSCAN over the positions, not drawn by anybody: a")
    add("-- human drawing neighbourhood boundaries is the ongoing per-city")
    add("-- labour D11 forbids, and distance is the question the matcher")
    add("-- actually asks. Venues in no cluster are kept, because discarding")
    add("-- them would quietly shrink a small city to its centre.")
    add("--")
    add(f"-- {len(venues)} venues, {len(clusters)} clusters, "
        f"{labels.count(-1)} unclustered. Sizes: "
        + ", ".join(str(centres[label][2]) for label in clusters) + ".")
    add("--")
    add("-- A lopsided first cluster is expected and is not a bug: DBSCAN")
    add("-- chains through a contiguous walkable centre, and in a city this")
    add("-- size the centre genuinely is one place people converge on. If a")
    add("-- city ever needs it split, that is an --eps decision made against")
    add("-- the console's own outcome data, not a boundary somebody draws.")
    add("--")
    add("-- Data (c) OpenStreetMap contributors, ODbL.")
    add("")
    add("do $$")
    add("declare")
    add("  v_city uuid;")
    add("begin")
    add(f"  select id into v_city from public.cities where name = {sql_string(args.city)};")
    add("  if v_city is null then")
    add(f"    raise exception 'no city called {args.city}';")
    add("  end if;")
    add("")
    add("  -- Every id below is derived from the city and the DBSCAN label, so")
    add("  -- re-running this file updates the rows it already wrote rather than")
    add("  -- adding a second set. See `cluster_id` for why that is worth the")
    add("  -- trouble: a wipe-and-rebuild hands every cluster a new uuid on a")
    add("  -- run that changed nothing, and orphans anything that referenced")
    add("  -- one.")
    add("  --")
    add("  -- A cluster this run no longer produces is deleted, and that is a")
    add("  -- real deletion rather than a side effect of a wipe. Venues survive")
    add("  -- it (the foreign key is `on delete set null`) and every one of")
    add("  -- them is reassigned by the upserts below.")
    add("  delete from public.venue_clusters")
    add("   where city_id = v_city")
    add("     and id <> all (array[")
    add(",\n".join(
        f"       {sql_string(cluster_id(args.city, label))}::uuid"
        for label in clusters
    ) + "]);")
    add("")

    for label in clusters:
        lat, lon, count = centres[label]
        add(
            f"  insert into public.venue_clusters "
            f"(id, city_id, centroid, venue_count)\n"
            f"  values ({sql_string(cluster_id(args.city, label))}, v_city, "
            f"extensions.ST_SetSRID("
            f"extensions.ST_MakePoint({lon:.6f}, {lat:.6f}), 4326)"
            f"::extensions.geography, {count})\n"
            f"  on conflict (id) do update set\n"
            f"    centroid = excluded.centroid, "
            f"venue_count = excluded.venue_count,\n"
            f"    computed_at = now();"
        )
    add("")

    for venue, label in zip(venues, labels):
        cluster = (
            f"{sql_string(cluster_id(args.city, label))}::uuid"
            if label >= 0
            else "null"
        )
        add(
            "  insert into public.venues (city_id, cluster_id, source, "
            "source_ref, name, kind, location, street, standing_spot, "
            "opening_hours, outdoor_seating, step_free)\n"
            f"  values (v_city, {cluster}, 'osm', {sql_string(venue.osm_id)}, "
            f"{sql_string(venue.name)}, {sql_string(venue.kind)}, "
            f"extensions.ST_SetSRID(extensions.ST_MakePoint("
            f"{venue.lon:.6f}, {venue.lat:.6f}), 4326)::extensions.geography, "
            f"{sql_string(venue.street)}, {sql_string(venue.spot)}, "
            f"{sql_string(venue.hours)}, "
            f"{'true' if venue.outdoor else 'false'}, "
            f"{'true' if venue.step_free else 'false'})\n"
            "  on conflict (source, source_ref) do update set\n"
            "    name = excluded.name, location = excluded.location,\n"
            "    street = excluded.street, standing_spot = excluded.standing_spot,\n"
            "    opening_hours = excluded.opening_hours,\n"
            "    outdoor_seating = excluded.outdoor_seating,\n"
            "    step_free = excluded.step_free,\n"
            "    cluster_id = excluded.cluster_id, active = true,\n"
            "    deactivated_at = null;"
        )

    add("end;")
    add("$$;")

    with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")

    print(
        f"{len(venues)} venues, {len(clusters)} clusters, "
        f"{labels.count(-1)} unclustered -> {args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
