-- Migration 021: say "unopposed", not "no other candidate filed"
--
-- Two House descriptions claimed "No other candidate filed". That is a claim
-- about the primary, and the same wording was already wrong once: in Council
-- District 1 two other Democrats had filed and lost (migration 016). Whether
-- anyone else filed for House 70 or 71 could not be confirmed either way.
--
-- What can be confirmed is the November ballot itself: the county's official
-- sample ballots (checked 14 October 2026) show Stephanie Boykin alone in
-- House 70 and Nicole Greer alone in House 71. So that is what they now say.
-- House 71 stays an open seat: LaDonna Appelbaum, first elected in 2018, is
-- term-limited.

update races r set description = 'Unopposed on the November ballot. Two-year term.'
  from elections e
 where r.election_id = e.id and e.election_date = date '2026-11-03'
   and r.title = 'State Representative — District 70';

update races r set description =
       'Open seat — the current representative is term-limited. Unopposed on the November ballot. Two-year term.'
  from elections e
 where r.election_id = e.id and e.election_date = date '2026-11-03'
   and r.title = 'State Representative — District 71';

do $$
begin
  if exists (select 1 from races r join elections e on e.id = r.election_id
              where e.election_date = date '2026-11-03'
                and r.description like '%No other candidate filed%') then
    raise exception 'Migration 021: a "No other candidate filed" description remains.';
  end if;
  if (select count(*) from races r join elections e on e.id = r.election_id
       where e.election_date = date '2026-11-03'
         and r.title in ('State Representative — District 70', 'State Representative — District 71')
         and r.description like '%Unopposed on the November ballot%') <> 2 then
    raise exception 'Migration 021: expected both House descriptions to be updated.';
  end if;
end $$;
