-- Civic Gateway — Supabase / PostgreSQL schema
-- Run this in the Supabase SQL editor (Project → SQL Editor → New query).
-- Mirrors the shape of BALLOT_DATA in index.html: one row per city, official,
-- election, race, candidate, and debate/interview resource.

create extension if not exists "pgcrypto";

-- One row per city/jurisdiction (e.g. "Maryland Heights, MO")
create table jurisdictions (
  id uuid primary key default gen_random_uuid(),
  name text not null,               -- "Maryland Heights"
  state text not null,              -- "MO"
  county text,                      -- "St. Louis County"
  city_website text,
  twitter text,
  facebook text,
  instagram text,
  youtube text,
  next_election_note text,          -- shown when no election is scheduled
  unique (name, state)
);

-- Current officeholders for a jurisdiction (shown when there's no upcoming election)
create table officials (
  id uuid primary key default gen_random_uuid(),
  jurisdiction_id uuid not null references jurisdictions(id) on delete cascade,
  name text not null,
  office text not null,             -- "Mayor", "City Council — Ward 1"
  party text,
  term text,
  bio text,
  email text,
  phone text,
  website text,
  twitter text,
  facebook text,
  sort_order int not null default 0
);

-- An election event for a jurisdiction (e.g. "Municipal General Election")
create table elections (
  id uuid primary key default gen_random_uuid(),
  jurisdiction_id uuid not null references jurisdictions(id) on delete cascade,
  name text not null,
  election_date date not null
);

-- A single ballot item within an election (e.g. "Mayor", "Prop A")
create table races (
  id uuid primary key default gen_random_uuid(),
  election_id uuid not null references elections(id) on delete cascade,
  title text not null,
  description text,
  sort_order int not null default 0
);

-- A candidate running in a race
create table candidates (
  id uuid primary key default gen_random_uuid(),
  race_id uuid not null references races(id) on delete cascade,
  name text not null,
  party text,
  bio text,
  email text,
  phone text,
  website text,
  twitter text,
  facebook text,
  sort_order int not null default 0
);

-- Debate/forum/info videos (attached to a race) and interviews (attached to a
-- candidate). Exactly one of race_id / candidate_id is set.
create table resources (
  id uuid primary key default gen_random_uuid(),
  race_id uuid references races(id) on delete cascade,
  candidate_id uuid references candidates(id) on delete cascade,
  kind text not null check (kind in ('debate', 'info', 'interview')),
  title text not null,
  url text not null,
  sort_order int not null default 0,
  check (
    (race_id is not null and candidate_id is null) or
    (race_id is null and candidate_id is not null)
  )
);

-- ---------------------------------------------------------------------------
-- Row Level Security: the world can read, nobody can write except you
-- (via the Supabase dashboard / service-role key, never from the browser).
-- ---------------------------------------------------------------------------

alter table jurisdictions enable row level security;
alter table officials enable row level security;
alter table elections enable row level security;
alter table races enable row level security;
alter table candidates enable row level security;
alter table resources enable row level security;

create policy "public can read jurisdictions" on jurisdictions for select using (true);
create policy "public can read officials" on officials for select using (true);
create policy "public can read elections" on elections for select using (true);
create policy "public can read races" on races for select using (true);
create policy "public can read candidates" on candidates for select using (true);
create policy "public can read resources" on resources for select using (true);

-- No insert/update/delete policies are defined on purpose — that means the
-- public "anon" key can never modify data, only the Supabase dashboard
-- (or a service-role key you never expose to the browser) can.

-- RLS policies only take effect once a role has the underlying table
-- privilege. Grant the Supabase anon/authenticated roles read-only access;
-- combined with the select-only policies above and no write policies, the
-- public key can read every row but modify nothing. The ALTER DEFAULT line
-- makes this apply automatically to any tables added later.
grant usage on schema public to anon, authenticated;
grant select on all tables in schema public to anon, authenticated;
alter default privileges in schema public grant select on tables to anon, authenticated;
