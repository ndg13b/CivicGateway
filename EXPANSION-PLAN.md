# Expansion Plan: More Cities + State & Federal Districts

Researched July 2026. This documents (1) the legislative districts covering our
current cities, with sources, (2) the 2026 election picture, and (3) the exact
checklist for adding new cities.

## 1. The district layer

### Why districts are modeled separately from cities

Cities and legislative districts overlap in both directions: Maryland Heights
alone is split across **two** state senate districts and **three** state house
districts, and Creve Coeur is split between **two** congressional districts.
So districts get their own table (`districts`), a many-to-many mapping to
cities (`jurisdiction_districts` with a `partial` flag), and officials/elections
can attach to either a city or a district. See `migrations/001-districts.sql`.

Whenever `partial = true`, the UI must say so — a resident's actual
representative depends on their address. We link the official lookup tools so
people can confirm:
- Missouri legislators by address: https://house.mo.gov/legislatorlookup.aspx
- U.S. House by ZIP: https://ziplook.house.gov/htbin/findrep_house

### District assignments — verified September 2026

Sources: TIGERweb boundary polygons intersected with each city's polygon
(Shapely), **cross-checked against the St. Louis County Board of Elections
ballot content report of 16 September 2026**, which is the authority on what
actually prints.

| City | U.S. House | MO Senate | MO House |
|---|---|---|---|
| Maryland Heights | **MO-1** 32.7% · **MO-2** 67.3% | **24** (100%) | **87** (100%) |
| Creve Coeur | **MO-1** 30.9% · **MO-2** 69.1% | **24** (100%) | **71** (100%) |
| Bridgeton | **MO-1** (100%) | **14** (100%) | **70** (100%) |
| Overland | **MO-1** (100%) | **14** (100%) | **72** (100%) |
| Town and Country | **MO-2** (100%) | **15** (100%) | **89** (100%) |

Senate 15 is odd-numbered and 2026 elects only even-numbered senate seats, so
Town and Country has no state senate contest this cycle — confirmed by the
county report, which carries no District 15 contest.

#### Which congressional map applies, and why it is the older one

TIGERweb carries two: layer 4 (119th) and layer 0 (120th, "January 1, 2026
vintage"). The obvious reading — that the 120th applies because it is the
Congress being elected — is **wrong**, and migration 009 acted on it before
migration 010 reverted it.

The 120th boundaries come from House Bill 1 (2025 Second Extraordinary
Session). That act is itself the subject of the referendum on this ballot as
statewide **Proposition A**, and a referendum petition suspends the act until
the vote. So November 2026 runs under the previous plan.

The county's ballot report is conclusive: the entire county has exactly two
congressional contests, districts 1 and 2. Under the 120th map Maryland
Heights would be 13% in district 3, and no district 3 contest exists anywhere
in St. Louis County.

**Boundary geometry is authoritative about where lines are. It is not
authoritative about which map is in force.** Only the election authority's own
ballot answers that, and it is the first thing to check — not the last.

If Proposition A passes, the new boundaries apply from 2028.

#### On the July table below

It was wrong for three of five cities, and the reason matters: it was built
from prose — legislator bios saying a district "includes Maryland Heights
(part)" — and prose cannot be checked. Anything deciding which contest a
person is shown should come from boundary data, confirmed against a ballot.

### Superseded: the original July 2026 research

Kept for provenance. **Do not rely on this table** — see above.

#### Verified district assignments (July 2026) — SUPERSEDED

| City | U.S. House | MO Senate | MO House |
|---|---|---|---|
| Maryland Heights | **MO-1** — Wesley Bell (D) | **24** — Tracy McCreery (D) *(part)*; **14** — Brian Williams (D) *(part)* | **70** — Stephanie Boykin (D) *(part)*; **71** — LaDonna Appelbaum (D) *(part)*; **87** — Connie Steinmetz (D) *(Westport area)* |
| Creve Coeur | **MO-1** — Bell *(part)*; **MO-2** — Ann Wagner (R) *(part)* | **24** — McCreery | **71** — Appelbaum *(part)* |
| Bridgeton | **MO-1** — Bell | **14** — Williams | **70** — Boykin |

Sources:
- [Missouri's 1st Congressional District (Wikipedia)](https://en.wikipedia.org/wiki/Missouri%27s_1st_congressional_district) — includes all of St. Louis City and much of northern St. Louis County, incl. Maryland Heights; Bridgeton (63044) confirmed via [congress.gov district map](https://www.congress.gov/member/district/wesley-bell/B001324)
- [Missouri's 2nd Congressional District (Wikipedia)](https://en.wikipedia.org/wiki/Missouri%27s_2nd_congressional_district) — Creve Coeur is split between MO-1 and MO-2
- [Sen. Tracy McCreery, District 24 (senate.mo.gov)](https://www.senate.mo.gov/Senators/Member/24) — district includes Creve Coeur, Maryland Heights, Kirkwood, Des Peres
- [Missouri's 14th Senate district (Wikipedia)](https://en.wikipedia.org/wiki/Missouri%27s_14th_Senate_district) — includes Bridgeton, Hazelwood, St. Ann, Maryland Heights (part)
- [Rep. Stephanie Boykin, District 70 (house.mo.gov)](https://house.mo.gov/MemberDetails.aspx?district=070) — district includes Bridgeton, Hazelwood, Maryland Heights (part)
- [Rep. LaDonna Appelbaum, District 71](https://house.mo.gov/MemberDetails.aspx?district=071) — portions of Chesterfield, Creve Coeur, Maryland Heights, Olivette, Overland ([caucus bio](https://www.molegdems.com/ladonna-appelbaum-1))
- [Rep. Connie Steinmetz, District 87](https://house.mo.gov/MemberDetails.aspx?district=087) — includes Creve Coeur Park and the Westport Plaza area ([campaign district page](https://www.conniesteinmetz.org/district87))

**Needs verification at data-entry time** (couldn't be confirmed from this
environment; check the official district maps at
[house.mo.gov](https://house.mo.gov/districtmap.aspx) /
[sos.mo.gov](https://www.sos.mo.gov/elections/maps)):
- Exact House-district boundaries inside each city (the `partial` flags are
  conservative; some may cover more/less than described)
- Whether any additional House district touches Creve Coeur (older sources
  mention an 82nd/89th-district sliver; District 89 — George Hruza (R) —
  covers Des Peres/Town and Country/Chesterfield and matters when Town and
  Country is added)

### ⚠️ Redistricting caveat — SUPERSEDED, see §1 above

This said the redraw affected only districts 4, 5 and 6 around Kansas City.
The redraw is real but is suspended pending the Proposition A referendum on
this ballot, so it does not apply to the 2026 election at all.

## 2. The 2026 elections (relevant to our cities)

- **Primary: August 4, 2026** · **General: November 3, 2026**
- Filing is closed; certified candidates are listed by the
  [Missouri Secretary of State](https://www.sos.mo.gov/elections/candidates).

What's on our residents' November ballots:

| Race | Status |
|---|---|
| **U.S. House MO-1** | Democratic primary: Wesley Bell (incumbent), Cori Bush, Alissa Murphy, Carl E. Harris Sr., Carl Earnest Henderson. Republican primary: Paul Berry III, Andrew Jones. ([Ballotpedia](https://ballotpedia.org/Missouri%27s_1st_Congressional_District_election,_2026)) |
| **U.S. House MO-2** | Republican primary: Ann Wagner (incumbent), Matthew Grant. Democratic primary: Timothy Bilash, Chuck Summers, Nick Vivio, Joan VonDras, Frederick Wellman. ([Ballotpedia](https://ballotpedia.org/Missouri%27s_2nd_Congressional_District_election,_2026)) |
| **State Auditor** (statewide) | R primary: Scott Fitzpatrick (incumbent), Gerald Wistrand. D primary: Gregory Upchurch, Quentin Wilson. Libertarian: Dustin Coffell. |
| **MO Senate 24** | Tracy McCreery (D, incumbent) running; full certified field to be confirmed from the SOS list. |
| **MO House 70 / 71 / 87** | All MO House seats are up in 2026. Certified candidate lists to be confirmed from the SOS list. |
| Statewide ballot measures | Several constitutional amendments are on 2026 ballots; pull the certified list from the SOS site. |

**Data-entry plan:** after the August 4 primary results are certified
(roughly mid-August), add a `races` + `candidates` set under each district's
November 3 election row — that's when the site's full "what's on your ballot"
view lights up with real contested races. Until then the district cards just
show the upcoming election date.

**Product note — primaries:** the site's data model supports showing the
primary itself (an `elections` row dated 2026-08-04 with races per party),
but a nonpartisan presentation of partisan primaries takes care. Recommend
skipping the primary this cycle and starting with the November general.

## 3. Adding new cities — checklist

Priority neighbors (all border current coverage):

| City | Officials directory | Status |
|---|---|---|
| Town and Country | https://www.town-and-country.org/ → Government → Board of Aldermen | ✅ Added (migrations/003). TODO: its state **senate** district (moved out of 24 in redistricting; unverified) and whether more House districts cover parts of it |
| Overland | https://overlandmo.org/226/City-Council | ✅ Added (migrations/003): MO-1, Senate 14, House 71 (part). TODO: check for additional House districts |
| St. Ann | https://www.stannmo.org/ → Government | Roster still needed (spread across pages). In MO-1, Senate 14 — verify House district |

Per-city process (same as the original three):
1. Pull mayor + council roster **from the city's official directory page**
   (names, ward, term, email, phone). Never from third-party aggregators.
2. Insert a `jurisdictions` row + `officials` rows (pattern in `seed.sql`).
3. Map the city to its districts in `jurisdiction_districts` (verify with the
   district-map links above; mark `partial` honestly).
4. Add the city to `assets/fallback-data.json`.
5. Check the city's April election cycle note (most St. Louis County
   municipalities elect councils each April).

## 4. Rollout order

1. **Migration + district seed** (`migrations/001`, `002`) — run in Supabase;
   site shows a "Your state & federal representatives" section per city.
2. **New cities** as their rosters are verified (needs the directory pages
   above, which weren't reachable from the automated environment).
3. **Post-primary (mid-August):** add November races + candidates per district.
4. **November general:** the ballot view becomes the main event for every
   covered city.

## 5. Entering the November 2026 ballot (after the Aug 4 primary)

The ballot renderer is live but shows "contests aren't listed yet" until races
exist, because nominees aren't certified until after the August 4 primary.
Once the certified list is published by the
[Secretary of State](https://www.sos.mo.gov/elections/candidates):

1. **Add a `races` row** per contest, attached to that scope's November 3
   `elections` row. Set `kind` (`office` or `measure`), `vote_for`, and for
   measures the verbatim `official_text`.
2. **Add `candidates` rows**, setting `incumbent` where it applies.
3. **Add a statewide scope** if not already present — a `districts` row with
   `level = 'statewide'` (e.g. "State of Missouri") holding the State Auditor
   race and statewide amendments. Statewide scopes attach to every city in the
   state automatically; no `jurisdiction_districts` rows needed.
4. **Add resources and link them.** Enter each debate/forum/interview once in
   `resources`, then attach it in `resource_links` to the race and/or to each
   candidate it covers. A forum covering a whole race should link to the race —
   the UI then shows it on the race page and on every candidate page in it,
   labelled "Also covers: …".
5. **Regenerate `assets/fallback-data.json`** so the offline snapshot matches.

Ballot order comes from `districts.level`; `races.sort_order` controls order
within a scope.

### Nonpartisan guardrails when entering data

- Aim for the **same categories of information for every candidate** in a race.
  If one candidate has a campaign site and interview linked, look for the
  equivalent for their opponents before publishing.
- For measures, link **both supporting and opposing** material where each exists.
- Prefer official and independent sources (election authorities, League of Women
  Voters, established local news) over partisan material.

## 6. Address-level district lookup (researched September 2026)

The `partial` flag means a city page sometimes has to say "if you live in
House District 87…". Resolving the visitor's actual location removes those
splits. This section records what was tested so it doesn't have to be
rediscovered.

### It works — one request does the whole job

```
https://geocoding.geo.census.gov/geocoder/geographies/onelineaddress
  ?address=12013+Colonial+Drive,+Maryland+Heights,+MO+63043
  &benchmark=Public_AR_Current
  &vintage=Current_Current
  &layers=all
  &format=json
```

Returns, in a single call and with no API key: congressional district, state
senate district, state house district, incorporated place, county, unified
school district, ZIP, and 2020 census block. The coordinates variant
(`geographies/coordinates?x=<lon>&y=<lat>`) takes the same parameters and is
what a browser geolocation button would use.

Verified against Maryland Heights: returned MO-1, Senate 24, House 87,
"Maryland Heights city", St. Louis County, Pattonville R-III — matching the
hand-researched table in §1.

### Four caveats, in order of how much they matter

1. **Congressional boundaries lag.** The response labels them "119th
   Congressional Districts" — the 2024 map. Missouri redrew mid-decade for
   2026. State legislative layers are labelled "2024" and are current, but
   **congressional results from this API must be checked against the new map**
   before being shown for a November 2026 ballot.
2. **Matches are interpolated, not rooftop.** A successful match returns the
   street segment's address range (e.g. `fromAddress: 12001`,
   `toAddress: 12069`) and a position estimated along it. Census and OSM
   disagreed by roughly 20 m on the same house. Irrelevant in the middle of a
   district, potentially wrong for an address sitting on a boundary.
3. **No fuzzy matching.** A misspelled street, a wrong house number, or an
   address that doesn't exist returns `"addressMatches":[]` with no
   suggestion. This is the likely real-world failure mode. Three empty results
   during testing turned out to be a bad test address, not missing coverage —
   don't conclude "no coverage" from a single miss.
4. **No wards or precincts.** Census has no layer for them. Only county data
   has these.

### Mailing city ≠ municipality

Large parts of unincorporated St. Louis County carry a "Maryland Heights, MO"
or "Creve Coeur, MO" postal address while belonging to no city government.
Someone in that situation who picks a city from the dropdown would be shown
aldermanic races they cannot vote in, and nothing would catch it.

The geocoder response solves this: it omits the `Incorporated Places` layer
for unincorporated territory. Location lookup can detect the case and say so.
**The city dropdown alone cannot** — this is a real correctness gap in the
current design, not just a convenience issue.

### Build order when this is picked up

1. **Location button** — browser geolocation → `geographies/coordinates`.
   Smallest change, no address handling at all, works with what's verified.
2. **House number + street picker** — street list built from TIGER/Line road
   files for St. Louis County, filtered to covered cities, stored in Supabase.
   Scoping autocomplete to covered streets means the visitor never types the
   fragile part, which removes most of caveat 3. Selecting a street also
   resolves the city, so no city dropdown is needed.
3. **Out-of-coverage ladder** — an address outside the five cities still gets
   statewide contests (they attach to every Missouri address), plus any
   state/federal district we happen to hold. Degrade to "we don't cover your
   city yet" with a link to the county Board of Elections, never a dead end.

Fallback whenever a lookup fails is the current city-level view, so this is an
enhancement on a working baseline rather than a new point of failure.

### Rejected alternatives

- **Nominatim** as primary — works, but its usage policy forbids per-keystroke
  autocomplete and requires attribution and rate limiting. Fine as a fallback
  for a failed Census match; not a foundation.
- **Commercial geocoders** (Google, Mapbox, Smarty) — reliable, but the key
  must be held server-side, which means visitor addresses would pass through
  infrastructure we operate. That forfeits "your address never leaves your
  browser", which is worth more to this project than the match rate.
- **County GIS address points + PostGIS** — the most accurate option, and the
  only one that yields wards and precincts. Deferred, not rejected: real
  ongoing maintenance, and Census is good enough for legislative districts.

### Privacy requirement

Lookups run from the browser, so the address never reaches our server or
Supabase. **Keep it out of the URL too** — resolve the address, then route to
the existing `#/city/<slug>`, holding resolved districts in memory. An address
in the hash would end up in browser history, shared links, and referrer
headers.

## 7. November 2026 — status

**The ballot is now essentially complete.** Source for everything below: the
St. Louis County Board of Elections "November 3, 2026 General Election —
Unofficial Ballot Content Report", generated 16 September 2026, plus the
Secretary of State's certified candidate booklet of 25 August 2026.

Measure text was transcribed from the county report **by script**, not by
hand — `official_text` is what a voter reads on the ballot, so paraphrase or
typo would defeat its purpose.

### What is on the site

| Scope | Contests |
|---|---|
| Federal | U.S. Representative (districts 1 and 2) |
| State | State Auditor; Senate 14 and 24; House 70, 71, 72, 87, 89 |
| County | County Executive, Prosecuting Attorney, County Assessor |
| Judicial | 19 retention questions, verbatim wording |
| Statewide measures | Constitutional Amendments 3, 6, 7, 8; Proposition A |
| County measures | Proposition A (County Auditor term), Proposition S (senior services levy) |
| City measures | Creve Coeur Proposition G (Government Center bonds) |
| School measures | Parkway Proposition P; Ritenour Propositions I and N |

### School districts — a scope added in migration 011

Coverage from TIGERweb school district polygons, percent of city area:

| City | School districts | Measures that apply |
|---|---|---|
| Maryland Heights | Parkway 52.8%, Pattonville 47.2% | Parkway P |
| Creve Coeur | Parkway 66.7%, Ladue 30.7%, Pattonville 2.6% | Parkway P |
| Town and Country | Parkway 97.9%, Kirkwood 1.6%, Ladue 0.5% | Parkway P |
| Overland | Ritenour 96.7%, University City 3.3% | Ritenour I and N |
| Bridgeton | Pattonville 50.7%, Hazelwood 47.5%, Ritenour 0.9% | Ritenour I and N |

Every one is marked partial — no city sits wholly inside one school district.
Bridgeton's 0.9% Ritenour sliver is genuine and included: a handful of
Bridgeton residents do vote on those measures, and omitting a real ballot item
is worse than showing one behind an "if you live in…" note.

### Still outstanding

**County Council.** Districts 1, 3, 5 and 7 are on the ballot. Which council
district each of our cities falls in is not in any dataset reachable from the
build environment, and the council map is not published as queryable boundary
geometry. A County Council scope exists with an election and no races, so the
site says the contest is not listed rather than looking complete. To resolve
it, a council district map or a sample ballot showing the council contest is
needed.

### The congressional map — a correction worth remembering

Migration 009 remapped cities using TIGERweb's "120th Congressional Districts"
layer, reasoning that the 120th Congress is elected in November 2026.

That was wrong, and migration 010 reverted it. Those boundaries come from
House Bill 1 (2025 Second Extraordinary Session), which is itself the subject
of the referendum on this ballot as statewide Proposition A. A referendum
petition suspends the act, so **the 2026 election runs under the previous
map.** The county's ballot report proves it: the entire county has exactly two
congressional contests, districts 1 and 2, and none for district 3.

The lesson: boundary geometry is authoritative about where lines are, not
about which map is in force. Only the election authority's own ballot answers
that, and it is the thing to check first.

If Proposition A passes, the new boundaries apply from the 2028 cycle and the
mapping needs revisiting then.

## 9. Address narrowing (built September 2026)

Supersedes the build order sketched in §6. The design changed once the extent
of partial coverage became clear: with school district measures on the ballot,
**every** city we serve splits across at least one scope, so the "if you live
in…" note went from an edge case to the common case.

### How it works

1. The visitor types an address, or clicks "Use my location".
2. An address goes to the Census **locations** endpoint, which returns
   coordinates. Geolocation skips this step entirely.
3. The point is tested against `assets/districts.geo.json`, which ships with
   the site. Point-in-polygon runs in the browser.
4. Scopes the address is not in are dropped from the ballot, and the page says
   which ones it hid.

### Why the boundaries ship with the site

Asking Census for the districts at a point would have been less code. It would
also have been wrong, silently.

The geographies endpoint returns whichever congressional vintage Census
currently publishes. Today that is the 119th, which is correct for this
election — but only by accident, and it will roll to the 120th without notice.
**The map in force for November 2026 is not the newest one**: HB1 is suspended
pending the Proposition A referendum on this ballot. Migration 009 made
precisely that mistake and had to be reverted in 010.

`tools/build-district-geo.py` pins the layer in one constant, `CONGRESS_LAYER`,
so the map can only change when someone changes it deliberately. Regenerate
after the 2026 election, once Proposition A's outcome is known.

The file is 63 KB raw, about 15 KB gzipped, and is fetched only when the tool
is used — never on the critical path.

### What it can and cannot resolve

| Scope | Resolvable | Why |
|---|---|---|
| U.S. House | ✅ | Boundaries shipped |
| School district | ✅ | Boundaries shipped |
| State House / Senate | n/a | Every city is wholly inside one |
| County Council | ❌ | No public boundary geometry found |

Districts we carry no scope for — Pattonville, Ladue, Hazelwood and the rest —
are in the file with a null slug. Their shapes are needed to rule a district
**out**: someone in Pattonville must not be shown Parkway's measure.

### Rules it follows

- **The address never enters the URL.** Resolved districts live in memory and
  `sessionStorage`; a shared link carries a city, never a home address.
- **`sessionStorage`, not `localStorage`** — the narrowing dies with the tab,
  so the next person using that browser does not inherit a stranger's address.
- **Every failure leaves the full ballot on screen.** No match, geocoder down,
  permission denied, boundaries unavailable: the page says what happened and
  changes nothing. The tool narrows a correct page; it never gates one.
- **Offered only where the city actually splits.** Where the picker already
  gives a certain answer, asking for an address takes something for nothing.
