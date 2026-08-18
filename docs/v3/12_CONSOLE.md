# 12 — The master console

Directives **D5** (everything configurable), **D10** (automation adjudicates, humans
calibrate), and the follow-up transcript: *"i want to be able to see the ratio of guys /
girls and be able to see matches made and feedback, and what they rated others"* and
*"randomly select a percentage of users to run different functionality on"*.

The console is a **separate Flutter Web app** (`apps/console`) with its own auth, its own
deployment, and no service-role key in the browser — every read and write goes through an
audited RPC. It is the highest-value target in the system (T7 in
[11_SECURITY.md](11_SECURITY.md)) and is built accordingly.

---

## 1. What the console is *for* — and what it is not for

| It is for | It is not for |
| --- | --- |
| Seeing whether the mechanism works | Adjudicating individual cases (D10) |
| Tuning config, versioned, with a diff and a blast-radius estimate | Editing rows by hand |
| Dry-running the matchmaker before a change goes live | Hand-composing groups |
| Sampling automated decisions to calibrate thresholds | Approving each decision |
| Handling the rare appeal | A moderation queue |
| Vetting venues (a one-time, per-city pass, ~10 min) | Ongoing venue labour |
| Running controlled experiments on a slice of users | Ad-hoc changes to individuals |

**The distinction that makes D10 real:** the console shows you *distributions and samples*
so you can adjust the rules. It never asks you to decide about a person, except when a
person appeals.

---

## 2. The privacy position, stated exactly

Your framing was: *"the core privacy model is no personally identifiable data stored on
server, which means i can look at all the data rent free without invading their privacy."*

The intent is right and it shapes the design. The precise version is worth stating,
because the difference matters legally and practically:

- What we store is **pseudonymous, not anonymous**: an identity hash, a first name, a last
  initial, a gender, a coarse anchor point. Under GDPR that is still personal data — a
  hash is a pseudonym, and a first name plus a city plus a hangout is re-identifying to
  anyone who was there. So "no PII" is not quite true, and building on that assumption
  would produce a system that is legally exposed exactly where it feels safest.
- But the *useful* half of the claim is true and we make it structurally true: **nothing
  you need for analysis requires identity.** Ratios, ratings, matches, feedback, trust
  outcomes — all of it is analysable over pseudonyms.

So the console is **pseudonymous by default**:

1. Every analytical view shows a stable pseudonym (`P-7F3A`), never a name.
2. Names, anchors and identity hashes are **not joinable** in any analytical view. There
   is no screen that puts "Marko ····n" next to "here is what they rated everyone".
3. Revealing an identity is a **deliberate, reason-required, audit-logged action**,
   available only in the appeal and severe-incident flows.
4. All console access is logged: who, what, when, which records.

**Why bother, if you are the only operator?** Three reasons, in order of weight. Osijek is
small and you will eventually recognise someone — the design should prevent you from
learning something about a person you know, not rely on you not looking. If the promise
"nobody ever learns how you rated them" has an asterisk that says "except the operator",
that asterisk will eventually be discovered, and it is the kind of detail that travels.
And an audit log plus non-joinable views is what turns "I didn't snoop" from a claim into
a fact — which protects you, not just them.

Nothing in this costs you analytical power. Everything below is fully available.

---

## 3. Views

### 3.1 Population
- Head count by city; **gender ratio** overall, per slot, per week (the number you asked
  for first — it is the leading indicator for whether 2+2 composition is even feasible)
- Verified vs unverified, active vs dormant, tenure distribution
- Supply/demand heat: available people per slot per H3 ring, and the resulting
  match-feasibility estimate — *this is the screen that tells you whether to recruit or to
  change the slot days*
- Newcomer funnel: signup → verified → availability set → first hangout, with drop-off and
  time-to-first-hangout percentiles

### 3.2 Matching
- Every `match_run`: seed, config version, snapshot hash, duration, how many matched, how
  many left over **and why** (the eligibility funnel: *filtered by cooldown 12, by
  standing 3, by distance 8, unmatched for lack of a composition-compatible partner 5*)
- Per hangout: template, per-member slot role, pairwise score components, alternates
  considered
- **Dry run**: execute the live snapshot against a draft config, diff against the current
  plan, discard. Nothing is written.
- Control-arm comparison: edge yield and attendance for template-composed vs
  `ALL_STRANGERS` groups

### 3.3 Hangouts and outcomes
- Timeline per hangout: proposed → confirmations → backfill attempts → lock → reveal →
  arrivals → ratings → close, drawn from the event log
- Cancellation reasons, backfill success rate, no-show rate by slot and by tenure

### 3.4 Feedback and ratings
- **The rating matrix**: who rated whom and what, over pseudonyms — enjoyment
  distribution, respect distribution, mutuality rate, straight-lining flags
- Per-hangout view: the 12 ratings a 4-person hangout produces, side by side. This is the
  screen that tells you whether a template produced a good evening.
- Distribution drift over time — the early-warning signal for `really_enjoyed` inflation
  once dating ships ([07_DATING.md](07_DATING.md))
- Meeting-point feedback: was it easy to find, was it pleasant — feeding the venue quality
  score ([05_PLACES.md](05_PLACES.md))

### 3.5 Trust (calibration, not adjudication)
- Standing distribution across the population — *the screen that catches a
  mis-configured trust system before it strangles a young city*
- Every automated decision with its evidence: which infractions, which independence
  weights, which threshold it crossed. **Sampled review**: the console picks N recent
  decisions at random and asks you "would you have made this call?" — your answers are
  recorded as calibration data, not as overrides
- Threshold simulator: "with these thresholds applied to the last 90 days, 4 people would
  have been suspended instead of 11" — before you save the change
- Appeals queue (expected volume: single digits per month)

### 3.6 Venues
- Ingestion results, candidate scoring, the vetting checklist, cluster map
- Usage rotation, sigil collisions (should be zero), and user-reported venue problems

### 3.7 Config
- Versioned editor, typed keys, scope (`global → country → city → experiment → cohort`)
- Diff view, effective-from timestamp, note field, one-click rollback
- **Blast radius**: which in-flight hangouts, if any, a change would touch (answer should
  usually be "none" — in-flight objects keep their version)
- Safety-critical keys are marked and require a confirmation step: the safety brief, ban
  thresholds, age gate, composition rules

---

## 4. Experiments (the dating pilot, and everything after it)

You asked for the ability to run new functionality on a random slice of a city. Built as a
first-class mechanism, because the alternative — flipping a flag for "some people" by
hand — is unrepeatable and unanalysable.

**Assignment:** deterministic and stateless.

```
bucket(person, experiment) = HMAC(experiment_salt, person_id) mod 10000
```

Same person, same experiment, same variant, forever — no assignment table needed to make
it work, though assignments are recorded for analysis. Different salt per experiment, so
being in the treatment arm of one experiment does not correlate with another.

**Definition:** an experiment is a config-layer entry — key, variants, allocation
(e.g. 20% treatment), targeting (city, tenure ≥ N hangouts, standing = GOOD), start/end,
primary metric, and **guardrail metrics with auto-stop thresholds**.

**Guardrails are mandatory, not optional.** Every experiment declares the metrics that
would make it a bad idea — report rate, no-show rate, cancellation rate, rating
completion — and the worker halts the experiment automatically if one breaches. An
experiment that can quietly make the product worse for two weeks is worse than no
experiment.

**Recording:** every hangout, match run and sanction records the experiment variants
active for it. Without that, the analysis is guesswork and the experiment was theatre.

**The dating pilot, concretely:** enable dating for a 15–20% slice of eligible Osijek
users; primary metric = whether romantic-conduct reports in *friend* hangouts drop for the
treatment arm (that is the actual hypothesis — the valve theory); guardrails = report rate
and female retention in the treatment arm, with auto-stop. Note the population caveat:
dating needs a dense compatible pool, so a 20% slice may be too thin to form hangouts at
all — the honest options are a larger slice in one city or a time-based rollout instead of
a user-based one. The console should show that feasibility estimate before you start.

---

## 5. Access control

| ID | Control |
| --- | --- |
| AC-1 | Separate app, separate auth realm, separate domain from anything user-facing |
| AC-2 | **MFA required.** No exceptions, including for you |
| AC-3 | Roles: `viewer` (aggregates only), `operator` (config, vetting, appeals), `owner` (experiments, safety-critical keys). Least privilege by default |
| AC-4 | **No service-role key in the browser.** Every action is an RPC that re-checks the role server-side |
| AC-5 | Every action written to an append-only audit log with actor, target, before/after, reason |
| AC-6 | Identity reveal, config changes to safety-critical keys, and manual sanction overrides each require a typed reason |
| AC-7 | Session timeout; re-auth for destructive actions |
| AC-8 | The console cannot delete audit rows, event log rows, or trust evidence — not as a policy, as a permission |

---

## 6. Build order

The console is not a P5 nice-to-have; parts of it are how earlier phases are verified.

| Phase | Console capability |
| --- | --- |
| P0 | Config editor (versioned) + city/slot schedule. Nothing else can be tuned without it |
| P1 | Population + funnel views; venue vetting |
| P2 | Match-run inspector + dry run; hangout timelines; rating matrix |
| P3 | Trust distributions, decision sampling, threshold simulator, appeals |
| P4 | Control-arm analysis, metric dashboards |
| P5 | Experiments framework |
| P6 | Dating pilot on top of experiments |
