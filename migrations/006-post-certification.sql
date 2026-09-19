-- Migration 006: clear the pre-certification caveat
--
-- Migration 005 stamped every November 3, 2026 election row with:
--
--   "Candidates reflect unofficial results from the August 4, 2026 primary.
--    Results are certified by the state in the weeks afterward."
--
-- Missouri certified on August 25, 2026. That sentence has been false since,
-- and it was still on the live site three weeks later. Clear it.
--
-- Safe to run whether or not 005 was ever applied: if the note is already
-- absent this updates nothing. Run BEFORE the migration that adds the
-- remaining certified contests, so no row is ever both certified and
-- labelled unofficial.

update elections
   set note = null
 where election_date = date '2026-11-03'
   and note like '%unofficial results%';

-- Nothing replaces it. The standing accuracy note on every ballot already
-- tells people to confirm with their election authority, and after
-- certification "these are the certified candidates" is the baseline
-- expectation rather than a caveat worth spending a line on.
