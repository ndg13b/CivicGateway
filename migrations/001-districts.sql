-- Migration 001: Legislative districts
-- Run AFTER schema.sql (existing projects: just run this file in the
-- Supabase SQL editor).
--
-- Cities and districts overlap in both directions (a city can span several
-- districts, a district covers many cities), so districts are their own
-- table with a many-to-many mapping to jurisdictions. Officials and
-- elections can now belong to EITHER a jurisdiction (mayor, city council)
-- or a district (state rep, state senator, U.S. representative).

-- One row per legislative district
create table districts (
  id uuid primary key default gen_random_uuid(),
  level text not null check (level in ('us_house', 'state_senate', 'state_house')),
  name text not null,               -- "Missouri's 1st Congressional District"
  short_name text,                  -- "MO-1", "Senate District 24"
  state text not null,              -- "MO"
  info_url text,                    -- official district/member page
  sort_order int not null default 0,
  unique (level, name, state)
);

-- Which districts cover which cities. partial = true means only part of
-- the city is inside this district (very common — always note it in the UI).
create table jurisdiction_districts (
  jurisdiction_id uuid not null references jurisdictions(id) on delete cascade,
  district_id uuid not null references districts(id) on delete cascade,
  partial boolean not null default false,
  primary key (jurisdiction_id, district_id)
);

-- Officials can belong to a jurisdiction OR a district (exactly one)
alter table officials add column district_id uuid references districts(id) on delete cascade;
alter table officials alter column jurisdiction_id drop not null;
alter table officials add constraint officials_exactly_one_parent check (
  (jurisdiction_id is not null and district_id is null) or
  (jurisdiction_id is null and district_id is not null)
);

-- Elections too (a district-level election like a U.S. House race)
alter table elections add column district_id uuid references districts(id) on delete cascade;
alter table elections alter column jurisdiction_id drop not null;
alter table elections add constraint elections_exactly_one_parent check (
  (jurisdiction_id is not null and district_id is null) or
  (jurisdiction_id is null and district_id is not null)
);

-- Same security model as everything else: world reads, nobody writes
-- through the public key.
alter table districts enable row level security;
alter table jurisdiction_districts enable row level security;
create policy "public can read districts" on districts for select using (true);
create policy "public can read jurisdiction_districts" on jurisdiction_districts for select using (true);
grant select on districts, jurisdiction_districts to anon, authenticated;
