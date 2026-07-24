-- v2 alignment, part 1 — identity minimalism and the four-level reflection.
--
-- Two product decisions from the v2 spec land here:
--
--   1. A first name is the ONLY thing one member ever learns about another.
--      The system-written "blurb" is gone: it was a soft profile, and soft
--      profiles invite exactly the pre-judgement this product exists to avoid.
--      The dead `emoji` column on meetups goes with it.
--
--   2. "Would you meet again?" was a yes/no. It becomes a four-level feeling:
--        really_enjoyed · enjoyed · no_preference · rather_not
--      A future group is seeded only from *mutual* warmth (both people at
--      enjoyed or above). `rather_not` is a silent, permanent "never compose
--      us again" — the other person is never told, and it can't be undone by
--      accident, so it lives in its own `exclusions` table.

-- ─────────────────────────────────────────────────────────────────────────
-- Identity minimalism
-- ─────────────────────────────────────────────────────────────────────────
alter table profiles drop column if exists blurb;
alter table meetups  drop column if exists emoji;

-- Attendees on a confirmed meetup — first name only, no blurb. This is still
-- the ONLY path by which one user learns anything about another.
create or replace function confirmed_attendees(m uuid)
  returns table (id uuid, first_name text)
  language sql stable security definer set search_path = public as $$
  select p.id, p.first_name
  from meetup_members mm
  join profiles p on p.id = mm.user_id
  where mm.meetup_id = m
    and is_confirmed(m)
    and is_member(m);
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Four-level reflection
-- ─────────────────────────────────────────────────────────────────────────
alter table reflections
  add column if not exists sentiment text
    check (sentiment in ('really_enjoyed', 'enjoyed', 'no_preference', 'rather_not'));

-- Backfill any existing rows from the old boolean, then retire it.
update reflections
  set sentiment = case when would_meet_again then 'enjoyed' else 'no_preference' end
  where sentiment is null;

alter table reflections alter column sentiment set not null;
alter table reflections drop column if exists would_meet_again;

-- Silent, permanent exclusions. A `rather_not` writes a row here; the group
-- composer must never place the pair together again. Directional storage,
-- symmetric effect — the composer checks both directions. No one is notified,
-- and there is no client-facing read path (service_role only).
create table if not exists exclusions (
  user_id     uuid not null references profiles (id) on delete cascade,
  excluded_id uuid not null references profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, excluded_id)
);

alter table exclusions enable row level security;
-- No policies: RLS on with zero policies denies every client. Only the
-- SECURITY DEFINER trigger below and service_role can touch this table.
revoke all on exclusions from anon, authenticated;

-- A `rather_not` reflection quietly records an exclusion. Runs as definer so
-- the ordinary reflection write (which the rater is allowed to make) is enough
-- to seed the exclusion without granting the client any access to the table.
create or replace function on_rather_not() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if new.sentiment = 'rather_not' then
    insert into exclusions (user_id, excluded_id)
    values (new.rater_id, new.subject_id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists reflections_rather_not on reflections;
create trigger reflections_rather_not
  after insert or update on reflections
  for each row execute function on_rather_not();

-- Mutual warmth, recomputed for the new scale: both people at `enjoyed` or
-- above, and neither has excluded the other. Still returns only the
-- counterpart id — never the direction or the raw feeling. service_role only.
create or replace function mutual_connections(u uuid)
  returns table (other_id uuid)
  language sql stable security definer set search_path = public as $$
  select r1.subject_id
  from reflections r1
  join reflections r2
    on r2.rater_id = r1.subject_id
   and r2.subject_id = r1.rater_id
  where r1.rater_id = u
    and r1.sentiment in ('really_enjoyed', 'enjoyed')
    and r2.sentiment in ('really_enjoyed', 'enjoyed')
    and not exists (
      select 1 from exclusions e
      where (e.user_id = r1.rater_id and e.excluded_id = r1.subject_id)
         or (e.user_id = r1.subject_id and e.excluded_id = r1.rater_id)
    );
$$;

-- CREATE OR REPLACE preserves prior grants, but re-assert the lock from 0005
-- in case this function is ever created fresh on a new environment.
revoke execute on function mutual_connections(uuid) from anon, authenticated;
