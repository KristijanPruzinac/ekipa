# Legacy audit — everything written before 2026-08-18

Directive **D1**: *"flag all previous code we had as BAD CODE… we want to reuse existing
logic but mostly make from scratch."*

**Blanket verdict: all 31 Dart files, all 8 migrations and all 6 v1/v2 design documents
are legacy. Nothing here may be imported, extended, or copied into `packages/` or
`apps/`.** The plan is to move the code to `legacy/` at P0 (so an accidental import
cannot compile) and delete it at P2 exit.

One honest qualification, because a false verdict is as useless as no verdict: **this is
not incompetent code.** It is *prototype-grade code with an unusually good privacy
model*, written to prove a different product. The reasons it must go are that it encodes
the wrong domain (`meetup`, RSVP-to-form, blurbs, no hangout lifecycle), and that its
structure makes the v3 requirements — testability, algorithm reuse, config-driven
behaviour — unreachable without rewriting the same files anyway. §4 lists what genuinely
carries forward, and it is not nothing.

---

## 1. Structural defects (why the shape, not just the content, is wrong)

| # | Defect | Where | Why it is disqualifying for v3 |
| --- | --- | --- | --- |
| S1 | **Global mutable singletons created at import time** | `repository.dart:142`, `profile_status.dart:24`, `router.dart:68-70` | No injection point ⇒ no test can substitute a fake ⇒ every test needs a live backend. The repo's own history shows the symptom: commit `6ec65d9` "Reset the router between widget tests" is a workaround for a global that should never have been global. |
| S2 | **Mock-vs-real branching inside UI and routing** | `home_screen.dart:33`, `router.dart:76` | `isBackendConfigured ? repository… : mock…` puts an environment decision in a widget. Fakes belong at the composition root; a screen must not know a backend exists. |
| S3 | **God repository** | `repository.dart` — auth + profile + invitations + reflections in one class | One class with four reasons to change; no aggregate boundaries; unmockable in parts. |
| S4 | **Domain types parse database rows** | `models.dart` `Profile.fromRow`, `Meetup.fromRow`, `Attendee.fromRow` | Infrastructure leak into the domain: the domain cannot be tested or reused without a schema, which directly blocks D3 (algorithms reusable everywhere). |
| S5 | **No algorithm layer at all** | — | The matchmaker — the actual product — does not exist in code. There is nowhere it could live under this structure. |
| S6 | **No config layer** | constants inline throughout | D5 (master console changes behaviour) is unimplementable without rewriting every call site. |
| S7 | **No error model** | every async call | `FutureBuilder` with `snapshot.data ?? const []` renders a *failed load as an empty state* (`home_screen.dart:54`) — a network error silently reads as "no invitations". |
| S8 | **Null-assertion on session state** | `repository.dart:45,91,104,127` `currentUser!.id` | Crashes on the sign-out race instead of returning a typed error. |
| S9 | **N+1 queries** | `repository.dart:44-73` — an RPC per meetup inside the loop | Fine at three rows, wrong as a pattern. |
| S10 | **IO inside a router redirect** | `router.dart:85` `await profileStatus.isComplete()` | Navigation blocks on the network; the guard is untestable and unstubs nothing. Session state belongs in a state machine the router reads synchronously. |
| S11 | **Domain objects passed through `state.extra`** | `router.dart:113,121,135` | Deep links and cold starts cannot reconstruct the object, which is why a mock lookup (`_mockMeetupById`) sits in the router as a fallback. |
| S12 | **Partial `copyWith`** | `models.dart:207-238` — `city`, `durationMin`, `expiresAt` are not copyable and nothing says so | The kind of silent surprise that produces a bug report six months later. |
| S13 | **Layer-first folders** | `screens/`, `widgets/`, `models/`, `data/` | Already showing strain at six screens; v3 has ~25. Feature-first from P0. |
| S14 | **One smoke test** | `test/widget_test.dart` (72 lines, whole suite) | The v3 plan is built on property-based, simulation and pgTAP testing. Starting point is effectively zero. |

---

## 2. File-by-file verdicts

`DELETE` = gone at P0. `SALVAGE-IDEA` = the code goes, the reasoning is carried into
`docs/v3/`. `PORT` = rewritten from scratch in the new structure, using this as a visual
or behavioural reference only.

### Dart — `lib/` (31 files, 4 161 lines)

| File | Verdict | Note |
| --- | --- | --- |
| `main.dart` | DELETE | New composition root with DI + config bootstrap. |
| `router.dart` | DELETE | S1, S10, S11. Replaced by a session state machine + typed routes. |
| `models/models.dart` | DELETE | S4, S12. Replaced by `freezed` domain types in `ekipa_core` + DTOs in `ekipa_data`. **Salvage:** the four-level sentiment and its wire mapping — the *concept*, not the class. |
| `data/repository.dart` | DELETE | S3, S8, S9. **Salvage:** the stance in its doc comment — *"this class never filters for privacy, only for convenience; the server enforces it."* That sentence is correct and becomes an architectural rule in v3. |
| `data/supabase_client.dart` | DELETE | Replaced by an injected client. |
| `data/mock_data.dart` | DELETE | S2. Replaced by fakes at the composition root. |
| `data/profile_status.dart` | DELETE | S1. Replaced by session state. |
| `data/activities.dart` | SALVAGE-IDEA | The catalogue idea survives as `ActivityTemplate` registry ([06_ACTIVITIES.md](06_ACTIVITIES.md)). |
| `data/format.dart` | PORT | Date formatting is the one genuinely reusable utility here. Rewrite with locale + timezone awareness (v3 is multi-city). |
| `theme/tokens.dart`, `theme/colors.dart`, `theme/text_styles.dart`, `theme/theme.dart` | PORT | The token approach is right and is the seed of `packages/ekipa_ui`. Values get redone against the new visual direction ([docs/reference](../reference/README.md)). |
| `widgets/*` (12 files) | PORT | `Screen`, `AppCard`, `AppButton`, `AppTag`, `AppText`, `PressableScale`, `Appear`, `AnimatedHeadline`, `Starfield`, `TicketCard`, `ActivityIcon`. Rebuilt in `ekipa_ui` as a proper primitive set with golden tests. The *motion* vocabulary (gentle fade-through, pressable scale, staggered appear) is worth keeping — it is the one part of the old app that reads as designed rather than assembled. |
| `screens/*` (6 files, 1 663 lines) | DELETE | Wrong product (welcome → invite → reflect). The new flow is onboarding → availability → hangout lifecycle → arrival → ratings. |

### SQL — `supabase/migrations/` (8 files, 575 lines)

| File | Verdict | Note |
| --- | --- | --- |
| `0001_init.sql` | DELETE | Wrong domain (`meetups`, `blurb`, `would_meet_again`). **Salvage:** the RLS shape — own-row policies plus `security definer` functions as the only cross-user path. |
| `0002`, `0008` (RSVP triggers) | DELETE | v3 replaces RSVP-to-form with confirmation + backfill. **Salvage:** the concurrency lesson in `0008` — take `SELECT … FOR UPDATE` on the parent before counting children, or simultaneous yeses lose updates. That bug will recur in the confirmation path; the fix is already known. |
| `0003`, `0004` (advisor hardening) | DELETE | **Salvage — the most valuable single lesson in the repo:** Supabase grants `EXECUTE` to `anon`/`authenticated` as explicit per-role ACL entries, so `REVOKE … FROM PUBLIC` is a silent no-op. Revoke from the role names. `0003` believed it had locked the RPC surface; it had not. |
| `0005` | DELETE | Same lesson, applied to `mutual_connections`. |
| `0006` (identity minimalism, 4-level reflection) | DELETE | **Salvage:** dropping the system-written blurb, and `rather_not` as a permanent silent exclusion in its own table. Both are v3 rules. |
| `0007` (reveal gate, expiry) | DELETE | **Salvage:** the late name reveal and the group-shape-before-names function. v3 keeps both, at T−60m. |

**Schema-level defects worth recording:** `meetup_members.attended` was never written by
anything (so a no-show could accumulate friend edges); `reflections` carried both
`would_meet_again` and `sentiment` after `0006`, two representations of one fact; there
was no slot model, no venue model, no trust model, and no matchmaker.

### Docs — `docs/` (6 files, 1 734 lines)

Archive to `docs/legacy/`, keep readable, never cite as truth.

| File | Verdict |
| --- | --- |
| `PRODUCT.md` | ARCHIVE — **highest-value legacy document.** Its reasoning about who this is for, why they are structurally isolated, hostless meetings, the first five minutes, and gender-composition failure modes carries into v3 and should be re-read before UX work. |
| `GRAPH.md` | ARCHIVE — the explore/exploit slot model, edge decay, cooldown-as-cover and the asymmetry invariant are all reused in [03_MATCHMAKER.md](03_MATCHMAKER.md), restated for the new domain. |
| `DESIGN.md` | ARCHIVE — superseded by the new visual direction. |
| `PLAN.md`, `REBUILD_PLAN.md`, `FINALIZATION_PLAN.md` | ARCHIVE — superseded by [08_ROADMAP.md](08_ROADMAP.md). |
| `README.md` (root) | REWRITE at P0 — it currently describes the v2 product as the truth. |

### Assets

`assets/backgrounds/*`, `assets/textures/paper.jpg` — KEEP for now, re-evaluate against
the new direction. Note the working tree currently has `welcome_dusk.jpg` deleted and
`welcome_dusk.png` untracked, plus uncommitted edits to `android/gradle.properties`,
`welcome_screen.dart`, `app_card.dart`, `screen.dart`, `starfield.dart`. **Commit or
discard these before the quarantine move**, so the reorganisation is a clean rename in
git history rather than a mixed diff.

---

## 3. Quarantine procedure (P0, first commit)

1. Commit or discard the working-tree changes listed above.
2. `git mv lib legacy/v2/lib`, `git mv supabase legacy/v2/supabase`,
   `git mv test legacy/v2/test`, `git mv docs/{PLAN,GRAPH,DESIGN,PRODUCT,REBUILD_PLAN,FINALIZATION_PLAN}.md docs/legacy/`.
3. Add `legacy/` to the analyzer exclude list and to a CI check that fails if any file
   outside `legacy/` imports from it. *Intention: the flag has to be mechanical. A
   comment saying "do not use" is not a control.*
4. `legacy/README.md` pointing here.
5. Delete `legacy/` at P2 exit. If nothing has been needed from it by then, nothing will
   be — and a dead tree in the repo is a tax on every search, every grep, and every
   future contributor's mental model.

---

## 4. What survives (the reason this audit is not just a delete list)

Carried into `docs/v3/` and binding on the new code:

1. **Privacy enforced in RLS, not in callers** — and tested with pgTAP this time.
2. **Mutual-only signals**; one-sided warmth creates nothing and is never surfaced.
3. **The invisible decline** — nobody learns who said no.
4. **The asymmetry invariant** — nobody may infer how anyone rated them, *including from
   the pattern of who they are matched with*. This is the constraint that forces
   non-deterministic re-pairing and makes cooldowns load-bearing.
5. **Explore/exploit**: never compose purely from the graph, or newcomers cannot enter.
6. **Late name reveal**; group shape before names.
7. **Ambiguity is the tax this population cannot afford** — fixed durations, stated end
   times, explicit "what happens", a normalised exit script.
8. **Two operational lessons that cost real debugging time:** revoke Supabase function
   grants from role names, not `PUBLIC`; lock the parent row before counting children.
9. **The motion vocabulary** of the UI kit.

Everything else is rewritten.
