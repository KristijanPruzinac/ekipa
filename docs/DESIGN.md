# Ekipa — design language

The brand is the opposite of a nightclub. The trait that excludes our users from
club culture — a preference for quiet — becomes the product's proud identity.
Every surface should feel the way we want the meetups to feel: **quiet, natural,
warm, unhurried, unambiguous.**

Codename for the current visual direction: **dusk** — warmth found in the dark.

## Feeling → decisions

| We want it to feel… | So the UI… |
| --- | --- |
| Calm, not stimulating | near-black forest-floor ground, one accent used sparingly |
| Unhurried | generous spacing, large soft shapes, one primary action per screen |
| Unambiguous (the core anxiety) | fixed durations, stated end times, explicit "what to expect", exit permission slip |
| Safe to say no | "not this time" is always present, always private, never punished |
| Human, not a marketplace | first names only, no photos required, no profile browsing |
| Ready before you ask | zero onboarding screens — no chip-pickers, no upfront questions; the Welcome screen *is* the promise that nothing is asked of you |

## Color

Defined in [`lib/theme/colors.dart`](../lib/theme/colors.dart) as an
`EkipaColors` `ThemeExtension`, resolved via `context.colors`. There is
deliberately **one theme, not light + dark** — `EkipaColors.dusk`. The whole
visual thesis is warmth found in the dark; a light inversion would undermine
it, so no light variant exists.

- **Ground** — near-black forest-floor background (`bg`, `bgGradientTop/Bottom`).
- **Glass** — translucent card fill (`glass` / `glassStrong`) with real
  `BackdropFilter` blur, hairline borders (`line` / `lineSoft`).
- **Ink** — warm off-white text (`ink` / `inkSoft` / `inkFaint`).
- **Moss** `#7FB077` (glow `#9FE08C`) — the living green that owns the app:
  the primary button, section labels, icon tint, the one ambient background
  glow present on every screen.
- **Ember** `#E8AC5D` — the one warm accent, and it is genuinely scarce: it
  appears in exactly two moments — the arrival pulse on Welcome, and the
  commitment button (`AppButton(celebrate: true)`, used only for "Yes, I'll
  come"). It must never be used as a generic accent, label color, or ambient
  wash — that scarcity is what makes it read as intentional. See the doc
  comment on `EkipaColors.ember` for the rule.
- **Danger** — muted, sits inside the palette, never alarm.

## Type

**Fraunces** — a soft, natural optical serif — carries the display moment
("You're in.") and titles for editorial warmth; **Inter** carries everything
functional (headings, body, labels). Both load via `google_fonts` in
[`lib/theme/text_styles.dart`](../lib/theme/text_styles.dart), which caches
them locally after first load.

The scale (`EkipaTextVariant`): `display` / `title` / `thesis` (Fraunces,
`thesis` italic for editorial pull-quotes like "We'll come to you.") then
`heading` / `body` / `bodyStrong` / `callout` / `calloutStrong` / `label` /
`caption` (Inter). Negative letter-spacing on large sizes, roomy line-heights
on body copy. Labels are the only uppercase, used as quiet section markers —
in moss, never ember.

## Components

A deliberately tiny kit ([`lib/widgets/`](../lib/widgets/)) so the whole app
reads as one calm system:

- **Screen** — the single page frame: safe-area aware, calm padding, a faint
  moss ambient glow on every screen, an optional pinned footer for the one
  primary action, and an optional `ambient` constellation field for the
  screen where atmosphere should be the star (Welcome).
- **AppCard** — glass content container (real blur, not a flat tint);
  `emphasis` adds a moss gradient wash + glow shadow for the "this is your
  invitation" hero.
- **AppButton** — `primary` (moss) / `secondary` / `ghost` / `danger`; 56pt
  min height. `celebrate: true` switches primary to the ember gradient —
  reserved for the single real commitment action.
- **AppText** — typographic variants + tones, the only way text is rendered.
- **ActivityIcon** — hand-drawn `CustomPainter` line icons per activity slug.
  No emoji anywhere in the app.
- **ConstellationField** — ambient canvas animation of quiet, mostly-isolated
  dots with a few warmly connected — the literal visual metaphor for the
  product's thesis (coordination failure, solved). Used on Welcome only.

## Motion & touch

Gentle and physical, never loud. Interactivity here is tactile feedback, not
gamification — the reward is a real meeting, not a dopamine loop.

- **Press** — every tappable thing springs down slightly and back
  ([`PressableScale`](../lib/widgets/pressable_scale.dart)), the one touch
  primitive. Motion values live in `EkipaMotion` (tokens): ~0.97 press scale,
  gentle durations, eased curves.
- **Entrance** — content fades and rises a few px on mount
  ([`Appear`](../lib/widgets/appear.dart)), staggered so a screen exhales into
  place rather than snapping.
- **Haptics** (`flutter/services.dart`'s `HapticFeedback`, used directly in the
  widgets) — a light tick on press, a selection tick on filling a heart, and a
  single medium-impact note reserved for real commitments ("Yes, I'll come").
  Sparing by design.
- **The heart** on the reflect screen ([`reflect_screen.dart`](../lib/screens/reflect_screen.dart))
  pops with a spring as it fills — the one small moment of delight, and it's
  about a person, not a score. It stays moss, not ember, on purpose.
- **The arrival pulse** on Welcome ([`welcome_screen.dart`](../lib/screens/welcome_screen.dart))
  is the other ember moment — a slow breathing dot standing in for "we're
  working on it, quietly."
- Screen transitions are the platform default. No bounce, no confetti, no
  streaks, no red dots.

## Voice

Plain, warm, second person. Short sentences. Never hype, never FOMO, never
"You have 3 new matches!". Compare:

- ✅ "A relaxed 90-minute walk with three other people. You can head off whenever
  you like; nobody will ask why."
- ❌ "🔥 New group alert! Don't miss out — RSVP now!"
