# Database

The schema is owned by migrations. **This is the only way schema changes** (D4).

| Folder | Holds |
| --- | --- |
| `migrations/` | Schema, RLS policies, RPCs, triggers |
| `tests/` | pgTAP: the seven privacy invariants, trigger behaviour under concurrency, constraint coverage |
| `seed/` | Deterministic development fixtures |

Two rules that CI enforces, both learned the expensive way in v1:

1. **A `create table` without `enable row level security` in the same migration
   fails the build** (DP-1). An RLS mistake is a silent privacy breach, and "we
   reviewed the policy" is not a control.
2. **Revoke grants from role names, not `PUBLIC`.** Supabase writes `EXECUTE`
   grants to `anon` and `authenticated` as explicit per-role ACL entries, so
   `revoke ... from public` is a silent no-op. v1 migration `0003` believed it had
   locked its RPC surface; it had not, and `0004` fixed it.

Nothing here yet — the fresh project and `0001_v3_core.sql` land in chunk 5.
