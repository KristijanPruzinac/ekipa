-- 00 · The negative control.
--
-- Every assertion in `02_privacy_invariants.sql` passes by receiving the word
-- `denied`. That makes one failure mode invisible: a harness that says `denied`
-- to everything — a typo in the role switch, a helper that swallows the wrong
-- exception — would report seven green invariants over a wide-open database.
--
-- So this file breaks an invariant on purpose and checks that the break is
-- **visible**. It runs first, and a green suite means the tests that follow it
-- can tell the two answers apart.
--
-- This is what "failing-then-passing" means in the P0 exit criterion. Written
-- once, kept forever, because the day it matters is the day somebody refactors
-- `tap.count_as`.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir fixture.sql

-- ─────────────────────────────────────────────────────────────────────────────
-- Breaking it the way it would actually get broken: not maliciously, but by
-- somebody reasonable deciding that a person ought to be able to see what was
-- said about them. That policy is one line, it reads as fair, and it ends the
-- product (T1).
create function tap.test_the_suite_can_fail()
returns setof text language plpgsql as $fn$
declare
  v_ana uuid := tap.auth_of(tap.alice());
begin
  return next is(
    tap.count_as(v_ana, 'select 1 from public.ratings'), 'denied',
    'control: with the schema as shipped, the ratings table is closed');

  grant select on table public.ratings to authenticated;
  create policy ratings_read_about_me on public.ratings
    for select to authenticated
    using (subject_id = public.current_person_id());

  return next is(
    tap.count_as(v_ana, 'select 1 from public.ratings'), '2',
    'control: one plausible policy opens it, and the harness says so');

  drop policy ratings_read_about_me on public.ratings;
  revoke select on table public.ratings from authenticated;

  return next is(
    tap.count_as(v_ana, 'select 1 from public.ratings'), 'denied',
    'control: and closes again when the policy goes');
end;
$fn$;

-- The other way a harness lies: by never actually becoming anybody, so every
-- query runs as the table owner and RLS never engages.
create function tap.test_the_role_switch_is_real()
returns setof text language plpgsql as $fn$
begin
  return next is(
    tap.value_as(tap.auth_of(tap.alice()), 'select current_user::text'),
    'authenticated',
    'control: a session really is the authenticated role, not the owner');

  return next is(
    tap.value_as(null, 'select current_user::text'), 'anon',
    'control: and an anonymous session really is anon');

  return next is(
    tap.value_as(tap.auth_of(tap.alice()),
      'select public.current_person_id()::text'),
    tap.alice()::text,
    'control: auth.uid() resolves to the person the test meant');

  return next is(current_user::text, session_user::text,
    'control: and the role is handed back before any assertion is made');
end;
$fn$;

select * from runtests('tap'::name, '^test_');

rollback;
