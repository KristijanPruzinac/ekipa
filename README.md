# Ekipa

> ⚠️ **This README describes v2 and is superseded.** As of 2026-08-18 the product was
> redesigned from the ground up. The canonical specification is
> [`docs/v3/`](docs/v3/README.md) — start with [the Bible](docs/v3/00_BIBLE.md), then
> [open questions](docs/v3/09_OPEN_QUESTIONS.md). All code and migrations described below
> are flagged legacy: see [`docs/v3/LEGACY_AUDIT.md`](docs/v3/LEGACY_AUDIT.md). This file
> is rewritten at P0.

**Company, without the noise.**

An app for people whose need for connection is normal or high, but whose
tolerance for the local connection ritual — loud, alcohol-centered,
performance-heavy — is low. Autistic, demisexual, socially anxious, or simply
quiet people who find each other online but never locally, because the going-out
culture doesn't accommodate them.

Ekipa is not a discovery app. It's an organizer nobody has to be.

> You answer a few taps, receive fully-organized invitations to tiny
> low-pressure meetups, privately mark who you'd see again, and the system
> slowly crystallizes those mutual yeses into recurring friend groups that
> eventually don't need the app at all.

## Core principles (these are load-bearing, not vibes)

- **Nobody ever initiates.** The single hardest act for this group is proposing.
  So it doesn't exist. Your only actions are answering questions and tapping
  yes/no on proposals the system makes.
- **Groups of 2–4, never events.** Small enough that nobody lurks and nobody
  performs.
- **Activity-first, shoulder-to-shoulder.** Walking, board games, bouldering —
  parallel activities that remove the conversational spotlight. "Just talk" is
  intentionally absent.
- **A decline is invisible.** A proposal only forms once everyone accepts, and
  nobody ever learns who said no. Even then a first name is the only thing you
  learn about anyone — no blurb — and names appear just three hours before you
  meet (before that, only the group's shape: how many, what mix).
- **Reflection is a private feeling, not a rating.** After a meeting each person
  quietly answers "how did it feel?" at four levels (really enjoyed → rather
  not). Only mutual warmth seeds a future group; "rather not" is a silent,
  permanent exclusion. No one is ever told how anyone answered.
- **Repetition over novelty.** Friendship needs ~40–60 hours together, so the
  value engine is the recurring cohort, not the one-off.
- **Ambiguity is the tax this group can't afford.** Fixed durations, stated end
  times, explicit "what to expect", a normalized exit script.

See [docs/PLAN.md](docs/PLAN.md) for the full phased build,
[docs/GRAPH.md](docs/GRAPH.md) for the connection graph and the composer (the
actual matching mechanism — edge formation, weight, decay, the slot model),
[docs/DESIGN.md](docs/DESIGN.md) for the visual language, and
[docs/PRODUCT.md](docs/PRODUCT.md) for the founding strategy (who this is for,
why they're isolated, failure modes, cold start, monetization).

## Stack

- **Client** — Flutter (Dart), targeting Android (and web for quick iteration).
  iOS is deferred until a Mac is available in the dev environment; nothing in
  the design is iOS-specific.
- **Backend** — Supabase: Postgres, phone auth, Row-Level Security, Edge Functions.
- **The composer** — a scheduled Edge Function that builds groups from
  availability + shared activity + the mutual-yes graph. Runs by hand from an
  admin view during the concierge phase — same code path.

## Getting started

```bash
# 1. Install dependencies
flutter pub get

# 2. Configure the backend (optional — the app runs on mock data without it)
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Or, without a backend, just:
flutter run
```

Without `--dart-define` config, the app runs entirely on mock data
(`lib/data/mock_data.dart`), so the whole UI — welcome (arrival) → invitation
→ reflect — is explorable offline. There is no onboarding screen: the arrival
screen itself is the zero-onboarding promise, not a step before it.

Run `flutter doctor` first if this is a fresh machine — you'll need the
Android SDK (with `cmdline-tools` installed and licenses accepted via
`flutter doctor --android-licenses`).

## Project layout

```
lib/
  main.dart                 entry point: theme + router wiring
  router.dart                go_router routes for the vertical slice
  theme/                     colors, spacing/radius/motion tokens, type scale, ThemeData
  widgets/                   the small shared UI kit (Screen, AppCard, AppButton,
                              AppTag, AppText, PressableScale, Appear)
  models/                    domain types (Profile, Meetup, Attendee, enums)
  data/                      activity catalog, mock data, date formatting, Supabase client
  screens/
    welcome_screen.dart                 arrival — no onboarding, ready immediately
    home_screen.dart                    your invitations
    invite_detail_screen.dart           the yes / not-this-time invitation
    reflect_screen.dart                 "who would you be happy to see again?"
supabase/
  migrations/0001_init.sql  schema with the privacy model in RLS
docs/                       PLAN.md, GRAPH.md, DESIGN.md, PRODUCT.md
```

## Status

Design system, data model + RLS, and the full vertical slice (welcome → home
→ invite → reflect) are built. The Supabase-backed invite loop
(`lib/data/repository.dart`, the confirm/cancel trigger in
`supabase/migrations/0002_meetup_status_transitions.sql`) is wired in, with
a mock-data fallback when no backend is configured. A project is now live
(`ekipa_app_v1`, `eu-central-1`) with all four migrations applied, an
advisor security/performance pass done, and the RLS invariants + RSVP
trigger verified against real seeded data (not just reviewed) — invisible
declines, attendee identities staying hidden pre-confirmation, and a single
decline cancelling a proposal even with an existing yes already in, all
confirmed live. The app builds and boots against the real project and
correctly redirects an unauthenticated session to `/auth`.

**Not done: phone sign-in itself.** It needs an SMS provider (Twilio,
MessageBird, or Vonage) connected in the Supabase dashboard under
Authentication → Providers → Phone — no available tooling exposes that
config, so it's a manual step, deliberately deferred for now. Until it's
connected, `/auth` will accept a number but can't actually deliver a code.
After that: profile inference from behavior, push
notifications, the morning-of confirmation flow, then the composer. See
[docs/PLAN.md](docs/PLAN.md).
