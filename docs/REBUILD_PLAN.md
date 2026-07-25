# Ekipa — v2 rebuild & completion plan

> **STATUS (2026-07-26): largely executed / superseded — historical record.**
> Product truth now lives in `PRODUCT.md`, `PLAN.md`, `DESIGN.md`, `GRAPH.md`.
> Read those first; use this file only for the reasoning behind decisions.
>
> - **Open decisions, resolved:** #1 the v2 docs were written and are canonical
>   (Phase A2 done). #2 the onboarding reversal was confirmed and built
>   (logistics-only pass, PLAN Phase 1). #3 `rather_not` got the dedicated
>   `exclusions` table (option b, as recommended). #4 (scheduler) and #5
>   (admin panel shape) remain genuinely open and now live with Phase B/C
>   work in PLAN.md.
> - **The migration ledger below is stale.** The live sequence consolidated
>   A3+A4 into `0006_v2_identity_and_reflection.sql` (blurb removal +
>   four-level sentiment + exclusions), landed the T−3h gate as `0007` and the
>   race-free trigger + post-confirmation withdraw as `0008`; `0009` is now
>   reserved for the graph-mechanism schema (`slot_kind`, attendance-gated
>   edges, weighted `mutual_connections()`, `pair_history` — GRAPH.md §9).
> - Phases B/C remain the open back half and are sequenced in PLAN.md
>   (Phases 2b–6) rather than here.

Derived from the code review dated 2026-07-24. This plan turned that review
into an ordered, dependency-aware build sequence for the sessions that
followed.

## Read this first — two honesty flags

1. **I do not have the canonical "spec v2" in the repo or memory.** Memory
   (`ekipa-project.md`) and `docs/PRODUCT.md`/`docs/PLAN.md` currently encode
   the *v1* principles. Every "v2 says…" statement in this plan is taken from
   the review text, not from a canonical document I can point to. Before Phase
   A item **A2** (doc rewrite) I need the actual v2 content from you — either
   you paste it, or you confirm "reconstruct it from the review." Until then I
   can implement the code changes (they're concrete) but I should not author
   authoritative product docs from my own reconstruction and risk drift.

2. **Restoring onboarding reverses a decision we committed.** "Zero onboarding
   screens" is currently documented as load-bearing in memory and in
   `DESIGN.md`/`PLAN.md`, and I deleted the onboarding screen on your explicit
   instruction. The review argues (persuasively) that *logistics* taps (city,
   gender, availability, group-size, same-gender-only) are not the
   *self-presentation* we were killing, and that the composer literally cannot
   run without availability/gender. I agree with the reasoning, but this is a
   real reversal — it needs your explicit "yes" once, and then memory + the
   design docs must change to say "no self-presentation" rather than "no
   onboarding," so a future session doesn't rip it back out.

---

## Phase 0 — deploy-now security fix (minutes, no dependencies)

**0.1 — Close the `mutual_connections` breach.** Verified live: the function
is `SECURITY DEFINER`, granted to `authenticated`, takes an arbitrary `u
uuid`, and has no `u = auth.uid()` check — so any signed-in user who knows
another user's UUID (which `confirmed_attendees` hands out) can enumerate that
person's mutual-yes edges. The client (`repository.dart`) never calls it; only
the future composer (service role) needs it.
- Migration `0005_lock_mutual_connections.sql`: `revoke execute on function
  mutual_connections(uuid) from authenticated;` plus, as defense in depth, add
  `where … and r1.rater_id = auth.uid()` is *not* right here (the composer
  needs arbitrary `u`) — so instead keep the revoke as the whole fix and rely
  on service-role-only access. Document that the composer must run as service
  role.
- Verify: role-impersonated call as user 1 for user 2's id returns
  `permission denied`; service-role call still works.

This ships independently of everything below and should not wait for plan
approval of the rest.

---

## Phase A — align the slice with v2 (cheap now, expensive later)

Order matters: schema-shape changes (blurbs, reflection scale, expiry) before
the screens that render them; the security/flow bug fixes are independent and
can land in parallel.

**A1 — Bug/flow fixes (independent, do alongside anything):**
- **Accept → wrong screen.** `router.dart` sends accept to `/reflect`. Change:
  accept returns to `/home` in the "you said yes" state; `/reflect` is reached
  only from a *completed* meetup. (Reflect entry point gets rebuilt properly in
  Phase B/no-show work; for now just stop routing there on accept.)
- **Silent RSVP failure.** `invite_detail_screen._respond` swallows the
  network error and proceeds as "recorded." Change: surface the failure, keep
  the user on the invite in an error state, let them retap. A phantom
  "accepted-but-not-recorded" no-show is the exact trust-killer to avoid.
- **Post-confirmation cancel does nothing.** The `handle_rsvp_change` trigger
  only transitions from `proposed`/`forming`. A `no` after `confirmed` is
  silently dropped. Add a cancellation path (part of the morning-of work in
  Phase B, but stub the DB path now so a late `no` isn't lost).
- **Trigger race window.** The count-based confirm check can double-fire under
  simultaneous RSVPs. Add `select … for update` on the meetup row (or re-check
  under lock) in `handle_rsvp_change`.
- **Home shows only the first fresh invite.** `home_screen` renders
  `fresh.first`. Render all non-standing proposed/forming invitations.

**A2 — Rewrite `docs/PRODUCT.md` + `docs/PLAN.md` to v2.** GATED on the v2
source (flag #1). Deliverables once unblocked: graduation-as-infrastructure
(standing groups with open seats, not exit), no-lone-newcomer / 2+2, 24h
proposal expiry, no-show escalation ladder, symbol/color recognition, T−3h
name reveal, four-level reflection. Also update memory (`ekipa-project.md`)
and `DESIGN.md` in the same pass so v1 assumptions stop reinfecting future
sessions. Do this *first* among the doc/spec work — it steers everything.

**A3 — Remove blurbs entirely.** v2: first name is the only identity data.
- Migration `0006_drop_blurb.sql`: `alter table profiles drop column blurb;`
  (destructive — the live DB has seeded blurbs; that's fine, they're test
  rows, but note it). Rewrite `confirmed_attendees` to return `(id,
  first_name)` only.
- Dart: drop `blurb` from `Attendee` + `Attendee.fromRow`; remove from
  `Profile`; delete blurb rendering in `invite_detail_screen` and
  `reflect_screen`. Attendee rows become first name + shared context (e.g.
  later "from your Tuesday walk").
- Re-seed the test rows without blurbs.

**A4 — Four-level reflection.** v2: really_enjoyed / enjoyed / no_preference /
rather_not, where `rather_not` is a silent permanent never-compose.
- Migration `0007_reflection_sentiment.sql`: change
  `reflections.would_meet_again boolean` → `sentiment text check (sentiment in
  ('really_enjoyed','enjoyed','no_preference','rather_not'))`. Handle existing
  rows (map true→enjoyed, false→no_preference, or just truncate test data).
- Rewrite `mutual_connections`: mutual = both parties `>= enjoyed`.
- **Decision needed:** how `rather_not` becomes "never compose again." Options:
  (a) write a row into `blocks` — simplest, but conflates a soft "rather not"
  with an explicit safety block/report; (b) a dedicated `exclusions` table the
  composer unions with `blocks`. I recommend (b) — keep the safety-grade
  `blocks` table distinct from reflection-derived soft exclusions. Flag for
  your call.
- Redesign the Reflect screen as a four-option row per person, preserving the
  current visual warmth (the heart-pop becomes a four-state selector).
- Update `repository.submitReflection` signature (`Map<String,bool>` →
  `Map<String, Sentiment>`).

**A5 — Proposal expiry (24h).** No `expires_at` exists anywhere.
- Migration `0008_proposal_expiry.sql`: add `meetups.expires_at timestamptz`;
  default `created_at + interval '24 hours'`. An expired unanswered proposal is
  treated as a silent decline (→ cancelled), same privacy semantics as a `no`.
- Enforcement needs a scheduler (pg_cron in Supabase, or the morning-of edge
  function in Phase B). For now: add the column + treat `now() > expires_at` as
  non-actionable in `myInvitations`; wire real expiry sweep in Phase B.

**A6 — Move name reveal to morning-of (T−3h).** Currently
`confirmed_attendees` returns names the instant everyone accepts (could be days
early).
- Rewrite `confirmed_attendees` to return rows only when `now() > starts_at -
  interval '3 hours'`. Before that, the invite card shows group size + gender
  composition ("3 people: 2 women, 1 man") instead of names — which requires
  A7 (gender collected) to be real.

**A7 — Restore minimal post-OTP onboarding.** GATED on flag #2 (your explicit
yes). ~90 seconds, all taps, framed as logistics, not a profile:
- Screens after OTP: first name, city (default Osijek), gender +
  same-gender-only toggle, availability grid, group-size comfort.
- Write to `profiles` (finally populate `gender`, `availability`,
  `group_size_pref`, `same_gender_only` — none are written today; `gender`
  isn't even parsed in `Profile.fromRow`).
- Router: gate on "profile complete" after auth, before Welcome.
- Keep behavioral inference for activities + talk_level (where it genuinely
  shines); stop trying to infer availability/gender/city (impossible or
  proposal-burning).
- This unblocks A6's gender-composition card and the composer's core inputs.

**A8 — Remove the dead `emoji` column** from `meetups` (v1 residue;
`DESIGN.md` says no emoji anywhere). Migration folded into one of the above.

**Phase A verification:** re-run `get_advisors`; re-run the RLS/trigger
role-impersonation checks; `flutter analyze` + `flutter test` (extend the
widget test for the new reflect UI and the accept→home routing); rebuild web
against the live project and screenshot the corrected flow.

---

## Phase B — the missing spine (the product's back half)

Larger, mostly new surfaces. Sequenced so the concierge can actually run the
manual phase as early as possible.

**B1 — Morning-of confirmation flow.** T−3h "still coming?" tap, T−2h
viability check, auto-cancel-before-anyone-travels messaging. Needs scheduled
execution — **decision:** pg_cron + a Postgres function, or a Supabase edge
function on a schedule. Recommend edge function (keeps logic testable, one
place for all time-based sweeps: expiry from A5, morning-of, no-show).

**B2 — Meeting-day screen.** Add `symbol` + `color` columns per meetup;
full-screen recognition display; live "2 of 3 on the way" state; anonymous
"running late" tap. This is the in-person hand-off; it's where ambiguity is
highest and the design matters most.

**B3 — No-show ladder.** Use the existing unused `attended` column +
`reliability`; three-step escalation; reliability never shown, never shames
(existing invariant).

**B4 — Admin / concierge panel (web, same API).** User list, availability
view, mutual-edge graph, manual group composition, proposal edit + send.
**Build this before the composer algorithm** — it's what lets you run the
manual concierge launch, and it becomes the composer's UI later. Likely a
separate route set / build flavor of the same Flutter app, service-role-gated.
**Decision:** same app behind an admin gate vs. a separate minimal tool.

**B5 — Settings, History, block/report UI.** Settings is where the
same-gender toggle and future preferences live; History is past meetups;
block/report finally makes the `blocks` table reachable from the UI.

---

## Phase C — automation

**C1 — Composer edge function.** Implements the v2 matching rules:
no-lone-newcomer / 2+2, edge maximization, reliability pairing,
newcomer-within-7-days, per-user load limits. Runs as service role
(dovetails with the Phase 0 security fix). Concierge-triggerable first
(reuses B4's UI), automated later.

**C2 — Standing groups.** Clique detection over mutual edges → opt-in cohort
proposal → cadence scheduling → open-seat backfill. Beyond today's `is_standing`
boolean.

**C3 — Push notifications** (new proposal, day-before, morning-of).

**C4 — Connect the SMS provider** (Twilio/MessageBird/Vonage in the Supabase
dashboard → Auth → Providers → Phone). Manual, your side, no tooling reaches
it. Until done, real phone sign-in can't deliver a code; the app runs in
mock/demo mode without it.

---

## Migration ledger (new files this plan adds)

- `0005_lock_mutual_connections.sql` — Phase 0
- `0006_drop_blurb.sql` — A3
- `0007_reflection_sentiment.sql` (+ exclusions table if we pick option b) — A4
- `0008_proposal_expiry.sql` — A5
- `0009_confirmed_attendees_time_gate.sql` — A6
- `0010_meetups_symbol_color.sql` — B2
- (onboarding writes need no schema change beyond using existing columns)

## Open decisions to resolve before/at each gate

1. **v2 doc source** (blocks A2): paste v2, or authorize reconstruction.
2. **Onboarding reversal** (blocks A7): confirm we re-add a post-OTP logistics
   gate and update memory/DESIGN accordingly.
3. **`rather_not` storage** (A4): overload `blocks` vs. new `exclusions` table
   (I recommend the latter).
4. **Scheduler** (A5/B1): pg_cron vs. scheduled edge function (I recommend edge).
5. **Admin panel shape** (B4): admin-gated route in the same app vs. separate
   tool.

## Suggested first move

Phase 0 (security) ships immediately regardless. Then the highest-leverage 20
minutes is A2 (rewrite the v2 docs) — but that's gated on decision #1. So the
practical first block is: **Phase 0 + all of A1 (bug fixes) + A3 (blurbs) + A8
(emoji)**, none of which are gated, while you resolve decisions #1 and #2.
