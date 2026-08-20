# Ekipa — the connection graph and the composer

This is the actual working mechanism: what the graph is made of, when an edge
appears, what it's worth, how it ages, and exactly how a group gets composed
from it. PRODUCT.md says *why* it works this way; this says *how*, in enough
detail to implement and to argue with.

Everything here is grounded in the existing schema — `reflections`,
`exclusions`, `blocks`, `mutual_connections()` in
[`0001_init.sql`](../supabase/migrations/0001_init.sql) and
[`0006_v2_identity_and_reflection.sql`](../supabase/migrations/0006_v2_identity_and_reflection.sql).
Where the mechanism needs something the schema doesn't have yet, it says so
under **Gap**.

---

## 1. What the graph is

- **Nodes** are profiles. Nothing else. A node carries logistics (city,
  availability, activities, group size, gender, equipment) and one internal
  number (`reliability`). It carries no interests, no personality, no text
  anyone reads.
- **Edges are mutual warmth after a real meeting.** Not a stated preference,
  not a profile similarity, not a swipe. The edge is evidence, produced by two
  people who spent 90 minutes together and independently said the meeting was
  good.
- **Anti-edges** are `exclusions` (from a `rather_not`) and `blocks`. They are
  permanent, symmetric in effect, and invisible.

The single most important property: **the graph is the only thing in the system
that knows anything real about compatibility.** Every other input — activity
overlap, availability, group size — is scheduling, not matching. That's why the
graph is worth building carefully and why nothing smarter should be attempted
until it has substance.

### What is deliberately not in the graph

- **Direction.** `mutual_connections(u)` returns counterpart ids only. No
  caller — not even an admin screen — learns who felt what, or who felt more.
- **One-sided warmth.** It creates nothing. It is not stored as a weak edge, a
  pending edge, or a "they might come around" hint. It simply never becomes
  anything, and it is never surfaced anywhere, to anyone.
- **Rejection.** A `rather_not` writes an `exclusions` row and produces no
  other observable effect anywhere in the product.

---

## 2. Edge formation — the exact rule

An edge between A and B exists when **all** of the following hold:

1. A and B shared a meetup that reached `completed`.
2. **Both actually attended it** (`meetup_members.attended`).
3. A reflected on B with `really_enjoyed` or `enjoyed`, *and* B reflected on A
   with `really_enjoyed` or `enjoyed`.
4. Neither has excluded or blocked the other, in either direction.

Rules 3 and 4 are what `mutual_connections()` already implements. **Rule 2 is
not implemented** — `attended` exists on `meetup_members` and is never written.

> **Gap — the attendance gate.** Right now a no-show can accumulate edges: if
> two people are invited, one doesn't turn up, and they both fill in a
> reflection anyway, the schema will happily form an edge from a meeting that
> didn't happen. Marking attendance is part of the arrival flow (PLAN Phase
> 2b): whoever checks in is present, and non-check-ins are resolved by the
> others' check-ins. `mutual_connections()` then needs `and mm.attended` joins
> on both sides.

### Silence is neutral, permanently

A missing reflection produces no edge and no exclusion. It never decays into a
negative, is never inferred from, and is never nagged about more than once.
This is the correct behaviour ethically and it creates the mechanism's biggest
practical risk, so it gets its own heading below (§7).

---

## 3. Edge weight, and why the four levels aren't wasted

`mutual_connections()` currently flattens `really_enjoyed` and `enjoyed` into
the same binary edge. That was right for shipping and is wrong for composing:
it throws away the one bit of gradient the reflection actually collects.

**Weight = the sum of the two sides**, with `enjoyed` = 1 and `really_enjoyed`
= 2. So an edge is 2, 3, or 4:

| A said | B said | Weight | Reading |
| --- | --- | --- | --- |
| enjoyed | enjoyed | 2 | it was fine, worth repeating |
| really enjoyed | enjoyed | 3 | one-sided spark, real edge |
| really enjoyed | really enjoyed | 4 | the thing we're trying to manufacture |

Weight is a **ranking signal inside the composer only**. It never surfaces, not
as a number, a label, an ordering of names, or a "you two got on well" nudge.
The asymmetry invariant (§5) forbids anything that would let someone reconstruct
a 3 from a 4.

### Recency

An edge from last month should outrank an edge from a year ago that never
repeated. Effective weight decays on the time since the pair last met:

```
effective = weight × 0.5 ^ (days_since_last_met / 120)
```

A ~4-month half-life, chosen so a good edge survives a season of nobody being
free but a stale one stops crowding out exploration. **Every co-occurrence
refreshes it** — that's the compounding the whole product is after: pairs that
keep meeting keep rising, pairs that fizzled quietly sink without ever being
deleted or judged.

> **Gap.** Both the weight and the recency need `mutual_connections()` to
> return more than `other_id` — minimally `(other_id, weight, last_met_at)`.
> It stays `security definer`, `service_role`-only, and still never returns
> direction. Proposed as migration `0009`.

---

## 4. Composing a group

The composer fills a group of 3–4 **slot by slot**, and every slot has a kind.
The kind is the mechanism; it's what makes the explore/exploit split real
rather than aspirational.

### 4.1 Hard constraints — checked on every insertion

A candidate who fails any of these is not scored, not ranked, not considered:

- No `exclusions` or `blocks` row with anyone already in the group, in either
  direction.
- Same city, ≥1 shared activity, overlapping availability slot.
- `same_gender_only` honored for everyone already seated *and* the candidate.
- **Never exactly one woman in a finished group.** Checked as a whole-group
  invariant before the group is emitted, not per slot — a group that lands
  there is rebuilt, not patched.
- New configurations (no existing edges among members) get a visible,
  daylight-appropriate spot.

### 4.2 The slot model, for a group of 4

| Slot | Kind | Filled with |
| --- | --- | --- |
| 1 | `anchor` | The person the group is built around |
| 2 | `graph_1hop` | Strongest eligible direct edge from the anchor |
| 3 | `graph_2hop` or `wildcard` | Friend-of-a-friend, else explore |
| 4 | `wildcard` | Newcomer first, else random eligible |

**Slot 1 — the anchor.** Not random. Priority order: people with zero completed
meetups (a newcomer waiting is the most expensive thing in the system), then
longest time since last meetup, then reliability. Anchoring on the most
starved user is what keeps the composer from serving its best-connected users
forever.

**Slot 2 — one hop.** The highest effective-weight edge from the anchor that
passes the cooldown (§4.4) and the hard constraints. If the anchor has no
edges — which is true of every new user — this slot becomes a `wildcard`.

**Slot 3 — two hops.** A candidate connected to slot 1 or 2 by an edge, scored
at `min(edge_a, edge_b) × 0.5`. Two hops is where the graph does work a human
organizer couldn't: it proposes someone you have no evidence about, on evidence
someone you liked does have. Below a floor score, this slot degrades to
`wildcard` rather than reaching for a bad third hop.

**Slot 4 — always a wildcard.** Never filled from the graph, at any graph
density, ever. Priority: users with zero edges, then users whose last few groups
were all repeats, then random among eligible.

### 4.3 The two invariants that keep the graph open

1. **At least one wildcard slot in every group, always.** Not "when the graph
   is sparse" — always. A composer that goes pure-exploit builds a closed
   clique that newcomers cannot enter, and a newcomer who is never grouped
   churns inside a week. Exploration is not a cold-start crutch; it is the
   permanent on-ramp, and it is also where the surprising pairs come from,
   because the graph by construction can only recommend from what it already
   knows.
2. **No group is more than half repeats.** A 4-person group has at most 2
   people who have met before; a 3-person group at most 1 pair.

Together these bound the composer at "someone you liked, plus someone new" —
which is a better product promise than either pure novelty (pleasant evenings,
no relationships) or pure familiarity (a friend group that stopped growing and
doesn't need us).

### 4.4 Cooldown — repetition is the point, saturation is the failure

A pair with an edge **may** be grouped again, deliberately: one familiar face
lowers the threat level of the whole evening for exactly our users, and
repeated exposure is the only known mechanism by which acquaintances become
friends. An app that only ever produces one-shot meetings manufactures nice
evenings and zero friendships.

The bound: **a pair may repeat after 2 intervening meetups for either of them,
or 3 weeks, whichever comes first.** Below that they're ineligible for each
other; above it the recency term (§3) does the rest naturally.

> **Gap.** "When did these two last meet, and how many meetups has each had
> since" is derivable from `meetup_members` ⋈ `meetups.starts_at`, but there's
> no helper for it. `pair_history(a, b)` belongs in `0009` alongside the
> weighted `mutual_connections()`.

### 4.5 Recording why

Every `meetup_members` row should carry the slot kind that produced it.

> **Gap.** `meetup_members.slot_kind` (`anchor` / `graph_1hop` / `graph_2hop` /
> `wildcard` / `newcomer`) doesn't exist. It is one column and without it §8 is
> unmeasurable — there is no way to ask whether graph-composed groups beat
> random ones if nothing records which was which. Add it in `0009`, before the
> first real meetups, because this data cannot be reconstructed later.

---

## 5. The asymmetry invariant

**Nobody may ever be able to infer how anyone reflected on them.** Not from a
screen, not from a notification, and — the hard part — not from the *pattern of
who they get grouped with*.

The dangerous inference is: *"I said really-enjoyed about them, and I've never
been grouped with them since, so they must have said rather-not."* In a city the
size of Osijek, that inference, made once and repeated to one friend, is a story
that travels and it ends the product's credibility.

Defenses, in order of importance:

- **Never re-group anyone deterministically**, including strong edges. Weight
  raises probability; it never guarantees. If a weight-4 pair always reappeared
  next week, its absence would be information.
- **The cooldown provides cover.** Since even the best pairs are ineligible for
  a couple of rounds, "we haven't been grouped again" is the normal case for
  everyone, and carries no signal.
- **No feature ever confirms a pairing was good** — no "you two got on well",
  no reunion notification, no ordering of names by anything but the alphabet.
- **Symmetric silence.** A `rather_not` and a never-submitted reflection
  produce outwardly identical behaviour.

Any future feature must be checked against this. The v2 "two of you have been
thinking about similar things" nudge (PLAN Phase 7) is exactly the kind of thing
that needs auditing here before it ships — it reveals composer reasoning, and
composer reasoning is downstream of reflections.

---

## 6. Graph states and the stage ladder

The stage ladder in PRODUCT.md is really a description of graph density around
a user, which makes it implementable rather than aspirational:

| Stage | Graph state | Composer behaviour |
| --- | --- | --- |
| **New** | 0 edges | All wildcard. Anchor priority. Get them seated fast. |
| **Mixing** | 1–4 edges | Slot 2 from the graph, slots 3–4 explore. |
| **Cohort candidate** | a mutual 3–4 clique | Offer opt-in standing group. |
| **Standing** | clique, opted in | Auto-schedule; the composer stops recomposing them. |
| **Graduated** | ~8–10 meets | Offer number exchange; stop scheduling. |

**Cohort detection** is a triangle/K4 search over `mutual_connections` — for
each user, do any 2–3 of their edges also connect to each other? That's the
whole algorithm, and it is cheap at this scale (hundreds of users, single-digit
average degree). It fires as an *offer*, never an automatic lock-in: silent
enrollment into a standing commitment is precisely the ambiguity this product
exists to remove. One tap each, or it doesn't happen.

**Graduation is a success state, not churn.** A clique that leaves is the
product working; design for it proudly.

---

## 7. Degenerate states (all of which will happen)

- **Empty graph (launch).** Every group is wildcards. This is correct and needs
  no special-casing — the slot model already degrades to it. It is also why v1
  can honestly ship with no matching intelligence whatsoever.
- **Reflections don't get submitted.** *The single biggest threat to the whole
  mechanism.* No reflections means no edges means the graph never starts,
  regardless of how good the composer is. Countermeasures: reflection is the
  one thing the app will ask for (a single prompt the evening after, then
  never again), it takes one tap per person, and it is never framed as rating.
  **Track submission rate as a v1 health metric.** Below roughly 60%, the graph
  mechanism is not viable as designed, and that is a finding to act on, not a
  bug to fix.
- **A user with an edge to nobody who is ever free.** Availability is a harder
  constraint than compatibility. The anchor priority already favours the
  longest-waiting; watch for people who never anchor successfully.
- **Everyone excludes one person.** They quietly become uncomposable. This must
  fail silently and gracefully — no notification, no "we're having trouble
  finding you a group", which would be the cruelest possible message. They keep
  receiving occasional wildcard-only proposals among people they haven't met.
- **The clique that eats the city.** A dense cohort absorbing all the active
  users starves everyone else. The wildcard invariant and the repeat bound
  prevent it structurally; the standing-group opt-out (removing them from
  general composition) does the rest.

---

## 8. Measuring whether any of this works

The composer's entire claim is that graph-composed groups produce more mutual
warmth than random ones. That's testable from day one *if* slot kinds are
recorded (§4.5), and the metric is:

> **Edge yield** — mutual edges formed per group, by slot composition.

Compare wildcard-only groups against graph-seeded ones. If graph-seeded groups
don't yield measurably more, the composer is decoration and the honest response
is to delete it, not tune it. The same measurement later evaluates Phase 7's
thought-aware composition, which is why it's worth wiring the instrumentation
before there's anything to instrument.

Secondary, in rough order of usefulness:

1. **Retention** — did they accept a second meetup. The only v1 metric that
   matters (PRODUCT.md); everything here is downstream of people coming back.
2. **Reflection submission rate** — the mechanism's fuel gauge (§7).
3. **Newcomer time-to-first-meetup** — is the wildcard invariant actually
   working, or is it being crowded out in practice.
4. **Attendance rate** — no-shows corrupt edge formation as well as evenings.
5. **Clique formation rate** — how often mixing actually reaches a cohort. This
   is the closest thing to "the product delivered a friendship."

---

## 9. Build order

Nothing here justifies its complexity before the loop retains people, so:

1. **`0009`** — the schema this mechanism needs and cannot backfill:
   `meetup_members.slot_kind`, `attended` actually written, weighted
   `mutual_connections()` returning `(other_id, weight, last_met_at)`, and
   `pair_history(a, b)`. Small, and it must land before the first real meetups.
2. **Concierge composer** — the slot model run by hand from an admin screen
   (PLAN Phase 4). Same rules, human trigger. It will be pure wildcards at
   first, which is the point.
3. **Automated composer** — the same function on a weekly cron once the manual
   version has stopped surprising you.
4. **Cohort detection** — only once cliques actually appear in real data.
5. **Learned weights** — a model predicting which compositions yield edges,
   trained on your own outcome data. Genuinely useful, and genuinely worthless
   before a few hundred completed meetups exist to train on.
