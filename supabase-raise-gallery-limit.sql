-- Paste into Supabase → SQL Editor → New query → Run.
-- Video compression was removed (uploads go in exactly as recorded),
-- so raw phone clips can be much bigger than the 70MB the gallery
-- bucket was originally capped at. This raises it to 500MB.

update storage.buckets set file_size_limit = 524288000 where id = 'gallery'; -- 500MB

-- One more thing this SQL can't reach: Supabase also has a PROJECT-WIDE
-- upload size limit (separate from this per-bucket one), commonly
-- defaulted to 50MB on new projects. Whichever limit is smaller wins.
-- Check/raise it at: Dashboard -> Project Settings -> Storage ->
-- "Global file size limit" (or similar wording in your dashboard).
