-- 0012 · The worker's surface. Service role only, and nothing else on earth.
--
-- **Zone 2 (`11_SECURITY.md §3).** The mill has no inbound port and no URL. It
-- is invoked by a scheduler, calls the four functions below, and exits. The
-- service-role key it uses exists in exactly one place — the worker's secret
-- manager — and never in a Flutter build, a `--dart-define`, the console
-- client, a CI log, or this repository.
--
-- Every function here is revoked from `authenticated` as well as from `anon`
-- and `public`. That is not belt-and-braces: the console shares one auth realm
-- with the app, so `authenticated` is a role a phone holds, and a worker
-- function granted to it would be a phone that can read the whole city.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- **Why a snapshot rather than a connection.**
--
-- `MatchPlan run(MatchSnapshot, MatchConfig, seed)` is a value-in / value-out
-- transform (D3). That property is what lets the same function run in the
-- worker, in a unit test, in the simulator over a synthetic city, and in the
-- console as a dry-run against live data — and it is what makes "why was I put
-- in that group?" answerable months later, by replaying the recorded snapshot
-- hash and seed.
--
-- A matcher holding a database connection would end all of that. So the worker
-- takes **one** consistent read, hands it to a pure function, and posts the
-- answer back. `worker_snapshot` is that read.
--
-- **No behavioural constant is a literal here** (D5). `p_max_travel_m`,
-- `p_cooldown_days` and the horizon arrive as parameters, resolved by the mill
-- from the config version it is running under, and the same version id is
-- recorded on the run. A number baked into this file would be a number the
-- console cannot move and history cannot explain.

-- ─────────────────────────────────────────────────────────────────────────────
-- One consistent read of everything a match run depends on.
create or replace function public.worker_snapshot(
  p_city_id       uuid,
  p_from          timestamptz,
  p_to            timestamptz,
  p_max_travel_m  integer,
  p_history_days  integer default 120
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_out jsonb;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'worker only' using errcode = '42501';
  end if;

  with
  -- Who is in scope: everybody in the city who is available for at least one
  -- slot in the window. Suspended and banned people are *included*, with their
  -- tier, rather than filtered out here — the matcher's eligibility stage owns
  -- that decision and records it in the funnel, so "twelve filtered by
  -- standing" is a number the console can show instead of a silence.
  slots as (
    select s.id, s.city_id, s.starts_at, s.ends_at
    from public.slots s
    where s.city_id = p_city_id
      and s.starts_at >= p_from
      and s.starts_at < p_to
  ),
  scope as (
    select distinct a.person_id
    from public.availability a
    join slots s on s.id = a.slot_id
  ),
  folk as (
    select
      p.id,
      p.gender_code,
      p.city_id,
      extensions.ST_Y(p.home_anchor::extensions.geometry) as lat,
      extensions.ST_X(p.home_anchor::extensions.geometry) as lon,
      coalesce(st.tier, 'GOOD')          as tier,
      coalesce(st.respect_yes, 0)        as respect_yes,
      coalesce(st.respect_no, 0)         as respect_no,
      p.joined_at,
      p.home_anchor
    from public.people p
    join scope on scope.person_id = p.id
    left join public.standing st on st.person_id = p.id
    where p.deleted_at is null
  ),
  -- What each person has done, which is what `weeks_waiting` and `completed`
  -- are made of. Counted from CLOSED hangouts only: a cancelled evening is not
  -- an evening, and counting it would quietly starve somebody whose group fell
  -- apart twice.
  done as (
    select
      m.person_id,
      count(*) filter (where h.state = 'CLOSED') as completed,
      max(s.ends_at) filter (where h.state = 'CLOSED') as last_at
    from public.hangout_members m
    join public.hangouts h on h.id = m.hangout_id
    join public.slots s on s.id = h.slot_id
    where m.person_id in (select person_id from scope)
    group by m.person_id
  ),
  -- Reachable clusters. **This is where "anywhere in town, ranked by closest"
  -- becomes a set.** The radius is a city property (`geo.max_travel_m`), not a
  -- preference we asked anybody for — see `LifecycleKeys.maxTravelMetres`.
  reach as (
    select f.id as person_id,
           coalesce(
             jsonb_agg(vc.id::text order by
                       extensions.ST_Distance(vc.centroid, f.home_anchor))
               -- The filter, not just the coalesce. A left join with no match
               -- aggregates to `[null]`, which is a list of one unreachable
               -- cluster rather than an empty one — and the matcher would read
               -- it as "these two share a cluster" for every pair with no
               -- clusters at all.
               filter (where vc.id is not null),
             '[]'::jsonb) as clusters
    from folk f
    left join public.venue_clusters vc
      on vc.city_id = p_city_id
     and extensions.ST_DWithin(vc.centroid, f.home_anchor, p_max_travel_m)
    group by f.id
  ),
  -- A throttled person gets one seat, not none. R2 on the sanction ladder is
  -- deliberately something a falsely-accused person barely feels
  -- (`04_TRUST.md §4.3`), so it is a quota rather than an exclusion.
  quota as (
    select sn.person_id, 1 as remaining
    from public.sanctions sn
    where sn.kind = 'THROTTLE'
      and sn.overturned_at is null
      and sn.starts_at <= now()
      and (sn.ends_at is null or sn.ends_at > now())
    group by sn.person_id
  ),
  -- **The rating gate.** Somebody who owes ratings on a closed hangout is not
  -- matched again until they answer. Expressed as a zero quota rather than as
  -- a filter, so it lands in the same funnel bucket the console already shows.
  owing as (
    select distinct m.person_id
    from public.hangout_members m
    join public.hangouts h on h.id = m.hangout_id
    where h.state in ('RATING', 'CLOSED')
      and m.released_at is null
      and m.arrived_at is not null
      and m.rated_at is null
      and h.rating_due_at is not null
  )
  select jsonb_build_object(
    'city', p_city_id,
    'taken_at', to_jsonb(now()),
    'slots', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', s.id, 'city', s.city_id,
        'starts_at', s.starts_at, 'ends_at', s.ends_at
      ) order by s.starts_at), '[]'::jsonb) from slots s
    ),
    'people', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', f.id,
        'gender', f.gender_code,
        'city', f.city_id,
        'lat', f.lat,
        'lon', f.lon,
        'clusters', r.clusters,
        'tier', lower(f.tier::text),
        'respect_yes', f.respect_yes,
        'respect_no', f.respect_no,
        'remaining_quota', case
          when f.id in (select person_id from owing) then 0
          else (select q.remaining from quota q where q.person_id = f.id)
        end,
        'completed', coalesce(d.completed, 0),
        'weeks_waiting', greatest(
          0,
          floor(extract(epoch from
            now() - coalesce(d.last_at, f.joined_at)) / 604800)::integer
        ),
        'equipment', (
          select coalesce(jsonb_agg(pe.equipment_code), '[]'::jsonb)
          from public.person_equipment pe where pe.person_id = f.id
        ),
        'activities', (
          select coalesce(jsonb_agg(pa.activity_id), '[]'::jsonb)
          from public.person_activities pa where pa.person_id = f.id
        )
      ) order by f.id), '[]'::jsonb)
      from folk f
      join reach r on r.person_id = f.id
      left join done d on d.person_id = f.id
    ),
    'availability', (
      select coalesce(jsonb_object_agg(x.slot_id, x.people), '{}'::jsonb)
      from (
        select a.slot_id::text as slot_id,
               jsonb_agg(a.person_id order by a.person_id) as people
        from public.availability a
        join slots s on s.id = a.slot_id
        where a.person_id in (select id from folk)
        group by a.slot_id
      ) x
    ),
    -- Edges and exclusions are restricted to pairs **both of whom are in
    -- scope**. The matcher has no use for the rest, and a snapshot that
    -- carried the city's whole graph would be a file on a worker's disk
    -- containing the friend graph of everybody who did not even sign up for
    -- this week.
    'edges', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'a', e.a_id, 'b', e.b_id, 'weight', e.weight,
        'meet_count', e.meet_count, 'last_met_at', e.last_met_at
      ) order by e.a_id, e.b_id), '[]'::jsonb)
      from public.edges e
      where e.a_id in (select id from folk) and e.b_id in (select id from folk)
    ),
    'exclusions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'a', x.a_id, 'b', x.b_id, 'reason', x.reason
      ) order by x.a_id, x.b_id), '[]'::jsonb)
      from public.exclusions x
      where x.a_id in (select id from folk) and x.b_id in (select id from folk)
    ),
    -- History drives both cooldown clocks. Ordered oldest first, because
    -- `MatchSnapshot.interveningHangoutsSince` counts forward from the last
    -- time a pair met and a reversed list would report every cooldown as
    -- satisfied.
    'history', (
      select coalesce(jsonb_agg(h.entry order by h.ended_at), '[]'::jsonb)
      from (
        select
          s.ends_at as ended_at,
          jsonb_build_object(
            'ended_at', s.ends_at,
            'members', jsonb_agg(m.person_id order by m.person_id)
          ) as entry
        from public.hangouts hh
        join public.slots s on s.id = hh.slot_id
        join public.hangout_members m on m.hangout_id = hh.id
        where hh.city_id = p_city_id
          and hh.state = 'CLOSED'
          and s.ends_at > now() - make_interval(days => p_history_days)
          and m.released_at is null
        group by hh.id, s.ends_at
      ) h
    ),
    -- Placed in an earlier run for the same week. Without this, a second run
    -- on the same day would double-book people — the unique index would catch
    -- it, but as a failed insert rather than as a plan that never proposed it.
    'already_placed', (
      select coalesce(jsonb_object_agg(x.person_id, x.slots), '{}'::jsonb)
      from (
        select m.person_id::text as person_id,
               jsonb_agg(m.slot_id order by m.slot_id) as slots
        from public.hangout_members m
        join slots s on s.id = m.slot_id
        where m.released_at is null
        group by m.person_id
      ) x
    )
  ) into v_out;

  return v_out;
end;
$$;

revoke all on function public.worker_snapshot(
  uuid, timestamptz, timestamptz, integer, integer
) from public, anon, authenticated;
grant execute on function public.worker_snapshot(
  uuid, timestamptz, timestamptz, integer, integer
) to service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- The plan, written in one transaction.
--
-- **Either the whole run lands or none of it does.** A half-written plan is the
-- worst artefact this system can produce: some people have a hangout, some
-- people are in a group of two, and the next run sees an inconsistent world and
-- makes it worse. The mill is stateless and disposable precisely because this
-- function is atomic — if the worker dies mid-post, the next run recomputes
-- from a database that never saw the partial answer.
--
-- **Every deadline arrives as an absolute timestamp**, computed by the mill
-- from the config version in force. `0003` requires all seven to be written at
-- creation for exactly one reason: a mid-day config change must never move a
-- deadline somebody is already inside.
--
-- Groups that collide with the one-hangout-per-slot index are **skipped, not
-- failed**. Two runs racing, or a repair pass overlapping a daily run, is a
-- normal condition; losing the other eleven groups over it is not.
create or replace function public.worker_commit_plan(p_plan jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_run       uuid;
  v_city      uuid := (p_plan->>'city')::uuid;
  v_group     jsonb;
  v_member    jsonb;
  v_hangout   uuid;
  v_written   integer := 0;
  v_skipped   integer := 0;
  v_hangouts  jsonb := '[]'::jsonb;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'worker only' using errcode = '42501';
  end if;
  if v_city is null then
    raise exception 'a plan needs a city' using errcode = '22023';
  end if;

  insert into public.match_runs (
    city_id, kind, seed, snapshot_hash, config_version_id, stats,
    finished_at, status
  )
  values (
    v_city,
    coalesce(p_plan->>'kind', 'daily'),
    (p_plan->>'seed')::bigint,
    coalesce(p_plan->>'snapshot_hash', ''),
    nullif(p_plan->>'config_version', '')::uuid,
    coalesce(p_plan->'stats', '{}'::jsonb),
    now(),
    'succeeded'
  )
  returning id into v_run;

  for v_group in select * from jsonb_array_elements(p_plan->'groups')
  loop
    begin
      insert into public.hangouts (
        slot_id, city_id, state, composition_rule, seed_person_id, activity_id,
        match_run_id, config_version_id, is_dating,
        confirm_opens_at, confirm_deadline_at, backfill_until, reveal_at,
        arrival_grace_until, late_report_until, rating_due_at
      )
      values (
        (v_group->>'slot')::uuid,
        v_city,
        'PLANNED',
        coalesce(v_group->>'composition_rule', 'NO_LONE_GENDER'),
        nullif(v_group->>'seed_person', '')::uuid,
        v_group->>'activity',
        v_run,
        nullif(p_plan->>'config_version', '')::uuid,
        coalesce((v_group->>'is_dating')::boolean, false),
        (v_group->>'confirm_opens_at')::timestamptz,
        (v_group->>'confirm_deadline_at')::timestamptz,
        (v_group->>'backfill_until')::timestamptz,
        (v_group->>'reveal_at')::timestamptz,
        (v_group->>'arrival_grace_until')::timestamptz,
        (v_group->>'late_report_until')::timestamptz,
        (v_group->>'rating_due_at')::timestamptz
      )
      returning id into v_hangout;

      for v_member in select * from jsonb_array_elements(v_group->'members')
      loop
        insert into public.hangout_members (
          hangout_id, person_id, slot_id, slot_role,
          ring_intended, ring_realised, via_person_id
        )
        values (
          v_hangout,
          (v_member->>'person')::uuid,
          (v_group->>'slot')::uuid,
          (v_member->>'role')::public.slot_role,
          nullif(v_member->>'ring_intended', '')::public.ring,
          nullif(v_member->>'ring_realised', '')::public.ring,
          nullif(v_member->>'via', '')::uuid
        );
      end loop;

      -- Why this group looks the way it does. **It cannot be reconstructed
      -- later**, so it is written now rather than after the first question
      -- about one.
      insert into public.match_run_groups (
        match_run_id, hangout_id, seed_person_id, ring_mix, rejected_alternates
      )
      values (
        v_run, v_hangout, nullif(v_group->>'seed_person', '')::uuid,
        coalesce(v_group->'ring_mix', '{}'::jsonb),
        coalesce(v_group->'rejected_alternates', '[]'::jsonb)
      );

      insert into public.hangout_events (hangout_id, type, payload)
      values (v_hangout, 'PLANNED',
              jsonb_build_object('run', v_run, 'seed', p_plan->'seed'));

      v_written := v_written + 1;
      v_hangouts := v_hangouts || to_jsonb(v_hangout::text);
    exception
      when unique_violation then
        -- Somebody in this group was already placed in this slot by another
        -- run. The index is the authority; this loop just declines to argue
        -- with it.
        v_skipped := v_skipped + 1;
    end;
  end loop;

  return jsonb_build_object(
    'run', v_run, 'written', v_written, 'skipped', v_skipped,
    'hangouts', v_hangouts
  );
end;
$$;

revoke all on function public.worker_commit_plan(jsonb)
  from public, anon, authenticated;
grant execute on function public.worker_commit_plan(jsonb) to service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- What the clock says is due.
--
-- The sweeper reads this every few minutes, forever. It is deliberately a
-- *query*, separate from the transition that follows it, so that a run which
-- dies between the two does nothing at all rather than something partial.
--
-- The partial indexes in `0003` exist for this function: it reads the handful
-- of rows that are actually due rather than the table.
create or replace function public.worker_due(p_limit integer default 200)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'worker only' using errcode = '42501';
  end if;

  return (
    select coalesce(jsonb_agg(x order by x->>'due_at'), '[]'::jsonb)
    from (
      select jsonb_build_object(
        'hangout', h.id, 'state', h.state, 'next', v.next, 'due_at', v.due_at
      ) as x
      from public.hangouts h
      cross join lateral (
        select
          case h.state
            when 'PLANNED'     then 'PROPOSED'
            when 'PROPOSED'    then 'CONFIRMING'
            when 'CONFIRMING'  then 'RESOLVE'
            when 'BACKFILLING' then 'RESOLVE'
            when 'LOCKED'      then 'REVEALED'
            when 'LIVE'        then 'RATING'
            when 'RATING'      then 'CLOSED'
          end as next,
          case h.state
            -- A planned hangout is told to its members immediately: it exists,
            -- and the only reason to hold it back is a dry run.
            when 'PLANNED'     then h.created_at
            when 'PROPOSED'    then h.confirm_opens_at
            when 'CONFIRMING'  then h.confirm_deadline_at
            when 'BACKFILLING' then h.backfill_until
            when 'LOCKED'      then h.reveal_at
            when 'LIVE'        then h.late_report_until
            when 'RATING'      then h.rating_due_at
          end as due_at
      ) v
      where v.due_at is not null
        and v.due_at <= now()
        and h.state in ('PLANNED', 'PROPOSED', 'CONFIRMING', 'BACKFILLING',
                        'LOCKED', 'LIVE', 'RATING')
      limit p_limit
    ) q
  );
end;
$$;

revoke all on function public.worker_due(integer)
  from public, anon, authenticated;
grant execute on function public.worker_due(integer) to service_role;
