# 04 — Trust: infractions, standing, sanctions, reports

Rewritten 2026-08-18 under directive **D10**: *"manual review is a no no… manual review
can be used to determine how the configured settings are doing, but not more."*

Lives in `packages/ekipa_core/lib/trust/`. Pure functions. Every output is a decision
object with its evidence attached; the worker persists it.

---

## 1. The design problem, stated precisely

We need a system that decides — **automatically, with nobody reading cases** — whether a
person is a danger, a nuisance, or the victim of two friends who decided to be cruel. It
has to do this with sparse, noisy, adversarial data, and it has to be wrong in the safe
direction.

Your constraint is the interesting one: *"if you get reported by 2 people who know each
other in a single meet, that shouldnt ban you… 2 meets gives better chances that you
actually are the offender."* That is exactly right, and it names the principle the whole
design hangs on:

> **Evidence weight comes from independence, not from count.**
>
> Two accusers who know each other, in one room, on one evening, are close to *one*
> observation. Two accusers in two different rooms on two different evenings who have
> never met are *two* observations, and the second one is worth far more than the first.

Everything below is a mechanisation of that sentence.

---

## 2. Two accumulators, not one

The earlier draft merged everything into one score. That was wrong, and the reason is
worth stating: **a flake and a creep need different responses, and merging them mislabels
both.**

| | **Reliability** | **Conduct** |
| --- | --- | --- |
| Measures | Do they turn up and close out their obligations | Are they safe and decent to be around |
| Fed by | silence at confirmation, no-shows, late arrivals, early leaves, missed ratings | respect ratings, reports, romantic-conduct violations |
| Data density | dense, objective, self-generated | sparse, subjective, adversarial |
| Response | throttle, segregate with other flakes, short suspension | pair exclusion, dating removal, suspension, ban |
| Wrong-direction risk | annoying | dangerous |

They never sum. A person can be perfectly reliable and a menace, or a lovely person who
never shows up, and the system must be able to say so.

---

## 3. Reliability — the easy half

Dense, objective, effectively self-reported by the system. A weighted, exponentially
decaying accumulator (half-life 90 days, config):

| Infraction | Weight | Intention |
| --- | --- | --- |
| `CONFIRM_DECLINE` (within window) | **0.5** | Cooperative. Priced near zero on purpose — §3.1 |
| `CONFIRM_DECLINE_LATE` | 2.0 | Honest but past the repair window |
| `CONFIRM_SILENT` | **3.0** | Silence destroys the repair window |
| `NO_SHOW` | **5.0** | The most damaging single act in the product |
| `LATE_ARRIVAL` (peer-attested) | 1.5 | |
| `EARLY_LEAVE` (peer-attested) | 2.0 | |
| `RATING_MISSED` | 1.0 | Starves the graph of its only fuel |
| `EQUIPMENT_PROMISED_NOT_BROUGHT` | 1.0 | |

Consecutive `CONFIRM_SILENT` / `NO_SHOW` events multiply by `streak_multiplier^(n−1)`
(default 2.0) — this is your "2 declines in a row" rule, expressed as a property of the
accumulator rather than as a separate rule that other mechanisms would have to know about.

**Responses** (all automatic, all reversible by decay):

| Score | Response | Visible |
| --- | --- | --- |
| < 4 | none | — |
| 4–8 | throttle: fewer hangouts per period | no |
| 8–14 | segregation: preferentially matched with others in the same band | no |
| ≥ 14 | suspension, 7d, ladder-escalating | **yes, with reason and end date** |

**Why segregation rather than punishment:** a group where everyone has flaked before is a
group where a flake costs less, and it protects reliable users from absorbing the damage.
It is uncomfortable to write down and it is the honest mechanism.

### 3.1 Why an early decline is nearly free

The system's scarce resource is **time to repair**. Punish declining and people learn to
stay silent and hope — and silence is strictly worse for everyone: no repair, likely
no-show, three people standing at a meeting point. So: **decline early, cost ≈ 0; stay
silent, cost high.** The app must say this in plain words at confirmation time. An
incentive nobody knows about is not an incentive.

Someone who declines *everything* is not a discipline problem, they are a matching
problem — their availability is wrong. Response: a prompt to fix their slots, and a
throttle. Not a ban.

---

## 4. Conduct — the hard half

Two channels feed it, and they have completely different statistical characters. Using
both is what makes automatic adjudication possible.

### 4.1 The dense channel: mandatory respect ratings

Every hangout produces **3 respect ratings per person** whether anything happened or not.
Over ten hangouts that is ~30 observations from ~30 different people who mostly do not
know each other. This is the backbone: it is the only conduct signal that is *dense,
unprompted, and hard to coordinate*, because a colluding pair cannot follow someone
through their next six hangouts.

Modelled as a Beta posterior with a prior that encodes "almost everyone is respectful":

```
disrespect_posterior = (no + β₀) / (total + α₀ + β₀)
     prior weight w₀ = α₀ + β₀ = 12,  prior mean = 0.97 respectful     (both config)
     usable only when total ≥ 12 actual ratings                        (your number)
```

**This is where tenure immunity comes from, and it is automatic** — no separate "trust
score" mechanism needed:

| History | `no` ratings | Posterior disrespect | Reading |
| --- | --- | --- | --- |
| 3 hangouts (9 ratings) | 2 | ~15% | high, but below the evidence gate → **no action** |
| 20 hangouts (60 ratings) | 2 | ~3.3% | indistinguishable from normal → immune to noise |
| 20 hangouts (60 ratings) | 14 | ~19.9% | a pattern nobody can explain away |

A veteran with sixty clean ratings cannot be moved by two malicious `no`s. A newcomer with
nine ratings cannot be sanctioned on the respect channel at all, because the gate has not
been met. Both are correct, and both fall out of the prior rather than out of a rule.

### 4.2 The sparse channel: reports, weighted by independence

A report is a spike, not a trend. It must be able to act fast, and it must not be
weaponisable by two friends in one room.

**Step 1 — within-hangout discount.** Reports about the same person from the same hangout
are ranked and discounted, because they are observations of one event:

```
d = [1.0, 0.4, 0.2]        (1st, 2nd, 3rd reporter in that hangout)
```

**Step 2 — connectedness discount.** If two reporters in a hangout are connected —
a friend edge, a prior shared hangout, or arrival within the same minute — their combined
weight collapses further:

```
m(h) = Σᵢ cᵢ · dᵢ · (1 − κ · maxConnectedness(i, other reporters in h))     κ default 0.7
```

Two friends reporting together in one hangout therefore produce roughly `1.0 + 0.4·0.3 ≈
1.12` — barely more than one stranger's single report. **That is your requirement, in one
line of arithmetic.**

**Step 3 — cross-context accumulation.** Independent contexts are what count:

```
E = Σ_h m(h) · severity(category) · decay(days)
contexts = |{ h : m(h) ≥ 0.5 }|
```

**Step 4 — corroboration from the dense channel.** Within one hangout, the *other*
members' respect ratings are near-free corroboration — and they are themselves discounted
by how connected those raters are to the reporter. A report backed by two unconnected
witnesses rating `respect = no` is strong evidence from a single evening; the same report
with both witnesses saying `respect = yes` is weak.

### 4.3 The response ladder (fully automatic)

Note what each rung costs the accused, because that is what determines how much evidence
it needs:

| Rung | Trigger | Cost to a falsely-accused person | Requires |
| --- | --- | --- | --- |
| **R0 · Pair exclusion** | **any report, immediately** | ~zero — one person they never meet again out of a whole city | 1 report, no corroboration |
| **R1 · Dating removal** | severe category, or E ≥ t₁ | loses an optional feature | 1 credible report |
| **R2 · Silent throttle + composition guard** | E ≥ t₁, or respect posterior above band with ≥12 ratings | fewer hangouts, invisible | 1 context |
| **R3 · Suspension 7d** | E ≥ t₂ **and contexts ≥ 2** | a week out | **2 independent contexts** |
| **R4 · Suspension 30–90d** | E ≥ t₃ and contexts ≥ 2, or R3 repeat | serious | 2+ contexts, ladder |
| **R5 · Ban** | E ≥ t₄ and contexts ≥ 3, or severe with contexts ≥ 2 | total | **3 independent contexts** |

**R0 is the most important rung in the system and it is free.** Whatever the truth, the
reporter never meets that person again. It perfectly protects the reporter, costs an
innocent person almost nothing, needs no evidence, and no human ever has to decide. Most
of what a moderation queue would do, this does instantly and correctly.

**The hard gate: nothing above R2 can fire from a single hangout, ever.** Not from four
reporters, not from a severe category, not from anything. One evening is one observation,
and two friends can manufacture one evening. What one evening *can* do is R0+R1+R2 —
protect everyone present, remove them from dating, and quietly reduce their exposure while
the second observation either arrives or does not.

**And the safety asymmetry:** the throttle applied at R2 after a severe report is
aggressive — matching frequency near zero for a cooling period, and never with anyone
connected to the reporter. Functionally close to a suspension, without being one, and
without needing evidence that does not exist yet. This is how the design reconciles "no
manual review" with "a real harasser must not get four more evenings".

### 4.4 What replaces "the moderator upheld it"

Reporter credibility has to update automatically. Corroboration is the proxy for a verdict:

```
report is SUBSTANTIATED  → independent corroboration arrived within the window
                            (another context, or unconnected respect=no witnesses)
report is UNSUPPORTED    → the subject accumulated ≥ N clean ratings from unconnected
                            people afterwards and no further reports appeared
```

`credibility ∈ [0.2, 1.5]`, starts at 1.0, `+0.15` substantiated, `−0.2` unsupported,
`−0.5` and a `REPORT_ABUSE` infraction on a pattern (reports that never corroborate, or
that concentrate on people who rated the reporter poorly — the revenge signature).

**Why this is better than the "silently mute a serial reporter" rule you proposed:** a
mute means the one time they are right, nobody hears it. Credibility decays continuously,
recovers when they are right, and never silences the channel.

---

## 5. The sanction ladder

`SanctionLadder` is a strategy (D6). Default `PROGRESSIVE_GEOMETRIC`:

```
duration(n) = base · multiplier^(n−1), capped
  reliability: base 7d,  multiplier 3, cap 90d
  conduct:     base 30d, multiplier 3, cap permanent
n = prior sanctions in the lookback window (365d), not lifetime
```

Every sanction records its evidence set, independence weights, context count, threshold
crossed, config version and ladder step. Without that record an appeal cannot be answered
and the thresholds cannot be calibrated — which are the only two things humans still do.

---

## 6. Where humans remain (and why it is not a moderation queue)

D10 says automation adjudicates. Two exceptions, both small and both bounded:

**1. Calibration, by sampling.** The console shows a random sample of recent automated
decisions with their full evidence and asks *"would you have made this call?"* Your answers
are recorded as calibration data — they do **not** change the decision. When the sample
disagrees with you often enough, you move a threshold and the simulator shows what that
would have done to the last 90 days ([12_CONSOLE.md §3.5](12_CONSOLE.md)). This is exactly
your proposal: manual review to see how the settings are doing, and nothing more.

**2. Appeals.** A person suspended or banned can appeal in one tap; the appeal arrives with
its evidence attached. Expected volume at 200 users: single digits per month — that is
exception handling, not a queue.

Appeals cannot be automated away, and the reason is not sentiment: **GDPR Art. 22
restricts decisions based solely on automated processing that significantly affect a
person, and requires a route to human intervention.** A ban is such a decision. The appeal
path is what makes an otherwise fully automatic system lawful, and it is cheap precisely
because R0–R2 are invisible and therefore never appealed.

Overturning an appeal removes the underlying evidence from the accumulator — otherwise a
wrong sanction quietly raises the ladder step for a year.

---

## 7. Anti-abuse of the trust system itself

| Attack | Defence |
| --- | --- |
| Two friends report someone in one hangout | Within-hangout discount + connectedness discount + the hard 2-context gate (§4.3) |
| A group coordinates `respect = no` | Same evening = one context; the Beta prior absorbs it for anyone with history; graph-connected raters are discounted |
| Following someone across hangouts to report repeatedly | The matcher's cooldown and exclusions make repeated co-occurrence structurally hard; repeat reporters of the same subject collapse to near-one weight |
| Revenge report after being rated `rather_not` | `rather_not` is invisible, so the trigger is unobservable |
| Ban evasion | Identity hash is unique and survives account deletion. **With AAI@EduHr deferred, this rests entirely on `.edu.hr` address normalisation** ([09_OPEN_QUESTIONS.md C-1](09_OPEN_QUESTIONS.md)) — lower-case, strip `+tag`, uniqueness enforced in the database. If evasion is observed, the answer is a second factor (phone), not a looser ladder |
| Farming reliability to reach dating unlock | Unlock needs distinct partners and a respect posterior above the evidence gate |
| Report-bombing a newcomer | Newcomers are below the respect evidence gate (no action possible there), and reports still need 2 independent contexts |
| Gaming by never rating | `RATING_MISSED` + the matching gate ([§8](#8-the-rating-gate)) |

---

## 8. The rating gate

Ratings are mandatory. The lever is chosen carefully: **unrated hangouts block being
matched again, not using the app.** Blocking the app is hostile, produces uninstalls, and
punishes someone who only wanted to fix their availability. The gate clears the moment
they rate — a turnstile, not a punishment.

Anti-satisficing: 2s minimum dwell per person, randomised order, no bulk control, and
straight-lining (identical answers at minimum dwell, repeatedly) **down-weights that
rater's influence** rather than rejecting the input. You cannot force sincerity; you can
make insincerity cheap to detect and harmless.

---

## 9. What must be tested

- Property: **no sanction above R2 is ever issued with `contexts < 2`.** This is the
  single most important test in the system.
- Property: two reporters in one hangout with a friend edge can never produce a suspension.
- Property: a person with ≥40 clean respect ratings cannot be moved past R2 by any two
  reports in one context.
- Property: decay is monotonic — commit nothing new and you always trend toward clean.
- Property: overturning an appeal restores the exact prior standing.
- Property: every report produces an immediate pair exclusion, unconditionally.
- Golden: the ladder produces 7/21/63/90 (reliability) and 30/90/permanent (conduct).
- Simulation: with 5% flakes and 1% bad actors, the suspension rate stays inside the
  configured band and bad actors are removed within N hangouts — **and the false-positive
  rate on innocent users under a 2-friend collusion attack is zero.** If the simulator
  cannot show that, the thresholds are wrong, and that must be visible before launch.
