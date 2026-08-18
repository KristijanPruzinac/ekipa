-- 03 · The RPC surface (DP-4, DP-5, DP-6, DP-7).
--
-- Every consequential write in this product goes through one of seven
-- functions, and each of them is `security definer` — which means each of them
-- is a hole in RLS that behaves itself only because it was written to. This
-- file is the check that it still is.
--
-- The most valuable assertion here is the dullest one: **no function has a null
-- ACL.** A `security definer` function that nobody remembered to grant is
-- executable by `PUBLIC`, silently, and `revoke ... from public` does not fix
-- it once Supabase has written per-role entries. That is the v1 lesson, and it
-- cost a migration to learn.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

\ir fixture.sql

-- ─────────────────────────────────────────────────────────────────────────────
-- DP-5. Structural, over every function that exists rather than the ones this
-- file happens to know about.
create function tap.test_definer_functions_are_pinned()
returns setof text language plpgsql as $fn$
begin
  return next is(
    (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind = 'f'
        and p.prosecdef
        and not exists (
          select 1 from unnest(coalesce(p.proconfig, '{}'::text[])) cfg
           where cfg like 'search_path=%')),
    '',
    'DP-5: every security definer function pins its search_path');

  return next is(
    (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind = 'f'
        and not p.prosecdef),
    '',
    'DP-5: and there is no invoker-rights function to reason about separately');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- DP-6. The silent no-op, made loud.
create function tap.test_no_function_is_open_to_public()
returns setof text language plpgsql as $fn$
begin
  return next is(
    (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind = 'f'
        and p.proacl is null),
    '',
    'DP-6: no function relies on the default ACL, which is PUBLIC EXECUTE');

  return next is(
    (select coalesce(string_agg(p.proname || ' :: ' || a::text, ', '), '')
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace,
            unnest(coalesce(p.proacl, '{}'::aclitem[])) a
      where n.nspname = 'public' and p.prokind = 'f'
        and (a::text like '=%' or a::text like 'anon=%')),
    '',
    'DP-6: no grant to PUBLIC or to anon survives on any function');

  return next is(
    (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind = 'f'
        and has_function_privilege('anon', p.oid, 'execute')),
    '',
    'DP-6: and anon can execute nothing, asked directly');
end;
$fn$;

-- The whole client API, in one string. Adding an RPC means editing this line,
-- which is the point: the surface is small enough to review, so it should be
-- impossible to grow without saying so.
create function tap.test_client_callable_allowlist()
returns setof text language plpgsql as $fn$
begin
  return next is(
    (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
       from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind = 'f'
        and has_function_privilege('authenticated', p.oid, 'execute')),
    'confirm_hangout, current_city_id, current_person_id, hangout_reveal, '
    || 'is_member, my_hangouts, set_availability',
    'DP-5: the client can call exactly these seven functions');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Confirmation. The state machine belongs to the server; the client sends a
-- claim and finds out what happened.
create function tap.test_confirm_hangout()
returns setof text language plpgsql as $fn$
declare
  v_ana   uuid := tap.auth_of(tap.alice());
  v_bruno uuid := tap.auth_of(tap.bruno());
  v_cvita uuid := tap.auth_of(tap.cvita());
  v_call  text;
begin
  v_call := 'select public.confirm_hangout('
            || quote_literal(tap.h_confirming()) || '::uuid, true)::text';

  return next is(
    tap.value_as(null, v_call), 'ERR:42501',
    'DP-5: an anonymous caller cannot confirm anything');

  return next is(
    tap.value_as(tap.auth_of(tap.dario()), v_call), 'ERR:42501',
    'DP-4: a non-member holding the hangout id cannot confirm');

  return next is(
    tap.value_as(v_ana,
      'select public.confirm_hangout(' || quote_literal(tap.h_before())
      || '::uuid, true)::text'),
    'ERR:22023',
    'DP-4: confirmation is refused while the hangout is only PROPOSED');

  return next is(
    tap.value_as(v_ana, v_call), 'CONFIRMING',
    'a member confirms, and the hangout stays open for the others');

  return next is(
    tap.value_as(v_bruno, v_call), 'CONFIRMING',
    'the second yes does not lock it either');

  -- Locking happens only when everyone has answered yes, and only here. Every
  -- other transition belongs to the sweeper, which owns the clock — otherwise
  -- the last person to answer decides what the group's evening becomes.
  return next is(
    tap.value_as(v_cvita, v_call), 'LOCKED',
    'the third yes locks it, in the transaction that counted them');

  return next is(
    (select count(*)::int from public.hangout_events
      where hangout_id = tap.h_confirming() and type = 'CONFIRMED'),
    3,
    'and each answer left an event behind, which is what makes it explainable');
end;
$fn$;

create function tap.test_confirm_after_the_deadline()
returns setof text language plpgsql as $fn$
begin
  update public.hangouts
     set confirm_deadline_at = now() - interval '1 minute'
   where id = tap.h_confirming();

  return next is(
    tap.value_as(tap.auth_of(tap.alice()),
      'select public.confirm_hangout(' || quote_literal(tap.h_confirming())
      || '::uuid, true)::text'),
    'ERR:22023',
    'DP-7: the deadline is enforced on the server, not by hiding a button');
end;
$fn$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Availability. "These are my slots" is a claim; the server checks all three
-- things it could be lying about.
create function tap.test_set_availability_verifies_the_claim()
returns setof text language plpgsql as $fn$
declare
  v_ana uuid := tap.auth_of(tap.alice());
begin
  return next is(
    tap.value_as(v_ana,
      'select public.set_availability(array['
      || quote_literal(tap.slot_free())    || ','
      || quote_literal(tap.slot_foreign()) || ','
      || quote_literal(tap.slot_past())    || ']::uuid[])::text'),
    '1',
    'a claim over three slots writes the one that was actually the caller''s');

  return next is(
    (select coalesce(string_agg(slot_id::text, ','), '')
       from public.availability where person_id = tap.alice()),
    tap.slot_free()::text,
    'the foreign city''s slot and the past slot are both dropped');

  return next is(
    tap.value_as(null,
      'select public.set_availability(array[]::uuid[])::text'),
    'ERR:42501',
    'DP-5: and an anonymous caller cannot set availability for anyone');
end;
$fn$;

select * from runtests('tap'::name, '^test_');

rollback;
