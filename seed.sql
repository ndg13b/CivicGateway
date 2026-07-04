-- Civic Gateway — seed data for the 3 currently-live cities
-- Run this AFTER schema.sql, in the Supabase SQL editor.
-- Source: index.html BALLOT_DATA (verified from each city's official site, May 2026).
-- No elections are currently scheduled for any of these three, so only
-- jurisdictions + officials rows are needed for now.

-- ---------------------------------------------------------------------------
-- Maryland Heights, MO
-- ---------------------------------------------------------------------------
with j as (
  insert into jurisdictions (name, state, county, city_website, twitter, facebook, instagram, youtube, next_election_note)
  values (
    'Maryland Heights', 'MO', 'St. Louis County',
    'https://www.marylandheights.com/',
    'CityofMH', 'cityofmarylandheights', 'marylandheightsmo',
    'https://www.youtube.com/channel/UCIc7CM_0RP8TJSjRYHjZ19A',
    'The most recent municipal election was April 7, 2026. The next regular municipal election is expected April 2027, when one City Council seat in each ward is up. Candidate details will appear here once filing opens.'
  )
  returning id
)
insert into officials (jurisdiction_id, name, office, party, term, bio, email, phone, sort_order)
select id, v.name, v.office, v.party, v.term, v.bio, v.email, v.phone, v.sort_order
from j, (values
  ('Mike Moeller', 'Mayor', 'Nonpartisan', 'Four-year term', 'Mayor of Maryland Heights; presides over City Council meetings.', 'mmoeller@marylandheights.com', '314-878-6730', 0),
  ('Abigail Dannegger', 'City Council — Ward 1', 'Nonpartisan', 'Two-year term', null, 'adannegger@marylandheights.com', '314-619-2450', 1),
  ('Susan Taylor', 'City Council — Ward 1', 'Nonpartisan', 'Two-year term', null, 'staylor@marylandheights.com', '314-484-7627', 2),
  ('Howard Abrams', 'City Council — Ward 2', 'Nonpartisan', 'Two-year term', null, 'habrams@marylandheights.com', '314-432-0814', 3),
  ('Kim Baker', 'City Council — Ward 2', 'Nonpartisan', 'Two-year term', null, 'kbaker@marylandheights.com', '314-952-1702', 4),
  ('Chuck Caverly', 'City Council — Ward 3', 'Nonpartisan', 'Two-year term', null, 'ccaverly@marylandheights.com', '314-566-0424', 5),
  ('Nancy Medvick', 'City Council — Ward 3 (President Pro-Tem)', 'Nonpartisan', 'Two-year term', null, 'nmedvick@marylandheights.com', '314-703-8987', 6),
  ('Steve Borgmann', 'City Council — Ward 4', 'Nonpartisan', 'Two-year term', null, 'sborgmann@marylandheights.com', '314-393-9448', 7),
  ('Norm Rhea', 'City Council — Ward 4', 'Nonpartisan', 'Two-year term', null, 'nrhea@marylandheights.com', '314-739-0096', 8)
) as v(name, office, party, term, bio, email, phone, sort_order);

-- ---------------------------------------------------------------------------
-- Creve Coeur, MO
-- ---------------------------------------------------------------------------
with j as (
  insert into jurisdictions (name, state, county, city_website, next_election_note)
  values (
    'Creve Coeur', 'MO', 'St. Louis County',
    'https://crevecoeurmo.gov/',
    'Council members serve staggered two-year terms; the mayor serves a three-year term. Council seats in each ward come up at the regular April municipal election. Candidate details will appear here once filing opens.'
  )
  returning id
)
insert into officials (jurisdiction_id, name, office, party, bio, website, email, phone, term, sort_order)
select id, v.name, v.office, v.party, v.bio, v.website, v.email, v.phone, v.term, v.sort_order
from j, (values
  ('Robert Hoffman', 'Mayor', 'Nonpartisan', 'Mayor of Creve Coeur, elected April 2021 after serving on the City Council 2010–2021.', 'https://crevecoeurmo.gov/318/Mayor-Robert-Hoffman', 'mayor-council@crevecoeurmo.gov', '314-432-6000', 'Three-year term', 0),
  ('Mark Manlin', 'City Council — Ward 1', 'Nonpartisan', null, 'https://crevecoeurmo.gov/319/Mark-Manlin---Ward-1', 'mayor-council@crevecoeurmo.gov', '314-432-6000', null, 1),
  ('Donna Spence', 'City Council — Ward 1', 'Nonpartisan', null, 'https://crevecoeurmo.gov/320/Donna-Spence---Ward-1', 'mayor-council@crevecoeurmo.gov', '314-432-6000', null, 2),
  ('Nicole Greer', 'City Council — Ward 2', 'Nonpartisan', null, 'https://crevecoeurmo.gov/321/Nicole-Greer---Ward-2', 'mayor-council@crevecoeurmo.gov', '314-432-6000', null, 3),
  ('Kim Norwood', 'City Council — Ward 2', 'Nonpartisan', null, 'https://crevecoeurmo.gov/322/Kim-Norwood---Ward-2', 'mayor-council@crevecoeurmo.gov', '314-432-6000', null, 4),
  ('David Hoffman', 'City Council — Ward 3', 'Nonpartisan', null, 'https://crevecoeurmo.gov/324/David-Hoffman---Ward-3', 'mayor-council@crevecoeurmo.gov', '314-432-6000', null, 5),
  ('Drew Newman', 'City Council — Ward 3', 'Nonpartisan', null, 'https://crevecoeurmo.gov/323/Drew-Newman---Ward-3', 'mayor-council@crevecoeurmo.gov', '314-432-6000', null, 6),
  ('Mara Berry', 'City Council — Ward 4', 'Nonpartisan', null, 'https://crevecoeurmo.gov/325/Mara-Berry---Ward-4', 'mayor-council@crevecoeurmo.gov', '314-432-6000', null, 7),
  ('Scott Saunders', 'City Council — Ward 4', 'Nonpartisan', null, 'https://crevecoeurmo.gov/326/Scott-Saunders---Ward-4', 'mayor-council@crevecoeurmo.gov', '314-432-6000', null, 8)
) as v(name, office, party, bio, website, email, phone, term, sort_order);

-- ---------------------------------------------------------------------------
-- Bridgeton, MO
-- ---------------------------------------------------------------------------
with j as (
  insert into jurisdictions (name, state, county, city_website, next_election_note)
  values (
    'Bridgeton', 'MO', 'St. Louis County',
    'https://www.bridgetonmo.com/',
    'Each ward has two council members; one seat in each ward is elected every April. Candidate details will appear here once filing opens.'
  )
  returning id
)
insert into officials (jurisdiction_id, name, office, party, bio, email, phone, facebook, sort_order)
select id, v.name, v.office, v.party, v.bio, v.email, v.phone, v.facebook, v.sort_order
from j, (values
  ('Randy Hein', 'Mayor', 'Nonpartisan', 'Mayor of Bridgeton.', 'rhein@bridgetonmo.gov', '314-373-3811', 'p/Randy-Hein-Mayor-of-Bridgeton-61556963852290', 0),
  ('Stephen Wesche', 'City Council — Ward 1', 'Nonpartisan', null, 'swesche@bridgetonmo.gov', '314-372-8010', null, 1),
  ('Robert Saettele', 'City Council — Ward 1', 'Nonpartisan', null, 'rsaettele@bridgetonmo.gov', '314-291-1131', null, 2),
  ('Bakula Patel', 'City Council — Ward 2', 'Nonpartisan', null, 'bpatel@bridgetonmo.gov', '314-344-5033', null, 3),
  ('Kathy Ioannou', 'City Council — Ward 2', 'Nonpartisan', null, 'kioannou@bridgetonmo.gov', '314-737-7878', null, 4),
  ('Kathy Luther', 'City Council — Ward 3', 'Nonpartisan', null, 'kluther@bridgetonmo.gov', '314-209-1715', null, 5),
  ('Gretchen Luke', 'City Council — Ward 3', 'Nonpartisan', null, 'gluke@bridgetonmo.gov', '314-292-9244', null, 6),
  ('Joni Norris', 'City Council — Ward 4', 'Nonpartisan', null, 'jnorris@bridgetonmo.gov', '314-291-8041', null, 7),
  ('Don Hood', 'City Council — Ward 4', 'Nonpartisan', null, 'dhood@bridgetonmo.gov', '314-716-3599', null, 8)
) as v(name, office, party, bio, email, phone, facebook, sort_order);
