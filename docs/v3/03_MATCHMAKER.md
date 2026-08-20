# 03 — The matchmaker

The one component nobody can verify by looking at the screen. Everything here exists to
make it **pure, deterministic, measurable and tunable before it has users**.

Lives in `packages/ekipa_core/lib/matching/`. No IO, no clock, no randomness except
through injected ports.

---

## 1. Signature

```dart
MatchPlan run(MatchSnapshot snapshot, MatchConfig config, Seed seed);
```

`MatchSnapshot` is an immutable in-memory view: people, availability, edges, exclusions,
standing, venues, recent-hangout history. `MatchPlan` is a list of proposed hangouts,
each carrying its template, per-member slot role, and the score components that produced
it.

**Intention:** the function is a value-in/value-out transform, so it can run in the
worker, in a test, in the simulator over a synthetic city, and in the console as a
dry-run against live data. That is directive **D3** made literal. It also means the
scariest code in the system has the cheapest possible test loop.

---

## 2. Pipeline

```
 snapshot
    │
 ① partition        → independent sub-problems: one per (city, slot)
    │
 ② eligibility      → per-person hard filters, then per-pair hard filters
    │
 ③ candidate graph  → nodes = eligible people, edges = pairs that MAY sit together,
    │                  annotated with affinity components
 ④ seed selection   → who each group is built around (standing-gated, weighted)
    │
 ⑤ ring draw        → the seed's partner drawn from R1 / R2 / strangers, by ratio
    │
 ⑥ completion       → second dyad by the same draw; leftovers placed; no hill climbing
    │
 ⑦ validation       → whole-group invariants; reject-and-rebuild, never patch
    │
 ⑧ emission         → MatchPlan + explanations + run statistics
```

Each stage is a separate pure function with its own tests. Intention: when the matcher
does something surprising, you can bisect *which stage* is wrong instead of reading one
500-line method.

### ① Partition — why per (city, slot)

Cross-slot optimisation ("this person would be better used on Thursday") is a real
opportunity and a real trap: it makes the problem global, non-decomposable and slow, and
it makes results incomprehensible. Instead we process slots in a **deterministic order
weighted by scarcity** (fewest available people first) and carry an "already placed this
run" set forward. Scarce slots get first pick of people; abundant slots can absorb the
remainder.

**Rejected — one global optimisation over the whole week:** better paper results, far
worse debuggability, and the marginal quality gain is dwarfed by "did the person show
up", which no optimiser controls.

### ② Eligibility — hard constraints (never scored, just excluded)

Per person:

- has availability for this slot; not already placed this run; not placed in an
  overlapping slot
- standing permits matching (no active suspension/ban; throttle quota not exhausted)
- has completed all required ratings for previous hangouts (the rating gate,
  [04_TRUST.md](04_TRUST.md))
- profile complete: verified identity, home anchor, gender

Per pair:

- no `exclusions` row in either direction (`rather_not`, block, report-driven)
- **cooldown**: the pair has not met within `cooldown_meetups` hangouts *or*
  `cooldown_days`, whichever comes first
- **share at least one reachable venue cluster** ([05_PLACES.md §4](05_PLACES.md)) — the
  geographic unit is the cluster, not raw pairwise distance, because the cluster is what a
  meeting point will eventually be chosen from

Per group (checked at ⑦, not per insertion):

- **no person is the only one of their gender** (invariant 1, §⑥) — this is the whole
  composition rule, at every group size
- if dating round: every member has ≥ `min_dating_candidates` compatible others
- at most `max_known_pairs` pairs that have met before (default: half)
- a shared reachable cluster exists for all members (see [05_PLACES.md](05_PLACES.md))

**Why hard constraints are a `Specification` composition rather than an `if` chain:**
each rule is separately testable, the failing rule is nameable in diagnostics ("nobody
eligible: 12 filtered by cooldown, 3 by standing"), and adding a rule cannot silently
reorder existing ones.

### ③ Candidate graph and the affinity components

For each eligible pair we compute components, each normalised to `[0,1]`, then combine:

| Component | Definition | Intention |
| --- | --- | --- |
| `friend` | decayed weight of a direct edge: `w · 0.5^(days_since/H)` | Repetition is how acquaintances become friends. Half-life `H` default 120d. |
| `bridge` | best two-hop path: `min(w₁,w₂) · bridge_discount` | The graph's one genuinely non-obvious move: propose someone you have no evidence about, on evidence from someone you liked. |
| `proximity` | over the group's best shared cluster: `1 − clamp(worst_member_travel / max_travel)` | The transcript's distance signal, expressed on clusters. Uses the **worst** member's travel, because that is the person who does not come. |
| `activity` | overlap of activity preferences and equipment | A cards hangout with nobody carrying cards is a failure the matcher can prevent. |
| `freshness` | penalty if the pair met recently but is past cooldown | Keeps a good pair from monopolising each other. |
| `respect_fit` | both sides above the respect floor (with a Bayesian prior, §6) | Keeps hangouts civil without letting a noisy 3-rating sample condemn anyone. |

```
affinity(a,b) = w_f·friend + w_b·bridge + w_p·proximity + w_a·activity
                − w_r·freshness_penalty
```

All `w_*` are config (D5) and their defaults come out of the simulator (§8), not out of
intuition.

**There is no group score, and there is no search over candidate groups.** An earlier
draft of this document proposed one (`α·mean + (1−α)·min` over the six pairs) and it was
wrong for this product: composition here is **generated**, not optimised. Affinity survives
only to answer a narrower question — *given that we have decided to draw from ring R, which
member of R?* — and as a tie-break. The shape of the group is decided by §④–⑥.

The **worst-member principle** that motivated the `min` term survives where it is genuinely
about one person's experience rather than a group's aggregate: the `proximity` component
above, and venue choice at lock ([05_PLACES.md §5](05_PLACES.md)). The person with the
forty-minute walk is still the person who does not come.

### ④ Seed selection — and why "most starved" is a trap

The seed decides the group's shape, because the draw in ⑤ runs over **the seed's** rings.
So seed choice is a policy decision, not an implementation detail.

**The trap, caught in review and worth stating in full:** our conduct sanction at R2 is a
*throttle* — we reduce how often someone is matched ([04_TRUST.md §5](04_TRUST.md)). A
throttled person is therefore, by construction, among the longest-waiting people in the
city. A naive "seed on whoever has waited longest" rule would hand them the first group of
every run and first pick of everyone's evening. The sanction inverts into a privilege, and
it does so **silently** — the throttle still looks correct in the logs (fewer hangouts
permitted) while each permitted hangout is the best one available.

**The rule: starvation credit accrues only in good standing.**

```
seed_pool = eligible(slot) ∧ standing == GOOD          -- throttled / watched excluded
weight(p) = (1 + starve_gain · min(weeks_waiting(p), starve_cap))
          · (newcomer_multiplier if completed_hangouts == 0 else 1)
seed      = weighted_sample_without_replacement(seed_pool, weight, rng(seed))
```

Defaults: `starve_gain = 1.0`, `starve_cap = 4` weeks, `newcomer_multiplier = 3`. All config.

Four properties, each deliberate:

1. **Newcomers still dominate.** They are the biggest churn risk and they are clean by
   definition, so the sanction gate costs them nothing.
2. **Waiting under sanction buys nothing.** A throttle is a *reduction*, not a *delay*.
   This is the whole point of the fix.
3. **Weighted sampling, not a sorted queue.** A deterministic order makes composition
   predictable from outside the system, and a predictable matcher is a gameable one; it
   also removes the need to invent tie-breaks.
4. **The starvation credit is capped.** Uncapped, someone who is unmatchable for a
   *structural* reason — no reachable cluster, a gender-ratio dead end — accrues unbounded
   priority, permanently outranks everyone, and still never gets matched. The cap keeps
   that person visible on the console's unmatched report instead of buried inside a weight.

**Throttled people are excluded from seeding, not from hangouts.** They may fill a seat
when their frequency quota allows, and per §6 are preferentially placed with others in the
same band. The sanction reads, honestly: *fewer evenings, and never the evening built
around you.*

**Rejected — seeding on the best-connected person:** serves the happiest users and starves
the rest. The classic recommender death spiral, arriving here as "the app never matched me."
**Rejected — strict longest-waiting-first:** the trap above, plus property 3.

### ⑤ The ring draw — the core algorithm

Every person has three rings over the mutual-edge graph:

| Ring | Definition | What it is for |
| --- | --- | --- |
| **R1 · enjoyed** | direct mutual edge | See people you liked again. Repeated exposure is the only known mechanism by which acquaintances become friends. |
| **R2 · leaves** | the R1 sets of my R1 people, minus my own R1 and me | **The operating principle.** You discover your friends' friends — which is how a social circle actually grows, and the one move no dating-style app makes. |
| **R3 · strangers** | everyone else eligible | New people enter the network and separate components merge. Without this the graph closes. |

**The draw**, once per dyad:

```
roll ~ U(0,1) from the run seed
  roll < A          → partner drawn from R1
  A ≤ roll < A + B  → partner drawn from R2
  otherwise         → partner drawn from R3   (this dyad has no prior connection)
```

`A` and `B` are per-city versioned config and are experiment-targetable
([12_CONSOLE.md §4](12_CONSOLE.md)). `C = 1 − A − B` is never configured directly, so the
three can never fail to sum.

**Within the drawn ring the partner is *sampled*, weighted** by edge strength × recency
decay × proximity — never `argmax`. Determinism here would violate invariant 3 below.

**Fallback goes down, never up.** If the drawn ring has no member passing the hard
constraints: R1 → R2 → R3. A stranger draw never silently becomes a friend draw, because
that is the direction that builds closed cliques; falling the other way costs one person
one evening of familiarity and increases exposure, which is the failure we can afford.

**Deficit correction within a run — the part that is easy to omit and expensive to omit.**
The per-dyad roll is unbiased, but the *fallbacks* are not: they are systematically biased
toward R3 exactly when the graph is thin. Left alone, a configured `0.25 / 0.50 / 0.25`
can realise as `0.05 / 0.15 / 0.80` with nothing anywhere saying so. Therefore:

- every hangout member row records **`ring_intended`** and **`ring_realised`**;
- later rolls in the same run are biased toward whichever ring is running a deficit, up to
  what the graph can actually supply;
- the console shows **configured next to realised**, per run and per city.

**Intention: the number you tune must be the number that happened.** A ratio you cannot
verify is a comment, not a control.

**R2 excludes the intermediary.** If A is the seed and C is drawn from R2 by way of B, then
B is not placed in that group. A group of A, B and C has three known pairs of six and one
outsider — the worst possible shape, where a trio talks and the fourth person watches.
*Rejected — including the intermediary ("the warm introduction"):* it is how introductions
work in real life and may well be better, but it is a different product shape. It is a
named future variant to be measured against this one, not assumed into it.

**R1 requires a mutual edge**, per canon ([02_DOMAIN.md](02_DOMAIN.md)) — edges form only
from mutual positive ratings and direction is never stored. Stated plainly: **a one-sided
"I enjoyed them" never causes a re-match.** This is load-bearing for privacy, not manners.
If one-sided liking could pull someone back, being re-matched would leak that they liked
you, and *not* being re-matched would leak the opposite.

### ⑥ Completion — second dyad, then leftovers

1. **Second dyad:** the draw runs again on a new seed chosen from the remaining candidates,
   under one added constraint — every cross pair between dyad 1 and dyad 2 must be
   strangers.
2. **So "2 known + 2 known, dyads strangers" is not a template. It is what happens when
   both draws succeed.** One draw succeeding is one dyad plus two strangers. Neither
   succeeding is four strangers. The four `GroupTemplate` entries of the earlier draft were
   *outcomes* described as *modes*; the registry is deleted, and with it the separately
   tuned "template mix" that could disagree with the ratio.
3. **Leftovers:** anyone not placed by a draw is placed into a group with an open seat under
   hard constraints only, longest-waiting-first among those in good standing. **A matched
   person beats a marginally better group** — that principle now lives here, as a placement
   pass, rather than as a `λ` inside an objective that no longer exists.

*Rejected — keeping the hill-climbing improvement pass:* it existed to repair the
order-dependence of greedy score maximisation. There is no score to maximise, so there is
nothing to repair. Deleting it removes a wall-clock budget, a tuning knob, and a class of
non-determinism, and costs nothing.

**Permanent invariants, at every graph density, forever:**

1. **No person is ever the only one of their gender in a group** — at *any* group size.
   This single rule replaces "2+2 or 4-same", covers the 3-person backfill case, and needs
   no special case for a third gender value. See [09_OPEN_QUESTIONS.md](09_OPEN_QUESTIONS.md) C-4/C-5.
2. **At most half the pairs in a group may have met before.** 2+2 gives two of six; it
   holds by construction.
3. **No pair is ever re-matched deterministically**, however strong the edge. If a strong
   pair always reappeared, its *absence* would become information about how someone rated —
   which breaks the asymmetry invariant ([02_DOMAIN.md §6](02_DOMAIN.md)).
4. **A person under sanction is never a seed** (§④).

> **Deleted invariant, and why.** An earlier draft required that *"at least one member of
> every group is not connected to anyone else in it."* It contradicts the 2+2 this product
> was explicitly asked for, and the job it was doing — preventing closed cliques — is done
> properly by the stranger share `C` and by the cooldown in §5. An invariant that
> contradicts the specification is a bug in the invariant.

### ⑦ Validation — reject and rebuild

Whole-group invariants are checked once, at the end. A group that fails is **discarded and
rebuilt**, never patched. Patching a group to satisfy a composition rule is how you get
"technically 2+2" groups where the swapped-in person satisfies nothing else.

### ⑧ Emission

For every proposed hangout: the seed, each member's **`ring_intended` and `ring_realised`**,
the intermediary for any R2 draw, per-pair affinity components, the chosen cluster, and the
alternates that were considered and rejected with the reason. Written to
`match_run_groups`. **This is what makes §9 and the console's explain view possible, and it
cannot be reconstructed later.**

It is also what makes a match *sayable*: "you were matched with C because C is a friend of
someone you liked." We never show that to a user — it would leak the graph — but if the
system cannot produce that sentence internally, the match was an accident.

---

## 3. Cadence and rounds

- Default: **one run per day** per city, at a configured hour, forming hangouts for slots
  `lead_days` ahead (default 2–3 days). Config keys, changeable from the console (D5).
- **Repair runs** are the same function with a restricted snapshot (only the broken
  hangout's slot, only standby-eligible people) and `A = B = 0`, because a backfill at
  noon cannot afford to be picky about rings. Same code, different input — not a second
  algorithm.
- **Dating rounds** are a flag on the run: a different composition rule, a different
  eligibility filter, and a global frequency budget ([07_DATING.md](07_DATING.md)). One
  rule differs structurally from friend rounds: **on the abundant side of the gender
  ratio, selection is longest-waiting-first, not score-first.** Scoring the abundant side
  would let a handful of people absorb every dating hangout — the dating-app dynamic,
  reproduced inside our matcher.

**Why one function with different inputs, not three matchers:** every extra matcher is a
place where the invariants get re-implemented slightly differently. The backfill path is
exactly where a rushed second implementation would forget the exclusion check.

---

## 4. Backfill (the morning-of repair)

Triggered when a member declines or goes silent past `confirm_deadline_at`.

1. Build the standby pool for the slot: people who marked available and were not matched,
   plus people who opted into "notify me if a place opens".
2. Filter by the same hard constraints **plus** a stricter proximity bound (a replacement
   invited at 12:00 for 17:30 will not cross the city).
3. Rank by: fewest recent hangouts, then affinity to the remaining confirmed members.
4. Invite **one at a time with a short expiry** (default 45 min), not a broadcast race.
   *Why:* a broadcast produces multiple acceptances and either an over-full group or a
   humiliating "sorry, taken" — the exact ambiguity this product exists to remove.
5. Stop at `backfill_until`. Then:
   - **3 confirmed and invariant 1 still holds** (nobody is the only one of their gender)
     → proceed, notify the group that it is a three
   - **3 confirmed but invariant 1 is broken** — a 2+2 that lost one woman is 1W+2M →
     **cancel.** This is the case the invariant exists for, and it is the reason backfill
     at step 3 ranks same-gender replacements first.
   - 2 confirmed → **cancel by default** (configurable): a pair of strangers is a
     different, higher-pressure social event than the one they agreed to. Exception when
     the remaining two already have an edge.
   - ≤1 → cancel, notify, and credit priority in the next run

*Rejected — running the unbalanced three with a disclosure and a free withdrawal:* the
withdrawal is free in the app and expensive socially, because the person who withdraws
knows the other three will notice. "You may leave" is not a real option when leaving is
visible, so the system must not create the situation.

Everyone is told the outcome **before they would leave home**. A wasted trip is the
single most trust-destroying experience the product can deliver.

---

## 5. Cooldown, saturation, and why repetition is bounded

A pair may meet again after `max(cooldown_meetups=2 intervening hangouts, cooldown_days=21)`.

- **Below that:** ineligible for each other.
- **Above that:** the `friend` component raises probability, never certainty.

Intention, twofold: repeated exposure is the only known mechanism by which acquaintances
become friends (so repetition must be possible), and *guaranteed* repetition would leak
rating information (so it must never be certain). The cooldown also provides social cover:
because even the best pairs sit out a couple of rounds, "we have not been matched again"
is the normal experience for everyone and carries no signal.

---

## 6. The respect signal, used carefully

Respect ratings are sparse and noisy early — the transcript names the problem exactly
("if they have 3 ratings the noise is high").

**Mechanism — Bayesian smoothing with an explicit evidence gate** (specified in full in
[04_TRUST.md §4.1](04_TRUST.md)):

```
respect_rate = (yes + α₀) / (yes + no + α₀ + β₀)      α₀,β₀ from a prior mean ≈ 0.97
usable       = (yes + no) ≥ min_respect_ratings        (default 12 — your number, because
                                                        almost everyone presses yes, so a
                                                        small sample carries no information)
```

- Below the evidence gate, a person is treated as **neutral** — never penalised for
  having little history, never boosted either.
- Above it, respect is used as a **gate and a throttle, never as a ranking boost**:
  - below `respect_floor_dating` → excluded from dating rounds entirely
  - below `respect_floor_friend` → match frequency throttled (fewer hangouts per period)
    and preferentially matched with others in the same band
  - one `no` from a single rater is an *infraction input of low weight*, not a verdict

**Why gate/throttle and never boost:** boosting high-respect people creates a
rich-get-richer loop where the pleasant become popular and everyone else quietly stops
being matched — and the signal is far too coarse (one bit, from three strangers) to
justify that. Gating removes the genuinely disruptive tail, which is all the signal can
honestly support. **Rejected — a public or self-visible respect score:** it converts a
safety signal into a status game within one week.

---

## 7. What the matchmaker must never do

1. Never place a suspended, banned, or throttle-exhausted person.
2. Never violate an exclusion, in either direction, for any reason, including backfill
   urgency.
3. Never re-pair deterministically.
4. Never produce a group where a member has no path to *anyone* they can talk to in a
   dating round (§ [07_DATING.md](07_DATING.md)).
5. Never emit a group whose composition rule fails — rebuild instead.
6. Never write to the database itself. It returns a plan; the worker persists it
   transactionally. *Why:* a matcher that writes cannot be dry-run, cannot be simulated,
   and cannot be rolled back.
7. **Never be reachable from a user's device** (D9). No client RPC, table write, or
   realtime channel triggers a run; matching is time-triggered only, the worker has no
   public ingress, and the matching library is not compiled into the mobile binary — a CI
   rule enforces that import boundary. Nothing about a match — score, slot role, template,
   or reason — is ever exposed to a client, which is simultaneously a privacy control and
   an anti-gaming control. See [11_SECURITY.md §3](11_SECURITY.md).

Each of these is a property-based test, not a code review item.

---

## 8. Tuning before there are users: the simulator

`tools/simulator` builds a synthetic city: N people with sampled home anchors,
availability densities, show-up probabilities, "pleasantness" latents that drive their
ratings of each other, and churn behaviour (probability of leaving after a bad or an
unmatched week). It runs the **real matchmaker** for 12 simulated weeks.

Outputs, per configuration:

- % of available people matched, by week
- newcomer time-to-first-hangout (p50/p90)
- repeat saturation: distribution of "how many of my hangouts contained someone I had
  already met"
- edge formation rate; clique formation rate
- attendance, cancellation, and sanction rates
- Gini-style concentration: is the top decile of users absorbing the hangouts?

**Why this exists:** every weight in §3 is currently a guess. A guess tested against a
simulated population with plausible behaviour is still a guess, but it is one whose
*failure modes* you have already seen — starvation, clique capture, cooldown deadlock —
and those are structural, not empirical. It also becomes the regression harness: a PR that
changes a weight prints a metric diff.

**What it cannot tell us:** whether people enjoy the hangouts. Nothing simulated can.
Real-world tuning starts the day there is outcome data.

---

## 9. Measuring whether the matchmaker earns its complexity

The claim under test: *graph-informed groups produce more mutual warmth and better
attendance than random eligible groups.*

- **Primary metric — edge yield:** mutual edges formed per completed hangout, sliced by
  **`ring_realised`**. The question the slice answers is the one that matters: *does an R2
  draw (a friend of someone you liked) actually beat a stranger?* If it does not, the graph
  is decoration.
- **The control arm is now free:** a run with `A = B = 0` is all-strangers by construction,
  so the permanent 10–20% control needs no separate code path — it is a config value on a
  fraction of runs. Permanent, not an experiment with an end date, because the alternative
  is never knowing.
- Secondary: attendance rate by realised ring; newcomer time-to-first-hangout; cancellation
  rate; rating-completion rate; **configured-versus-realised ring mix**, which is a health
  metric for the matcher rather than for the product.

**If ring-drawn groups do not beat the control, the honest response is to set `A = B = 0`
and ship the constraint solver alone** — availability, cluster reachability, composition,
cooldown, safety are doing most of the real work regardless. Note what the ring draw buys
us here: that retreat is a **config change**, not a refactor. The earlier score-maximising
design would have required deleting code to admit the same thing, which is precisely why
nobody ever does.
