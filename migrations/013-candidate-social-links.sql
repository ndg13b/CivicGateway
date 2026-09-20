-- Migration 013: room for the social accounts a candidate actually has
--
-- Candidates and officials carry `twitter` and `facebook` only. The accounts
-- that turn up for down-ballot candidates are more often Instagram or
-- LinkedIn, and a few campaign for a race entirely on YouTube.
--
-- Missing a candidate's only account because we had no column for it is the
-- same neutrality failure the labelled slots were meant to fix: whoever
-- happens to use the two networks we support looks better documented than
-- whoever does not.
--
-- Columns hold a handle or a full URL; the site normalises either.

alter table candidates add column instagram text;
alter table candidates add column linkedin  text;
alter table candidates add column youtube   text;

alter table officials  add column instagram text;
alter table officials  add column linkedin  text;
alter table officials  add column youtube   text;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
do $$
declare missing text;
begin
  for missing in
    select t || '.' || c
    from (values ('candidates'), ('officials')) as tt(t),
         (values ('instagram'), ('linkedin'), ('youtube')) as cc(c)
    where not exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = tt.t and column_name = cc.c)
  loop
    raise exception 'Migration 013: % was not created.', missing;
  end loop;
end $$;
