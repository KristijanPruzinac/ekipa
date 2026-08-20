-- 0005 · Versioned config, match runs, and the audit log.
--
-- Directive D5, stated more strongly than the transcript asked for: **no
-- behavioural constant is a literal in code.** If a product person could
-- reasonably want it different next month, it is a row in `config_values`.
--
-- Why the versioning matters more than it looks: shorten the confirmation
-- window at 11:00 while forty people have a 09:00 confirmation pending, apply
-- it retroactively, and you have penalised people under a rule that did not
-- exist when they were asked. That is the most trust-destroying class of bug
-- this product can have and it is invisible without versioning. It also makes
-- historical analysis honest — "did attendance improve?" means nothing if you
-- cannot say which rules were live.

create table public.config_versions (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  created_by  uuid references auth.users(id) on delete set null,
  effective_from timestamptz not null default now(),
  note        text not null,
  published   boolean not null default false
);
alter table public.config_versions enable row level security;
revoke all on table public.config_versions from anon, authenticated;

-- Scope resolves global → country → city → cohort, most specific wins. Osijek
-- can run three weekdays while a new city runs one, without a code path.
create table public.config_values (
  version_id  uuid not null references public.config_versions(id) on delete cascade,
  key         text not null,
  scope_kind  text not null check (scope_kind in ('global', 'country', 'city', 'cohort')),
  scope_ref   text not null default '',
  value       jsonb not null,
  primary key (version_id, key, scope_kind, scope_ref)
);
alter table public.config_values enable row level security;
revoke all on table public.config_values from anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Match runs.
--
-- A run takes a snapshot and a seed; the same snapshot and seed must produce a
-- byte-identical plan. `snapshot_hash` is what makes that claim checkable
-- rather than asserted, and it is why a run can be replayed exactly when it
-- does something surprising.
create table public.match_runs (
  id                uuid primary key default gen_random_uuid(),
  city_id           uuid not null references public.cities(id) on delete cascade,
  kind              text not null check (kind in ('daily', 'repair', 'dating', 'dry_run')),
  seed              bigint not null,
  snapshot_hash     text not null,
  config_version_id uuid references public.config_versions(id) on delete set null,
  started_at        timestamptz not null default now(),
  finished_at       timestamptz,
  status            text not null default 'running'
    check (status in ('running', 'succeeded', 'failed')),
  -- The eligibility funnel lives here: filtered by cooldown 12, by standing 3,
  -- by distance 8, unmatched for lack of a composition-compatible partner 5.
  -- Without it the console can only say "nothing happened", which is the least
  -- useful sentence a matcher can produce.
  stats             jsonb not null default '{}'::jsonb
);
alter table public.match_runs enable row level security;
revoke all on table public.match_runs from anon, authenticated;
create index match_runs_city_idx on public.match_runs (city_id, started_at desc);

-- Why each group was built the way it was. **This cannot be reconstructed
-- later**, so it is written before the first real hangout rather than after the
-- first question about one. It is also what makes a match *sayable* — "you were
-- matched with C because C is a friend of someone you liked". We never show
-- that to a user, because it would leak the graph; but if the system cannot
-- produce the sentence internally, the match was an accident.
create table public.match_run_groups (
  match_run_id        uuid not null references public.match_runs(id) on delete cascade,
  hangout_id          uuid references public.hangouts(id) on delete set null,
  seed_person_id      uuid references public.people(id) on delete set null,
  ring_mix            jsonb not null default '{}'::jsonb,
  score_components    jsonb not null default '{}'::jsonb,
  rejected_alternates jsonb not null default '[]'::jsonb,
  created_at          timestamptz not null default now(),
  primary key (match_run_id, hangout_id)
);
alter table public.match_run_groups enable row level security;
revoke all on table public.match_run_groups from anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Console access control and the audit log (AC-3, AC-5, AC-8).
create table public.admin_roles (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  role         text not null check (role in ('viewer', 'operator', 'owner')),
  granted_at   timestamptz not null default now(),
  granted_by   uuid references auth.users(id) on delete set null
);
alter table public.admin_roles enable row level security;
revoke all on table public.admin_roles from anon, authenticated;

-- Append-only as a *permission*, not as a policy: the console has no delete or
-- update grant on this table, so "the operator cannot erase their own trail" is
-- a property of the database rather than a promise in a document.
create table public.admin_audit (
  id          bigint generated always as identity primary key,
  actor       uuid references auth.users(id) on delete set null,
  action      text not null,
  target      text,
  reason      text,
  before      jsonb,
  after       jsonb,
  occurred_at timestamptz not null default now()
);
alter table public.admin_audit enable row level security;
revoke all on table public.admin_audit from anon, authenticated;
create index admin_audit_time_idx on public.admin_audit (occurred_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- Cross-file foreign keys, added now that both sides exist.
alter table public.hangouts
  add constraint hangouts_match_run_fk
  foreign key (match_run_id) references public.match_runs(id) on delete set null;

alter table public.hangouts
  add constraint hangouts_config_version_fk
  foreign key (config_version_id)
  references public.config_versions(id) on delete set null;
