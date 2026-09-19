-- Migration 011: county offices, ballot measures and exact judicial wording
--
-- SOURCE: St. Louis County Board of Elections, "November 3, 2026 General
-- Election — Unofficial Ballot Content Report", generated 16 September 2026.
-- Every measure's text below is transcribed verbatim from that report by
-- script rather than by hand, because official_text is what a voter reads on
-- the ballot and paraphrasing it would defeat the point.
--
-- Run AFTER 010.
--
-- The report also revealed how much of the ballot we were missing: four
-- constitutional amendments, a statewide referendum, three county offices,
-- two county propositions, a Creve Coeur bond issue and three school district
-- measures — none of which were on the site.

-- ---------------------------------------------------------------------------
-- School districts are a new scope. Parkway and Ritenour both have measures
-- on this ballot, and between them they cover every city we serve.
-- ---------------------------------------------------------------------------
alter table districts drop constraint if exists districts_level_check;
alter table districts add constraint districts_level_check check (
  level in ('statewide','us_senate','us_house','state_senate','state_house',
            'county','judicial','municipal','school'));

insert into districts (level, name, short_name, state, info_url, sort_order) values
  ('school', 'Parkway C-2 School District', 'Parkway C-2', 'MO',
   'https://www.parkwayschools.net/', 20),
  ('school', 'Ritenour School District', 'Ritenour', 'MO',
   'https://www.ritenour.k12.mo.us/', 21);

-- Coverage measured against TIGERweb school district polygons, percent of
-- each city's area. Every one is partial: no city sits wholly in one district.
insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, true
from (values
  ('Maryland Heights', 'Parkway C-2'),   -- 52.8%
  ('Creve Coeur',      'Parkway C-2'),   -- 66.7%
  ('Town and Country', 'Parkway C-2'),   -- 97.9%
  ('Overland',         'Ritenour'),      -- 96.7%
  ('Bridgeton',        'Ritenour')       -- 0.9%, a genuine sliver
) as v(city, sd)
join jurisdictions j on j.name = v.city and j.state = 'MO'
join districts d on d.short_name = v.sd and d.state = 'MO';

insert into elections (district_id, name, election_date)
select id, 'General Election', date '2026-11-03'
from districts where short_name in ('Parkway C-2','Ritenour') and state = 'MO';

-- Creve Coeur's bond issue is a city measure, so it hangs off the city itself.
insert into elections (jurisdiction_id, name, election_date)
select id, 'General Election', date '2026-11-03'
from jurisdictions where name = 'Creve Coeur' and state = 'MO';

-- County Council seats are on the ballot (districts 1, 3, 5 and 7) but which
-- council district each city falls in is not in any dataset reachable here,
-- and the council map is not published as boundary geometry we can query.
-- Give it its own scope with no races so the ballot says so rather than
-- looking complete.
insert into districts (level, name, short_name, state, info_url, sort_order)
values ('county', 'St. Louis County Council', 'County Council', 'MO',
        'https://stlouiscountymo.gov/st-louis-county-government/county-council/', 9);

insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, true
from jurisdictions j, districts d
where j.state = 'MO' and j.county = 'St. Louis County'
  and d.short_name = 'County Council' and d.state = 'MO';

insert into elections (district_id, name, election_date)
select id, 'General Election', date '2026-11-03'
from districts where short_name = 'County Council' and state = 'MO';


-- ---------------------------------------------------------------------------
-- County-wide offices. Note Doug Clemens appears here as a candidate for
-- Assessor while also being the sitting House 72 representative — which is
-- why House 72 is an open seat.
-- ---------------------------------------------------------------------------

with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'County Executive', 'office', 1, 'Chief executive of St. Louis County government. Four-year term.', 1
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'St. Louis County' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, sort_order)
select r.id, v.name, v.party, false, v.sort_order
from r, (values
  ('Dennis Hancock', 'Republican', 0),
  ('Jake Zimmerman', 'Democratic', 1),
  ('J D McFarland', 'Green', 2)
) as v(name, party, sort_order);

with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'Prosecuting Attorney', 'office', 1, 'Chief prosecutor for St. Louis County. Four-year term.', 2
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'St. Louis County' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, sort_order)
select r.id, v.name, v.party, false, v.sort_order
from r, (values
  ('Melissa Price Smith', 'Democratic', 0),
  ('Theo Brown Sr.', 'Libertarian', 1)
) as v(name, party, sort_order);

with r as (
  insert into races (election_id, title, kind, vote_for, description, sort_order)
  select e.id, 'County Assessor', 'office', 1, 'Values property in St. Louis County for tax purposes. Four-year term.', 3
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'St. Louis County' and d.state = 'MO'
    and e.election_date = date '2026-11-03'
  returning id
)
insert into candidates (race_id, name, party, incumbent, sort_order)
select r.id, v.name, v.party, false, v.sort_order
from r, (values
  ('David Messner', 'Republican', 0),
  ('Doug Clemens', 'Democratic', 1),
  ('Austin Brown', 'Green', 2)
) as v(name, party, sort_order);

-- ---------------------------------------------------------------------------
-- Ballot measures. official_text is verbatim from the county's report.
-- ---------------------------------------------------------------------------

insert into races (election_id, title, kind, vote_for, official_text, sort_order)
  select e.id, 'Constitutional Amendment 3', 'measure', 1, 'Proposed by the 103rd General Assembly (First Regular Session) HCS HJR 73 Shall the Missouri Constitution be amended to: * Repeal the 2024 voter-approved Amendment providing reproductive healthcare rights, including abortion through fetal viability; * Allow abortions for rape and incest (under twelve-weeks’ gestation), emergencies, and fetal anomalies; * Allow legislation regulating abortion; * Ensure parental consent for minors’ abortions; * Prohibit gender transition procedures for minors? State governmental entities estimate no costs or savings. Greene County estimates it may experience an unknown increase in tax revenue. Other local governmental entities estimate no costs or savings.', 10
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'Statewide' and d.state = 'MO'
    and e.election_date = date '2026-11-03';

insert into races (election_id, title, kind, vote_for, official_text, sort_order)
  select e.id, 'Constitutional Amendment 6', 'measure', 1, 'Proposed by Initiative Petition Shall the Missouri Constitution be amended to: * expand the initiative and referendum petition process by making it a fundamental right; * allow courts to revise ballot summaries through lawsuits; * prohibit the legislature from weakening initiative or referendum powers; * prohibit the legislature from changing or repealing laws enacted through the initiative process, or passing laws similar to those rejected by referendum, without approval from at least 80% of both chambers; and * preserve existing majority vote and signature requirements for initiative and referendum petitions? State and local governmental entities estimate no costs or savings.', 11
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'Statewide' and d.state = 'MO'
    and e.election_date = date '2026-11-03';

insert into races (election_id, title, kind, vote_for, official_text, sort_order)
  select e.id, 'Constitutional Amendment 7', 'measure', 1, 'Proposed by 103rd General Assembly (Second Regular Session) SS SCS SJR 95 Shall the Missouri Constitution be amended to establish a permanent public endowment fund to support state government instead of taxing Missouri residents, prohibit the General Assembly from appropriating or diverting the fund, and eliminate state-imposed taxes once the fund generates sufficient revenue to replace them? State and local governmental entities estimate no costs or savings.', 12
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'Statewide' and d.state = 'MO'
    and e.election_date = date '2026-11-03';

insert into races (election_id, title, kind, vote_for, official_text, sort_order)
  select e.id, 'Constitutional Amendment 8', 'measure', 1, 'Proposed by the 103rd General Assembly (Second Regular Session) CCS HCS SS SJR 87 Shall the Missouri Constitution be amended to support law enforcement by preserving the right of citizens to elect a county sheriff, prohibiting the removal of a county sheriff except by a writ of quo warranto, and recognizing the office of sheriff as part of the administration of justice? State and local governmental entities estimate no costs or savings.', 13
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'Statewide' and d.state = 'MO'
    and e.election_date = date '2026-11-03';

insert into races (election_id, title, kind, vote_for, official_text, sort_order)
  select e.id, 'Proposition A — congressional map referendum', 'measure', 1, 'Proposed by Referendum Petition Do the people of the state of Missouri approve the act of the General Assembly entitled “House Bill No. 1 (2025 Second Extraordinary Session),” which repeals Missouri’s existing congressional plan, and replaces it with new congressional boundaries that keep more counties intact? State and local governmental entities estimate no costs or savings.', 14
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'Statewide' and d.state = 'MO'
    and e.election_date = date '2026-11-03';

insert into races (election_id, title, kind, vote_for, official_text, sort_order)
  select e.id, 'County Proposition A — County Auditor term', 'measure', 1, 'Shall Sections 2.200 and 2.210 of the Charter of St. Louis County be amended to remove the term of office from the position of County Auditor and as set forth in Exhibit A of Ordinance No. 29,627, on file with the St. Louis County Administrative Director and the St. Louis County Board of Election Commissioners?', 20
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'St. Louis County' and d.state = 'MO'
    and e.election_date = date '2026-11-03';

insert into races (election_id, title, kind, vote_for, official_text, sort_order)
  select e.id, 'County Proposition S — senior services levy', 'measure', 1, 'Shall St. Louis County levy a tax of five cents per each one hundred dollars ($100.00) of assessed valuation for the purpose of providing services to persons sixty years of age or older?', 21
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'St. Louis County' and d.state = 'MO'
    and e.election_date = date '2026-11-03';

insert into races (election_id, title, kind, vote_for, official_text, sort_order)
  select e.id, 'Parkway Proposition P — operating levy', 'measure', 1, 'In order to retain and attract teachers and support staff, maintain safe and secure schools, sustain academic and extracurricular experiences for students, while maintaining the District''s financial stability, shall the Board of Education of the Parkway C-2 School District, St. Louis County, Missouri, be authorized to increase the operating tax levy ceiling of the District by $0.46 per $100 of assessed valuation according to the 2027 assessment for general operating expenses of the District? If this proposition is approved, the adjusted operating levy of the school district is estimated to increase from (based on 2025 tax rates) $2.6736 to $3.1336 per $100 of assessed valuation for residential real property, from $4.4173 to $4.8773 for commercial real property, from $3.1038 to $3.5638 for agricultural real property and from $3.7709 to $4.2309 for personal property.', 30
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'Parkway C-2' and d.state = 'MO'
    and e.election_date = date '2026-11-03';

insert into races (election_id, title, kind, vote_for, official_text, sort_order)
  select e.id, 'Ritenour Proposition I — building bonds', 'measure', 1, 'For the purposes of updating safety and security systems and classroom technology, improving, maintaining, repairing and renovating school classrooms and buildings, funding other needed upgrades to facilities including energy efficiency improvements and refinancing existing leases for capital improvements, shall the Board of Education of the Ritenour School District, St. Louis County, Missouri, borrow money in the amount of Forty-Two Million Dollars ($42,000,000) and issue general obligation bonds for the payment thereof, resulting in a zero rate change to the debt service property tax levy? If this proposition is approved, the adjusted debt service levy of the District will remain $0.84 per $100 of assessed valuation of real and personal property. (Note: If Propositions I and N are both approved, the District''s adjusted debt service levy is estimated to be $0.69 per $100 of assessed valuation of real and personal property in 2027 and $0.54 per $100 of assessed valuation of real and personal property in 2030.)', 31
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'Ritenour' and d.state = 'MO'
    and e.election_date = date '2026-11-03';

insert into races (election_id, title, kind, vote_for, official_text, sort_order)
  select e.id, 'Ritenour Proposition N — operating levy', 'measure', 1, 'For purposes of paying salaries and benefits to teachers and other district staff, providing classroom educational material including instructional technology, avoiding cutbacks in educational programming, and providing funds for other operating purposes, shall the Board of Education of the Ritenour School District of St. Louis County, Missouri be authorized to increase the operating tax levy ceiling by $0.15 per $100 of assessed valuation in tax year 2027, and by an additional $0.15 per $100 of assessed valuation in tax year 2030? If this proposition is approved, the total levy of the District is expected to remain unchanged due to the expected voluntary reductions to the District''s debt service tax levy of $0.15 per $100 of assessed valuation in tax year 2027 and an additional reduction of $0.15 per $100 of assessed valuation in tax year 2030, resulting in the estimated adjusted operating levy of the District per $100 of assessed valuation to be $3.0384 for residential real property, $3.7558 for commercial real property and $4.5491 for personal property in tax year 2027 and $3.1884 for residential real property, $3.9058 for commercial real property and $4.6991 for personal property in tax year 2030.', 32
  from elections e join districts d on d.id = e.district_id
  where d.short_name = 'Ritenour' and d.state = 'MO'
    and e.election_date = date '2026-11-03';

insert into races (election_id, title, kind, vote_for, official_text, sort_order)
  select e.id, 'Proposition G — Government Center bonds', 'measure', 1, 'Shall the City of Creve Coeur, Missouri, issue its general obligation bonds in an amount not to exceed $14,000,000 for the purpose of demolishing the existing 75-year-old Government Center and designing, constructing, furnishing, and equipping a new Government Center on the same property? If this proposition is approved, the debt service levy of the city is expected to remain unchanged at the current levy of $0.082 per one hundred dollars assessed valuation of real and personal property.', 40
  from elections e join jurisdictions jj on jj.id = e.jurisdiction_id
  where jj.name = 'Creve Coeur' and jj.state = 'MO'
    and e.election_date = date '2026-11-03';

-- ---------------------------------------------------------------------------
-- Judicial retention: replace our constructed wording with the ballot's own.
-- Migration 007 used the standard statutory phrasing, which was close but not
-- what prints. The county words circuit questions "Division No. N - Shall
-- Judge X, Circuit Judge of Judicial Circuit No. 21, be retained in office?"
-- ---------------------------------------------------------------------------
update races set official_text = 'Shall Judge PAUL C. WILSON of the Missouri Supreme Court be retained in office?'
 where kind = 'measure' and title ilike '%WILSON%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge VIRGINIA W. LAY of the Eastern District Court of Appeals be retained in office?'
 where kind = 'measure' and title ilike '%LAY%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge REBECA NAVARRO-McKELVEY of the Eastern District Court of Appeals be retained in office?'
 where kind = 'measure' and title ilike '%NAVARRO-McKELVEY%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge ANGELA TURNER QUIGLESS of the Eastern District Court of Appeals be retained in office?'
 where kind = 'measure' and title ilike '%QUIGLESS%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge RICHARD M. STEWART, Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%STEWART%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge JOHN BORBONUS, Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%BORBONUS%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge MARY ELIZABETH OTT, Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%OTT%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge AMANDA B. McNELLEY, Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%McNELLEY%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge JEFFERY McPHERSON, Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%McPHERSON%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge LORNE BAKER, Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%BAKER%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge MATT HEARNE, Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%HEARNE%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge ELLEN WYATT DUNNE, Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%DUNNE%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge JULIA PUSATERI LASATER, Associate Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%LASATER%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge NICOLETTE ANTONIA KLAPP, Associate Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%KLAPP%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge JUSTIN W. RUTH, Associate Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%RUTH%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge JASON K. LEWIS, Associate Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%LEWIS%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge KELLY SNYDER, Associate Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%SNYDER%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge MONDONNA L. GHASEDI, Associate Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%GHASEDI%'
   and official_text like 'Shall Judge%';
update races set official_text = 'Shall Judge CHASTIDY DILLON-AMELUNG, Associate Circuit Judge of Judicial Circuit No. 21, be retained in office?'
 where kind = 'measure' and title ilike '%DILLON-AMELUNG%'
   and official_text like 'Shall Judge%';

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n from races r
    join elections e on e.id = r.election_id
   where e.election_date = date '2026-11-03' and r.kind = 'measure'
     and r.official_text is not null;
  if n < 30 then
    raise exception 'Migration 011: expected at least 30 measures with text, found %.', n;
  end if;

  select count(*) into n from races r
    join elections e on e.id = r.election_id
    join districts d on d.id = e.district_id
   where d.short_name = 'St. Louis County' and r.kind = 'office';
  if n <> 3 then
    raise exception 'Migration 011: expected 3 county offices, found %.', n;
  end if;
end $$;
