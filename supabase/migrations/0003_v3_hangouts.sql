-- 0003 · The hangout lifecycle — the spine of the product.
--
-- Two rules shape this file.
--
-- **Neither table below is client-readable.** Not the hangout, not the
-- membership. Everything a person is allowed to know about their own hangout
-- comes through an RPC in 0006, because what they may know *changes with time*
-- — shape before reveal, names after — and a row-level policy cannot express
-- "these four columns, but only after 17:30" without one mistake becoming a
-- silent leak. `hangout_members` also carries `ring_*` and `via_person_id`,
-- which are matcher diagnostics that would publish the friend graph outright.
--
-- **The invariants that matter are constraints, not application checks.**
-- "No person is in two hangouts in the same slot" and "no two live groups share
-- a sigil at the same place" cannot be enforced by a Dart method under
-- concurrency. They are indexes.

create type public.hangout_state as enum (
  'PLANNED',      -- the matcher emitted it; nobody has been told
  'PROPOSED',     -- members know a hangout exists for their slot
  'CONFIRMING',   -- morning-of; each member answers yes or no
  'BACKFILLING',  -- someone declined; the repair pass is running
  'LOCKED',       -- enough confirmations; it is happening
  'REVEALED',     -- meeting point, sigil and names are visible
  'LIVE',         -- arrival taps, grace window, late reports
  'RATING',       -- mandatory ratings are open
  'CLOSED',       -- edges formed, infractions written, metrics final
  'CANCELLED',    -- the system called it off, before anyone left home
  'ABANDONED'     -- nobody arrived
);

-- What the ring draw asked for, and what the graph could actually supply.
-- Recording both is what makes the configured ratio verifiable: fallbacks bias
-- systematically toward strangers exactly when the graph is thin, so a
-- configured 0.25/0.50/0.25 can realise as 0.05/0.15/0.80 with nothing
-- anywhere saying so (03_MATCHMAKER.md §⑤).
create type public.ring as enum ('r1_enjoyed', 'r2_leaf', 'r3_stranger');

create type public.slot_role as enum ('seed', 'partner', 'backfill');

-- Silence is a third answer, not a missing one. It is treated as worse than a
-- decline, because the scarce resource is time to repair and silence destroys
-- it (04_TRUST.md §3.1).
create type public.confirmation as enum ('yes', 'no', 'silent');

-- ─────────────────────────────────────────────────────────────────────────────
create table public.hangouts (
  id                  uuid primary key default gen_random_uuid(),
  slot_id             uuid not null references public.slots(id) on delete restrict,
  city_id             uuid not null references public.cities(id) on delete restrict,
  state               public.hangout_state not null default 'PLANNED',
  composition_rule    text not null,
  seed_person_id      uuid references public.people(id) on delete set null,
  activity_id         text not null references public.activity_templates(id),
  cluster_id          uuid references public.venue_clusters(id) on delete set null,
  -- Assigned at lock, not at match: if someone declines and is backfilled, the
  -- replacement only has to reach the *cluster*. Choosing a venue early would
  -- mean re-choosing it every time the group changed.
  meeting_point_id    uuid references public.venues(id) on delete set null,
  sigil_id            uuid references public.sigils(id) on delete set null,
  match_run_id        uuid,
  config_version_id   uuid,
  is_dating           boolean not null default false,
  -- All seven deadlines are written at creation from the config version above,
  -- so a mid-day config change never moves a deadline someone is already
  -- inside. That class of bug — penalising people under a rule that did not
  -- exist when they were asked — is the most trust-destroying one available.
  confirm_opens_at    timestamptz,
  confirm_deadline_at timestamptz,
  backfill_until      timestamptz,
  reveal_at           timestamptz,
  arrival_grace_until timestamptz,
  late_report_until   timestamptz,
  rating_due_at       timestamptz,
  created_at          timestamptz not null default now(),
  closed_at           timestamptz,
  cancel_reason       text,
  -- Lets `hangout_members` carry a composite foreign key, which is what makes
  -- the one-hangout-per-slot index below trustworthy rather than hopeful.
  unique (id, slot_id)
);
alter table public.hangouts enable row level security;
revoke all on table public.hangouts from anon, authenticated;

create index hangouts_slot_idx on public.hangouts (slot_id);
create index hangouts_state_idx on public.hangouts (state);

-- The sweeper runs these every few minutes, forever. Partial indexes keep it
-- reading the handful of rows that are actually due rather than the table.
create index hangouts_due_confirm_idx on public.hangouts (confirm_deadline_at)
  where state = 'CONFIRMING';
create index hangouts_due_backfill_idx on public.hangouts (backfill_until)
  where state = 'BACKFILLING';
create index hangouts_due_reveal_idx on public.hangouts (reveal_at)
  where state = 'LOCKED';
create index hangouts_due_rating_idx on public.hangouts (rating_due_at)
  where state = 'RATING';

-- The transcript's explicit requirement, enforced where it cannot be raced: two
-- groups never share a symbol at the same place in the same slot. A collision
-- is impossible, not unlikely.
create unique index hangouts_sigil_unique
  on public.hangouts (meeting_point_id, sigil_id, slot_id)
  where meeting_point_id is not null and sigil_id is not null;

-- ─────────────────────────────────────────────────────────────────────────────
create table public.hangout_members (
  hangout_id       uuid not null references public.hangouts(id) on delete cascade,
  person_id        uuid not null references public.people(id) on delete cascade,
  -- Denormalised from the hangout and held consistent by the composite key
  -- below, purely so the one-per-slot uniqueness can be an index.
  slot_id          uuid not null,
  slot_role        public.slot_role not null,
  ring_intended    public.ring,
  ring_realised    public.ring,
  -- The intermediary of an r2 draw. Never selectable by any client-facing
  -- policy: it names an edge, which is the whole friend graph in one column.
  via_person_id    uuid references public.people(id) on delete set null,
  joined_at        timestamptz not null default now(),
  -- Set when a hangout is cancelled, which frees the person to be matched into
  -- that slot again. The row itself is never deleted: cancellations are input
  -- to trust and the event log has to stay answerable months later.
  released_at      timestamptz,
  confirmation     public.confirmation,
  confirmed_at     timestamptz,
  arrived_at       timestamptz,
  arrival_attested boolean,
  -- Whether the device was near the meeting point at tap time. **The boolean
  -- only** — never the coordinates, never a trace. It raises the cost of a
  -- false arrival without building a tracking product.
  arrival_proximate boolean,
  rated_at         timestamptz,
  primary key (hangout_id, person_id),
  foreign key (hangout_id, slot_id)
    references public.hangouts(id, slot_id) on delete cascade
);
alter table public.hangout_members enable row level security;
revoke all on table public.hangout_members from anon, authenticated;

create index hangout_members_person_idx on public.hangout_members (person_id);

-- A person cannot be in two hangouts in the same slot. Enforced by the
-- database, because two match runs, or a run and a backfill, can race.
create unique index hangout_members_one_per_slot
  on public.hangout_members (person_id, slot_id)
  where released_at is null;

-- ─────────────────────────────────────────────────────────────────────────────
-- The event log (01_ARCHITECTURE.md §7). Append-only, and the reason a sanction
-- can be explained to a human months later.
create table public.hangout_events (
  id                 bigint generated always as identity primary key,
  hangout_id         uuid not null references public.hangouts(id) on delete cascade,
  type               text not null,
  payload            jsonb not null default '{}'::jsonb,
  actor_person_id    uuid references public.people(id) on delete set null,
  occurred_at        timestamptz not null default now(),
  config_version_id  uuid
);
alter table public.hangout_events enable row level security;
revoke all on table public.hangout_events from anon, authenticated;
create index hangout_events_hangout_idx
  on public.hangout_events (hangout_id, occurred_at);

create table public.person_events (
  id               bigint generated always as identity primary key,
  person_id        uuid not null references public.people(id) on delete cascade,
  type             text not null,
  payload          jsonb not null default '{}'::jsonb,
  occurred_at      timestamptz not null default now(),
  config_version_id uuid
);
alter table public.person_events enable row level security;
revoke all on table public.person_events from anon, authenticated;
create index person_events_person_idx
  on public.person_events (person_id, occurred_at);
