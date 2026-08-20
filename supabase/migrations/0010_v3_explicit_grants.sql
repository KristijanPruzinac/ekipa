-- 0010 · Say the grants out loud.
--
-- **The bug this fixes, stated plainly.** Nine migrations wrote row-level
-- policies and never wrote a single `grant select`. Against the hosted project
-- everything worked, because Supabase bootstraps
-- `alter default privileges in schema public grant all on tables to anon,
-- authenticated`, so every table created by a migration arrived pre-granted.
-- Against a stack started from these files alone, `select 1 from public.people`
-- returns *permission denied* — the first pgTAP run said exactly that, on the
-- first invariant, the first time it was ever executed.
--
-- Two things were wrong and only one of them was the failing test.
--
-- 1. **The privilege was ambient.** A policy says *which rows*; a grant says
--    *whether at all*. Writing only the first half means the data plane's
--    actual permissions live in a platform default rather than in this
--    directory, so the schema is not reproducible and `docs/v3/11_SECURITY.md`
--    §4's "RLS-first" is only true by luck.
--
-- 2. **`anon` could select from every one of those tables.** RLS with a policy
--    scoped `to authenticated` returns zero rows to an anonymous caller, so
--    nothing leaked — but the reason nothing leaked was a policy clause, with a
--    live grant sitting behind it. DP-2's default is deny, and a deny that
--    depends on remembering a `to authenticated` on every future policy is not
--    a default.
--
-- So: revoke the ambient grant, revoke the future one, and hand back exactly
-- the reads each policy was written to permit — one grant per policy, in the
-- same file, where the two can be read together.
--
-- **Rule 9 note.** The failing assertion was not weakened. `people` and
-- `availability` still answer `1` and `0` for the two people in the fixture;
-- they now answer it because a line in a migration says they may, rather than
-- because a platform default happened to.

-- ─────────────────────────────────────────────────────────────────────────────
-- Stop the bleeding: no future table arrives pre-granted.
--
-- This applies to objects created by the role that runs migrations, which is
-- the role that creates every table here. A table added in 0011 will be
-- unreadable by any client until somebody writes the grant — which is the
-- behaviour DP-2 describes and has not had until now.
alter default privileges in schema public
  revoke all on tables from anon, authenticated;

alter default privileges in schema public
  revoke all on sequences from anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Take back everything, then hand back what is written down.
--
-- Blunt on purpose. An enumerated revoke would have to be kept in step with a
-- table list that grows, and the failure mode of forgetting one is silent.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- The read surface, one grant per policy.
--
-- Each line below has a policy in an earlier migration that narrows it. The
-- comment names the narrowing, so a reader can check the pair without opening
-- two files.

-- Catalogues. Small, public-by-nature, and useless to an attacker: knowing that
-- `woman | man | other` exists is not information. They are still gated on
-- `authenticated`, because there is no anonymous surface in this product at
-- all — you verify, then you see anything.
grant select on table public.cities to authenticated;          -- cities_read
grant select on table public.genders to authenticated;         -- genders_read
grant select on table public.equipment to authenticated;       -- equipment_read
grant select on table public.activity_templates to authenticated;
                                                    -- activity_templates_read
grant select on table public.report_categories to authenticated;
                                                    -- report_categories_read

-- The caller's own rows. Every one of these policies resolves through
-- `current_person_id()`, so the grant is wide and the policy is a single row.
grant select on table public.people to authenticated;          -- people_read_self
grant select on table public.devices to authenticated;         -- devices_read_self
grant select on table public.availability to authenticated;
                                                    -- availability_read_self
grant select on table public.person_equipment to authenticated;
                                                    -- person_equipment_read_self
grant select on table public.person_activities to authenticated;
                                                    -- person_activities_read_self

-- The city's slots. Scoped by `slots_read_own_city`, because another city's
-- slots would publish where we operate and how thin each market is.
grant select on table public.slots to authenticated;           -- slots_read_own_city

-- Sanctions, restored: 0004 granted this explicitly and the blanket revoke
-- above took it back. A person sees the sanction they can already feel — never
-- the standing behind it (invariant 7).
grant select on table public.sanctions to authenticated;
                                              -- sanctions_read_own_visible

-- ─────────────────────────────────────────────────────────────────────────────
-- Deliberately **not** granted, each for a stated reason:
--
--   hangouts, hangout_members     read only through `my_hangouts()` and
--                                 `hangout_reveal()`, which enforce the time
--                                 gate that invariant 2 turns on. A direct
--                                 select would hand out names before reveal.
--   sigils, venues, venue_clusters read only through `hangout_reveal()`. The
--                                 catalogue would leak nothing much and buy
--                                 nothing at all, so DP-2's default stands
--                                 (0007 already said this in a comment; now the
--                                 comment and the ACL agree).
--   ratings, reports, edges,      invariants 1, 3, 4, 6, 7. Nobody reads these,
--   exclusions, infractions,      including about themselves. `denied` is the
--   standing, venue_feedback      strongest answer a privacy test can get, and
--                                 it is the answer these must give.
--   match_runs, match_run_groups  D9. Nothing about how a group was built ever
--                                 reaches a client.
--   config_versions, config_values,
--   admin_roles, admin_audit      console surface, reached through
--                                 `console_*` functions gated on admin_role().
--
-- The `execute` grants on functions are untouched: those were always written
-- explicitly, function by function, which is why they were right.
