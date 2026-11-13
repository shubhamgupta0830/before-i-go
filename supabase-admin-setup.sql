-- Paste into Supabase → SQL Editor → New query → Run.
-- This REPLACES the original two-question "responses" table with a
-- flexible design: questions you can add/edit/retire from admin.html,
-- and answers that each keep a frozen snapshot of the question's
-- wording at the moment they were answered -- so editing or removing
-- a question later never changes what a past answer looks like.
--
-- Safe to run now: only my own test rows exist so far.

drop table if exists public.responses cascade;

-- ---------- questions (editable; answers keep their own snapshot) ----------
create table public.questions (
  id uuid primary key default gen_random_uuid(),
  prompt text not null,
  position integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.questions enable row level security;

create policy "anyone can read questions"
on public.questions for select
to public
using (true);

create policy "signed-in user can manage questions"
on public.questions for all
to authenticated
using (true)
with check (true);

insert into public.questions (prompt, position) values
  ('What''s a memory or shared experience you''ll remember me by?', 1),
  ('What are some of your favorite things about me?', 2);

-- ---------- submissions (one per friend's visit) ----------
create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  friend_name text not null,
  ok_to_share boolean not null default false,
  shared_approved boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.submissions enable row level security;

create policy "anyone can submit"
on public.submissions for insert
to public
with check (true);

create policy "signed-in user can read all submissions"
on public.submissions for select
to authenticated
using (true);

create policy "signed-in user can update submissions"
on public.submissions for update
to authenticated
using (true)
with check (true);

create policy "anyone can read shared-approved submissions"
on public.submissions for select
to public
using (shared_approved = true);

-- ---------- answers (one per question per submission) ----------
create table public.answers (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions(id) on delete cascade,
  question_id uuid references public.questions(id) on delete set null,
  question_prompt text not null,  -- frozen wording at time of answering
  position integer not null default 0,
  kind text not null check (kind in ('text','video','audio')),
  text_value text,
  file_path text,
  created_at timestamptz not null default now()
);
alter table public.answers enable row level security;

create policy "anyone can insert answers"
on public.answers for insert
to public
with check (true);

create policy "signed-in user can read all answers"
on public.answers for select
to authenticated
using (true);

create policy "anyone can read answers of shared-approved submissions"
on public.answers for select
to public
using (
  exists (
    select 1 from public.submissions s
    where s.id = answers.submission_id and s.shared_approved = true
  )
);

-- ---------- storage: the existing "responses" bucket (private) ----------
create policy "signed-in user can view all response files"
on storage.objects for select
to authenticated
using (bucket_id = 'responses');

create policy "anyone can view files of shared-approved answers"
on storage.objects for select
to public
using (
  bucket_id = 'responses'
  and exists (
    select 1 from public.answers a
    join public.submissions s on s.id = a.submission_id
    where a.file_path = storage.objects.name and s.shared_approved = true
  )
);

-- ---------- photo drops (friends' own photos of you) ----------
-- Private until you approve one; approved ones show on the public
-- page under initials, never the friend's full name.
create table public.photo_drops (
  id uuid primary key default gen_random_uuid(),
  friend_name text not null,
  storage_path text not null,
  caption text,
  approved boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.photo_drops enable row level security;

create policy "anyone can submit a photo drop"
on public.photo_drops for insert
to public
with check (true);

create policy "signed-in user can manage photo drops"
on public.photo_drops for all
to authenticated
using (true)
with check (true);

create policy "anyone can read approved photo drops"
on public.photo_drops for select
to public
using (approved = true);

create policy "anyone can view files of approved photo drops"
on storage.objects for select
to public
using (
  bucket_id = 'responses'
  and exists (
    select 1 from public.photo_drops p
    where p.storage_path = storage.objects.name and p.approved = true
  )
);

-- ---------- "open when" notes ----------
-- Sealed, in spirit: no public read policy exists for this table at
-- all, not even for approved/shared content -- only you (signed in)
-- can ever read these, in admin.html, whenever the moment comes.
create table public.open_when_notes (
  id uuid primary key default gen_random_uuid(),
  friend_name text not null,
  trigger_label text not null,
  kind text not null check (kind in ('text','video','audio')),
  text_value text,
  file_path text,
  created_at timestamptz not null default now()
);
alter table public.open_when_notes enable row level security;

create policy "anyone can leave an open-when note"
on public.open_when_notes for insert
to public
with check (true);

create policy "signed-in user can read open-when notes"
on public.open_when_notes for select
to authenticated
using (true);

-- ---------- site text (editable from admin.html) ----------
create table public.site_content (
  id text primary key default 'main',
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.site_content enable row level security;

create policy "anyone can read site text"
on public.site_content for select
to public
using (true);

create policy "signed-in user can write site text"
on public.site_content for all
to authenticated
using (true)
with check (true);

-- ---------- gallery items (photos + videos, editable from admin.html) ----------
create table public.gallery_items (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('image','video')),
  storage_path text not null,
  caption text,
  position integer not null default 0,
  created_at timestamptz not null default now()
);
alter table public.gallery_items enable row level security;

create policy "anyone can read gallery items"
on public.gallery_items for select
to public
using (true);

create policy "signed-in user can manage gallery items"
on public.gallery_items for all
to authenticated
using (true)
with check (true);

-- ---------- public storage bucket for gallery media ----------
insert into storage.buckets (id, name, public, file_size_limit)
values ('gallery', 'gallery', true, 73400320); -- 70MB per file, after client-side compression

create policy "anyone can view gallery files"
on storage.objects for select
to public
using (bucket_id = 'gallery');

create policy "signed-in user can manage gallery files"
on storage.objects for all
to authenticated
using (bucket_id = 'gallery')
with check (bucket_id = 'gallery');

-- ---------- one more manual step (can't be done from SQL) ----------
-- Go to: Authentication -> Users -> Add user
-- Enter your own email + a password you choose, "Auto Confirm User" ON.
-- That login is what gets you into admin.html. Nobody else can write
-- to questions, submissions, answers, site_content, gallery_items, or
-- either storage bucket without it.
