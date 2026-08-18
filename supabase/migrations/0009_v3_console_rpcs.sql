-- 0009 · The console's entire read and write surface.
--
-- The console is T7 in `docs/v3/11_SECURITY.md`: the highest-value target in
-- the system, because one compromised operator session reads more than any
-- number of compromised user sessions. So it gets the same treatment as the
-- client surface in 0006 and one control the client surface does not have.
--
-- **AC-4, restated as a fact about this file.** There is no service-role key in
-- the browser. Every function below is `security definer` with a role check as
-- its first statement, `set search_path`, and grants revoked from the role
-- names rather than from `PUBLIC` — the v1 silent no-op that 0006's header
-- describes.
--
-- **AC-2 becomes a permission, not a setting.** `admin_role()` requires the
-- session's assurance level to be `aal2`, so an operator who has not completed
-- a second factor is refused *by the database*. "MFA required. No exceptions,
-- including for you" is otherwise a sentence in a document and a checkbox in a
-- dashboard, and neither of those refuses a stolen password.
--
-- **A deviation from AC-1, recorded rather than hidden.** AC-1 asks for a
-- separate auth realm. There is one Supabase project, because there is one free
-- tier and no company (Q-ENTITY), so console sessions live in the same
-- `auth.users` as user sessions. The compensating controls are that a user's
-- JWT is worthless here without a row in `admin_roles`, that every function
-- re-checks that row rather than trusting the app, and that the app is deployed
-- to its own origin. The residual risk is real and it is this: an attacker who
-- takes over the *operator's* ordinary user account also has their console
-- session. Revisit when there is an entity to hold a second project.

-- ─────────────────────────────────────────────────────────────────────────────
-- Who is asking, and are they finished authenticating.
create or replace function public.admin_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select r.role
  from public.admin_roles r
  where r.auth_user_id = auth.uid()
    -- The MFA gate. Supabase writes `aal2` into the JWT only after a second
    -- factor has been presented for this session; anything else — a password
    -- alone, a stale token, a recovery link — resolves to no role at all.
    and coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
$$;

revoke all on function public.admin_role() from public, anon;
grant execute on function public.admin_role() to authenticated;

-- The ladder. `viewer` reads aggregates, `operator` changes configuration and
-- schedules, `owner` holds experiments and safety-critical keys (AC-3).
--
-- Least privilege by default is expressed as an ordering rather than a set of
-- flags, because every permission question in this product is "is this person
-- at least an X" and a flag matrix answers that question three different ways.
create or replace function public.admin_at_least(p_role text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    array_position(array['viewer', 'operator', 'owner'], public.admin_role())
      >= array_position(array['viewer', 'operator', 'owner'], p_role),
    false
  )
$$;

revoke all on function public.admin_at_least(text) from public, anon;
grant execute on function public.admin_at_least(text) to authenticated;

-- Writing the trail. Private to this file: the audit row is written inside the
-- same transaction as the action it describes, so an action that succeeds while
-- its log entry fails is not a state this database can reach (AC-5).
--
-- `admin_audit` has no update or delete grant to anyone, so append-only is a
-- permission rather than a policy (AC-8). Nothing in this file deletes from it,
-- and nothing outside this file can.
--
-- internal: granted to nobody. It is called only by the console functions
-- below, from inside the transaction that performs the action being logged.
-- Granting it to a client would let a console session write whatever trail it
-- liked, which is worse than having no trail.
create or replace function public.admin_log(
  p_action text,
  p_target text,
  p_reason text,
  p_before jsonb,
  p_after  jsonb
)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
begin
  if not public.admin_at_least('viewer') then
    raise exception 'not an operator' using errcode = '42501';
  end if;

  insert into public.admin_audit (actor, action, target, reason, before, after)
  values (auth.uid(), p_action, p_target, p_reason, p_before, p_after);
end;
$$;

revoke all on function public.admin_log(text, text, text, jsonb, jsonb)
  from public, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Configuration: read.
create or replace function public.console_config_versions(p_limit integer)
returns table (
  id             uuid,
  created_at     timestamptz,
  effective_from timestamptz,
  note           text,
  published      boolean,
  value_count    integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.admin_at_least('viewer') then
    raise exception 'not permitted' using errcode = '42501';
  end if;

  return query
  select v.id, v.created_at, v.effective_from, v.note, v.published,
         (select count(*)::integer from public.config_values cv
           where cv.version_id = v.id)
  from public.config_versions v
  order by v.effective_from desc, v.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$$;

revoke all on function public.console_config_versions(integer)
  from public, anon;
grant execute on function public.console_config_versions(integer)
  to authenticated;

create or replace function public.console_config_values(p_version_id uuid)
returns table (
  key        text,
  scope_kind text,
  scope_ref  text,
  value      jsonb
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.admin_at_least('viewer') then
    raise exception 'not permitted' using errcode = '42501';
  end if;

  return query
  select cv.key, cv.scope_kind, cv.scope_ref, cv.value
  from public.config_values cv
  where cv.version_id = p_version_id
  order by cv.key, cv.scope_kind, cv.scope_ref;
end;
$$;

revoke all on function public.console_config_values(uuid) from public, anon;
grant execute on function public.console_config_values(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Configuration: publish.
--
-- Everything the console checked before calling this is checked again here, on
-- the four things that have a consequence: **who** may publish, **when** it
-- applies, **that a reason exists**, and **that the trail is written**. Nothing
-- the app displays is a permission (11_SECURITY.md §2).
--
-- Two checks are deliberately *not* here, and the line between them matters:
--
--   * **Key names.** The declared catalogue lives in Dart (`ConfigCatalogue`),
--     because a second copy in SQL is a second thing to keep in step and the
--     failure mode of drift is a key that validates on one side and not the
--     other. An unknown key stores a row nothing reads: a typo, not a breach.
--     The console refuses it before it gets here.
--   * **Which keys are safety-critical.** Rather than teach the server that
--     list, **every** publish requires a typed reason. AC-6 asks for a reason
--     on safety-critical changes; requiring one always is stronger, costs one
--     sentence, and removes a list the server would have to be told about
--     twice.
--
-- A new version is written **unpublished**. Publishing is a separate act, so a
-- half-entered version cannot become the live rules because a browser tab
-- crashed halfway through.
create or replace function public.console_publish_config(
  p_note           text,
  p_effective_from timestamptz,
  p_values         jsonb,
  p_reason         text
)
returns uuid
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_version uuid;
  v_row     jsonb;
  v_kind    text;
  v_ref     text;
  v_count   integer := 0;
begin
  if not public.admin_at_least('operator') then
    raise exception 'not permitted' using errcode = '42501';
  end if;

  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'a config change needs a reason' using errcode = '22023';
  end if;
  if coalesce(btrim(p_note), '') = '' then
    raise exception 'a version needs a note' using errcode = '22023';
  end if;

  -- The rule this whole table exists for: no version may start applying in the
  -- past. A backdated version penalises people under a rule that did not exist
  -- when they were asked, and it is invisible afterwards because every
  -- historical join then reads as if the rule had always been there.
  if p_effective_from < now() then
    raise exception 'a version cannot take effect in the past'
      using errcode = '22023';
  end if;

  if jsonb_typeof(p_values) is distinct from 'array' then
    raise exception 'values must be an array of rows' using errcode = '22023';
  end if;

  insert into public.config_versions (created_by, effective_from, note)
  values (auth.uid(), p_effective_from, btrim(p_note))
  returning id into v_version;

  for v_row in select * from jsonb_array_elements(p_values)
  loop
    v_kind := v_row ->> 'scope_kind';
    v_ref  := coalesce(v_row ->> 'scope_ref', '');

    -- A `city` scope with an empty reference reads as targeted and behaves as
    -- a second global layer that outranks the real one. The check constraint
    -- accepts it; the resolver would too. This is where it is refused.
    if v_kind = 'global' and v_ref <> '' then
      raise exception 'the global scope carries no reference'
        using errcode = '22023';
    end if;
    if v_kind <> 'global' and v_ref = '' then
      raise exception 'scope % needs a reference', v_kind
        using errcode = '22023';
    end if;

    insert into public.config_values
      (version_id, key, scope_kind, scope_ref, value)
    values (v_version, v_row ->> 'key', v_kind, v_ref, v_row -> 'value');
    v_count := v_count + 1;
  end loop;

  perform public.admin_log(
    'config.publish',
    v_version::text,
    btrim(p_reason),
    jsonb_build_object('effective_from', p_effective_from),
    jsonb_build_object('values', v_count, 'note', btrim(p_note))
  );

  return v_version;
end;
$$;

revoke all on function
  public.console_publish_config(text, timestamptz, jsonb, text)
  from public, anon;
grant execute on function
  public.console_publish_config(text, timestamptz, jsonb, text)
  to authenticated;

-- Publishing is the moment the rules change, so it is its own act with its own
-- audit row. A version can be built, read, diffed and abandoned without ever
-- reaching anybody.
create or replace function public.console_mark_published(
  p_version_id uuid,
  p_reason     text
)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_was boolean;
begin
  if not public.admin_at_least('operator') then
    raise exception 'not permitted' using errcode = '42501';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'publishing needs a reason' using errcode = '22023';
  end if;

  select published into v_was
  from public.config_versions
  where id = p_version_id
  for update;

  if v_was is null then
    raise exception 'no such version' using errcode = '22023';
  end if;

  update public.config_versions set published = true where id = p_version_id;

  perform public.admin_log(
    'config.mark_published',
    p_version_id::text,
    btrim(p_reason),
    jsonb_build_object('published', v_was),
    jsonb_build_object('published', true)
  );
end;
$$;

revoke all on function public.console_mark_published(uuid, text)
  from public, anon;
grant execute on function public.console_mark_published(uuid, text)
  to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Cities and the slot schedule.
--
-- `cities` is readable by any authenticated user, but only where `active` — the
-- catalogue policy in 0001. The console needs the inactive ones too, because a
-- city is inactive precisely while it is being set up.
create or replace function public.console_cities()
returns table (
  id           uuid,
  name         text,
  country_code text,
  timezone     text,
  active       boolean,
  slot_count   integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.admin_at_least('viewer') then
    raise exception 'not permitted' using errcode = '42501';
  end if;

  return query
  select c.id, c.name, c.country_code::text, c.timezone, c.active,
         (select count(*)::integer from public.slots s
           where s.city_id = c.id and s.starts_at > now())
  from public.cities c
  order by c.active desc, c.name;
end;
$$;

revoke all on function public.console_cities() from public, anon;
grant execute on function public.console_cities() to authenticated;

create or replace function public.console_slots(
  p_city_id uuid,
  p_from    date,
  p_to      date
)
returns table (
  id            uuid,
  starts_at     timestamptz,
  ends_at       timestamptz,
  local_date    date,
  local_weekday smallint,
  local_time    time,
  generated_by  text,
  available     integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.admin_at_least('viewer') then
    raise exception 'not permitted' using errcode = '42501';
  end if;

  return query
  select s.id, s.starts_at, s.ends_at, s.local_date, s.local_weekday,
         s.local_time, s.generated_by,
         (select count(*)::integer from public.availability a
           where a.slot_id = s.id)
  from public.slots s
  where s.city_id = p_city_id
    and s.local_date >= p_from
    and s.local_date <= p_to
  order by s.starts_at;
end;
$$;

revoke all on function public.console_slots(uuid, date, date)
  from public, anon;
grant execute on function public.console_slots(uuid, date, date)
  to authenticated;

-- Materialising slots. **This is the only place a local time becomes an
-- instant.**
--
-- The division of labour is deliberate and it is the reason this takes a list
-- rather than a schedule. Which Thursdays exist, and at what local times, is
-- calendar arithmetic that belongs in `ekipa_core` where it is pure and tested
-- (`SlotSchedule.materialise`). Turning `(2026-10-25, 17:30, Europe/Zagreb)`
-- into UTC needs the tz database, which Postgres ships and Dart does not. So
-- Dart sends local dates and times, and `at time zone` — using the city's own
-- IANA id, never the server's — does the one conversion.
--
-- Idempotent by `on conflict do nothing` against the `(city_id, starts_at)`
-- unique key: a generator run twice adds nothing, which matters because the
-- second run is usually somebody checking whether the first one worked.
create or replace function public.console_generate_slots(
  p_city_id      uuid,
  p_slots        jsonb,
  p_generated_by text,
  p_reason       text
)
returns integer
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_tz      text;
  v_row     jsonb;
  v_start   timestamptz;
  v_minutes integer;
  v_made    integer := 0;
begin
  if not public.admin_at_least('operator') then
    raise exception 'not permitted' using errcode = '42501';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'generating slots needs a reason' using errcode = '22023';
  end if;

  select timezone into v_tz from public.cities where id = p_city_id;
  if v_tz is null then
    raise exception 'no such city' using errcode = '22023';
  end if;

  if jsonb_typeof(p_slots) is distinct from 'array' then
    raise exception 'slots must be an array' using errcode = '22023';
  end if;

  for v_row in select * from jsonb_array_elements(p_slots)
  loop
    v_minutes := (v_row ->> 'minutes')::integer;
    if v_minutes is null or v_minutes <= 0 then
      raise exception 'a slot needs a positive length' using errcode = '22023';
    end if;

    v_start := ((v_row ->> 'local_date') || ' ' || (v_row ->> 'local_time'))
                 ::timestamp at time zone v_tz;

    insert into public.slots
      (city_id, starts_at, ends_at, local_date, local_weekday, local_time,
       generated_by)
    values (
      p_city_id,
      v_start,
      v_start + make_interval(mins => v_minutes),
      (v_row ->> 'local_date')::date,
      (v_row ->> 'weekday')::smallint,
      (v_row ->> 'local_time')::time,
      p_generated_by
    )
    on conflict (city_id, starts_at) do nothing;

    if found then
      v_made := v_made + 1;
    end if;
  end loop;

  perform public.admin_log(
    'schedule.generate_slots',
    p_city_id::text,
    btrim(p_reason),
    jsonb_build_object('offered', jsonb_array_length(p_slots)),
    jsonb_build_object('created', v_made, 'generated_by', p_generated_by)
  );

  return v_made;
end;
$$;

revoke all on function
  public.console_generate_slots(uuid, jsonb, text, text)
  from public, anon;
grant execute on function
  public.console_generate_slots(uuid, jsonb, text, text)
  to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Blast radius (12_CONSOLE.md §3.7).
--
-- What a config change would and would not reach, as rows rather than as a
-- reassurance. Ids and deadlines only: nothing here names a person, and the
-- screen it feeds is a count.
create or replace function public.console_in_flight()
returns table (
  id                uuid,
  kind              text,
  decides_at        timestamptz,
  config_version_id uuid
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.admin_at_least('viewer') then
    raise exception 'not permitted' using errcode = '42501';
  end if;

  return query
  select h.id, 'hangout'::text,
         -- The next moment a rule is applied to it. Deadlines are written at
         -- creation, so the earliest one still ahead is the one a change could
         -- reach first.
         least(
           coalesce(h.confirm_deadline_at, 'infinity'::timestamptz),
           coalesce(h.reveal_at,           'infinity'::timestamptz),
           coalesce(h.rating_due_at,       'infinity'::timestamptz)
         ),
         h.config_version_id
  from public.hangouts h
  where h.state not in ('CLOSED', 'CANCELLED', 'ABANDONED')
  order by 3;
end;
$$;

revoke all on function public.console_in_flight() from public, anon;
grant execute on function public.console_in_flight() to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- The trail, readable by anyone who can see the console at all.
--
-- A log only its writer can read is a log that protects nobody. This one exists
-- so "I did not go looking" is a fact rather than a claim (12_CONSOLE.md §2),
-- and a fact nobody can check is a claim again.
create or replace function public.console_audit(p_limit integer)
returns table (
  id          bigint,
  actor       uuid,
  action      text,
  target      text,
  reason      text,
  before      jsonb,
  after       jsonb,
  occurred_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.admin_at_least('viewer') then
    raise exception 'not permitted' using errcode = '42501';
  end if;

  return query
  select a.id, a.actor, a.action, a.target, a.reason, a.before, a.after,
         a.occurred_at
  from public.admin_audit a
  order by a.occurred_at desc, a.id desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
end;
$$;

revoke all on function public.console_audit(integer) from public, anon;
grant execute on function public.console_audit(integer) to authenticated;
