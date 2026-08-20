-- 0006 · The client's entire read and write surface.
--
-- Every function here follows DP-5 without exception: a caller check as the
-- **first statement**, `set search_path`, and grants revoked from the role
-- names rather than from `PUBLIC`.
--
-- That last one is the most valuable single lesson carried out of v1. Supabase
-- writes `EXECUTE` grants to `anon` and `authenticated` as explicit per-role ACL
-- entries, so `revoke ... from public` is a **silent no-op**. Migration `0003`
-- of the old project believed it had locked its RPC surface; it had not, and
-- `0004` discovered it. The code is gone, the lesson is here.
--
-- The cardinal rule these implement (11_SECURITY.md §2): everything the app
-- sends is a claim by an attacker who happens to be a user. Nothing the app
-- displays is a permission.

-- ─────────────────────────────────────────────────────────────────────────────
-- Am I in this hangout? The predicate every function below opens with.
create or replace function public.is_member(p_hangout_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.hangout_members m
    where m.hangout_id = p_hangout_id
      and m.person_id = public.current_person_id()
      and m.released_at is null
  )
$$;

revoke all on function public.is_member(uuid) from public, anon;
grant execute on function public.is_member(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- What a person may know about their own hangouts **before** the reveal: that
-- it exists, when it is, how many people, the gender mix, and what they
-- themselves answered.
--
-- Deliberately absent: who. Names appear at T−60m and not before, because early
-- names invite pre-judgement and quiet last-minute filtering — which is both
-- unkind and the exact failure mode a product about not being screened cannot
-- have. Also absent: the meeting point, for the same reason plus one more —
-- a venue plus a time is enough for someone to turn up uninvited.
create or replace function public.my_hangouts()
returns table (
  hangout_id      uuid,
  state           public.hangout_state,
  starts_at       timestamptz,
  ends_at         timestamptz,
  activity_id     text,
  is_dating       boolean,
  member_count    integer,
  gender_mix      jsonb,
  my_confirmation public.confirmation,
  confirm_opens_at    timestamptz,
  confirm_deadline_at timestamptz,
  reveal_at       timestamptz,
  rating_due_at   timestamptz,
  names_visible   boolean,
  cancel_reason   text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_person uuid := public.current_person_id();
begin
  if v_person is null then
    raise exception 'not a member' using errcode = '42501';
  end if;

  return query
  select
    h.id,
    h.state,
    s.starts_at,
    s.ends_at,
    h.activity_id,
    h.is_dating,
    (select count(*)::integer
       from public.hangout_members m2
      where m2.hangout_id = h.id and m2.released_at is null),
    (select coalesce(jsonb_object_agg(g.gender_code, g.n), '{}'::jsonb)
       from (select p2.gender_code, count(*) as n
               from public.hangout_members m3
               join public.people p2 on p2.id = m3.person_id
              where m3.hangout_id = h.id and m3.released_at is null
              group by p2.gender_code) g),
    me.confirmation,
    h.confirm_opens_at,
    h.confirm_deadline_at,
    h.reveal_at,
    h.rating_due_at,
    (h.reveal_at is not null and now() >= h.reveal_at
      and h.state in ('REVEALED', 'LIVE', 'RATING', 'CLOSED')),
    h.cancel_reason
  from public.hangout_members me
  join public.hangouts h on h.id = me.hangout_id
  join public.slots s on s.id = h.slot_id
  where me.person_id = v_person
    and me.released_at is null
  order by s.starts_at;
end;
$$;

revoke all on function public.my_hangouts() from public, anon;
grant execute on function public.my_hangouts() to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- The reveal. The only cross-person read in the system, and the only place a
-- meeting point is disclosed.
--
-- Two checks, and both are load-bearing (DP-7):
--   * the caller is a member — otherwise anyone with a hangout id reads a group
--   * `now() >= reveal_at` — the time gate is enforced *here*, on the server,
--     because a client that merely hides the screen still received the data,
--     and the person who patches the client is exactly the adversary this
--     product's whole mechanism rests on defeating (T1).
--
-- Names come back as first name and last initial, never as a formatted string.
-- The `Marko ····n` mask is a domain rule and lives in exactly one place, the
-- `DisplayName` value object; a second implementation in SQL is a second place
-- for it to be wrong.
create or replace function public.hangout_reveal(p_hangout_id uuid)
returns table (
  person_id    uuid,
  first_name   text,
  last_initial text,
  gender_code  text,
  is_me        boolean,
  arrived      boolean,
  venue_name   text,
  venue_lat    double precision,
  venue_lon    double precision,
  sigil_symbol text,
  sigil_colour text
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_person uuid := public.current_person_id();
  v_ready  boolean;
begin
  if v_person is null or not public.is_member(p_hangout_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select (h.reveal_at is not null
          and now() >= h.reveal_at
          and h.state in ('REVEALED', 'LIVE', 'RATING', 'CLOSED'))
    into v_ready
  from public.hangouts h
  where h.id = p_hangout_id;

  if not coalesce(v_ready, false) then
    raise exception 'not revealed yet' using errcode = '42501';
  end if;

  return query
  select
    p.id,
    p.first_name,
    p.last_initial,
    p.gender_code,
    (p.id = v_person),
    (m.arrived_at is not null),
    v.name,
    extensions.ST_Y(v.location::extensions.geometry),
    extensions.ST_X(v.location::extensions.geometry),
    sg.symbol,
    sg.colour
  from public.hangout_members m
  join public.people p on p.id = m.person_id
  join public.hangouts h on h.id = m.hangout_id
  left join public.venues v on v.id = h.meeting_point_id
  left join public.sigils sg on sg.id = h.sigil_id
  where m.hangout_id = p_hangout_id
    and m.released_at is null
  order by (p.id = v_person) desc, p.first_name;
end;
$$;

revoke all on function public.hangout_reveal(uuid) from public, anon;
grant execute on function public.hangout_reveal(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Availability. A whole-week replace rather than per-slot toggles, so the app
-- never has to reason about partial failure and the server never has to reason
-- about ordering.
create or replace function public.set_availability(p_slot_ids uuid[])
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

  select city_id into v_city from public.people where id = v_person;

  -- The claim is "these are my slots". The server verifies that each one
  -- exists, is in the future, and belongs to the caller's city — a client can
  -- send any uuid it likes, including a slot in a denser city.
  delete from public.availability a
  where a.person_id = v_person
    and a.slot_id in (
      select s.id from public.slots s
      where s.city_id = v_city and s.starts_at > now()
    );

  insert into public.availability (person_id, slot_id, source)
  select v_person, s.id, 'manual'
  from public.slots s
  where s.id = any(p_slot_ids)
    and s.city_id = v_city
    and s.starts_at > now()
  on conflict do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.set_availability(uuid[]) from public, anon;
grant execute on function public.set_availability(uuid[]) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- The morning-of confirmation.
--
-- `for update` on the hangout row before counting members is not defensive
-- programming, it is a bug already paid for once: in v1, simultaneous yeses
-- lost updates because the parent was never locked. The same shape recurs here,
-- and the fix is already known.
create or replace function public.confirm_hangout(
  p_hangout_id uuid,
  p_coming     boolean
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
  v_deadline timestamptz;
  v_yes    integer;
  v_size   integer;
begin
  if v_person is null or not public.is_member(p_hangout_id) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select h.state, h.confirm_deadline_at
    into v_state, v_deadline
  from public.hangouts h
  where h.id = p_hangout_id
  for update;

  if v_state not in ('CONFIRMING', 'BACKFILLING') then
    raise exception 'not open for confirmation' using errcode = '22023';
  end if;
  if v_deadline is not null and now() > v_deadline then
    raise exception 'confirmation window has closed' using errcode = '22023';
  end if;

  update public.hangout_members m
     set confirmation = (case when p_coming then 'yes' else 'no' end)::public.confirmation,
         confirmed_at = now()
   where m.hangout_id = p_hangout_id
     and m.person_id = v_person;

  insert into public.hangout_events (hangout_id, type, payload, actor_person_id)
  values (
    p_hangout_id,
    case when p_coming then 'CONFIRMED' else 'DECLINED' end,
    '{}'::jsonb,
    v_person
  );

  select count(*) filter (where m.confirmation = 'yes'), count(*)
    into v_yes, v_size
  from public.hangout_members m
  where m.hangout_id = p_hangout_id and m.released_at is null;

  -- Locking happens only when everyone has said yes. Every other transition —
  -- a decline opening backfill, a deadline turning silence into information,
  -- the cancellation that keeps three people from a wasted trip — belongs to
  -- the sweeper, which owns the clock. A client-triggered state machine would
  -- mean the last person to answer decides what the group's evening becomes.
  if p_coming and v_yes = v_size and v_state = 'CONFIRMING' then
    update public.hangouts set state = 'LOCKED' where id = p_hangout_id;
    v_state := 'LOCKED';
  end if;

  return v_state;
end;
$$;

revoke all on function public.confirm_hangout(uuid, boolean) from public, anon;
grant execute on function public.confirm_hangout(uuid, boolean) to authenticated;
