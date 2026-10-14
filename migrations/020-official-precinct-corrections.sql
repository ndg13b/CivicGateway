-- Migration 020: corrections from the county's official precinct data
--
-- SOURCE: the St. Louis County Board of Elections' own November 3, 2026 data,
-- published on its ArcGIS account (orgid wkbq75VVf2MvUvs7):
--   * precincts_2026_11_view — every precinct with its congressional, state
--     senate, state house, council and school district, and whether anyone
--     lives in it ("Voting Precinct" or "Nonresidential Precinct")
--   * the official sample ballot PDF for each precinct, linked from the same
--     layer.
-- Checked 14 October 2026: all 95 sample ballots for precincts in our five
-- cities were read and compared, contest by contest, with what this site
-- shows for each city. Every candidate (34) and judge (19) on the site appears
-- on those ballots exactly as spelled. Four things differed, all at the edges
-- of a city, and the county's ballots win:
--
--   1. Creve Coeur: precinct CC042 votes in County Council District 5. The
--      site had no District 5 contest. District 5 is 0.08% of the city by
--      area — below the threshold the boundary builder used, which is why the
--      geometry check missed it — but it is a whole precinct of voters.
--   2. Town and Country: precinct CC045 votes in State Senate 24 and State
--      House 71, not House 89. The site showed House 89 to everyone in the
--      city and no Senate contest at all.
--   3. Bridgeton: its only Ritenour precinct (AP204) is nonresidential. Nobody
--      in Bridgeton votes on the Ritenour measures; none of Bridgeton's 16
--      sample ballots carry them. Geometry said "0.9%, a genuine sliver"
--      (migration 011) — true of the land, not of the voters.
--   4. Overland: the reverse. Its only non-Ritenour precinct (MID207) is
--      nonresidential, so every Overland voter gets both Ritenour measures —
--      all 10 Overland sample ballots carry them. "Depends on your address"
--      was wrong.

-- ---------------------------------------------------------------------------
-- 1. County Council District 5 (Creve Coeur, partial)
-- ---------------------------------------------------------------------------
insert into districts (level, name, short_name, state, info_url, sort_order) values
  ('county', 'St. Louis County Council — District 5', 'Council 5', 'MO',
   'https://stlouiscountymo.gov/st-louis-county-government/county-council/', 9);

insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, true
  from jurisdictions j, districts d
 where j.name = 'Creve Coeur' and j.state = 'MO'
   and d.short_name = 'Council 5' and d.state = 'MO';

insert into elections (district_id, name, election_date)
select id, 'General Election', date '2026-11-03'
  from districts where short_name = 'Council 5' and state = 'MO';

-- Lisa Clancy holds the seat (term ends 31 December 2026) and is the only
-- candidate on the ballot, as sample ballot CC-042 shows.
with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'County Council — District 5', 'office', 1,
         'Represents District 5 on the St. Louis County Council. Four-year term. '
         || 'Lisa Clancy is unopposed in November.', 4
    from elections e join districts d on d.id = e.district_id
   where d.short_name = 'Council 5' and d.state = 'MO'
     and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, sort_order)
select r.id, 'Lisa Clancy', 'Democratic', true, 1 from r;

-- ---------------------------------------------------------------------------
-- 2. Town and Country: Senate 24 and House 71 for precinct CC045
-- ---------------------------------------------------------------------------
insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, true
  from jurisdictions j, districts d
 where j.name = 'Town and Country' and j.state = 'MO'
   and d.short_name in ('Senate 24', 'House 71') and d.state = 'MO';

update jurisdiction_districts jd set partial = true
  from jurisdictions j, districts d
 where jd.jurisdiction_id = j.id and jd.district_id = d.id
   and j.name = 'Town and Country' and d.short_name = 'House 89';

-- ---------------------------------------------------------------------------
-- 3. Bridgeton: no Ritenour voters
-- ---------------------------------------------------------------------------
delete from jurisdiction_districts jd
 using jurisdictions j, districts d
 where jd.jurisdiction_id = j.id and jd.district_id = d.id
   and j.name = 'Bridgeton' and d.short_name = 'Ritenour';

-- ---------------------------------------------------------------------------
-- 4. Overland: every voter is in Ritenour
-- ---------------------------------------------------------------------------
update jurisdiction_districts jd set partial = false
  from jurisdictions j, districts d
 where jd.jurisdiction_id = j.id and jd.district_id = d.id
   and j.name = 'Overland' and d.short_name = 'Ritenour';

-- ---------------------------------------------------------------------------
-- Verification: each city's scopes, compared with what the county's ballots
-- say. A mismatch stops the migration rather than half-applying it.
-- ---------------------------------------------------------------------------
do $$
declare want text; got text; city text;
begin
  for city, want in
    select * from (values
      ('Bridgeton',        'House 70, Senate 14'),
      ('Creve Coeur',      'Council 3*, Council 5*, House 71, Parkway C-2*, Senate 24'),
      ('Maryland Heights', 'Council 7*, House 87, Parkway C-2*, Senate 24'),
      ('Overland',         'Council 1*, House 72, Ritenour, Senate 14'),
      ('Town and Country', 'Council 3, House 71*, House 89*, Parkway C-2*, Senate 15, Senate 24*')
    ) as v(city, want)
  loop
    select string_agg(d.short_name || case when jd.partial then '*' else '' end, ', '
                      order by d.short_name)
      into got
      from jurisdiction_districts jd
      join jurisdictions j on j.id = jd.jurisdiction_id
      join districts d on d.id = jd.district_id
     where j.name = city and j.state = 'MO'
       and d.level in ('state_senate', 'state_house', 'county', 'school')
       and d.short_name <> 'St. Louis County';
    if got is distinct from want then
      raise exception 'Migration 020: % scopes are "%", expected "%".', city, got, want;
    end if;
  end loop;

  if not exists (
    select 1 from candidates c
      join races r on r.id = c.race_id
      join elections e on e.id = r.election_id
     where r.title = 'County Council — District 5' and c.name = 'Lisa Clancy'
       and c.incumbent and e.election_date = date '2026-11-03') then
    raise exception 'Migration 020: the District 5 contest was not created.';
  end if;
end $$;
