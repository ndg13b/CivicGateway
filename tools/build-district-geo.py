#!/usr/bin/env python3
"""Build assets/districts.geo.json — the boundaries the site resolves against.

    python3 tools/build-district-geo.py

Only the scopes a city genuinely SPLITS across need geometry. Everything else
is settled by the city picker alone, so shipping it would be dead weight.
Today that means congressional districts and school districts; state house and
senate are whole-city for all five cities.

WHY WE SHIP POLYGONS INSTEAD OF ASKING AN API
---------------------------------------------
The Census geographies endpoint will happily return a congressional district
for a point, but it returns whichever vintage Census currently publishes. In
September 2026 that is the 119th — correct for this election — but only by
coincidence, and it will roll to the 120th without warning.

That distinction is not academic: migration 009 remapped two cities onto the
120th map, which is suspended pending the Proposition A referendum, and had to
be reverted in 010. Pinning the layer here means the site cannot silently
switch maps underneath us. CONGRESS_LAYER below is the single place that
decision lives.

Districts we do not cover get a null slug: we still need their shape, so that
someone in Pattonville is not shown Parkway's ballot measure.
"""
import json, gzip, pickle, urllib.request, urllib.parse, os, sys
from shapely.geometry import Polygon, mapping, box
from shapely.ops import unary_union

BASE = "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb"
UA = {"User-Agent": "CivicGateway-build/1.0 (https://civicgateway.org)"}

# Layer 4 = 119th Congress. This is the map in force for the November 3, 2026
# election, because HB1 (which drew the 120th) is suspended pending the
# statewide Proposition A referendum on that same ballot. Revisit for 2028.
CONGRESS_LAYER = "Legislative/MapServer/4"
SCHOOL_LAYER = "School/MapServer/0"

# County Council districts are not Census geography, so they come from the
# county's own GIS. Districts 1, 3, 5 and 7 are on the 2026 ballot; 2, 4 and 6
# are mid-term. We fetch all seven because being in a district that is NOT up
# is the answer for most of our cities, and we would rather say that than
# leave a contest looking unresolved.
COUNCIL_SERVICE = ("https://services2.arcgis.com/w657bnjzrjguNyOy/arcgis/rest/"
                   "services/Council_District_Plan_2022/FeatureServer/0/query")

# TIGERweb name -> our districts.short_name, or None when we carry no scope
# for it (we still need the shape, to rule that district IN and others OUT).
SLUGS = {
    "Congressional District 1": "MO-1",
    "Congressional District 2": "MO-2",
    "Parkway C-2 School District": "Parkway C-2",
    "Ritenour School District": "Ritenour",
    # Only the council districts on the 2026 ballot carry a scope. The others
    # are shipped with a null slug so the site can tell someone their council
    # seat simply is not up this year, rather than saying nothing.
    "District 1": "Council 1",
    "District 3": "Council 3",
    "District 7": "Council 7",
}

CITIES = ["Maryland Heights city", "Creve Coeur city", "Bridgeton city",
          "Overland city", "Town and Country city"]


# Must match slugify() in assets/app.js, which builds the same key from the
# jurisdiction name and state: "Maryland Heights" -> "maryland-heights-mo".
def slugify_city(name, state="mo"):
    slug = "".join(c if c.isalnum() else "-" for c in name.lower())
    while "--" in slug:
        slug = slug.replace("--", "-")
    return f"{slug.strip('-')}-{state}"


def post(url, params):
    req = urllib.request.Request(
        url, data=urllib.parse.urlencode(params).encode(), headers=UA)
    return json.load(urllib.request.urlopen(req, timeout=120))


def to_shape(geom):
    parts = []
    for ring in geom["rings"]:
        p = Polygon(ring)
        if not p.is_valid:
            p = p.buffer(0)
        parts.append(p)
    return unary_union(parts)


def fetch(layer, where="STATE='29'"):
    r = post(f"{BASE}/{layer}/query", {
        "where": where, "outFields": "NAME", "returnGeometry": "true",
        "outSR": "4326", "f": "json"})
    if "error" in r:
        sys.exit(f"TIGERweb error on {layer}: {r['error']}")
    return {f["attributes"]["NAME"]: to_shape(f["geometry"]) for f in r["features"]}


def main():
    where = "STATE='29' AND NAME IN (" + ",".join(f"'{c}'" for c in CITIES) + ")"
    places = fetch("Places_CouSub_ConCity_SubMCD/MapServer/4", where)
    if len(places) != len(CITIES):
        sys.exit(f"expected {len(CITIES)} cities, got {sorted(places)}")
    covered = unary_union(list(places.values()))
    clip = box(*covered.bounds).buffer(0.01)

    out = {
        "note": "Boundaries for resolving an address to its districts. "
                "Congressional layer is the 119th Congress — the map in force "
                "for November 3, 2026. See tools/build-district-geo.py.",
        "congress_layer": CONGRESS_LAYER,
        "districts": [],
    }

    # City outlines too, so "use my location" can tell which city a point is in
    # without a round trip — and can say plainly when it is in none of them.
    for name, geom in places.items():
        out["districts"].append({
            "kind": "city",
            "name": name.replace(" city", ""),
            "slug": slugify_city(name.replace(" city", "")),
            "geometry": mapping(geom.simplify(0.00005, preserve_topology=True)),
        })

    def council():
        r = post(COUNCIL_SERVICE, {
            "where": "1=1", "outFields": "LONGNAME", "returnGeometry": "true",
            "outSR": "4326", "f": "json"})
        if "error" in r:
            sys.exit(f"county council service error: {r['error']}")
        return {f["attributes"]["LONGNAME"]: to_shape(f["geometry"])
                for f in r["features"]}

    sources = [("us_house", fetch(CONGRESS_LAYER)),
               ("school", fetch(SCHOOL_LAYER)),
               # kind must match districts.level in the database, so the address
               # tool can line a resolved boundary up with the scope it filters.
               ("county", council())]

    for kind, layer in sources:
        for name, geom in layer.items():
            if not geom.intersects(covered):
                continue
            # Require a real overlap with a city, not a shared boundary line.
            if geom.intersection(covered).area / covered.area < 0.0005:
                continue
            simplified = geom.intersection(clip).simplify(
                0.00005, preserve_topology=True)
            if simplified.is_empty:
                continue
            out["districts"].append({
                "kind": kind,
                "name": name,
                "slug": SLUGS.get(name),
                "geometry": mapping(simplified),
            })

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(root, "assets", "districts.geo.json")
    body = json.dumps(out, separators=(",", ":"))
    with open(path, "w") as fh:
        fh.write(body)

    print(f"{len(out['districts'])} districts -> {path}")
    for d in out["districts"]:
        print(f"   {d['kind']:<9} {d['name']:<44} slug={d['slug']}")
    print(f"{len(body)/1024:.1f} KB raw, "
          f"{len(gzip.compress(body.encode()))/1024:.1f} KB gzipped")


if __name__ == "__main__":
    main()
