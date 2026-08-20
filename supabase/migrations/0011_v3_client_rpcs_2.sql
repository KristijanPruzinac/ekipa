-- 0011 · The rest of the client's surface.
--
-- 0006 shipped four functions — read my hangouts, read the reveal, set
-- availability, confirm. Everything else the app needs to *do* was missing, so
-- the app has never been able to sign anybody up, mark an arrival, or submit a
-- rating. This file closes that, under the same rules 0006 states and without
-- one exception to them:
--
--   * a caller check as the **first statement** of every function,
--   * `set search_path`,
--   * `revoke ... from public, anon` by role name, never bare `PUBLIC`,
--   * and no function returns another person's row without a membership check.
--
-- Two things are deliberately *not* here.
--
-- **There is no `set_city`, and no city parameter anywhere.** `people.city_id`
-- is derived from the anchor, server-side, once. A client that could set its
-- own city could relocate into a denser one on the morning of a match run,
-- which is the cheapest possible attack on a scarcity-limited matcher.
--
-- **There is no function that returns a count of other people.** The nearest
-- thing, `my_slots`, returns a *bucket*. See the comment on it: a raw number is
-- gameable and it publishes how thin the network is, which is the one figure a
-- young network cannot afford to show (`05_PLACES.md §7`).

-- ─────────────────────────────────────────────────────────────────────────────
-- The missing link between a verified identity and a session.
--
-- `people.identity_id` is `not null`, and `people.auth_user_id` points at an
-- anonymous auth user — so between "the worker verified a code" and "the app
-- called create_profile" there was nothing joining the two. The worker mints
-- the anonymous session; this column is where it records whose session it is,
-- so `create_profile` can resolve an identity from `auth.uid()` alone and never
-- has to take one as a parameter. A client-supplied identity id would be a
-- client choosing whose account to complete.
alter table public.identities
  add column if not exists auth_user_id uuid unique
    references auth.users(id) on delete set null;

-- ─────────────────────────────────────────────────────────────────────────────
-- Signup.
--
-- One call, because four writes means four ways to end up with half a member,
-- and a row with a name and no gender is a person the matcher silently never
-- places — which looks like nothing being wrong from the inside.
create or replace function public.create_profile(
  p_first_name   text,
  p_last_initial text,
  p_gender_code  text,
  p_latitude     double precision,
  p_longitude    double precision,
  p_equipment    text[] default '{}'
)
returns uuid
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_identity uuid;
  v_dob      date;
  v_city     uuid;
  v_person   uuid;
  v_anchor   extensions.geography(Point, 4326);
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  select i.id, i.date_of_birth
    into v_identity, v_dob
  from public.identities i
  where i.auth_user_id = auth.uid()
    and i.revoked_at is null;

  if v_identity is null then
    raise exception 'this session has no verified identity'
      using errcode = '42501';
  end if;

  -- 18+. Attested rather than proven: `hrEduPersonDateOfBirth` is an optional
  -- AAI attribute and an email code carries no age at all, so a null here is
  -- the ordinary case and not a failure (`09_OPEN_QUESTIONS.md` Q-AGE). What
  -- must never happen is a *known* under-18 getting through.
  if v_dob is not null and v_dob > (current_date - interval '18 years') then
    raise exception 'ekipa is 18+' using errcode = '42501';
  end if;

  if exists (select 1 from public.people p where p.identity_id = v_identity
               and p.deleted_at is null) then
    raise exception 'this identity already has a profile'
      using errcode = '23505';
  end if;

  if not exists (select 1 from public.genders g
                  where g.code = p_gender_code and g.active) then
    raise exception 'no such gender' using errcode = '23503';
  end if;

  -- **Snapped before it is stored, not before it is sent.** The app snaps too,
  -- so a person can see what is kept — but the app is the adversary's copy
  -- (`11_SECURITY.md §2`), and an unsnapped coordinate that arrives here is a
  -- home address unless this line exists. ~500 m at Osijek's latitude.
  v_anchor := extensions.ST_SetSRID(
    extensions.ST_MakePoint(
      round(p_longitude::numeric / 0.0064) * 0.0064,
      round(p_latitude::numeric  / 0.0045) * 0.0045
    ),
    4326
  )::extensions.geography;

  -- The city is derived, never claimed. Nearest active city, and only if the
  -- person is plausibly in it — 40 km, which admits the villages around Osijek
  -- and refuses somebody who dropped a pin in Zagreb.
  select c.id into v_city
  from public.cities c
  where c.active
    and extensions.ST_DWithin(c.centroid, v_anchor, 40000)
  order by extensions.ST_Distance(c.centroid, v_anchor)
  limit 1;

  if v_city is null then
    raise exception 'we are not in your city yet' using errcode = '22023';
  end if;

  insert into public.people (
    identity_id, auth_user_id, first_name, last_initial,
    gender_code, city_id, home_anchor
  )
  values (
    v_identity, auth.uid(), btrim(p_first_name), btrim(p_last_initial),
    p_gender_code, v_city, v_anchor
  )
  returning id into v_person;

  insert into public.standing (person_id) values (v_person);

  insert into public.person_equipment (person_id, equipment_code)
  select v_person, e.code
  from public.equipment e
  where e.code = any(p_equipment) and e.active
  on conflict do nothing;

  insert into public.person_events (person_id, type)
  values (v_person, 'PROFILE_CREATED');

  return v_person;
end;
$$;

revoke all on function public.create_profile(
  text, text, text, double precision, double precision, text[]
) from public, anon;
grant execute on function public.create_profile(
  text, text, text, double precision, double precision, text[]
) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Where a person stands, in the four words the app can render.
--
-- Derived here rather than assembled in the client from three reads, because
-- "am I allowed to use this product" is a trust decision and trust decisions do
-- not live in the client (rule 6). A client that decided it was `active`
-- because a sign-in succeeded would walk a suspended member into the picker and
-- the refusal would arrive later, from a write, with nothing attached
-- explaining it.
create or replace function public.my_state()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_person uuid := public.current_person_id();
  v_tier   public.standing_tier;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if v_person is null then
    return 'incomplete';
  end if;

  select s.tier into v_tier from public.standing s where s.person_id = v_person;

  return case v_tier
    when 'BANNED' then 'banned'
    when 'SUSPENDED' then 'suspended'
    else 'active'
  end;
end;
$$;

revoke all on function public.my_state() from public, anon;
grant execute on function public.my_state() to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- The week, with a coarse sense of how busy each slot is.
--
-- **The bucket is the whole point.** `05_PLACES.md §7`: a raw count is gameable
-- — somebody watching it learns when to mark themselves available to be matched
-- with whoever is left — and it publishes how thin the network is, which is the
-- one figure a young network cannot afford to show. Five buckets carry
-- everything the decision needs and none of what an observer wants.
--
-- The ratio is against the city's active population rather than an absolute
-- number, so a slot does not read as "busiest" in a town of nine people.
create or replace function public.my_slots()
returns table (
  slot_id       uuid,
  starts_at     timestamptz,
  local_date    date,
  local_weekday smallint,
  local_time    time,
  chosen        boolean,
  density       double precision
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_person uuid := public.current_person_id();
  v_city   uuid;
  v_active integer;
begin
  if v_person is null then
    raise exception 'no person for this session' using errcode = '42501';
  end if;

  select p.city_id into v_city from public.people p where p.id = v_person;

  select greatest(count(*), 1)::integer into v_active
  from public.people p
  where p.city_id = v_city and p.deleted_at is null;

  return query
  select
    s.id,
    s.starts_at,
    s.local_date,
    s.local_weekday,
    s.local_time,
    exists (
      select 1 from public.availability a
      where a.slot_id = s.id and a.person_id = v_person
    ),
    -- Cast every arm. An unadorned `0.95` in a CASE is `numeric`, and the
    -- signature above promises `double precision` — which plpgsql does not
    -- check until the function is *called*, so the whole thing looked fine
    -- until pgTAP ran it and got `42804`. Every caller would have hit it.
    (case
       when taken.n::double precision / v_active >= 0.30 then 0.95::double precision
       when taken.n::double precision / v_active >= 0.20 then 0.80::double precision
       when taken.n::double precision / v_active >= 0.12 then 0.55::double precision
       when taken.n::double precision / v_active >= 0.05 then 0.35::double precision
       else 0.15::double precision
     end)
  from public.slots s
  cross join lateral (
    select count(*) as n
    from public.availability a2
    where a2.slot_id = s.id
  ) as taken
  where s.city_id = v_city
    and s.starts_at > now()
  order by s.starts_at;
end;
$$;

revoke all on function public.my_slots() from public, anon;
grant execute on function public.my_slots() to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- "Same as last week."
--
-- The single most-used control in a product whose weekly ask is otherwise nine
-- taps. Copies the *pattern* — weekday and time — rather than the rows, because
-- last week's slot ids are in the past and a copy of them would write nothing.
create or replace function public.repeat_last_week()
returns integer
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_person uuid := public.current_person_id();
  v_city   uuid;
  v_count  integer;
begin
  if v_person is null then
    raise exception 'no person for this session' using errcode = '42501';
  end if;

  select p.city_id into v_city from public.people p where p.id = v_person;

  insert into public.availability (person_id, slot_id, source)
  select v_person, s.id, 'repeat'
  from public.slots s
  where s.city_id = v_city
    and s.starts_at > now()
    and (s.local_weekday, s.local_time) in (
      select past.local_weekday, past.local_time
      from public.availability a
      join public.slots past on past.id = a.slot_id
      where a.person_id = v_person
        and past.starts_at < now()
        and past.starts_at > now() - interval '14 days'
    )
  on conflict do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.repeat_last_week() from public, anon;
grant execute on function public.repeat_last_week() to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Arrival.
--
-- `p_near` is the device's own answer to "are you within the fence", and it is
-- **recorded, never trusted**. It is a boolean and never a coordinate: it
-- raises the cost of a false arrival without building a tracking product
-- (`0003`, `arrival_proximate`). A client can send `true` from anywhere, which
-- is exactly why the peer attestations below exist.
create or replace function public.mark_arrived(
  p_hangout_id uuid,
  p_near       boolean default null
)
returns public.hangout_state
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_person uuid := public.current_person_id();
  v_state  public.hangout_state;
begin
  if v_person is null or not public.is_member(p_hangout_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select h.state into v_state
  from public.hangouts h where h.id = p_hangout_id for update;

  if v_state not in ('REVEALED', 'LIVE') then
    raise exception 'not open for arrivals' using errcode = '22023';
  end if;

  update public.hangout_members m
     set arrived_at = coalesce(m.arrived_at, now()),
         arrival_proximate = p_near
   where m.hangout_id = p_hangout_id and m.person_id = v_person;

  insert into public.hangout_events (hangout_id, type, payload, actor_person_id)
  values (
    p_hangout_id, 'ARRIVED',
    jsonb_build_object('proximate', p_near), v_person
  );

  -- The first arrival moves the group to LIVE. Everything after that — the
  -- grace window, the late report, the abandonment — belongs to the sweeper,
  -- which owns the clock. A client-driven state machine would mean the last
  -- person to tap decides what the group's evening becomes.
  if v_state = 'REVEALED' then
    update public.hangouts set state = 'LIVE' where id = p_hangout_id;
    v_state := 'LIVE';
  end if;

  return v_state;
end;
$$;

revoke all on function public.mark_arrived(uuid, boolean) from public, anon;
grant execute on function public.mark_arrived(uuid, boolean) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Peer attestation.
--
-- Everyone taps for themselves *and* about each other. One tap per group is not
-- enough: it makes the first arriver the sole witness, and a group of two
-- friends can then manufacture a full attendance record for four.
--
-- The write is an event rather than a column, because attestations disagree and
-- the disagreement is the evidence. `02_DOMAIN.md §4` combines them: present
-- means they tapped *and* nobody contradicted it, or a majority attests it —
-- and that combination is the sweeper's to make at close, not this function's.
create or replace function public.attest_member(
  p_hangout_id uuid,
  p_member_id  uuid,
  p_present    boolean
)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_person uuid := public.current_person_id();
  v_state  public.hangout_state;
begin
  if v_person is null or not public.is_member(p_hangout_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  if p_member_id = v_person then
    raise exception 'attest is about somebody else' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.hangout_members m
    where m.hangout_id = p_hangout_id
      and m.person_id = p_member_id
      and m.released_at is null
  ) then
    raise exception 'not in this hangout' using errcode = '42501';
  end if;

  select h.state into v_state from public.hangouts h where h.id = p_hangout_id;
  if v_state not in ('REVEALED', 'LIVE') then
    raise exception 'not open for attestation' using errcode = '22023';
  end if;

  insert into public.hangout_events (hangout_id, type, payload, actor_person_id)
  values (
    p_hangout_id,
    'ATTESTED',
    jsonb_build_object('subject', p_member_id, 'present', p_present),
    v_person
  );
end;
$$;

revoke all on function public.attest_member(uuid, uuid, boolean)
  from public, anon;
grant execute on function public.attest_member(uuid, uuid, boolean)
  to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- "I will bring the cards", withdrawn or confirmed.
--
-- Free before the reveal, because a swap is cheap while the activity can still
-- change. After it, the group has been told what it is doing.
create or replace function public.set_bringing(
  p_hangout_id uuid,
  p_bringing   boolean
)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_person uuid := public.current_person_id();
  v_state  public.hangout_state;
begin
  if v_person is null or not public.is_member(p_hangout_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select h.state into v_state from public.hangouts h where h.id = p_hangout_id;
  if v_state in ('CLOSED', 'CANCELLED', 'ABANDONED') then
    raise exception 'that evening is over' using errcode = '22023';
  end if;

  insert into public.hangout_events (hangout_id, type, payload, actor_person_id)
  values (
    p_hangout_id,
    case when p_bringing then 'EQUIPMENT_PROMISED' else 'EQUIPMENT_WITHDRAWN' end,
    jsonb_build_object('before_reveal', v_state not in ('REVEALED','LIVE','RATING')),
    v_person
  );
end;
$$;

revoke all on function public.set_bringing(uuid, boolean) from public, anon;
grant execute on function public.set_bringing(uuid, boolean) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- The ratings, all of them, in one transaction.
--
-- **All at once, because a partial set is indistinguishable from a missing
-- one.** The rating gate blocks a person from being matched again until they
-- have answered; if half a set could land, the gate would block somebody who
-- tried, which is the worst possible way to spend a penalty.
--
-- `p_answers` is `[{"subject": uuid, "enjoyment": text, "respect": bool,
-- "dwell_ms": int}]`. `dwell_ms` is a **hint, never a verdict** — measured on a
-- client we treat as hostile, forgeable in a second, and it feeds a
-- down-weighting heuristic on straight-lining and nothing else.
--
-- Nothing is returned. The caller learns that it worked, and never learns what
-- anyone else said — invariant 3, which is what makes an honest `rather_not`
-- safe to give.
create or replace function public.submit_ratings(
  p_hangout_id   uuid,
  p_answers      jsonb,
  p_easy_to_find boolean,
  p_good_to_meet boolean
)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_person   uuid := public.current_person_id();
  v_state    public.hangout_state;
  v_venue    uuid;
  v_expected integer;
  v_given    integer;
begin
  if v_person is null or not public.is_member(p_hangout_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select h.state, h.meeting_point_id
    into v_state, v_venue
  from public.hangouts h where h.id = p_hangout_id for update;

  if v_state not in ('RATING', 'LIVE') then
    raise exception 'ratings are not open' using errcode = '22023';
  end if;

  -- Every other member, or none. Counted server-side against the membership,
  -- because the client's idea of who was there is the client's.
  select count(*) into v_expected
  from public.hangout_members m
  where m.hangout_id = p_hangout_id
    and m.released_at is null
    and m.person_id <> v_person;

  select count(*) into v_given
  from jsonb_array_elements(p_answers) as answer
  join public.hangout_members m
    on m.hangout_id = p_hangout_id
   and m.person_id = (answer->>'subject')::uuid
   and m.released_at is null
   and m.person_id <> v_person;

  if v_given <> v_expected then
    raise exception 'rate everybody, or nobody' using errcode = '22023';
  end if;

  insert into public.ratings (
    hangout_id, rater_id, subject_id, enjoyment, respect, dwell_ms
  )
  select
    p_hangout_id,
    v_person,
    (answer->>'subject')::uuid,
    (answer->>'enjoyment')::public.enjoyment,
    (answer->>'respect')::boolean,
    nullif(answer->>'dwell_ms', '')::integer
  from jsonb_array_elements(p_answers) as answer
  on conflict (hangout_id, rater_id, subject_id) do nothing;

  -- A `rather_not` is a permanent, symmetric exclusion, and it is invisible to
  -- its subject — which is what makes it safe to give honestly, and what makes
  -- the revenge report unobservable (`04_TRUST.md §4.3`, rung R0).
  insert into public.exclusions (a_id, b_id, reason)
  select
    least(v_person, (answer->>'subject')::uuid),
    greatest(v_person, (answer->>'subject')::uuid),
    'rather_not'
  from jsonb_array_elements(p_answers) as answer
  where (answer->>'enjoyment') = 'rather_not'
  on conflict do nothing;

  if v_venue is not null then
    insert into public.venue_feedback (
      hangout_id, person_id, venue_id, easy_to_find, good_to_meet
    )
    values (
      p_hangout_id, v_person, v_venue, p_easy_to_find, p_good_to_meet
    )
    on conflict (hangout_id, person_id) do nothing;
  end if;

  update public.hangout_members m
     set rated_at = now()
   where m.hangout_id = p_hangout_id and m.person_id = v_person;

  insert into public.hangout_events (hangout_id, type, actor_person_id)
  values (p_hangout_id, 'RATED', v_person);
end;
$$;

revoke all on function public.submit_ratings(uuid, jsonb, boolean, boolean)
  from public, anon;
grant execute on function public.submit_ratings(uuid, jsonb, boolean, boolean)
  to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- A report.
--
-- Heavier than a rating and invisible to its subject, **including the count**
-- (invariant 6). The first report costs the subject almost nothing and protects
-- the reporter completely: they never meet again. That asymmetry is the whole
-- design — it makes reporting cheap for the person who needs it and worthless
-- as a weapon, because one report from one evening can never reach a sanction
-- a person can feel (`0004`, the `context_count >= 2` constraint).
--
-- `p_note` is the only free text in the system. It never reaches the matcher, a
-- notification body, or a display name (rule 11).
create or replace function public.report_member(
  p_hangout_id uuid,
  p_member_id  uuid,
  p_category   text,
  p_note       text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_person uuid := public.current_person_id();
begin
  if v_person is null or not public.is_member(p_hangout_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;
  if p_member_id = v_person then
    raise exception 'a report is about somebody else' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.hangout_members m
    where m.hangout_id = p_hangout_id and m.person_id = p_member_id
  ) then
    raise exception 'not in this hangout' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.report_categories c
    where c.code = p_category and c.active
  ) then
    raise exception 'no such category' using errcode = '23503';
  end if;

  insert into public.reports (
    reporter_id, subject_id, hangout_id, category, note
  )
  values (
    v_person, p_member_id, p_hangout_id, p_category, left(p_note, 1000)
  )
  on conflict (reporter_id, subject_id, hangout_id) do nothing;

  -- R0, immediately and always: these two never meet again. It costs the
  -- subject nothing they can observe and it is the only part of a report that
  -- is worth anything to the reporter tonight.
  insert into public.exclusions (a_id, b_id, reason)
  values (
    least(v_person, p_member_id), greatest(v_person, p_member_id), 'block'
  )
  on conflict do nothing;
end;
$$;

revoke all on function public.report_member(uuid, uuid, text, text)
  from public, anon;
grant execute on function public.report_member(uuid, uuid, text, text)
  to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- "Something is wrong with this place."
--
-- One tap on the reveal screen, and the venue is demoted the instant it is
-- tapped rather than after somebody reads a queue. Past a threshold it is
-- deactivated pending re-ingestion. That is D11 in one function: a venue that
-- closed down must stop being chosen without anybody being on duty.
create or replace function public.report_venue(
  p_hangout_id uuid,
  p_reason     text
)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_person uuid := public.current_person_id();
  v_venue  uuid;
  v_hits   integer;
begin
  if v_person is null or not public.is_member(p_hangout_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select h.meeting_point_id into v_venue
  from public.hangouts h where h.id = p_hangout_id;

  if v_venue is null then
    raise exception 'no meeting point on that hangout' using errcode = '22023';
  end if;

  insert into public.hangout_events (hangout_id, type, payload, actor_person_id)
  values (
    p_hangout_id,
    'VENUE_REPORTED',
    jsonb_build_object('venue', v_venue, 'reason', left(p_reason, 120)),
    v_person
  );

  insert into public.venue_feedback (
    hangout_id, person_id, venue_id, easy_to_find, good_to_meet
  )
  values (p_hangout_id, v_person, v_venue, false, false)
  on conflict (hangout_id, person_id)
  do update set easy_to_find = false, good_to_meet = false;

  -- Distinct hangouts, not distinct taps: four people at one bad venue is one
  -- observation of that venue, and treating it as four would let a single group
  -- delete a place from the city.
  select count(distinct e.hangout_id) into v_hits
  from public.hangout_events e
  where e.type = 'VENUE_REPORTED'
    and e.payload->>'venue' = v_venue::text
    and e.occurred_at > now() - interval '90 days';

  if v_hits >= 3 then
    update public.venues
       set active = false, deactivated_at = now()
     where id = v_venue and active;
  end if;
end;
$$;

revoke all on function public.report_venue(uuid, text) from public, anon;
grant execute on function public.report_venue(uuid, text) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Devices, for the morning-of push.
--
-- A plain insert policy would let a client attach a token to somebody else's
-- person id, which is a notification channel into a stranger's phone. So it is
-- a function, and the person id is `current_person_id()` and nothing else.
create or replace function public.register_device(
  p_push_token text,
  p_platform   text
)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_person uuid := public.current_person_id();
begin
  if v_person is null then
    raise exception 'no person for this session' using errcode = '42501';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'unknown platform' using errcode = '22023';
  end if;

  insert into public.devices (person_id, push_token, platform)
  values (v_person, p_push_token, p_platform)
  on conflict (push_token)
  do update set person_id = v_person, last_seen_at = now();
end;
$$;

revoke all on function public.register_device(text, text) from public, anon;
grant execute on function public.register_device(text, text) to authenticated;
