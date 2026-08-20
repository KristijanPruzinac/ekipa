# 08 — Roadmap

Phases are ordered by **risk retired per week**, not by what is pleasant to build. Each
has an explicit exit criterion; a phase is not done because the code exists, it is done
when its criterion is demonstrated.

The single sequencing principle: **the matchmaker is the most interesting component and
the least urgent one.** Its value is zero until people reliably arrive at hangouts, and a
sophisticated matcher over an empty graph is indistinguishable from random. Build the
loop, then the intelligence.

---

## P0 — Foundation (no product yet)

| Work | Why now |
| --- | --- |
| Quarantine v1/v2 code into `legacy/`, archive v2 docs into `docs/legacy/` | Directive D1. Nothing must be able to import it by accident. |
| Monorepo: `apps/mobile`, `packages/ekipa_core`, `packages/ekipa_data`, `packages/ekipa_ui`, `services/mill`, `tools/simulator` | The shared-core property is structural; retrofitting it later never happens. |
| CI: analyse, format, test, **dependency lint** (core imports no Flutter/IO), coverage floor on `ekipa_core` | The dependency rule is only real if a machine enforces it. |
| `Clock`, `RandomSource`, `ConfigSnapshot`, `Result` types + fakes | Every later component depends on these; retrofitting a clock is a rewrite. |
| Fresh Supabase project (free tier) + `0001_v3_core.sql` | v2 schema is superseded; a fresh schema is cheaper than eight reconciling migrations. |
| `tools/simulator` skeleton — synthetic population, real matchmaker, metric table | **Pulled forward from P4.** Every ring ratio is unverifiable until the graph exists, which is roughly two months after launch. The simulator is the only way to test the most important algorithm in the app before it runs on people. |
| pgTAP harness with the seven privacy invariants failing-then-passing | Privacy tests written before features cannot be skipped "for now". |
| Security gates: RLS-by-default migration lint, secret scanning, no-service-key-in-client rule, matching-library import boundary, §8 of [11_SECURITY.md](11_SECURITY.md) written into `CONTRIBUTING` | D9/D13. A security rule with no CI check is a wish. |
| Console v0: versioned config editor + city/slot schedule ([12_CONSOLE.md §6](12_CONSOLE.md)) | Nothing downstream is tunable without it, and D5 is unimplementable. |
| **Design system agreed by preview *before* any Flutter code** — direction, then tokens (colour, type scale, spacing, radius, motion), then 6 primitives in `ekipa_ui` | The v2 theme is scrapped in full (amendment 2026-08-18). Screens built on ad-hoc styling get restyled twice, and a direction argued in prose gets built wrong. Previews are HTML, reviewed and iterated, and only then translated to Dart tokens. |

**Exit:** `melos test` runs core + data + app + pgTAP green in CI; a dry-run matchmaker
over a fixture snapshot produces a deterministic plan and writes nothing.

---

## P1 — Identity, availability, the seat (the smallest real loop)

- `.edu.hr` email-code identity verification → `identity_hash`, first name, last initial
- Onboarding: name confirm, gender, anchor pin (+ optional location permission), travel
  radius, activity preferences, equipment
- Availability picker: this week's slots for the city, 90-minute blocks, 3 start times,
  2–3 configured weekdays; repeat-last-week shortcut
- Session state machine + route guards; suspended/banned states rendered honestly
- Master console v0: config editor (versioned), city + slot schedule, people list

**Exit:** a real person signs up, verifies, sets availability for three slots, and the
database shows exactly the seven fields we promised to store — and nothing else.

---

## P2 — The hangout lifecycle end to end (still no intelligence)

- Matchmaker **v0**: hard constraints + `ALL_STRANGERS` + starvation anchor. No graph, no
  scoring beyond proximity. *This is the honest launch matcher.*
- Full lifecycle state machine + sweeper + durable deadlines
- Confirmation flow, backfill (one-at-a-time invite with expiry), 3-person fallback,
  cancellation before anyone leaves home
- Meeting-point ingestion for one city + console vetting; sigil allocation
- Reveal screen: map, walking time, sigil, names, rules screen
- Arrival taps + peer attestation + late/dip window
- Ratings with the anti-satisficing rules; edge formation; **the rating gate** — an
  unrated past hangout blocks *being matched again*, never app access
- Push (FCM/APNs) + Realtime updates
- **Delete `legacy/`.** If nothing has been needed from it by now, nothing will be.

**Exit:** ten real hangouts run end to end in one city, with ≥80% rating completion and
zero incidents of a group arriving to find nobody there. This is the number that decides
whether the product works at all; everything after it is optimisation.

---

## P3 — Trust

- Infraction emission from every lifecycle transition; decaying accumulator; tiers
- Sanction ladder + notifications with reasons + appeal queue in the console
- Reports: categories, independence weighting, corroboration, the R0–R5 ladder. **No
  review queue** (D10) — calibration sampling + appeals only

**Exit:** a simulated 5%-flake population produces a sanction rate inside the configured
band; every sanction in staging is explainable from its event log by someone who was not
present.

---

## P4 — Intelligence

- Edges, exclusions, decay; the **ring draw** (R1/R2/R3) with the configured ratio,
  deficit correction, and `ring_intended` / `ring_realised` recorded per member
- Permanent control arm — a fraction of runs at `A = B = 0`, which needs no separate code
- Ratio tuning against the simulator; configured-vs-realised panel in the console
- Slot-quality indicator behind the availability picker (H3 demand, coarse buckets)

**Exit:** edge yield of template-composed groups beats the control arm by a margin that
survives the sample size — **or** the scoring is deleted and the constraint solver stands
alone. Both are acceptable outcomes; not measuring is not.

---

## P5 — Second city

- City onboarding as a data operation: timezone, weekdays, venue ingest, vetting pass
- Per-city config scoping proven in production
- No code changes required. If any are, P5 has found a hard-coded assumption, which is
  the point of doing it early.

**Exit:** a second city runs a week of hangouts with no deploy.

---

## P6 — Dating

- Consent + unlock + separate top-level tab
- Compatibility constraint, dating rounds, frequency budgets
- Post-hangout mutual interest + contact exchange
- Tightened safety profile

**Exit:** dating hangouts show no elevation in report rate versus friend hangouts over a
meaningful sample. If they do, the flag goes off and the design is revisited — that
possibility is the reason it ships last.

---

## Store readiness (runs alongside P2–P3, not at the end)

**The pilot does not go through a store.** With no entity (Q-ENTITY), an individual Play
account would publish a home address on the listing, so pilot builds are distributed via
**Firebase App Distribution** — free, no developer account, testers install from a link.
The Play listing waits for the entity, and is opened in the entity's name the first time.

That defers the fee, not the requirements. Everything below is still built during P2–P3,
because each is expensive to retrofit and a store review is not the reason to do any of it:

- **Account deletion in-app** (Apple requires it; Google requires a web path too) — and
  our deletion must retain the identity hash for ban enforcement, which needs to be
  disclosed in the privacy policy, not discovered by a reviewer.
- **Privacy manifests / data-safety declarations** matching what we actually store
  (location, contact info, identifiers, sensitive data if dating ships).
- **User-generated content / social-app requirements**: report + block flows, moderation
  contact, a stated policy. We have these by design; they must be *findable* in the app.
- **Sensitive-data justification** for orientation (dating) and location permission
  purpose strings.
- **Age rating** consistent with the age decision ([09_OPEN_QUESTIONS.md](09_OPEN_QUESTIONS.md) Q-AGE).
- **iOS is deferred (decision 2026-08-18): Android first.** The mitigation for
  "Android-only assumptions get baked in silently" is structural, not scheduling — no
  platform channel, no Android-only plugin, and no `Platform.isAndroid` branch outside
  `apps/mobile/lib/platform/`, checked by the dependency lint. Revisit when a Mac or a
  hosted macOS runner exists ([09_OPEN_QUESTIONS.md](09_OPEN_QUESTIONS.md) C-3).

---

## What we deliberately do not build

| Not building | Why |
| --- | --- |
| Chat / messaging | The meeting is the product; a chat becomes the product and then becomes the moderation burden. |
| Profiles, photos, bios | Pre-judgement is the failure mode we exist to remove, and photos are the single largest moderation surface. |
| Public events, open groups | Big groups of strangers are the worst format for this population. |
| A feed | There is nothing to scroll. If there is, we built the wrong thing. |
| Web app for users | Push notifications and the arrival flow are mobile-shaped. The console is the only web surface. |
