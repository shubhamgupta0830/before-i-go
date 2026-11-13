-- Paste this whole file into Supabase → SQL Editor → New query → Run.
-- It creates the table that holds responses, the storage bucket for
-- video/audio files, and the policies that let anonymous visitors
-- (your friends, not signed into anything) submit but never read
-- or overwrite each other's answers.

create table public.responses (
  id uuid primary key default gen_random_uuid(),
  friend_name text not null,
  q1_type text not null check (q1_type in ('text','video','audio')),
  q1_text text,
  q1_file_path text,
  q2_type text not null check (q2_type in ('text','video','audio')),
  q2_text text,
  q2_file_path text,
  created_at timestamptz not null default now()
);

alter table public.responses enable row level security;

-- anyone can submit a response; nobody (besides you, via the
-- Supabase dashboard) can read, edit, or delete one.
-- (uses "public" rather than "anon" -- this project's publishable-key
-- requests didn't resolve to the "anon" role, "public" covers it safely)
create policy "anyone can submit a response"
on public.responses for insert
to public
with check (true);

-- storage bucket for the video/audio files, private (not public)
insert into storage.buckets (id, name, public, file_size_limit)
values ('responses', 'responses', false, 52428800); -- 50MB per file

create policy "anyone can upload a response file"
on storage.objects for insert
to anon
with check (bucket_id = 'responses');
