-- Migration 016: October review of county contests and candidate links
--
-- A full pass on 10 October 2026, three and a half weeks before the election.
-- The certified field is unchanged: every candidate and measure still matches
-- what was certified, Proposition A is on the ballot under the 2022 map (the
-- Missouri Supreme Court ruled on 3 September and the U.S. Supreme Court
-- declined to step in), and Amendment 3 carries the appeals court's rewritten
-- summary. What follows corrects how three county contests were described and
-- settles the three link questions left open after the September link check.

-- ---------------------------------------------------------------------------
-- 1. Incumbents in county contests
--
-- Migrations 011 and 012 inserted every county candidate with incumbent =
-- false. State and federal incumbents carry the tag, so a sitting
-- congresswoman read "Incumbent" while a sitting county councilman did not.
-- Three county candidates hold the office they are running for:
--
--   Mark Harder — District 7 council member, term ending 31 December 2026.
--   Rita H Days — District 1 council member and council chair.
--   Melissa Price Smith — Prosecuting Attorney, sworn in 3 January 2025 after
--     appointment to the vacancy Wesley Bell left on going to Congress.
--
-- Nobody else on a county contest qualifies. County Executive and Assessor
-- are open seats: Sam Page did not run, and Jake Zimmerman, the current
-- Assessor, is running for Executive instead. District 3 is open: Dennis
-- Hancock, who holds it, is also running for Executive.
-- ---------------------------------------------------------------------------
update candidates c set incumbent = true
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and (r.title, c.name) in (
         ('County Council — District 7', 'Mark Harder'),
         ('County Council — District 1', 'Rita H Days'),
         ('Prosecuting Attorney',        'Melissa Price Smith'));

-- ---------------------------------------------------------------------------
-- 2. District 1 description
--
-- "No other candidate filed for this seat" was wrong. Ella Jones and Maria
-- Chappelle-Nadal filed and ran against Days in the 4 August Democratic
-- primary. What is true is that nobody from another party filed, so she is
-- alone on the November ballot.
-- ---------------------------------------------------------------------------
update races r
   set description = 'Represents District 1 on the St. Louis County Council. Four-year term. '
                  || 'Rita H Days won the August Democratic primary and is unopposed in November.'
  from elections e
 where r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Council — District 1';

-- ---------------------------------------------------------------------------
-- 3. Links
--
-- Dennis Hancock — County Executive.
--   hancockforcountyexecutive.com is given as his campaign site in two Call
--   Newspapers articles and a Hoodline report on his campaign.
--
-- Jake Zimmerman — County Executive.
--   Migration 015 removed http://www.jakezimmerman.org/welcome.php, a path
--   that answers 404, and deliberately did not guess a replacement. The root
--   has since been confirmed: Ballotpedia names the domain as his campaign
--   site, the domain renders his campaign's own header, and the root loads.
--   Without it, adding Hancock's site would leave the County Executive race
--   with one candidate linked and the other blank.
--
-- Raychel Proudie — State Senator, District 14.
--   Her "website" was her House District 73 member page — an officeholder
--   page for a different office, not a campaign site. Doug Clemens's House
--   page was left off for that reason in migration 014; this applies the same
--   rule. The link also now redirects to the House's archive site. Her
--   campaign Facebook and Instagram stay.
--
-- Not changed: Dan Hyatt's Facebook. Two automated checks disagreed and
-- nobody has been able to open it signed in. Nothing is removed on a maybe.
-- ---------------------------------------------------------------------------
update candidates c set website = 'https://hancockforcountyexecutive.com/'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Executive' and c.name = 'Dennis Hancock';

update candidates c set website = 'https://www.jakezimmerman.org/'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Executive' and c.name = 'Jake Zimmerman';

update candidates c set website = null
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Senator — District 14' and c.name = 'Raychel Proudie';

-- ---------------------------------------------------------------------------
-- Verification — every update above must have matched a row.
-- ---------------------------------------------------------------------------
do $$
declare n int; v text;
begin
  select count(*) into n from candidates c
    join races r on r.id = c.race_id join elections e on e.id = r.election_id
   where e.election_date = date '2026-11-03' and c.incumbent
     and c.name in ('Mark Harder', 'Rita H Days', 'Melissa Price Smith');
  if n <> 3 then
    raise exception 'Migration 016: expected 3 county incumbents, found %.', n;
  end if;

  select count(*) into n from candidates c
    join races r on r.id = c.race_id join elections e on e.id = r.election_id
   where e.election_date = date '2026-11-03' and c.incumbent
     and r.title in ('County Executive', 'County Assessor', 'County Council — District 3');
  if n <> 0 then
    raise exception 'Migration 016: an open county seat has an incumbent.';
  end if;

  select description into v from races r join elections e on e.id = r.election_id
   where e.election_date = date '2026-11-03' and r.title = 'County Council — District 1';
  if v is null or v like '%No other candidate filed%' then
    raise exception 'Migration 016: District 1 description was not updated.';
  end if;

  select count(*) into n from candidates c
    join races r on r.id = c.race_id join elections e on e.id = r.election_id
   where e.election_date = date '2026-11-03' and r.title = 'County Executive'
     and c.website is not null and c.name in ('Dennis Hancock', 'Jake Zimmerman');
  if n <> 2 then
    raise exception 'Migration 016: expected websites for Hancock and Zimmerman, found %.', n;
  end if;

  select website into v from candidates c
    join races r on r.id = c.race_id join elections e on e.id = r.election_id
   where e.election_date = date '2026-11-03' and c.name = 'Raychel Proudie';
  if v is not null then
    raise exception 'Migration 016: Raychel Proudie still has a website (%).', v;
  end if;
  if not exists (select 1 from candidates where name = 'Raychel Proudie' and facebook is not null) then
    raise exception 'Migration 016: Raychel Proudie lost her campaign Facebook.';
  end if;
end $$;
