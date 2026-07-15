-- Migration 003: Add Town and Country and Overland
-- Run AFTER migrations/002-seed-districts.sql.
--
-- Rosters transcribed from each city's official elected-officials page
-- (July 2026). District mappings below only include what could be verified;
-- known gaps are marked TODO — resolve them with the official lookup tools
-- linked in EXPANSION-PLAN.md before treating district info as complete.

-- ---------------------------------------------------------------------------
-- Town and Country, MO — Mayor + Board of Aldermen (two per ward)
-- Source: https://www.town-and-country.org/ elected officials page
-- ---------------------------------------------------------------------------
with j as (
  insert into jurisdictions (name, state, county, city_website, next_election_note)
  values (
    'Town and Country', 'MO', 'St. Louis County',
    'https://www.town-and-country.org/',
    'The Board of Aldermen has two members per ward; municipal elections are held in April. Candidate details will appear here once filing opens. The full board can be reached at CityCouncil@town-and-country.org.'
  )
  returning id
)
insert into officials (jurisdiction_id, name, office, party, email, phone, sort_order)
select id, v.name, v.office, 'Nonpartisan', v.email, v.phone, v.sort_order
from j, (values
  ('Charles H. Rehm, Jr.', 'Mayor',                       'TCmayor@town-and-country.org',      '314-413-2937', 0),
  ('Barbara Ann Hughes',   'Board of Aldermen — Ward 1',  'barbhugs1954@gmail.com',            '314-872-8228', 1),
  ('Ben Schwoerer',        'Board of Aldermen — Ward 1',  'tandcward1@gmail.com',              '314-712-2802', 2),
  ('Al Gerber',            'Board of Aldermen — Ward 2',  'algerber4ward2@gmail.com',          '314-409-4727', 3),
  ('Michelle Friedman',    'Board of Aldermen — Ward 2',  'michellefriedman.ward2@gmail.com',  '314-920-9163', 4),
  ('John Harder',          'Board of Aldermen — Ward 3',  'tryharderforward3@gmail.com',       '314-910-0969', 5),
  ('Joe Kinsella',         'Board of Aldermen — Ward 3',  'kinsella23ward3@gmail.com',         '314-374-6673', 6),
  ('Michael Sawyer',       'Board of Aldermen — Ward 4',  'sawyer4ward4@gmail.com',            '314-329-7710', 7),
  ('David Murphy',         'Board of Aldermen — Ward 4',  'murphy4alderman@gmail.com',         '636-686-0563', 8)
) as v(name, office, email, phone, sort_order);

-- ---------------------------------------------------------------------------
-- Overland, MO — Mayor + City Council (two per ward, staggered terms)
-- Source: https://overlandmo.org/226/City-Council and city directory
-- ---------------------------------------------------------------------------
with j as (
  insert into jurisdictions (name, state, county, city_website, next_election_note)
  values (
    'Overland', 'MO', 'St. Louis County',
    'https://overlandmo.org/',
    'Council terms are staggered, expiring in April 2027 and April 2028 by seat; municipal elections are held in April. Candidate details will appear here once filing opens.'
  )
  returning id
)
insert into officials (jurisdiction_id, name, office, party, term, email, phone, sort_order)
select id, v.name, v.office, 'Nonpartisan', v.term, v.email, v.phone, v.sort_order
from j, (values
  ('Marty A. Little',     'Mayor',                    'Term expires April 2030', null,                          null,           0),
  ('Beth Ruckman',        'City Council — Ward 1',    'Term expires April 2027', 'bethruckman@overlandmo.org',  '314-913-0841', 1),
  ('Patrick Wroblewski',  'City Council — Ward 1',    'Term expires April 2028', 'patrickw@overlandmo.org',     '314-313-2620', 2),
  ('Karen Stiebel',       'City Council — Ward 2',    'Term expires April 2027', 'karens@overlandmo.org',       '314-409-4934', 3),
  ('Lee Furnace',         'City Council — Ward 2',    'Term expires April 2028', 'leefurnace@overlandmo.org',   null,           4),
  ('Jessica Requejo',     'City Council — Ward 3',    'Term expires April 2028', 'jessicar@overlandmo.org',     '314-441-6364', 5),
  ('Leslie Ferguson',     'City Council — Ward 3',    'Term expires April 2027', 'l.ferguson@overlandmo.org',   '314-609-0179', 6),
  ('Larry Bennett',       'City Council — Ward 4',    'Term expires April 2027', 'lbennett@overlandmo.org',     '314-629-2221', 7),
  ('Kirby Barnard',       'City Council — Ward 4',    'Term expires April 2028', 'kirbybarnard@overlandmo.org', '314-423-0267', 8)
) as v(name, office, term, email, phone, sort_order);

-- ---------------------------------------------------------------------------
-- New district: Missouri House District 89 (parts of Town and Country,
-- Des Peres, Chesterfield)
-- ---------------------------------------------------------------------------
with d as (
  insert into districts (level, name, short_name, state, info_url, sort_order)
  values ('state_house', 'Missouri House District 89', 'House 89', 'MO',
          'https://house.mo.gov/MemberDetails.aspx?district=089', 23)
  returning id
)
insert into officials (district_id, name, office, party, term, bio, website, sort_order)
select id, 'George Hruza', 'State Representative — District 89', 'Republican', 'Two-year term (since Jan 2025)',
       'State Representative for District 89, which includes parts of Des Peres, Town and Country, and Chesterfield.',
       'https://house.mo.gov/MemberDetails.aspx?district=089', 0
from d;

insert into elections (district_id, name, election_date)
select id, 'General Election', date '2026-11-03'
from districts where short_name = 'House 89' and state = 'MO';

-- ---------------------------------------------------------------------------
-- District coverage for the new cities (verified mappings only)
--
-- TODO (verify before relying on these being complete):
--   * Town and Country's state SENATE district — redistricting moved it out
--     of District 24; the current district was not verifiable from research.
--   * Whether additional House districts cover parts of Town and Country.
--   * Whether additional House/Senate districts cover parts of Overland.
-- ---------------------------------------------------------------------------
insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, v.partial
from (values
  ('Town and Country', 'MO-2',      false),
  ('Town and Country', 'House 89',  true),
  ('Overland',         'MO-1',      false),
  ('Overland',         'Senate 14', false),
  ('Overland',         'House 71',  true)
) as v(city, district, partial)
join jurisdictions j on j.name = v.city and j.state = 'MO'
join districts d on d.short_name = v.district and d.state = 'MO';
