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

## The vibe mechanic (why it beats an algorithm)

After a real meeting, each person privately answers "who would you be happy to
see again?" **Mutual human judgment after a real meeting beats any interest model.**
Rules that make it safe:

- **Strictly mutual, strictly private.** Only mutual yeses have any effect. A
  one-sided yes and any no are never revealed. Nobody can ever learn they weren't
  picked.
- **Never framed as rating people.** "Who would you be happy to see again?" is a
  preference about your future, not a judgment of them.
- Mutual yeses become edges in a graph the composer uses to seed future groups.

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
  forever. Countermeasures: a morning-of confirmation tap (a no-confirm quietly
  shrinks/cancels and notifies everyone *before they leave home*), and an
  internal-only reliability score so flakes get matched with flakes and reliable
  people are protected. Never shame anyone publicly.
- **The 2-person problem:** pairs are highest intimacy and highest risk. Default
  to 3–4 for first meetings; unlock pairs only between a mutual yes.
- **Nobody vibes:** quietly vary composition and activity rather than ever
  surfacing the fact.
- **Safety, especially for women:** same-gender group option, public venues only
  for new configurations, identity verification behind the scenes (display stays
  first-name only), silent block-and-report that guarantees never being grouped
  again. If women don't feel safe, you lose half the network and the other half's
  trust.
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

## Money (later, never at the start)

Charge at the **standing-group stage**, the point the app has demonstrably
delivered — a few € / month for "your group runs on autopilot". Never per-message,
never boosts, never coupons; all import dating-app psychology this product
rejects. Venue partnerships (board-game cafés, climbing gyms) for cheaper meetups
on quiet weekdays are the incentive idea reborn as reduced friction, not a bribe.

## The one-sentence spec

> An app where lonely, quiet people answer a few taps of questions, receive fully
> organized invitations to tiny low-pressure meetups, privately mark who they'd
> see again, and the system slowly crystallizes those mutual yeses into recurring
> friend groups that eventually don't need the app at all.

The hardest step — the first initiation — dissolves under this design, which is
the sign the design is right: the best solution to the hardest step is a system
where that step was never the user's to take.
