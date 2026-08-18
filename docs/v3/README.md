# ekipa v3 — the specification set

Written 2026-08-18, replacing everything before it. Read in this order.

| # | Document | What it answers |
| --- | --- | --- |
| 00 | **[The Bible](00_BIBLE.md)** | Both user transcripts, verbatim. **Canonical — nothing may contradict it.** Standing directives D1–D13 and the append-only amendment log. |
| 01 | [System architecture](01_ARCHITECTURE.md) | What kind of machine this is; runtime topology; the shared pure core; the dependency rule; versioned config; deadlines; determinism; testing strategy. |
| 02 | [Domain model](02_DOMAIN.md) | Vocabulary; entities; the hangout lifecycle state machine; arrival and attestation; ratings semantics; identity, privacy invariants, schema sketch. |
| 03 | [The matchmaker](03_MATCHMAKER.md) | The pipeline, hard constraints, affinity components, group templates, assembly + local search, cooldown, the respect signal, backfill, measurement. |
| 04 | [Trust](04_TRUST.md) | Two accumulators — reliability and conduct — that never sum. Independence-weighted evidence, the R0–R5 ladder, why there is no moderation queue. |
| 05 | [Places](05_PLACES.md) | Why "areas" are dropped; anchor points; why no licensable source sells star ratings; venue **clusters as the matching unit**; meeting-point selection; sigils. |
| 06 | [Activities](06_ACTIVITIES.md) | The activity contract; cards; the conversation deck; what the platform provides. |
| 07 | [Dating](07_DATING.md) | Unlock, the compatibility constraint, frequency budgets, the *ask once* rule, the gender-imbalance mechanisms, tightened safety. |
| 08 | [Roadmap](08_ROADMAP.md) | Phases P0–P6 with exit criteria, store readiness, and what we deliberately do not build. |
| 09 | **[Open questions](09_OPEN_QUESTIONS.md)** | Decisions needed from you, gaps with proposed defaults, risks. **Start here after the Bible.** |
| 10 | [Tooling](10_TOOLING.md) | MCP servers to add, the one worth building, package choices, dev environment. |
| 11 | **[Security](11_SECURITY.md)** | Threat model, the isolation of the matchmaker, the hostile-client rule, data-plane controls, client hardening mapped to OWASP MASVS/MASTG, hard rules for AI-written code. |
| 12 | [The master console](12_CONSOLE.md) | What you can see and tune, pseudonymous-by-default analytics, the experiments framework, access control. |
| — | [Legacy audit](LEGACY_AUDIT.md) | Every pre-2026-08-18 file, its verdict, and the nine things that survive. |
| — | [UI reference](../reference/README.md) | 40 split reference frames grouped by app, and the visual direction they argue for. |

## The one-paragraph version

A person verifies an identity, marks which 90-minute slots they are free this week, and
does nothing else. A matchmaker runs nightly and forms **hangouts** of four (2+2 by
gender, or four of one gender) under hard constraints — availability, cluster
reachability, cooldown, exclusions, standing. Composition is a **draw from the person's
own network rings**: someone they already enjoyed, a friend of someone they enjoyed, or a
stranger, in a configured ratio. On the morning of, everyone confirms; a decline triggers
a one-at-a-time backfill, and if it fails the hangout runs with three or is cancelled
before anyone leaves home. An hour before, the group sees a map pin, a vetted meeting
point, and its sigil. Arrivals are peer-attested. An activity template (cards, or an
escalating conversation deck) gives the evening a shape. Afterwards everyone rates
everyone — how it felt, and whether they were respectful — mandatory, mutual-only, never
revealed. Those ratings feed the network rings, the two trust accumulators, and, once
unlocked, a separate dating layer where opted-in adults may ask each other out in person
under one rule: **you may ask, ask once, then take the answer.**

## The three rules that constrain every future feature

1. **Nobody may ever infer how anyone rated them** — not from a screen, not from a
   notification, and not from the pattern of who they are matched with.
2. **Nothing behavioural is a literal in code.** If it could reasonably change next
   month, it is a versioned config value, and the version is recorded on whatever it
   affected.
3. **Automation adjudicates; humans calibrate and hear appeals** (D10). There is no
   per-case moderation queue. Evidence weight comes from *independence*, not count, and
   nothing above a silent throttle may fire from a single hangout.
