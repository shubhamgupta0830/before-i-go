-- Paste into Supabase → SQL Editor → New query → Run.
-- admin.html's Questions tab lets you set an optional subtitle shown
-- under each question, but the live `questions` table predates that
-- field, so saving fails with "Could not find the 'subtitle' column".
-- This adds it.

alter table public.questions add column if not exists subtitle text;
