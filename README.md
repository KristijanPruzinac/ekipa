# Ekipa

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
- **A decline is invisible.** A proposed meetup only becomes visible to its
  members once everyone has accepted. Nobody ever learns who said no.
- **"Would you see them again?" is mutual and private.** One-sided yeses and any
  no are never revealed to anyone. Mutual yeses become the graph that seeds
  future groups.
- **Repetition over novelty.** Friendship needs ~40–60 hours together, so the
  value engine is the recurring cohort, not the one-off.
- **Ambiguity is the tax this group can't afford.** Fixed durations, stated end
  times, explicit "what to expect", a normalized exit script.

See [docs/PLAN.md](docs/PLAN.md) for the full phased build and
[docs/DESIGN.md](docs/DESIGN.md) for the visual language.

## Stack

- **Client** — Expo (React Native) + `expo-router`, TypeScript.
- **Backend** — Supabase: Postgres, phone auth, Row-Level Security, Edge Functions.
- **The composer** — a scheduled Edge Function that builds groups from
  availability + shared activity + the mutual-yes graph. Runs by hand from an
  admin view during the concierge phase — same code path.

## Getting started

```bash
# 1. Install deps and reconcile versions to your installed Expo CLI
npm install
npx expo install --fix

# 2. Configure the backend (optional — the app runs on mock data without it)
cp .env.example .env
#   then paste your Supabase URL + anon key

# 3. Run
npx expo start
```

Without a `.env`, the app runs entirely on mock data (`src/lib/mock.ts`), so the
whole UI — welcome → onboarding → invitation → reflect — is explorable offline.

## Project layout

```
app/                      expo-router screens (the vertical slice)
  index.tsx               welcome
  onboarding/activities   tap-only intake (step 1 of 3)
  home.tsx                your invitations
  invite/[id].tsx         the yes / not-this-time invitation
  reflect/[id].tsx        "who would you be happy to see again?"
src/
  components/             the small shared UI kit (Screen, Card, Button, Tag, Text)
  theme/                  design tokens + light/dark resolution
  lib/                    supabase client, domain types, activity catalog, mock data
supabase/
  migrations/0001_init.sql  schema with the privacy model in RLS
docs/                     PLAN.md, DESIGN.md
```

## Status

Foundation scaffold: design system, data model + RLS, and a working vertical
slice on mock data. Next: real auth + onboarding persistence, then the invite
loop against Supabase, then the composer. See [docs/PLAN.md](docs/PLAN.md).
