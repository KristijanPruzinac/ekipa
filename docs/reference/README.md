# UI reference set

Eight side-by-side reference screenshots from the founding session (2026-08-18), split
into **40 individual frames**, grouped by app and by set. Source images:
`~/Pictures/Screenshots/Snimka zaslona 2026-08-18 0051*.png` — matched to the attachments
by exact pixel dimensions. Splitter: [`tools/reference/split_refs.py`](../../tools/reference/split_refs.py)
(gutter detection on flat background columns; 327 px frames, no manual cropping).

Two sets per app:

- **`highlight/`** — a mixed set: splash, a couple of core screens, and the Mobbin
  "flows index" card in position 5 (not a product screen; kept for completeness).
- **`onboarding/`** — the app's actual first-run sequence, left to right.

---

## The set

### Opal — `opal/`
Dark, cinematic, one object in the void. The onboarding is a **narrative**: one line of
copy, one image, `TAP TO CONTINUE`, and the stone resolves from rough rock to fire over
three screens.

| highlight | onboarding |
| --- | --- |
| [01 splash mark](opal/highlight/01-splash-mark.png) | [01 splash mark](opal/onboarding/01-splash-mark.png) |
| [02 onboarding "Closer…"](opal/highlight/02-onboarding-closer.png) | [02 splash wordmark](opal/onboarding/02-splash-wordmark.png) |
| [03 home score](opal/highlight/03-home-score.png) | [03 "reveals its fire"](opal/onboarding/03-story-reveals-its-fire.png) |
| [04 today score detail](opal/highlight/04-today-score-detail.png) | [04 "Closer…"](opal/onboarding/04-story-closer.png) |
| [05 flows index](opal/highlight/05-flows-index.png) | [05 "Dimmed by noise"](opal/onboarding/05-story-dimmed-by-noise.png) |

**Take:** the progressive-reveal onboarding, one sentence per screen; the confidence to
show almost nothing; metric pills under a hero object (`53 Sleep · 90 Focus · 100 Rest`)
as a layout for a hangout's facts (time · place · who).
**Leave:** the score gauge. We do not have a number to show a person about themselves,
and inventing one would turn standing into the status game [04_TRUST.md](../v3/04_TRUST.md) forbids.

### Posh — `posh/`
Near-black, oversized white display type over motion, ruthless auth minimalism.

| highlight | onboarding |
| --- | --- |
| [01 splash](posh/highlight/01-splash-black.png) | [01 splash wordmark](posh/onboarding/01-splash-wordmark.png) |
| [02 event edit](posh/highlight/02-event-edit.png) | [02 "find your secret rave"](posh/onboarding/02-hero-secret-rave.png) |
| [03 event overview](posh/highlight/03-event-overview.png) | [03 "find your yoga class"](posh/onboarding/03-hero-yoga-class.png) |
| [04 discover feed](posh/highlight/04-discover-city-feed.png) | [04 phone entry](posh/onboarding/04-phone-entry.png) |
| [05 flows index](posh/highlight/05-flows-index.png) | [05 email + captcha](posh/onboarding/05-email-entry-captcha.png) |

**Take:** the auth screens — one question per screen, one field, one button, an escape
hatch underneath (`Switch to email`). That is the exact shape of our identity step. Also
the stat pair layout in *event overview* (`RSVP 1 · Page visits 2`) for hangout facts.
**Leave:** the discover feed and the whole broadcast/event surface. We have no feed
([08_ROADMAP.md](../v3/08_ROADMAP.md)).

### Polarsteps — `polarsteps/`
Light, warm, map-forward, and the friendliest forms in the set.

| highlight | onboarding |
| --- | --- |
| [01 splash](polarsteps/highlight/01-splash-logo.png) | [01 splash](polarsteps/onboarding/01-splash-logo.png) |
| [02 profile](polarsteps/highlight/02-profile.png) | [02 "plan, track, relive"](polarsteps/onboarding/02-hero-plan-track-relive.png) |
| [03 trip create](polarsteps/highlight/03-trip-create.png) | [03 signup options](polarsteps/onboarding/03-signup-options.png) |
| [04 map plan/track](polarsteps/highlight/04-trip-map-plan.png) | [04 basics: first name](polarsteps/onboarding/04-basics-first-name.png) |
| [05 flows index](polarsteps/highlight/05-flows-index.png) | [05 basics: last name](polarsteps/onboarding/05-basics-last-name.png) |

**Take:** the **bottom sheet over a blurred map** — this is the template for the anchor
pin step and for the reveal screen (map + meeting point + sigil + walking time). Floating
labels, a clearly disabled-then-enabled primary button, and one heading per step
("Let's cover the basics") for our onboarding. The plan/track segmented control maps
cleanly onto our **Hangouts / Dating** top tabs.
**Leave:** the social layer (followers, activity feed).

### Places — `places/`
Warm ivory, serif display, photographic hero, editorial calm. The most *adult* of the
four.

| highlight | onboarding |
| --- | --- |
| [01 splash wordmark](places/highlight/01-splash-wordmark.png) | [01 splash wordmark](places/onboarding/01-splash-wordmark.png) |
| [02 phone entry over hero](places/highlight/02-phone-entry-hero.png) | [02 phone entry over hero](places/onboarding/02-phone-entry-hero.png) |
| [03 AI answer](places/highlight/03-ai-answer.png) | [03 keypad, empty](places/onboarding/03-phone-keypad-empty.png) |
| [04 place detail](places/highlight/04-place-detail.png) | [04 keypad, filled](places/onboarding/04-phone-keypad-filled.png) |
| [05 flows index](places/highlight/05-flows-index.png) | [05 verify code](places/onboarding/05-verify-code.png) |

**Take:** **`04 place detail` is the single most directly reusable frame in the set** —
photo carousel, serif name, one line of location, an open/closed dot, metadata chips, and
a floating action row. That is our meeting-point screen almost exactly: photo of the
standing spot, name, walking time, open/closed, chips (`step-free`, `outdoor`, `quiet`),
actions (`Directions`, `I've arrived`). Also the code-entry screen and the warm neutral
palette as a counterweight to pure black.
**Leave:** the AI assistant surface.

---

## Direction for `packages/ekipa_ui`

What the four have in common is the actual brief: **a splash that is a held moment, one
question per screen, type doing the work instead of chrome, and photography or a single
object carrying the atmosphere.** None of them shows a dense dashboard on first run, and
none of them asks two things at once.

Working direction, to be confirmed:

- **Dark base, warm accent.** Opal/Posh darkness for atmosphere and battery, Places'
  ivory-and-serif warmth for the human moments (names, the meeting point, the ratings).
  Two registers, used deliberately: *system voice* dark, *people* warm.
- **One decision per screen.** Availability, confirmation, arrival and ratings are all
  single-decision surfaces. The reference set is unanimous on this.
- **Motion as atmosphere, not spectacle** — the one thing worth keeping wholesale from
  the v1 kit (fade-through, pressable scale, staggered appear).
- **No numbers about people.** No scores, no streaks, no badges. Opal's gauge is
  excellent for sleep and would be poison here.

Screen-by-screen mapping lives with the P1/P2 UI work; this file is the source of the
visual argument.
