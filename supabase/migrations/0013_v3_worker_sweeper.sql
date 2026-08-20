-- 0013 · The sweeper. One guarded step, and the two that carry consequences.
--
-- **The clock belongs to the server.** Every transition that depends on time
-- happens here, in a transaction, triggered by a worker that owns no state.
-- The client can do exactly two things to a hangout's state — the third yes
-- locks it, the first arrival makes it live — and both are in `0006`/`0011`
-- with their own guards. Everything else is below, because a client-driven
-- state machine means the last person to answer decides what the group's
-- evening becomes.
--
-- **`worker_advance` derives its own target.** It is told a hangout, not a
-- destination. The mill and the database would otherwise both hold a copy of
-- the transition table, and the day they disagreed the database would lose an
-- argument it should always win.
--
-- **No behavioural constant is a literal.** Group size, the infraction weights,
-- the edge weights and the arrival floor all arrive in `p_params`, resolved by
-- the mill from the config version in force, and that version id is copied onto
-- every row written here. `0004` requires the weight *as applied* for a reason:
-- recomputing it later from current config would silently rewrite history every
-- time a threshold moved, and somebody would be sanctioned for a pattern that
-- was never against the rules while they were doing it.

-- ─────────────────────────────────────────────────────────────────────────────
-- Where four people meet, chosen at lock rather than at match.
--
-- **Late on purpose** (`0003`). If somebody declines and is backfilled, the
-- replacement only has to reach the *cluster*; choosing a venue at match time
-- would mean re-choosing it every time the group changed.
--
-- The ranking is the one the transcript asked for: a place everybody can get
-- to, then the place our own outcome data likes best, then the closest. Note
-- what is not in it — no rating from anywhere else, no sponsorship, no
-- rotation for fairness to venues. This product owes venues nothing.
create or replace function public.worker_pick_meeting_point(
  p_hangout_id   uuid,
  p_max_travel_m integer
)
returns uuid
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_city   uuid;
  v_centre extensions.geography;
  v_size   integer;
  v_venue  uuid;
begin
  -- The grant is not the control (DP-5). This function is only reachable by
  -- `service_role` today, but a `security definer` function whose safety rests
  -- on nobody having granted it is one `grant execute` away from handing a
  -- phone the ability to reassign a group's meeting point.
  if auth.role() is distinct from 'service_role' then
    raise exception 'worker only' using errcode = '42501';
  end if;

  select h.city_id into v_city from public.hangouts h where h.id = p_hangout_id;

  -- The group's centre of gravity, which is what "closest" is measured from.
  -- Not any one person's anchor: ranking by distance to the seed would quietly
  -- make being drawn first worth something.
  select
    extensions.ST_Centroid(
      extensions.ST_Collect(p.home_anchor::extensions.geometry)
    )::extensions.geography,
    count(*)
  into v_centre, v_size
  from public.hangout_members m
  join public.people p on p.id = m.person_id
  where m.hangout_id = p_hangout_id and m.released_at is null;

  -- A cluster everybody can reach. `count(*) = v_size` is the "everybody" —
  -- a cluster three of four can reach is not a meeting point, it is an
  -- exclusion of the fourth.
  select v.id into v_venue
  from public.venues v
  join public.venue_clusters c on c.id = v.cluster_id
  where v.city_id = v_city
    and v.active
    and (
      select count(*)
      from public.hangout_members m
      join public.people p on p.id = m.person_id
      where m.hangout_id = p_hangout_id
        and m.released_at is null
        and extensions.ST_DWithin(c.centroid, p.home_anchor, p_max_travel_m)
    ) = v_size
  order by
    -- Our own signal first: "was it easy to find", "was it a good place to
    -- meet", asked after every hangout. Nulls last, so an unmeasured venue is
    -- tried after a good one and before a bad one.
    v.outcome_score desc nulls last,
    extensions.ST_Distance(v.location, v_centre) asc,
    v.id
  limit 1;

  -- Nobody shares a cluster. Rather than refuse the evening, fall back to the
  -- nearest active venue to the group's centre: a slightly awkward walk beats
  -- a cancellation, and the venue feedback will tell us if it was worse than
  -- that.
  if v_venue is null then
    select v.id into v_venue
    from public.venues v
    where v.city_id = v_city and v.active
    order by extensions.ST_Distance(v.location, v_centre) asc, v.id
    limit 1;
  end if;

  return v_venue;
end;
$$;

revoke all on function public.worker_pick_meeting_point(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.worker_pick_meeting_point(uuid, integer)
  to service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- The mark.
--
-- 24 symbols × 6 colours against a venue that will never hold more than a
-- handful of groups at once. **The surplus is the point**: collision avoidance
-- is a uniqueness constraint (`hangouts_sigil_unique`), and a constraint with a
-- tight domain fails by refusing to allocate. This function picks from what the
-- index would accept, so the insert never has to lose that race.
create or replace function public.worker_pick_sigil(
  p_venue_id uuid,
  p_slot_id  uuid
)
returns uuid
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_sigil uuid;
begin
  -- plpgsql rather than `language sql`, only so this line can exist: a `sql`
  -- body is one expression and cannot refuse anybody. The grant already limits
  -- this to the worker; DP-5 says the check is the control and the grant is
  -- the belt.
  if auth.role() is distinct from 'service_role' then
    raise exception 'worker only' using errcode = '42501';
  end if;

  select sg.id into v_sigil
  from public.sigils sg
  where sg.active
    and not exists (
      select 1 from public.hangouts h
      where h.meeting_point_id = p_venue_id
        and h.slot_id = p_slot_id
        and h.sigil_id = sg.id
    )
  -- Random rather than sequential: a city where every Thursday's first group is
  -- the red circle is a city where the mark stops being a mark.
  order by random()
  limit 1;

  return v_sigil;
end;
$$;

revoke all on function public.worker_pick_sigil(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.worker_pick_sigil(uuid, uuid) to service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- One step.
create or replace function public.worker_advance(
  p_hangout_id uuid,
  p_params     jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_state    public.hangout_state;
  v_slot     uuid;
  v_deadline timestamptz;
  v_backfill timestamptz;
  v_grace    timestamptz;
  v_min      integer := coalesce((p_params->>'min_group_size')::integer, 3);
  v_travel   integer := coalesce((p_params->>'max_travel_m')::integer, 6000);
  v_floor    integer := coalesce((p_params->>'min_arrivals')::integer, 2);
  v_version  uuid    := nullif(p_params->>'config_version', '')::uuid;
  v_weights  jsonb   := coalesce(p_params->'weights', '{}'::jsonb);
  v_yes      integer;
  v_size     integer;
  v_arrived  integer;
  v_venue    uuid;
  v_sigil    uuid;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'worker only' using errcode = '42501';
  end if;

  -- The row is locked before anything is read off it. Two sweeper runs
  -- overlapping is a normal condition — one of them is a retry after a
  -- timeout — and without this they both resolve the same confirmation and
  -- write the infractions twice.
  select h.state, h.slot_id, h.confirm_deadline_at, h.backfill_until,
         h.arrival_grace_until
    into v_state, v_slot, v_deadline, v_backfill, v_grace
  from public.hangouts h
  where h.id = p_hangout_id
  for update;

  if v_state is null then
    raise exception 'no such hangout' using errcode = '22023';
  end if;

  -- ── PLANNED → PROPOSED ────────────────────────────────────────────────────
  if v_state = 'PLANNED' then
    update public.hangouts set state = 'PROPOSED' where id = p_hangout_id;
    insert into public.hangout_events (hangout_id, type, config_version_id)
    values (p_hangout_id, 'PROPOSED', v_version);
    return jsonb_build_object('from', 'PLANNED', 'to', 'PROPOSED');
  end if;

  -- ── PROPOSED → CONFIRMING ─────────────────────────────────────────────────
  if v_state = 'PROPOSED' then
    update public.hangouts set state = 'CONFIRMING' where id = p_hangout_id;
    insert into public.hangout_events (hangout_id, type, config_version_id)
    values (p_hangout_id, 'CONFIRMING', v_version);
    return jsonb_build_object('from', 'PROPOSED', 'to', 'CONFIRMING');
  end if;

  -- ── CONFIRMING / BACKFILLING → LOCKED | BACKFILLING | CANCELLED ───────────
  if v_state in ('CONFIRMING', 'BACKFILLING') then
    -- **Silence is a third answer, not a missing one** (`0003`). Writing it
    -- down is what makes it chargeable, and what makes the person's own record
    -- readable later as something other than a gap.
    update public.hangout_members m
       set confirmation = 'silent'
     where m.hangout_id = p_hangout_id
       and m.released_at is null
       and m.confirmation is null;

    -- Infractions for this round, once. `on conflict` cannot help here because
    -- infractions have no natural key, so the guard is the `for update` above
    -- plus the fact that a hangout leaves this state in the same transaction.
    insert into public.infractions
      (person_id, which, type, weight, hangout_id, config_version_id)
    select
      m.person_id,
      'reliability',
      case
        when m.confirmation = 'silent' then 'CONFIRM_SILENT'
        when m.confirmed_at is not null and v_deadline is not null
             and m.confirmed_at > v_deadline then 'CONFIRM_DECLINE_LATE'
        else 'CONFIRM_DECLINE'
      end::public.infraction_type,
      case
        when m.confirmation = 'silent'
          then coalesce((v_weights->>'CONFIRM_SILENT')::numeric, 1.5)
        when m.confirmed_at is not null and v_deadline is not null
             and m.confirmed_at > v_deadline
          then coalesce((v_weights->>'CONFIRM_DECLINE_LATE')::numeric, 1)
        else coalesce((v_weights->>'CONFIRM_DECLINE')::numeric, 0.25)
      end,
      p_hangout_id,
      v_version
    from public.hangout_members m
    where m.hangout_id = p_hangout_id
      and m.released_at is null
      and m.confirmation in ('no', 'silent');

    select count(*) filter (where m.confirmation = 'yes'), count(*)
      into v_yes, v_size
    from public.hangout_members m
    where m.hangout_id = p_hangout_id and m.released_at is null;

    if v_yes >= v_min then
      -- Anybody who did not say yes leaves the group. The row is **released,
      -- never deleted**: a cancellation is input to trust and the event log has
      -- to stay answerable months later. Releasing also frees them to be
      -- matched into that slot again, which the partial unique index depends
      -- on.
      update public.hangout_members m
         set released_at = now()
       where m.hangout_id = p_hangout_id
         and m.released_at is null
         and m.confirmation is distinct from 'yes';

      v_venue := public.worker_pick_meeting_point(p_hangout_id, v_travel);
      v_sigil := case when v_venue is null then null
                      else public.worker_pick_sigil(v_venue, v_slot) end;

      update public.hangouts
         set state = 'LOCKED', meeting_point_id = v_venue, sigil_id = v_sigil
       where id = p_hangout_id;

      insert into public.hangout_events
        (hangout_id, type, payload, config_version_id)
      values (p_hangout_id, 'LOCKED',
              jsonb_build_object('venue', v_venue, 'sigil', v_sigil,
                                 'confirmed', v_yes), v_version);

      return jsonb_build_object('from', v_state, 'to', 'LOCKED',
                                'venue', v_venue, 'sigil', v_sigil);
    end if;

    -- Not enough yeses. One repair pass, and only if there is still time for a
    -- replacement to be asked and answer. Past that the honest thing is to
    -- cancel — **before anybody leaves home**, which is the whole reason the
    -- backfill window ends before the reveal.
    if v_state = 'CONFIRMING'
       and v_backfill is not null and v_backfill > now() then
      update public.hangout_members m
         set released_at = now()
       where m.hangout_id = p_hangout_id
         and m.released_at is null
         and m.confirmation in ('no', 'silent');

      update public.hangouts set state = 'BACKFILLING' where id = p_hangout_id;
      insert into public.hangout_events
        (hangout_id, type, payload, config_version_id)
      values (p_hangout_id, 'BACKFILLING',
              jsonb_build_object('confirmed', v_yes, 'needed', v_min),
              v_version);
      return jsonb_build_object('from', v_state, 'to', 'BACKFILLING',
                                'confirmed', v_yes);
    end if;

    update public.hangouts
       set state = 'CANCELLED',
           closed_at = now(),
           cancel_reason =
             'Not enough people could make it, and there was no time left to '
             'find somebody else. You are first in line for the next run.'
     where id = p_hangout_id;

    insert into public.hangout_events
      (hangout_id, type, payload, config_version_id)
    values (p_hangout_id, 'CANCELLED',
            jsonb_build_object('confirmed', v_yes, 'needed', v_min), v_version);

    return jsonb_build_object('from', v_state, 'to', 'CANCELLED',
                              'confirmed', v_yes);
  end if;

  -- ── LOCKED → REVEALED ─────────────────────────────────────────────────────
  if v_state = 'LOCKED' then
    -- A locked hangout with no meeting point would reveal a blank screen at the
    -- one moment somebody needs to know where to walk. Try once more before
    -- giving up on it.
    select h.meeting_point_id into v_venue
    from public.hangouts h where h.id = p_hangout_id;

    if v_venue is null then
      v_venue := public.worker_pick_meeting_point(p_hangout_id, v_travel);
      v_sigil := case when v_venue is null then null
                      else public.worker_pick_sigil(v_venue, v_slot) end;
      update public.hangouts
         set meeting_point_id = v_venue, sigil_id = v_sigil
       where id = p_hangout_id;
    end if;

    if v_venue is null then
      update public.hangouts
         set state = 'CANCELLED', closed_at = now(),
             cancel_reason =
               'We could not find a place everybody could get to. That is ours '
               'to fix, not yours.'
       where id = p_hangout_id;
      insert into public.hangout_events (hangout_id, type, config_version_id)
      values (p_hangout_id, 'CANCELLED', v_version);
      return jsonb_build_object('from', 'LOCKED', 'to', 'CANCELLED',
                                'why', 'no venue');
    end if;

    update public.hangouts set state = 'REVEALED' where id = p_hangout_id;
    insert into public.hangout_events (hangout_id, type, config_version_id)
    values (p_hangout_id, 'REVEALED', v_version);
    return jsonb_build_object('from', 'LOCKED', 'to', 'REVEALED');
  end if;

  -- ── LIVE → RATING | ABANDONED ─────────────────────────────────────────────
  if v_state = 'LIVE' then
    -- **Attendance is settled here and nowhere else.** `02_DOMAIN.md §4`:
    -- present means they tapped *and* nobody contradicted it, or a majority
    -- attests it. Both halves matter — the tap alone makes a lie free, and the
    -- attestations alone make the quiet person absent.
    update public.hangout_members m
       set arrival_attested = case
             when m.arrived_at is not null then (
               -- They tapped. Present unless the group says otherwise, and a
               -- tie goes to the person who was there: being contradicted by
               -- one of three is an argument, not a verdict.
               select count(*) filter (
                        where not (e.payload->>'present')::boolean)
                   <= count(*) filter (
                        where (e.payload->>'present')::boolean)
               from public.hangout_events e
               where e.hangout_id = p_hangout_id
                 and e.type = 'ATTESTED'
                 and (e.payload->>'subject')::uuid = m.person_id
             )
             else (
               -- They did not tap — a dead phone, or they were not there.
               -- Two people saying they were is what tells the two apart.
               select count(*) filter (
                        where (e.payload->>'present')::boolean) >= 2
               from public.hangout_events e
               where e.hangout_id = p_hangout_id
                 and e.type = 'ATTESTED'
                 and (e.payload->>'subject')::uuid = m.person_id
             )
           end
     where m.hangout_id = p_hangout_id
       and m.released_at is null;

    select count(*) into v_arrived
    from public.hangout_members m
    where m.hangout_id = p_hangout_id
      and m.released_at is null
      and coalesce(m.arrival_attested, m.arrived_at is not null);

    -- Below the floor, nothing is written. Two people who were stood up should
    -- not carry a record of the evening, and the people who did turn up must
    -- not be charged for the ones who did not.
    if v_arrived < v_floor then
      update public.hangouts
         set state = 'ABANDONED', closed_at = now()
       where id = p_hangout_id;
      insert into public.hangout_events
        (hangout_id, type, payload, config_version_id)
      values (p_hangout_id, 'ABANDONED',
              jsonb_build_object('arrived', v_arrived), v_version);
      return jsonb_build_object('from', 'LIVE', 'to', 'ABANDONED',
                                'arrived', v_arrived);
    end if;

    insert into public.infractions
      (person_id, which, type, weight, hangout_id, config_version_id)
    select
      m.person_id, 'reliability', 'NO_SHOW'::public.infraction_type,
      coalesce((v_weights->>'NO_SHOW')::numeric, 3), p_hangout_id, v_version
    from public.hangout_members m
    where m.hangout_id = p_hangout_id
      and m.released_at is null
      and m.confirmation = 'yes'
      and not coalesce(m.arrival_attested, m.arrived_at is not null);

    insert into public.infractions
      (person_id, which, type, weight, hangout_id, config_version_id)
    select
      m.person_id, 'reliability', 'LATE_ARRIVAL'::public.infraction_type,
      coalesce((v_weights->>'LATE_ARRIVAL')::numeric, 0.5),
      p_hangout_id, v_version
    from public.hangout_members m
    where m.hangout_id = p_hangout_id
      and m.released_at is null
      and m.arrived_at is not null
      and v_grace is not null
      and m.arrived_at > v_grace;

    update public.hangouts set state = 'RATING' where id = p_hangout_id;
    insert into public.hangout_events
      (hangout_id, type, payload, config_version_id)
    values (p_hangout_id, 'RATING',
            jsonb_build_object('arrived', v_arrived), v_version);
    return jsonb_build_object('from', 'LIVE', 'to', 'RATING',
                              'arrived', v_arrived);
  end if;

  -- ── RATING → CLOSED ───────────────────────────────────────────────────────
  if v_state = 'RATING' then
    insert into public.infractions
      (person_id, which, type, weight, hangout_id, config_version_id)
    select
      m.person_id, 'reliability', 'RATING_MISSED'::public.infraction_type,
      coalesce((v_weights->>'RATING_MISSED')::numeric, 0.5),
      p_hangout_id, v_version
    from public.hangout_members m
    where m.hangout_id = p_hangout_id
      and m.released_at is null
      and coalesce(m.arrival_attested, m.arrived_at is not null)
      and m.rated_at is null;

    -- **Edges are mutual or they do not exist.** A one-sided "I enjoyed them"
    -- creates nothing — not a weak edge, not a pending one. That is load-
    -- bearing for privacy rather than manners: if one-sided liking could pull
    -- somebody back, being re-matched would leak that they liked you, and *not*
    -- being re-matched would leak the opposite (`0004`).
    --
    -- The key is `(least, greatest)`, so there is no column that could hold a
    -- direction and no query that could recover who liked whom first.
    insert into public.edges (a_id, b_id, weight, meet_count, last_met_at)
    select
      least(r1.rater_id, r1.subject_id),
      greatest(r1.rater_id, r1.subject_id),
      case
        when r1.enjoyment = 'really_enjoyed' and r2.enjoyment = 'really_enjoyed'
          then coalesce((p_params->>'edge_strong')::numeric, 1)
        else coalesce((p_params->>'edge_warm')::numeric, 0.6)
      end,
      1,
      now()
    from public.ratings r1
    join public.ratings r2
      on r2.hangout_id = r1.hangout_id
     and r2.rater_id = r1.subject_id
     and r2.subject_id = r1.rater_id
    where r1.hangout_id = p_hangout_id
      and r1.rater_id < r1.subject_id
      and r1.enjoyment in ('enjoyed', 'really_enjoyed')
      and r2.enjoyment in ('enjoyed', 'really_enjoyed')
    on conflict (a_id, b_id) do update
      set weight = greatest(edges.weight, excluded.weight),
          meet_count = edges.meet_count + 1,
          last_met_at = excluded.last_met_at;

    -- The respect signal, which is one bit from three strangers and is treated
    -- as such: it feeds a posterior with a strong prior and is never shown to
    -- anybody, including its subject.
    insert into public.standing (person_id, respect_yes, respect_no)
    select
      r.subject_id,
      count(*) filter (where r.respect),
      count(*) filter (where not r.respect)
    from public.ratings r
    where r.hangout_id = p_hangout_id
    group by r.subject_id
    on conflict (person_id) do update
      set respect_yes = standing.respect_yes + excluded.respect_yes,
          respect_no  = standing.respect_no  + excluded.respect_no,
          computed_at = now();

    update public.hangouts
       set state = 'CLOSED', closed_at = now()
     where id = p_hangout_id;
    insert into public.hangout_events (hangout_id, type, config_version_id)
    values (p_hangout_id, 'CLOSED', v_version);

    return jsonb_build_object('from', 'RATING', 'to', 'CLOSED');
  end if;

  return jsonb_build_object('from', v_state, 'to', v_state, 'why', 'nothing due');
end;
$$;

revoke all on function public.worker_advance(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.worker_advance(uuid, jsonb) to service_role;
