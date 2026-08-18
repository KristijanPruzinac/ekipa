-- 0008 · The four indexes the advisor pass argued for, and the twenty-one it
-- did not.
--
-- `get_advisors` reports twenty-five unindexed foreign keys (DP-10). Adding all
-- twenty-five would be the easy way to make a report go green and the wrong way
-- to run a database: every index is write amplification on a table the sweeper
-- touches every few minutes, and an index with no query behind it is a cost
-- with no benefit.
--
-- So the test applied to each was: **name the query.** Four had one. The rest
-- reference a catalogue — genders, activities, equipment, report categories,
-- cities, config versions, admin users — and a catalogue row is never deleted,
-- which is the only thing an index on the referencing side buys you there.
--
-- The remaining twenty-one are declined on purpose and recorded in
-- `supabase/README.md`, so the next advisor pass reads as a decision rather
-- than as twenty-one unread warnings.

-- "Every venue in this city", run by ingestion on every refresh and by the
-- console every time somebody vets a place. `venues_cluster_idx` covers the
-- matcher's question; nothing covered this one.
create index venues_city_idx on public.venues (city_id) where active;

-- "Why was this group built the way it was" — the single most important console
-- query, and the reason match_run_groups exists at all. Its primary key is
-- (match_run_id, hangout_id), so a lookup by hangout alone scans.
create index match_run_groups_hangout_idx
  on public.match_run_groups (hangout_id);

-- "Everything this run produced", which is how a surprising run gets read back
-- after it has already happened.
create index hangouts_match_run_idx on public.hangouts (match_run_id)
  where match_run_id is not null;

-- Ratings by rater, which is not a display query — it is how the trust system
-- detects straight-lining and computes report credibility (04_TRUST.md §4).
-- `ratings_subject_idx` answers "what was said about this person"; this one
-- answers "what does this person always say", and only the second one can catch
-- a rater whose every answer is identical.
create index ratings_rater_idx on public.ratings (rater_id);
