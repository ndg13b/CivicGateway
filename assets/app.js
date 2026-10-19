/* ============================================================
   Civic Gateway — application logic (ES module)

   Expects the host page to define, BEFORE this module loads:
     window.CIVIC_CONFIG = {
       supabaseUrl:     "https://<project>.supabase.co",
       supabaseKey:     "<anon public key>",   // read-only by RLS
       fallbackDataUrl: "assets/fallback-data.json",
     };

   Two ideas drive this file:

   1. A ballot is ASSEMBLED, not stored. A voter's ballot is every contest
      from every scope covering them — city, state house/senate, congressional,
      statewide — collected and sorted into the order a real ballot reads.
      See buildBallot().

   2. Everything is a PAGE. Candidates, contests, and measures each get a
      real URL (a hash route) so they can be shared, bookmarked, and reached
      with the back button. See the router at the bottom.

   All text originating in the database is escaped with esc() before being
   placed in HTML, and URLs are validated with safeUrl().
   ============================================================ */

// Loaded on demand in fetchFromSupabase(), never as a static import. A static
// import that fails takes the whole module down before a line of it runs, so
// the saved copy never gets its chance: with esm.sh unreachable, the live site
// sat on "Loading…" indefinitely. As a dynamic import, a CDN outage is just
// one more way the database can be unreachable, and the fallback covers it.
const SUPABASE_JS = "https://esm.sh/@supabase/supabase-js@2";

const CONFIG = window.CIVIC_CONFIG || {};
const FETCH_TIMEOUT_MS = 8000;

const STATE_NAMES = {
  AL: "Alabama", AK: "Alaska", AZ: "Arizona", AR: "Arkansas", CA: "California",
  CO: "Colorado", CT: "Connecticut", DE: "Delaware", FL: "Florida", GA: "Georgia",
  HI: "Hawaii", ID: "Idaho", IL: "Illinois", IN: "Indiana", IA: "Iowa",
  KS: "Kansas", KY: "Kentucky", LA: "Louisiana", ME: "Maine", MD: "Maryland",
  MA: "Massachusetts", MI: "Michigan", MN: "Minnesota", MS: "Mississippi", MO: "Missouri",
  MT: "Montana", NE: "Nebraska", NV: "Nevada", NH: "New Hampshire", NJ: "New Jersey",
  NM: "New Mexico", NY: "New York", NC: "North Carolina", ND: "North Dakota", OH: "Ohio",
  OK: "Oklahoma", OR: "Oregon", PA: "Pennsylvania", RI: "Rhode Island", SC: "South Carolina",
  SD: "South Dakota", TN: "Tennessee", TX: "Texas", UT: "Utah", VT: "Vermont",
  VA: "Virginia", WA: "Washington", WV: "West Virginia", WI: "Wisconsin", WY: "Wyoming",
  DC: "District of Columbia",
};

// How a ballot reads, top to bottom. Measures are pulled out to their own
// closing section regardless of the scope that owns them.
const BALLOT_SECTIONS = [
  { label: "Federal", levels: ["us_senate", "us_house"] },
  { label: "State", levels: ["statewide", "state_senate", "state_house"] },
  { label: "County", levels: ["county"] },
  { label: "Judicial", levels: ["judicial"] },
  { label: "City", levels: ["municipal"] },
  // School districts currently carry only measures, which close the ballot.
  // The section is here for school board contests, which are elected in April.
  { label: "School", levels: ["school"] },
];

const LEVEL_LABELS = {
  us_senate: "U.S. Senate", us_house: "U.S. Congress", statewide: "Statewide office",
  state_senate: "State Senate", state_house: "State House", county: "County",
  judicial: "Judicial", municipal: "City", school: "School district",
};

const LOOKUP_LINKS = `<a href="https://house.mo.gov/legislatorlookup.aspx" target="_blank" rel="noopener">Look up your Missouri legislators</a> · <a href="https://ziplook.house.gov/htbin/findrep_house" target="_blank" rel="noopener">Find your U.S. representative</a>`;

// Shown in the masthead dateline and the footer. One constant so the two can
// never drift apart — they did, and sat three weeks stale.
const DATA_REVIEWED = "October 2026";

/* ---------- Voting logistics ----------
   Knowing what is on the ballot is only half of it; the other half is knowing
   how and by when to vote. Keyed by state, then by election date, so November
   deadlines cannot leak onto an April municipal ballot.

   This lives in code rather than the database because these are state-level
   statutory dates, not per-jurisdiction data. If a second state is ever added
   it moves to a table; the shape here is already the shape of that table.

   VERIFIED 13 Sept 2026 against the St. Louis County Board of Elections
   2026/2027 Election Calendar and the Secretary of State's Notice of Election
   in the certified-candidate booklet. Statute citations are the county's own.
   The mailed-ballot return deadline was added 10 Oct 2026: RSMo 115.293 counts
   absentee ballots received by the close of polls, which the county board's
   2024 FAQ and the City of St. Louis board's 2026 election page both state as
   7:00 p.m. on Election Day. The notary note is from the Secretary of State's how-to-vote page.
   Early voting sites and hours were added 14 Oct 2026 from the Board of
   Elections' own 2026 lookup (lookup_app_abs_2026_11 on its ArcGIS account,
   updated 22 Sept 2026): the Board plus 20 satellite sites from October 20,
   and BOTH Saturdays. The county's printed calendar lists only October 31,
   which is how "the only weekend option" got onto this page. It was wrong.
   Re-verify against the calendar before any future election is added — these
   are the one part of the site where being approximately right is not good
   enough, because a wrong deadline costs somebody their vote.

   A date that OPENS something carries `until`, the last day it stays open.
   Without it, the day absentee voting opened the row turned grey and read
   "Passed", hiding who qualifies, while it was the one thing a voter could
   actually go and do.                                                       */
const VOTING_GUIDE = {
  MO: {
    authority: "St. Louis County Board of Elections",
    authorityUrl: "https://stlouiscountymo.gov/st-louis-county-government/board-of-elections/",
    calendarUrl: "https://stlouiscountymo.gov/st-louis-county-government/board-of-elections/elections/resources-and-information/election-calendar/",
    stateUrl: "https://www.sos.mo.gov/elections/goVoteMissouri/",
    idNote:
      "Missouri asks for a government-issued photo ID at the polls. If you do " +
      "not have one, you can still cast a provisional ballot, and the state " +
      "offers a free ID for voting.",
    elections: {
      "2026-11-03": {
        pollHours: "6:00 a.m. to 7:00 p.m.",
        // The Board of Elections' own lookup tools for this election, on its
        // ArcGIS account. Election-specific, so they live here, not above.
        lookups: [
          { label: "Find an early voting site near you",
            url: "https://stlouiscovotes.maps.arcgis.com/apps/instant/nearby/index.html?appid=9301b4594bef4d9c9271778e4648179d" },
          { label: "Find your Election Day polling place",
            url: "https://stlouiscovotes.maps.arcgis.com/apps/instant/nearby/index.html?appid=13fb36e785c84dbdbcc5219f999652ba" },
          { label: "See your official sample ballot",
            url: "https://stlouiscovotes.maps.arcgis.com/apps/instant/lookup/index.html?appid=4c3116b104af40bea77ebea20aaae275" },
        ],
        dates: [
          {
            on: "2026-09-22",
            until: "2026-11-02",
            label: "Absentee voting opens, with an excuse",
            detail: "By mail or in person, if one of the state's ten reasons applies to you — being away on Election Day, illness, military service and others. Opens 8:00 a.m. (RSMo 115.279). Most mailed ballots need a notary's signature on the return envelope; the instructions that come with yours say whether it does.",
          },
          {
            on: "2026-10-07",
            label: "Last day to register to vote",
            detail: "By 5:00 p.m. Registering after this means voting in the next election, not this one (RSMo 115.135).",
          },
          {
            on: "2026-10-20",
            until: "2026-11-02",
            // Missouri law calls this no-excuse in-person absentee voting; almost
            // everyone else calls it early voting. The label uses the name voters
            // know and the detail keeps the legal one, so the row can still be
            // matched against the county calendar.
            label: "Early voting opens, no excuse needed",
            detail: "Legally called no-excuse in-person absentee voting. Vote in person with photo ID and no reason required, at the Board of Elections or any of 20 satellite sites around the county — libraries, community centers and others. Weekdays 8:00 a.m. to 4:30 p.m. through October 30. In person only — a mailed ballot still needs one of the ten reasons (RSMo 115.277).",
          },
          {
            on: "2026-10-21",
            label: "Last day to request a mailed ballot",
            detail: "Applications must reach the Board of Elections by 5:00 p.m. (RSMo 115.279). The ballot itself then has to be back by 7:00 p.m. on Election Day, so leave time for the mail both ways.",
          },
          {
            on: "2026-10-24",
            label: "Saturday early and absentee voting",
            detail: "The Board of Elections and all 20 satellite sites are open 9:00 a.m. to 1:00 p.m.",
          },
          {
            on: "2026-10-31",
            label: "Saturday early and absentee voting",
            detail: "The last Saturday before the election. The Board of Elections, 725 Northwest Plaza Dr., St. Ann, and all 20 satellite sites are open 9:00 a.m. to 1:00 p.m.",
          },
          {
            on: "2026-11-02",
            label: "Last day to vote early or absentee in person",
            detail: "At the Board of Elections and all 20 satellite sites, 8:00 a.m. to 5:00 p.m., the day before the election.",
          },
          {
            on: "2026-11-03",
            label: "Election Day",
            // The return deadline lives here rather than on the request-deadline
            // row: passed rows hide their detail, and this is the row still
            // showing when someone has a mailed ballot on the kitchen table.
            detail: "Polls are open 6:00 a.m. to 7:00 p.m. Bring photo ID. Voting by mail? Your ballot must reach the Board of Elections by 7:00 p.m. — a postmark is not enough (RSMo 115.293).",
          },
        ],
      },
    },
  },
};

let PLACES = {};      // "maryland-heights-mo" -> place view-model
let STATEWIDE = {};   // "MO" -> [district, …] applying to every city in that state

const $ = (id) => document.getElementById(id);

/* ---------- Safety helpers ---------- */

function esc(v) {
  return String(v ?? "")
    .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;").replaceAll("'", "&#39;");
}

function safeUrl(u) {
  // Guard the empties first. String(null) is "null", which resolves happily
  // against the page URL — so a missing website produced a working-looking
  // "Website" link pointing at /null on every candidate who had none.
  if (u == null) return null;
  const raw = String(u).trim();
  if (!raw || raw === "null" || raw === "undefined") return null;
  try {
    const parsed = new URL(raw, window.location.href);
    return ["http:", "https:"].includes(parsed.protocol) ? parsed.href : null;
  } catch { return null; }
}

function slugify(s) {
  return String(s).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

function initials(name) {
  const words = String(name).split(/\s+/).map((w) => w.replace(/[^\p{L}]/gu, "")).filter(Boolean);
  return words.slice(0, 2).map((w) => w[0].toUpperCase()).join("") || "•";
}

function formatDate(iso) {
  try {
    return new Date(`${iso}T12:00:00`).toLocaleDateString("en-US", {
      weekday: "long", year: "numeric", month: "long", day: "numeric",
    });
  } catch { return iso; }
}

function formatShortDate(iso) {
  try {
    return new Date(`${iso}T12:00:00`).toLocaleDateString("en-US", {
      year: "numeric", month: "long", day: "numeric",
    });
  } catch { return iso; }
}

// Local date, not UTC. toISOString() rolls over to tomorrow at 7 p.m. Central,
// which would have dropped election-day contests off the page at the exact
// moment the last voters are still in line.
function today() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

// Whole days from today to an ISO date: negative once it has passed, 0 today.
// Built from calendar parts so daylight-saving shifts can't round it off by one.
function daysUntil(iso) {
  const [y, m, d] = String(iso).split("-").map(Number);
  const [ty, tm, td] = today().split("-").map(Number);
  if (!y || !ty) return null;
  return Math.round((Date.UTC(y, m - 1, d) - Date.UTC(ty, tm - 1, td)) / 86400000);
}

function countdown(days) {
  if (days === 0) return "today";
  if (days === 1) return "tomorrow";
  return `${days} days away`;
}

/* ---------- Data loading ---------- */

const RACE_SELECT = `
  races(
    *,
    candidates(*, resource_links(resources(*))),
    resource_links(resources(*))
  )`;

async function fetchFromSupabase() {
  const { createClient } = await withTimeout(import(SUPABASE_JS), FETCH_TIMEOUT_MS);
  const supabase = createClient(CONFIG.supabaseUrl, CONFIG.supabaseKey);

  const jurisdictions = supabase.from("jurisdictions").select(`
    *,
    officials!officials_jurisdiction_id_fkey(*),
    elections!elections_jurisdiction_id_fkey(*, ${RACE_SELECT}),
    jurisdiction_districts(
      partial,
      districts(
        *,
        officials!officials_district_id_fkey(*),
        elections!elections_district_id_fkey(*, ${RACE_SELECT})
      )
    )
  `);

  // Statewide scopes are matched by state, not through jurisdiction_districts,
  // so a newly added city picks them up with nothing to remember.
  const statewide = supabase.from("districts").select(`
    *,
    officials!officials_district_id_fkey(*),
    elections!elections_district_id_fkey(*, ${RACE_SELECT})
  `).eq("level", "statewide");

  const [jRes, sRes] = await withTimeout(Promise.all([jurisdictions, statewide]), FETCH_TIMEOUT_MS);

  if (jRes.error) throw new Error(jRes.error.message);
  if (sRes.error) throw new Error(sRes.error.message);
  if (!jRes.data || !jRes.data.length) throw new Error("no rows returned");
  return { jurisdictions: jRes.data, statewide: sRes.data || [] };
}

function withTimeout(promise, ms) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error("timed out")), ms)),
  ]);
}

async function fetchFallback() {
  const res = await fetch(CONFIG.fallbackDataUrl || "assets/fallback-data.json");
  if (!res.ok) throw new Error(`fallback fetch failed (${res.status})`);
  const json = await res.json();
  if (!json.jurisdictions || !json.jurisdictions.length) throw new Error("fallback is empty");
  return { jurisdictions: json.jurisdictions, statewide: json.statewide || [] };
}

async function loadData() {
  showStatus("Loading available areas…");

  if (!CONFIG.supabaseUrl || !CONFIG.supabaseKey) {
    showError("This page is not configured: CIVIC_CONFIG is missing its Supabase URL or key.");
    return;
  }

  let raw;
  let usedFallback = false;
  try {
    raw = await fetchFromSupabase();
  } catch (dbErr) {
    console.warn("Database unavailable, trying offline snapshot:", dbErr.message);
    try {
      raw = await fetchFallback();
      usedFallback = true;
    } catch (fbErr) {
      console.warn("Fallback unavailable:", fbErr.message);
      showError("We couldn't load the data right now. This is usually temporary.");
      return;
    }
  }

  try {
    buildPlaces(raw);
    hideStatus();
    if (usedFallback) {
      const el = $("status");
      el.hidden = false;
      el.innerHTML = `<span>Live updates are temporarily unavailable — showing our most recently saved copy of this information.</span>`;
    }
    populateStates();
    route();
  } catch (err) {
    // Never fail silently: a stuck "Loading…" tells the visitor nothing and
    // leaves us nothing to debug with.
    console.error("Civic Gateway failed to render:", err);
    showError(`Something went wrong displaying this page (${err.message}). Reloading usually fixes it.`);
  }
}

/* ---------- Shaping the raw rows into view-models ---------- */

function mapPerson(p, extra = {}) {
  return {
    name: p.name,
    office: p.office || null,
    party: p.party || null,
    term: p.term || null,
    bio: p.bio || null,
    email: p.email || null,
    phone: p.phone || null,
    website: p.website || null,
    twitter: p.twitter || null,
    facebook: p.facebook || null,
    instagram: p.instagram || null,
    linkedin: p.linkedin || null,
    youtube: p.youtube || null,
    incumbent: !!p.incumbent,
    resources: (p.resource_links || []).map((l) => l.resources).filter(Boolean),
    ...extra,
  };
}

function mapDistrict(d, partial) {
  return {
    level: d.level,
    name: d.name,
    shortName: d.short_name,
    infoUrl: d.info_url,
    sortOrder: d.sort_order ?? 0,
    partial: !!partial,
    officials: (d.officials || []).slice().sort(bySort).map((o) => mapPerson(o)),
    elections: d.elections || [],
  };
}

const bySort = (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0);

function buildPlaces({ jurisdictions, statewide }) {
  PLACES = {};
  STATEWIDE = {};

  for (const d of statewide) {
    (STATEWIDE[d.state] = STATEWIDE[d.state] || []).push(mapDistrict(d, false));
  }

  for (const j of jurisdictions) {
    const key = slugify(`${j.name}-${j.state}`);
    const districts = (j.jurisdiction_districts || [])
      .map((link) => (link.districts ? mapDistrict(link.districts, link.partial) : null))
      .filter(Boolean)
      .sort((a, b) => a.sortOrder - b.sortOrder);

    const place = {
      key,
      name: j.name,
      state: j.state,
      county: j.county,
      website: j.city_website,
      social: { twitter: j.twitter, facebook: j.facebook, instagram: j.instagram, youtube: j.youtube },
      note: j.next_election_note,
      officials: (j.officials || []).slice().sort(bySort).map((o) => mapPerson(o)),
      cityElections: j.elections || [],
      districts,
    };

    place.ballot = buildBallot(place);
    indexPeople(place);
    PLACES[key] = place;
  }
}

/* ---------- Ballot assembly ----------
   Collect every contest a voter in this place will see on the next election
   date, from every scope, and order it the way a ballot reads.
------------------------------------------------------------------- */

function scopesFor(place) {
  // Every electoral scope covering this place: the city itself, its mapped
  // districts, and any statewide scope for its state.
  const scopes = [{
    level: "municipal",
    label: `City of ${place.name}`,
    partial: false,
    elections: place.cityElections,
    sortOrder: 0,
  }];
  for (const d of place.districts) {
    scopes.push({
      level: d.level, label: d.name, shortName: d.shortName,
      partial: d.partial, elections: d.elections, sortOrder: d.sortOrder,
    });
  }
  for (const d of (STATEWIDE[place.state] || [])) {
    scopes.push({
      level: d.level, label: d.name, shortName: d.shortName,
      partial: false, elections: d.elections, sortOrder: d.sortOrder,
    });
  }
  return scopes;
}

function buildBallot(place) {
  const scopes = scopesFor(place);
  const cutoff = today();

  // The nearest upcoming election date across all scopes is "the" next ballot.
  const dates = [];
  for (const s of scopes) {
    for (const e of s.elections || []) {
      if (e.election_date >= cutoff) dates.push(e.election_date);
    }
  }
  if (!dates.length) return null;
  const date = dates.sort()[0];

  let name = "Election";
  let note = null;
  for (const s of scopes) {
    for (const e of s.elections || []) {
      if (e.election_date !== date) continue;
      name = e.name || name;
      if (e.note) note = e.note;
    }
  }

  // With an address resolved, drop the scopes this address is not in. Only
  // levels we actually resolved are filtered — a scope we cannot pin down
  // (County Council) still shows for everyone, which is the honest default.
  const excluded = [];
  const keepScope = (s) => {
    if (!LOCATION) return true;
    const resolved = LOCATION.districts[s.level];
    if (resolved === undefined) return true;          // level not resolvable
    if (!s.partial) return true;                      // covers the whole city
    const mine = resolved && resolved.slug === s.shortName;
    if (!mine) excluded.push(s.label);
    return mine;
  };

  const contests = [];
  const pending = [];
  for (const s of scopes) {
    if (!keepScope(s)) continue;
    for (const e of (s.elections || [])) {
      if (e.election_date !== date) continue;
      if (!(e.races || []).length) pending.push(s.label);
      for (const r of (e.races || []).slice().sort(bySort)) {
        contests.push({
          id: `${slugify(r.title)}-${slugify(s.shortName || s.label)}`,
          title: r.title,
          description: r.description || null,
          kind: r.kind || "office",
          officialText: r.official_text || null,
          voteFor: r.vote_for ?? 1,
          scopeLevel: s.level,
          scopeLabel: s.label,
          scopeShort: s.shortName || null,
          partial: s.partial,
          candidates: (r.candidates || []).slice().sort(bySort).map((c) => mapPerson(c)),
          resources: (r.resource_links || []).map((l) => l.resources).filter(Boolean),
        });
      }
    }
  }

  // Propositions and amendments follow the offices, the way they print. Judicial
  // retention questions are the exception: they are measures mechanically —
  // a yes/no on a named judge — but a real ballot prints them as their own
  // block, not among the amendments. Keeping them in the Judicial section also
  // stops fifteen retention questions from burying a constitutional amendment.
  //
  // The measures themselves print in a fixed order, checked against all 95 of
  // the county's November 2026 sample ballots for our cities: statewide
  // questions, then county, then the judicial retention block, then city, then
  // school. Statewide and county measures therefore come BEFORE the judges and
  // local ones after — the order the walkthrough promises to follow.
  const isClosing = (c) => c.kind === "measure" && c.scopeLevel !== "judicial";
  const MEASURE_RANK = { statewide: 0, county: 1, municipal: 3, school: 4 };
  const rank = (c) => MEASURE_RANK[c.scopeLevel] ?? 5;
  // Array sort is stable, so each level keeps its own sort_order.
  const measures = contests.filter(isClosing).sort((a, b) => rank(a) - rank(b));
  const earlyMeasures = measures.filter((m) => rank(m) < 2);
  const lateMeasures = measures.filter((m) => rank(m) >= 2);
  const sectioned = contests.filter((c) => !isClosing(c));

  const sections = [];
  const pushSection = (def) => {
    const inSection = sectioned.filter((c) => def.levels.includes(c.scopeLevel));
    if (!inSection.length) return;
    inSection.sort((a, b) =>
      def.levels.indexOf(a.scopeLevel) - def.levels.indexOf(b.scopeLevel));
    // Contests for the same office across sibling districts (e.g. three state
    // house districts covering one city) collapse into one address-varies group.
    sections.push({ label: def.label, groups: groupByOffice(inSection) });
  };
  const asGroups = (list) => list.map((m) => ({ single: m }));
  for (const def of BALLOT_SECTIONS) {
    if (def.label === "Judicial") {
      if (earlyMeasures.length) {
        sections.push({ label: "Statewide and county measures", groups: asGroups(earlyMeasures) });
      }
    }
    pushSection(def);
  }
  if (lateMeasures.length) {
    sections.push({ label: "City and school measures", groups: asGroups(lateMeasures) });
  }

  return {
    date,
    name,
    note,
    pending: [...new Set(pending)],
    excluded: [...new Set(excluded)],
    sections,
    hasContests: contests.length > 0,
    otherDates: [...new Set(dates)].filter((d) => d !== date).sort(),
  };
}

function groupByOffice(contests) {
  // Two contests belong together when they are the same office at the same
  // level in different districts — the voter gets exactly one of them.
  const byOffice = new Map();
  for (const c of contests) {
    // Measures never group. Grouping means "you get exactly one of these",
    // which is true of one office across sibling districts and false of
    // measures — a voter answers every measure on their ballot. Without this,
    // baseOfficeName() reduces every "Retention — <judge>" to "Retention" and
    // folds fifteen separate questions into a single address-varies card.
    const officeKey = c.kind === "measure"
      ? `measure::${c.id}`
      : `${c.scopeLevel}::${baseOfficeName(c.title)}`;
    if (!byOffice.has(officeKey)) byOffice.set(officeKey, []);
    byOffice.get(officeKey).push(c);
  }
  const groups = [];
  for (const [, list] of byOffice) {
    if (list.length === 1) groups.push({ single: list[0] });
    else groups.push({ office: baseOfficeName(list[0].title), variants: list });
  }
  return groups;
}

function baseOfficeName(title) {
  // "State Representative — District 70" -> "State Representative"
  return String(title).split(/\s+[—–-]\s+/)[0].trim();
}

/* ---------- People / contest index for routing ---------- */

function indexPeople(place) {
  place.people = new Map();
  place.contests = new Map();

  const byName = new Map();

  const add = (person, context) => {
    // An incumbent seeking re-election appears twice in the data — once as a
    // current officeholder, once as a candidate. They are one person and get
    // one page: merge, preferring the candidate framing and any filled-in field.
    const existing = byName.get(person.name);
    if (existing) {
      const merged = place.people.get(existing);
      for (const [k, v] of Object.entries({ ...person, ...context })) {
        if (merged[k] == null || merged[k] === "" ||
            (Array.isArray(merged[k]) && !merged[k].length)) merged[k] = v;
      }
      if (context.role === "candidate") {
        Object.assign(merged, {
          role: "candidate",
          contestId: context.contestId,
          contestTitle: context.contestTitle,
          electionDate: context.electionDate,
          incumbent: merged.incumbent || person.incumbent,
        });
      }
      person.slug = existing;
      return;
    }

    const base = slugify(person.name);
    let s = base;
    let n = 2;
    while (place.people.has(s)) s = `${base}-${n++}`;
    place.people.set(s, { ...person, ...context, slug: s });
    byName.set(person.name, s);
    // Stamp the slug onto the source object so cards can link without a lookup.
    person.slug = s;
  };

  for (const o of place.officials) {
    add(o, { role: "official", contextLabel: `${place.name} city government` });
  }
  for (const d of place.districts) {
    for (const o of d.officials) {
      add(o, { role: "official", contextLabel: d.name, partial: d.partial });
    }
  }
  for (const d of (STATEWIDE[place.state] || [])) {
    for (const o of d.officials) add(o, { role: "official", contextLabel: d.name });
  }

  if (place.ballot) {
    for (const section of place.ballot.sections) {
      for (const group of section.groups) {
        const list = group.single ? [group.single] : group.variants;
        for (const c of list) {
          place.contests.set(c.id, c);
          for (const cand of c.candidates) {
            add(cand, {
              role: "candidate",
              contestId: c.id,
              contestTitle: c.title,
              contextLabel: c.title,
              electionDate: place.ballot.date,
            });
          }
        }
      }
    }
  }
}

/* ---------- Status / error UI ---------- */

function showStatus(msg) {
  const el = $("status");
  el.hidden = false;
  el.innerHTML = `<span class="spinner" aria-hidden="true"></span> ${esc(msg)}`;
}
function hideStatus() { $("status").hidden = true; }
function showError(msg) {
  const el = $("status");
  el.hidden = false;
  el.innerHTML = `<div class="error-box" role="alert">${esc(msg)}<br>
    <button type="button" id="retryBtn">Try again</button></div>`;
  $("retryBtn").addEventListener("click", () => loadData());
}

/* ---------- Location picker ---------- */

function statesInData() {
  return [...new Set(Object.values(PLACES).map((p) => p.state))].sort();
}

function populateStates() {
  const sel = $("state");
  const states = statesInData();
  sel.innerHTML = "";
  sel.disabled = false;

  const single = states.length === 1;
  if ($("stateField")) $("stateField").hidden = single;
  if ($("pickerRow")) $("pickerRow").classList.toggle("single", single);

  if (single) {
    sel.append(new Option(STATE_NAMES[states[0]] || states[0], states[0], true, true));
    populateCities(states[0]);
  } else {
    sel.append(new Option("Select a state…", ""));
    for (const s of states) sel.append(new Option(STATE_NAMES[s] || s, s));
    $("city").disabled = true;
    $("city").innerHTML = "";
    $("city").append(new Option("Select a state first", ""));
  }
}

function populateCities(state, selectedKey = null) {
  const sel = $("city");
  sel.innerHTML = "";
  sel.disabled = false;
  sel.append(new Option("Select your city…", ""));
  Object.values(PLACES)
    .filter((p) => p.state === state)
    .sort((a, b) => a.name.localeCompare(b.name))
    .forEach((p) => sel.append(new Option(p.name, p.key, false, p.key === selectedKey)));
}

function onStateChange() {
  const s = $("state").value;
  if (!s) {
    $("city").disabled = true;
    $("city").innerHTML = "";
    $("city").append(new Option("Select a state first", ""));
    navigate("/", { replace: true });
    return;
  }
  populateCities(s);
  navigate("/", { replace: true });
}

function onCityChange() {
  const key = $("city").value;
  PICKER_OPEN = false;
  navigate(key ? `/city/${key}` : "/");
}

/* ---------- Shared render pieces ---------- */

/* ---------- Contact links ----------

   One prominent link to the official or campaign site, then the social
   accounts as small marks. A candidate with six accounts and one with two
   should look comparable at a glance — a flat list makes the busier campaign
   look better documented, which is the same asymmetry the labelled slots
   exist to avoid. The site is the thing worth a real click; the rest are
   doors to the same person.                                                */

// Handle or full URL, either way. Stored data is inconsistent because it comes
// from several sources, and demanding one shape would just lose accounts.
function socialUrl(base, value) {
  const raw = String(value || "").trim();
  if (!raw) return null;
  if (/^https?:\/\//i.test(raw)) return safeUrl(raw);
  return safeUrl(base + encodeURIComponent(raw.replace(/^@/, "")));
}

const SOCIALS = [
  { key: "twitter",   label: "X (Twitter)", base: "https://twitter.com/",
    path: "M18.9 2H22l-6.8 7.7L23 22h-6.3l-4.9-6.4L6.2 22H3l7.3-8.3L2.4 2h6.4l4.4 5.9L18.9 2Zm-1.1 18h1.7L8.3 3.8H6.5L17.8 20Z" },
  { key: "facebook",  label: "Facebook", base: "https://facebook.com/",
    path: "M22 12a10 10 0 1 0-11.6 9.9v-7H7.9V12h2.5V9.8c0-2.5 1.5-3.9 3.8-3.9 1.1 0 2.2.2 2.2.2v2.5h-1.3c-1.2 0-1.6.8-1.6 1.6V12h2.8l-.4 2.9h-2.4v7A10 10 0 0 0 22 12Z" },
  { key: "instagram", label: "Instagram", base: "https://instagram.com/",
    path: "M12 2.2c3.2 0 3.6 0 4.9.1 3.3.1 4.8 1.7 4.9 4.9.1 1.3.1 1.6.1 4.8s0 3.6-.1 4.9c-.1 3.2-1.7 4.8-4.9 4.9-1.3.1-1.6.1-4.9.1s-3.6 0-4.9-.1c-3.2-.1-4.8-1.7-4.9-4.9C2.2 15.6 2.2 15.2 2.2 12s0-3.6.1-4.9c.1-3.2 1.7-4.8 4.9-4.9C8.4 2.2 8.8 2.2 12 2.2Zm0 5.1a4.7 4.7 0 1 0 0 9.4 4.7 4.7 0 0 0 0-9.4Zm0 7.7a3 3 0 1 1 0-6 3 3 0 0 1 0 6Zm4.9-7.9a1.1 1.1 0 1 0 0-2.2 1.1 1.1 0 0 0 0 2.2Z" },
  { key: "linkedin",  label: "LinkedIn", base: "https://www.linkedin.com/in/",
    path: "M6.9 21H3.3V9.3h3.6V21ZM5.1 7.7a2.1 2.1 0 1 1 0-4.2 2.1 2.1 0 0 1 0 4.2ZM21 21h-3.6v-5.7c0-1.4 0-3.1-1.9-3.1s-2.2 1.5-2.2 3V21H9.7V9.3h3.4V11h.1a3.8 3.8 0 0 1 3.4-1.9c3.6 0 4.3 2.4 4.3 5.5V21Z" },
  { key: "youtube",   label: "YouTube", base: "https://youtube.com/@",
    path: "M21.6 7.2a2.5 2.5 0 0 0-1.8-1.8C18.2 5 12 5 12 5s-6.2 0-7.8.4a2.5 2.5 0 0 0-1.8 1.8A26 26 0 0 0 2 12a26 26 0 0 0 .4 4.8 2.5 2.5 0 0 0 1.8 1.8C5.8 19 12 19 12 19s6.2 0 7.8-.4a2.5 2.5 0 0 0 1.8-1.8A26 26 0 0 0 22 12a26 26 0 0 0-.4-4.8ZM10 15.1V8.9l5.2 3.1-5.2 3.1Z" },
];

function contactLinks(c) {
  const site = safeUrl(c.website);
  const out = [];

  if (site) {
    let host = site;
    try { host = new URL(site).hostname.replace(/^www\./, ""); } catch { /* keep full */ }
    // Label by what the link IS, not by what we were hoping to find. Sitting
    // members' listed sites are usually their .gov office page, and calling
    // that a "campaign website" next to a challenger's actual campaign site
    // would compare two different things while implying they match.
    const official = /\.gov$/i.test(host) || /\.gov$/i.test(host.split(":")[0]);
    out.push(`<a class="site-link" href="${esc(site)}" target="_blank" rel="noopener">
        <span class="site-link-label">${
          official ? "Official office page"
                   : c.role === "candidate" ? "Campaign website" : "Website"}</span>
        <span class="site-link-host">${esc(host)}</span>
      </a>`);
  }

  const marks = [];
  for (const s of SOCIALS) {
    const url = socialUrl(s.base, c[s.key]);
    if (!url) continue;
    marks.push(`<a class="social" href="${esc(url)}" target="_blank" rel="noopener"
        title="${esc(s.label)}" aria-label="${esc(s.label)}">
        <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="${s.path}"/></svg>
      </a>`);
  }
  if (marks.length) out.push(`<div class="socials">${marks.join("")}</div>`);

  const direct = [];
  if (c.email) direct.push(`<a class="link" href="mailto:${esc(c.email)}">Email</a>`);
  if (c.phone) direct.push(`<a class="link" href="tel:${esc(String(c.phone).replace(/[^0-9+]/g, ""))}">${esc(c.phone)}</a>`);
  if (direct.length) out.push(`<div class="links">${direct.join("")}</div>`);

  return out.join("");
}

const RESOURCE_ICONS = { debate: "▶", interview: "🎤", info: "📄" };

function resourceCard(r, alsoCovers = []) {
  const url = safeUrl(r.url);
  if (!url) return "";
  const meta = [r.source, r.published_on ? formatShortDate(r.published_on) : null]
    .filter(Boolean).map(esc).join(" · ");
  const shared = alsoCovers.length
    ? `<span class="res-shared">Also covers: ${alsoCovers.map(esc).join(", ")}</span>` : "";
  // The note gets its own line: it is where a link says who it leaves out
  // ("recorded before the primary; X was not part of it"), and that should
  // read as a sentence, not as a fourth item in the byline.
  return `
    <a class="res" href="${esc(url)}" target="_blank" rel="noopener">
      <span class="res-ico" aria-hidden="true">${RESOURCE_ICONS[r.kind] || "🔗"}</span>
      <span class="res-body">
        <span class="res-title">${esc(r.title)}</span>
        ${meta ? `<span class="res-meta">${meta}</span>` : ""}
        ${r.note ? `<span class="res-note">${esc(r.note)}</span>` : ""}
        ${shared}
      </span>
    </a>`;
}

// The chip on a ballot card. Says how much is behind it, so "nothing yet" and
// "three links" don't look the same from the ballot.
function raceLinkLabel(c) {
  const n = (c.resources || []).length;
  return n ? `Debates &amp; info (${n})` : "Race page";
}

// What a race or measure page links to, and what it deliberately doesn't.
// Shown on every one of those pages, so the rule is public and the same
// everywhere. A function, not a constant: SUGGEST_URL is defined further down.
function resourceStandards() {
  return `<p class="neutrality">What we link here: recordings and reports of debates
  and candidate forums, nonpartisan election guides, official documents, and straight
  news coverage. We leave out endorsements, opinion pieces and campaign material.
  Anything published by the government asking voters to approve a measure is labeled
  as such. Civic Gateway does not endorse candidates or take positions on measures.
  <a href="${SUGGEST_URL}" target="_blank" rel="noopener">Suggest something we've
  missed</a>.</p>`;
}

const VOTE411_URL = "https://www.vote411.org/";

// A section that is always present. Empty, it says so plainly — on a race page
// "no debate has been held" is information, and a missing heading would hide it.
function resourceBlock(label, resources, emptyText) {
  return `<div class="page-sec"><h3>${esc(label)}</h3>
    ${resources.length
      ? resources.map((r) => resourceCard(r)).join("")
      : `<p class="empty-note">${esc(emptyText)} <a href="${SUGGEST_URL}" target="_blank" rel="noopener">Suggest one</a></p>`}
  </div>`;
}

function resourceSection(label, resources, { contest = null, excludeName = null } = {}) {
  if (!resources.length) return "";
  // A resource attached to a whole contest covers every candidate in it; on a
  // person's page we list the others so it's clear the link isn't one-sided.
  const alsoCovers = contest
    ? contest.candidates.map((c) => c.name).filter((n) => n !== excludeName)
    : [];
  return `<div class="page-sec"><h3>${esc(label)}</h3>
    ${resources.map((r) => resourceCard(r, alsoCovers)).join("")}</div>`;
}

function personCard(person, href, { featured = false, note = null, flag = null, compact = false } = {}) {
  return `
    <a class="person-card${featured ? " featured" : ""}${compact ? " compact" : ""}" href="${esc(href)}">
      ${compact ? "" : `<span class="avatar" aria-hidden="true">${esc(initials(person.name))}</span>`}
      <span class="person-info">
        <span class="person-name">${esc(person.name)}${
          person.incumbent ? '<span class="chip-inc">Incumbent</span>' : ""}</span>
        <span class="person-office">${esc(note || person.office || person.party || "")}</span>
        ${flag ? `<span class="on-ballot-flag">${esc(flag)}</span>` : ""}
      </span>
      <span class="person-more" aria-hidden="true">${compact ? "›" : "Details ›"}</span>
    </a>`;
}

/* ---------- View: the city page (ballot + officials) ---------- */

function renderCity(place) {
  setChrome({ picker: "fold", selected: place });

  let html = `
    <div class="jurisdiction-header">
      <h2>${esc(place.name)}, ${esc(STATE_NAMES[place.state] || place.state)}</h2>
      ${place.county ? `<span class="county">${esc(place.county)}</span>` : ""}
      <button type="button" class="linkish change-place" id="changePlace"
              aria-controls="pickerCard" aria-expanded="${PICKER_OPEN}">Change city or address</button>
    </div>
    ${deadlineBanner(place)}`;

  html += renderBallot(place);
  html += renderVotingInfo(place);
  // The city's own site and accounts are useful, but not before the ballot.
  const links = cityLinksRow(place);
  if (links) html += `<div class="city-links-sec"><span class="city-links-label">City of ${esc(place.name)} online</span>${links}</div>`;
  html += renderWhoRepresentsYou(place);

  paint(html);
}

/* ---------- The picker: address combobox and tabs ---------- */

let STREET_PICK = null;   // the street the visitor actually chose
let STREET_HITS = [];
let STREET_AT = -1;

function pickerMsg(text, kind = "info") {
  const el = $("pickerMsg");
  if (!el) return;
  el.textContent = text;
  el.className = `picker-msg ${kind}`;
  el.hidden = !text;
}

function closeStreetList() {
  const list = $("streetList"), input = $("streetInput");
  if (list) { list.hidden = true; list.innerHTML = ""; }
  if (input) input.setAttribute("aria-expanded", "false");
  STREET_HITS = []; STREET_AT = -1;
}

function renderStreetList(hits) {
  const list = $("streetList"), input = $("streetInput");
  if (!list) return;
  STREET_HITS = hits; STREET_AT = -1;
  if (!hits.length) { closeStreetList(); return; }
  list.innerHTML = hits.map((h, i) => `
    <li role="option" id="street-opt-${i}" data-i="${i}" aria-selected="false">
      <span class="street-name">${esc(h.name)}</span>
      <span class="street-city">${esc(h.city)}</span>
    </li>`).join("");
  list.hidden = false;
  input.setAttribute("aria-expanded", "true");
  for (const li of list.querySelectorAll("li")) {
    // mousedown, not click: blur would close the list before click landed.
    li.addEventListener("mousedown", (e) => {
      e.preventDefault();
      chooseStreet(Number(li.dataset.i));
    });
  }
}

function highlightStreet(next) {
  const list = $("streetList");
  if (!list || !STREET_HITS.length) return;
  STREET_AT = (next + STREET_HITS.length) % STREET_HITS.length;
  list.querySelectorAll("li").forEach((li, i) => {
    const on = i === STREET_AT;
    li.classList.toggle("is-active", on);
    li.setAttribute("aria-selected", on ? "true" : "false");
  });
  $("streetInput").setAttribute("aria-activedescendant", `street-opt-${STREET_AT}`);
}

function chooseStreet(i) {
  const hit = STREET_HITS[i];
  if (!hit) return;
  STREET_PICK = hit;
  $("streetInput").value = hit.name;
  closeStreetList();
  pickerMsg(`${hit.name} is in ${hit.city}.`);
  const num = $("houseNo");
  if (num && !num.value) num.focus();
}

async function onStreetInput() {
  const input = $("streetInput");
  STREET_PICK = null;
  try { await loadStreets(); }
  catch { pickerMsg("Street list unavailable — use the city tab instead.", "warn"); return; }
  renderStreetList(searchStreets(input.value));
}

function onStreetKey(e) {
  if (e.key === "ArrowDown") { e.preventDefault(); highlightStreet(STREET_AT + 1); }
  else if (e.key === "ArrowUp") { e.preventDefault(); highlightStreet(STREET_AT - 1); }
  else if (e.key === "Enter") {
    if (STREET_AT >= 0) { e.preventDefault(); chooseStreet(STREET_AT); }
    else if (STREET_HITS.length === 1) { e.preventDefault(); chooseStreet(0); }
    else onFindBallot();
  } else if (e.key === "Escape") closeStreetList();
}

// Resolve the chosen street even when the visitor typed it out and never
// touched the list — an exact normalized match is as good as a click.
function settledStreet() {
  if (STREET_PICK) return STREET_PICK;
  const typed = normalizeStreet(($("streetInput") || {}).value || "");
  if (!typed) return null;
  const exact = STREET_INDEX.filter((s) => s.key === typed);
  return exact.length === 1 ? exact[0] : null;
}

async function onFindBallot() {
  closeStreetList();
  try { await loadStreets(); }
  catch { pickerMsg("Street list unavailable — use the city tab instead.", "warn"); return; }

  const street = settledStreet();
  if (!street) {
    pickerMsg("Pick a street from the list so we know which city you're in.", "warn");
    return;
  }
  const raw = (($("houseNo") || {}).value || "").trim();
  if (!raw) { pickerMsg("Add your house number.", "warn"); $("houseNo").focus(); return; }

  // Catch a wrong number here rather than letting the geocoder return nothing
  // and leaving the visitor to guess which half was wrong.
  const n = parseInt(raw, 10);
  if (Number.isFinite(n) && street.lo != null && (n < street.lo || n > street.hi)) {
    pickerMsg(
      `${street.name} runs from ${street.lo} to ${street.hi}. Check the number — ` +
      `or use the city tab if that address is right.`, "warn");
    return;
  }

  pickerMsg("Looking up your districts…");
  const query = `${raw} ${street.name}, ${street.city}, MO`;
  try {
    const { lon, lat, label } = await geocode(query);

    // The geocoder's answer has to agree with the street list about which
    // city this is. A mismatch means the lookup landed somewhere else —
    // through a stale index, an ambiguous name, or a bad response — and
    // acting on it would show someone another city's ballot.
    await loadGeo();
    const landed = cityAt(lon, lat);
    if (landed && landed.name !== street.city) {
      pickerMsg(
        `That lookup came back in ${landed.name}, not ${street.city}. ` +
        `Showing ${landed.name} — switch to the city tab if that's wrong.`);
    } else if (!landed) {
      pickerMsg(`We couldn't place that inside ${street.city}. Use the city tab instead.`, "warn");
      return;
    }
    await resolvePoint(lon, lat, label, street.city);
  } catch (err) {
    pickerMsg(
      String(err.message) === "no match"
        ? `We couldn't place ${raw} ${street.name}. Use the city tab to see the whole ${street.city} ballot.`
        : "The address lookup is unavailable right now. The city tab still works.",
      "warn");
  }
}

function showPane(which) {
  const addr = which === "address";
  for (const [tab, pane, on] of [["tabAddress", "paneAddress", addr],
                                 ["tabCity", "paneCity", !addr]]) {
    const t = $(tab), p = $(pane);
    if (t) { t.classList.toggle("is-active", on); t.setAttribute("aria-selected", String(on)); }
    if (p) p.hidden = !on;
  }
  pickerMsg("");
}

/* ---------- Address tool behaviour ---------- */

function addrMsg(text, kind = "info") {
  const el = $("addrMsg");
  if (!el) return;
  el.textContent = text;
  el.className = `addr-msg ${kind}`;
  el.hidden = !text;
}

// Anything that fails here leaves the full city ballot on screen. The tool is
// a narrowing convenience on top of a correct page, never a gate in front of
// one, so every failure path says what happened and changes nothing.
// `hintCity` is the city the street list already told us. Geolocation has no
// such hint, so the point is tested against the city outlines instead.
async function resolvePoint(lon, lat, label, hintCity = null) {
  await loadGeo();
  const districts = districtsAt(lon, lat);
  const city = cityAt(lon, lat) ||
    (hintCity ? { slug: slugify(`${hintCity}-MO`), name: hintCity } : null);

  if (!city) {
    const msg = "That location is outside the cities we cover yet. " +
                "Your county and state contests are the same either way — " +
                "pick a nearby city to see them.";
    if ($("pickerMsg")) pickerMsg(msg, "warn"); else addrMsg(msg, "warn");
    return;
  }
  if (!PLACES[city.slug]) {
    const msg = `We don't have ${city.name} yet. Your state and county contests still apply.`;
    if ($("pickerMsg")) pickerMsg(msg, "warn"); else addrMsg(msg, "warn");
    return;
  }

  LOCATION = { label, districts, city: city.slug };
  writeKept(KEY_LOCATION, LOCATION);
  // The ballot's own banner now says what was resolved, so the picker's
  // progress line has nothing left to report — and the picker can fold away.
  pickerMsg("");
  PICKER_OPEN = false;
  refreshBallots();
  // Routing by hash rather than calling render directly keeps the back button
  // working, and keeps the address itself out of the URL. Someone who came
  // here from the walkthrough's "first, your address" step goes back to it.
  const target = WALK_PENDING ? `#/city/${city.slug}/walk` : `#/city/${city.slug}`;
  WALK_PENDING = false;
  if (location.hash !== target) location.hash = target;
  else route();
}

function cityAt(lon, lat) {
  for (const d of (GEO && GEO.districts) || []) {
    if (d.kind === "city" && inGeometry(lon, lat, d.geometry)) return d;
  }
  return null;
}

// The picker is above the ballot and may be scrolled off; move focus as well
// as the scroll so keyboard users land in the field too.
function openPicker() {
  PICKER_OPEN = true;
  const card = $("pickerCard");
  if (card) card.hidden = false;
  const btn = $("changePlace");
  if (btn) btn.setAttribute("aria-expanded", "true");
}

function onChangePlace() {
  openPicker();
  const card = $("pickerCard");
  if (card) card.scrollIntoView({ behavior: "smooth", block: "start" });
  const first = $("tabAddress");
  if (first) first.focus({ preventScroll: true });
}

function jumpToAddressPicker() {
  openPicker();
  showPane("address");
  const card = $("pickerCard");
  if (card) card.scrollIntoView({ behavior: "smooth", block: "center" });
  const street = $("streetInput");
  if (street) { street.focus({ preventScroll: true }); loadStreets().catch(() => {}); }
}

// Used from the picker and from inside a ballot, so messages go to whichever
// of the two message areas is currently on the page.
function locMsg(text, kind = "info") {
  if ($("pickerMsg")) pickerMsg(text, kind); else addrMsg(text, kind);
}

function onUseLocation() {
  if (!navigator.geolocation) {
    locMsg("This browser can't share your location. Type an address instead.", "warn");
    return;
  }
  locMsg("Asking your browser for your location…");
  navigator.geolocation.getCurrentPosition(
    (pos) => resolvePoint(pos.coords.longitude, pos.coords.latitude, "your location")
      .catch(() => locMsg("Couldn't load district boundaries.", "warn")),
    () => locMsg("Location permission was declined. You can type an address instead.", "warn"),
    { timeout: 10000, maximumAge: 60000 });
}

function clearLocation() {
  LOCATION = null;
  writeKept(KEY_LOCATION, null);
  refreshBallots();
  route();
}

// A ballot is assembled once at load, so narrowing to an address has to
// reassemble it. indexPeople() rebuilds its maps from scratch, so re-running
// both is safe and keeps person and contest routes pointing at what is
// actually on screen.
function refreshBallots() {
  for (const place of Object.values(PLACES)) {
    place.ballot = buildBallot(place);
    indexPeople(place);
  }
}

// Rendering replaces the results element wholesale, so the controls are bound
// after each paint rather than once at boot.
function bindAddressTool() {
  on("changePlace", "click", onChangePlace);
  on("addrJump", "click", jumpToAddressPicker);
  on("addrGeo", "click", onUseLocation);
  on("addrClear", "click", clearLocation);
}

function cityLinksRow(p) {
  const parts = [];
  const site = safeUrl(p.website);
  if (site) parts.push(`<a class="link" href="${esc(site)}" target="_blank" rel="noopener">Official city website</a>`);
  if (p.social.twitter) parts.push(`<a class="link" href="https://twitter.com/${encodeURIComponent(p.social.twitter)}" target="_blank" rel="noopener">X / Twitter</a>`);
  if (p.social.facebook) parts.push(`<a class="link" href="https://facebook.com/${encodeURIComponent(p.social.facebook)}" target="_blank" rel="noopener">Facebook</a>`);
  if (p.social.instagram) parts.push(`<a class="link" href="https://instagram.com/${encodeURIComponent(p.social.instagram)}" target="_blank" rel="noopener">Instagram</a>`);
  const yt = safeUrl(p.social.youtube);
  if (yt) parts.push(`<a class="link" href="${esc(yt)}" target="_blank" rel="noopener">YouTube</a>`);
  return parts.length ? `<div class="city-links">${parts.join("")}</div>` : "";
}

function renderBallot(place) {
  const b = place.ballot;
  if (!b) {
    return `<div class="notice"><strong>No election is currently scheduled.</strong>
      ${place.note ? ` ${esc(place.note)}` : ""}</div>`;
  }

  let html = `<section class="ballot-panel" aria-label="What is on your ballot">
    <div class="ballot-head">
      <div class="kicker">What's on your ballot</div>
      <h3>${esc(b.name)} <span class="when">${esc(formatDate(b.date))}</span></h3>
      ${b.hasContests ? `<a class="walk-cta" href="${walkHref(place)}">${
        Object.keys(picksFor(b.date)).length ? "Continue walking through my ballot" : "Walk me through my ballot"} →</a>` : ""}
    </div>
    ${ballotSummary(b)}
    ${addressTool(place, b)}`;

  // The caveat belongs with the ballot, but at its end: read first, it was a
  // paragraph between the visitor and every race.
  const accuracy = `<div class="accuracy-note">
      ${LOCATION
        ? `<strong>Narrowed to your address.</strong>
           Contests for districts you are not in have been removed.`
        : `<strong>This is what we expect on a ${esc(place.name)} ballot.</strong>
           Some contests depend on your exact street address — ${LOOKUP_LINKS}.`}
      Always confirm with your local election authority before voting.
      ${b.note ? `<br><span class="note-status">${esc(b.note)}</span>` : ""}
    </div>`;

  if (!b.hasContests) {
    return html + accuracy + `<div class="notice"><strong>Contests for this election aren't listed yet.</strong>
      We add each contest and its candidates once they are officially certified.
      In the meantime, your current representatives are listed below.</div>
      </section>`;
  }

  let itemNo = 0;
  for (const section of b.sections) {
    html += `<div class="ballot-section" id="sec-${esc(slugify(section.label))}"><span class="ballot-section-label">${esc(section.label)}</span></div>`;

    // A section made entirely of retention questions gets the list treatment.
    const retentions = section.groups
      .map((g) => g.single)
      .filter((c) => c && c.kind === "measure" && c.scopeLevel === "judicial");
    if (retentions.length === section.groups.length && retentions.length) {
      const block = renderRetentionBlock(place, retentions, itemNo);
      html += block.html;
      itemNo = block.nextNo;
      continue;
    }

    html += `<div class="contest-grid">`;
    for (const group of section.groups) {
      itemNo += 1;
      html += group.single
        ? renderContest(place, group.single, itemNo)
        : renderVariantGroup(place, group, itemNo);
    }
    html += `</div>`;
  }

  if (b.pending.length) {
    html += `<div class="notice"><strong>More contests are expected on this ballot.</strong>
      We haven't listed the ${esc(b.pending.join(", "))} ${b.pending.length === 1 ? "contest" : "contests"}
      yet — we add each one only after confirming it against official sources.
      Your official sample ballot will show everything you can vote on.</div>`;
  }
  html += `<div class="ballot-end">End of ballot</div>${accuracy}</section>`;
  return html;
}

// Offered only when this city actually splits across a scope an address can
// settle. Where the city picker already gives a certain answer, asking for an
// address would be taking something for nothing.
function citySplits(place) {
  return place.districts.some(
    (d) => d.partial && RESOLVABLE.includes(d.level));
}

function addressTool(place, b) {
  if (!citySplits(place)) return "";

  if (LOCATION) {
    const bits = [];
    for (const level of RESOLVABLE) {
      const d = LOCATION.districts[level];
      if (d && d.slug) bits.push(d.name);
      else if (d) bits.push(`${d.name} (no contests here)`);
    }
    return `<div class="addr-tool resolved">
        <div class="addr-resolved">
          <strong>Showing the ballot for ${esc(LOCATION.label)}</strong>
          ${bits.length ? `<span class="addr-districts">${esc(bits.join(" · "))}</span>` : ""}
          ${b.excluded.length
            ? `<span class="addr-districts">Hidden: ${esc(b.excluded.join(", "))}</span>` : ""}
        </div>
        <button type="button" class="addr-clear" id="addrClear">Show the whole city again</button>
      </div>`;
  }

  // Rather than a second address box with different behaviour from the one in
  // the picker, send people to the picker. One address control, one set of
  // rules about what it accepts.
  return `<div class="addr-tool">
      <p class="addr-prompt"><strong>Some races below depend on your street address.</strong>
        Add it to see only yours.</p>
      <div class="addr-row">
        <button type="button" id="addrJump">Narrow to my address</button>
        <button type="button" id="addrGeo" class="linkish">or use my location</button>
      </div>
      <div class="addr-msg" id="addrMsg" hidden></div>
    </div>`;
}

// Seeing the size of the ballot up front is less daunting than discovering it
// by scrolling, and the jump links make a long ballot navigable.
function ballotSummary(b) {
  let offices = 0;
  let measures = 0;
  let retentions = 0;
  for (const section of b.sections) {
    for (const g of section.groups) {
      const list = g.single ? [g.single] : g.variants;
      const first = list[0];
      if (!first) continue;
      if (first.kind !== "measure") offices += 1;
      // Counting judge retentions as "ballot measures" undersells how much of
      // the ballot they are and misnames them — people expect "measures" to
      // mean propositions and amendments.
      else if (first.scopeLevel === "judicial") retentions += 1;
      else measures += 1;
    }
  }
  if (!offices && !measures && !retentions) return "";
  const bits = [];
  if (offices) bits.push(`${offices} race${offices === 1 ? "" : "s"}`);
  if (measures) bits.push(`${measures} measure${measures === 1 ? "" : "s"}`);
  if (retentions) bits.push(`${retentions} judge${retentions === 1 ? "" : "s"} to keep or remove`);
  // Short names for the jump links; the section headings keep the full ones.
  const SHORT = { "Statewide and county measures": "Measures", "Judicial": "Judges",
                  "City and school measures": "Local measures" };
  const jumps = b.sections
    .map((s) => `<a href="#sec-${esc(slugify(s.label))}">${esc(SHORT[s.label] || s.label)}</a>`)
    .join("");
  return `<div class="ballot-summary">
      <span class="ballot-count">${esc(bits.join(" · "))}</span>
      <span class="ballot-jumps">${jumps}</span>
    </div>`;
}

// The number is ours, for scanning and reference — it is not an official
// ballot item number, so it stays visually quiet.
function itemNumber(n) {
  return n ? `<span class="item-no" aria-hidden="true">${n}</span>` : "";
}

function renderContest(place, c, num) {
  if (c.kind === "measure") return renderMeasureCard(place, c, num);

  const href = `#/city/${place.key}/contest/${c.id}`;
  const sub = [
    c.voteFor > 1 ? `Vote for up to ${c.voteFor}` : "Vote for one",
    c.scopeLabel,
  ].filter(Boolean).join(" · ");

  // Every contest has a page, whether or not we have found anything to put on
  // it yet. Hiding the link until a debate turns up made the page impossible
  // to find, and an empty page that says so is itself useful to a voter.
  return `
    <div class="contest">
      <div class="contest-head">
        <h4>${itemNumber(num)}<a class="contest-link" href="${esc(href)}">${esc(c.title)}</a></h4>
        <div class="contest-actions"><a class="chip-btn" href="${esc(href)}">${raceLinkLabel(c)}</a></div>
      </div>
      <div class="contest-sub">${esc(sub)}</div>
      ${c.description ? `<p class="race-description">${esc(c.description)}</p>` : ""}
      ${c.partial ? `<div class="varies"><strong>Depends on your address.</strong>
        This district covers only part of ${esc(place.name)}.</div>` : ""}
      ${c.candidates.length
        ? `<div class="people-grid tight">${c.candidates.map((cand) =>
            personCard(cand, personHref(place, cand), { note: cand.party, compact: true })).join("")}</div>`
        : `<p class="nothing">Candidates for this contest aren't certified yet.</p>`}
    </div>`;
}

function renderVariantGroup(place, group, num) {
  let html = `
    <div class="contest wide">
      <div class="contest-head"><h4>${itemNumber(num)}${esc(group.office)}</h4></div>
      <div class="contest-sub">Vote for one</div>
      <div class="varies"><strong>${esc(place.name)} spans more than one district for this office.</strong>
        Your ballot will show only one of them — ${LOOKUP_LINKS}.</div>`;
  for (const v of group.variants) {
    html += `
      <div class="district-option">
        <div class="doh">If you're in ${esc(v.scopeShort || v.scopeLabel)}
          <a class="chip-btn" href="#/city/${esc(place.key)}/contest/${esc(v.id)}">${raceLinkLabel(v)}</a></div>
        <div class="people-grid tight">
          ${v.candidates.length
            ? v.candidates.map((cand) => personCard(cand, personHref(place, cand), { note: cand.party, compact: true })).join("")
            : `<p class="nothing">Candidates not certified yet.</p>`}
        </div>
      </div>`;
  }
  return html + `</div>`;
}

// Judicial retention is a run of near-identical questions — nineteen of
// "Shall Judge <name> of <court> be retained in office?" — where the only
// thing that changes is the name. Nineteen full contest cards is eight
// thousand pixels of ballot that looks far more daunting than the decision
// actually is. Set them as a list under each court instead, explain the
// mechanic once, and keep the full official text on each question's own page.
function renderRetentionBlock(place, contests, startNo) {
  const byCourt = new Map();
  for (const c of contests) {
    const court = c.scopeLabel || "Judicial";
    if (!byCourt.has(court)) byCourt.set(court, []);
    byCourt.get(court).push(c);
  }

  let n = startNo;
  let html = `<div class="retention">
    <p class="retention-lead">These judges are not running against anyone. For
    each one you vote <strong>yes</strong> to keep them on the bench or
    <strong>no</strong> to remove them. Leaving one blank is also allowed.</p>`;

  for (const [court, list] of byCourt) {
    html += `<div class="retention-court">${esc(court)}</div><ul class="retention-list">`;
    for (const c of list) {
      n += 1;
      const name = String(c.title).replace(/^Retention\s+[—–-]\s+/, "");
      html += `<li class="retention-item">
          ${itemNumber(n)}
          <a class="retention-name" href="#/city/${esc(place.key)}/measure/${esc(c.id)}">${esc(name)}</a>
          <span class="retention-yn">Yes / No</span>
        </li>`;
    }
    html += `</ul>`;
  }
  return { html: html + `</div>`, nextNo: n };
}

function renderMeasureCard(place, m, num) {
  return `
    <div class="measure">
      <h4>${itemNumber(num)}${esc(m.title)}</h4>
      <div class="contest-sub">${esc(m.scopeLabel)} · Vote yes or no</div>
      ${m.officialText ? `<div class="official-text">${esc(m.officialText)}</div>` : ""}
      <div class="yn"><span>YES</span><span>NO</span></div>
      <a class="chip-btn" href="#/city/${esc(place.key)}/measure/${esc(m.id)}">Read full text &amp; information →</a>
    </div>`;
}

function personHref(place, person) {
  return `#/city/${place.key}/person/${person.slug || slugify(person.name)}`;
}

/* ---------- Narrowing a ballot to one address ----------

   Several scopes only cover part of a city — Maryland Heights and Creve Coeur
   each straddle two congressional districts, and every city we serve straddles
   two or more school districts. Without an address the ballot has to show both
   sides behind an "if you live in…" note, which is honest but is work we are
   pushing onto the reader.

   Two deliberate choices:

   1. THE BOUNDARIES ARE OURS, NOT AN API'S. assets/districts.geo.json ships
      with the site and the point-in-polygon runs here. Asking Census for a
      congressional district would return whichever vintage it currently
      publishes, and the map in force for this election is NOT the newest one —
      HB1 is suspended pending the Proposition A referendum. Migration 009 made
      exactly that mistake. tools/build-district-geo.py pins the layer.

   2. THE ADDRESS NEVER LEAVES THE BROWSER, except to the Census geocoder, and
      never enters the URL. Resolved districts live in memory and in browser
      storage (see "What this site keeps on your device"), so a shared link
      carries a city, never a home address.                                   */

let LOCATION = null;   // { label, city, districts: {us_house: "MO-1", school: "…"|null} }
let GEO = null;        // lazily fetched districts.geo.json

/* ---------- What this site keeps on your device ----------
   Two things, and only on the device: where you are (the districts an address
   resolved to) and the choices made in the ballot walkthrough. Nothing is sent
   anywhere — the site has no server to send it to.

   By default both live in sessionStorage: they survive a refresh and moving
   between pages, and are gone when the tab closes, so the next person at a
   library computer starts clean. "Remember on this device" is the visitor's
   choice to move both into localStorage, so they are still there next visit.
   "Forget" clears everything, everywhere. Even when remembered, the street
   address itself is not kept — only the districts it resolved to.

   Never cookies: a cookie is sent with every request for the page, which
   would hand a voter's choices to the web host for no reason.            */
const KEY_LOCATION = "civic.location";
const KEY_PICKS = "civic.picks";
const KEY_REMEMBER = "civic.remember";

let PICKS = {};        // { "2026-11-03": { "<contest id>": choice, … } }

function remembering() {
  try { return localStorage.getItem(KEY_REMEMBER) === "1"; } catch { return false; }
}

function keptStore() {
  try { return remembering() ? localStorage : sessionStorage; } catch { return null; }
}

function readKept(key) {
  try {
    const s = keptStore();
    const v = s && s.getItem(key);
    return v ? JSON.parse(v) : null;
  } catch { return null; }
}

function writeKept(key, value) {
  try {
    const s = keptStore();
    if (!s) return;
    if (value == null) { s.removeItem(key); return; }
    // A remembered location outlives the visit, so it drops the address.
    const v = key === KEY_LOCATION && remembering() && value.label !== "your location"
      ? { ...value, label: "your saved address" } : value;
    s.setItem(key, JSON.stringify(v));
  } catch { /* storage unavailable (private mode): it just won't outlive the page */ }
}

function setRemember(on) {
  try {
    if (on) localStorage.setItem(KEY_REMEMBER, "1");
    else {
      localStorage.removeItem(KEY_REMEMBER);
      localStorage.removeItem(KEY_LOCATION);
      localStorage.removeItem(KEY_PICKS);
    }
  } catch { return; }
  // Re-write both into whichever store now applies, then clear the other.
  writeKept(KEY_LOCATION, LOCATION);
  writeKept(KEY_PICKS, PICKS);
  if (on) {
    try { sessionStorage.removeItem(KEY_LOCATION); sessionStorage.removeItem(KEY_PICKS); } catch { /* fine */ }
  }
}

function forgetEverything() {
  for (const get of [() => localStorage, () => sessionStorage]) {
    try {
      const s = get();
      for (const k of [KEY_LOCATION, KEY_PICKS, KEY_REMEMBER]) s.removeItem(k);
    } catch { /* nothing to clear */ }
  }
  LOCATION = null;
  PICKS = {};
  refreshBallots();
}

function picksFor(date) {
  if (!PICKS[date]) PICKS[date] = {};
  return PICKS[date];
}

function setPick(date, key, value) {
  const p = picksFor(date);
  if (value == null) delete p[key]; else p[key] = value;
  writeKept(KEY_PICKS, PICKS);
}

const GEO_URL = "assets/districts.geo.json";
const STREETS_URL = "assets/streets.json";
const CENSUS_LOCATIONS =
  "https://geocoding.geo.census.gov/geocoder/locations/onelineaddress";

let STREETS = null;    // { "Maryland Heights": [["Adie Rd", 2400, 11999], …] }
let STREET_INDEX = []; // flattened, searchable: { city, name, lo, hi, key }

// The geocoder has no fuzzy matching: a wrong suffix or a house number that
// doesn't exist returns nothing at all, with no suggestion. Completing against
// the real street list removes that failure rather than handling it — the
// visitor never types the fragile part. Picking a street also settles which
// city they are in, so no city has to be chosen first.
async function loadStreets() {
  if (STREETS) return STREETS;
  const res = await withTimeout(fetch(STREETS_URL), FETCH_TIMEOUT_MS);
  if (!res.ok) throw new Error(`street list unavailable (${res.status})`);
  STREETS = await res.json();
  STREET_INDEX = [];
  for (const [city, list] of Object.entries(STREETS)) {
    for (const [name, lo, hi] of list) {
      STREET_INDEX.push({ city, name, lo, hi, key: normalizeStreet(name) });
    }
  }
  return STREETS;
}

// Fold the things people vary: case, punctuation, and the handful of suffix
// abbreviations that account for most mistyped addresses.
const SUFFIXES = {
  street: "st", avenue: "ave", road: "rd", drive: "dr", lane: "ln",
  court: "ct", circle: "cir", boulevard: "blvd", place: "pl", terrace: "ter",
  parkway: "pkwy", trail: "trl", way: "way", square: "sq", highway: "hwy",
  north: "n", south: "s", east: "e", west: "w",
};

function normalizeStreet(s) {
  return String(s).toLowerCase().replace(/[.,'']/g, "").split(/\s+/)
    .map((w) => SUFFIXES[w] || w).filter(Boolean).join(" ");
}

// Rank by where the query lands: the start of the name first, then the start
// of any later word, and only then mid-word. Without the word-boundary rule,
// typing "main" offers "Romaine Ave", which is a substring match and a useless
// suggestion. Mid-word hits are kept, but only when nothing better exists.
function searchStreets(query, limit = 8) {
  const q = normalizeStreet(query);
  if (q.length < 2) return [];
  const strong = [], weak = [];
  for (const s of STREET_INDEX) {
    const at = s.key.indexOf(q);
    if (at < 0) continue;
    const wordStart = at === 0 || s.key[at - 1] === " ";
    const entry = { ...s, rank: at * 10 + s.name.length };
    (wordStart ? strong : weak).push(entry);
  }
  const pick = strong.length ? strong : weak;
  pick.sort((a, b) => a.rank - b.rank || a.name.localeCompare(b.name));
  return pick.slice(0, limit);
}

// Which scope levels an address can settle. A level absent here is never
// filtered, so a scope we cannot resolve (County Council) keeps showing.
const RESOLVABLE = ["us_house", "school", "county"];

async function loadGeo() {
  if (GEO) return GEO;
  const res = await withTimeout(fetch(GEO_URL), FETCH_TIMEOUT_MS);
  if (!res.ok) throw new Error(`boundaries unavailable (${res.status})`);
  GEO = await res.json();
  return GEO;
}

// Ray casting, counting crossings of every ring. An odd count is inside; holes
// work automatically because crossing into a hole flips the count back out.
function inRing(lon, lat, ring) {
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i], [xj, yj] = ring[j];
    if ((yi > lat) !== (yj > lat) &&
        lon < ((xj - xi) * (lat - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

function inGeometry(lon, lat, geom) {
  const polys = geom.type === "MultiPolygon" ? geom.coordinates : [geom.coordinates];
  for (const poly of polys) {
    let hit = false;
    for (const ring of poly) if (inRing(lon, lat, ring)) hit = !hit;
    if (hit) return true;
  }
  return false;
}

// Resolve a point to one district per resolvable level. A level can legitimately
// come back null — someone in Pattonville is in no school district we carry,
// and must NOT be shown Parkway's measure.
function districtsAt(lon, lat) {
  const found = {};
  for (const level of RESOLVABLE) found[level] = null;
  for (const d of (GEO && GEO.districts) || []) {
    if (!RESOLVABLE.includes(d.kind)) continue;
    if (!inGeometry(lon, lat, d.geometry)) continue;
    found[d.kind] = { slug: d.slug, name: d.name };
  }
  return found;
}

// JSONP, not fetch. The Census geocoder sends no Access-Control-Allow-Origin
// header, so a cross-origin fetch from this site is blocked by the browser —
// which is what "the address lookup is unavailable" was reporting. It does
// support JSONP, and a <script> tag is not subject to CORS.
//
// JSONP means running whatever that host returns, so this is narrower than it
// looks: one fixed https://geocoding.geo.census.gov URL, a one-shot callback
// removed as soon as it fires or times out, and the response shape checked
// before anything is read out of it. The caller then confirms the coordinates
// land inside the city the street list already named, so a wrong or hostile
// answer cannot quietly move someone to a different ballot.
//
// The alternative is proxying through a server of ours, which would mean
// visitor addresses touching our infrastructure — a worse trade for this site
// than a script tag pointed at one government host.
function geocode(address) {
  return new Promise((resolve, reject) => {
    const cb = `civicGeo${Date.now()}${Math.floor(Math.random() * 1e6)}`;
    const script = document.createElement("script");
    let done = false;

    const cleanup = () => {
      delete window[cb];
      script.remove();
      clearTimeout(timer);
    };
    const timer = setTimeout(() => {
      if (done) return;
      done = true; cleanup();
      reject(new Error("timed out"));
    }, FETCH_TIMEOUT_MS);

    window[cb] = (json) => {
      if (done) return;
      done = true; cleanup();
      const match = (((json || {}).result || {}).addressMatches || [])[0];
      const c = match && match.coordinates;
      if (!match || typeof c.x !== "number" || typeof c.y !== "number") {
        reject(new Error("no match"));
        return;
      }
      resolve({ lon: c.x, lat: c.y, label: String(match.matchedAddress || address) });
    };

    script.onerror = () => {
      if (done) return;
      done = true; cleanup();
      reject(new Error("unreachable"));
    };
    script.src = `${CENSUS_LOCATIONS}?address=${encodeURIComponent(address)}` +
                 `&benchmark=Public_AR_Current&format=jsonp&callback=${cb}`;
    document.head.appendChild(script);
  });
}

/* ---------- Voting logistics ---------- */

// The guide for the election actually being shown, or null. Never falls back
// to "some other election's dates" — wrong dates are worse than no dates.
function votingGuide(place) {
  if (!place.ballot) return null;
  const state = VOTING_GUIDE[place.state];
  const election = state && state.elections[place.ballot.date];
  return election ? { ...state, ...election } : null;
}

// The next deadline that hasn't passed, with how far off it is.
function nextDeadline(guide) {
  for (const d of guide.dates) {
    const days = daysUntil(d.on);
    if (days !== null && days >= 0) return { ...d, days };
  }
  return null;
}

// A deadline close enough to act on gets said once, loudly, above the ballot.
// Below three weeks out, "register by October 7" stops being trivia.
function deadlineBanner(place) {
  const guide = votingGuide(place);
  if (!guide) return "";
  const next = nextDeadline(guide);
  if (!next || next.days > 21) return "";
  return `<div class="deadline-banner">
      <span class="deadline-when">${esc(countdown(next.days))}</span>
      <span class="deadline-what"><strong>${esc(next.label)}</strong> — ${esc(formatShortDate(next.on).replace(/, \d{4}$/, ""))}</span>
      <a class="deadline-link" href="#how-to-vote">All dates</a>
    </div>`;
}

// Passed deadlines stay on the page, marked as passed. Hiding them would let
// somebody assume they still have time.
function renderVotingInfo(place) {
  const guide = votingGuide(place);
  if (!guide) return "";
  const next = nextDeadline(guide);

  const rows = guide.dates.map((d) => {
    const days = daysUntil(d.on);
    const started = days !== null && days < 0;
    // A window that has opened and not yet closed is the opposite of passed.
    // (Compared explicitly: null >= 0 is true in JavaScript.)
    const left = d.until ? daysUntil(d.until) : null;
    const open = started && left !== null && left >= 0;
    const passed = started && !open;
    const isNext = next && next.on === d.on;
    const status = open ? "Open now"
      : passed ? (d.until ? "Closed" : "Passed")
      : days === null ? "" : countdown(days);
    return `<li class="vote-date${passed ? " passed" : ""}${open ? " open" : ""}${isNext ? " next" : ""}">
        <span class="vote-date-day">${esc(formatShortDate(d.on))}</span>
        <span class="vote-date-body">
          <strong>${esc(d.label)}</strong>
          <span class="vote-date-detail">${esc(d.detail)}</span>
        </span>
        ${status ? `<span class="vote-date-status">${esc(status)}</span>` : ""}
      </li>`;
  }).join("");

  const authority = safeUrl(guide.authorityUrl);
  const calendar = safeUrl(guide.calendarUrl);
  const state = safeUrl(guide.stateUrl);

  return `
    <section class="vote-panel" id="how-to-vote" aria-label="How to vote">
      <div class="part-break">
        <span class="part-eyebrow">Voter information</span>
        <h3>How and when to vote</h3>
        <p>Dates set by Missouri law for the ${esc(formatShortDate(place.ballot.date))}
           election. Confirm anything time-sensitive with your election authority —
           we are a volunteer project, not an election office.</p>
      </div>
      <ol class="vote-dates">${rows}</ol>
      ${(guide.lookups || []).length ? `<div class="vote-lookups">
        <span class="vote-lookups-from">From the ${esc(guide.authority)}:</span>
        ${guide.lookups.map((l) => {
          const u = safeUrl(l.url);
          return u ? `<a href="${esc(u)}" target="_blank" rel="noopener">${esc(l.label)}</a>` : "";
        }).join("")}
      </div>` : ""}
      <p class="vote-id">${esc(guide.idNote)}</p>
      <div class="vote-links">
        ${authority ? `<a href="${esc(authority)}" target="_blank" rel="noopener">${esc(guide.authority)}</a>` : ""}
        ${state ? `<a href="${esc(state)}" target="_blank" rel="noopener">Register &amp; check your registration</a>` : ""}
        ${calendar ? `<a href="${esc(calendar)}" target="_blank" rel="noopener">Official election calendar</a>` : ""}
      </div>
    </section>`;
}

function renderWhoRepresentsYou(place) {
  const officials = renderOfficialsSection(place);
  const districts = renderDistrictOfficials(place);
  if (!officials && !districts) return "";

  const lead = place.ballot
    ? `The people below currently hold office. They are <strong>not</strong> ballot
       choices — anyone up for election on ${esc(formatShortDate(place.ballot.date))}
       appears in the ballot above and is marked here.`
    : `The people below currently hold office in and around ${esc(place.name)}.`;

  return `
    <div class="part-break">
      <span class="part-eyebrow">Not ballot content</span>
      <h3>Who represents you now</h3>
      <p>${lead}</p>
    </div>
    ${officials}${districts}`;
}

function renderOfficialsSection(place) {
  if (!place.officials.length) return "";
  const featured = place.officials.filter((o) => String(o.office || "").toLowerCase().startsWith("mayor"));
  const rest = place.officials.filter((o) => !featured.includes(o));
  const card = (o, opts = {}) =>
    personCard(o, personHref(place, o), { ...opts, flag: ballotFlag(place, o) });
  return `
    <div class="section-title">Your city officials</div>
    <div class="people-grid">
      ${featured.map((o) => card(o, { featured: true })).join("")}
      ${rest.map((o) => card(o)).join("")}
    </div>`;
}

// An officeholder who is also a candidate this cycle shows up in both parts of
// the page; say so rather than letting it read as a duplicate.
function ballotFlag(place, person) {
  const entry = place.people.get(person.slug);
  return entry && entry.role === "candidate" ? "On this ballot — see above" : null;
}

function renderDistrictOfficials(place) {
  const all = [...place.districts, ...(STATEWIDE[place.state] || [])];
  if (!all.length) return "";

  let html = `<div class="section-title">Your state &amp; federal representatives</div>`;
  let daggerShown = false;

  for (const [level, label] of Object.entries(LEVEL_LABELS)) {
    const ds = all.filter((d) => d.level === level);
    if (!ds.length) continue;
    let cards = "";
    for (const d of ds) {
      for (const o of d.officials) {
        if (d.partial) daggerShown = true;
        cards += personCard(o, personHref(place, o), {
          note: (o.office || d.name) + (d.partial ? " †" : ""),
          flag: ballotFlag(place, o),
        });
      }
    }
    if (cards) {
      html += `<div class="district-group"><h4 class="district-level">${esc(label)}</h4>
        <div class="people-grid">${cards}</div></div>`;
    }
  }
  if (daggerShown) {
    html += `<p class="district-note">† This district covers only part of the city, so your
      representative depends on your exact address. ${LOOKUP_LINKS}</p>`;
  }
  return html;
}

/* ---------- View: person page ---------- */

const SUGGEST_URL = "https://github.com/ndg13b/CivicGateway/issues";

/* ---------- Candidate information: same slots for everyone ----------

   Incumbents arrive with a biography and an official page because that is
   what house.mo.gov and house.gov publish; challengers have no equivalent
   source. Left as free-form prose, that reads as a difference between the
   candidates rather than a difference in our research — in every contested
   race the officeholder got a paragraph and the challenger got a party label.

   So every candidate gets the same labelled slots and the empty ones are
   shown, not hidden. Absence then reads as "we don't have this yet", which is
   true, instead of "there is nothing to say about this person", which isn't.
   The incumbent's advantage narrows to holding the office, which is a fact
   worth stating rather than an edge we handed them.                        */
function slot(label, filled, emptyText) {
  return `<div class="slot">
      <div class="slot-label">${esc(label)}</div>
      <div class="slot-body${filled ? "" : " is-empty"}">${
        filled || `${esc(emptyText)} <a href="${SUGGEST_URL}" target="_blank" rel="noopener">Suggest one</a>`
      }</div>
    </div>`;
}

function infoSlots(person, contest) {
  const out = [];

  // Sourced from an official office page, so say so. It explains why only
  // people already in office have one.
  if (person.bio) {
    out.push(`<div class="slot">
        <div class="slot-label">Currently holds this office</div>
        <div class="slot-body"><p>${esc(person.bio)}</p>
          <span class="slot-src">From their official office page</span></div>
      </div>`);
  }

  const isCandidate = person.role === "candidate";
  out.push(slot(
    isCandidate ? "Campaign website & contact" : "Contact & official links",
    contactLinks(person),
    isCandidate
      ? "We don't have a campaign site or contact for this candidate yet."
      : "We don't have contact details for this office yet."));

  if (isCandidate) {
    out.push(slot("Voter guide response", null,
                  "No voter guide questionnaire on file for this candidate."));
  }
  return `<div class="slots">${out.join("")}</div>`;
}

// The site is one volunteer's research, and what is missing is missing for
// that reason rather than because it doesn't exist. Saying so plainly is more
// honest than quietly levelling everyone down to the least-documented.
function coverageNote() {
  return `<p class="coverage-note">Some candidates have more material online than others,
    and this page shows what the volunteer running Civic Gateway has found so far — not
    everything that exists. A blank section is a gap in our research, not a judgement about
    the candidate. <a href="${SUGGEST_URL}" target="_blank" rel="noopener">Suggest something
    we've missed</a> and we'll add it.</p>`;
}

// Everyone else on the ballot for this seat. A voter comparing candidates
// should not have to go back to the ballot and find the contest again.
function opponentsPanel(place, person, contest) {
  if (!contest || !contest.candidates) return "";
  const others = contest.candidates.filter((c) => c.name !== person.name);
  if (!others.length) {
    return `<div class="aside-sec"><h3>Others in this race</h3>
      <p class="nothing">No other candidate filed for this seat.</p></div>`;
  }
  return `<div class="aside-sec">
      <h3>Others in this race</h3>
      <div class="opp-list">${others.map((c) => `
        <a class="opp" href="${esc(personHref(place, c))}">
          <span class="opp-av" aria-hidden="true">${esc(initials(c.name))}</span>
          <span class="opp-body">
            <span class="opp-name">${esc(c.name)}${
              c.incumbent ? '<span class="chip-inc">Incumbent</span>' : ""}</span>
            ${c.party ? `<span class="opp-party">${esc(c.party)}</span>` : ""}
          </span>
        </a>`).join("")}</div>
      <a class="opp-all" href="#/city/${esc(place.key)}/contest/${esc(contest.id)}">See the whole contest →</a>
    </div>`;
}

function renderPerson(place, person) {
  setChrome({ picker: false, selected: place });

  const isCandidate = person.role === "candidate";
  const metaBits = [person.party, person.term,
    isCandidate && place.ballot ? `On the ballot ${formatShortDate(place.ballot.date)}` : null]
    .filter(Boolean);

  const contest = person.contestId ? place.contests.get(person.contestId) : null;
  // Contest-level resources (debates covering the whole race) plus this
  // person's own (interviews). Shared resources appear in both places.
  const contestResources = contest ? contest.resources : [];
  const ownResources = person.resources || [];

  const debates = [...contestResources.filter((r) => r.kind === "debate"),
                   ...ownResources.filter((r) => r.kind === "debate")];
  const interviews = ownResources.filter((r) => r.kind === "interview");
  const info = [...contestResources.filter((r) => r.kind === "info"),
                ...ownResources.filter((r) => r.kind === "info")];

  const alsoOnBallot = place.ballot
    ? [...place.contests.values()].filter((c) => c.id !== person.contestId).slice(0, 4)
    : [];

  const html = `
    <a class="backlink" href="#/city/${esc(place.key)}">‹ Back to ${esc(place.name)}</a>
    <article class="detail-sheet">
    <div class="person-hero">
      <div class="hero-av" aria-hidden="true">${esc(initials(person.name))}</div>
      <div>
        <h1>${esc(person.name)}</h1>
        <div class="seeking">${isCandidate
          ? `Candidate for <strong>${esc(person.contestTitle || "")}</strong>`
          : esc(person.office || person.contextLabel || "")}</div>
        ${metaBits.length ? `<div class="hero-meta">${metaBits.map(esc).join(" · ")}</div>` : ""}
      </div>
    </div>

    <div class="detail-cols">
      <div class="detail-main">
        ${infoSlots(person, contest)}
        ${resourceSection("Debates & candidate forums", debates, { contest, excludeName: person.name })}
        ${resourceSection("Interviews & coverage", interviews)}
        ${resourceSection("More information", info, { contest, excludeName: person.name })}
        ${coverageNote()}
      </div>
      <aside class="detail-aside" aria-label="More from this ballot">
        ${opponentsPanel(place, person, contest)}
        ${alsoOnBallot.length ? `<div class="aside-sec"><h3>Also on your ballot</h3>
          <div class="also">${alsoOnBallot.map((c) => `
            <a href="#/city/${esc(place.key)}/${c.kind === "measure" ? "measure" : "contest"}/${esc(c.id)}">
              ${esc(c.title)}<small>${c.kind === "measure" ? "Ballot measure"
                : `${c.candidates.length} candidate${c.candidates.length === 1 ? "" : "s"}`}</small></a>`).join("")}
          </div></div>` : ""}
      </aside>
    </div>

    <p class="neutrality">Civic Gateway does not endorse candidates. Links are provided so you can
    hear candidates in their own words and from independent coverage; inclusion is not an
    endorsement, and we aim to list the same categories of information for every candidate in a race.</p>
    </article>`;

  paint(html);
  document.title = `${person.name} — Civic Gateway`;
}

/* ---------- View: contest page ---------- */

function renderContestPage(place, contest) {
  setChrome({ picker: false, selected: place });

  const html = `
    <a class="backlink" href="#/city/${esc(place.key)}">‹ Back to ${esc(place.name)}</a>
    <article class="detail-sheet">
    <div class="page-head">
      <h1>${esc(contest.title)}</h1>
      <div class="hero-meta">${esc(contest.scopeLabel)} ·
        ${contest.voteFor > 1 ? `Vote for up to ${contest.voteFor}` : "Vote for one"}${
        place.ballot ? ` · ${esc(formatShortDate(place.ballot.date))}` : ""}</div>
    </div>
    ${contest.description ? `<div class="page-sec"><p>${esc(contest.description)}</p></div>` : ""}
    ${contest.partial ? `<div class="varies"><strong>Depends on your address.</strong>
      This district covers only part of ${esc(place.name)}. ${LOOKUP_LINKS}</div>` : ""}

    <div class="page-sec"><h3>Candidates</h3>
      ${contest.candidates.length
        ? `<div class="people-grid">${contest.candidates.map((c) =>
            personCard(c, personHref(place, c), { note: c.party })).join("")}</div>`
        : `<p class="nothing">Candidates aren't certified yet.</p>`}
    </div>

    ${resourceBlock("Debates & candidate forums",
      contest.resources.filter((r) => r.kind === "debate"),
      "We don't know of a recorded debate or candidate forum for this race yet.")}
    ${resourceBlock("Impartial information",
      contest.resources.filter((r) => r.kind === "info"),
      "We haven't found a nonpartisan guide or news coverage of this race yet.")}

    ${contest.candidates.length > 1 ? `<div class="page-sec"><h3>Compare the candidates in their own words</h3>
      <p>The League of Women Voters' <a href="${VOTE411_URL}" target="_blank" rel="noopener">VOTE411</a>
      guide sends every candidate in a race the same questions and publishes the answers they
      send back. Enter your address there to see the races on your ballot.</p></div>` : ""}

    ${resourceStandards()}
    </article>`;

  paint(html);
  document.title = `${contest.title} — Civic Gateway`;
}

/* ---------- View: measure page ---------- */

function renderMeasurePage(place, measure) {
  setChrome({ picker: false, selected: place });

  const html = `
    <a class="backlink" href="#/city/${esc(place.key)}">‹ Back to ${esc(place.name)}</a>
    <article class="detail-sheet measure-sheet">
    <div class="page-head">
      <h1>${esc(measure.title)}</h1>
      <div class="hero-meta">${esc(measure.scopeLabel)} · Ballot measure${
        place.ballot ? ` · ${esc(formatShortDate(place.ballot.date))}` : ""}</div>
    </div>
    ${measure.officialText
      ? `<div class="page-sec"><h3>Official ballot language</h3>
         <div class="official-text">${esc(measure.officialText)}</div></div>` : ""}
    ${measure.description ? `<div class="page-sec"><h3>Summary</h3><p>${esc(measure.description)}</p></div>` : ""}
    <div class="page-sec"><h3>How the vote works</h3>
      ${/^Retention\s+[—–-]/.test(measure.title)
        // "Leaving current law unchanged" is the opposite of what NO does here.
        ? `<p>A <strong>YES</strong> vote keeps the judge in office for a new term.
           A <strong>NO</strong> vote is a vote to remove the judge. A judge who gets
           more NO votes than YES votes leaves office, and the seat is filled by a
           new appointment.</p>`
        : `<p>A <strong>YES</strong> vote supports the measure as written above.
           A <strong>NO</strong> vote opposes it, leaving current law unchanged.</p>`}</div>
    ${resourceBlock("Official documents & impartial coverage", measure.resources,
      "We haven't linked any official documents or news coverage for this question yet.")}
    ${resourceStandards()}
    </article>`;

  paint(html);
  document.title = `${measure.title} — Civic Gateway`;
}

/* ---------- View: walk me through my ballot ----------
   One race per screen, in ballot order, ending in a review the visitor can
   print as notes. Three rules shape it:

   1. ONLY RACES THIS VOTER ACTUALLY GETS. Where a city splits across a
      district the address lookup can settle, the walkthrough asks for the
      address first. Where it splits across one the lookup cannot settle
      (state House and Senate lines), the screen asks "which one is on your
      ballot?" and points to the official sample ballot, rather than guessing.

   2. NEUTRAL. Candidates in ballot order, all presented the same way. Every
      race can be skipped; nothing is suggested, preselected or summarised.

   3. CHOICES STAY ON THE DEVICE. See "What this site keeps on your device".
      Steps are addressed by number in the URL; choices never are.          */

let WALK_PENDING = false;   // came to the address picker from the walkthrough

// Same rule as citySplits(), plus: a location resolved in another city does
// not settle this one.
function walkNeedsAddress(place) {
  if (!citySplits(place)) return false;
  if (!LOCATION) return true;
  return Boolean(LOCATION.city) && LOCATION.city !== place.key;
}

function walkSteps(place) {
  const b = place.ballot;
  if (!b || !b.hasContests) return [];
  const steps = [];
  for (const section of b.sections) {
    const singles = section.groups.map((g) => g.single);
    const retentions = singles.filter((c) => c && c.kind === "measure" && c.scopeLevel === "judicial");
    if (retentions.length && retentions.length === section.groups.length) {
      // Nineteen near-identical yes/no questions are one screen, not nineteen.
      steps.push({ type: "retention", key: "retention", section: section.label, contests: retentions });
      continue;
    }
    for (const g of section.groups) {
      if (g.variants) {
        steps.push({
          type: "variants", key: `where::${g.variants[0].scopeLevel}::${g.office}`,
          section: section.label, office: g.office, variants: g.variants,
        });
        continue;
      }
      const c = g.single;
      // Partial and not settled by the address: ask before assuming.
      const unsure = c.partial && !(LOCATION && RESOLVABLE.includes(c.scopeLevel));
      steps.push({
        type: c.kind === "measure" ? "measure" : "office", key: c.id,
        section: section.label, contest: c, askIfOnBallot: unsure,
      });
    }
  }
  return steps;
}

function walkHref(place, step) {
  return `#/city/${place.key}/walk${step ? `/${step}` : ""}`;
}

function officialSampleBallotUrl(place) {
  const g = votingGuide(place);
  const hit = g && (g.lookups || []).find((l) => /sample ballot/i.test(l.label));
  return hit ? safeUrl(hit.url) : null;
}

function rememberControl() {
  return `<label class="walk-remember">
      <input type="checkbox" id="walkRemember"${remembering() ? " checked" : ""}>
      <span><strong>Remember my location and choices on this device</strong>
      so they are still here if I leave and come back. Leave this off on a shared
      or public computer.</span>
    </label>`;
}

function walkPrivacyNote() {
  return `<p class="walk-privacy">Your choices stay in this browser. They are never
    sent anywhere — this site has no server to send them to — and nobody, including
    us, can see them. <button type="button" class="linkish" id="walkForget">Forget my
    location and choices</button></p>`;
}

function renderWalk(place, stepParam) {
  const b = place.ballot;
  if (!b || !b.hasContests) return renderCity(place);

  if (walkNeedsAddress(place)) return renderWalkAddress(place);
  setChrome({ picker: false, selected: place });

  const steps = walkSteps(place);
  if (stepParam === "review") return renderWalkReview(place, steps);
  const n = Number(stepParam);
  if (!stepParam || !Number.isInteger(n) || n < 1 || n > steps.length) {
    return renderWalkIntro(place, steps);
  }
  return renderWalkStep(place, steps, n);
}

function renderWalkAddress(place) {
  setChrome({ picker: true, selected: place });
  WALK_PENDING = true;
  paint(`
    <a class="backlink" href="#/city/${esc(place.key)}">‹ Back to the ${esc(place.name)} ballot</a>
    <article class="detail-sheet walk-sheet">
      <div class="walk-kicker">Walk through your ballot</div>
      <h1>First, where you live</h1>
      <p class="walk-lead">Some races on a ${esc(place.name)} ballot depend on your street
        address. To walk you through only the races you will actually see, we need it first.
        It is used to find your districts and is never stored or shared.</p>
      <div class="addr-row">
        <button type="button" id="addrJump">Type my address</button>
        <button type="button" id="addrGeo" class="secondary">Use my location</button>
      </div>
      <div class="addr-msg" id="addrMsg" hidden></div>
    </article>`);
  document.title = `Walk through your ballot — ${place.name} — Civic Gateway`;
}

function renderWalkIntro(place, steps) {
  const b = place.ballot;
  const picks = picksFor(b.date);
  const answered = Object.keys(picks).length > 0;
  paint(`
    <a class="backlink" href="#/city/${esc(place.key)}">‹ Back to the full ballot</a>
    <article class="detail-sheet walk-sheet">
      <div class="walk-kicker">${esc(b.name)} · ${esc(formatDate(b.date))}</div>
      <h1>Walk through your ballot</h1>
      <p class="walk-lead">${steps.length} screens, one race at a time, in the order they
        appear on your ballot${LOCATION ? ` for ${esc(LOCATION.label)}` : ` in ${esc(place.name)}`}.
        Choose, skip, or come back later. At the end you can print your choices as notes
        to take with you.</p>
      <ul class="walk-points">
        <li>Links open in a new tab, so you won't lose your place.</li>
        <li>Every race can be skipped. Nothing is filled in for you.</li>
        <li>Civic Gateway does not endorse candidates or take positions on measures.</li>
      </ul>
      ${rememberControl()}
      <div class="walk-nav">
        <a class="walk-btn primary" href="${walkHref(place, 1)}">${answered ? "Start from the first race" : "Start"} →</a>
        ${answered ? `<a class="walk-btn" href="${walkHref(place, "review")}">Review my choices</a>` : ""}
      </div>
      ${walkPrivacyNote()}
    </article>`);
  bindWalkCommon(place);
  document.title = `Walk through your ballot — ${place.name} — Civic Gateway`;
}

function walkProgress(n, total, section) {
  const pct = Math.round((n / total) * 100);
  return `<div class="walk-progress">
      <div class="walk-progress-text"><span>${esc(section)}</span><span>${n} of ${total}</span></div>
      <div class="walk-bar" role="progressbar" aria-valuemin="1" aria-valuemax="${total}"
           aria-valuenow="${n}" aria-label="Race ${n} of ${total}"><span style="width:${pct}%"></span></div>
    </div>`;
}

// One candidate choice block for an office contest. Values are indexes into
// the candidate list, so a name never has to survive an HTML attribute.
function officeChoices(place, c, date) {
  const pick = picksFor(date)[c.id] || null;
  const multi = c.voteFor > 1;
  const type = multi ? "checkbox" : "radio";
  const chosen = (name) => pick && (pick.name === name || (pick.names || []).includes(name));
  const items = c.candidates.map((cand, i) => `
      <label class="walk-option">
        <input type="${type}" name="pick-${esc(c.id)}" data-contest="${esc(c.id)}" data-i="${i}"${chosen(cand.name) ? " checked" : ""}>
        <span class="walk-option-body">
          <span class="walk-option-name">${esc(cand.name)}${cand.incumbent ? '<span class="chip-inc">Incumbent</span>' : ""}</span>
          ${cand.party ? `<span class="walk-option-meta">${esc(cand.party)}</span>` : ""}
        </span>
        <a class="walk-option-more" href="${esc(personHref(place, cand))}" target="_blank" rel="noopener">About ›</a>
      </label>`).join("");
  const writeIn = pick && pick.writeIn != null ? pick.writeIn : "";
  return `<fieldset class="walk-options" data-contest="${esc(c.id)}" data-votefor="${c.voteFor}">
      <legend>${multi ? `Vote for up to ${c.voteFor}` : "Vote for one"}</legend>
      ${items}
      ${multi ? "" : `<label class="walk-option walk-writein">
        <input type="radio" name="pick-${esc(c.id)}" data-contest="${esc(c.id)}" data-writein="1"${pick && pick.writeIn != null ? " checked" : ""}>
        <span class="walk-option-body"><span class="walk-option-name">Write in a name</span>
        <input type="text" class="walk-writein-text" data-contest="${esc(c.id)}" maxlength="80"
               value="${esc(writeIn)}" aria-label="Write-in name"></span>
      </label>`}
      <button type="button" class="linkish walk-clear" data-contest="${esc(c.id)}">Clear my choice</button>
      <p class="walk-limit" data-contest="${esc(c.id)}" hidden></p>
    </fieldset>`;
}

function yesNoChoices(key, date, label = null) {
  const pick = picksFor(date)[key];
  return `<div class="walk-yn" role="radiogroup"${label ? ` aria-label="${esc(label)}"` : ""}>
      ${["yes", "no"].map((v) => `<label class="walk-yn-opt">
        <input type="radio" name="yn-${esc(key)}" data-yn="${esc(key)}" value="${v}"${pick === v ? " checked" : ""}>
        <span>${v === "yes" ? "Yes" : "No"}</span></label>`).join("")}
      <button type="button" class="linkish walk-clear" data-yn-clear="${esc(key)}">Clear</button>
    </div>`;
}

function raceLinks(place, c) {
  const href = `#/city/${place.key}/${c.kind === "measure" ? "measure" : "contest"}/${c.id}`;
  const res = (c.resources || []).map((r) => resourceCard(r)).join("");
  return `<div class="walk-links">
      ${res ? `<h3>Debates &amp; impartial information</h3>${res}` : ""}
      <a class="walk-racepage" href="${esc(href)}" target="_blank" rel="noopener">Open this race's page in a new tab ↗</a>
    </div>`;
}

function renderWalkStep(place, steps, n) {
  const b = place.ballot;
  const s = steps[n - 1];
  let body = "";

  if (s.type === "office" || s.type === "measure") {
    const c = s.contest;
    const ask = s.askIfOnBallot ? `
      <div class="walk-ask">
        <p><strong>This race is only on some ${esc(place.name)} ballots</strong> — those in
          ${esc(c.scopeLabel)}. Is it on yours?
          ${officialSampleBallotUrl(place) ? `<a href="${esc(officialSampleBallotUrl(place))}" target="_blank" rel="noopener">Check your official sample ballot ↗</a>` : ""}</p>
        <div class="walk-yn">
          ${[["yes", "Yes, it's on my ballot"], ["no", "No"], ["unsure", "Not sure"]].map(([v, l]) => `
            <label class="walk-yn-opt"><input type="radio" name="where-${esc(c.id)}" data-where="${esc(`where::${c.id}`)}" value="${v}"${picksFor(b.date)[`where::${c.id}`] === v ? " checked" : ""}><span>${esc(l)}</span></label>`).join("")}
        </div>
      </div>` : "";
    const showChoices = !s.askIfOnBallot || picksFor(b.date)[`where::${c.id}`] === "yes";
    const choices = s.type === "office" ? officeChoices(place, c, b.date) : `
      <div class="walk-official">${esc(c.officialText || "")}</div>
      <p class="walk-how">A <strong>YES</strong> vote supports the measure as written. A
        <strong>NO</strong> vote opposes it, leaving current law unchanged.</p>
      ${yesNoChoices(c.id, b.date, c.title)}`;
    body = `
      <h1>${esc(c.title)}</h1>
      <p class="walk-meta">${esc(c.scopeLabel)}${s.type === "office" ? ` · ${c.voteFor > 1 ? `Vote for up to ${c.voteFor}` : "Vote for one"}` : " · Vote yes or no"}</p>
      ${c.description ? `<p class="walk-desc">${esc(c.description)}</p>` : ""}
      ${ask}
      <div class="walk-reveal" data-reveal="${esc(`where::${c.id}`)}"${showChoices ? "" : " hidden"}>
        ${choices}
      </div>
      ${raceLinks(place, c)}`;
  } else if (s.type === "variants") {
    const chosen = picksFor(b.date)[s.key] || null;
    body = `
      <h1>${esc(s.office)}</h1>
      <div class="walk-ask">
        <p><strong>Your ballot has one of these races, depending on where you live.</strong>
          Which district are you in?
          ${officialSampleBallotUrl(place) ? `<a href="${esc(officialSampleBallotUrl(place))}" target="_blank" rel="noopener">Check your official sample ballot ↗</a>` : ""}</p>
        <div class="walk-yn">
          ${s.variants.map((v) => `<label class="walk-yn-opt"><input type="radio" name="where-${esc(s.key)}" data-where="${esc(s.key)}" value="${esc(v.id)}"${chosen === v.id ? " checked" : ""}><span>${esc(v.scopeShort || v.scopeLabel)}</span></label>`).join("")}
          <label class="walk-yn-opt"><input type="radio" name="where-${esc(s.key)}" data-where="${esc(s.key)}" value="unsure"${chosen === "unsure" ? " checked" : ""}><span>Not sure</span></label>
        </div>
      </div>
      ${s.variants.map((v) => `
        <div class="walk-reveal" data-reveal="${esc(s.key)}" data-for="${esc(v.id)}"${chosen === v.id ? "" : " hidden"}>
          <p class="walk-meta">${esc(v.title)} · ${esc(v.scopeLabel)}</p>
          ${v.description ? `<p class="walk-desc">${esc(v.description)}</p>` : ""}
          ${officeChoices(place, v, b.date)}
          ${raceLinks(place, v)}
        </div>`).join("")}`;
  } else if (s.type === "retention") {
    const byCourt = new Map();
    for (const c of s.contests) {
      if (!byCourt.has(c.scopeLabel)) byCourt.set(c.scopeLabel, []);
      byCourt.get(c.scopeLabel).push(c);
    }
    const jpr = s.contests.flatMap((c) => c.resources || []).find((r) => /yourmissourijudges/.test(r.url || ""));
    body = `
      <h1>Judges: keep or remove</h1>
      <p class="walk-desc">These judges are not running against anyone. For each one, a
        <strong>YES</strong> vote keeps the judge in office for a new term and a
        <strong>NO</strong> vote is a vote to remove the judge. You can leave any of them blank.</p>
      ${jpr ? `<div class="walk-links">${resourceCard(jpr)}</div>` : ""}
      ${[...byCourt].map(([court, list]) => `
        <h3 class="walk-court">${esc(court)}</h3>
        <ul class="walk-judges">
          ${list.map((c) => `<li class="walk-judge">
            <a class="walk-judge-name" href="${esc(`#/city/${place.key}/measure/${c.id}`)}" target="_blank" rel="noopener">${esc(String(c.title).replace(/^Retention\s+[—–-]\s+/, ""))}</a>
            ${yesNoChoices(c.id, b.date, c.title)}
          </li>`).join("")}
        </ul>`).join("")}`;
  }

  const prev = n > 1 ? walkHref(place, n - 1) : walkHref(place);
  const next = n < steps.length ? walkHref(place, n + 1) : walkHref(place, "review");
  paint(`
    <a class="backlink" href="#/city/${esc(place.key)}">‹ Leave the walkthrough</a>
    <article class="detail-sheet walk-sheet">
      ${walkProgress(n, steps.length, s.section)}
      ${body}
      <div class="walk-nav">
        <a class="walk-btn" href="${prev}">← Back</a>
        <a class="walk-btn primary" href="${next}">${n < steps.length ? "Next →" : "Review my choices →"}</a>
      </div>
    </article>`);
  bindWalkCommon(place);
  bindWalkChoices(place);
  document.title = `${n} of ${steps.length} — Walk through your ballot — Civic Gateway`;
}

// What the visitor chose for one step, as plain lines for the review and the
// printed notes. Nothing chosen is said plainly, never filled in.
function walkSummary(place, s) {
  const p = picksFor(place.ballot.date);
  const office = (c) => {
    const v = p[c.id];
    if (!v) return "No choice";
    if (v.writeIn != null) return v.writeIn ? `Write-in: ${v.writeIn}` : "Write-in (no name entered)";
    const names = v.names || [v.name];
    return names.map((nm) => {
      const cand = c.candidates.find((x) => x.name === nm);
      return cand && cand.party ? `${nm} (${cand.party})` : nm;
    }).join(", ");
  };
  const yn = (k) => (p[k] === "yes" ? "Yes" : p[k] === "no" ? "No" : "No choice");

  if (s.type === "office" || s.type === "measure") {
    const c = s.contest;
    const lines = [];
    if (s.askIfOnBallot) {
      const w = p[`where::${c.id}`];
      if (w === "no") return [{ label: c.title, value: "Not on my ballot" }];
      if (w !== "yes") return [{ label: c.title, value: "Not sure if this is on my ballot" }];
    }
    lines.push({ label: c.title, value: s.type === "office" ? office(c) : yn(c.id) });
    return lines;
  }
  if (s.type === "variants") {
    const w = p[s.key];
    const v = s.variants.find((x) => x.id === w);
    if (!v) return [{ label: s.office, value: "Not sure which district — check your sample ballot" }];
    return [{ label: v.title, value: office(v) }];
  }
  if (s.type === "retention") {
    return s.contests.map((c) => ({
      label: `Keep Judge ${String(c.title).replace(/^Retention\s+[—–-]\s+/, "")}?`, value: yn(c.id),
    }));
  }
  return [];
}

function renderWalkReview(place, steps) {
  const b = place.ballot;
  const guide = votingGuide(place);
  const next = guide && nextDeadline(guide);
  const lookups = (guide && guide.lookups) || [];
  let section = null;
  const rows = steps.map((s, i) => {
    const head = s.section !== section ? `<h3 class="walk-review-section">${esc(s.section)}</h3>` : "";
    section = s.section;
    return head + `<div class="walk-review-step">
        <div class="walk-review-rows">
          ${walkSummary(place, s).map((l) => `<div class="walk-review-row">
            <span class="walk-review-race">${esc(l.label)}</span>
            <span class="walk-review-pick${/^No choice|^Not sure/.test(l.value) ? " none" : ""}">${esc(l.value)}</span>
          </div>`).join("")}
        </div>
        <a class="walk-change" href="${walkHref(place, i + 1)}">Change</a>
      </div>`;
  }).join("");

  paint(`
    <a class="backlink" href="#/city/${esc(place.key)}">‹ Back to the full ballot</a>
    <article class="detail-sheet walk-sheet walk-review">
      <div class="walk-print-head">
        <strong>My ballot notes — not a ballot</strong>
        <span>Personal notes made at civicgateway.org. Vote on the official ballot at your polling place.</span>
      </div>
      <div class="walk-kicker">${esc(b.name)} · ${esc(formatDate(b.date))}</div>
      <h1>Your choices</h1>
      <p class="walk-lead">${esc(place.name)}${LOCATION ? ` · ${esc(LOCATION.label)}` : ""}.
        Check them over, change anything, then print them if you'd like notes to take with you.</p>
      <div class="walk-review-list">${rows}</div>
      <div class="walk-print-foot">
        ${next ? `<p><strong>Next:</strong> ${esc(next.label)} — ${esc(formatShortDate(next.on))}.</p>` : ""}
        <p>Missouri lets voters bring their own notes like these to the polls. Keep them to
          yourself: showing someone how you voted is not allowed. Bring a photo ID.</p>
        ${lookups.length ? `<p>Find your polling place, early voting sites and official sample
          ballot through the ${esc(guide.authority)}.</p>` : ""}
      </div>
      <div class="walk-nav">
        <button type="button" class="walk-btn primary" id="walkPrint">Print my notes</button>
        <a class="walk-btn" href="${walkHref(place, steps.length)}">← Back to the last race</a>
        <button type="button" class="walk-btn" id="walkStartOver">Clear my choices</button>
      </div>
      ${lookups.length ? `<div class="vote-lookups walk-no-print">
        <span class="vote-lookups-from">From the ${esc(guide.authority)}:</span>
        ${lookups.map((l) => { const u = safeUrl(l.url); return u ? `<a href="${esc(u)}" target="_blank" rel="noopener">${esc(l.label)}</a>` : ""; }).join("")}
      </div>` : ""}
      ${rememberControl()}
      ${walkPrivacyNote()}
    </article>`);
  bindWalkCommon(place);
  on("walkPrint", "click", () => window.print());
  on("walkStartOver", "click", () => {
    if (!window.confirm("Clear every choice you've made for this election?")) return;
    PICKS[b.date] = {};
    writeKept(KEY_PICKS, PICKS);
    route();
  });
  document.title = `Your ballot notes — ${place.name} — Civic Gateway`;
}

function bindWalkCommon(place) {
  on("walkRemember", "change", (e) => setRemember(e.target.checked));
  on("walkForget", "click", () => {
    if (!window.confirm("Forget your location and every choice you've made, on this device?")) return;
    forgetEverything();
    location.hash = `#/city/${place.key}`;
  });
}

function bindWalkChoices(place) {
  const date = place.ballot.date;
  const root = $("results");
  const contestById = new Map();
  for (const c of place.contests.values()) contestById.set(c.id, c);

  // Candidates (radio or checkbox).
  root.querySelectorAll("input[data-contest][data-i], input[data-writein]").forEach((input) => {
    input.addEventListener("change", () => {
      const id = input.dataset.contest;
      const c = contestById.get(id);
      if (!c) return;
      if (input.dataset.writein) {
        const text = root.querySelector(`.walk-writein-text[data-contest="${CSS.escape(id)}"]`);
        setPick(date, id, { writeIn: (text && text.value.trim()) || "" });
        if (text) text.focus();
        return;
      }
      if (c.voteFor > 1) {
        const boxes = [...root.querySelectorAll(`input[data-contest="${CSS.escape(id)}"][data-i]`)];
        const on = boxes.filter((x) => x.checked);
        const limit = root.querySelector(`.walk-limit[data-contest="${CSS.escape(id)}"]`);
        if (on.length > c.voteFor) {
          input.checked = false;
          if (limit) { limit.hidden = false; limit.textContent = `You can choose up to ${c.voteFor}.`; }
          return;
        }
        if (limit) limit.hidden = true;
        const names = on.map((x) => c.candidates[Number(x.dataset.i)].name);
        setPick(date, id, names.length ? { names } : null);
      } else {
        setPick(date, id, { name: c.candidates[Number(input.dataset.i)].name });
      }
    });
  });
  // Typing a write-in selects the write-in option.
  root.querySelectorAll(".walk-writein-text").forEach((text) => {
    text.addEventListener("input", () => {
      const id = text.dataset.contest;
      const radio = root.querySelector(`input[data-writein][data-contest="${CSS.escape(id)}"]`);
      if (radio) radio.checked = true;
      setPick(date, id, { writeIn: text.value.trim() });
    });
  });
  // Yes / no.
  root.querySelectorAll("input[data-yn]").forEach((input) => {
    input.addEventListener("change", () => setPick(date, input.dataset.yn, input.value));
  });
  // "Which one is on your ballot?" — show the matching race, hide the rest.
  root.querySelectorAll("input[data-where]").forEach((input) => {
    input.addEventListener("change", () => {
      const key = input.dataset.where;
      setPick(date, key, input.value);
      root.querySelectorAll(`[data-reveal="${CSS.escape(key)}"]`).forEach((el) => {
        el.hidden = el.dataset.for ? el.dataset.for !== input.value : input.value !== "yes";
      });
    });
  });
  // Clear buttons.
  root.querySelectorAll("button.walk-clear").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = btn.dataset.contest || btn.dataset.ynClear;
      setPick(date, id, null);
      const sel = btn.dataset.contest
        ? `input[data-contest="${CSS.escape(id)}"]`
        : `input[data-yn="${CSS.escape(id)}"]`;
      root.querySelectorAll(sel).forEach((x) => { if (x.type !== "text") x.checked = false; });
    });
  });
}

/* ---------- Chrome + painting ---------- */

// picker: true   — the full picker (home, "first, your address")
//         "fold" — a city is showing: the picker is folded away until the
//                  visitor asks to change city or address. On a phone it was
//                  over 400px of controls between the visitor and their ballot.
//         false  — detail pages
let PICKER_OPEN = false;

function setChrome({ picker, selected }) {
  const open = picker === true || (picker === "fold" && PICKER_OPEN);
  if ($("intro")) $("intro").hidden = !(picker === true && !selected);
  if ($("pickerCard")) $("pickerCard").hidden = !open;
  if (selected) {
    if ($("state").value !== selected.state) {
      $("state").value = selected.state;
      populateCities(selected.state, selected.key);
    } else if ($("city").value !== selected.key) {
      populateCities(selected.state, selected.key);
    }
  }
}

function paint(html) {
  const r = $("results");
  r.innerHTML = html;
  r.classList.add("active");
  bindAddressTool();
  window.scrollTo({ top: 0, behavior: "instant" });
}

function paintNotFound(message) {
  setChrome({ picker: true, selected: null });
  paint(`<div class="notice"><strong>${esc(message)}</strong>
    <br><a href="#/">Start over</a></div>`);
}

/* ---------- Router ----------
   Routes (everything after the "#" — the server only ever serves index.html):
     #/                                  the picker
     #/city/<city>                       ballot + officials
     #/city/<city>/person/<slug>         candidate or officeholder page
     #/city/<city>/contest/<id>          one contest, with its debates
     #/city/<city>/measure/<id>          one ballot measure
     #/city/<city>/walk[/<n>|/review]    walk through the ballot one race at a time
------------------------------------------------------------------- */

function navigate(path, { replace = false } = {}) {
  const url = `#${path}`;
  if (replace) history.replaceState(null, "", url);
  else history.pushState(null, "", url);
  route();
}

function parseHash() {
  const raw = window.location.hash.replace(/^#/, "");
  if (!raw || raw === "/") return { name: "home" };

  // Legacy links from the first version looked like "#maryland-heights-mo".
  if (!raw.startsWith("/")) return { name: "city", city: raw };

  const parts = raw.split("/").filter(Boolean);
  if (parts[0] !== "city" || !parts[1]) return { name: "home" };
  const city = parts[1];
  if (parts.length === 2) return { name: "city", city };
  const [, , kind, id] = parts;
  if (kind === "walk") return { name: "walk", city, id: id ? decodeURIComponent(id) : null };
  if (["person", "contest", "measure"].includes(kind) && id) {
    return { name: kind, city, id: decodeURIComponent(id) };
  }
  return { name: "city", city };
}

function route() {
  document.title = "Civic Gateway — Find Your Elections & Elected Officials";
  const r = parseHash();

  if (r.name === "home") {
    setChrome({ picker: true, selected: null });
    if ($("city")) $("city").value = "";
    // Someone coming back with a kept location gets a way straight back in.
    const back = LOCATION && LOCATION.city && PLACES[LOCATION.city];
    if (back) {
      paint(`<div class="resume-note">
          <span>Pick up where you left off: <strong>${esc(back.name)}</strong>${
            LOCATION.label ? ` · ${esc(LOCATION.label)}` : ""}</span>
          <a href="#/city/${esc(back.key)}">See the ballot</a>
          ${back.ballot && back.ballot.hasContests ? `<a href="${walkHref(back)}">Walk through it</a>` : ""}
          <button type="button" class="linkish" id="resumeForget">Forget it</button>
        </div>`);
      on("resumeForget", "click", () => { forgetEverything(); route(); });
      return;
    }
    $("results").classList.remove("active");
    $("results").innerHTML = "";
    return;
  }

  const place = PLACES[r.city];
  if (!place) return paintNotFound("We don't have information for that location yet.");

  if (r.name === "city") return renderCity(place);
  if (r.name === "walk") return renderWalk(place, r.id);
  if (r.name === "person") {
    const person = place.people.get(r.id);
    return person ? renderPerson(place, person) : paintNotFound("We couldn't find that person.");
  }
  if (r.name === "contest") {
    const c = place.contests.get(r.id);
    return c ? renderContestPage(place, c) : paintNotFound("We couldn't find that contest.");
  }
  if (r.name === "measure") {
    const m = place.contests.get(r.id);
    return m ? renderMeasurePage(place, m) : paintNotFound("We couldn't find that ballot measure.");
  }
  return renderCity(place);
}

/* ---------- Boot ---------- */

// A narrowed ballot and walkthrough choices survive navigating between pages
// in this tab and die with it — unless the visitor chose "Remember on this
// device". See "What this site keeps on your device".
LOCATION = readKept(KEY_LOCATION);
PICKS = readKept(KEY_PICKS) || {};

// Both review stamps come from one constant; the markup carries no date of
// its own, so a stale one can't survive in the HTML.
for (const id of ["reviewedTop", "reviewedFoot"]) {
  if ($(id)) $(id).textContent = DATA_REVIEWED;
}

const on = (id, ev, fn) => { const el = $(id); if (el) el.addEventListener(ev, fn); };
on("state", "change", onStateChange);
on("city", "change", onCityChange);

on("tabAddress", "click", () => showPane("address"));
on("tabCity", "click", () => showPane("city"));
on("streetInput", "input", onStreetInput);
on("streetInput", "keydown", onStreetKey);
on("streetInput", "blur", () => setTimeout(closeStreetList, 120));
on("houseNo", "keydown", (e) => { if (e.key === "Enter") onFindBallot(); });
on("addrFind", "click", onFindBallot);
on("useLocation", "click", onUseLocation);
// Warm the street list on first focus so the first keystroke already completes.
on("streetInput", "focus", () => { loadStreets().catch(() => {}); });
document.addEventListener("click", (e) => {
  const a = e.target.closest && e.target.closest('a[href^="#"]');
  if (!a) return;
  const href = a.getAttribute("href");
  if (href.startsWith("#/") || href === "#") return;     // a real route
  const target = document.getElementById(decodeURIComponent(href.slice(1)));
  if (!target) return;
  e.preventDefault();
  target.scrollIntoView({ behavior: "smooth", block: "start" });
});
window.addEventListener("popstate", route);
window.addEventListener("hashchange", route);

loadData();
