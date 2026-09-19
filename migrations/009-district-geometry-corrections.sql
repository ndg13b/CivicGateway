-- Migration 009: district mappings corrected against actual boundary geometry
--
-- Migration 008 could only add, because it was based on point sampling and
-- sampling cannot prove a district is absent from a city. With
-- tigerweb.geo.census.gov now reachable, the real polygons were fetched and
-- intersected with each city's polygon, so absence IS provable. This
-- migration therefore removes as well as adds.
--
-- METHOD: every Missouri district polygon from TIGERweb's Legislative service
-- and every city polygon from its Places service, intersected locally with
-- Shapely. Figures below are percent of the city's area.
--
--   Maryland Heights   Senate 24 100%   House 87 100%   CD2 86.9% · CD3 13.1%
--   Creve Coeur        Senate 24 100%   House 71 100%   CD2 100%
--   Bridgeton          Senate 14 100%   House 70 100%   CD1 100%
--   Overland           Senate 14 100%   House 72 99.99% CD1 100%
--   Town and Country   Senate 15 99.99% House 89 99.98% CD2 100%
--
-- Overlaps below 0.1% are boundary-precision noise and are ignored.
--
-- ---------------------------------------------------------------------------
-- THE CONGRESSIONAL LAYER MATTERS MOST
--
-- Congressional figures come from TIGERweb layer 0, "120th Congressional
-- Districts; January 1, 2026 vintage" — the districts being elected on
-- November 3, 2026. The 119th layer is the map the sitting Congress was
-- elected under in 2024 and does NOT apply to this ballot.
--
-- The two differ, and both differ from our data:
--
--                       our data     119th (2024)          120th (Nov 2026)
--   Maryland Heights    MO-1 100%    CD1 32.7% CD2 67.3%   CD2 86.9% CD3 13.1%
--   Creve Coeur         MO-1 + MO-2  CD1 30.9% CD2 69.1%   CD2 100%
--
-- So Maryland Heights has been shown the 1st District contest, which its
-- residents cannot vote in under either map, while the contest they can vote
-- in was absent. EXPANSION-PLAN §1 said the mid-decade redraw touched only
-- districts 4, 5 and 6 around Kansas City. That was wrong: the St. Louis
-- lines moved substantially.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. MO-2 is missing a certified candidate
--
-- Migration 005 entered Wagner and Wellman only. The certified booklet also
-- lists a Libertarian. Omitting a minor-party candidate from a race is the
-- single worst error a nonpartisan guide can make, so this is the first fix.
-- ---------------------------------------------------------------------------
insert into candidates (race_id, name, party, incumbent, sort_order)
select r.id, 'Brandon Coulter Daugherty', 'Libertarian', false, 2
from races r
join elections e on e.id = r.election_id
join districts d on d.id = e.district_id
where d.short_name = 'MO-2' and d.state = 'MO'
  and e.election_date = date '2026-11-03'
  and not exists (select 1 from candidates c
                  where c.race_id = r.id and c.name = 'Brandon Coulter Daugherty');

-- ---------------------------------------------------------------------------
-- 2. MO-3 — new scope. 13.1% of Maryland Heights is in it under the 2026 map.
-- Certified: R Bob Onder · D Bethany E Mann · L Jim Higgins
-- ---------------------------------------------------------------------------
insert into districts (level, name, short_name, state, info_url, sort_order)
values ('us_house', 'Missouri''s 3rd Congressional District', 'MO-3', 'MO',
        'https://www.house.gov/representatives', 2);

insert into elections (district_id, name, election_date)
select id, 'General Election', date '2026-11-03'
from districts where short_name = 'MO-3' and state = 'MO';

with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'U.S. Representative — District 3', 'office', 1,
         'Represents Missouri''s 3rd Congressional District in the U.S. House. Two-year term.', 0
  from elections e
  join districts d on d.id = e.district_id
  where d.short_name = 'MO-3' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, sort_order)
select r.id, v.name, v.party, false, v.sort_order
from r, (values
  ('Bob Onder',       'Republican',  0),
  ('Bethany E Mann',  'Democratic',  1),
  ('Jim Higgins',     'Libertarian', 2)
) as v(name, party, sort_order);

-- ---------------------------------------------------------------------------
-- 3. Remove mappings the geometry disproves
--
-- Each of these is a contest a city's residents cannot vote in. Maryland
-- Heights alone carried four.
-- ---------------------------------------------------------------------------
delete from jurisdiction_districts jd
 using jurisdictions j, districts d
 where jd.jurisdiction_id = j.id and jd.district_id = d.id and j.state = 'MO'
   and ( (j.name = 'Maryland Heights'
          and d.short_name in ('MO-1', 'Senate 14', 'House 70', 'House 71'))
      or (j.name = 'Creve Coeur' and d.short_name = 'MO-1')
      or (j.name = 'Overland'    and d.short_name = 'House 71') );

-- ---------------------------------------------------------------------------
-- 4. Add the congressional mappings the geometry proves
-- ---------------------------------------------------------------------------
insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, v.partial
from (values
  ('Maryland Heights', 'MO-2', true),   -- 86.9% of the city
  ('Maryland Heights', 'MO-3', true)    -- 13.1% of the city
) as v(city, short_name, partial)
join jurisdictions j on j.name = v.city and j.state = 'MO'
join districts d on d.short_name = v.short_name and d.state = 'MO'
where not exists (select 1 from jurisdiction_districts x
                  where x.jurisdiction_id = j.id and x.district_id = d.id);

-- ---------------------------------------------------------------------------
-- 5. Correct the partial flags
--
-- `partial` drives the "if you live in…" note. A city wholly inside one
-- district should not carry that warning — it makes a certain answer look
-- uncertain, which is its own kind of wrong.
-- ---------------------------------------------------------------------------
update jurisdiction_districts jd
   set partial = v.partial
  from jurisdictions j, districts d, (values
  ('Maryland Heights', 'Senate 24', false),
  ('Maryland Heights', 'House 87',  false),
  ('Creve Coeur',      'MO-2',      false),
  ('Creve Coeur',      'House 71',  false),
  ('Town and Country', 'House 89',  false)
) as v(city, short_name, partial)
 where jd.jurisdiction_id = j.id and jd.district_id = d.id
   and j.name = v.city and j.state = 'MO'
   and d.short_name = v.short_name and d.state = 'MO'
   and jd.partial is distinct from v.partial;

-- ---------------------------------------------------------------------------
-- Verification — the whole point of this migration is which contests each
-- city shows, so assert that directly.
-- ---------------------------------------------------------------------------
do $$
declare got text; want text;
begin
  for want, got in
    select w.expected,
           (select string_agg(d.short_name, ', ' order by d.short_name)
              from jurisdiction_districts jd
              join districts d on d.id = jd.district_id
             where jd.jurisdiction_id = j.id
               and d.level in ('us_house','state_senate','state_house'))
    from (values
      ('Maryland Heights', 'House 87, MO-2, MO-3, Senate 24'),
      ('Creve Coeur',      'House 71, MO-2, Senate 24'),
      ('Bridgeton',        'House 70, MO-1, Senate 14'),
      ('Overland',         'House 72, MO-1, Senate 14'),
      ('Town and Country', 'House 89, MO-2, Senate 15')
    ) as w(city, expected)
    join jurisdictions j on j.name = w.city and j.state = 'MO'
  loop
    if got is distinct from want then
      raise exception 'Migration 009: mapping mismatch. expected [%], got [%]', want, got;
    end if;
  end loop;

  if not exists (select 1 from candidates c
                 join races r on r.id = c.race_id
                 join elections e on e.id = r.election_id
                 join districts d on d.id = e.district_id
                 where d.short_name = 'MO-2' and c.party = 'Libertarian'
                   and e.election_date = date '2026-11-03') then
    raise exception 'Migration 009: MO-2 Libertarian candidate missing.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Officeholders for the newly-mapped scopes
--
-- Removing a wrong mapping also removes whoever was attached to it, so
-- Overland lost a state representative it never actually had (LaDonna
-- Appelbaum, House 71) and gained House 72, which had nobody. Its sitting
-- representative is Doug Clemens, per house.mo.gov/MemberDetails.aspx?district=072.
--
-- Note he is NOT among the certified candidates for District 72 — the seat is
-- open, which is consistent with a term limit. So Overland's page will show
-- Clemens under "who represents you now" and two new names on the ballot,
-- which is correct and is exactly the distinction the two sections exist for.
-- ---------------------------------------------------------------------------
insert into officials (district_id, name, office, party, website, sort_order)
select d.id, 'Doug Clemens', 'State Representative — District 72', 'Democratic',
       'https://house.mo.gov/MemberDetails.aspx?district=072', 0
from districts d
where d.short_name = 'House 72' and d.state = 'MO'
  and not exists (select 1 from officials o where o.district_id = d.id);

-- TODO — officeholders still missing, both blocked on a source:
--   * Senate 15 (Town and Country). Ballotpedia names David Gregory, but
--     senate.mo.gov/Senators/Member/15 404s, so it is unconfirmed and left out.
--   * MO-3 (13% of Maryland Heights). Its sitting representative has not been
--     entered; only the November contest is present.
-- Neither affects the ballot — both are "who represents you now" gaps.

-- ---------------------------------------------------------------------------
-- KNOWN CONSEQUENCE, recorded deliberately
--
-- One mapping now serves two different questions: what is on your ballot
-- (120th Congress map) and who represents you today (119th). They diverge for
-- Maryland Heights and Creve Coeur, both of which are roughly a third in the
-- current 1st District. Dropping MO-1 fixes the ballot and costs those two
-- cities Wesley Bell under "who represents you now".
--
-- The ballot is the reason this site exists and voting opens in days, so the
-- ballot wins. The proper fix is to date-scope jurisdiction_districts so a
-- mapping can apply to one map and not the other — a schema change, not
-- something to attempt this week.
--
-- State legislative districts did NOT change between the two maps: the 2024
-- and 2026 layers agree for all five cities, so those removals are pure
-- corrections with no such trade-off.
-- ---------------------------------------------------------------------------
