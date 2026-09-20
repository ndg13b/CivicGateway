-- Migration 014: candidate websites and social accounts
--
-- SOURCE: each candidate's Ballotpedia page, listed inline. Only links inside
-- that page's candidate infobox were taken — Ballotpedia's own accounts appear
-- in the site header and a share dialog on every page, and an earlier pass
-- picked those up as candidates' own. Every row below was reviewed by hand
-- before being written.
--
-- WHAT IS DELIBERATELY NOT HERE
--
--   * Candidates whose Ballotpedia page does not name this contest, unless
--     checked individually. Mark Osmack was checked and is included; Theo
--     Brown Sr.'s page carries no links at all, so there is nothing to add.
--   * Austin Brown — the page under that name has no Missouri or St. Louis
--     connection and covers a past officeholder elsewhere. Wrong person.
--   * Eight candidates with no Ballotpedia page or no links on it. They keep
--     empty slots, which the page states plainly rather than hiding.
--
-- Personal accounts are used only where a candidate has no campaign presence
-- at all. Ballotpedia researches some people more deeply than others, so
-- listing personal profiles wherever they exist would make coverage depth
-- look like a difference between candidates.

-- Case notes:
-- Doug Clemens: House member page left off; it is an officeholder
--   link, already on his officials row, not a campaign site.
-- Doug Clemens: no campaign accounts found; using the personal
--   account Ballotpedia lists, as it is their only public presence.
-- Dan Hyatt: no campaign accounts found; using the personal
--   account Ballotpedia lists, as it is their only public presence.

-- ---------------------------------------------------------------------------
-- Doug Clemens — County Assessor
--   https://ballotpedia.org/Doug_Clemens
update candidates c set facebook = 'douglas.clemens.10', linkedin = 'douglas-clemens-120320a'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Assessor' and c.name = 'Doug Clemens';

-- Andrew Koenig — County Council — District 3
--   https://ballotpedia.org/Andrew_Koenig
update candidates c set website = 'https://www.electandrewkoenig.com/', facebook = 'AndrewKoenigMO', twitter = 'koenig4MO'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Council — District 3' and c.name = 'Andrew Koenig';

-- Mark Osmack — County Council — District 3
--   https://ballotpedia.org/Mark_Osmack
update candidates c set website = 'https://osmackformissouri.com', facebook = 'osmackformo', twitter = 'mark_osmack'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Council — District 3' and c.name = 'Mark Osmack';

-- John Kiehne — County Council — District 7
--   https://ballotpedia.org/John_Kiehne
update candidates c set website = 'https://kiehneformissouri.com', facebook = 'kiehneformissouri', twitter = 'kiehne4missouri', instagram = 'kiehneformissouri', youtube = 'kiehneformissouri'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Council — District 7' and c.name = 'John Kiehne';

-- Mark Harder — County Council — District 7
--   https://ballotpedia.org/Mark_Harder
update candidates c set website = 'https://www.markformissouri.com/', facebook = 'markhardermo', twitter = 'MarkHarderMO', youtube = 'MarkHardermo'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Council — District 7' and c.name = 'Mark Harder';

-- Jake Zimmerman — County Executive
--   https://ballotpedia.org/Jake_Zimmerman
update candidates c set website = 'http://www.jakezimmerman.org/welcome.php'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Executive' and c.name = 'Jake Zimmerman';

-- Dustin Coffell — State Auditor
--   https://ballotpedia.org/Dustin_Coffell
update candidates c set facebook = 'coffell4mo', twitter = 'Coffell4MO'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Auditor' and c.name = 'Dustin Coffell';

-- Quentin Wilson — State Auditor
--   https://ballotpedia.org/Quentin_Wilson
update candidates c set website = 'https://www.quentin4mo.com', instagram = 'quentinformissouri'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Auditor' and c.name = 'Quentin Wilson';

-- Scott Fitzpatrick — State Auditor
--   https://ballotpedia.org/Scott_Fitzpatrick
update candidates c set website = 'https://auditor.mo.gov/aboutus/auditor', facebook = 'MissouriStateAuditor', twitter = 'Auditor_Fitz', instagram = 'auditorfitzpatrick'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Auditor' and c.name = 'Scott Fitzpatrick';

-- Stephanie Boykin — State Representative — District 70
--   https://ballotpedia.org/Stephanie_Boykin
update candidates c set website = 'https://house.mo.gov/MemberDetails.aspx?year=2026&code=R&district=070', instagram = 'staterepboykin'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Representative — District 70' and c.name = 'Stephanie Boykin';

-- Nicole Greer — State Representative — District 71
--   https://ballotpedia.org/Nicole_Greer
update candidates c set website = 'https://votegreer.com/', facebook = 'electgreer', instagram = 'votegreer'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Representative — District 71' and c.name = 'Nicole Greer';

-- Jeffrey Jacks — State Representative — District 72
--   https://ballotpedia.org/Jeffrey_Jacks
update candidates c set website = 'https://jeff72.com', facebook = 'JefferyJacksforMissouri', twitter = 'JeffJacks4MO72', instagram = 'jeffreyjacksforstaterep'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Representative — District 72' and c.name = 'Jeffrey Jacks';

-- Patrick James Wroblewski — State Representative — District 72
--   https://ballotpedia.org/Patrick_Wroblewski
update candidates c set website = 'https://www.patrickforthe72.com', facebook = 'PatrickWroblewski72', instagram = 'patrickforthe72', youtube = 'PatrickForThe72'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Representative — District 72' and c.name = 'Patrick James Wroblewski';

-- Connie Steinmetz — State Representative — District 87
--   https://ballotpedia.org/Connie_Steinmetz
update candidates c set website = 'https://house.mo.gov/memberdetails.aspx?district=087', twitter = 'steinmetzHD87', instagram = 'repconniesteinmetz', facebook = 'conniesteinmetz87'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Representative — District 87' and c.name = 'Connie Steinmetz';

-- Dan Hyatt — State Representative — District 87
--   https://ballotpedia.org/Dan_Hyatt
update candidates c set facebook = 'hyattdj'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Representative — District 87' and c.name = 'Dan Hyatt';

-- George Hruza — State Representative — District 89
--   https://ballotpedia.org/George_Hruza
update candidates c set website = 'https://house.mo.gov/memberdetails.aspx?district=089', facebook = 'hruzaformissouri', twitter = 'GeorgeHruza'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Representative — District 89' and c.name = 'George Hruza';

-- Raychel Proudie — State Senator — District 14
--   https://ballotpedia.org/Raychel_Proudie
update candidates c set website = 'https://house.mo.gov/MemberDetails.aspx?year=2025&code=R&district=073', facebook = 'VotePROUD14', instagram = 'rcproudie'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Senator — District 14' and c.name = 'Raychel Proudie';

-- Vernon Norman — State Senator — District 14
--   https://ballotpedia.org/Vernon_Norman
update candidates c set website = 'https://normanformissouri.com/home'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Senator — District 14' and c.name = 'Vernon Norman';

-- LaVanna Wrobley — State Senator — District 24
--   https://ballotpedia.org/LaVanna_Wrobley
update candidates c set website = 'https://www.wrobleyformissouri.com/', facebook = 'wrobleyformissouri', twitter = 'lavannaformo', instagram = 'wrobleyformissouri'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Senator — District 24' and c.name = 'LaVanna Wrobley';

-- Tracy McCreery — State Senator — District 24
--   https://ballotpedia.org/Tracy_McCreery
update candidates c set website = 'https://www.senate.mo.gov/Senators/Member?id=277', twitter = 'SenTracyMcC', facebook = 'McCreeryforMO', instagram = 'tracymccreery', youtube = 'tracymccreeryforstatesenat1612'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Senator — District 24' and c.name = 'Tracy McCreery';

-- Paul Berry III — U.S. Representative — District 1
--   https://ballotpedia.org/Paul_Berry_(Missouri)
update candidates c set website = 'https://www.momadmaga.com/', facebook = 'BerryForUSA'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'U.S. Representative — District 1' and c.name = 'Paul Berry III';

-- Tom Schmitz — U.S. Representative — District 1
--   https://ballotpedia.org/Tom_Schmitz
update candidates c set website = 'https://tomschmitzforliberty.com/', youtube = 'TomSchmitzLP'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'U.S. Representative — District 1' and c.name = 'Tom Schmitz';

-- Wesley Bell — U.S. Representative — District 1
--   https://ballotpedia.org/Wesley_Bell
update candidates c set website = 'https://bell.house.gov', facebook = 'repwesleybell', twitter = 'RepWesleyBellMO', instagram = 'repwesleybell', youtube = 'CongressmanWesleyBell'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'U.S. Representative — District 1' and c.name = 'Wesley Bell';

-- Ann Wagner — U.S. Representative — District 2
--   https://ballotpedia.org/Ann_Wagner
update candidates c set website = 'https://wagner.house.gov/', facebook = 'RepAnnWagner', twitter = 'RepAnnWagner', instagram = 'repannwagner', youtube = 'annwagner160'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'U.S. Representative — District 2' and c.name = 'Ann Wagner';

-- Brandon Coulter Daugherty — U.S. Representative — District 2
--   https://ballotpedia.org/Brandon_Daugherty
update candidates c set twitter = 'Libertarian4MO'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'U.S. Representative — District 2' and c.name = 'Brandon Coulter Daugherty';

-- Fred Wellman — U.S. Representative — District 2
--   https://ballotpedia.org/Frederick_Wellman
update candidates c set website = 'https://www.wellmanformo.com/', facebook = 'wellmanformo', twitter = 'WellmanForMO', instagram = 'WellmanforMO', youtube = 'WellmanForMO'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'U.S. Representative — District 2' and c.name = 'Fred Wellman';

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n
  from candidates c join races r on r.id = c.race_id join elections e on e.id = r.election_id
  where e.election_date = date '2026-11-03'
    and (c.website is not null or c.twitter is not null or c.facebook is not null
         or c.instagram is not null or c.linkedin is not null or c.youtube is not null);
  if n <> 26 then
    raise exception 'Migration 014: expected % candidates with links, found %.', 26, n;
  end if;
end $$;
