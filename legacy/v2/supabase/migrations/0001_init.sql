-- Ekipa — initial schema.
--
-- The privacy model is not a feature layered on top; it lives in these RLS
-- policies. Two invariants matter most:
--   1. A decline is invisible. Until everyone has accepted (meetup becomes
--      'confirmed'), a member can see only their OWN invite row — never who
--      else was invited, and never who declined.
--   2. "Would you see them again?" is one-way private. A member can read only
--      their own reflection rows. Mutual matches are computed server-side and
--      the other person's choice is never exposed to anyone.

-- ─────────────────────────────────────────────────────────────────────────
-- Profiles
-- ─────────────────────────────────────────────────────────────────────────
create table profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  first_name       text not null,
  city             text not null,
  gender           text,                      -- used only for same-gender grouping
  same_gender_only boolean not null default false,
  group_size_pref  int not null default 3 check (group_size_pref between 2 and 4),
  talk_level       text not null default 'balanced'
                     check (talk_level in ('chatty', 'balanced', 'quiet_company')),
  activities       text[] not null default '{}',
  availability     text[] not null default '{}',
  blurb            text not null default '',   -- system-written; no free-text bio
  reliability      numeric not null default 1.0,  -- INTERNAL ONLY, never shown
  verified         boolean not null default false,
  created_at       timestamptz not null default now()
);

alter table profiles enable row level security;

-- You can read and edit only your own profile. Other people's details are
-- never queried directly — they reach you only as attendee blurbs on a
-- confirmed meetup, via the security-definer function below.
create policy profiles_select_own on profiles
  for select using (id = auth.uid());
create policy profiles_update_own on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_insert_own on profiles
  for insert with check (id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- Meetups
-- ─────────────────────────────────────────────────────────────────────────
create table meetups (
  id              uuid primary key default gen_random_uuid(),
  status          text not null default 'proposed'
                    check (status in ('proposed', 'forming', 'confirmed', 'completed', 'cancelled')),
  activity_slug   text not null,
  activity_label  text not null,
  emoji           text not null default '🌿',
  venue_name      text not null,
  venue_note      text not null default '',
  city            text not null,
  starts_at       timestamptz not null,
  duration_min    int not null default 90,
  is_standing     boolean not null default false,
  what_to_expect  text not null default '',
  created_at      timestamptz not null default now()
);

create table meetup_members (
  meetup_id    uuid not null references meetups (id) on delete cascade,
  user_id      uuid not null references profiles (id) on delete cascade,
  rsvp         text not null default 'pending'
                 check (rsvp in ('pending', 'yes', 'no')),
  confirmed_at timestamptz,               -- morning-of confirmation
  attended     boolean,
  primary key (meetup_id, user_id)
);

alter table meetups enable row level security;
alter table meetup_members enable row level security;

-- Helper: is the current user a member of this meetup?
create function is_member(m uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from meetup_members
    where meetup_id = m and user_id = auth.uid()
  );
$$;

-- Helper: has this meetup been confirmed (everyone said yes)?
create function is_confirmed(m uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (select 1 from meetups where id = m and status = 'confirmed');
$$;

-- A member can see the meetup they were invited to (they must, to respond).
create policy meetups_select_member on meetups
  for select using (is_member(id));

-- THE invisibility rule. A member row is visible only if:
--   (a) it is your own invite, or
--   (b) the meetup is confirmed AND you belong to it.
-- Before confirmation you cannot see who else was invited or who declined.
create policy members_select_visible on meetup_members
  for select using (
    user_id = auth.uid()
    or (is_confirmed(meetup_id) and is_member(meetup_id))
  );

-- You may only change your own RSVP / confirmation.
create policy members_update_own on meetup_members
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Attendee blurbs for a confirmed meetup, first-name only. This is the ONLY
-- path by which one user learns anything about another.
create function confirmed_attendees(m uuid)
  returns table (id uuid, first_name text, blurb text)
  language sql stable security definer set search_path = public as $$
  select p.id, p.first_name, p.blurb
  from meetup_members mm
  join profiles p on p.id = mm.user_id
  where mm.meetup_id = m
    and is_confirmed(m)
    and is_member(m);
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Reflections — "who would you be happy to see again?"
-- ─────────────────────────────────────────────────────────────────────────
create table reflections (
  meetup_id         uuid not null references meetups (id) on delete cascade,
  rater_id          uuid not null references profiles (id) on delete cascade,
  subject_id        uuid not null references profiles (id) on delete cascade,
  would_meet_again  boolean not null,
  created_at        timestamptz not null default now(),
  primary key (meetup_id, rater_id, subject_id)
);

alter table reflections enable row level security;

-- You can read and write ONLY your own reflections. You can never see how
-- anyone reflected on you — not a yes, not a no.
create policy reflections_rw_own on reflections
  for all using (rater_id = auth.uid()) with check (rater_id = auth.uid());

-- Mutual "yes" edges, computed server-side. Returns only the counterpart id;
-- callers never learn the direction or the other person's raw choice. The
-- composer uses this graph to seed future groups.
create function mutual_connections(u uuid)
  returns table (other_id uuid)
  language sql stable security definer set search_path = public as $$
  select r1.subject_id
  from reflections r1
  join reflections r2
    on r2.rater_id = r1.subject_id
   and r2.subject_id = r1.rater_id
  where r1.rater_id = u
    and r1.would_meet_again
    and r2.would_meet_again;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Blocks — silent. A blocked pair is never grouped again; no one is notified.
-- ─────────────────────────────────────────────────────────────────────────
create table blocks (
  blocker_id uuid not null references profiles (id) on delete cascade,
  blocked_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

alter table blocks enable row level security;
create policy blocks_rw_own on blocks
  for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- Auto-provision a bare profile when a user signs up (edited later in onboarding).
create function handle_new_user() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, first_name, city)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'first_name', ''), '')
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
