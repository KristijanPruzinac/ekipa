# Ekipa — implementation plan

The one-sentence spec: _people answer a few taps, receive fully-organized
invitations to tiny low-pressure meetups, privately reflect on who they'd enjoy
meeting again, and the system crystallizes those mutual yeses into recurring
friend groups that eventually don't need the app._

> **v2 reconciliation (current).** Five decisions changed how the loop works
> since the first pass. They're folded into the phases below, but in one place:
>
> 1. **A first name is the only identity data.** The system-written "blurb" is
>    gone everywhere — profiles, the `confirmed_attendees` RPC, the UI.
> 2. **Reflection is four levels, not yes/no** — really enjoyed / enjoyed / no
>    preference / rather not. Only mutual warmth (both ≥ enjoyed) seeds a group;
>    "rather not" writes a silent, permanent exclusion.
> 3. **Names reveal at T−3h, not at confirmation.** A confirmed group first sees
>    only its shape (how many, what mix); first names arrive three hours before.
> 4. **There is a short logistics onboarding after the code** — first name,
>    city, gender, group size, availability, activities. This is a deliberate
>    softening of the original "zero onboarding" stance: logistics only, never a
>    profile to perform. Routing gates on profile-complete again.
> 5. **Palette runs two warmth registers** — moss = digital/system, amber/ember
>    = the paper & arrival layer (see DESIGN.md).

> **v2.1 reconciliation — hostless and venueless (current).** We can't organize
> anything: no venue partner, no reserved table, nobody on site. That's now a
> design commitment rather than a limitation, and it moves real work around.
> See PRODUCT.md for the reasoning; the mechanical consequences are:
>
> 1. **Meetups happen at curated outdoor spots**, not venues — quiet, free,
>    open, visible, populated-adjacent. A `spots` catalog replaces the flat
>    `venue_name` / `venue_note` text on `meetups`.
> 2. **The spot is predetermined, never voted on.** No pre-meeting group
>    decision of any kind. The app states place and time; you tap yes or no.
> 3. **The arrival protocol is a real feature, not a screen we forgot.** Group
>    name, precise pin, photo of the exact spot, arrival check-ins, a job for
>    the first arriver — the app is the host *and* the signage.
> 4. **The in-app question deck is promoted to v1 core.** With no host to start
>    the activity and no table to play cards on, the zero-equipment default is
>    what most meetups will actually run on. It stops being a later nicety.
> 5. **Equipment is a logistics field** ("I can bring cards / Uno / nothing").
>    Physical games are the bonus layer, never the foundation.
> 6. **Composition rules get explicit**: half graph / half wildcard, a repeat
>    cooldown of 2–3 meetups, never exactly one woman in a group, and
>    daylight-leaning visible spots for any new configuration.
> 7. **Winter is a known, unsolved cost.** Summer launch; an indoor-tolerable
>    fallback list is scheduled work, not a surprise.

## Phase 0 — Foundation ✅ (this scaffold)

- Flutter (Dart) project, targeting Android (and web for quick iteration/demo).
  iOS is deferred — no Mac in the current dev environment — and will be
  re-added when one is available; nothing in the design is iOS-hostile.
- Design system: one dusk theme (no light variant — see DESIGN.md), shared
  glass/glow widget kit.
- Data model + RLS encoding the two privacy invariants (invisible declines,
  one-way-private reflections).
- Working vertical slice on mock data: welcome (arrival) → invite → reflect.
  The first pass shipped with **no onboarding screens**; v2 adds one short
  logistics pass (see Phase 1) — logistics only, never a profile to perform.

_Started as an Expo/React Native prototype, then ported to Flutter once the
design decisions were validated — see the README for why._

## Phase 1 — Auth & logistics onboarding ✅ (client-side)

- Supabase phone auth (SMS) is the first thing asked of a new user. Then, once
  — a short **logistics** pass: first name, city, gender, group size, when
  they're free, what they'd show up for.
- **To add (v2.1): what you can bring.** A multi-select of equipment —
  a deck of cards, Uno, a board game, a ball, nothing — stored on `profiles`
  and read by the composer when it picks the activity for a group. It stays
  logistics: it's about objects, not about you, and no member ever reads
  another's list as a description of them. "Nothing" must be a completely
  ordinary answer, because it will be the majority answer.
- **Why this reverses the original "zero onboarding" stance.** The first pass
  tried to infer everything from behavior and ask nothing upfront. But the
  composer can't form anyone's *first* group from an empty profile — it needs a
  city, an activity, a rough availability, and (safety-relevant, un-inferable)
  gender and same-gender preference before the loop can even start. The honest
  reading of the principle isn't "ask nothing"; it's "never make someone perform
  themselves." So onboarding is strictly logistics — no bio, no photos, no
  personality, nothing another member ever reads. Behavioural refinement
  (narrowing activities/availability from accept-vs-decline over time) still
  layers on top; it just isn't the *only* source anymore.
- **No blurb.** The system-written one-liner is gone. A first name is the only
  thing one member ever learns about another. No free-text bio, no photos, no
  profile browsing anywhere in the app.
- Persist to `profiles`; routing gates on **profile-complete** again (a first
  name + city), cached in `ProfileStatus` so it isn't a per-navigation DB hit
  and cleared on sign-out.
- **Built:** `AuthScreen` (phone + code), `OnboardingScreen` (the logistics
  pass, `repository.saveProfile`), and a `GoRouter` redirect that sends a
  signed-in-but-unonboarded user to `/onboarding`. All of it is a no-op when no
  Supabase project is configured, so the mock-data demo path (see README) is
  untouched. `profiles` rows still auto-provision via the `handle_new_user`
  trigger; onboarding fills them in.

## Phase 2 — The invite loop (against Supabase) ✅ (client-side, untested against a live project)

- Home = your invitations, read from `meetups` + your own `meetup_members` row.
- Invitation screen: what-to-expect, the group's *shape* while confirmed but
  pre-reveal (`group_composition`), first names only inside the T−3h window
  (`confirmed_attendees`), the exit permission slip, and a two-step withdraw
  after yes.
- **Yes / Not-this-time** writes only your own RSVP. "No" is silent: the
  proposal simply "doesn't form", and RLS guarantees you never see who declined.
- Push notifications (`firebase_messaging` / FCM — the old `expo-notifications`
  reference predates the Flutter port): new proposal, day-before, morning-of
  confirmation tap.
- Morning-of: a no-confirm quietly shrinks/cancels the group and notifies
  everyone **before they leave home**. No-shows are the deadliest failure here.

**Built:** `lib/data/repository.dart` (`myInvitations`, `respond`,
`submitReflection`), wired into Home/Invite/Reflect with a mock-data fallback
when no backend is configured (see README). `supabase/migrations/0002_meetup_status_transitions.sql`
adds the trigger that actually flips a meetup to `confirmed` once every
member has said yes, or `cancelled` the instant anyone says no — 0001_init.sql
had the RLS invariants but nothing that made the status transition happen.
Home and Invite Detail reveal first names only inside the T−3h window (0007);
before that a confirmed group shows its shape (count + gender mix) via
`group_composition`, and an unconfirmed one shows nothing. `0008` makes the
status trigger race-free (a row lock serialises concurrent yeses) and lets a
confirmed member withdraw without punishing the rest.

**Not built:** push notifications, the morning-of confirmation flow, and —
important — none of this has been run against a real, provisioned Supabase
project. There isn't one yet. The code is written directly against the
schema in `supabase/migrations/`, but until a project exists and
`SUPABASE_URL`/`SUPABASE_ANON_KEY` are supplied via `--dart-define`, it's
verified by `flutter analyze`/`flutter test` and schema review, not a live
run. Provisioning the project and running the migrations is the next
concrete step, and needs a Supabase account.

## Phase 2b — Place, arrival, and the deck (v1 core, new in v2.1)

The hostless/venueless commitment concentrates almost entirely into the meetup
itself, and none of this is optional polish: with no host and no reserved
table, a meetup that nobody can find or nobody can start is a meetup that
fails. Everything here is v1.

**The spot catalog.** A `spots` table replaces the flat `venue_name` /
`venue_note` columns on `meetups` (which stay, denormalized, for the invite
copy). A spot is: city, display name ("the two benches by the fountain"),
precise coordinates, a **photo of the exact spot**, an arrival note describing
where to stand/sit and what you'll see, a surface flag (picnic table / wide
steps / grass only), and curation attributes — visibility, foot traffic,
whether it's fine after dark, weather exposure, seasons it's usable in. Seeded
by hand from a spreadsheet; there is no user-submitted-spot feature in v1.
The composer picks the spot; nobody votes on it, and the app never asks the
group to agree on anything before they've met.

**The arrival protocol** — a screen that becomes live in the hour before the
start time, and the most scripted surface in the app:

- A **group name** ("you're the Blue Fox group"), generated at confirmation, so
  the group is a findable thing rather than four unrelated people.
- The pin, the photo, and the arrival note, together, above the fold.
- **"I'm here"** check-in, showing how many of the group have arrived — counts
  only until the T−3h name reveal has happened, which it always has by then.
- **The first arriver gets an instruction, not a wait**: "take the bench facing
  the river — the others will find you."
- When everyone is marked present, the app **deals the opening move**: the
  first card, on everyone's screen at once. Nobody has to be the person who
  starts, because the app is.
- A quiet "I can't find them" path, since outdoors this will happen.

**The question deck.** A local deck of prompts (no network round-trip, works on
a bench with bad signal), dealt one at a time, skippable by anyone without
explanation, escalating gently over a session — the Aron-style payload
disguised as a game. This is the zero-equipment default and therefore the
actual activity of most meetups; it deserves the same care as the invite
ticket, not a list view. Physical games layer on top when the group's declared
equipment (Phase 1) allows, and the composer may favour a group where something
is available — but never at the cost of a good deck session.

**Not started.** No `spots` migration, no arrival screen, no deck content yet.
This is the largest single piece of unbuilt v1 work.

## Phase 3 — Reflect & crystallize (the graph)

> The mechanism — edge formation, weight, decay, cooldown, the slot model,
> degenerate states, and how any of it gets measured — is specified in
> **[GRAPH.md](GRAPH.md)**. This phase is the part that produces edges; Phase 4
> is the part that consumes them. Don't restate the rules here; they drift.

- Post-meetup: "how did it feel?" writes `reflections` at four levels — really
  enjoyed / enjoyed / no preference / rather not (built as UI). Never framed as
  rating. **The one thing the app will ask for**, one tap per person, once.
- `mutual_connections` (both ≥ enjoyed, neither excluded) is the graph; a
  "rather not" writes a silent, permanent `exclusions` row. Both built (0006).
- **`0009` — the schema the mechanism needs and cannot backfill.** Land this
  before the first real meetups, because none of this data is reconstructable
  afterwards (GRAPH.md §9):
  - `meetup_members.slot_kind` — why each person was placed. Without it there
    is no way to ever ask whether the composer beats randomness.
  - `attended` actually written (from the arrival check-ins, Phase 2b) and
    joined into edge formation. Today a meeting nobody attended can still form
    an edge (GRAPH.md §2).
  - `mutual_connections()` returning `(other_id, weight, last_met_at)` instead
    of a flat id — the four-level scale is currently collapsed to binary at
    exactly the point it was supposed to be useful.
  - `pair_history(a, b)` for the cooldown.
- **Reflection submission rate is a v1 health metric**, not a nice-to-have. No
  reflections → no edges → no mechanism, however good the composer is
  (GRAPH.md §7).
- **Stage ladder** = graph density around a user (GRAPH.md §6): mixing →
  cohort (a mutual 3–4 clique, offered as an opt-in standing group, never a
  silent lock-in) → graduation (~8–10 meets; let them exchange numbers). The
  app succeeding means getting out of the way — design for it proudly.

## Phase 4 — The composer (consuming the graph)

> Composition rules live in **[GRAPH.md §4](GRAPH.md)** — hard constraints, the
> four-slot model, the two invariants (always ≥1 wildcard slot; never >half
> repeats), and the cooldown. This phase is the delivery vehicle for them.

- Edge Function, run weekly by cron **and** on-demand from an admin view.
- Input: active profiles (city, availability ∩, ≥1 shared activity, equipment),
  the weighted mutual-warmth graph, exclusions, blocks, reliability, pair
  history, and the spot catalog. Output: proposed `meetups` + `meetup_members`
  (each with its `slot_kind`) + a chosen spot.
- Spot/activity selection: prefer a spot whose surface fits the activity and an
  activity the group's declared equipment supports — with the in-app deck as
  the always-valid default, so no group ever depends on someone remembering to
  bring something.
- **Concierge mode first:** you run the same function by hand from an admin
  screen for the first month or two — seeds cohorts, surfaces edge cases,
  validates the loop before automating. At launch it is pure wildcards, because
  the graph is empty; that's the design working, not a missing feature.
- Internal **reliability score**: flakes matched with flakes, reliable people
  protected. Never shown, never shames. Once no-show data exists, **overbook to
  5 for a 4-person meetup.**
- **Instrument it from the first run: edge yield by slot composition**
  (GRAPH.md §8). If graph-composed groups don't out-yield random ones, the
  composer is decoration and gets deleted rather than tuned.

## Phase 5 — Trust & safety

- Phone verification behind the scenes; display is first-name only.
- Same-gender-only grouping honored end to end.
- New configurations meet only at **open, visible, populated-adjacent spots**,
  in daylight where the slot allows. Visibility is the safety mechanism — a
  roof isn't one. Secluded spots never enter the catalog, however pleasant.
- Silent exclusions: an explicit **block-and-report** (`blocks`) and the implicit
  "rather not" reflection (`exclusions`) both guarantee the pair is never grouped
  again; nobody is notified either way.
- Loud, repeated framing: **this is for friendship.** Groups of 3–4 (not pairs)
  for new configs structurally defuse romantic ambiguity.

## Phase 6 — Closed beta

- One city (Osijek), **walks + board games only** — cheapest to organize, most
  silence-tolerant. Composer needs ~30–50 active users to form groups reliably.
- **Launch into summer**, deliberately: outdoor-only is a warm-months product,
  and the first season is the one where the format is cheapest to run.
- **Curate 10–15 spots by hand before launch** — walk them, photograph them,
  check them for visibility and foot traffic at the hours we'd actually use.
  This is a weekend of legwork and it is load-bearing.
- Personally seed the first ~10 meetups (invite by hand, be reachable that
  evening). Do the unscalable things at ignition.
- Recruit where the population already is: local subreddit/Discord, FERIT
  student groups, neurodivergent/introvert communities, bouldering-gym board.
- Pitch: _"An app where you never text anyone, organize anything, or meet more
  than three people at once."_
- **The only metric that matters here is retention** — did people come back.
  Nothing about matching quality is measurable until the graph has substance.

## Phase 6b — Winter (the scheduled reckoning)

Outdoor-only means the app hibernates November–March in continental Croatia.
That's the honest cost of dropping venues and it doesn't need solving before
launch, but it does need solving before the first autumn:

- A small **indoor-tolerable fallback list** in the spot catalog, flagged as
  seasonal: quiet cafés off-peak, a library corner, a covered terrace.
- Spot records already carry weather exposure and usable seasons (Phase 2b), so
  this is mostly curation plus a composer filter, not new architecture.
- Framed to users as a weather fallback, which everyone understands. It must
  never quietly become the default — the outdoor spot is the product.

## Phase 7 — Thought-aware composition (later, after the graph works)

Only once the loop retains people and the graph has substance: a light
recurring prompt when scheduling ("what's been on your mind lately?", one
sentence), embedded and used to decide *which* graph-compatible people are
grouped this week. It composes groups; it never replaces the graph, and it is
never shown to another member as a description of a person — which is the line
that keeps it compatible with first-name-only identity.

- **Rare overlaps outweigh common ones.** Similarity scoring discounts topics
  common across the user base and amplifies rare ones (inverse-frequency
  weighting, TF-IDF-style). Two people who both "like walks" share nothing the
  composer doesn't already know; two people currently chewing on the same
  niche thing share a lot. Without this, generic overlaps drown the signal —
  the whole point of the prompt.
- **Recency is the trigger, not the substrate.** The weekly sentence captures
  *current* preoccupation — conversational fuel, weighted for scheduling.
  Optionally, a small one-time set of reflective questions at some point
  *after* the first meetup ("what could you talk about for an hour?",
  "something you changed your mind about recently") gives the embedding a
  stabler substrate underneath the weekly signal. Strictly machine-read: never
  rendered to any member, ever, framed and stored as composer input — the same
  logistics-not-performance line onboarding already walks. Skippable without
  consequence.
- **The deck nudge.** The one place thought data may surface: a deck card
  saying "two of you have been thinking about similar things lately" —
  deliberately not who, and not what. It exists because computed similarity
  only opens doors; the durable effect comes from the group *discovering* the
  overlap live. It must pass the GRAPH.md §5 asymmetry audit before it ships
  (it reveals composer reasoning, and composer reasoning is downstream of
  reflections); if it can't be worded to pass, it doesn't ship.

The honest test comes free with it: do thought-composed groups actually
produce more mutual warmth than random ones (edge yield by slot composition,
GRAPH.md §8)? That's the first real evidence the matching does anything, and
if it doesn't, this phase gets deleted rather than tuned.

## Beyond the roadmap (far horizon — recorded so it isn't relitigated)

None of this is scheduled; it's the founding conversation's long tail, kept
here so future decisions don't accidentally close doors to it.

- **Circumstance layers.** Connection by shared situation (expats, students far
  from home, people navigating the same thing) is a *different layer* from
  friendship-by-warmth — the multiplex-network insight. If ever built, it's a
  separate matching dimension with its own rules, never averaged into one
  score.
- **Learned composition.** A model predicting which compositions yield edges,
  trained on our own outcome data (GRAPH.md §9.5). Worthless before a few
  hundred completed meetups; the `slot_kind` instrumentation exists so this
  stays possible.
- **Second city.** The venueless design's payoff — nothing physical to
  replicate. Spot curation is the only per-city legwork.
- **The open version.** The original thought experiment — an open-source,
  possibly federated protocol for finding like-minded people, matching without
  a central party holding anyone's corpus. This product is deliberately the
  small, honest, local version of that idea; if it ever grows toward the big
  one, open-sourcing the mechanism is the natural move, because trust *is* the
  product.
- **Romance: not a feature, and if ever, last.** The research this product was
  designed against says pair-chemistry is unpredictable from any profile data
  (Joel et al. 2017) — so the honest romance feature is not a matching
  algorithm but an explicit, separate, clearly-labeled opt-in mode on the same
  meeting machinery. Until then the stance stays what PRODUCT.md says: loudly,
  repeatedly, for friendship.

## Money (later, never at the start)

- Charge at **Stage 2** (the standing group) — the point the app has
  demonstrably delivered. A few € / month for "your group runs on autopilot".
- Never per-message, never boosts, never coupons — all import dating-app
  psychology this product explicitly rejects.
- ~~Venue partnerships (board-game cafés, climbing gyms)~~ — dropped in v2.1.
  The product is venueless by design; a café can only reappear on the winter
  fallback list, as a weather answer, never as a partnership or a default.

## Deliberately NOT building

- No feed, no likes, no follower counts, no public profiles.
- No open-ended chat before a meeting. The meeting is the product.
- No "initiate a meetup" button. Ever.
- **No voting on place or time**, and no group decision of any kind before the
  group has met. Every pre-meeting decision is a chance for the meeting to
  dissolve; the app decides and you answer yes or no.
- **No host role**, appointed or volunteered. The app is the host; making a
  user the host hands the initiator job to the person least willing to take it.
- **No user-submitted spots** in v1. Curation is the safety mechanism.
- Nothing that shows anyone how they were reflected on, in any aggregate,
  score, or streak — not even a positive one.
