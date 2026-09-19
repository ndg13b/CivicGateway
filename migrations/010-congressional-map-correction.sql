-- Migration 010: revert the congressional mapping — 009 used the wrong map
--
-- WHAT WENT WRONG
--
-- Migration 009 remapped Maryland Heights and Creve Coeur using TIGERweb's
-- "120th Congressional Districts; January 1, 2026 vintage" layer, on the
-- reasoning that the 120th Congress is the one elected in November 2026.
--
-- The boundaries in that layer are real. The inference was not. That map comes
-- from House Bill 1 (2025 Second Extraordinary Session), and HB1 is the
-- subject of a referendum petition that appears on this very ballot as
-- statewide PROPOSITION A:
--
--   "Do the people of the state of Missouri approve the act of the General
--    Assembly entitled 'House Bill No. 1 (2025 Second Extraordinary
--    Session)', which repeals Missouri's existing congressional plan, and
--    replaces it with new congressional boundaries that keep more counties
--    intact?"
--
-- A referendum petition suspends the act until the vote. So the November 3,
-- 2026 congressional elections are run under the PREVIOUS plan — the same map
-- the sitting Congress was elected under, TIGERweb's 119th layer.
--
-- The St. Louis County Board of Elections ballot content report dated
-- 16 September 2026 settles it: the entire county has exactly two
-- congressional contests, District 1 and District 2. There is no District 3
-- contest anywhere in the county. Under the 120th map Maryland Heights would
-- be 13% in District 3, and that contest simply does not exist here.
--
-- THE LESSON: boundary geometry is authoritative about where lines are. It is
-- not authoritative about which map is legally in force. Only the election
-- authority's ballot answers that, and it should have been checked first.
--
-- 009's state legislative changes were CORRECT and are untouched — the county
-- report lists Districts 70, 71, 72, 87 and 89, and no Senate District 15,
-- exactly as 008 and 009 concluded.
--
-- ---------------------------------------------------------------------------
-- Correct mapping for November 2026, from the 119th-Congress geometry and
-- confirmed against the county ballot:
--
--   Maryland Heights   CD 1 32.7%  ·  CD 2 67.3%      both, partial
--   Creve Coeur        CD 1 30.9%  ·  CD 2 69.1%      both, partial
--   Bridgeton          CD 1 100%                      whole
--   Overland           CD 1 100%                      whole
--   Town and Country   CD 2 100%                      whole
-- ---------------------------------------------------------------------------

-- 1. Remove the 3rd District entirely. No St. Louis County ballot carries it.
delete from candidates c
 using races r, elections e, districts d
 where c.race_id = r.id and r.election_id = e.id and e.district_id = d.id
   and d.short_name = 'MO-3' and d.state = 'MO';

delete from races r
 using elections e, districts d
 where r.election_id = e.id and e.district_id = d.id
   and d.short_name = 'MO-3' and d.state = 'MO';

delete from elections e
 using districts d
 where e.district_id = d.id and d.short_name = 'MO-3' and d.state = 'MO';

delete from jurisdiction_districts jd
 using districts d
 where jd.district_id = d.id and d.short_name = 'MO-3' and d.state = 'MO';

delete from districts d
 where d.short_name = 'MO-3' and d.state = 'MO';

-- 2. Restore MO-1 for the two cities 009 removed it from. Both are roughly a
--    third in the 1st District under the map actually in force.
insert into jurisdiction_districts (jurisdiction_id, district_id, partial)
select j.id, d.id, true
from jurisdictions j, districts d
where j.state = 'MO' and j.name in ('Maryland Heights', 'Creve Coeur')
  and d.short_name = 'MO-1' and d.state = 'MO'
  and not exists (select 1 from jurisdiction_districts x
                  where x.jurisdiction_id = j.id and x.district_id = d.id);

-- 3. MO-2 covers most but not all of those two cities, so it is partial for
--    them. Maryland Heights gained MO-2 in 009, which was right — that city
--    genuinely does split, just between 1 and 2 rather than 2 and 3.
update jurisdiction_districts jd
   set partial = true
  from jurisdictions j, districts d
 where jd.jurisdiction_id = j.id and jd.district_id = d.id
   and j.state = 'MO' and j.name in ('Maryland Heights', 'Creve Coeur')
   and d.short_name = 'MO-2' and d.state = 'MO'
   and jd.partial is distinct from true;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
do $$
declare got text; want text;
begin
  if exists (select 1 from districts where short_name = 'MO-3' and state = 'MO') then
    raise exception 'Migration 010: MO-3 still present.';
  end if;

  for want, got in
    select w.expected,
           (select string_agg(d.short_name || case when jd.partial then '*' else '' end,
                              ', ' order by d.short_name)
              from jurisdiction_districts jd
              join districts d on d.id = jd.district_id
             where jd.jurisdiction_id = j.id and d.level = 'us_house')
    from (values
      ('Maryland Heights', 'MO-1*, MO-2*'),
      ('Creve Coeur',      'MO-1*, MO-2*'),
      ('Bridgeton',        'MO-1'),
      ('Overland',         'MO-1'),
      ('Town and Country', 'MO-2')
    ) as w(city, expected)
    join jurisdictions j on j.name = w.city and j.state = 'MO'
  loop
    if got is distinct from want then
      raise exception 'Migration 010: congressional mapping wrong. expected [%], got [%]', want, got;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Side effect, and a welcome one: Wesley Bell is a current representative of
-- both Maryland Heights and Creve Coeur again. The "one mapping cannot serve
-- both the ballot and who-represents-you" problem that 009 introduced goes
-- away with it — under the map actually in force, the two questions have the
-- same answer.
--
-- If Proposition A passes, the new boundaries take effect for the 2028 cycle
-- and this mapping will need revisiting then. Not before.
-- ---------------------------------------------------------------------------
