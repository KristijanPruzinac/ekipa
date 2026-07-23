# Ekipa — design language

The brand is the opposite of a nightclub. The trait that excludes our users from
club culture — a preference for quiet — becomes the product's proud identity.
Every surface should feel the way we want the meetups to feel: **quiet, natural,
warm, unhurried, unambiguous.**

## Feeling → decisions

| We want it to feel… | So the UI… |
| --- | --- |
| Calm, not stimulating | warm paper backgrounds, deep forest ink, one accent used sparingly |
| Unhurried | generous spacing, large soft shapes, one primary action per screen |
| Unambiguous (the core anxiety) | fixed durations, stated end times, explicit "what to expect", exit permission slip |
| Safe to say no | "not this time" is always present, always private, never punished |
| Human, not a marketplace | first names only, no photos required, no profile browsing |

## Color

Defined in [`src/theme/tokens.ts`](../src/theme/tokens.ts), light + dark.

- **Paper** neutrals — warm, off-white backgrounds (deep forest at night).
- **Ink** — deep natural greens/charcoals for text.
- **Moss** `#4A6B4D` — the living-green brand. Used for emphasis and the one
  primary action.
- **Clay** `#C97B5A` — soft terracotta accent. Used sparingly.
- Signal colors are muted to sit inside the palette, never alarm.

## Type

A humanist scale (`type` in tokens): `display` / `title` / `heading` / `body` /
`callout` / `label` / `caption`. Negative letter-spacing on large sizes, roomy
line-heights on body copy. Labels are the only uppercase, used as quiet
section markers.

## Components

A deliberately tiny kit so the whole app reads as one calm system:

- **Screen** — the single page frame: safe-area aware, calm padding, an optional
  pinned footer for the one primary action.
- **Card** — content container; `emphasis` gives the soft green wash for the
  "this is your invitation" hero.
- **Button** — `primary` (moss) / `secondary` / `ghost` / `danger`; 56pt min
  height so every tap target is easy and unhurried.
- **Tag** — selectable chip for tap-only onboarding.
- **Text** — typographic variants + tones, the only way text is rendered.

## Motion

Gentle. Screen transitions fade. No bounce, no confetti, no gamified
celebration — rewards here are real meetings, not dopamine loops.

## Voice

Plain, warm, second person. Short sentences. Never hype, never FOMO, never
"You have 3 new matches!". Compare:

- ✅ "A relaxed 90-minute walk with three other people. You can head off whenever
  you like; nobody will ask why."
- ❌ "🔥 New group alert! Don't miss out — RSVP now!"
