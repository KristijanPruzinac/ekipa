-- 0002 · Identity and people.
--
-- The privacy model starts here, and the shape of it is: **a client can read
-- its own row and nothing else about anybody.** Cross-person reads exist in
-- exactly one place — the reveal RPC in 0006 — and it carries a time-window
-- check.
--
-- What is stored is the list in 02_DOMAIN.md §6 and nothing beside it. No
-- photos, no bio, no surname, no address, no location trace, no messages. If a
-- column here is not on that list, the list is wrong or the column is.

-- ─────────────────────────────────────────────────────────────────────────────
-- Equipment registry (D6). Catalogue, arriving in this file rather than 0001
-- only because `person_equipment` references it.
create table public.equipment (
  code      text primary key,
  label_hr  text not null,
  label_en  text not null,
  active    boolean not null default true
);
alter table public.equipment enable row level security;
create policy equipment_read on public.equipment
  for select to authenticated using (active);  -- catalogue: what you can bring

insert into public.equipment (code, label_hr, label_en) values
  ('deck_of_cards', 'Špil karata', 'Deck of cards');

-- ─────────────────────────────────────────────────────────────────────────────
-- Identities. **No client policy at all**, deliberately: RLS with no policy is
-- deny-all, and nothing outside the worker has any business reading this table.
--
-- The hash is HMAC-SHA256(pepper, provider || ':' || normalised_subject), and
-- the pepper lives in a secret manager, never in this database (ID-1). A hash
-- whose secret sits beside it protects nothing from a database compromise.
--
-- Say the true thing: this is pseudonymisation, not anonymisation. It reduces
-- breach impact and blocks casual re-lookup. It is still personal data.
create table public.identities (
  id             uuid primary key default gen_random_uuid(),
  identity_hash  bytea not null,
  hash_version   smallint not null default 1,
  provider       text not null,
  verified_at    timestamptz not null default now(),
  date_of_birth  date,
  revoked_at     timestamptz,
  -- Unique on (version, hash) rather than on the hash alone, so a pepper
  -- rotation can write a new generation without colliding with the old one.
  unique (hash_version, identity_hash)
);
alter table public.identities enable row level security;
revoke all on table public.identities from anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- People.
--
-- `auth_user_id` points at an **anonymous** Supabase auth user. The university
-- address never reaches Supabase Auth: the worker verifies the code, computes
-- the peppered hash, and binds a session to it. Using email OTP directly would
-- put every student's address in `auth.users`, which is precisely the data this
-- design exists not to hold.
create table public.people (
  id            uuid primary key default gen_random_uuid(),
  identity_id   uuid not null unique references public.identities(id)
                  on delete restrict,
  auth_user_id  uuid unique references auth.users(id) on delete set null,
  first_name    text not null check (length(btrim(first_name)) between 1 and 40),
  last_initial  text not null check (char_length(last_initial) = 1),
  gender_code   text not null references public.genders(code),
  city_id       uuid not null references public.cities(id),
  -- Snapped to a ~500 m grid before it is written. Useful for "twenty minutes
  -- away", never a home address. Never displayed to anyone: matching input
  -- only.
  home_anchor   extensions.geography(Point, 4326),
  -- Bounds are sanity limits, not policy. The *default* a person starts with
  -- comes from config (D5), because it is a number a product decision could
  -- reasonably move next month.
  max_travel_m  integer check (max_travel_m between 250 and 50000),
  joined_at     timestamptz not null default now(),
  deleted_at    timestamptz
);
alter table public.people enable row level security;
create index people_city_idx on public.people (city_id) where deleted_at is null;
create index people_anchor_idx on public.people using gist (home_anchor);

-- ─────────────────────────────────────────────────────────────────────────────
-- The one function every policy in this schema is built on.
--
-- It is `security definer` because a policy on `people` cannot read `people`
-- without recursing into itself. It is safe to be definer for the narrowest
-- possible reason: **its only input is `auth.uid()`**, so the caller cannot ask
-- it about anyone but themselves. There is no argument to abuse.
create or replace function public.current_person_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from public.people p
  where p.auth_user_id = auth.uid()
    and p.deleted_at is null
$$;

revoke all on function public.current_person_id() from public, anon;
grant execute on function public.current_person_id() to authenticated;

create or replace function public.current_city_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.city_id
  from public.people p
  where p.auth_user_id = auth.uid()
    and p.deleted_at is null
$$;

revoke all on function public.current_city_id() from public, anon;
grant execute on function public.current_city_id() to authenticated;

create policy people_read_self on public.people
  for select to authenticated
  using (id = public.current_person_id());

-- No insert, update or delete policy. Every write that carries a consequence
-- goes through an RPC that re-checks the rule server-side (DP-4). A client that
-- could update its own `city_id` could relocate itself into a denser city on
-- the morning of a match run.

-- ─────────────────────────────────────────────────────────────────────────────
-- Devices. One row per device, pruned on push failure (G27).
create table public.devices (
  id           uuid primary key default gen_random_uuid(),
  person_id    uuid not null references public.people(id) on delete cascade,
  push_token   text not null unique,
  platform     text not null check (platform in ('android', 'ios')),
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
alter table public.devices enable row level security;
create index devices_person_idx on public.devices (person_id);
create policy devices_read_self on public.devices
  for select to authenticated
  using (person_id = public.current_person_id());

-- ─────────────────────────────────────────────────────────────────────────────
-- What a person can bring, and what they would like to do (D6).
create table public.person_equipment (
  person_id      uuid not null references public.people(id) on delete cascade,
  equipment_code text not null references public.equipment(code),
  primary key (person_id, equipment_code)
);
alter table public.person_equipment enable row level security;
create policy person_equipment_read_self on public.person_equipment
  for select to authenticated
  using (person_id = public.current_person_id());

create table public.person_activities (
  person_id   uuid not null references public.people(id) on delete cascade,
  activity_id text not null references public.activity_templates(id),
  primary key (person_id, activity_id)
);
alter table public.person_activities enable row level security;
create policy person_activities_read_self on public.person_activities
  for select to authenticated
  using (person_id = public.current_person_id());

-- ─────────────────────────────────────────────────────────────────────────────
-- Availability: a claim that a person *could* attend a slot. Not a preference,
-- not a booking.
create table public.availability (
  person_id  uuid not null references public.people(id) on delete cascade,
  slot_id    uuid not null references public.slots(id) on delete cascade,
  marked_at  timestamptz not null default now(),
  source     text not null check (source in ('manual', 'repeat')),
  primary key (person_id, slot_id)
);
alter table public.availability enable row level security;
create index availability_slot_idx on public.availability (slot_id);
create policy availability_read_self on public.availability
  for select to authenticated
  using (person_id = public.current_person_id());

-- Slots become readable now that there is a city to scope them to. A person has
-- no use for another city's slots, and handing them out would publish where we
-- operate and how thin each market is.
create policy slots_read_own_city on public.slots
  for select to authenticated
  using (city_id = public.current_city_id());
