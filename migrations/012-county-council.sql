-- Migration 012: St. Louis County Council districts
--
-- Migration 011 created a placeholder "County Council" scope with an election
-- and no races, so the ballot would admit the contest was unlisted rather than
-- look complete. The county's GIS publishes the boundaries after all —
-- Council_District_Plan_2022, on the county's ArcGIS service — so the
-- placeholder can be replaced with the real thing.
--
-- Coverage, from those polygons against each city, as percent of city area:
--
--   Bridgeton          District 2  99.94%
--   Maryland Heights   District 2  97.73%   District 7  1.39%
--   Overland           District 2  60.19%   District 1 39.81%
--   Creve Coeur        District 2  59.15%   District 3 40.77%
--   Town and Country   District 3  99.99%
--
-- Districts 1, 3, 5 and 7 are on the 2026 ballot; 2, 4 and 6 are mid-term.
-- That single fact does most of the work here:
--
--   * Bridgeton has NO council contest this year — it is District 2 almost
--     entirely, and District 2 is not up. No scope is added for it, because
--     nothing appears on that ballot to explain.
--   * Maryland Heights has one for 1.4% of the city. Small, but real: those
--     residents vote in District 7 and everyone else in the city does not.
--   * Overland and Creve Coeur are split roughly 60/40 between a district
--     that is up and one that is not.
--
-- Every mapping below is therefore partial except Town and Country's.
-- Candidates come from the county's ballot content report of 16 September.
--
-- Run AFTER 011.

-- ---------------------------------------------------------------------------
-- Retire the placeholder
-- ---------------------------------------------------------------------------
delete from elections e using districts d
 where e.district_id = d.id and d.short_name = 'County Council' and d.state = 'MO';
delete from jurisdiction_districts jd using districts d
 where jd.district_id = d.id and d.short_name = 'County Council' and d.state = 'MO';
delete from districts
 where short_name = 'County Council' and state = 'MO';

-- ---------------------------------------------------------------------------
-- The three council districts that both touch our cities and are on the ballot
-- ---------------------------------------------------------------------------
insert into districts (level, name, short_name, state, info_url, sort_order) values
  ('county', 'St. Louis County Council — District 1', 'Council 1', 'MO',
   'https://stlouiscountymo.gov/st-louis-county-government/county-council/', 9),
  ('county', 'St. Louis County Council — District 3', 'Council 3', 'MO',
   'https://stlouiscountymo.gov/st-louis-county-government/county-council/', 9),
  ('county', 'St. Louis County Council — District 7', 'Council 7', 'MO',
   'https://stlouiscountymo.gov/st-louis-county-government/county-council/', 9);

insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, v.partial
from (values
  ('Overland',         'Council 1', true),   -- 39.8% of the city
  ('Creve Coeur',      'Council 3', true),   -- 40.8%
  ('Town and Country', 'Council 3', false),  -- 99.99%
  ('Maryland Heights', 'Council 7', true)    -- 1.4%
) as v(city, short_name, partial)
join jurisdictions j on j.name = v.city and j.state = 'MO'
join districts d on d.short_name = v.short_name and d.state = 'MO';

insert into elections (district_id, name, election_date)
select id, 'General Election', date '2026-11-03'
from districts where short_name in ('Council 1','Council 3','Council 7') and state = 'MO';

-- District 1 — Rita H Days (D), no other candidate filed.
with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'County Council — District 1', 'office', 1,
         'Represents District 1 on the St. Louis County Council. Four-year term. '
         || 'No other candidate filed for this seat.', 4
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'Council 1' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, sort_order)
select r.id, 'Rita H Days', 'Democratic', false, 1 from r;

-- District 3 — Andrew Koenig (R) v. Mark Osmack (D).
with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'County Council — District 3', 'office', 1,
         'Represents District 3 on the St. Louis County Council. Four-year term.', 4
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'Council 3' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, sort_order)
select r.id, v.name, v.party, false, v.sort_order
from r, (values ('Andrew Koenig','Republican',0), ('Mark Osmack','Democratic',1))
  as v(name, party, sort_order);

-- District 7 — Mark Harder (R) v. John Kiehne (D).
with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'County Council — District 7', 'office', 1,
         'Represents District 7 on the St. Louis County Council. Four-year term.', 4
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'Council 7' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, sort_order)
select r.id, v.name, v.party, false, v.sort_order
from r, (values ('Mark Harder','Republican',0), ('John Kiehne','Democratic',1))
  as v(name, party, sort_order);

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
do $$
declare got text; want text;
begin
  if exists (select 1 from districts where short_name = 'County Council') then
    raise exception 'Migration 012: placeholder County Council scope still present.';
  end if;

  for want, got in
    select w.expected,
           coalesce((select string_agg(d.short_name, ', ' order by d.short_name)
                       from jurisdiction_districts jd
                       join districts d on d.id = jd.district_id
                      where jd.jurisdiction_id = j.id
                        and d.short_name like 'Council %'), '')
    from (values
      ('Overland', 'Council 1'), ('Creve Coeur', 'Council 3'),
      ('Town and Country', 'Council 3'), ('Maryland Heights', 'Council 7'),
      ('Bridgeton', '')       -- District 2, not on this ballot
    ) as w(city, expected)
    join jurisdictions j on j.name = w.city and j.state = 'MO'
  loop
    if got is distinct from want then
      raise exception 'Migration 012: council mapping wrong. expected [%], got [%]', want, got;
    end if;
  end loop;
end $$;
