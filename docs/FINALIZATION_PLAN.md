# Ekipa — finalization plan (visual polish + motion + v2 completion)

> **STATUS (2026-07-26): decisions resolved, plan a working session record.**
> Product truth lives in `PRODUCT.md`, `PLAN.md`, `DESIGN.md`, `GRAPH.md`.
>
> - **§0.2 palette — resolved as recommended:** the two warmth registers
>   (moss = digital/system, amber/ember = paper & arrival) were adopted and
>   are documented in DESIGN.md as the rule. "Ember exactly twice" is retired.
> - **Reflect — resolved:** the four-level selector was built (the comp's
>   single heart was not copied); DESIGN.md now describes the built selector.
> - **Onboarding reversal — confirmed and built** (PLAN Phase 1).
> - **`rather_not` storage — resolved:** dedicated `exclusions` table
>   (consolidated into migration `0006`).
> - Open decision #4 (copying comps more literally) is closed unless
>   reopened explicitly.

Goal: a professional, polished, **fully functional** app that looks and moves
like the reference mockups — no static screens. This plan merges three tracks:

1. **Visual** — photographic dusk backgrounds, torn-paper tickets, textured
   cards, matching the references.
2. **Motion** — animated star trails, dynamic letter reveals, screen
   transitions, shared-element hero moves. "I hate static screens" is the bar.
3. **Function** — the v2 correctness/security work from `REBUILD_PLAN.md`
   folded in, so polish and correctness ship together, not separately.

It supersedes nothing in `REBUILD_PLAN.md`; it sequences that work alongside
the visual overhaul.

---

## 0. Reading the references honestly (must read before building)

The five mockups are gorgeous and set the target aesthetic. But they are
AI-rendered comps, and copying them literally would break things:

- **Typos everywhere** — "Weiting", "within o week", "hearby", "Sasturday",
  "vertification code", "Tep to see the plan", "won't effect future", "Lucja/
  Jana" vs "Lucija". The real app strings are already correct in code; I match
  the *look*, not the text.
- **They show v1 content we're removing.** The invite + reflect comps show
  **blurbs** ("Into photo walks and sci-fi…") under every name, and the invite
  shows **attendee names before the meeting**. v2 kills both (blurbs gone;
  names revealed only at T−3h). So: match the card *layout and warmth*, but the
  "who's coming" area shows group composition pre-reveal, not names+blurbs.
- **Palette drift toward amber.** The comps use warm amber/gold prominently —
  the auth button is orange, the invite accept is amber, the star trails are
  gold. That collides with our hard rule *"ember appears exactly twice."* See
  the decision below; I will not silently overwrite that rule again.

### Design decisions to lock (my recommendation in bold)

1. **Backgrounds: photographic vs. the hand-built vector world.** The comps
   replace the flat dusk ground + `ConstellationField` with real photographic
   skies. **Recommendation: adopt photographic backgrounds as the base layer,
   and keep the constellation/star animation as an overlay on top** — best of
   both: the reference's richness *plus* our living-thesis motion. The pure
   hand-vector look is retired as the base.
2. **Palette / ember scarcity.** The comps are warmer than "ember twice
   allows." **Recommendation: evolve the rule rather than break it silently —**
   define two warmth registers: **moss = the digital/system layer** (labels,
   standing-group card, secondary actions, the constellation threads) and
   **amber/ember = the tactile "paper & arrival" layer** (the invite ticket,
   the arrival pulse, the single "Yes, I'll come" commitment, and the warm
   star-trails on Welcome). Ember stops being "exactly twice" and becomes "the
   warm/physical world only, never a generic accent." The auth primary button
   becomes **moss** (keep it out of the warm layer) unless you want it amber.
   → **Needs your yes**, because it rewrites a rule you cared about. Everything
   else can proceed while this is open.
3. **`reflect` heart vs. 4-level.** v2 says four levels (really enjoyed /
   enjoyed / no preference / rather not). The comp shows a single heart toggle.
   **Recommendation: build the 4-level selector** (keep the warm glow of the
   highlighted row from the comp), because binary can't express "rather not"
   (the silent never-compose signal). Confirmed in `REBUILD_PLAN.md` A4.

---

## 1. Asset pipeline (Higgsfield → repo)

**Model:** `seedream_v5_lite` ("Seedream 5.0 Lite"), 1 credit/image, 9:16 for
backgrounds, 3:4 for paper. Balance at start: 55.33 credits.

**Generating now (background jobs, IDs tracked in session):**
- Welcome dusk sky over the Drava (`ac087536…`)
- Home deep-blue starfield (`6f45fa5e…`)
- Auth dawn-dusk gradient (`f6849ae9…`)
- Reflect single-bright-star sky (`2cb7ef00…`)
- Cream paper texture for tickets (`f8eb011a…`)

**Note:** the exact reference comps aren't stored in Higgsfield (they were
pasted, not uploaded — the recent Higgsfield uploads turned out to be current-
app screenshots + unrelated CAD renders), so these are generated from prompts
matched to the comps, not image-conditioned. If a result misses, I regenerate
that one (1 credit) with a tighter prompt or, if needed, upload a comp via
`media_import_url` to use as an `image_references` anchor.

**Pipeline:** poll `job_status` → download the chosen result → save under
`assets/backgrounds/` and `assets/textures/` → register in `pubspec.yaml`
`flutter: assets:` → load via `Image.asset` / `DecorationImage`. Downscale to
~1080-wide and compress (keep the app bundle lean). Each screen's `Screen`
frame gets an optional `backgroundAsset` slot; a painted-gradient fallback
stays for when an asset is missing or `--no-assets` demo.

**Which asset goes where:**
- Welcome → dusk-Drava sky, full-bleed, animation overlay on top.
- Home → deep-blue starfield, cards float over it (matches comp 2).
- Auth → dawn gradient (matches comp 3).
- Reflect → single-star sky (matches comp 4).
- Invite detail → starfield base + the **paper ticket** as the foreground card.

---

## 2. Motion system (the "no static screens" work)

New reusable widgets under `lib/widgets/motion/`:

**2.1 `Starfield` (replaces/absorbs `ConstellationField`).** Base = the photo
background. Overlay = a single-`Ticker` `CustomPainter`:
- **Twinkling stars:** N stars, each `opacity = base + amp*sin(t*speed+phase)`
  with staggered phase; a few large ones get a soft `MaskFilter.blur` glow.
  Varying brightness per your note.
- **Shooting stars / trails:** a spawner emits a shooting star every ~2.5–5 s:
  a bright head travels along a path leaving a **gradient trail (warm head →
  transparent tail)**; after it lands the whole streak **fades out over ~0.6 s**
  — exactly your "flying stars that leave trails that fade after a few seconds."
- **Persistent warm threads:** keep a few faint constellation lines (the
  "warmly connected dots" thesis) so the metaphor survives under the new look.
- Respects `MediaQuery.disableAnimations` (freeze twinkle, no shooting stars).

**2.2 `AnimatedHeadline` (dynamic letters).** Splits a string into characters
(or words); each unit `Interval`-staggered within one controller: opacity 0→1,
`translateY` +8→0, subtle blur→0, so letters "settle in." Used for "You're in."
and "A new invitation" (your dynamic-letters request). `perCharacter` and
`perWord` modes; runs once on mount, reduced-motion → instant.

**2.3 Screen transitions.** Replace default routes with `CustomTransitionPage`
in `go_router`: calm cross-fade + 2–3% scale/parallax, ~300–400 ms, eased.
**Shared-element hero:** the activity icon tile animates from the Home card
into the Invite-detail hero (Flutter `Hero`), so opening an invite feels
physical, not a cut.

**2.4 Micro-motion (keep + extend what exists).** `Appear` staggered entrances,
`PressableScale`, the reflect selection glow, commitment haptic. Add: the
arrival pulse already exists; make the Welcome "See my invitation" button a
soft breathing glow.

**2.5 `TicketCard`.** The invite detail becomes a torn-paper ticket: a
`CustomClipper` for the scalloped/notched ticket edge + perforation dashed
dividers + the generated paper texture as fill + a soft drop shadow, slightly
rotated like the comp. The Home "walking" card is a lighter paper variant; the
standing-group card stays dark glass (matches comp 2 exactly — warm paper for
the fresh invite, cool glass for the standing group).

---

## 3. Functional completion (folded in from REBUILD_PLAN.md)

Polish is worthless on broken flows, so these ship in the same pass:

**3.1 Security (do first, independent):** revoke `mutual_connections` from
`authenticated` (verified live hole). Migration `0005`.

**3.2 Flow/correctness bugs:**
- accept → return to Home "you said yes" state (not Reflect).
- surface RSVP write failures (no silent phantom no-shows).
- Home renders **all** fresh invitations, not just the first.
- trigger race hardening (`for update`), post-confirmation cancel path.

**3.3 v2 content:**
- remove blurbs (DB + models + `confirmed_attendees` + screens).
- 4-level reflection (`sentiment` enum; `mutual_connections` = both ≥ enjoyed;
  `rather_not` → exclusions).
- 24h proposal expiry (`expires_at`).
- name reveal gated to T−3h; pre-reveal card shows group composition
  (needs gender collected).
- restore ~90-second logistics onboarding after OTP (first name, city, gender
  + same-gender-only, availability, group size) — **the one open product
  reversal**, see `REBUILD_PLAN.md` flag #2.
- drop the dead `emoji` column.

**3.4 Docs + memory** rewritten to v2 in the same pass (so future sessions
stop rebuilding v1), including the palette-rule evolution from §0.

Phases B/C from `REBUILD_PLAN.md` (morning-of flow, meeting-day recognition
screen, no-show ladder, admin/concierge panel, composer, standing groups, push,
SMS) remain the post-finalization roadmap — this plan gets the *existing*
surfaces to polished + correct, not the entire unbuilt back half.

---

## 4. Build order

1. **Phase 0** — security fix `0005` (minutes, independent).
2. **Assets in** — collect the 5 generations, save, wire `pubspec`, add
   `backgroundAsset` to `Screen`. Screens immediately look like the comps.
3. **Motion core** — `Starfield` (twinkle + shooting stars) on Welcome;
   `AnimatedHeadline` on Welcome + Home; screen transitions + the Home→Invite
   hero. This is the bulk of "no static screens."
4. **TicketCard** — invite detail + Home fresh-invite as paper; standing group
   stays glass.
5. **Functional v2** — 3.2 bugs, then 3.3 content (blurbs out, 4-level reflect,
   expiry, T−3h reveal, onboarding), each with `flutter analyze`+`test` and a
   live RLS re-check.
6. **Palette reconciliation** — apply the §0.2 decision once you confirm it.
7. **Docs/memory to v2.**
8. **Verify** — build web against the live project, screenshot every screen,
   iterate against the comps until they match; then a device/emulator pass for
   the motion (screenshots can't show animation).

## 5. Open decisions (blocking only where noted)

1. **Palette / ember rule evolution** (§0.2) — blocks only the final palette
   pass (step 6); everything else proceeds.
2. **Onboarding reversal** (§3.3) — blocks the onboarding screens only.
3. **`rather_not` storage** — `blocks` vs. new `exclusions` table (I recommend
   the latter).
4. Anything from the comps you want copied *more* literally than I've proposed
   (e.g. if you actually want the amber auth button, say so).

## 6. Credits

Started 55.33; ~5–6 spent on the first asset batch (1 credit each).
Regenerations are 1 credit each. I'll keep total image spend modest and report
before any large batch.
