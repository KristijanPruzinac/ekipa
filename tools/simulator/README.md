# `tools/simulator`

Twelve simulated weeks of a synthetic city, run through the **real** matchmaker.

```bash
cd tools/simulator
dart run bin/simulate.dart                      # the metric table
dart run bin/simulate.dart --help               # flags, and every config key
dart run bin/simulate.dart \
  --set matching.cooldown_meetups=1 --compare   # a config change, with a delta
dart run bin/simulate.dart --json               # for diffing two runs
```

## Why it exists before the app does

Every weight in [`docs/v3/03_MATCHMAKER.md`](../../docs/v3/03_MATCHMAKER.md) §3
is a guess, and every one of them is unverifiable until a friend graph exists —
roughly two months after launch. This was pulled forward from P4 to P0 because
it is the only way to test the most important algorithm in the product before it
runs on people.

It answers the six questions of §8 and nothing else. A metric with no decision
attached to it is a number, and a report full of numbers is a report nobody
reads.

**What it cannot tell us:** whether anybody enjoys the hangouts. Nothing
simulated can.

## What it is not allowed to contain

No matching rule, no composition rule, no eligibility rule. It calls
`Matchmaker` and `Composition` from `package:ekipa_core/matching.dart` — a
simulator carrying its own copy of the rules tells you about the copy. The one
thing it does own is the *behaviour of people*, which lives entirely in
[`lib/src/behaviour.dart`](lib/src/behaviour.dart): one struct, one default per
field, one sentence saying where each number came from. Those are assumptions
about people the product *observes*; they are not `MatchConfig` keys and must
never migrate there.

## Determinism

One seed reaches everything through forks named after what they decide
(`week:3` → `ratings` → `hangout-key:person`). Changing the rating model does
not reshuffle who turned up in week 2 — which is what makes a delta between two
configs a signal rather than noise. `--compare` runs the baseline on the same
seed, so both halves see the same founders and the same arrivals.

## What the first twelve weeks said

Run at the declared defaults, seed 1, 120 founders, six arrivals a week:

| metric | value |
| --- | --- |
| match rate | 65–83%, rising with density |
| time to first hangout | p50 1w, p90 3w |
| never matched | 8.1% |
| said yes when asked | 82.9% |
| groups that collapsed | 42.1% |
| repeat saturation | 6.7% |
| edges inside a triangle | 30.6% |
| hangout concentration | gini 0.350 |

Three findings, in order of how much they should change what gets built next.

**1. The configured ring mix is unrealisable in a young city.** 25/50/25
realises as 1.8 / 9.4 / 88.8. This is not a bug in the draw: an R1 or R2 draw
that finds nobody falls back outward, and for the first two months there is
almost nobody to find. It is the exact reason `ring_intended` and
`ring_realised` are both stored and the console shows them side by side. A
launch ratio tuned on paper would have been wrong, and nothing in the product
would have said so.

**2. Groups collapse on the composition rule, not on no-shows.** 82.9% of
placed people say yes, and 42% of groups still fail to run — 97 of them on
`loneGender`, 44 on `tooSmall`, 4 on `tooFamiliar`. A 2+2 that loses one member
is 1+2, and the honest response is to cancel. **This is a measurement of a
feature that does not exist yet:** backfill (P2) is what turns most of those 97
into hangouts, and the number says how much of the product is currently sitting
behind it.

**3. A shorter cooldown reduces clique formation.** Dropping
`matching.cooldown_meetups` from 2 to 1 moves never-matched 8.1% → 6.5%,
newcomer p50 to zero weeks, repeat saturation 6.7% → 8.8%, and edges inside a
triangle 30.6% → **16.8%**. The last one runs against intuition — letting people
repeat sooner produces *fewer* closed triads — because more hangouts held (173 →
182) spreads the same warmth across more distinct pairs. Recorded, not acted on:
one seed is an observation, and the cooldown is also a product promise about not
seeing the same face every week.

Reproduce any of these with `--seed=1`; the seed and the snapshot hash are what
make a surprising table re-runnable rather than an anecdote.

## Absent on purpose

**Sanction rate.** §8 asks for it. The trust ladder in
[`docs/v3/04_TRUST.md`](../../docs/v3/04_TRUST.md) is not implemented, and
approximating it here would be a second copy of a rule that must have exactly
one. The report says so in its own output rather than leaving a silent gap.

**Backfill.** Not implemented either, which is why finding 2 reads as a
cancellation rate rather than as a backfill rate.

## Tests

`dart test` — 63 of them. The statistics have known-value tests (a triangle
closes three edges; four people where one holds everything is gini 0.75), the
loop has determinism and rule-obedience tests, and the population model has
tests that each knob actually bites: an always-available city matches most of
itself, a city that enjoys nobody forms no edges, and a city where every
negative answer is permanent strangles itself.
