# Ekipa — implementation plan

The one-sentence spec: _people answer a few taps, receive fully-organized
invitations to tiny low-pressure meetups, privately mark who they'd see again,
and the system crystallizes those mutual yeses into recurring friend groups that
eventually don't need the app._

## Phase 0 — Foundation ✅ (this scaffold)

- Flutter (Dart) project, targeting Android (and web for quick iteration/demo).
  iOS is deferred — no Mac in the current dev environment — and will be
  re-added when one is available; nothing in the design is iOS-hostile.
- Design system: one dusk theme (no light variant — see DESIGN.md), shared
  glass/glow widget kit.
- Data model + RLS encoding the two privacy invariants (invisible declines,
  one-way-private reflections).
- Working vertical slice on mock data: welcome (arrival) → invite → reflect.
  **Zero onboarding screens** — no upfront chip-pickers or preference forms;
  see Phase 1 for how the profile actually gets built.

_Started as an Expo/React Native prototype, then ported to Flutter once the
design decisions were validated — see the README for why._

## Phase 1 — Auth & silent profile-building

- Supabase phone auth (SMS) is the *only* thing asked of a new user before
  they land on Welcome. No activities/availability/comfort form — that
  contradicts the "nobody initiates, nothing is asked of you" premise as much
  as an initiate button would.
- Everything Phase 0's old three-step intake used to collect is instead
  inferred or asked **one question at a time, in-context, after the fact**:
  - **Activities** — start from a broad, generous default set for the
    person's city; narrow based on which invitations they actually accept
    vs. decline over time.
  - **Availability** — inferred from which invitations they accept/decline
    and at what times, not asked upfront.
  - **Comfort** (group size, talk level, same-gender-only) — same-gender-only
    is the one thing worth a single explicit toggle (safety-relevant, can't
    be safely inferred); offer it unobtrusively from a settings surface the
    user finds on their own, never as a gate before Welcome. Talk level and
    group-size preference are inferred from reflections and repeat behavior.
- System still **writes the one-line blurb** shown to others — from inferred
  signal, not a form. No free-text bio, no photos required, no profile
  browsing anywhere in the app.
- Persist to `profiles`; routing gates only on "is phone-verified", never on
  "is onboarding complete" — that concept no longer exists.

## Phase 2 — The invite loop (against Supabase)

- Home = your invitations, read from `meetups` + your own `meetup_members` row.
- Invitation screen: what-to-expect, first-name attendees (via
  `confirmed_attendees` once confirmed), the exit permission slip.
- **Yes / Not-this-time** writes only your own RSVP. "No" is silent: the
  proposal simply "doesn't form", and RLS guarantees you never see who declined.
- Push notifications (`expo-notifications`): new proposal, day-before,
  morning-of confirmation tap.
- Morning-of: a no-confirm quietly shrinks/cancels the group and notifies
  everyone **before they leave home**. No-shows are the deadliest failure here.

## Phase 3 — Reflect & crystallize

- Post-meetup: "who would you be happy to see again?" writes `reflections`
  (built as UI). Never framed as rating.
- `mutual_connections` graph (built in SQL) feeds the composer.
- **Stage ladder** (friendship has stages, so the product does too):
  - _Mixing_ (meets 1–3): groups composed fresh, seeded by mutual yeses.
  - _Cohort_: when 3–4 form a mutual-yes clique, offer opt-in "make this
    regular, every other Saturday". One tap each → standing group, auto-scheduled.
  - _Graduation_: after ~8–10 meets, let them exchange numbers / export a chat.
    The app succeeding means getting out of the way — design for it proudly.

## Phase 4 — The composer

- Edge Function, run weekly by cron **and** on-demand from an admin view.
- Input: active profiles (availability ∩, ≥1 shared activity, city), the
  mutual-yes graph, blocks, reliability. Output: proposed `meetups` +
  `meetup_members`, at most one new person per existing cohort.
- **Concierge mode first:** you run the same function by hand from an admin
  screen for the first month or two — seeds cohorts, surfaces edge cases,
  validates the loop before automating.
- Internal **reliability score**: flakes matched with flakes, reliable people
  protected. Never shown, never shames.

## Phase 5 — Trust & safety

- Phone verification behind the scenes; display is first-name only.
- Same-gender-only grouping honored end to end.
- New configurations meet in **public venues only**.
- Silent **block-and-report** (`blocks`): guarantees the pair is never grouped
  again; nobody is notified.
- Loud, repeated framing: **this is for friendship.** Groups of 3–4 (not pairs)
  for new configs structurally defuse romantic ambiguity.

## Phase 6 — Closed beta

- One city (Osijek), **walks + board games only** — cheapest to organize, most
  silence-tolerant. Composer needs ~30–50 active users to form groups reliably.
- Recruit where the population already is: local subreddit/Discord, FERIT
  student groups, neurodivergent/introvert communities, bouldering-gym board.
- Pitch: _"An app where you never text anyone, organize anything, or meet more
  than three people at once."_

## Money (later, never at the start)

- Charge at **Stage 2** (the standing group) — the point the app has
  demonstrably delivered. A few € / month for "your group runs on autopilot".
- Never per-message, never boosts, never coupons — all import dating-app
  psychology this product explicitly rejects.
- Venue partnerships (board-game cafés, climbing gyms) for cheaper meetups on
  quiet weekdays: the incentive idea reborn as reduced friction, not a bribe.

## Deliberately NOT building

- No feed, no likes, no follower counts, no public profiles.
- No open-ended chat before a meeting. The meeting is the product.
- No "initiate a meetup" button. Ever.
