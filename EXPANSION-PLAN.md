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

### Verified district assignments (July 2026)

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

| City | Officials directory | Notes |
|---|---|---|
| Town and Country | https://www.town-and-country.org/ → Government → Board of Aldermen | Mayor + 8 aldermen (2/ward); in MO-2, Senate 24?, House 89 (Hruza) — verify |
| Overland | https://overlandmo.org/226/City-Council | Mayor Marty A. Little (verified, term to 2030); 8 council (2/ward); in MO-1, Senate 14, House 71 (part) — verify wards/contacts from the directory |
| St. Ann | https://www.stannmo.org/ → Government | In MO-1, Senate 14 — verify House district |

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
