# 01 — System architecture

Derived from [00_BIBLE.md](00_BIBLE.md) directives **D2, D3, D4, D5, D6**.

Every section states the **intention** (what property we are buying), the **mechanism**
(how), and the **rejected alternative** (what we are deliberately not doing, and what it
would have cost). A decision without a rejected alternative is not a decision — it is a
default that nobody examined.

---

## 1. What kind of system this actually is

Before choosing frameworks, name the machine. Ekipa is **not** a CRUD app with a feed.
It is:

> A **periodic batch optimiser** (the matchmaker) that assigns scarce people to scarce
> time slots, wrapped in a **long-running distributed state machine** (the hangout
> lifecycle) whose transitions are driven by *deadlines* and *human confirmations*,
> feeding a **reputation accumulator** (trust) that gates entry back into the optimiser.

Three consequences follow immediately, and they shape everything:

1. **The hard part runs on a schedule, not on a request.** Most of the interesting code
   never runs inside a user's HTTP call. It runs in a job, over a snapshot, and writes a
   plan. That means it can be pure, deterministic and replayable — so it must be.
2. **Time is a first-class input, not an ambient fact.** Slot boundaries, morning-of
   confirmation, backfill cut-off, arrival windows, rating deadlines, sanction expiry —
   every one is a deadline that fires without a user present. A system driven by
   deadlines needs an explicit clock abstraction and a durable timer mechanism, or it
   becomes untestable and drifts under DST.
3. **Correctness is mostly about invariants across rows, not within them.** "No person
   is in two hangouts in the same slot." "No two live groups share a symbol at the same
   venue." "A suspended user is in no future hangout." These cannot be enforced by
   validation in a Dart method; they are database constraints and transactional writes.

---

## 2. Runtime topology

```
┌──────────────────────┐        ┌───────────────────────┐
│  apps/mobile         │        │  apps/console         │
│  Flutter · iOS+Android│       │  Flutter Web (admin)  │
└──────────┬───────────┘        └───────────┬───────────┘
           │ RLS-scoped PostgREST + Realtime │ service-role RPC (behind admin auth)
           ▼                                 ▼
┌───────────────────────────────────────────────────────┐
│  Supabase project                                     │
│  · Postgres  ← the single source of truth + invariants│
│  · Auth      ← session issuance only                  │
│  · RLS       ← the privacy model, tested not reviewed │
│  · Realtime  ← push-free live updates while app open  │
│  · Storage   ← venue photos                           │
└──────────┬────────────────────────────────────────────┘
           │ service role, transactional RPCs only
           ▼
┌───────────────────────────────────────────────────────┐
│  services/mill  —  the Dart worker ("the mill")       │
│  · matchmaker runs        · backfill/repair passes    │
│  · sanction expiry        · notification fan-out      │
│  · venue ingestion (OSM)                              │
│  Tier 0: GitHub Actions cron · Tier 1: Cloud Run      │
└───────────────────────────────────────────────────────┘
           ▲
           │  pg_cron inside Postgres fires *time-only* transitions
           │  and enqueues work; it never decides who meets whom
           │
           ├─► FCM / APNs (push)
           └─► Overpass API / OSM (venue ingestion, rate-limited, cached)
```

### Where the worker actually runs — two tiers, and why tier 0 is not a compromise

**Constraint (2026-08-18): no paid infrastructure, no company, no card.** That is a real
constraint and it is satisfiable without weakening anything that matters.

| | **Tier 0 — free, now** | **Tier 1 — when there is an entity and revenue** |
| --- | --- | --- |
| Daily match run, venue ingest, notifications | **GitHub Actions scheduled workflow** running the Dart worker | Cloud Run + Cloud Scheduler with OIDC |
| Deadline transitions (confirm expiry, lock, reveal, rating window) | **`pg_cron`** inside Postgres | unchanged |
| Backfill invites during the confirm window | pg_cron enqueues; a 10-minute Actions job drains the queue | worker loop |
| Database | Supabase free tier | Supabase Pro (PITR) |
| Push | FCM (free at any scale we will reach) | unchanged |

**Moving between tiers is a deployment change, not a code change** — the worker is a
stateless binary that reads a snapshot and writes through RPCs, so what invokes it is
interchangeable by construction.

**Why GitHub Actions is the *right* tier-0 answer rather than a sad one:** a scheduled
Actions run is **pull-based**. There is no listener, no URL, no port, and therefore no
ingress to secure — which satisfies **D9** more completely than a Cloud Run service with an
authenticated endpoint does. The service-role credential lives in exactly one place
(repository secrets) and never in an image. Public repositories get free minutes, so the
recurring cost is genuinely zero.

**The three costs, stated:**

1. **Cron is approximate.** Actions schedules can be delayed under load, and GitHub
   disables schedules on repositories with 60 days of no activity. Tolerable here: the
   nightly run has a lead time of days, and the backfill window is hours wide against a
   45-minute invite expiry. It would *not* be tolerable for anything user-facing and
   interactive, and nothing user-facing runs here.
2. **Supabase's free tier pauses a project after 7 days of inactivity.** The daily run is
   what keeps it awake — so the scheduler failing silently eventually pauses the database.
   That is a monitored condition, not an assumption ([11_SECURITY.md](11_SECURITY.md)).
3. **Free tier has no managed point-in-time recovery.** See the backup rule below.

**Two traps this repository is specifically exposed to, because it is public:**

- **Never write a database dump to a CI artifact.** Artifacts on a public repository are
  downloadable by anyone. A backup job that "just uploads the dump" publishes the entire
  user table. Dumps are encrypted at rest in the job and pushed to a *private* store; the
  plaintext never touches the Actions filesystem beyond the pipe.
- **Never expose secrets to a workflow triggered by a fork.** `pull_request` from a fork
  must not receive repository secrets, and `pull_request_target` must never check out and
  execute the PR's code. On a public repo this is the single most likely way the
  service-role key leaves the building.

### Why a separate Dart worker instead of Supabase Edge Functions

**Intention:** directive **D3** — the matchmaker must be *the same code* in the app's
dev tooling, the simulator, the admin console preview and production. If it is written
in TypeScript on Edge Functions and the client is Dart, we maintain two domain models
and they will drift; the drift will be silent and it will be in the rules that decide
who meets whom.

**Mechanism:** the algorithms live in `packages/ekipa_core` (pure Dart, zero IO). The
worker is a thin Dart binary that loads a snapshot, calls the pure function, and writes
the result through transactional RPCs. The simulator calls the identical function with a
synthetic snapshot. The console can dry-run a real snapshot and show what *would*
happen, using the same function.

**Rejected — Edge Functions (Deno/TS):** cheaper to deploy, no container, already in the
Supabase bill. Costs: a second language for the domain, no shared types, a 150s wall
clock ceiling that a local-search optimiser will eventually hit, and no ability to run
the production matcher inside `flutter test`. We would pay for that in correctness.

**Rejected — plpgsql/SQL matchmaker:** fastest data access, zero network. Costs: the
worst testing story available, no property-based testing, no simulation harness, and a
scoring function that becomes unreadable at about 200 lines. SQL is where we express
*constraints*, not *policy*.

**Rejected — Serverpod / full Dart backend replacing Supabase:** one stack end to end.
Costs: we would rebuild auth, RLS-equivalent authorisation, realtime and storage. RLS is
the single highest-leverage safety feature in this product; we are not writing our own.

### Why Postgres stays the source of truth even though a worker exists

The worker is **stateless and disposable**. It holds no queue, no cache of record, no
schedule of its own. If it dies mid-run, the next run recomputes from the database. All
scheduling state (what is due, what expired) is queryable SQL. **Intention:** a system
whose recovery procedure is "start it again."

---

## 3. Repository shape

```
apps/
  mobile/                 Flutter app (iOS + Android). Thin. Owns no rules.
  console/                Flutter Web master console. Thin. Owns no rules.
services/
  mill/                   Dart worker: schedulers, jobs, adapters, deployment.
packages/
  ekipa_core/             PURE DART. Domain + algorithms + policies. No IO. No Flutter.
  ekipa_data/             DTOs, mappers, Supabase/Overpass/FCM gateways. Implements core ports.
  ekipa_ui/               Design system: tokens, primitives, motion. No feature code.
supabase/
  migrations/             Schema, RLS, RPCs, triggers. The only way schema changes.
  tests/                  pgTAP: RLS invariants, trigger behaviour, constraint coverage.
  seed/                   Deterministic dev fixtures.
tools/
  simulator/              Synthetic-population runner over ekipa_core. Tuning + regression.
  reference/              Scripts that produced docs/reference (image splitter, etc.).
docs/
  v3/                     This spec set. Canonical.
  reference/              Split UI reference frames, grouped by app.
  legacy/                 v1/v2 documents, archived. Read for history, never for truth.
legacy/                   v1/v2 source, quarantined. Never imported. Deleted at P2 exit.
```

**Why a monorepo with pub workspaces** (Dart ≥3.6 `workspace:` / Melos optional):
`ekipa_core` is consumed by four different runtimes (app, console, worker, simulator). A
change to a matching rule must be compiled against all four in one CI run, or the "same
code everywhere" property is a claim rather than a fact.

**Why feature-first inside the app** (`features/availability/…`, not `screens/`,
`widgets/`, `models/`): layer-first folders were what the v1 code did and they stop
working at roughly ten features — every change touches four directories and reviewers
lose the ability to see a feature whole. Feature-first keeps change locality; the shared
layer is what is genuinely shared, and it has to earn that.

---

## 4. The dependency rule

```
presentation  →  application  →  domain  ←  infrastructure
   (widgets)      (use cases,     (entities,     (Supabase,
                   controllers)    policies,      Overpass,
                                   algorithms)    FCM, clock)
```

Arrows are compile-time dependencies. **Nothing points out of `domain`.** Infrastructure
depends on domain because it *implements domain-declared ports*.

Concretely:

- `ekipa_core` may not import `package:flutter`, `package:supabase_flutter`,
  `dart:io`, or `DateTime.now()`. This is enforced in CI by a dependency lint, not by
  discipline — discipline degrades under deadline, lints do not.
- Every side effect the domain needs is a port: `Clock`, `RandomSource`,
  `HangoutRepository`, `PeopleRepository`, `NotificationSink`, `ConfigSource`,
  `IdentityVerifier`, `PlaceSource`. Ports are abstract classes declared in
  `ekipa_core`; adapters live in `ekipa_data` / `services/mill`.
- Tests substitute fakes for ports. **There is no "mock mode" branch in a screen** —
  which is exactly what the v1 code did (`isBackendConfigured ? repo : mockData`), and
  it is why the v1 screens are untestable in any interesting way. Fakes are injected at
  the composition root; the screen cannot tell.

### OOP patterns used, and only where they earn their place

| Pattern | Where | Why here |
| --- | --- | --- |
| Strategy + registry | `CompositionRule`, `ActivityTemplate`, `IdentityVerifier`, `SanctionLadder`, `SeedPolicy` | D6: new options are new classes plus a registry entry, never an edit to a `switch` in the matcher. |
| Value object | `SlotId`, `PersonRef`, `GeoPoint`, `Money`-like scalars, `Standing` | Illegal states unrepresentable; equality by value makes test assertions readable. |
| State machine (explicit) | `HangoutLifecycle`, `SessionState` | Transitions are data with guards, so "which notification fires when" is one table, not scattered `if`s. |
| Specification | `EligibilityRule` composables | Hard constraints compose with `and`/`or` and each is unit-testable alone. |
| Repository (narrow) | one per aggregate, not one god class | v1 had a single `EkipaRepository` doing auth + profile + meetups + reflections. That class is the reason nothing there is testable in isolation. |
| Result / sealed error types | all IO boundaries | Exceptions as control flow across an async UI produce the "grey screen with a spinner" failure mode. |
| Pure function pipeline | matchmaker stages | Each stage is `(input) -> output`, so any stage can be golden-tested and replayed. |

**Patterns deliberately not used:** no service locator singletons (v1's
`const repository = EkipaRepository()` global is exactly the thing that makes a test
suite need a real backend), no inheritance hierarchies for entities (composition +
sealed classes), no generic "BaseRepository<T>" abstraction (it always leaks and never
fits the third case).

---

## 5. Configuration: every number is data

Directive **D5**. The transcript asks for master-console control of the matchmaker
cadence, the confirmation hour, the active weekdays, ban durations, the dating unlock
threshold. The general rule we adopt is stronger:

> **No behavioural constant is a literal in code.** If a product person could reasonably
> want it different next month, it is a config key.

**Mechanism — versioned, effective-dated config:**

```
config_versions(id, created_at, created_by, note)
config_values(version_id, key, value_json)          -- typed at read time by ekipa_core
```

- A run (matchmaker, sweep, sanction evaluation) resolves **one immutable
  `ConfigSnapshot`** at start and passes it down as a parameter. Nothing reads config
  from a global.
- Every `match_run` and every `sanction` row records the `config_version_id` used.
- Changes take effect from a stated instant; **in-flight hangouts keep the version they
  were created under.**

**Why versioning matters more than it looks:** if you shorten the confirmation window at
11:00 while 40 people have a 09:00 confirmation pending, and the change applies
retroactively, you will penalise people under a rule that did not exist when they were
asked. That is the single most trust-destroying class of bug this product can have, and
it is invisible without versioning. It also makes historical analysis honest: "did
attendance improve?" is meaningless if you cannot say which rules were live.

**Rejected — env vars / `--dart-define`:** requires a deploy per change, no audit trail,
no per-city override, and the app and worker can disagree.

**Scoping:** keys resolve `global → country → city → cohort`, most specific wins. Osijek
can run three weekdays while a new city runs one, without a code path.

---

## 6. Time, deadlines and the sweeper

**Intention:** deadline-driven behaviour must be deterministic, testable, and correct
across DST and timezones.

- `Clock` is a port. `ekipa_core` never calls `DateTime.now()`. Tests inject a fake clock
  and advance it; the simulator runs twelve weeks in a second.
- All instants are stored as `timestamptz` (UTC). All *rules* are expressed in the
  **city's local timezone** (IANA id on the city row) because "16:00" and "the morning
  of" are local human concepts. Slot instants are materialised per week per city, so
  DST is resolved once, at materialisation, and never recomputed ambiguously.
- **Durable timers are rows, not in-memory schedulers.** Each hangout carries
  `confirm_opens_at`, `confirm_deadline_at`, `backfill_until`, `reveal_at`,
  `arrival_grace_until`, `rating_due_at`. The mill runs a **sweeper** every N minutes:
  "find everything whose deadline has passed and whose transition has not been applied,
  and apply it, idempotently."
- **Idempotency is mandatory.** Every sweep action is guarded by a state check inside the
  same transaction that writes the transition, so a double-run is a no-op rather than a
  double penalty.

**Rejected — `pg_cron` doing the work in SQL:** fine for calling the worker, wrong for
containing the policy (see §2).

---

## 7. The event log

Every meaningful thing that happens to a hangout or a person is appended to
`hangout_events` / `person_events`: `(id, subject_id, type, payload_json, actor,
occurred_at, config_version_id)`. Current state is a projection maintained
transactionally alongside.

**Intention, four things at once:**

1. **Sanctions need evidence.** "Why was I banned?" must be answerable precisely, by a
   human, months later. Without an event log this is guesswork.
2. **Deadline logic needs to be replayable** when it misfires.
3. **Metrics are derived, not instrumented separately** — no second pipeline to keep in
   sync with reality.
4. **The matchmaker's inputs are historical facts**, so a run can be re-executed exactly.

This is event-*sourcing-lite*: the log is the audit and analytics substrate; the
projection is what the app queries. We do not rebuild state from the log at read time.

---

## 8. Determinism and replay in the matchmaker

Non-negotiable, because this is the component nobody can eyeball for correctness:

- A run takes a **snapshot** (people, availability, edges, standing, venues, config) and
  a **seed**. Same snapshot + same seed ⇒ byte-identical plan.
- `match_runs(id, started_at, config_version_id, seed, snapshot_hash, status, stats)` and
  `match_run_groups(...)` record what was produced **and why** — which template, which
  slot role each member filled, the score components.
- The console can **dry-run**: execute against live data, write nothing, render the plan.

**Why:** without recorded slot roles and score components you cannot ever answer "does
the graph-informed matcher beat random?" — and an unmeasurable optimiser is decoration.
This data cannot be reconstructed after the fact, so it is built before the first real
hangout, not after.

---

## 9. Testing strategy (what proves what)

| Layer | Technique | Proves |
| --- | --- | --- |
| `ekipa_core` policies | unit tests | each rule in isolation |
| matchmaker | **property-based** (`fast_check`-style generators) | invariants hold for *all* generated populations: no double-booking, no cooldown violation, composition rule always satisfied, no suspended user placed |
| matchmaker | golden runs (fixed seed + snapshot) | no unintended behaviour change in a refactor |
| whole mechanism | **simulation harness** (`tools/simulator`) | aggregate outcomes: match rate, newcomer time-to-first-hangout, repeat saturation, ban rate over 12 simulated weeks |
| database | **pgTAP** | RLS actually denies what we claim; triggers behave under concurrency |
| app | widget + golden tests over fakes | screens render every state (loading/empty/error/suspended) |
| flows | integration tests against a seeded local Supabase | the loop end-to-end |

**Why property-based and simulation, specifically:** the matchmaker's failure modes are
statistical, not exceptional. It will not throw; it will quietly starve newcomers, or
build cliques, or match the same pair every week. Example-based tests cannot see that.
The simulator is how we tune weights **before** we have users, and how we detect a
regression in fairness when someone changes a constant.

**Why pgTAP:** an RLS mistake is a silent privacy breach. "We reviewed the policy" is not
a control. Each privacy invariant in [02_DOMAIN.md](02_DOMAIN.md) gets a test that
authenticates as a non-member and asserts zero rows.

---

## 10. Client architecture (Flutter)

- **State management: Riverpod** (recommended, see [09_OPEN_QUESTIONS.md](09_OPEN_QUESTIONS.md) Q-STATE).
  *Why:* compile-safe DI and override-in-test are first-class, which is exactly the
  property the v1 code lacked; async state (loading/error/data) is modelled rather than
  hand-rolled with `FutureBuilder`; providers compose without inheritance.
  *Rejected — Bloc:* excellent discipline, more ceremony per feature, and its DI story
  (`provider`/`get_it`) is weaker for test overrides. *Rejected — setState + FutureBuilder
  (what v1 did):* every screen re-implements loading/error/retry and none of it is testable.
- **Navigation:** `go_router` with typed routes, guarded by an explicit `SessionState`
  machine: `unauthenticated → identity_unverified → onboarding_incomplete → ready →
  restricted(suspended) → banned`. Guards read one state; screens never decide routing.
- **Offline/first paint:** the app is a thin cache over server truth. Local persistence
  (Drift or Isar) is deferred until there is a measured need; premature local DBs create
  sync bugs that dwarf the problem they solve.
- **Realtime:** subscribe to your own hangout rows while the app is open, so a
  confirmation or a backfill appears without a pull-to-refresh. Push handles the app-closed
  case. Both paths converge on the same projection.
- **Push:** FCM (Android) + APNs via FCM (iOS). Notification content is deliberately
  vague until reveal time ("Your hangout needs a confirmation") — the notification shade
  is a semi-public surface.

---

## 11. Security posture

- **RLS-first.** Clients get PostgREST access under RLS only. Any operation that needs to
  see more than the caller may see is a `security definer` RPC with an explicit member
  check inside — and `EXECUTE` revoked from `anon`/`authenticated` unless the client is
  the intended caller.
  *Carried-over lesson from v1:* Supabase grants EXECUTE to `anon`/`authenticated` as
  explicit per-role ACL entries, so `REVOKE … FROM PUBLIC` is a **no-op**. Revoke from the
  role names. (v1 `0003` got this wrong and `0004` fixed it; the lesson survives, the code
  does not.)
- **The mill uses the service role and is the only thing that does.** Its key never
  reaches a client build. Admin console actions go through audited RPCs, never raw table
  writes.
- **Identity pepper lives in a KMS/secret store, not in the database.** A hash whose
  pepper sits in the same database it protects is not a protection. See
  [02_DOMAIN.md §Identity](02_DOMAIN.md).
- **Automated sanctions require a human-reachable appeal path** — both because it is
  right and because GDPR Art. 22 constrains automated decisions with significant effects.
  See [04_TRUST.md](04_TRUST.md) and [09_OPEN_QUESTIONS.md](09_OPEN_QUESTIONS.md) Q-LEGAL.

---

## 12. What we keep from v1/v2

Flagging the code as bad (D1) does not mean the thinking was bad. These ideas are
load-bearing and carry forward — see [LEGACY_AUDIT.md](LEGACY_AUDIT.md) for the file-level
verdicts:

1. **Privacy enforced in RLS, not in callers.**
2. **Mutual-only signals.** One-sided warmth creates nothing and is never surfaced.
3. **The invisible decline** — nobody learns who said no.
4. **The asymmetry invariant** — nobody may infer how anyone rated them, including from
   the *pattern* of who they are matched with. This constrains the matchmaker (never
   re-pair deterministically) and it is why cooldowns provide cover.
5. **Explore/exploit**: never compose purely from the graph, or newcomers can never enter.
6. **Ambiguity is the tax this population cannot afford** — fixed durations, stated end
   times, explicit "what happens next".
7. The concurrency lesson: `SELECT … FOR UPDATE` on the parent row before counting
   children, or simultaneous confirmations lose updates.
