# 06 — Activities

Two at launch, as the transcript specifies. Both are instances of one contract, because
the third activity must not require touching the hangout lifecycle.

---

## 1. The contract

```dart
abstract class ActivityTemplate {
  ActivityId get id;
  Requirements get requirements;          // equipment, min carriers, min people, indoor/outdoor
  Brief brief(HangoutContext c);          // shown at reveal: what happens, how long, how it ends
  ArrivalScript arrivalScript(...);       // what the first arriver does; what unlocks on full arrival
  Session session(HangoutContext c, Seed seed);  // the content, deterministic per hangout
  ExitScript exit(...);                   // the normalised way to leave
}
```

**Why every activity must provide an exit script:** ambiguity is the tax this population
cannot afford, and the most expensive ambiguity in a social meeting is *"is it over?"*.
A stated end time plus a scripted goodbye ("that's the deck — thanks, see you around")
removes the single most dreaded moment of the evening. This is not decoration; it is the
reason people accept a second invitation.

**Why the session is deterministic per hangout** (seeded from hangout id): every member's
phone shows the same card in the same order without any real-time synchronisation, and
the content can be regenerated identically if someone reinstalls mid-hangout. No server
round-trip, no "my phone shows a different question."

---

## 2. `CARDS` — bring a deck

The transcript's reasoning is right and worth preserving verbatim in the code comment:
*"we need at least 2 people with cards in a normal card game meet, because one can dip."*

- `Requirements.equipment = deck_of_cards`, `minCarriers = 2`.
- **This is a matchmaker constraint, not a hope.** A person's profile carries what they
  can bring; the assembler will not emit a `CARDS` hangout without two carriers, and a
  backfill that drops below two carriers **switches the activity** to
  `CONVERSATION_DECK` and tells everyone at reveal, rather than sending four people to
  play nothing.
- The app supplies rules for 3 and 4-player games that work on a bench (Šnaps/Briškula
  for two pairs, President, Durak) with a one-screen rule card — because "we have cards
  and nobody knows a 4-player game" is a real dead end.
- Carriers are asked to confirm at reveal ("bringing your deck?"). A `no` before reveal
  is free and swaps the activity. A carrier who confirms and does not bring gets a low
  infraction — same accumulator, no new mechanism ([04_TRUST.md](04_TRUST.md)).

---

## 3. `CONVERSATION_DECK` — the zero-equipment default

This is the one that must be excellent, because it is what most hangouts will be.

### Structure

1. **Three warm-ups** drawn from a curated easy pool (~10–15), shuffled freely. Their job
   is to get four people talking in turn within ninety seconds, with no self-disclosure
   cost.
2. **The escalating set**, sampled but **never reordered**. The transcript's instinct is
   exactly right and is the actual finding in the literature: the closeness effect comes
   from *gradually escalating reciprocal self-disclosure* (Aron et al., 1997 — the
   "closeness-generating procedure"). The escalation *is* the mechanism; shuffling it
   destroys it and can also land an intimate question on strangers in minute four.
   So: sample a subset, preserve the original relative order, and enforce a minimum gap
   between intensity levels.
3. **Pass is always available**, on every card, for every person, with no explanation and
   no visible record. A question deck without a free pass is an interrogation.

### Content and licensing — flag

The canonical 36-question list is an appendix to a copyrighted 1997 paper (and has been
widely republished, which is not the same as being public domain). **We write our own
deck**, structured on the same published mechanism (three sets of increasing
self-disclosure, reciprocal turn-taking, ~45 minutes), and cite the research for the
method rather than reproducing the instrument. Cheaper than a licence conversation, and
it lets us tune the content for a Croatian student audience, which the original was
never written for. See [09_OPEN_QUESTIONS.md](09_OPEN_QUESTIONS.md) Q-DECK.

### Delivery

- Unlocks **when every member has tapped "I'm here"** — as the transcript specifies. This
  is deliberate theatre: it converts arrival into a shared accomplishment and gives the
  group its first joint action.
- One card at a time, advanced by any member's tap, mirrored on all devices via Realtime,
  with a local fallback to the deterministic sequence if the connection drops.
- A visible, gentle pace hint (~4 min/card) — never a countdown clock. A timer turns a
  conversation into a task.
- The deck is explicitly *a template, not a rule*: the first screen says so in one line.
  Groups that abandon it for their own conversation have succeeded, not failed, and the
  app should say that too.

---

## 4. What every activity gets from the platform

Shared, not re-implemented per activity:

| Capability | Where |
| --- | --- |
| Reveal screen: map pin, walking time, sigil, names, "what happens" | platform |
| **The rules screen** — no dating/advances in a friend hangout, stated plainly (transcript, explicit) | platform, shown at confirmation **and** at reveal |
| First-arriver job ("take the bench facing the river; the others will find you") | platform, per meeting point |
| Arrival taps + peer attestation + late/dip reporting inside the 30-minute window | platform |
| End-of-hangout prompt → ratings | platform |

**Why the rules screen appears twice:** once at confirmation (before the day is
committed, when opting out is free) and once at reveal (when it is about to matter).
Stating a norm once, at signup, is how norms fail to exist.
