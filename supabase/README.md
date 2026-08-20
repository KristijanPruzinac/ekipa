# Database

The schema is owned by migrations. **This is the only way schema changes** (D4).

| Folder | Holds |
| --- | --- |
| `migrations/` | Schema, RLS policies, RPCs, indexes |
| `tests/` | pgTAP: the seven privacy invariants, the RPC surface, the constraints that cannot be raced |
| `seed/` | Deterministic development fixtures |

The hosted project is **`ekipa-v3`**, free tier, `eu-central-1` (Frankfurt),
Postgres 17. Fresh, not migrated from v2 (Q-PROJECT).

---

## The migrations

Eight files rather than one, split by what they are *about* rather than by when
they were written, so a question has a file rather than a line range.

| File | What it establishes |
| --- | --- |
| `0001_v3_catalogue` | Registries and the public facts of a city: genders, cities, slots, venues, clusters, sigils, activities. The only tables a client may read in full. |
| `0002_v3_people` | Identity, people, devices, availability — and `current_person_id()`, the function every policy in the schema is built on. |
| `0003_v3_hangouts` | The lifecycle: states, hangouts, memberships, event logs. Neither hangout table is client-readable. |
| `0004_v3_trust` | Ratings, edges, exclusions, reports, infractions, sanctions, standing. No client SELECT anywhere except a *visible* sanction. |
| `0005_v3_config_and_runs` | Versioned config (D5), match runs and their reasoning, console roles, the append-only audit log. |
| `0006_v3_client_rpcs` | The client's entire read and write surface: seven functions, and nothing else. |
| `0007_v3_sigils` | 144 `(symbol, colour)` pairs, as codes rather than glyphs or hex. |
| `0008_v3_indexes` | The four indexes the advisor pass argued for, and why the other twenty-one were declined. |

---

## Two rules CI enforces, both learned the expensive way in v1

1. **A `create table` without `enable row level security` in the same migration
   fails the build** (DP-1). An RLS mistake is a silent privacy breach, and "we
   reviewed the policy" is not a control.
2. **Revoke grants from role names, not `PUBLIC`.** Supabase writes `EXECUTE`
   grants to `anon` and `authenticated` as explicit per-role ACL entries, so
   `revoke ... from public` is a silent no-op. v1 migration `0003` believed it
   had locked its RPC surface; it had not, and `0004` fixed it.

`dart run tools/lint/bin/migration_lint.dart` checks both, plus DP-2's
`-- catalogue:` marker, DP-5's `search_path` / revoke / grant triple, and rule
10 (no migration drops or shortens a trust or audit table).

---

## Running the tests

```
supabase start
supabase test db
```

Each file in `tests/` opens a transaction, includes `fixture.sql`, defines its
assertions as functions, runs them through pgTAP's `runtests()`, and rolls back.
They are order-independent and leave nothing behind.

`00_harness_is_honest.sql` runs first and is the reason to trust the rest: it
breaks an invariant on purpose and checks that the break is *visible*. Every
other privacy assertion passes by receiving the word `denied`, and a harness
that said `denied` to everything would report seven green invariants over a
wide-open database.

| File | Covers |
| --- | --- |
| `00_harness_is_honest` | The negative control: the suite can fail, and the role switch is real |
| `01_deny_by_default` | DP-1, DP-2, DP-3, DP-4 — whole-schema, so a table added next month is covered by a test written today |
| `02_privacy_invariants` | The seven invariants of [02_DOMAIN.md §6](../docs/v3/02_DOMAIN.md) |
| `03_rpc_surface` | DP-5, DP-6, DP-7 and the seven-function allowlist |
| `04_constraints` | One hangout per person per slot, sigil collision, the R2 gate, pair-table symmetry |

---

## What the advisor pass says, and why

DP-10 runs `get_advisors` before every release. Three classes of finding recur,
and all three are **intended**. They are written down here so the next pass is
read rather than skimmed.

**`rls_enabled_no_policy` — 21 tables, INFO.** This is the design, not a gap.
RLS enabled with no policy is deny-all, and that is the strongest form of
enforcement available because it cannot be got wrong in a `using` clause. Every
table on that list is one the client reaches through an RPC or not at all.

**`authenticated_security_definer_function_executable` — 7 functions, WARN.**
Exactly the seven RPCs in `0006`. Each is `security definer` on purpose: it is
the only way a caller can be shown a fact derived from rows they may not read.
Each opens with a caller check, pins `search_path`, and is revoked from `anon`
and from `PUBLIC` — verified in `03_rpc_surface.sql`, not asserted here.

**`unindexed_foreign_keys` — 25, INFO.** Four were added in `0008`, each with a
named query behind it. The other twenty-one reference a catalogue — genders,
activities, equipment, report categories, cities, config versions, admin users —
and a catalogue row is never deleted, which is the only thing an index on the
referencing side buys. They stay declined until a query asks for one.

**`unused_index` — 21, INFO.** The database has never served a real query. This
finding means nothing before the pilot and will mean something after it.
