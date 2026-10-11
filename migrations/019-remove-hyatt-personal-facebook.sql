-- Migration 019: remove Dan Hyatt's personal Facebook link
--
-- facebook.com/hyattdj was added in migration 014 as Dan Hyatt's only public
-- presence, from his Ballotpedia page. That page was last updated for his
-- 2016 run in House District 72, not this race.
--
-- Two automated checks disagreed about whether the page existed, so it was
-- opened by hand while signed in (11 October 2026). It is a personal profile:
-- political posts, but nothing that identifies it as the candidate's or as a
-- campaign page. With no way to confirm it is the same Dan Hyatt, it comes
-- off. A link to the wrong person's personal page is worse than an empty
-- slot, and it would point voters at a private individual.
--
-- His candidate page goes back to the empty "we don't have a campaign site or
-- contact" slot, which says plainly that this is a gap in our research.

update candidates c set facebook = null
  from races r, elections e
 where c.race_id = r.id and r.election_id = e.id
   and e.election_date = date '2026-11-03'
   and r.title = 'State Representative — District 87' and c.name = 'Dan Hyatt';

do $$
begin
  if exists (select 1 from candidates where name = 'Dan Hyatt' and facebook is not null) then
    raise exception 'Migration 019: Dan Hyatt still has a Facebook link.';
  end if;
  -- Raychel Proudie's campaign page was checked by hand at the same time and
  -- is genuine; make sure nothing here touched it.
  if not exists (select 1 from candidates where name = 'Raychel Proudie' and facebook = 'VotePROUD14') then
    raise exception 'Migration 019: Raychel Proudie''s campaign Facebook is missing.';
  end if;
end $$;
