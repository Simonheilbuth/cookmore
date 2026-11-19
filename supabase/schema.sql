-- CookMore cloud backup – database schema and security rules for Supabase.
--
-- Run this once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- Every app installation signs in anonymously and gets its own user id.
-- Row Level Security (RLS) makes sure a user can only see and change
-- their own rows, even though all users share the same table.

create table if not exists public.profile_backups (
  user_id    uuid        not null default auth.uid()
                         references auth.users (id) on delete cascade,
  profile_id text        not null check (char_length(profile_id) <= 64),
  nickname   text        not null check (char_length(nickname) between 2 and 20),
  data       jsonb       not null check (pg_column_size(data) < 200000),
  updated_at timestamptz not null default now(),
  primary key (user_id, profile_id)
);

-- Without RLS every user could read every row. With RLS and no matching
-- policy, nothing is allowed. The policies below open up only own rows.
alter table public.profile_backups enable row level security;

drop policy if exists "Read own backups" on public.profile_backups;
create policy "Read own backups"
  on public.profile_backups for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Insert own backups" on public.profile_backups;
create policy "Insert own backups"
  on public.profile_backups for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Update own backups" on public.profile_backups;
create policy "Update own backups"
  on public.profile_backups for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Delete own backups" on public.profile_backups;
create policy "Delete own backups"
  on public.profile_backups for delete
  to authenticated
  using ((select auth.uid()) = user_id);
