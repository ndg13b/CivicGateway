-- Migration 007: contests certified for November 3, 2026
--
-- SOURCE: "Certification of Candidates and Party Emblems", Denny Hoskins,
-- Missouri Secretary of State, certified 25 August 2026.
--   https://www.sos.mo.gov/CMSImages/ElectionCandidates/2026GeneralElectionCertifiedCandidates.pdf
--
-- Every name below is transcribed from that document. Nothing here comes from
-- news coverage or a search result.
--
-- Run AFTER 006-post-certification.sql.
--
-- STILL NOT COVERED by this migration, because the SoS booklet does not
-- contain them — they only appear on the county's sample ballot:
--   * St. Louis County offices (County Executive is known to be on the ballot)
--   * Any county or municipal ballot measures
--   * Any constitutional amendments referred to November
-- See EXPANSION-PLAN.md §7.

-- ---------------------------------------------------------------------------
-- Candidate order
--
-- The certification states it lists "the order in which the candidates' names
-- are to appear on the ballot", and it groups candidates by party emblem in
-- the order Republican, Democratic, Libertarian, Independent. We follow that
-- order everywhere rather than leading with incumbents or with one party,
-- which is both more defensible and less work to justify.
--
-- Migration 005 predates this and ordered MO-1 with the Democrat first and
-- MO-2 with the Republican first — inconsistent with each other and with the
-- certified order. Normalised below.
-- ---------------------------------------------------------------------------

update candidates c
   set sort_order = case lower(coalesce(c.party, ''))
                      when 'republican'  then 0
                      when 'democratic'  then 1
                      when 'libertarian' then 2
                      else 3
                    end
  from races r
  join elections e on e.id = r.election_id
 where c.race_id = r.id
   and e.election_date = date '2026-11-03';

-- ---------------------------------------------------------------------------
-- Missouri Senate District 24 — Maryland Heights, Creve Coeur
-- R: LaVanna Wrobley   D: Tracy McCreery (incumbent)
-- ---------------------------------------------------------------------------
with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'State Senator — District 24', 'office', 1,
         'Represents the 24th District in the Missouri Senate. Four-year term.', 0
  from elections e
  join districts d on d.id = e.district_id
  where d.short_name = 'Senate 24' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, bio, website, sort_order)
select r.id, v.name, v.party, v.incumbent, v.bio, v.website, v.sort_order
from r, (values
  ('LaVanna Wrobley', 'Republican', false, null, null, 0),
  ('Tracy McCreery',  'Democratic', true,
   'State Senator for the 24th District since 2023. Previously served in the Missouri House.',
   'https://www.senate.mo.gov/Senators/Member/24', 1)
) as v(name, party, incumbent, bio, website, sort_order);

-- ---------------------------------------------------------------------------
-- Missouri Senate District 14 — Bridgeton, Overland, part of Maryland Heights
-- R: Vernon Norman   D: Raychel Proudie
--
-- OPEN SEAT: the sitting senator (Brian Williams) is not among the certified
-- nominees. ⚠ Confirm why — term limit or retirement — before describing the
-- seat as open on the site. Neither candidate is marked incumbent.
--
-- Migration 002 left Senate 14 without a November election row, because it was
-- unclear whether the seat was on the 2026 cycle at all. The certified list
-- settles it: both parties nominated. Create the missing election first, or
-- the race insert below silently matches nothing and the contest never
-- appears — which is how a scope goes quietly missing from a ballot.
-- ---------------------------------------------------------------------------
insert into elections (district_id, name, election_date)
select d.id, 'General Election', date '2026-11-03'
from districts d
where d.short_name = 'Senate 14' and d.state = 'MO'
  and not exists (
    select 1 from elections e
    where e.district_id = d.id and e.election_date = date '2026-11-03');

with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'State Senator — District 14', 'office', 1,
         'Represents the 14th District in the Missouri Senate. Four-year term.', 0
  from elections e
  join districts d on d.id = e.district_id
  where d.short_name = 'Senate 14' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, sort_order)
select r.id, v.name, v.party, false, v.sort_order
from r, (values
  ('Vernon Norman',   'Republican', 0),
  ('Raychel Proudie', 'Democratic', 1)
) as v(name, party, sort_order);

-- ---------------------------------------------------------------------------
-- Missouri House District 87 — Westport area of Maryland Heights
-- R: Dan Hyatt   D: Connie Steinmetz (incumbent)
--
-- This contest was missing entirely: migration 005 listed District 87 as
-- unverified, so Maryland Heights voters in it saw no state house contest.
-- ---------------------------------------------------------------------------
with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'State Representative — District 87', 'office', 1,
         'Represents the 87th District in the Missouri House. Two-year term.', 0
  from elections e
  join districts d on d.id = e.district_id
  where d.short_name = 'House 87' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, bio, website, sort_order)
select r.id, v.name, v.party, v.incumbent, v.bio, v.website, v.sort_order
from r, (values
  ('Dan Hyatt',        'Republican', false, null, null, 0),
  ('Connie Steinmetz', 'Democratic', true,
   'State Representative for the 87th District.',
   'https://house.mo.gov/MemberDetails.aspx?district=087', 1)
) as v(name, party, incumbent, bio, website, sort_order);

-- ---------------------------------------------------------------------------
-- Missouri House District 89 — part of Town and Country
-- R: George Hruza (incumbent)   D: Bryan Troop
-- ---------------------------------------------------------------------------
with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'State Representative — District 89', 'office', 1,
         'Represents the 89th District in the Missouri House. Two-year term.', 0
  from elections e
  join districts d on d.id = e.district_id
  where d.short_name = 'House 89' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, bio, website, sort_order)
select r.id, v.name, v.party, v.incumbent, v.bio, v.website, v.sort_order
from r, (values
  ('George Hruza', 'Republican', true,
   'State Representative for the 89th District.',
   'https://house.mo.gov/MemberDetails.aspx?district=089', 0),
  ('Bryan Troop',  'Democratic', false, null, null, 1)
) as v(name, party, incumbent, bio, website, sort_order);

-- ---------------------------------------------------------------------------
-- St. Louis County — scope only, no contests yet
--
-- County Executive is on the November 3 ballot, but the county's offices are
-- not in the Secretary of State's booklet and have not been transcribed from
-- a sample ballot yet.
--
-- Create the scope and its election anyway, with no races. buildBallot()
-- treats a scope that has an election but no races as "pending" and the page
-- says so: "More contests are expected on this ballot… we haven't listed the
-- County contests yet." Without this row the ballot would look complete while
-- silently missing the county, which is the worse failure by far — a voter
-- would have no reason to suspect anything was absent.
--
-- Delete nothing when the county contests are added; just insert races
-- against this election and the notice disappears on its own.
-- ---------------------------------------------------------------------------
insert into districts (level, name, short_name, state, info_url, sort_order)
values ('county', 'St. Louis County', 'St. Louis County', 'MO',
        'https://stlouiscountymo.gov/st-louis-county-government/board-of-elections/', 8);

insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, false
from jurisdictions j
cross join districts d
where d.short_name = 'St. Louis County' and d.state = 'MO'
  and j.state = 'MO' and j.county = 'St. Louis County';

insert into elections (district_id, name, election_date)
select id, 'General Election', date '2026-11-03'
from districts where short_name = 'St. Louis County' and state = 'MO';

-- ---------------------------------------------------------------------------
-- Judicial retention
--
-- Missouri's non-partisan court plan puts appellate and (in St. Louis County)
-- circuit judges on the ballot as yes/no retention questions rather than as
-- contests between candidates. These are modelled as kind = 'measure'.
--
-- Names are from the "Certificate of Judicial Candidates, Article V, Section
-- 25(c)" pages of the same certified booklet.
--
-- Three scopes, all covering every city we serve:
--   * Missouri Supreme Court            — statewide
--   * Court of Appeals, Eastern District — includes St. Louis County
--   * 21st Judicial Circuit             — is St. Louis County
--
-- ⚠ CONFIRM against a county sample ballot before publishing:
--   1. That the 21st Circuit still corresponds to St. Louis County. The
--      circuit was reorganised in recent years and this matters for all
--      fifteen local questions.
--   2. The exact printed wording. The text below is the standard statutory
--      form; if the county prints it differently, official_text must match
--      the county, since that is the wording a voter sees.
-- ---------------------------------------------------------------------------

insert into districts (level, name, short_name, state, info_url, sort_order) values
  ('judicial', 'Supreme Court of Missouri', 'MO Supreme Court', 'MO',
   'https://www.courts.mo.gov/page.jsp?id=27', 10),
  ('judicial', 'Missouri Court of Appeals, Eastern District', 'Appeals East', 'MO',
   'https://www.courts.mo.gov/page.jsp?id=525', 11),
  ('judicial', '21st Judicial Circuit', 'Circuit 21', 'MO',
   'https://www.stlcountycourts.com/', 12);

-- Judicial scopes are not 'statewide' level, so they need explicit links.
-- Every city we cover is in St. Louis County, so all three apply in full.
insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, false
from jurisdictions j
cross join districts d
where d.short_name in ('MO Supreme Court', 'Appeals East', 'Circuit 21')
  and d.state = 'MO'
  and j.state = 'MO';

insert into elections (district_id, name, election_date)
select id, 'General Election', date '2026-11-03'
from districts
where short_name in ('MO Supreme Court', 'Appeals East', 'Circuit 21')
  and state = 'MO';

-- One retention question per judge. sort_order follows the certified listing.
insert into races (election_id, title, kind, vote_for, official_text, description, sort_order)
select e.id,
       'Retention — ' || v.judge,
       'measure',
       1,
       'Shall Judge ' || v.judge || ' of the ' || v.court || ' be retained in office?',
       'A yes-or-no question on keeping a sitting judge in office. Judges here '
       || 'are not elected against an opponent; voters decide only whether each '
       || 'one stays on the bench.',
       v.sort_order
from elections e
join districts d on d.id = e.district_id
join (values
  -- Supreme Court
  ('MO Supreme Court', 'Paul C. Wilson',              'Supreme Court of Missouri', 0),
  -- Court of Appeals, Eastern District
  ('Appeals East', 'Virginia W. Lay',                 'Missouri Court of Appeals, Eastern District', 0),
  ('Appeals East', 'Rebeca Navarro-McKelvey',         'Missouri Court of Appeals, Eastern District', 1),
  ('Appeals East', 'Angela Turner Quigless',          'Missouri Court of Appeals, Eastern District', 2),
  -- 21st Circuit — Circuit Judges
  ('Circuit 21', 'Richard M. Stewart',                '21st Judicial Circuit, Division 2',  0),
  ('Circuit 21', 'John Borbonus',                     '21st Judicial Circuit, Division 6',  1),
  ('Circuit 21', 'Mary Elizabeth Ott',                '21st Judicial Circuit, Division 7',  2),
  ('Circuit 21', 'Amanda B. McNelley',                '21st Judicial Circuit, Division 8',  3),
  ('Circuit 21', 'Jeffery McPherson',                 '21st Judicial Circuit, Division 16', 4),
  ('Circuit 21', 'Lorne Baker',                       '21st Judicial Circuit, Division 17', 5),
  ('Circuit 21', 'Matt Hearne',                       '21st Judicial Circuit, Division 20', 6),
  ('Circuit 21', 'Ellen Wyatt Dunne',                 '21st Judicial Circuit, Division 21', 7),
  -- 21st Circuit — Associate Circuit Judges
  ('Circuit 21', 'Julia Pusateri Lasater',            '21st Judicial Circuit, Division 32', 8),
  ('Circuit 21', 'Nicolette Antonia Klapp',           '21st Judicial Circuit, Division 33', 9),
  ('Circuit 21', 'Justin W. Ruth',                    '21st Judicial Circuit, Division 34', 10),
  ('Circuit 21', 'Jason K. Lewis',                    '21st Judicial Circuit, Division 35', 11),
  ('Circuit 21', 'Kelly Snyder',                      '21st Judicial Circuit, Division 39', 12),
  ('Circuit 21', 'Mondonna L. Ghasedi',               '21st Judicial Circuit, Division 43', 13),
  ('Circuit 21', 'Chastidy Dillon-Amelung',           '21st Judicial Circuit, Division 44', 14)
) as v(scope, judge, court, sort_order) on v.scope = d.short_name
where e.election_date = date '2026-11-03' and d.state = 'MO';

-- ---------------------------------------------------------------------------
-- Verification
--
-- Every insert above is "insert … select … join", which inserts zero rows and
-- reports success when the scope it joins to is missing. That is exactly how
-- Senate 14 went missing from this migration on the first pass. Fail loudly
-- instead: if a contest did not land, this aborts the whole transaction.
-- ---------------------------------------------------------------------------
do $$
declare
  expected text[] := array[
    'State Senator — District 24',
    'State Senator — District 14',
    'State Representative — District 87',
    'State Representative — District 89'
  ];
  missing text;
  judicial_count int;
begin
  foreach missing in array expected loop
    if not exists (
      select 1 from races r
      join elections e on e.id = r.election_id
      where r.title = missing and e.election_date = date '2026-11-03'
    ) then
      raise exception 'Migration 007: contest "%" was not created — its district or election row is missing.', missing;
    end if;
  end loop;

  select count(*) into judicial_count
  from races r
  join elections e on e.id = r.election_id
  join districts d on d.id = e.district_id
  where d.level = 'judicial' and e.election_date = date '2026-11-03';

  if judicial_count <> 19 then
    raise exception 'Migration 007: expected 19 judicial retention questions, found %.', judicial_count;
  end if;
end $$;
