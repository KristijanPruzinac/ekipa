-- 0001 · Catalogue: the registries and the public facts of a city.
--
-- Nothing here is about a person. These are the tables a client may read in
-- full — a list of genders for a picker, the slots this week, the venues in
-- town — and they are marked `-- catalogue:` where a permissive policy appears,
-- because DP-2 forbids `using (true)` everywhere else and a rule with a silent
-- exception is not a rule.
--
-- Directive D6: every extension point below is a *registry table*, not an enum.
-- Adding a gender handling policy, an activity, or a sanction ladder is a row
-- plus a strategy class, never a migration of every `switch` in the codebase.

create extension if not exists postgis with schema extensions;
create extension if not exists btree_gist with schema extensions;

-- ─────────────────────────────────────────────────────────────────────────────
-- Genders (D6). A registry, because the composition rule is a *policy over*
-- this list: "no person is ever the only one of their gender in a group". The
-- rule does not name any value here, which is what lets a third value exist
-- without a special case (09_OPEN_QUESTIONS.md C-4).
create table public.genders (
  code        text primary key,
  label_hr    text not null,
  label_en    text not null,
  sort_order  smallint not null,
  active      boolean not null default true
);
alter table public.genders enable row level security;
create policy genders_read on public.genders
  for select to authenticated using (true);  -- catalogue: a picker's options

insert into public.genders (code, label_hr, label_en, sort_order) values
  ('woman', 'Žena',  'Woman', 1),
  ('man',   'Muškarac', 'Man', 2),
  ('other', 'Drugo', 'Other', 3);

-- ─────────────────────────────────────────────────────────────────────────────
-- Cities. Rules are expressed in the city's local timezone because "16:00" and
-- "the morning of" are local human concepts; instants are stored in UTC.
create table public.cities (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  country_code  char(2) not null,
  timezone      text not null,
  centroid      extensions.geography(Point, 4326) not null,
  active        boolean not null default false,
  created_at    timestamptz not null default now(),
  unique (name, country_code)
);
alter table public.cities enable row level security;
create policy cities_read on public.cities
  for select to authenticated using (active);  -- catalogue: where we operate

insert into public.cities (name, country_code, timezone, centroid, active) values
  ('Osijek', 'HR', 'Europe/Zagreb',
   extensions.ST_SetSRID(extensions.ST_MakePoint(18.6955, 45.5550), 4326)::extensions.geography,
   true);

-- ─────────────────────────────────────────────────────────────────────────────
-- Slots. Materialised per week per city so DST is resolved once, at generation,
-- and never recomputed ambiguously (01_ARCHITECTURE.md §6).
create table public.slots (
  id             uuid primary key default gen_random_uuid(),
  city_id        uuid not null references public.cities(id) on delete cascade,
  starts_at      timestamptz not null,
  ends_at        timestamptz not null,
  local_date     date not null,
  local_weekday  smallint not null check (local_weekday between 1 and 7),
  local_time     time not null,
  generated_by   text not null,
  created_at     timestamptz not null default now(),
  unique (city_id, starts_at),
  check (ends_at > starts_at)
);
alter table public.slots enable row level security;
create index slots_city_start_idx on public.slots (city_id, starts_at);

-- ─────────────────────────────────────────────────────────────────────────────
-- Venues and clusters (05_PLACES.md). Clusters are derived from venue positions
-- on ingestion — never authored — which is what makes a village work with the
-- same mechanism as a city, just with less supply.
create table public.venue_clusters (
  id           uuid primary key default gen_random_uuid(),
  city_id      uuid not null references public.cities(id) on delete cascade,
  label        text,
  centroid     extensions.geography(Point, 4326) not null,
  venue_count  integer not null default 0,
  computed_at  timestamptz not null default now()
);
alter table public.venue_clusters enable row level security;
create index venue_clusters_city_idx on public.venue_clusters (city_id);
create index venue_clusters_centroid_idx
  on public.venue_clusters using gist (centroid);

create table public.venues (
  id                uuid primary key default gen_random_uuid(),
  city_id           uuid not null references public.cities(id) on delete cascade,
  cluster_id        uuid references public.venue_clusters(id) on delete set null,
  source            text not null,
  source_ref        text not null,
  name              text not null,
  kind              text not null,
  location          extensions.geography(Point, 4326) not null,
  opening_hours     text,
  -- Attributes recorded and used for nothing yet. Proxies are hypotheses, and
  -- hypotheses are stored, not trusted (05_PLACES.md §3). Promoting one into
  -- the ranking is then a measurement against real outcomes, not a guess.
  attributes        jsonb not null default '{}'::jsonb,
  poi_density_150m  integer,
  indoor_tolerable  boolean,
  step_free         boolean,
  -- Our own signal, which is the one nobody else has: "was it easy to find",
  -- "did it feel like a good place to meet", asked after every hangout.
  outcome_uses      integer not null default 0,
  outcome_score     numeric(4, 3),
  active            boolean not null default true,
  ingested_at       timestamptz not null default now(),
  deactivated_at    timestamptz,
  unique (source, source_ref)
);
alter table public.venues enable row level security;
create index venues_cluster_idx on public.venues (cluster_id) where active;
create index venues_location_idx on public.venues using gist (location);

-- ─────────────────────────────────────────────────────────────────────────────
-- Sigils. A symbol and a colour, describable out loud, language-independent.
-- 24 x 6 combinations, far more than one venue will ever need at once.
create table public.sigils (
  id          uuid primary key default gen_random_uuid(),
  symbol      text not null,
  colour      text not null,
  label_hr    text not null,
  label_en    text not null,
  active      boolean not null default true,
  unique (symbol, colour)
);
alter table public.sigils enable row level security;

-- ─────────────────────────────────────────────────────────────────────────────
-- Activities (D6, 06_ACTIVITIES.md). The requirements column is what stops the
-- matcher emitting a cards hangout with nobody carrying cards.
create table public.activity_templates (
  id            text primary key,
  label_hr      text not null,
  label_en      text not null,
  requirements  jsonb not null default '{}'::jsonb,
  active        boolean not null default true
);
alter table public.activity_templates enable row level security;
create policy activity_templates_read on public.activity_templates
  for select to authenticated using (active);  -- catalogue: what a hangout does

insert into public.activity_templates (id, label_hr, label_en, requirements) values
  ('CONVERSATION_DECK', 'Razgovor', 'Conversation', '{"equipment": null}'::jsonb),
  ('CARDS', 'Karte', 'Cards',
   '{"equipment": "deck_of_cards", "min_carriers": 2}'::jsonb);
