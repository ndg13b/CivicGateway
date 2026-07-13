-- Migration 002: Seed the districts covering the three current cities.
-- Run AFTER migrations/001-districts.sql.
--
-- Officeholders verified July 2026 via official legislature/Congress pages
-- and Ballotpedia (sources listed in EXPANSION-PLAN.md). District→city
-- coverage is drawn from official district descriptions; entries flagged
-- partial=true mean the district covers only part of that city.
-- IMPORTANT: verify the fine-grained boundary details against the official
-- maps (links in EXPANSION-PLAN.md) before adding more cities.

-- ---------------------------------------------------------------------------
-- Districts + their current officeholders
-- ---------------------------------------------------------------------------

with d as (
  insert into districts (level, name, short_name, state, info_url, sort_order)
  values ('us_house', 'Missouri''s 1st Congressional District', 'MO-1', 'MO',
          'https://bell.house.gov/', 0)
  returning id
)
insert into officials (district_id, name, office, party, term, bio, website, sort_order)
select id, 'Wesley Bell', 'U.S. Representative — MO-1', 'Democratic', 'Two-year term (since Jan 2025)',
       'U.S. Representative for Missouri''s 1st Congressional District, which includes all of St. Louis City and much of northern St. Louis County. Former St. Louis County Prosecuting Attorney.',
       'https://bell.house.gov/', 0
from d;

with d as (
  insert into districts (level, name, short_name, state, info_url, sort_order)
  values ('us_house', 'Missouri''s 2nd Congressional District', 'MO-2', 'MO',
          'https://wagner.house.gov/', 1)
  returning id
)
insert into officials (district_id, name, office, party, term, bio, website, sort_order)
select id, 'Ann Wagner', 'U.S. Representative — MO-2', 'Republican', 'Two-year term (serving since 2013)',
       'U.S. Representative for Missouri''s 2nd Congressional District, covering much of western and southern St. Louis County.',
       'https://wagner.house.gov/', 0
from d;

with d as (
  insert into districts (level, name, short_name, state, info_url, sort_order)
  values ('state_senate', 'Missouri Senate District 24', 'Senate 24', 'MO',
          'https://www.senate.mo.gov/Senators/Member/24', 10)
  returning id
)
insert into officials (district_id, name, office, party, term, bio, website, sort_order)
select id, 'Tracy McCreery', 'State Senator — District 24', 'Democratic', 'Four-year term (since 2023)',
       'State Senator for the 24th District in central St. Louis County, which includes Maryland Heights, Creve Coeur, Kirkwood, and Des Peres.',
       'https://www.senate.mo.gov/Senators/Member/24', 0
from d;

with d as (
  insert into districts (level, name, short_name, state, info_url, sort_order)
  values ('state_senate', 'Missouri Senate District 14', 'Senate 14', 'MO',
          'https://www.senate.mo.gov/Senators/Member/14', 11)
  returning id
)
insert into officials (district_id, name, office, party, term, bio, website, sort_order)
select id, 'Brian Williams', 'State Senator — District 14', 'Democratic', 'Four-year term (since 2019)',
       'State Senator for the 14th District in northern St. Louis County, which includes Bridgeton, St. Ann, Hazelwood, and parts of Maryland Heights.',
       'https://www.senate.mo.gov/Senators/Member/14', 0
from d;

with d as (
  insert into districts (level, name, short_name, state, info_url, sort_order)
  values ('state_house', 'Missouri House District 70', 'House 70', 'MO',
          'https://house.mo.gov/MemberDetails.aspx?district=070', 20)
  returning id
)
insert into officials (district_id, name, office, party, term, bio, website, sort_order)
select id, 'Stephanie Boykin', 'State Representative — District 70', 'Democratic', 'Two-year term (since Jan 2025)',
       'State Representative for District 70, which includes Bridgeton, Hazelwood, and part of Maryland Heights. Retired U.S. Air Force lieutenant colonel and certified teacher.',
       'https://house.mo.gov/MemberDetails.aspx?district=070', 0
from d;

with d as (
  insert into districts (level, name, short_name, state, info_url, sort_order)
  values ('state_house', 'Missouri House District 71', 'House 71', 'MO',
          'https://house.mo.gov/MemberDetails.aspx?district=071', 21)
  returning id
)
insert into officials (district_id, name, office, party, term, bio, website, sort_order)
select id, 'LaDonna Appelbaum', 'State Representative — District 71', 'Democratic', 'Two-year term',
       'State Representative for District 71, which includes portions of Creve Coeur, Maryland Heights, Chesterfield, Olivette, Overland, and unincorporated St. Louis County.',
       'https://house.mo.gov/MemberDetails.aspx?district=071', 0
from d;

with d as (
  insert into districts (level, name, short_name, state, info_url, sort_order)
  values ('state_house', 'Missouri House District 87', 'House 87', 'MO',
          'https://house.mo.gov/MemberDetails.aspx?district=087', 22)
  returning id
)
insert into officials (district_id, name, office, party, term, bio, website, sort_order)
select id, 'Connie Steinmetz', 'State Representative — District 87', 'Democratic', 'Two-year term (since Jan 2025)',
       'State Representative for District 87, which includes the Westport area of Maryland Heights, Creve Coeur Park, and nearby unincorporated St. Louis County. Taught for nearly 40 years in the Clayton and Hazelwood school districts.',
       'https://house.mo.gov/MemberDetails.aspx?district=087', 0
from d;

-- ---------------------------------------------------------------------------
-- District → city coverage
-- partial = true means the district covers only part of the city, so a
-- resident's actual representative depends on their address.
-- ---------------------------------------------------------------------------

insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, v.partial
from (values
  -- Maryland Heights: MO-1; split between Senate 24/14; split among House 70/71/87
  ('Maryland Heights', 'MO-1',      false),
  ('Maryland Heights', 'Senate 24', true),
  ('Maryland Heights', 'Senate 14', true),
  ('Maryland Heights', 'House 70',  true),
  ('Maryland Heights', 'House 71',  true),
  ('Maryland Heights', 'House 87',  true),
  -- Creve Coeur: split between MO-1 and MO-2; Senate 24; House 71 (part)
  ('Creve Coeur', 'MO-1',      true),
  ('Creve Coeur', 'MO-2',      true),
  ('Creve Coeur', 'Senate 24', false),
  ('Creve Coeur', 'House 71',  true),
  -- Bridgeton: MO-1; Senate 14; House 70
  ('Bridgeton', 'MO-1',      false),
  ('Bridgeton', 'Senate 14', false),
  ('Bridgeton', 'House 70',  false)
) as v(city, district, partial)
join jurisdictions j on j.name = v.city and j.state = 'MO'
join districts d on d.short_name = v.district and d.state = 'MO';

-- ---------------------------------------------------------------------------
-- Upcoming district elections: the November 3, 2026 general election.
-- Party nominees are decided in the August 4, 2026 primary; add races +
-- candidates once nominees are certified (see EXPANSION-PLAN.md).
-- ---------------------------------------------------------------------------

insert into elections (district_id, name, election_date)
select d.id, 'General Election', date '2026-11-03'
from districts d
where d.short_name in ('MO-1', 'MO-2', 'Senate 24', 'House 70', 'House 71', 'House 87')
  and d.state = 'MO';
