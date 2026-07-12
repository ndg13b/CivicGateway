/* ============================================================
   Civic Gateway — application logic (ES module)

   Expects the host page to define, BEFORE this module loads:
     window.CIVIC_CONFIG = {
       supabaseUrl:  "https://<project>.supabase.co",
       supabaseKey:  "<anon public key>",   // read-only by RLS
     };

   All text that originates in the database is escaped with esc()
   before being placed in HTML, so a stray quote or angle bracket
   in a name, note, or URL can never break or script the page.
   ============================================================ */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CONFIG = window.CIVIC_CONFIG || {};
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

let PLACES = {};        // key "Maryland Heights, MO" -> jurisdiction view-model
let CURRENT_KEY = null; // selected place key
let MODAL_PEOPLE = [];  // people list backing the open results view (for dialog lookup)

const $ = (id) => document.getElementById(id);

/* ---------- Safety ---------- */

function esc(v) {
  return String(v ?? "")
    .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;").replaceAll("'", "&#39;");
}

// Only allow http(s) and mailto/tel links from data; anything else is dropped.
function safeUrl(u, allowed = ["http:", "https:"]) {
  try {
    const parsed = new URL(String(u), window.location.href);
    return allowed.includes(parsed.protocol) ? parsed.href : null;
  } catch { return null; }
}

/* ---------- Data loading ---------- */

async function loadData() {
  showStatus("Loading available areas…");

  if (!CONFIG.supabaseUrl || !CONFIG.supabaseKey) {
    showError("This page is not configured: CIVIC_CONFIG is missing its Supabase URL or key.");
    return;
  }

  const supabase = createClient(CONFIG.supabaseUrl, CONFIG.supabaseKey);
  const { data, error } = await supabase
    .from("jurisdictions")
    .select(`
      *,
      officials(*),
      elections(
        *,
        races(
          *,
          candidates(*, resources:resources_candidate_id_fkey(*)),
          resources:resources_race_id_fkey(*)
        )
      )
    `);

  if (error) {
    showError(`We couldn't load the data (${error.message}). This is usually temporary.`);
    return;
  }
  if (!data || !data.length) {
    showError("The database is reachable but has no areas in it yet.");
    return;
  }

  PLACES = {};
  const today = new Date().toISOString().slice(0, 10);

  for (const j of data) {
    const key = `${j.name}, ${j.state}`;
    const officials = (j.officials || [])
      .slice().sort((a, b) => a.sort_order - b.sort_order)
      .map((o) => ({
        name: o.name, office: o.office, party: o.party, term: o.term, bio: o.bio,
        email: o.email, phone: o.phone, website: o.website,
        twitter: o.twitter, facebook: o.facebook, interviews: [],
      }));

    const nextElection = (j.elections || [])
      .filter((e) => e.election_date >= today)
      .sort((a, b) => a.election_date.localeCompare(b.election_date))[0];

    let election = null;
    if (nextElection) {
      election = {
        name: nextElection.name,
        date: nextElection.election_date,
        races: (nextElection.races || [])
          .slice().sort((a, b) => a.sort_order - b.sort_order)
          .map((r) => ({
            title: r.title,
            description: r.description,
            debates: (r.resources || []).filter((x) => x.kind === "debate"),
            info: (r.resources || []).filter((x) => x.kind === "info"),
            candidates: (r.candidates || [])
              .slice().sort((a, b) => a.sort_order - b.sort_order)
              .map((c) => ({
                name: c.name, office: null, party: c.party, term: null, bio: c.bio,
                email: c.email, phone: c.phone, website: c.website,
                twitter: c.twitter, facebook: c.facebook,
                interviews: (c.resources || []).filter((x) => x.kind === "interview"),
              })),
          })),
      };
    }

    PLACES[key] = {
      key,
      name: j.name,
      state: j.state,
      county: j.county,
      website: j.city_website,
      social: { twitter: j.twitter, facebook: j.facebook, instagram: j.instagram, youtube: j.youtube },
      note: j.next_election_note,
      election,
      officials,
    };
  }

  hideStatus();
  populateStates();
  restoreFromHash();
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
  const set = new Set(Object.values(PLACES).map((p) => p.state));
  return [...set].sort();
}

function populateStates() {
  const sel = $("state");
  const states = statesInData();
  sel.innerHTML = "";
  sel.disabled = false;

  if (states.length === 1) {
    // Only one state available: pre-select it, no extra click needed.
    const s = states[0];
    sel.append(new Option(STATE_NAMES[s] || s, s, true, true));
    populateCities(s);
  } else {
    sel.append(new Option("Select a state…", ""));
    for (const s of states) sel.append(new Option(STATE_NAMES[s] || s, s));
    $("city").disabled = true;
    $("city").innerHTML = "";
    $("city").append(new Option("Select a state first", ""));
  }
}

function populateCities(state, preselectKey = null) {
  const sel = $("city");
  sel.innerHTML = "";
  sel.disabled = false;
  sel.append(new Option("Select your city…", ""));
  Object.values(PLACES)
    .filter((p) => p.state === state)
    .sort((a, b) => a.name.localeCompare(b.name))
    .forEach((p) => sel.append(new Option(p.name, p.key, false, p.key === preselectKey)));
  if (preselectKey && PLACES[preselectKey]) render(preselectKey);
}

function onStateChange() {
  const s = $("state").value;
  clearResults();
  if (!s) {
    $("city").disabled = true;
    $("city").innerHTML = "";
    $("city").append(new Option("Select a state first", ""));
    return;
  }
  populateCities(s);
}

function onCityChange() {
  const key = $("city").value;
  if (!key) { clearResults(); return; }
  render(key);
  const p = PLACES[key];
  history.replaceState(null, "", `#${slug(p)}`);
}

function slug(p) {
  return `${p.name}-${p.state}`.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

function restoreFromHash() {
  const h = window.location.hash.replace(/^#/, "");
  if (!h) return;
  const match = Object.values(PLACES).find((p) => slug(p) === h);
  if (!match) return;
  $("state").value = match.state;
  populateCities(match.state, match.key);
}

/* ---------- Rendering ---------- */

function clearResults() {
  const r = $("results");
  r.classList.remove("active");
  r.innerHTML = "";
  CURRENT_KEY = null;
  MODAL_PEOPLE = [];
}

function render(key) {
  const p = PLACES[key];
  if (!p) return;
  CURRENT_KEY = key;
  const r = $("results");

  let html = `
    <div class="jurisdiction-header">
      <h2>${esc(p.name)}, ${esc(STATE_NAMES[p.state] || p.state)}</h2>
      ${p.county ? `<span class="county">${esc(p.county)}</span>` : ""}
    </div>
    ${cityLinksRow(p)}`;

  if (p.election) {
    html += renderElection(p);
  } else {
    html += `
      <div class="notice"><strong>No election is currently scheduled.</strong>
      ${p.note ? ` ${esc(p.note)}` : ""}</div>
      ${renderOfficials(p)}`;
  }

  r.innerHTML = html;
  r.classList.add("active");
  attachPersonHandlers(r);
  r.scrollIntoView({ behavior: "smooth", block: "start" });
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

function initials(name) {
  const words = String(name).split(/\s+/).map((w) => w.replace(/[^\p{L}]/gu, "")).filter(Boolean);
  return words.slice(0, 2).map((w) => w[0].toUpperCase()).join("") || "•";
}

function personCard(person, index, { featured = false } = {}) {
  return `
    <button type="button" class="person-card${featured ? " featured" : ""}" data-person="${index}">
      <span class="avatar" aria-hidden="true">${esc(initials(person.name))}</span>
      <span class="person-info">
        <span class="person-name">${esc(person.name)}</span>
        <span class="person-office">${esc(person.office || person.party || "")}</span>
      </span>
      <span class="person-more" aria-hidden="true">Details ›</span>
    </button>`;
}

function renderOfficials(p) {
  MODAL_PEOPLE = p.officials;
  const featured = [];
  const rest = [];
  p.officials.forEach((o, i) => {
    (String(o.office || "").toLowerCase().startsWith("mayor") ? featured : rest).push([o, i]);
  });
  return `
    <div class="section-title">Your current elected officials</div>
    <div class="people-grid">
      ${featured.map(([o, i]) => personCard(o, i, { featured: true })).join("")}
      ${rest.map(([o, i]) => personCard(o, i)).join("")}
    </div>`;
}

function renderElection(p) {
  const e = p.election;
  // Flatten candidates across races into one list the dialog can index into.
  MODAL_PEOPLE = [];
  let html = `
    <div class="election-banner">
      <h3>${esc(e.name)}</h3>
      <div class="date">Election day: ${esc(formatDate(e.date))}</div>
    </div>
    <div class="section-title">What's on the ballot</div>`;

  e.races.forEach((race, ri) => {
    const hasResources = race.debates.length || race.info.length;
    html += `
      <div class="race">
        <div class="race-header">
          <h4>${esc(race.title)}</h4>
          ${hasResources ? `<button type="button" class="race-resources-btn" data-race="${ri}">Debates &amp; info</button>` : ""}
        </div>
        ${race.description ? `<p class="race-description">${esc(race.description)}</p>` : ""}
        <div class="people-grid">
          ${race.candidates.map((c) => {
            const idx = MODAL_PEOPLE.push(c) - 1;
            return personCard(c, idx);
          }).join("")}
        </div>
      </div>`;
  });
  return html;
}

function formatDate(iso) {
  try {
    return new Date(`${iso}T12:00:00`).toLocaleDateString("en-US", {
      weekday: "long", year: "numeric", month: "long", day: "numeric",
    });
  } catch { return iso; }
}

/* ---------- Person / race dialogs ---------- */

function attachPersonHandlers(root) {
  root.querySelectorAll(".person-card").forEach((btn) => {
    btn.addEventListener("click", () => openPerson(Number(btn.dataset.person)));
  });
  root.querySelectorAll(".race-resources-btn").forEach((btn) => {
    btn.addEventListener("click", () => openRace(Number(btn.dataset.race)));
  });
}

function contactLinks(c) {
  const parts = [];
  const site = safeUrl(c.website);
  if (site) parts.push(`<a class="link" href="${esc(site)}" target="_blank" rel="noopener">Website</a>`);
  if (c.email) parts.push(`<a class="link" href="mailto:${esc(c.email)}">Email</a>`);
  if (c.phone) parts.push(`<a class="link" href="tel:${esc(String(c.phone).replace(/[^0-9+]/g, ""))}">${esc(c.phone)}</a>`);
  if (c.twitter) parts.push(`<a class="link" href="https://twitter.com/${encodeURIComponent(String(c.twitter).replace("@", ""))}" target="_blank" rel="noopener">X / Twitter</a>`);
  if (c.facebook) parts.push(`<a class="link" href="https://facebook.com/${encodeURIComponent(c.facebook)}" target="_blank" rel="noopener">Facebook</a>`);
  return parts.join("");
}

function openPerson(index) {
  const c = MODAL_PEOPLE[index];
  if (!c) return;
  const links = contactLinks(c);
  const interviews = (c.interviews || [])
    .map((v) => {
      const u = safeUrl(v.url);
      return u ? `<a class="link" href="${esc(u)}" target="_blank" rel="noopener">${esc(v.title)}</a>` : "";
    }).join("");

  $("dialogBody").innerHTML = `
    <h3>${esc(c.name)}</h3>
    <div class="role">${esc([c.office, c.party, c.term].filter(Boolean).join(" · "))}</div>
    ${c.bio ? `<p>${esc(c.bio)}</p>` : ""}
    <h4>Contact &amp; links</h4>
    <div class="links">${links || '<span class="none">No links available</span>'}</div>
    ${interviews ? `<h4>Interviews &amp; coverage</h4><div class="links">${interviews}</div>` : ""}`;
  $("personDialog").showModal();
}

function openRace(raceIndex) {
  const p = PLACES[CURRENT_KEY];
  const race = p?.election?.races[raceIndex];
  if (!race) return;
  const sec = (label, arr) => {
    const items = arr.map((x) => {
      const u = safeUrl(x.url);
      return u ? `<a class="link" href="${esc(u)}" target="_blank" rel="noopener">${esc(x.title)}</a>` : "";
    }).join("");
    return items ? `<h4>${label}</h4><div class="links">${items}</div>` : "";
  };
  $("dialogBody").innerHTML = `
    <h3>${esc(race.title)}</h3>
    <div class="role">Ballot item — debates &amp; information</div>
    ${sec("Debate &amp; forum videos", race.debates)}
    ${sec("Voter information", race.info)}`;
  $("personDialog").showModal();
}

/* ---------- Boot ---------- */

$("state").addEventListener("change", onStateChange);
$("city").addEventListener("change", onCityChange);
$("dialogClose").addEventListener("click", () => $("personDialog").close());
$("personDialog").addEventListener("click", (e) => {
  // Click on the backdrop (outside the panel) closes the dialog.
  if (e.target === e.currentTarget) e.currentTarget.close();
});

loadData();
