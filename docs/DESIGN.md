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
| Human, not a marketplace | first names only (no blurb, no photos, no profile browsing) |
| Never made to perform yourself | onboarding is one short *logistics* pass (when/where/how-many) — never a bio, personality, or anything another member reads |

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
Warmth runs in **two deliberate registers**, so the app can feel warm without
diluting the scarce accent (the evolution of the old "ember appears exactly
twice" rule):

- **Moss = the digital / system layer.** `#7FB077` (glow `#9FE08C`) — the living
  green that owns the app's UI: the primary button, system section labels, icon
  tints on dark glass, the star threads, the standing-group card.
- **Amber / ember = the tactile "paper & arrival" layer.** The warm world you're
  *arriving into*: the invite ticket (its amber activity tile + `paperEmber`
  section labels), the arrival pulse on Welcome, the single commitment button
  (`AppButton(celebrate: true)` — "Yes, I'll come"), and the warm star-trails.
  Ember is still not a generic accent — it belongs to the physical/arrival world
  only, never a stray UI highlight.
- **Paper** — the ticket world: warm cream stock (`paperInk` / `paperInkSoft`
  text, `paperEmber` accent, `paperLine` perforations) over a real paper
  texture. The tactile half of the design, set against the cool digital sky.
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
moss on dark system surfaces, `paperEmber` on the cream ticket.

## Components

A deliberately tiny kit ([`lib/widgets/`](../lib/widgets/)) so the whole app
reads as one calm system:

- **Screen** — the single page frame: safe-area aware, calm padding, a
  full-bleed photographic dusk-sky `backgroundAsset` with a painted-gradient
  fallback, an optional legibility `scrim`, an optional pinned footer for the
  one primary action, and an optional `ambient` [Starfield] overlay.
- **TicketCard** — the tactile half of the design: a physical paper ticket
  (real cream texture, soft drop shadow, scalloped stub edges via a
  `CustomClipper`, dashed `TicketPerforation` dividers). Carries the invite on
  its own detail screen and each fresh invite on Home; the standing-group card
  stays dark glass, so paper reads as "a genuinely new invitation".
- **AppCard** — glass content container (real blur, not a flat tint);
  `emphasis` adds a moss gradient wash + glow shadow.
- **AppButton** — `primary` (moss) / `secondary` / `ghost` / `danger`; 56pt
  min height. `celebrate: true` switches primary to the ember gradient —
  reserved for the single real commitment action.
- **AppText** — typographic variants + tones, the only way text is rendered.
- **ActivityIcon** — hand-drawn `CustomPainter` line icons per activity slug.
  No emoji anywhere in the app.
- **Starfield** — living-sky overlay: stars that twinkle at varying brightness,
  warm shooting-stars that leave a fading trail, and a few warmly connected
  threads — the literal metaphor for the product's thesis (isolated points,
  quietly linked). Reduced-motion aware. Replaces the old `ConstellationField`.
- **AnimatedHeadline** — per-character fade-and-rise reveal for arrival
  headlines (e.g. "A new invitation"); collapses to plain text under
  reduced-motion.

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
