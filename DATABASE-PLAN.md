# Database Plan: Moving Civic Gateway off a hardcoded JS object

Right now all data lives inside `index.html`, in the `BALLOT_DATA` object. This
document describes moving that data into a real database (Supabase, a hosted
Postgres service with a free tier) without changing anything visitors see.

## Why

`BALLOT_DATA` works fine for 3 cities. It gets painful once you have dozens of
cities, want other people to help maintain data, or want data updates to not
require editing HTML/JS. A database also removes the "is `upcomingElection`
null or not" guesswork — instead you just ask "does this city have an election
row with a future date?"

## Table design

Each piece of `BALLOT_DATA` maps to a table:

| Current field | Table | Notes |
|---|---|---|
| City key (`"Maryland Heights, MO"`) | `jurisdictions` | one row per city |
| `county`, `cityWebsite`, `citySocial` | `jurisdictions` columns | |
| `nextElectionNote` | `jurisdictions.next_election_note` | |
| `currentOfficials[]` | `officials` | each row points at a `jurisdiction_id` |
| `upcomingElection` | `elections` | one row per election event, points at a `jurisdiction_id` |
| `upcomingElection.races[]` | `races` | each row points at an `election_id` |
| `race.candidates[]` | `candidates` | each row points at a `race_id` |
| `race.resources.debates/info` | `resources` (kind = `debate`/`info`) | points at a `race_id` |
| `candidate.interviews[]` | `resources` (kind = `interview`) | points at a `candidate_id` |

See `schema.sql` for the actual table definitions and `seed.sql` for the 3
current cities converted into insertable rows.

### Design decisions worth knowing

- **`officials` and `candidates` are separate tables**, even though both are
  "people," because they attach to different parents (a candidate belongs to
  a race; an official belongs to a city directly).
- **"Is there an election?" is a query, not a stored flag.** A city has an
  upcoming election if it has an `elections` row with `election_date` in the
  future. This can't go stale the way a hand-set `upcomingElection: null` can.
- **Security model:** Row Level Security (RLS) is on for every table, with a
  "public can read" policy and *no* write policy. That means the public
  anon key (safe to put in client-side code) can only ever read — nobody can
  modify data through the website itself. Edits happen through the Supabase
  dashboard or a service-role key that never leaves your machine.

## Rollout steps

1. **Create a Supabase project** (free tier) at supabase.com.
2. **Run `schema.sql`** in the Supabase SQL editor to create the tables + RLS
   policies.
3. **Run `seed.sql`** to load Maryland Heights, Creve Coeur, and Bridgeton.
4. **Build a separate test page** (`db-test.html` in this repo) that fetches
   from Supabase instead of reading `BALLOT_DATA`, and reshapes the response
   into the same shape the existing render functions expect. Compare it
   side-by-side against the live `index.html` until they match.
5. **Only once you're happy**, replace `index.html`'s data layer with the
   Supabase fetch (or point your domain at the new page). The static file
   keeps working the whole time — there's no risky cutover moment.

## Known tradeoff

Once the site depends on Supabase, it depends on Supabase being reachable —
free-tier projects pause after a period of inactivity and need a click to
wake. Fine while building; before relying on this for a live election, either
upgrade off the free tier or keep a static snapshot of `BALLOT_DATA` as a
fallback if the fetch fails (the pattern used in `db-test.html`).

## What's next after this

- Add more nearby cities (the `officials`/`jurisdictions` shape scales to any
  number without code changes).
- Wire in a Google Civic Information Elections API proxy (a small serverless
  function) for jurisdictions with active statewide/federal elections, since
  that API key must never live in client-side code.
- Add an admin UI so a non-developer can add/edit a city without SQL.
