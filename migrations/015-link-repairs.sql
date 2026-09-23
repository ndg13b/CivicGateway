-- Migration 015: remove links that a live check proved dead
--
-- Source: tools/check-links.py run against the live site on 20 September 2026,
-- with --browser so social accounts were opened in a real Chromium.
--
-- Only the three findings that are unambiguous are acted on here. The run also
-- returned fifteen Twitter links as "broken" on HTTP 403; that was the tool
-- being wrong, not the links. X refuses headless browsers as a matter of
-- policy, and 403 says nothing about whether an account exists — two of the
-- fifteen were sitting members of Congress. The tool has been corrected to
-- treat anything short of an explicit 404 on a social host as undecided.
--
-- Nothing is removed on a maybe. A missing link shows an honest empty slot;
-- a wrong one is worse than that, but so is deleting a working one.

-- ---------------------------------------------------------------------------
-- Mark Harder — County Council District 7
--
-- markformissouri.com does not resolve at all: DNS returns nothing, so the
-- domain is gone rather than the page. His YouTube channel reports that it
-- does not exist. His Facebook page loads and stays.
-- ---------------------------------------------------------------------------
update candidates c set website = null, youtube = null
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Council — District 7' and c.name = 'Mark Harder';

-- ---------------------------------------------------------------------------
-- Jake Zimmerman — County Executive
--
-- http://www.jakezimmerman.org/welcome.php answers 404. Confirmed by hand
-- earlier: the domain is alive over https and renders the campaign's own
-- theme, but that path is gone. The site root is the likely replacement and
-- is deliberately NOT written in here — it has not been looked at, and
-- guessing a URL is how the broken one arrived in the first place.
-- ---------------------------------------------------------------------------
update candidates c set website = null
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'County Executive' and c.name = 'Jake Zimmerman';

-- ---------------------------------------------------------------------------
-- Vernon Norman — State Senator District 14
--
-- normanformissouri.com/home redirects to the site root, which loads. The
-- root is the same campaign, so this is a straight correction rather than a
-- removal.
-- ---------------------------------------------------------------------------
update candidates c set website = 'https://www.normanformissouri.com/'
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Senator — District 14' and c.name = 'Vernon Norman';

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
do $$
declare v text;
begin
  select website into v from candidates c
    join races r on r.id = c.race_id join elections e on e.id = r.election_id
   where c.name = 'Mark Harder' and e.election_date = date '2026-11-03';
  if v is not null then
    raise exception 'Migration 015: Mark Harder still has a website (%).', v;
  end if;

  select website into v from candidates c
    join races r on r.id = c.race_id join elections e on e.id = r.election_id
   where c.name = 'Vernon Norman' and e.election_date = date '2026-11-03';
  if v is distinct from 'https://www.normanformissouri.com/' then
    raise exception 'Migration 015: Vernon Norman website is %, expected the root.', v;
  end if;

  -- The false positives must survive. If a later change ever removes these,
  -- something has gone wrong in exactly the way this migration warns about.
  if not exists (select 1 from candidates where name = 'Wesley Bell' and twitter is not null)
     or not exists (select 1 from candidates where name = 'Ann Wagner' and twitter is not null) then
    raise exception 'Migration 015: a Twitter link was removed that should have been kept.';
  end if;
end $$;
