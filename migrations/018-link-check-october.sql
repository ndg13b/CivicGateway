-- Migration 018: fixes from the 11 October link check
--
-- Source: check-links.py run against the live site after migration 017 — 102
-- links, 78 on candidates and 24 on race pages. Two real problems; one false
-- alarm left alone.
--
-- False alarm, deliberately NOT changed: the Secretary of State's 2026 ballot
-- measures page timed out. sos.mo.gov is slow, a timeout says nothing about
-- whether a page exists, and the page was read successfully the same day.
-- The checker has been corrected to call a timeout NEEDS-EYES, not BROKEN.

-- ---------------------------------------------------------------------------
-- Ritenour Propositions I and N
--
-- The district's FAQ page (/about-us/allin/faq-about-propositions-i-n) now
-- answers 404. The district home page loads and links to its current
-- Propositions I & N pages, including the FAQ, but the new address for the
-- FAQ itself could not be confirmed — and guessing a URL is how dead links
-- get in. So the link points at the home page and says why.
-- ---------------------------------------------------------------------------
update resources
   set url   = 'https://www.ritenourschools.org/',
       title = 'Propositions I and N: information from the Ritenour School District',
       note  = 'Published by the school district asking voters to approve the measures. '
            || 'Its home page links to the district''s Propositions I & N pages, including a FAQ.'
 where url = 'https://www.ritenourschools.org/about-us/allin/faq-about-propositions-i-n';

-- ---------------------------------------------------------------------------
-- Mark Osmack — County Council District 3: Twitter removed
--
-- twitter.com/mark_osmack answered 404 while all fourteen other Twitter links
-- in the same run answered 200, so this is the platform saying the account is
-- gone, not a bot block. The handle dates from his 2018 congressional run; no
-- current campaign account could be found. 404 is the one status this project
-- treats as proof a social account is gone (see migration 015). His website
-- and Facebook stay.
-- ---------------------------------------------------------------------------
update candidates c set twitter = null
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Council — District 3' and c.name = 'Mark Osmack';

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
do $$
declare n int;
begin
  if exists (select 1 from resources where url like '%faq-about-propositions-i-n%') then
    raise exception 'Migration 018: the dead Ritenour FAQ link is still present.';
  end if;

  select count(*) into n from resource_links rl
    join resources res on res.id = rl.resource_id
   where res.url = 'https://www.ritenourschools.org/';
  if n <> 2 then
    raise exception 'Migration 018: expected the Ritenour link on 2 measures, found %.', n;
  end if;

  if exists (select 1 from candidates where name = 'Mark Osmack' and twitter is not null) then
    raise exception 'Migration 018: Mark Osmack still has a Twitter link.';
  end if;
  if not exists (select 1 from candidates where name = 'Mark Osmack' and website is not null and facebook is not null) then
    raise exception 'Migration 018: Mark Osmack lost his website or Facebook.';
  end if;
end $$;
