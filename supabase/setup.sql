-- After 5 Pickleball Club — Supabase setup
-- Run this once: Supabase dashboard → SQL Editor → New query → paste → Run.
-- Safe to run again; it won't duplicate or delete anything.

-- 1. Members table -----------------------------------------------------------

create table if not exists public.members (
  id                        uuid primary key default gen_random_uuid(),
  created_at                timestamptz not null default now(),
  full_name                 text not null check (char_length(full_name) between 1 and 120),
  address                   text not null check (char_length(address) between 1 and 200),
  birthday                  date not null,
  contact_number            text not null check (char_length(contact_number) between 7 and 20),
  email                     text check (char_length(email) <= 120),
  emergency_contact_name    text not null check (char_length(emergency_contact_name) between 1 and 120),
  emergency_contact_number  text not null check (char_length(emergency_contact_number) between 7 and 20),
  dupr_id                   text check (char_length(dupr_id) <= 40),
  registration              text check (char_length(registration) <= 80),
  team_logo_url             text check (char_length(team_logo_url) <= 500)
);

-- Added after the first version: did the member say they've already paid?
alter table public.members add column if not exists fees_paid boolean;

-- When an officer confirmed the registration on admin.html (empty = not yet confirmed).
alter table public.members add column if not exists confirmed_at timestamptz;

-- Players an officer added by hand on admin.html (e.g. walk-ins). These only need a name,
-- so the personal details are optional for them — but still required for website sign-ups.
alter table public.members add column if not exists added_by_admin boolean not null default false;
alter table public.members alter column address drop not null;
alter table public.members alter column birthday drop not null;
alter table public.members alter column contact_number drop not null;
alter table public.members alter column emergency_contact_name drop not null;
alter table public.members alter column emergency_contact_number drop not null;
alter table public.members drop constraint if exists members_details_required;
alter table public.members add constraint members_details_required check (
  added_by_admin or (address is not null and birthday is not null and contact_number is not null
                     and emergency_contact_name is not null and emergency_contact_number is not null));

-- The website may only ADD rows. It cannot read, change or delete them,
-- so members' personal details are visible only to you in the dashboard.
alter table public.members enable row level security;

revoke all on public.members from anon, authenticated;
grant insert on public.members to anon, authenticated;

drop policy if exists "Website can submit registrations" on public.members;
create policy "Website can submit registrations"
  on public.members for insert
  to anon, authenticated
  with check (confirmed_at is null and not added_by_admin); -- website sign-ups can't be pre-confirmed or pose as admin-added

-- 2. Admins (who may see registrations on admin.html) ------------------------

-- Signing in is not enough: an account must also be listed here.
-- Add one with the statement at the bottom of this file.
create table if not exists public.admins (
  user_id   uuid primary key references auth.users (id) on delete cascade,
  added_at  timestamptz not null default now()
);

alter table public.admins enable row level security;

revoke all on public.admins from anon, authenticated;
grant select on public.admins to authenticated;

-- A signed-in account can only check whether IT is an admin; nobody can add themselves.
drop policy if exists "Accounts can see their own admin entry" on public.admins;
create policy "Accounts can see their own admin entry"
  on public.admins for select
  to authenticated
  using (user_id = (select auth.uid()));

-- Admins can read registrations.
grant select on public.members to authenticated;

-- Admins can confirm (or un-confirm) a registration. That is the only thing they can change:
-- the grant covers the confirmed_at column and nothing else.
grant update (confirmed_at) on public.members to authenticated;

drop policy if exists "Admins can confirm registrations" on public.members;
create policy "Admins can confirm registrations"
  on public.members for update
  to authenticated
  using (exists (select 1 from public.admins a where a.user_id = (select auth.uid())))
  with check (exists (select 1 from public.admins a where a.user_id = (select auth.uid())));

-- Admins can add a player by name, and remove players that were added that way (not website sign-ups).
grant delete on public.members to authenticated;

drop policy if exists "Admins can add players" on public.members;
create policy "Admins can add players"
  on public.members for insert
  to authenticated
  with check (added_by_admin and exists (select 1 from public.admins a where a.user_id = (select auth.uid())));

drop policy if exists "Admins can remove players they added" on public.members;
create policy "Admins can remove players they added"
  on public.members for delete
  to authenticated
  using (added_by_admin and exists (select 1 from public.admins a where a.user_id = (select auth.uid())));

drop policy if exists "Admins can view registrations" on public.members;
create policy "Admins can view registrations"
  on public.members for select
  to authenticated
  using (exists (select 1 from public.admins a where a.user_id = (select auth.uid())));

-- 3. Team logo storage -------------------------------------------------------

-- Public bucket: anyone with a logo's link can view that image (so the links in
-- the members table open directly). Uploads are limited to 5 MB PNG/JPG/WebP.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('team-logos', 'team-logos', true, 5242880, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- The website may upload new logos, but not list, replace or delete existing ones.
drop policy if exists "Website can upload team logos" on storage.objects;
create policy "Website can upload team logos"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'team-logos');

-- 4. Matches (the Match Day posters on matchday.html) --------------------------

-- One row per doubles match: two players on each side. Names and photo links are
-- copied in by an officer on admin.html, so the public page never reads the
-- members table. A player's photo is the image they uploaded when registering.
create table if not exists public.matches (
  id               uuid primary key default gen_random_uuid(),
  created_at       timestamptz not null default now(),
  label            text check (char_length(label) <= 60),          -- e.g. "Round 1", "Final"
  match_date       date not null,
  match_time       time,
  court            text check (char_length(court) <= 120),
  team_a_name      text check (char_length(team_a_name) <= 60),
  team_a_player1   text not null check (char_length(team_a_player1) between 1 and 120),
  team_a_player2   text not null check (char_length(team_a_player2) between 1 and 120),
  team_a_player1_photo_url  text check (char_length(team_a_player1_photo_url) <= 500),
  team_a_player2_photo_url  text check (char_length(team_a_player2_photo_url) <= 500),
  team_b_name      text check (char_length(team_b_name) <= 60),
  team_b_player1   text not null check (char_length(team_b_player1) between 1 and 120),
  team_b_player2   text not null check (char_length(team_b_player2) between 1 and 120),
  team_b_player1_photo_url  text check (char_length(team_b_player1_photo_url) <= 500),
  team_b_player2_photo_url  text check (char_length(team_b_player2_photo_url) <= 500)
);

-- In case an earlier version of this table (one logo per team) was already created.
alter table public.matches add column if not exists team_a_player1_photo_url text check (char_length(team_a_player1_photo_url) <= 500);
alter table public.matches add column if not exists team_a_player2_photo_url text check (char_length(team_a_player2_photo_url) <= 500);
alter table public.matches add column if not exists team_b_player1_photo_url text check (char_length(team_b_player1_photo_url) <= 500);
alter table public.matches add column if not exists team_b_player2_photo_url text check (char_length(team_b_player2_photo_url) <= 500);

alter table public.matches enable row level security;

-- Anyone may see the matches; only admins may add or delete them.
revoke all on public.matches from anon, authenticated;
grant select on public.matches to anon, authenticated;
grant insert, delete on public.matches to authenticated;

drop policy if exists "Anyone can view matches" on public.matches;
create policy "Anyone can view matches"
  on public.matches for select
  to anon, authenticated
  using (true);

drop policy if exists "Admins can add matches" on public.matches;
create policy "Admins can add matches"
  on public.matches for insert
  to authenticated
  with check (exists (select 1 from public.admins a where a.user_id = (select auth.uid())));

drop policy if exists "Admins can delete matches" on public.matches;
create policy "Admins can delete matches"
  on public.matches for delete
  to authenticated
  using (exists (select 1 from public.admins a where a.user_id = (select auth.uid())));

-- 5. Make an account an admin ------------------------------------------------
-- First create the account: Authentication → Users → Add user → Create new user
-- (enter an email and password, keep "Auto Confirm User" ticked).
-- Then remove the two dashes below, put in that email, and run just this statement:

-- insert into public.admins (user_id)
--   select id from auth.users where email = 'officer@example.com'
--   on conflict do nothing;
