-- 0014 · What the reveal screen needs, and what the home screen needs.
--
-- Two gaps found by writing the app against the real surface rather than
-- against a fake.
--
-- **The reveal was missing the only sentence that matters.** `hangout_reveal`
-- returned the venue's name and its coordinates. A name and a pin is not enough
-- to get four strangers to the same three metres: the screen's most-read line
-- is "Outside, at the tables on the left as you face the door", and there was
-- nowhere for it to come from. `venues.standing_spot` is that column, and
-- `venues.street` is the address a person reads out to a taxi driver.
--
-- Neither is written by hand. `tools/cartography/build_venues.py` generates
-- both from the OSM tags — hedged where the tags are ambiguous, because a
-- confident sentence about a terrace that is packed away for winter is worse
-- than one that admits it does not know. Writing 231 of these per city is
-- exactly the ongoing labour D11 forbids.
--
-- **The home screen was missing the person.** There was `my_state` (four words)
-- and `my_hangouts`, and nothing that answered "what is my name, where am I,
-- how many of these have I been to, is dating open yet". Four table reads
-- through four policies would have worked and would have put the dating-unlock
-- rule in the client, where rule 6 says a trust decision may never live.

-- ─────────────────────────────────────────────────────────────────────────────
alter table public.venues
  add column if not exists street text,
  -- The sentence the reveal prints. Bounded, because it is rendered into a
  -- fixed card on the most important screen in the product and a paragraph
  -- there would push the map off the fold.
  add column if not exists standing_spot text
    check (standing_spot is null or char_length(standing_spot) <= 240),
  add column if not exists outdoor_seating boolean not null default false;

-- ─────────────────────────────────────────────────────────────────────────────
-- The reveal, with the two columns it always needed.
--
-- The two checks from 0006 are unchanged and both still load-bearing (DP-7):
-- the caller is a member, and `now() >= reveal_at`. The time gate is enforced
-- here rather than by hiding a screen, because a client that merely hides it
-- has still received the data, and the person who patches the client is exactly
-- the adversary this product's mechanism rests on defeating (T1).
--
-- **`walk_minutes` is computed from the caller's own anchor**, and it is the
-- only place a person's anchor is ever turned into something visible — to
-- themselves, about a venue, never about another person (`05_PLACES.md §2`).
-- 80 metres a minute is an ordinary walking pace and the number is rounded up:
-- being early is free and being late is an infraction.
--
-- `create or replace` cannot widen a `returns table (...)`, so both of the
-- rewritten functions below are dropped first. That is safe here and would not
-- be for a table: rule 10 forbids dropping a *trust or audit* table, because
-- infractions, sanctions, reports and event logs are evidence. A function is
-- code, and its grants are re-issued on the next line.
drop function if exists public.hangout_reveal(uuid);

create function public.hangout_reveal(p_hangout_id uuid)
returns table (
  person_id     uuid,
  first_name    text,
  last_initial  text,
  gender_code   text,
  is_me         boolean,
  arrived       boolean,
  venue_name    text,
  venue_street  text,
  standing_spot text,
  opening_hours text,
  step_free     boolean,
  outdoor       boolean,
  walk_minutes  integer,
  venue_lat     double precision,
  venue_lon     double precision,
  sigil_symbol  text,
  sigil_colour  text,
  sigil_label   text
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_person uuid := public.current_person_id();
  v_ready  boolean;
  v_anchor extensions.geography;
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

  select p.home_anchor into v_anchor
  from public.people p where p.id = v_person;

  return query
  select
    p.id,
    p.first_name,
    p.last_initial,
    p.gender_code,
    (p.id = v_person),
    (m.arrived_at is not null),
    v.name,
    v.street,
    v.standing_spot,
    v.opening_hours,
    v.step_free,
    v.outdoor_seating,
    case
      when v.location is null or v_anchor is null then null
      else greatest(
        1,
        ceil(extensions.ST_Distance(v.location, v_anchor) / 80.0)::integer
      )
    end,
    extensions.ST_Y(v.location::extensions.geometry),
    extensions.ST_X(v.location::extensions.geometry),
    sg.symbol,
    sg.colour,
    sg.label_hr
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
-- Who the caller is, in the shape the app renders.
--
-- **`dating_unlocked` is decided here.** It is a *rule*, and rule 6 says a rule
-- the UI acts on has to be one the server also refuses on. A client that
-- computed "four completed, so show the dating tab" would show it to anybody
-- who patched the number — and, worse, the real gate would then have to exist
-- twice, in two languages, and drift.
--
-- **`completed_hangouts` is the only count this product shows a person about
-- themselves**, and only because it is what the dating tab is waiting for.
-- There is no streak, no score, no badge: standing is service-role only
-- (invariant 7), and a visible trust score becomes a status game inside a week.
create or replace function public.my_profile()
returns table (
  person_id          uuid,
  first_name         text,
  last_initial       text,
  gender_code        text,
  city_id            uuid,
  city_name          text,
  has_anchor         boolean,
  anchor_lat         double precision,
  anchor_lon         double precision,
  completed_hangouts integer,
  dating_unlocked    boolean,
  equipment          text[]
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_person uuid := public.current_person_id();
  v_done   integer;
begin
  if v_person is null then
    raise exception 'no person for this session' using errcode = '42501';
  end if;

  select count(*)::integer into v_done
  from public.hangout_members m
  join public.hangouts h on h.id = m.hangout_id
  where m.person_id = v_person
    and m.released_at is null
    and h.state = 'CLOSED';

  return query
  select
    p.id,
    p.first_name,
    p.last_initial,
    p.gender_code,
    p.city_id,
    c.name,
    (p.home_anchor is not null),
    extensions.ST_Y(p.home_anchor::extensions.geometry),
    extensions.ST_X(p.home_anchor::extensions.geometry),
    v_done,
    -- Four, from `00_BIBLE.md`: the dating layer opens after enough hangouts
    -- that a person has a graph to draw on, and early enough that it does not
    -- feel like a grind. It is a threshold a product decision could move, so
    -- it belongs in config — and it is a literal here only until the worker
    -- publishes a version, which is the same compromise `my_slots` makes.
    (v_done >= 4),
    coalesce(
      (select array_agg(pe.equipment_code order by pe.equipment_code)
         from public.person_equipment pe where pe.person_id = p.id),
      '{}'::text[]
    )
  from public.people p
  join public.cities c on c.id = p.city_id
  where p.id = v_person;
end;
$$;

revoke all on function public.my_profile() from public, anon;
grant execute on function public.my_profile() to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- The hangout list, with the activity's own words.
--
-- `my_hangouts` returned an `activity_id` and left the app to know what
-- `CONVERSATION_DECK` means. That put product copy in the client with no way to
-- change it without a release, and it would have to be duplicated in the
-- console. The label comes from the catalogue instead.
--
-- Still deliberately absent, exactly as in 0006: **who**, and **where**. Names
-- appear at T−60m and not before, because early names invite pre-judgement and
-- quiet last-minute filtering — which is both unkind and the exact failure a
-- product about not being screened cannot have. A venue plus a time is enough
-- for somebody to turn up uninvited.
drop function if exists public.my_hangouts();

create function public.my_hangouts()
returns table (
  hangout_id      uuid,
  state           public.hangout_state,
  starts_at       timestamptz,
  ends_at         timestamptz,
  activity_id     text,
  activity_label  text,
  is_dating       boolean,
  member_count    integer,
  gender_mix      jsonb,
  my_confirmation public.confirmation,
  i_arrived       boolean,
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
    at.label_en,
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
    (me.arrived_at is not null),
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
  left join public.activity_templates at on at.id = h.activity_id
  where me.person_id = v_person
    and me.released_at is null
    and h.state <> 'PLANNED'
  order by s.starts_at;
end;
$$;

revoke all on function public.my_hangouts() from public, anon;
grant execute on function public.my_hangouts() to authenticated;
