-- Migration 008: district mapping corrections found by geocoding
--
-- The district table in EXPANSION-PLAN §1 was built in July 2026 from
-- legislator bios and encyclopaedia articles, which describe districts in
-- prose ("includes Maryland Heights (part)"). With the Census geographies API
-- now reachable, those mappings were checked against the 2024 state
-- legislative layer — the current one — by sampling points across each city
-- and keeping only those the API places inside that city.
--
-- Results (each line is every sample point that landed in the city):
--
--   Town and Country   15/15  Senate 15 | House 89
--   Maryland Heights  105/105 Senate 24 | House 87
--   Creve Coeur        21/21  Senate 24 | House 71
--   Bridgeton          21/21  Senate 14 | House 70
--   Overland           34/34  Senate 14 | House 72
--
-- Bridgeton and Creve Coeur match what we already had. The other three do not.
--
-- ⚠ WHAT THIS MIGRATION DOES AND DOES NOT DO
--
-- Sampling can prove a district IS present in a city. It cannot prove one is
-- absent — a small sliver can fall between sample points. So this migration
-- only ADDS mappings and contests. It removes nothing, because removing a
-- mapping could hide a contest from someone entitled to vote in it, and that
-- is the worse error.
--
-- The removals that the evidence suggests are listed at the bottom as a
-- decision for a human with access to an official district map. Until then
-- the affected cities show extra contests behind an "if you live in…" note,
-- which is misleading but not disenfranchising.

-- ---------------------------------------------------------------------------
-- Missouri House District 72 — Overland
--
-- This is the significant one. Overland is currently mapped to House 71 and
-- not to House 72 at all, so Overland voters are shown the District 71
-- contest — which 34 of 34 sample points say is not theirs — and are not
-- shown District 72, which is. District 72 does not exist in our data at all.
--
-- Certified candidates, from the Secretary of State's booklet:
--   R: Jeffrey Jacks    D: Patrick James Wroblewski
-- ---------------------------------------------------------------------------
insert into districts (level, name, short_name, state, info_url, sort_order)
values ('state_house', 'Missouri House District 72', 'House 72', 'MO',
        'https://house.mo.gov/MemberDetails.aspx?district=072', 4);

insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, false
from jurisdictions j, districts d
where d.short_name = 'House 72' and d.state = 'MO'
  and j.name = 'Overland' and j.state = 'MO';

insert into elections (district_id, name, election_date)
select id, 'General Election', date '2026-11-03'
from districts where short_name = 'House 72' and state = 'MO';

with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'State Representative — District 72', 'office', 1,
         'Represents the 72nd District in the Missouri House. Two-year term.', 0
  from elections e
  join districts d on d.id = e.district_id
  where d.short_name = 'House 72' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, sort_order)
select r.id, v.name, v.party, false, v.sort_order
from r, (values
  ('Jeffrey Jacks',            'Republican', 0),
  ('Patrick James Wroblewski', 'Democratic', 1)
) as v(name, party, sort_order);

-- ---------------------------------------------------------------------------
-- Missouri Senate District 15 — Town and Country
--
-- Town and Country had no senate district mapped at all. It is District 15,
-- uniformly across 15 sample points.
--
-- District 15 is odd-numbered, and 2026 elects only even-numbered Missouri
-- senate seats — every senate district in the certified booklet is even. So
-- there is deliberately NO election row here: Town and Country correctly has
-- no state senate contest this cycle. The mapping still matters, so the city
-- shows its sitting senator under "who represents you now" and so the seat
-- appears automatically in 2028.
-- ---------------------------------------------------------------------------
insert into districts (level, name, short_name, state, info_url, sort_order)
values ('state_senate', 'Missouri Senate District 15', 'Senate 15', 'MO',
        'https://www.senate.mo.gov/Senators/Member/15', 3);

insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, false
from jurisdictions j, districts d
where d.short_name = 'Senate 15' and d.state = 'MO'
  and j.name = 'Town and Country' and j.state = 'MO';

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n
  from races r join elections e on e.id = r.election_id
  where r.title = 'State Representative — District 72'
    and e.election_date = date '2026-11-03';
  if n <> 1 then
    raise exception 'Migration 008: House 72 contest not created (found %).', n;
  end if;

  select count(*) into n
  from jurisdictions j
  join jurisdiction_districts jd on jd.jurisdiction_id = j.id
  join districts d on d.id = jd.district_id
  where j.name = 'Town and Country' and d.short_name = 'Senate 15';
  if n <> 1 then
    raise exception 'Migration 008: Town and Country not mapped to Senate 15 (found %).', n;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- NOT DONE — needs an official district map, not sampling
--
-- Every sample point in these cities contradicted the mapping we hold. If an
-- official map confirms it, these mappings should be deleted, and the cities
-- stop showing contests their residents cannot vote in:
--
--   Maryland Heights — currently mapped to Senate 14, House 70 and House 71
--     in addition to Senate 24 and House 87. 105 of 105 sample points across
--     the whole city returned Senate 24 and House 87 only. If correct,
--     Maryland Heights is being shown three contests it has no vote in, and
--     the "if you live in District 70/71/87" split is entirely spurious.
--
--   Overland — currently mapped to House 71. 34 of 34 points returned
--     House 72 (added above). The House 71 mapping is very likely wrong.
--
-- Check against https://house.mo.gov/districtmap.aspx and the county's
-- precinct maps before deleting anything. The deletions would be:
--
--   delete from jurisdiction_districts jd
--    using jurisdictions j, districts d
--    where jd.jurisdiction_id = j.id and jd.district_id = d.id
--      and ( (j.name = 'Maryland Heights'
--             and d.short_name in ('Senate 14','House 70','House 71'))
--         or (j.name = 'Overland' and d.short_name = 'House 71') );
-- ---------------------------------------------------------------------------
