#!/usr/bin/env python3
"""Add a city to ekipa. One command, one name, no maps drawn by hand.

    python tools/cartography/add_city.py "Osijek, Croatia"

**Intention — D11 says the product must not need ongoing per-city labour, and
a checklist is labour.** Before this script, launching in a second city meant a
person opening Overpass Turbo, typing a bounding box by hand, downloading two
JSON files, running two builders with the right flags, and writing a city row.
Six chances to make a mistake nobody would notice until four strangers were
standing in the wrong place. Now it is one line, and the only thing a human
supplies is the name of the city.

**What it derives, and from what.**

* **The bounding box** comes from Nominatim, which returns the city's own
  administrative extent. Rejected: a fixed radius around the centre — that is a
  circle drawn around a guess, and it is wrong in both directions at once for
  any city that is not round.
* **The geometry and the venues** come from two Overpass queries against that
  box. Both are cached on disk, because a re-run for a tweaked ``--eps`` should
  not re-download six megabytes, and because Overpass is a free service run by
  volunteers.
* **The clusters, the standing spots, and the map** come from the two builders
  that already existed. This script does not reimplement any of them; it works
  out their arguments.

**What a human still decides.** The country code and timezone are asked for
only when Nominatim's answer is ambiguous, and ``--activate`` is deliberately
opt-in: a city with a map and no members is not open, and the row's ``active``
flag is the switch that says people may sign up there. Turning that on is a
product decision, not a consequence of running a script.

**What this is not.** It is not a service. It runs on a laptop, writes files
into the repo, and the files are reviewed and committed like any other change —
so a bad OSM edit upstream shows up in a diff rather than silently in
production. That is the same reason the generated SQL is checked in.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Both services ask for a User-Agent that identifies the caller and would let
# them get in touch if this script misbehaved. Sending a browser's string
# instead would be a lie told to a free service run by volunteers.
AGENT = "ekipa-cartography/1.0 (+https://github.com/Kikomali/ekipa)"

NOMINATIM = "https://nominatim.openstreetmap.org/search"

# Two mirrors, tried in order. Overpass instances go down or rate-limit, and a
# city build that fails at 3am because one server was busy is not automation.
OVERPASS = (
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
)

# Windows consoles still default to cp1252, and every city this will ever be
# run for has a name it cannot encode. Failing to print a city's name is a
# ridiculous way for a build to die, so the stream is widened rather than the
# names narrowed.
for stream in (sys.stdout, sys.stderr):
    if hasattr(stream, "reconfigure"):
        stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parents[2]
CACHE = ROOT / ".cache" / "cartography"

# Kept in step with `build_venues.MEETABLE`. Asking Overpass for less than the
# builder can use would silently shrink the venue pool; asking for more just
# wastes bandwidth.
VENUE_QUERY = """
[out:json][timeout:180];
(
  nwr["amenity"~"^(cafe|restaurant|bar|pub|ice_cream)$"]["name"]({bbox});
  nwr["leisure"~"^(park|garden)$"]["name"]({bbox});
);
out center tags;
"""

# What the map is made of. `build_basemap` sorts these into its six layers by
# tag, so this only has to be a superset of what it draws.
SHAPE_QUERY = """
[out:json][timeout:300];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary|residential|unclassified|living_street|pedestrian|footway|path|cycleway)$"]({bbox});
  way["railway"~"^(rail|light_rail|tram|subway)$"]({bbox});
  way["natural"="water"]({bbox});
  way["waterway"~"^(river|canal|stream)$"]({bbox});
  way["landuse"~"^(grass|forest|meadow|village_green|recreation_ground|cemetery)$"]({bbox});
  way["leisure"~"^(park|garden|pitch|golf_course)$"]({bbox});
  relation["natural"="water"]({bbox});
);
out geom;
"""


def slugify(name: str) -> str:
    """A filename for a city, in ASCII, without inventing a transliteration.

    Croatian ``č`` becomes ``c`` and German ``ü`` becomes ``u``, which is what
    every other tool in this repo already assumes about asset names. The city's
    real name is never touched — it goes into the database exactly as
    Nominatim spelled it, and that is what the app renders.
    """
    folded = (
        name.replace("č", "c").replace("ć", "c").replace("ž", "z")
        .replace("š", "s").replace("đ", "dj").replace("ü", "u")
        .replace("ö", "o").replace("ä", "a").replace("ß", "ss")
    )
    ascii_only = folded.encode("ascii", "ignore").decode("ascii").lower()
    return "".join(c if c.isalnum() else "_" for c in ascii_only).strip("_")


def fetch(url: str, data: bytes | None = None, *, label: str) -> bytes:
    """One HTTP call, with the courtesies these services ask for."""
    request = urllib.request.Request(url, data=data, headers={"User-Agent": AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        payload = response.read()
    print(f"  {label}: {len(payload) / 1024:.0f} KB")
    return payload


def cached(key: str, produce) -> dict:
    """Disk-cached JSON.

    **Intention — a re-run must be cheap.** Tuning ``--eps`` is the one thing
    somebody will genuinely do more than once, and re-downloading the whole
    city to change a clustering radius would make that painful enough that
    nobody bothers, which is how a bad default becomes permanent.
    """
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{hashlib.sha256(key.encode()).hexdigest()[:16]}.json"
    if path.exists():
        print(f"  cached: {path.name}")
        return json.loads(path.read_text(encoding="utf-8"))
    payload = produce()
    path.write_text(json.dumps(payload), encoding="utf-8")
    return payload


def geocode(query: str) -> dict:
    """Ask Nominatim what and where this city is."""
    def produce() -> dict:
        url = NOMINATIM + "?" + urllib.parse.urlencode(
            {"q": query, "format": "jsonv2", "limit": "5", "addressdetails": "1"}
        )
        results = json.loads(fetch(url, label="nominatim"))
        # Nominatim's own ranking, filtered to things that are actually
        # settlements. Without the filter, "Osijek" can resolve to a street or
        # a bus stop of that name, and the bounding box would be forty metres
        # wide — a failure that produces a valid-looking empty city.
        places = [
            r for r in results
            if r.get("addresstype") in {"city", "town", "village", "municipality"}
            or r.get("type") in {"city", "town", "village", "administrative"}
        ]
        if not places:
            raise SystemExit(f"nothing settlement-shaped matched {query!r}")
        return places[0]

    return cached(f"geocode:{query}", produce)


def overpass(query: str, bbox: str, label: str) -> dict:
    """Run one Overpass query, trying each mirror in turn."""
    body = query.format(bbox=bbox).encode("utf-8")

    def produce() -> dict:
        last: Exception | None = None
        for n, endpoint in enumerate(OVERPASS):
            try:
                return json.loads(fetch(endpoint, body, label=f"{label} ({n + 1})"))
            except (urllib.error.URLError, TimeoutError) as error:
                print(f"  {endpoint} failed: {error}", file=sys.stderr)
                last = error
                time.sleep(5)
        raise SystemExit(f"every Overpass mirror refused {label}: {last}")

    return cached(f"overpass:{label}:{bbox}", produce)


def sql_string(value: str | None) -> str:
    if value is None:
        return "null"
    return "'" + value.replace("'", "''") + "'"


def write_city_sql(
    path: pathlib.Path, name: str, country: str, timezone: str,
    lat: float, lon: float,
) -> None:
    """The city row itself, so the venue seed has something to attach to.

    **`active` is false and stays false.** A city with a map is a city that
    *could* open, and the flag that says people may sign up there is a product
    decision made by a person looking at whether there are enough of them yet.
    Having the script decide it would mean a city opened because a build ran.
    """
    path.write_text(
        f"""-- The city row for {name}. GENERATED by tools/cartography/add_city.py.
--
-- `active` is false on purpose: this says the city exists and has a map, not
-- that it is open. Opening it is a decision somebody makes, in the console.
insert into public.cities (name, country_code, timezone, centroid, active)
values (
  {sql_string(name)}, {sql_string(country.upper())}, {sql_string(timezone)},
  extensions.ST_Point({lon:.6f}, {lat:.6f}, 4326)::extensions.geography,
  false
)
on conflict (name, country_code) do update set
  timezone = excluded.timezone, centroid = excluded.centroid;
""",
        encoding="utf-8",
        newline="\n",
    )
    print(f"wrote {path.relative_to(ROOT)}")


def run(script: str, *args: str) -> None:
    """Call one of the two builders, and fail loudly if it fails.

    Subprocess rather than an import, so that the command this script runs is
    the same command a person would type by hand — which means the failure a
    person debugs is reproducible without this file in the middle of it.
    """
    command = [sys.executable, str(ROOT / "tools" / "cartography" / script), *args]
    print(f"\n$ {script} " + " ".join(args))
    result = subprocess.run(command, cwd=ROOT, check=False)
    if result.returncode != 0:
        raise SystemExit(f"{script} failed with {result.returncode}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("city", help='e.g. "Osijek, Croatia"')
    parser.add_argument("--country", help="ISO 3166-1 alpha-2, if Nominatim is wrong")
    parser.add_argument("--timezone", help="IANA name, if the guess is wrong")
    parser.add_argument("--eps", type=float, default=300.0, help="cluster radius, m")
    parser.add_argument("--min-samples", type=int, default=3)
    parser.add_argument("--tolerance", type=float, default=6.0, help="map detail, m")
    parser.add_argument(
        "--refresh", action="store_true",
        help="ignore the download cache and ask OSM again",
    )
    args = parser.parse_args()

    if args.refresh and CACHE.exists():
        for stale in CACHE.glob("*.json"):
            stale.unlink()
        print("cache cleared")

    print(f"\n── {args.city} ─────────────────────────────────")
    place = geocode(args.city)
    name = place["name"]
    country = args.country or place.get("address", {}).get("country_code", "")
    if len(country) != 2:
        raise SystemExit("could not determine a country code — pass --country")

    lat, lon = float(place["lat"]), float(place["lon"])
    south, north, west, east = (float(v) for v in place["boundingbox"])
    bbox = f"{south},{west},{north},{east}"
    slug = slugify(name)
    print(f"  {name} ({country.upper()}) at {lat:.4f},{lon:.4f}")
    print(f"  box {bbox}")

    # A timezone is not something Nominatim returns, and guessing one from a
    # longitude is how a confirmation deadline lands an hour out. The lookup is
    # the standard library's own database where it can answer, and an explicit
    # question where it cannot.
    timezone = args.timezone or COUNTRY_ZONES.get(country.upper(), "")
    if not timezone:
        raise SystemExit(
            f"no default timezone known for {country.upper()} — pass --timezone"
        )
    print(f"  timezone {timezone}")

    venues = overpass(VENUE_QUERY, bbox, "venues")
    shapes = overpass(SHAPE_QUERY, bbox, "shapes")

    raw = CACHE / f"{slug}_venues.json"
    raw.write_text(json.dumps(venues), encoding="utf-8")
    shape_file = CACHE / f"{slug}_shapes.json"
    shape_file.write_text(json.dumps(shapes), encoding="utf-8")

    seed = ROOT / "supabase" / "seed"
    seed.mkdir(parents=True, exist_ok=True)
    write_city_sql(seed / f"{slug}_city.sql", name, country, timezone, lat, lon)

    run(
        "build_venues.py",
        "--source", str(raw),
        "--city", name,
        "--eps", str(args.eps),
        "--min-samples", str(args.min_samples),
        "--out", str(seed / f"{slug}_venues.sql"),
    )
    run(
        "build_basemap.py",
        "--source", str(shape_file),
        "--bounds", f"{south},{west},{north},{east}",
        "--tolerance", str(args.tolerance),
        "--out", str(ROOT / "apps" / "mobile" / "assets" / "basemap" / f"{slug}.ekmap"),
    )

    print(
        f"\n{name} is built. Three files changed; review the diff, then:\n"
        f"  psql < supabase/seed/{slug}_city.sql\n"
        f"  psql < supabase/seed/{slug}_venues.sql\n"
        f"and set `active` in the console when there are people to match."
    )
    return 0


# Enough of the world to cover anywhere this launches next, and an honest
# refusal everywhere else. A wrong timezone is not a cosmetic bug: every
# deadline in the product is absolute, and an hour's error means a person is
# told to confirm at a time that has passed. Rejected — deriving it from the
# longitude, which is wrong for roughly half of Europe.
COUNTRY_ZONES = {
    "HR": "Europe/Zagreb", "SI": "Europe/Ljubljana", "RS": "Europe/Belgrade",
    "BA": "Europe/Sarajevo", "HU": "Europe/Budapest", "AT": "Europe/Vienna",
    "DE": "Europe/Berlin", "IT": "Europe/Rome", "CZ": "Europe/Prague",
    "SK": "Europe/Bratislava", "PL": "Europe/Warsaw", "NL": "Europe/Amsterdam",
    "BE": "Europe/Brussels", "FR": "Europe/Paris", "ES": "Europe/Madrid",
    "PT": "Europe/Lisbon", "IE": "Europe/Dublin", "GB": "Europe/London",
    "DK": "Europe/Copenhagen", "SE": "Europe/Stockholm", "NO": "Europe/Oslo",
    "FI": "Europe/Helsinki", "EE": "Europe/Tallinn", "LV": "Europe/Riga",
    "LT": "Europe/Vilnius", "RO": "Europe/Bucharest", "BG": "Europe/Sofia",
    "GR": "Europe/Athens", "CH": "Europe/Zurich", "MK": "Europe/Skopje",
    "AL": "Europe/Tirane", "ME": "Europe/Podgorica", "XK": "Europe/Belgrade",
}

if __name__ == "__main__":
    raise SystemExit(main())
