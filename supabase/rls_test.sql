-- CookMore – security test: can a user reach another user's data?
--
-- Run in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Run supabase/schema.sql first.
--
-- The test creates two fake users (A and B) with one backup row each,
-- then acts as user A and tries to read, change, delete and create B's data.
-- Everything happens inside a transaction that is rolled back at the end,
-- so no data is left behind.
--
-- Result:
--   "Success. No rows returned"  -> all tests passed
--   an error starting with FAIL  -> that test failed (RLS is not working)

begin;

-- Test users (needed because user_id references auth.users).
insert into auth.users (id, aud, role, email)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'rls-test-a@example.invalid'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'rls-test-b@example.invalid');

-- One backup row per user (inserted as the table owner, which bypasses RLS).
insert into public.profile_backups (user_id, profile_id, nickname, data)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'profile-a', 'Alice', '{}'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'profile-b', 'Bob',   '{}');

-- From here on, act exactly like the app does when signed in as user A.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub": "aaaaaaaa-0000-0000-0000-000000000001", "role": "authenticated"}',
  true
);

do $$
declare
  b_id constant uuid := 'bbbbbbbb-0000-0000-0000-000000000002';
  affected int;
  inserted boolean;
begin
  -- Test 1: A can read their own row.
  if (select count(*) from public.profile_backups where profile_id = 'profile-a') <> 1 then
    raise exception 'FAIL 1: user A cannot read their own backup';
  end if;

  -- Test 2: A cannot see B's row, not even when asking for it directly.
  if (select count(*) from public.profile_backups where user_id = b_id) <> 0 then
    raise exception 'FAIL 2: user A can read user B''s backup';
  end if;

  -- Test 3: A cannot change B's row.
  update public.profile_backups set nickname = 'Hacked' where user_id = b_id;
  get diagnostics affected = row_count;
  if affected <> 0 then
    raise exception 'FAIL 3: user A changed user B''s backup';
  end if;

  -- Test 4: A cannot delete B's row.
  delete from public.profile_backups where user_id = b_id;
  get diagnostics affected = row_count;
  if affected <> 0 then
    raise exception 'FAIL 4: user A deleted user B''s backup';
  end if;

  -- Test 5: A cannot create a row that claims to belong to B.
  begin
    insert into public.profile_backups (user_id, profile_id, nickname, data)
    values (b_id, 'fake', 'Fake', '{}');
    inserted := true;
  exception when insufficient_privilege then
    inserted := false; -- "new row violates row-level security policy"
  end;
  if inserted then
    raise exception 'FAIL 5: user A created a backup for user B';
  end if;
end $$;

-- Test 6: requests without a signed-in user (role "anon") get no access.
reset role;
set local role anon;
do $$
begin
  perform count(*) from public.profile_backups;
  raise exception 'FAIL 6: the anon role can read profile_backups';
exception when insufficient_privilege then
  null; -- "permission denied" is the expected result
end $$;

rollback;
