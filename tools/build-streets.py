#!/usr/bin/env python3
"""Build assets/streets.json — the street list the address box completes against.

    python3 tools/build-streets.py

Source is the Census TIGER/Line ADDRFEAT file for St. Louis County, which
carries every street segment with its house-number ranges. We keep only
segments that fall inside a city we serve, then collapse them to one entry per
street with the span of house numbers seen on it.

WHY AUTOCOMPLETE AND NOT A FREE-TEXT BOX
----------------------------------------
The Census geocoder has no fuzzy matching. A misspelled street, a wrong suffix
(Dr for Ln), or a house number that does not exist returns an empty result with
no suggestion — and that is the failure a real visitor hits, not an exotic one.
Three empty results during this project's research turned out to be one bad
test address, not missing coverage.

Completing against a real street list removes the failure instead of handling
it: the visitor never types the fragile part, and we send the geocoder a string
we know it can parse. The house-number range then catches a typo locally,
before any request goes out.

Picking a street also settles which city they are in, so no city has to be
chosen first.

Output shape, keyed by city:

    {"Maryland Heights": [["Adie Rd", 2400, 11999], ...], ...}

A street with no usable range appears as ["Name"] alone; the house number is
then accepted without a local check and left to the geocoder.
"""
import io, json, gzip, os, sys, urllib.request, zipfile
from collections import defaultdict

import shapefile                      # pyshp
from shapely.geometry import shape
from shapely.ops import unary_union
from shapely.strtree import STRtree

COUNTY_FIPS = "29189"                 # St. Louis County, Missouri
TIGER_YEAR = "2024"
ADDRFEAT = (f"https://www2.census.gov/geo/tiger/TIGER{TIGER_YEAR}/ADDRFEAT/"
            f"tl_{TIGER_YEAR}_{COUNTY_FIPS}_addrfeat.zip")

PLACES = ("https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/"
          "Places_CouSub_ConCity_SubMCD/MapServer/4/query")
CITIES = ["Maryland Heights city", "Creve Coeur city", "Bridgeton city",
          "Overland city", "Town and Country city"]
UA = {"User-Agent": "CivicGateway-build/1.0 (https://civicgateway.org)"}


def city_polygons():
    import urllib.parse
    where = "STATE='29' AND NAME IN (" + ",".join(f"'{c}'" for c in CITIES) + ")"
    req = urllib.request.Request(PLACES, headers=UA, data=urllib.parse.urlencode({
        "where": where, "outFields": "NAME", "returnGeometry": "true",
        "outSR": "4326", "f": "json"}).encode())
    data = json.load(urllib.request.urlopen(req, timeout=120))
    out = {}
    for f in data["features"]:
        rings = [shape({"type": "Polygon", "coordinates": [r]}) for r in f["geometry"]["rings"]]
        out[f["attributes"]["NAME"].replace(" city", "")] = unary_union(
            [r if r.is_valid else r.buffer(0) for r in rings])
    if len(out) != len(CITIES):
        sys.exit(f"expected {len(CITIES)} cities, got {sorted(out)}")
    return out


def main():
    cities = city_polygons()
    names, geoms = list(cities), list(cities.values())
    tree = STRtree(geoms)

    print(f"downloading {ADDRFEAT} …")
    blob = urllib.request.urlopen(
        urllib.request.Request(ADDRFEAT, headers=UA), timeout=300).read()
    zf = zipfile.ZipFile(io.BytesIO(blob))
    base = f"tl_{TIGER_YEAR}_{COUNTY_FIPS}_addrfeat"
    reader = shapefile.Reader(
        shp=io.BytesIO(zf.read(base + ".shp")),
        dbf=io.BytesIO(zf.read(base + ".dbf")),
        shx=io.BytesIO(zf.read(base + ".shx")))

    fields = [f[0] for f in reader.fields[1:]]
    spans = defaultdict(lambda: [None, None])
    for sr in reader.iterShapeRecords():
        rec = dict(zip(fields, list(sr.record)))
        street = (rec.get("FULLNAME") or "").strip()
        if not street:
            continue
        geom = shape(sr.shape.__geo_interface__)
        for idx in tree.query(geom):
            if not geoms[idx].intersects(geom):
                continue
            key = (names[idx], street)
            for side in ("LFROMHN", "LTOHN", "RFROMHN", "RTOHN"):
                raw = (rec.get(side) or "").strip()
                if not raw.isdigit():
                    continue          # ranges can be blank, or carry letters
                n = int(raw)
                lo, hi = spans[key]
                spans[key] = [n if lo is None else min(lo, n),
                              n if hi is None else max(hi, n)]
            break                     # one city per segment is enough

    by_city = defaultdict(list)
    for (city, street), (lo, hi) in sorted(spans.items()):
        by_city[city].append([street] if lo is None else [street, lo, hi])

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(root, "assets", "streets.json")
    body = json.dumps(by_city, separators=(",", ":"), sort_keys=True)
    with open(path, "w") as fh:
        fh.write(body)

    total = sum(len(v) for v in by_city.values())
    print(f"{total} streets across {len(by_city)} cities -> {path}")
    for city in sorted(by_city):
        print(f"   {city:<20} {len(by_city[city]):>4}")
    print(f"{len(body)/1024:.0f} KB raw, "
          f"{len(gzip.compress(body.encode()))/1024:.1f} KB gzipped")


if __name__ == "__main__":
    main()
