-- v2 alignment, part 2 — the late name reveal and proposal expiry.
--
--   1. Names are not revealed at confirmation. A confirmed group first sees
--      only its *shape* — how many are coming, and the gender mix if it's
--      relevant to them. First names appear three hours before the meetup,
--      close enough to arrival that they're useful and too late to be used
--      for pre-judgement or a quiet last-minute filter.
--
--   2. A proposal that no group forms around should die on its own, quietly,
--      within a day — never linger as a stale "maybe" someone forgot to answer.

-- ─────────────────────────────────────────────────────────────────────────
-- Late name reveal
-- ─────────────────────────────────────────────────────────────────────────
-- Names only within three hours of the start. Also narrowed to people who
-- actually said yes — a confirmed meetup's attendees are its yeses, not
-- everyone who was ever invited.
create or replace function confirmed_attendees(m uuid)
  returns table (id uuid, first_name text)
  language sql stable security definer set search_path = public as $$
  select p.id, p.first_name
  from meetup_members mm
  join profiles p  on p.id = mm.user_id
  join meetups mt  on mt.id = mm.meetup_id
  where mm.meetup_id = m
    and mm.rsvp = 'yes'
    and is_confirmed(m)
    and is_member(m)
    and now() >= mt.starts_at - interval '3 hours';
$$;

-- The shape of a confirmed group, shown before the name reveal. Counts only —
-- never identities. Member-gated like everything else here.
create or replace function group_composition(m uuid)
  returns table (total int, women int, men int, other int)
  language sql stable security definer set search_path = public as $$
  select
    count(*)::int,
    count(*) filter (where p.gender = 'woman')::int,
    count(*) filter (where p.gender = 'man')::int,
    count(*) filter (where p.gender is null or p.gender not in ('woman', 'man'))::int
  from meetup_members mm
  join profiles p on p.id = mm.user_id
  where mm.meetup_id = m
    and mm.rsvp = 'yes'
    and is_confirmed(m)
    and is_member(m);
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 24-hour proposal expiry
-- ─────────────────────────────────────────────────────────────────────────
alter table meetups add column if not exists expires_at timestamptz;
alter table meetups alter column expires_at set default (now() + interval '24 hours');

-- Backfill still-open proposals so nothing hangs forever.
update meetups
  set expires_at = created_at + interval '24 hours'
  where expires_at is null and status in ('proposed', 'forming');

-- Cancel proposals nobody completed in time. Returns how many it swept, so a
-- scheduler can log it. service_role only; wire it to pg_cron in production:
--   select cron.schedule('expire-proposals', '*/15 * * * *',
--                         'select expire_stale_proposals()');
create or replace function expire_stale_proposals() returns int
  language sql security definer set search_path = public as $$
  with expired as (
    update meetups
      set status = 'cancelled'
    where status in ('proposed', 'forming')
      and expires_at is not null
      and now() > expires_at
    returning 1
  )
  select coalesce(count(*), 0)::int from expired;
$$;

revoke execute on function expire_stale_proposals() from anon, authenticated;
