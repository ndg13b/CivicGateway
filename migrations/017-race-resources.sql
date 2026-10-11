-- Migration 017: debates, forums and impartial information for race pages
--
-- Every contest and measure now has a page reachable from the ballot. This
-- fills the first round of links for those pages.
--
-- WHAT QUALIFIES (the same rule is printed on every race page):
--   * recordings and reports of debates and candidate forums
--   * nonpartisan election guides
--   * official documents
--   * straight news coverage
-- Left out: endorsements, opinion pieces, editorials, campaign material, and
-- advocacy groups on either side. Pages published by a government asking
-- voters to approve its own measure are allowed but labeled as such.
--
-- Every URL below came from a search result or a page read directly; none is
-- constructed from a pattern. Researched 11 October 2026.
--
-- WHAT WAS LOOKED FOR AND NOT FOUND
--   * No general-election debate has been held or scheduled for any office on
--     these ballots that we could find. In the 2nd District, Ann Wagner has
--     declined to debate; that claim comes from her opponent and an editorial,
--     so it is not stated on the page — the page just says no debate is known.
--   * The County Executive items are from before the August primary. Each one
--     says so, and says J D McFarland was not part of it, rather than being
--     left off: the two candidates who were in them are both on the November
--     ballot, and a voter is better served by the link plus the caveat.
--   * County Proposition A (Auditor's term) has no coverage anywhere yet.
--   * State House and Senate, County Council, Prosecutor and Assessor: no
--     forum or race-level coverage found. Those pages say so.

do $$
begin
  if exists (select 1 from resources where url = 'https://www.sos.mo.gov/petitions/2026ballotmeasures') then
    raise exception 'Migration 017 has already been applied.';
  end if;
end $$;

create temporary table r017 (
  key text primary key, kind text, title text, url text,
  source text, published_on date, note text
);

insert into r017 values
-- Statewide measures ---------------------------------------------------------
('sos', 'info',
 'Official ballot titles and fair ballot language for the 2026 statewide measures',
 'https://www.sos.mo.gov/petitions/2026ballotmeasures',
 'Missouri Secretary of State', null,
 'Fair ballot language is the state''s own plain-language statement of what a yes vote and a no vote would do.'),
('a3-bp', 'info',
 'Missouri Amendment 3 (2026)',
 'https://ballotpedia.org/Missouri_Amendment_3,_Prohibit_Abortion_and_Gender_Transition_Procedures_for_Minors_Amendment_(2026)',
 'Ballotpedia', null, null),
('a3-ky3', 'info',
 'Amendment 3 would restrict abortion in Missouri two years after voters approved constitutional protections',
 'https://www.ky3.com/2026/09/22/amendment-3-would-restrict-abortion-missouri-two-years-after-voters-approved-constitutional-protections/',
 'KY3', date '2026-09-22', null),
('a6-bp', 'info',
 'Missouri voters to decide amendment requiring voter approval for certain legislative changes to initiative process and voter-approved laws',
 'https://news.ballotpedia.org/2026/09/09/missouri-voters-to-decide-amendment-requiring-voter-approval-for-certain-legislative-changes-to-initiative-process-and-voter-approved-laws/',
 'Ballotpedia News', date '2026-09-09', null),
('a6-ky3', 'info',
 'Missourians to vote on whether to raise the threshold for lawmakers to change voter-approved laws',
 'https://www.ky3.com/2026/09/24/missourians-vote-whether-raise-threshold-lawmakers-change-voter-approved-laws/',
 'KY3', date '2026-09-24', null),
('a7-bp', 'info',
 'Missouri voters to decide amendment to establish Show-Me Prosperity Investment Fund to reduce and eliminate state taxes',
 'https://news.ballotpedia.org/2026/05/19/missouri-voters-to-decide-amendment-to-establish-show-me-prosperity-investment-fund-to-reduce-and-eliminate-state-taxes/',
 'Ballotpedia News', date '2026-05-19', null),
('a7-ky3', 'info',
 'Missouri voters to decide on fund aimed at eliminating state taxes',
 'https://www.ky3.com/2026/09/28/missouri-voters-decide-fund-aimed-eliminating-state-taxes/',
 'KY3', date '2026-09-28', null),
('a8-ky3', 'info',
 'Missouri voters to decide on constitutional status for sheriff''s office',
 'https://www.ky3.com/2026/09/29/missouri-voters-decide-constitutional-status-sheriffs-office/',
 'KY3', date '2026-09-29', null),
('a8-kctv', 'info',
 'Amendment 8: Missouri ballot measure would make removing sheriffs far more difficult',
 'https://www.kctv5.com/2026/09/30/missouri-ballot-measure-would-make-removing-sheriffs-far-harder/',
 'KCTV5', date '2026-09-30', null),
('pa-bp', 'info',
 'Missouri voters to decide congressional map referendum in November after court ruling',
 'https://news.ballotpedia.org/2026/09/09/missouri-voters-to-decide-congressional-map-referendum-in-november-after-court-ruling/',
 'Ballotpedia News', date '2026-09-09', null),
('pa-kcur', 'info',
 'Missouri Supreme Court puts referendum to overturn new congressional map on ballot',
 'https://www.kcur.org/politics-elections-and-government/2026-09-03/missouri-supreme-court-redistricting-referendum-congress-november-election',
 'KCUR', date '2026-09-03', null),
-- County and local measures --------------------------------------------------
('props-stlpr', 'info',
 'St. Louis County voters to weigh property tax increase for senior services',
 'https://www.stlpr.org/government-politics-issues/2026-10-05/st-louis-county-voters-to-weigh-property-tax-increase-for-senior-services',
 'St. Louis Public Radio', date '2026-10-05', null),
('propg-west', 'info',
 'Creve Coeur Government Center proposition renamed to Prop G',
 'https://www.westnewsmagazine.com/news/creve-coeur-government-center-proposition-renamed-to-prop-g/article_4ab9f235-ba3b-4362-baba-9890de0d39fa.html',
 'West Newsmagazine', null, null),
('propp-district', 'info',
 'Proposition P: information from the Parkway School District',
 'https://www.parkwayschools.net/about-parkway/proposition-p-2026',
 'Parkway School District', null,
 'Published by the school district asking voters to approve the measure.'),
('propp-kmov', 'info',
 'Parkway School District proposes tax hike: What it would mean for your wallet',
 'https://www.firstalert4.com/2026/08/12/parkway-school-district-tax-hike-what-it-means-your-wallet/',
 'KMOV', date '2026-08-12', null),
('propp-west', 'info',
 'Parkway puts tax proposal on Nov. 3 ballot',
 'https://www.westnewsmagazine.com/news/parkway-puts-tax-proposal-on-nov-3-ballot/article_2e4e962f-cc13-4ed2-a533-62888b696c39.html',
 'West Newsmagazine', null, null),
('ritenour-faq', 'info',
 'Frequently asked questions about Propositions I and N',
 'https://www.ritenourschools.org/about-us/allin/faq-about-propositions-i-n',
 'Ritenour School District', null,
 'Published by the school district asking voters to approve the measures.'),
-- Judicial retention ---------------------------------------------------------
('jpr', 'info',
 'Judicial Performance Review findings for the judges on the ballot',
 'https://yourmissourijudges.org/',
 'Missouri Judicial Performance Review Committee', null,
 'A committee of lawyers, non-lawyers and retired judges reviews every judge up for retention and publishes whether each one meets the performance standards.'),
-- Office races ---------------------------------------------------------------
('ce-ninepbs', 'debate',
 'Race for County Executive: The St. Louis Citizens'' Agenda',
 'https://www.pbs.org/video/race-for-county-executive-the-st-louis-citizens-agenda-5uon9x/',
 'Nine PBS and St. Louis Magazine', null,
 'An hour-long special in which each candidate answers the same five issues residents raised. Recorded before the August 4 primary, so it includes Dennis Hancock and Jake Zimmerman; J D McFarland was not part of it.'),
('ce-west-forum', 'debate',
 'County executive candidates offer competing visions for St. Louis County at forum',
 'https://www.westnewsmagazine.com/news/county-executive-candidates-offer-competing-visions-for-st-louis-county-at-forum/article_be3fc4f4-7704-4f03-a05a-ab9e8b70b475.html',
 'West Newsmagazine', null,
 'A report on a forum held before the August 4 primary. Dennis Hancock and Jake Zimmerman took part; J D McFarland was not part of it.'),
('ce-stlmag', 'info',
 'County Executive Citizens'' Agenda',
 'https://www.stlmag.com/topics/county-executive-citizens-agenda/',
 'St. Louis Magazine', null,
 'Written coverage from the Citizens'' Agenda project, issue by issue. From before the primary: covers Dennis Hancock and Jake Zimmerman; J D McFarland was not part of it.'),
('ce-call', 'info',
 'Five candidates from three parties vie for St. Louis County Executive seat',
 'https://callnewspapers.com/five-candidates-from-three-parties-vie-for-st-louis-county-executive-seat/',
 'Call Newspapers', null,
 'Profiles the whole field before the August primary, including J D McFarland, who did not respond to the paper''s interview request.'),
('mo2-bp', 'info',
 'Missouri''s 2nd Congressional District election, 2026',
 'https://ballotpedia.org/Missouri%27s_2nd_Congressional_District_election,_2026',
 'Ballotpedia', null, null),
('aud-kcur', 'info',
 'Missouri voters choose contenders for state auditor race in November',
 'https://www.kcur.org/2026-08-04/missouri-voters-choses-contenders-for-state-auditor-race-in-november',
 'KCUR', date '2026-08-04', null);

-- Where each one appears. Order within a page: official first, then
-- nonpartisan references, then news.
create temporary table l017 (key text, race_title text, sort_order int);
insert into l017 values
('sos', 'Constitutional Amendment 3', 0), ('a3-bp', 'Constitutional Amendment 3', 1), ('a3-ky3', 'Constitutional Amendment 3', 2),
('sos', 'Constitutional Amendment 6', 0), ('a6-bp', 'Constitutional Amendment 6', 1), ('a6-ky3', 'Constitutional Amendment 6', 2),
('sos', 'Constitutional Amendment 7', 0), ('a7-bp', 'Constitutional Amendment 7', 1), ('a7-ky3', 'Constitutional Amendment 7', 2),
('sos', 'Constitutional Amendment 8', 0), ('a8-ky3', 'Constitutional Amendment 8', 2), ('a8-kctv', 'Constitutional Amendment 8', 3),
('sos', 'Proposition A — congressional map referendum', 0),
('pa-bp', 'Proposition A — congressional map referendum', 1),
('pa-kcur', 'Proposition A — congressional map referendum', 2),
('props-stlpr', 'County Proposition S — senior services levy', 2),
('propg-west', 'Proposition G — Government Center bonds', 2),
('propp-district', 'Parkway Proposition P — operating levy', 0),
('propp-kmov', 'Parkway Proposition P — operating levy', 2),
('propp-west', 'Parkway Proposition P — operating levy', 3),
('ritenour-faq', 'Ritenour Proposition I — building bonds', 0),
('ritenour-faq', 'Ritenour Proposition N — operating levy', 0),
('ce-ninepbs', 'County Executive', 0),
('ce-west-forum', 'County Executive', 1),
('ce-stlmag', 'County Executive', 2),
('ce-call', 'County Executive', 3),
('mo2-bp', 'U.S. Representative — District 2', 1),
('aud-kcur', 'State Auditor', 2);

insert into resources (kind, title, url, source, published_on, note, sort_order)
select kind, title, url, source, published_on, note, 0 from r017;

insert into resource_links (resource_id, race_id, sort_order)
select res.id, r.id, l.sort_order
  from l017 l
  join r017 k on k.key = l.key
  join resources res on res.url = k.url and res.title = k.title
  join races r on r.title = l.race_title
  join elections e on e.id = r.election_id and e.election_date = date '2026-11-03';

-- One review site covers all nineteen retention questions.
insert into resource_links (resource_id, race_id, sort_order)
select res.id, r.id, 0
  from r017 k
  join resources res on res.url = k.url and res.title = k.title
  join races r on r.title like 'Retention — %'
  join elections e on e.id = r.election_id and e.election_date = date '2026-11-03'
 where k.key = 'jpr';

-- ---------------------------------------------------------------------------
-- Verification — a mistyped race title would otherwise insert nothing and
-- report success, which is exactly how migration 007 once lost a contest.
-- ---------------------------------------------------------------------------
do $$
declare n int; t text;
begin
  select count(*) into n from resources res join r017 k on k.url = res.url and k.title = res.title;
  if n <> (select count(*) from r017) then
    raise exception 'Migration 017: expected % resources, found %.', (select count(*) from r017), n;
  end if;

  -- Every planned link landed on exactly one race.
  for t in
    select l.key || ' -> ' || l.race_title from l017 l
     where (select count(*) from races r join elections e on e.id = r.election_id
             where r.title = l.race_title and e.election_date = date '2026-11-03') <> 1
  loop
    raise exception 'Migration 017: link target not found exactly once: %', t;
  end loop;

  select count(*) into n from resource_links rl
    join resources res on res.id = rl.resource_id
   where res.url = 'https://yourmissourijudges.org/';
  if n <> 19 then
    raise exception 'Migration 017: expected 19 retention links, found %.', n;
  end if;

  select count(*) into n from resource_links rl
    join resources res on res.id = rl.resource_id
    join r017 k on k.url = res.url and k.title = res.title;
  if n <> (select count(*) from l017) + 19 then
    raise exception 'Migration 017: expected % links, found %.', (select count(*) from l017) + 19, n;
  end if;
end $$;

drop table r017;
drop table l017;
