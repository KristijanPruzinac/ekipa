-- 0004 · Ratings, the graph, and trust.
--
-- This is the file the whole privacy promise rests on, so the default is
-- absolute: **no client SELECT on any table here.** Not one. The four
-- invariants below are enforced by the absence of a policy, which is the only
-- form of enforcement that cannot be got wrong in a `using` clause:
--
--   3. Nobody can ever read how anyone rated them — not the value, not the
--      existence, not an aggregate that leaks it.
--   4. The direction of an edge is not stored and cannot be derived.
--   6. Reports are invisible to the reported person, including the count.
--   7. Standing, trust score and any respect aggregate are service-role only.
--
-- The single exception is a *visible* sanction, and it is an exception on
-- purpose: a suspension a person cannot see is a suspension they cannot appeal,
-- and GDPR Art. 22 requires a route to human intervention for an automated
-- decision with a significant effect.

create type public.enjoyment as enum (
  'really_enjoyed', 'enjoyed', 'no_preference', 'rather_not'
);

create type public.exclusion_reason as enum (
  'rather_not', 'block', 'report_upheld'
);

create type public.infraction_type as enum (
  'CONFIRM_DECLINE',
  'CONFIRM_DECLINE_LATE',
  'CONFIRM_SILENT',
  'NO_SHOW',
  'LATE_ARRIVAL',
  'EARLY_LEAVE',
  'RATING_MISSED',
  'EQUIPMENT_PROMISED_NOT_BROUGHT',
  'REPORT_ABUSE',
  'CONDUCT'
);

-- Two accumulators that never sum (04_TRUST.md §2): a flake and a creep need
-- different responses, and merging them mislabels both.
create type public.accumulator as enum ('reliability', 'conduct');

create type public.sanction_kind as enum (
  'THROTTLE', 'SEGREGATE', 'DATING_REMOVAL', 'SUSPENSION', 'BAN'
);

create type public.standing_tier as enum (
  'GOOD', 'WATCHED', 'THROTTLED', 'SEGREGATED', 'SUSPENDED', 'BANNED'
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Ratings. Two mandatory questions per other member, plus the venue questions
-- that make the catalogue self-improving.
--
-- `dwell_ms` is a **hint, never a verdict**. It is measured on a client we
-- treat as hostile and can be forged in a second. It feeds a down-weighting
-- heuristic on straight-lining and can never, on its own, cost anyone anything.
create table public.ratings (
  hangout_id  uuid not null references public.hangouts(id) on delete cascade,
  rater_id    uuid not null references public.people(id) on delete cascade,
  subject_id  uuid not null references public.people(id) on delete cascade,
  enjoyment   public.enjoyment not null,
  respect     boolean not null,
  dwell_ms    integer,
  created_at  timestamptz not null default now(),
  primary key (hangout_id, rater_id, subject_id),
  check (rater_id <> subject_id)
);
alter table public.ratings enable row level security;
revoke all on table public.ratings from anon, authenticated;
create index ratings_subject_idx on public.ratings (subject_id);

-- The venue questions. Within a few weeks these produce a quality model
-- specific to our exact case — four strangers converging at 17:30 — which no
-- star rating anywhere measures.
create table public.venue_feedback (
  hangout_id    uuid not null references public.hangouts(id) on delete cascade,
  person_id     uuid not null references public.people(id) on delete cascade,
  venue_id      uuid not null references public.venues(id) on delete cascade,
  easy_to_find  boolean not null,
  good_to_meet  boolean not null,
  created_at    timestamptz not null default now(),
  primary key (hangout_id, person_id)
);
alter table public.venue_feedback enable row level security;
revoke all on table public.venue_feedback from anon, authenticated;
create index venue_feedback_venue_idx on public.venue_feedback (venue_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Edges. Mutual only, and the key is (least, greatest) so **symmetry is
-- structural**: there is no column that could hold a direction, so no query can
-- recover who liked whom first. A one-sided "I enjoyed them" creates nothing.
--
-- That is load-bearing for privacy, not manners. If one-sided liking could pull
-- someone back, being re-matched would leak that they liked you — and *not*
-- being re-matched would leak the opposite.
create table public.edges (
  a_id        uuid not null references public.people(id) on delete cascade,
  b_id        uuid not null references public.people(id) on delete cascade,
  weight      numeric(5, 4) not null,
  meet_count  integer not null default 1,
  last_met_at timestamptz not null,
  created_at  timestamptz not null default now(),
  primary key (a_id, b_id),
  check (a_id < b_id)
);
alter table public.edges enable row level security;
revoke all on table public.edges from anon, authenticated;
create index edges_b_idx on public.edges (b_id);

-- Permanent and symmetric. A `rather_not` is invisible to its subject, which is
-- what makes the revenge report unobservable: the trigger cannot be seen.
create table public.exclusions (
  a_id       uuid not null references public.people(id) on delete cascade,
  b_id       uuid not null references public.people(id) on delete cascade,
  reason     public.exclusion_reason not null,
  created_at timestamptz not null default now(),
  primary key (a_id, b_id),
  check (a_id < b_id)
);
alter table public.exclusions enable row level security;
revoke all on table public.exclusions from anon, authenticated;
create index exclusions_b_idx on public.exclusions (b_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Reports.
create table public.report_categories (
  code      text primary key,
  severity  smallint not null check (severity between 1 and 3),
  leeway    boolean not null,
  label_hr  text not null,
  label_en  text not null,
  active    boolean not null default true
);
alter table public.report_categories enable row level security;
create policy report_categories_read on public.report_categories
  for select to authenticated using (active);  -- catalogue: what to report

-- `leeway = true` means a first offence inside a *dating* hangout is weighted
-- lower, because signals genuinely get misread where advances are permitted.
-- Severe categories get none: touching, following and threats are not misread.
insert into public.report_categories (code, severity, leeway, label_hr, label_en)
values
  ('pushy',      1, true,  'Nije odustajao/la',        'Would not drop it'),
  ('disrespect', 1, true,  'Nepoštovanje',             'Disrespectful'),
  ('unwanted_contact', 2, false, 'Neželjeni dodir',    'Unwanted touching'),
  ('following',  3, false, 'Praćenje',                 'Followed me'),
  ('threat',     3, false, 'Prijetnja',                'Threatened me'),
  ('hate',       3, false, 'Govor mržnje',             'Hate speech');

create table public.reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid not null references public.people(id) on delete cascade,
  subject_id   uuid not null references public.people(id) on delete cascade,
  hangout_id   uuid not null references public.hangouts(id) on delete cascade,
  category     text not null references public.report_categories(code),
  -- The only free text in the entire system. It never reaches the matcher, a
  -- notification body, or a display name (rule 11).
  note         text check (char_length(note) <= 1000),
  created_at   timestamptz not null default now(),
  -- Corroboration is what replaces "a moderator upheld it" (04_TRUST.md §4.4).
  outcome      text check (outcome in ('substantiated', 'unsupported')),
  resolved_at  timestamptz,
  check (reporter_id <> subject_id),
  unique (reporter_id, subject_id, hangout_id)
);
alter table public.reports enable row level security;
revoke all on table public.reports from anon, authenticated;
create index reports_subject_idx on public.reports (subject_id, created_at);
create index reports_hangout_idx on public.reports (hangout_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Infractions, sanctions, standing.
create table public.infractions (
  id                uuid primary key default gen_random_uuid(),
  person_id         uuid not null references public.people(id) on delete cascade,
  which             public.accumulator not null,
  type              public.infraction_type not null,
  -- The weight *as applied*, copied from the config version in force at the
  -- time. Recomputing it later from current config would silently rewrite
  -- history every time a threshold moved.
  weight            numeric(5, 3) not null,
  hangout_id        uuid references public.hangouts(id) on delete set null,
  source_report_id  uuid references public.reports(id) on delete set null,
  occurred_at       timestamptz not null default now(),
  config_version_id uuid,
  -- Set when an appeal is upheld. The evidence leaves the accumulator, because
  -- otherwise a wrong sanction quietly raises the ladder step for a year.
  voided_at         timestamptz,
  void_reason       text
);
alter table public.infractions enable row level security;
revoke all on table public.infractions from anon, authenticated;
create index infractions_person_idx
  on public.infractions (person_id, occurred_at) where voided_at is null;

create table public.sanctions (
  id                 uuid primary key default gen_random_uuid(),
  person_id          uuid not null references public.people(id) on delete cascade,
  which              public.accumulator not null,
  kind               public.sanction_kind not null,
  ladder_step        smallint not null,
  -- R0 to R2 are invisible by design: a pair exclusion, a dating removal and a
  -- silent throttle cost a falsely-accused person almost nothing, and they are
  -- therefore never appealed. Everything a person can feel, they can see.
  visible            boolean not null,
  reason_code        text not null,
  evidence           jsonb not null default '{}'::jsonb,
  context_count      smallint not null,
  starts_at          timestamptz not null default now(),
  ends_at            timestamptz,
  config_version_id  uuid,
  appealed_at        timestamptz,
  overturned_at      timestamptz,
  created_at         timestamptz not null default now(),
  -- Nothing above R2 may ever fire from a single hangout. Not from four
  -- reporters, not from a severe category. One evening is one observation, and
  -- two friends can manufacture one evening. This is the single most important
  -- rule in the trust system, so it is a constraint and not a code path.
  check (
    kind in ('THROTTLE', 'SEGREGATE', 'DATING_REMOVAL') or context_count >= 2
  ),
  check (kind <> 'BAN' or context_count >= 2)
);
alter table public.sanctions enable row level security;
revoke all on table public.sanctions from anon, authenticated;
create index sanctions_person_idx on public.sanctions (person_id, starts_at);
create index sanctions_active_idx on public.sanctions (person_id, ends_at)
  where overturned_at is null;

-- The one thing in this file a person may read about themselves, and only the
-- part they can already feel.
create policy sanctions_read_own_visible on public.sanctions
  for select to authenticated
  using (person_id = public.current_person_id() and visible);
grant select on table public.sanctions to authenticated;

create table public.standing (
  person_id          uuid primary key references public.people(id) on delete cascade,
  tier               public.standing_tier not null default 'GOOD',
  reliability_score  numeric(6, 3) not null default 0,
  conduct_score      numeric(6, 3) not null default 0,
  respect_yes        integer not null default 0,
  respect_no         integer not null default 0,
  report_credibility numeric(4, 3) not null default 1.0,
  computed_at        timestamptz not null default now()
);
alter table public.standing enable row level security;
revoke all on table public.standing from anon, authenticated;

-- Not even to the person it is about. A visible standing becomes a status game
-- within a week, and the respect signal is one bit from three strangers — far
-- too coarse to justify telling anyone what it says about them.
