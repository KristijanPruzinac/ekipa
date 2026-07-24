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
- Push notifications (`expo-notifications`): new proposal, day-before,
  morning-of confirmation tap.
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

## Phase 3 — Reflect & crystallize

- Post-meetup: "how did it feel?" writes `reflections` at four levels — really
  enjoyed / enjoyed / no preference / rather not (built as UI). Never framed as
  rating.
- `mutual_connections` graph (both people ≥ enjoyed, neither excluded) feeds the
  composer; a "rather not" writes a silent, permanent `exclusions` row.
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
- Silent exclusions: an explicit **block-and-report** (`blocks`) and the implicit
  "rather not" reflection (`exclusions`) both guarantee the pair is never grouped
  again; nobody is notified either way.
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
