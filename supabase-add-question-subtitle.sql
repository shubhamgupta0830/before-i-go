-- Paste into Supabase → SQL Editor → New query → Run.
-- Adds an optional subtitle shown under a question's main prompt
-- (e.g. a hint or clarifying line). Leave it blank in the admin
-- panel and the page simply won't show a subtitle for that question.

alter table public.questions add column if not exists subtitle text;
