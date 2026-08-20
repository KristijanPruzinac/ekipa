# Ekipa — product & strategy

The founding reasoning behind the app. Read this before making product decisions;
the mechanics elsewhere (PLAN, DESIGN) follow from it.

## Who this is for

Not "introverts". The real category is **people whose need for connection is
normal or high, but whose tolerance for the local connection ritual is low.**
Clubs and bars are a filtering mechanism — loud, alcohol-centered,
high-ambiguity, performance-heavy — and that filter excludes autistic people,
demisexual people (who need slow familiarity before anything feels real),
socially anxious people, and plain quiet people. What they share isn't a
personality type; it's a **mismatch with the dominant third places.** That's why
you find them online: online strips out the parts of socializing that cost them
the most — initiation, noise, ambiguity, and the inability to exit.

## Why they're structurally isolated

This is the core insight and it's a paradox: **the group is defined by absence.**
You find extroverts by going where they gather. You cannot find people by where
they aren't. Discovery requires broadcasting, which is exactly the behavior this
group avoids. So every member assumes they're alone when the city is statistically
full of them. **It's a coordination failure, not a scarcity problem** — and
coordination failures are solvable with tooling.

## Why existing attempts fail

- **Meetup** is event-shaped: big groups of strangers, one host doing
  performative labor, one-off attendance. Big groups of strangers are the worst
  possible format for this population.
- **Bumble BFF and similar** trap people in chat purgatory — endless texting that
  never converts to meeting. This group is precisely the group that won't force
  the conversion.
- **Anonymous-signal ideas** (e.g. "send a heart to someone nearby") are poetic
  but create ambiguity with no path to action — and ambiguity is the one tax this
  group cannot afford.

## Design principles that follow

- **Groups of 2–4, never events.** Small enough that nobody lurks and nobody
  performs.
- **Activity-first, shoulder-to-shoulder.** Parallel activity removes the
  conversational spotlight. "Hang out and talk" is the hardest format; make it
  impossible to schedule.
- **Kill the initiator role.** The bottleneck in all informal socializing is that
  someone must propose, pick a time and place, and absorb rejection risk. Nobody
  here wants that job. The system is the extroverted friend: it proposes a fully
  formed plan; everyone just taps yes or no. **Rejection lands on software, not a
  person.**
- **Ambiguity-minimizing by default.** Fixed duration, stated end time, explicit
  "what happens", a normalized exit script. Autistic-friendly turns out to be
  everyone-friendly.
- **Repetition over novelty.** Casual friendship takes ~40–60 hours together.
  One-off meetups mathematically cannot produce friends. The unit is a recurring
  small group; the app's job is keeping that cadence alive with zero organizing
  effort.
- **Minimal-to-no pre-meeting chat.** The meeting is the product.
- **The app is the host.** There is no organizer, no venue partner, no person
  running the meetup. Everything a host would do — deciding the place, helping
  people find each other, breaking the first silence, starting the activity —
  has to be absorbed by software. See below; this is the constraint that shapes
  the most of the product.

## Where it happens: curated outdoor spots, no venue, no host

We can't organize anything. No reserved tables, no partner café, nobody
standing there to greet people. That sounds like a weakness and mostly isn't:
what we're forced into is a pure software product that replicates to a second
city at zero marginal cost, because there's nothing physical to replicate.

**The default is a quiet, visible, free outdoor spot**, not a café terrace.
A terrace looks like the safe choice — a table, chairs, a scene that "explains
itself" to onlookers — but legibility to onlookers is a comfort for people who
care how the scene reads, and ours are the people most drained by exactly that.
Priced honestly, a café charges our users on every axis they're sensitive to:

| Cost | Café terrace | Outdoor spot |
| --- | --- | --- |
| Sensory load | music, crowd noise, bleed-through conversation | quiet |
| Being observed | an audience of patrons and staff | nobody watching |
| Forced transactions | the waiter, ordering under time pressure | none |
| Money | a per-meetup cost, weekly, for students | free |
| Time pressure | the table is implicitly rented | open-ended |
| Seating geometry | face-to-face, sustained eye contact | side-by-side, walking |

That last row matters more than it looks: side-by-side and walking formats let
conversation happen without sustained eye contact, which is the whole
shoulder-to-shoulder principle, and a café physically prevents it.

Three real problems survive, and they were never actually about cafés — a venue
was just a lazy way to solve them:

- **Safety is visibility, not a roof.** What makes meeting strangers safe is
  other people within sight. So the curation rule is *open and
  populated-adjacent*: the Drava promenade, a park lawn beside a used path,
  riverside steps. Never a quiet corner nobody walks past — especially for
  women, especially after dark. Daylight-leaning defaults for new groups.
- **Cards need a surface.** Prefer spots with picnic tables or wide steps, and
  lean on formats that need no surface at all. This is the strongest argument
  for the in-app question deck: it works on a bench, on grass, on a walk.
- **Weather and darkness are the honest cost.** In continental Croatia,
  November–March, outdoor-only means the app hibernates. A summer launch
  doesn't have to solve it, but it's coming. The eventual answer is a small
  list of indoor-tolerable fallbacks — and yes, a quiet café off-peak can be
  one of them, as a weather contingency users understand, never as the default.

**Spots are predetermined, never voted on.** Voting feels democratic but it's
friction with a failure mode: a decision, a waiting period, the chance nobody
votes, and forced pre-meeting interaction between people whose whole value
proposition is "no pressure before the meeting." Every decision pushed onto the
group before they've met is a chance for the meeting to dissolve. The app
behaves like a confident host precisely because there is no human one: *here is
the place, here is the time, yes or no.* Curating and rotating a short list of
good spots is a spreadsheet, not an organization.

## The first five minutes (the hostless product's real design problem)

Outdoors this gets *harder*, not easier — no table number, no "we're obviously
the group at table 6." The app has to be the host and the signage both:

- **Finding each other.** Every group gets a name ("you're the Blue Fox group,
  the two benches by the fountain, 18:00"), a precise pin, and a photo of the
  exact spot. Arrival check-ins show how many of the group are already there.
- **The first arriver gets a job**, not an awkward wait: "take the bench facing
  the river — the others will find you."
- **Breaking the silence.** The moment everyone is marked present, the app
  deals the opening move — the first question from the deck. Nobody has to be
  the one who starts, because the app is the one who starts. This is the host's
  single most important function and it's fully scriptable.
- **Running the activity.** Members can declare what they can bring (cards, a
  deck of Uno, nothing), and composition can favor a table where something is
  available. But **the zero-equipment default must be excellent**, because it's
  what most meetups will actually be — and that default is the in-app question
  deck. The hostless constraint doesn't add work; it promotes the deck from a
  later nicety to v1 core, with physical games as a bonus layer on top.

The rule that generalizes: every time a design choice trades "reads as normal
to outsiders" against "feels low-cost to the participants," this product picks
the second one.

## The vibe mechanic (why it beats an algorithm)

After a real meeting, each person privately answers **"how did it feel?"** for
each person — at four levels: really enjoyed / enjoyed / no preference / rather
not. **Mutual human judgment after a real meeting beats any interest model.**
Rules that make it safe:

- **Strictly mutual, strictly private.** Only mutual warmth (both people at
  *enjoyed* or above) seeds a future group. A one-sided feeling and any
  reluctance are never revealed. Nobody can ever learn they weren't picked.
- **Never framed as rating people.** It's a preference about your future, not a
  judgment of them — which is why the scale is *feelings*, not stars.
- **"Rather not" is a silent, permanent exclusion.** The pair is never composed
  again; the other person is never told. It's the gentle, un-accusatory version
  of a block, folded into the same quiet gesture.
- Mutual warmth becomes edges in a graph the composer uses to seed future groups.
- **A one-sided warm answer decays silently.** Nobody may ever be able to infer
  "I said yes to them and was never grouped with them again, so they must have
  said no." In a city the size of Osijek that inference, made once and told to
  one friend, is a story that travels. It's why the reflection is asymmetric by
  construction and why nobody is ever shown anything about how they were
  reflected on.

**The graph is never used alone.** Composing only from existing edges produces a
closed clique that stops growing and that new users can never enter — an empty
graph means never being grouped, which means churn in week one. So every group
is a blend: roughly half people connected through the graph (one or two hops of
mutual warmth) and half wildcards — newcomers or plain randomness. Randomness
isn't a fallback for a cold start, it's a permanent feature: it's the
exploration mechanism, the on-ramp for newcomers, and the source of the
surprising pairings a graph can't see. Graph edges are exploit, wildcards are
explore, and the composer never goes pure exploit.

**Repeating people is deliberate.** One familiar face lowers the threat level of
the whole evening — an anchor, which matters most to exactly our users — and
repeated exposure is *how* acquaintances become friends. An app that only ever
produces one-shot meetings manufactures pleasant evenings and no relationships,
which betrays the mission. But a group that is *all* familiar faces has stopped
being an introduction, so repetition is bounded rather than maximized. The
promise lands at "someone you liked, plus someone new," which is a better
promise than pure novelty anyway.

> The exact mechanism — how an edge forms, what it weighs, how it ages, the
> slot-by-slot composition rule, the cooldown, and how any of it is measured —
> is specified in **[GRAPH.md](GRAPH.md)**. This section is the reasoning;
> that document is the algorithm.

## Group crystallization (a ladder, because friendship has stages)

1. **Mixing (meets 1–3):** groups composed fresh, seeded by mutual yeses as they
   accumulate. This finds the vibes.
2. **Cohort:** when 3–4 form a mutual-yes clique, the system offers *opt-in*
   "make this a regular thing, every other Saturday". One tap each → a standing,
   auto-scheduled group. Opt-in, never silent lock-in (that's ambiguity again).
3. **Graduation:** after ~8–10 meets the group doesn't need the app. Let them
   exchange numbers / export a chat. **The app succeeding means getting out of the
   way** — design for it proudly; it's the best marketing.

## Failure modes to design against

- **No-shows** are deadly here; one ghosted meetup can end a user's willingness
  forever, and with no host and no reserved table there is nothing to absorb it.
  Expect this to be the #1 operational problem. Countermeasures: a day-before
  nudge and a morning-of confirmation tap (a no-confirm quietly shrinks/cancels
  and notifies everyone *before they leave home*), an internal-only reliability
  score so flakes get matched with flakes and reliable people are protected,
  and — once there's real no-show data — deliberate overbooking to 5 for a
  4-person meetup. A group of 2 because two people flaked is a worse product
  experience than a mediocre match. Never shame anyone publicly.
- **The 2-person problem:** pairs are highest intimacy and highest risk. Default
  to 3–4 for first meetings; unlock pairs only between a mutual yes.
- **Nobody vibes:** quietly vary composition and activity rather than ever
  surfacing the fact.
- **Safety, especially for women:** same-gender group option; new configurations
  meet only at **open, visible, populated-adjacent spots in daylight** (the
  curation rule above — visibility is the safety mechanism, not indoorness);
  identity verification behind the scenes (display stays first-name only);
  silent block-and-report that guarantees never being grouped again. If women
  don't feel safe, you lose half the network and the other half's trust.
- **Gender composition, decided upfront rather than emergently.** Undesigned,
  the app quietly becomes a dating app or becomes creepy for women — either one
  kills the friendship product. The v1 rule is boring on purpose: **never
  exactly one woman in a group.** All-same, an even split, or 3+1 where the
  three are women. It costs some composer flexibility and saves the product.
- **Romantic ambiguity:** state loudly and repeatedly that this is for friendship;
  mixed groups of 3–4 rather than pairs structurally defuse it.

## Cold start (concretely, for a city like Osijek)

The composer needs ~30–50 active users in one city to form groups reliably.
Narrow brutally: one city, one or two activity types first (walks and board games
— cheapest to organize, most silence-tolerant). Recruit where the population
already is: local subreddit, Discord servers, FERIT student groups,
neurodivergent/introvert communities, the bouldering-gym notice board.

**Run the mechanism by hand first.** For a month or two, personally play the
composer with a spreadsheet and a form: propose small recurring
shoulder-to-shoulder meetups with explicit rules and observe what breaks. It
validates the loop and seeds the first cohorts before a line of composer code has
to be trusted. The same admin path becomes the automated composer later.

Do the unscalable things at ignition, too: personally invite people for the
first ~10 meetups, curate and photograph the spot list yourself, and be
reachable the evening of. Before the graph exists the composer is pure
randomness — which is fine, that's what the sequencing is for — so the quality
of those first meetups comes from hand-work, not from code.

**The metric v1 has is retention, and only retention.** The graph is empty
until people come back; matching intelligence is worthless before there are
~50 active users and a few dozen meetups of outcome data. The characteristic
failure for someone with a developer's instincts is building the interesting
algorithm before the habit exists.

## Money (later, never at the start)

Charge at the **standing-group stage**, the point the app has demonstrably
delivered — a few € / month for "your group runs on autopilot". Never per-message,
never boosts, never coupons; all import dating-app psychology this product
rejects. (An earlier draft floated venue partnerships — board-game cafés,
climbing gyms — as "the incentive idea reborn as reduced friction." That's
demoted: the product is deliberately venueless, and the only place a venue may
reappear is the winter fallback list, where it is a weather answer and not a
business relationship.)

## The one-sentence spec

> An app where lonely, quiet people answer a few taps of questions, receive fully
> organized invitations to tiny low-pressure meetups, privately mark who they'd
> see again, and the system slowly crystallizes those mutual yeses into recurring
> friend groups that eventually don't need the app at all.

The hardest step — the first initiation — dissolves under this design, which is
the sign the design is right: the best solution to the hardest step is a system
where that step was never the user's to take.
