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

### District assignments — corrected September 2026 from boundary geometry

The July table below it was wrong for three of five cities. These figures are
polygon intersections: every Missouri district polygon from TIGERweb's
Legislative service against each city's polygon from its Places service,
computed with Shapely. Percentages are share of the city's area; anything
under 0.1% is boundary-precision noise.

| City | U.S. House (120th — Nov 2026) | MO Senate | MO House |
|---|---|---|---|
| Maryland Heights | **MO-2** 86.9% · **MO-3** 13.1% | **24** (100%) | **87** (100%) |
| Creve Coeur | **MO-2** (100%) | **24** (100%) | **71** (100%) |
| Bridgeton | **MO-1** (100%) | **14** (100%) | **70** (100%) |
| Overland | **MO-1** (100%) | **14** (100%) | **72** (100%) |
| Town and Country | **MO-2** (100%) | **15** (100%) | **89** (100%) |

Only Maryland Heights genuinely spans two districts for any office, so it is
the only city whose ballot carries an "if you live in…" note.

#### Two congressional maps, and which one applies

TIGERweb carries both. **Layer 0, "120th Congressional Districts; January 1,
2026 vintage", is the map being elected on November 3, 2026.** Layer 4, the
119th, is what the sitting Congress was elected under in 2024 and does not
apply to this ballot.

| City | 119th (sitting Congress) | 120th (Nov 2026 ballot) |
|---|---|---|
| Maryland Heights | CD 1 32.7% · CD 2 67.3% | CD 2 86.9% · CD 3 13.1% |
| Creve Coeur | CD 1 30.9% · CD 2 69.1% | CD 2 100% |
| Bridgeton, Overland | CD 1 100% | CD 1 100% |
| Town and Country | CD 2 100% | CD 2 100% |

State legislative districts are identical between the 2024 and 2026 layers for
all five cities, so only the congressional lines moved.

#### ⚠️ The July redistricting note was wrong

It said the mid-decade redraw affected only districts 4, 5 and 6 around Kansas
City, leaving MO-1 and MO-2 alone. The geometry says otherwise: the St. Louis
lines moved substantially, and **Maryland Heights was showing the 1st District
contest, which its residents cannot vote in under either map.**

The lesson is not about redistricting. It is that the whole July table came
from prose — legislator bios saying a district "includes Maryland Heights
(part)" — and prose cannot be checked. Geometry can. Anything that decides
which contest a person is shown should come from boundary data.

#### One known limitation

`jurisdiction_districts` has no notion of time, so one mapping answers both
"what is on your ballot" (120th map) and "who represents you now" (119th).
They disagree for Maryland Heights and Creve Coeur, each roughly a third in
the current 1st District. The ballot takes precedence, so those two cities no
longer show Wesley Bell under "who represents you now". Fixing it properly
means date-scoping the mapping table.

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

### ⚠️ Redistricting caveat

Missouri redrew its **congressional** map mid-decade for 2026; reporting says
the new lines affect districts 4, 5, and 6 (Kansas City area), leaving MO-1
and MO-2 as described above — but **verify the St. Louis-area lines are
unchanged** before the November election data goes in, in case of ongoing
litigation.

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

## 7. November 2026 — what still has to be pulled from official sources

The build environment cannot reach `sos.mo.gov`, `stlouiscountymo.gov`,
`house.mo.gov` or `senate.mo.gov`, so everything below has to come from a
person with a browser. Web search reaches secondary coverage, which is not an
acceptable source for a certified candidate list on a nonpartisan site.

### Where the official sources live

| What | Where |
|---|---|
| **Certified candidate list, Nov 3 2026** | [2026GeneralElectionCertifiedCandidates.pdf](https://www.sos.mo.gov/CMSImages/ElectionCandidates/2026GeneralElectionCertifiedCandidates.pdf) — one PDF, every state and federal contest |
| Same list, browsable | [Candidates on the Web](https://s1.sos.mo.gov/candidatesonweb/) |
| County offices, judicial retentions, local measures | [St. Louis County Board of Elections](https://stlouiscountymo.gov/st-louis-county-government/board-of-elections/) — the sample ballot lookup is the authority for what actually prints on a ballot |
| Dates and deadlines | [BOE election calendar](https://stlouiscountymo.gov/st-louis-county-government/board-of-elections/elections/resources-and-information/election-calendar/) and [state election calendar](https://www.sos.mo.gov/elections/calendar) |
| Absentee rules | [BOE absentee voting](https://stlouiscountymo.gov/st-louis-county-government/board-of-elections/elections/absentee-voting/) |
| Polling places | [BOE polling places](https://stlouiscountymo.gov/st-louis-county-government/board-of-elections/elections/polling-places/) |

The SoS PDF covers statewide, congressional, and legislative contests. It does
**not** cover county offices, judicial retention questions, or local measures —
those only appear on the county's sample ballot. Both sources are needed.

### 7a. Voting dates — VERIFIED 13 September 2026 ✓

`VOTING_GUIDE` in `assets/app.js` now matches the county's published
2026/2027 Election Calendar and the Secretary of State's Notice of Election:

| Date | Event | Source |
|---|---|---|
| Sept 22, 8 a.m. | Absentee voting with an excuse opens | RSMo 115.279(3) |
| **Oct 7, 5 p.m.** | **Last day to register** | RSMo 115.135(1) |
| Oct 20, 8 a.m. | No-excuse in-person absentee opens | RSMo 115.277 |
| Oct 21, 5 p.m. | Last day to request a mailed ballot | RSMo 115.279(3) |
| Nov 2, 5 p.m. | Last day to vote absentee in person at the BOE | county calendar |
| Nov 3, 6 a.m.–7 p.m. | Election Day, polls open | SoS Notice of Election |

Two dates the aggregators had missed entirely — Sept 22 and Nov 2 — are now
included. Re-verify against the calendar whenever a new election is added.

### 7b. Contests — state and federal DONE, county outstanding

Entered in `migrations/007-certified-november-contests.sql` from the certified
booklet:

| Contest | Certified candidates |
|---|---|
| Senate 24 | LaVanna Wrobley (R) · Tracy McCreery (D, incumbent) |
| Senate 14 | Vernon Norman (R) · Raychel Proudie (D) — open seat |
| House 87 | Dan Hyatt (R) · Connie Steinmetz (D, incumbent) |
| House 89 | George Hruza (R, incumbent) · Bryan Troop (D) |
| Judicial retention | 19 questions — 1 Supreme Court, 3 Court of Appeals Eastern, 15 in the 21st Circuit |

Candidate order follows the certified booklet's party order (Republican,
Democratic, Libertarian, Independent) throughout, including a correction to
migration 005, which had ordered MO-1 and MO-2 inconsistently.

**Still outstanding — only on the county sample ballot:**

- **St. Louis County offices.** County Executive is confirmed on the ballot.
  A `county` scope now exists with a November election and no races, so the
  site tells visitors the county contests are not listed yet rather than
  presenting an incomplete ballot as complete. Adding races to that election
  clears the notice automatically.
- **Any county or municipal measures**, and any constitutional amendment
  referred to November.

For each, capture the office title exactly as printed, every candidate with
certified party, incumbency, and `vote_for` where it is more than one.

### 7c. Identity questions — both resolved 19 September 2026 ✓

- **Nicole Greer** — the House 71 candidate and the Creve Coeur Ward 2 council
  member are the **same person**. Her campaign site (votegreer.com) carries
  both "Nicole Greer for Missouri House District 71" and "Nicole Greer for
  Creve Coeur City Council"; the city's own Ward 2 page matches. The merge
  `indexPeople()` performs is therefore correct, and her page should show both
  roles. No data change needed.

- **Senate 14's open seat** — Brian Williams, the sitting senator, ran for
  St. Louis County Executive rather than re-election and lost the August
  Democratic primary. He is not on the November ballot. Recorded as a comment
  in migration 007, not as site copy, since it comes from news reporting.

### 7d. Still open

- **Town and Country's state senate district.** Search could not settle it and
  the city currently shows **no state senate contest at all**, which is almost
  certainly wrong. Fastest resolution is the Census geocoder, which returns
  the state senate district for any point — see §6. Check two or three points
  across the city, since it may span districts:

  ```
  https://geocoding.geo.census.gov/geocoder/geographies/coordinates?x=<lon>&y=<lat>&benchmark=Public_AR_Current&vintage=Current_Current&layers=all&format=json
  ```

  Read `2024 State Legislative Districts - Upper` from the response. Note that
  layer is current; the congressional layer is not (§6, caveat 1).

- **County offices, measures, and judicial wording** — still need a sample
  ballot. The county's own lookup requires a voter-record login; open
  alternatives are Vote411 (League of Women Voters), Ballotpedia and
  BallotReady. None of them, nor the county site, is reachable from the build
  environment — WebSearch is the only external access available here, and
  search snippets are not an acceptable source for candidate names.

  **County Executive specifically:** news reporting consistently gives Jake
  Zimmerman (D) against Dennis Hancock (R), with at least one mention of a
  Green Party candidate. That last part is exactly why it is not entered — a
  nonpartisan site that omits a minor-party candidate from a race has failed
  at the one thing it promises. Enter the full field from an official source
  or leave the pending notice up.

## 8. District mappings checked against the geocoder (September 2026)

With `geocoding.geo.census.gov` reachable, the §1 table — built in July from
legislator bios and encyclopaedia prose — was checked against the Census 2024
state legislative layer. Points were sampled across each city's bounding box
and kept only where the API placed them inside that city.

| City | Sample points | Senate | House | Our §1 table said |
|---|---|---|---|---|
| Town and Country | 15/15 | **15** | 89 | senate district unknown |
| Maryland Heights | 105/105 | **24 only** | **87 only** | Senate 14 + 24; House 70 + 71 + 87 |
| Creve Coeur | 21/21 | 24 | 71 | ✅ matches |
| Bridgeton | 21/21 | 14 | 70 | ✅ matches |
| Overland | 34/34 | 14 | **72** | House 71 |

### What was acted on

`migrations/008-district-mapping-corrections.sql` makes only **additive**
changes, because sampling can prove a district is present in a city but never
that one is absent — a sliver can fall between sample points.

- **House 72 added, mapped to Overland**, with its certified contest
  (Jeffrey Jacks R, Patrick James Wroblewski D). District 72 was missing from
  our data entirely while Overland was shown District 71.
- **Senate 15 added, mapped to Town and Country.** No election row: District
  15 is odd-numbered and 2026 elects only even-numbered senate seats — every
  senate district in the certified booklet is even. Town and Country correctly
  has no state senate contest this cycle, and the seat will appear on its own
  in 2028.

### What was not

Deleting mappings needs an official district map. If the sampling is right,
**Maryland Heights is being shown three contests its residents cannot vote in**
(Senate 14, House 70, House 71) and its "if you live in District 70/71/87"
split is spurious; Overland's House 71 mapping is likewise wrong. The exact
delete statement is written out at the foot of migration 008, to run once
[house.mo.gov/districtmap.aspx](https://house.mo.gov/districtmap.aspx) or the
county's precinct maps confirm it.

Showing an extra contest is misleading; removing one wrongly would stop
someone seeing a race they can vote in. The second is worse, so the extras
stay until a map settles it.

### Method note

Sampling is a check, not a source. The authoritative answer is boundary
geometry — TIGER shapefiles or the county's precinct maps. Only
`geocoding.geo.census.gov` is allowlisted here; `tigerweb.geo.census.gov`,
`www2.census.gov` and `api.census.gov` are not, so the geometry route is not
available from this environment.
