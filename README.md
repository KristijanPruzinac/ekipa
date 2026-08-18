# ekipa

Four people. Ninety minutes. A place you can both walk to.

ekipa forms small hangouts between verified students who have marked the same
90-minute window as free. A backend matchmaker builds the groups; there is no
feed, no profile, no photo, and nothing to scroll. You mark when you are free,
you get a seat, you go, and you rate the people you met — privately, and nobody
ever learns what you said.

> **Status: rebuilding.** Everything before 2026-08-18 is quarantined in
> [`legacy/`](legacy/) and is not the product. The specification set in
> [`docs/v3/`](docs/v3/) is canonical, and no code in this repository outranks it.

---

## Read in this order

| | |
| --- | --- |
| [`docs/v3/README.md`](docs/v3/README.md) | The map. Start here. |
| [`docs/v3/00_BIBLE.md`](docs/v3/00_BIBLE.md) | Founding transcripts, directives D1–D13, and the amendment log. **Canonical — nothing may contradict it.** |
| [`docs/v3/09_OPEN_QUESTIONS.md`](docs/v3/09_OPEN_QUESTIONS.md) | What is decided, what is still open, and what carries a default. |
| [`docs/v3/03_MATCHMAKER.md`](docs/v3/03_MATCHMAKER.md) | The ring draw — the single most important algorithm in the app. |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | The twelve hard rules and what CI enforces. |

## Layout

```
apps/mobile         Flutter app. Thin. Owns no rules.
apps/console        Flutter Web master console. Separate auth, no service key.
packages/ekipa_core PURE DART. Domain, policies, algorithms. No IO, no Flutter.
packages/ekipa_data Adapters: Supabase, Overpass, FCM. Implements core's ports.
packages/ekipa_ui   Design system: tokens, primitives, motion. No feature code.
services/mill       The worker. Matchmaker, sweeper, ingestion. No inbound port.
tools/simulator     Synthetic population over the real matcher. Tuning harness.
tools/lint          The dependency-rule lint. Tested, because a lint nobody has
                    watched fail is a lint that passes everything.
supabase/           Migrations, pgTAP privacy tests, seed fixtures.
legacy/             Quarantined v1/v2. Never imported. Deleted at P2 exit.
```

`ekipa_core` is consumed by four runtimes and depends on nothing. That is not
tidiness — it is what lets the matchmaker run identically in the app's tests, the
worker, the console's dry-run and the simulator, which is the only way an
algorithm nobody can eyeball gets verified before it runs on people.

## Working on it

```bash
flutter pub get                                  # resolves the whole workspace
dart run tools/lint/bin/dependency_lint.dart     # the architecture, enforced
cd packages/ekipa_core && dart test              # the part that matters
```

Requires Flutter 3.44.7 (pinned; CI and local must match or goldens fight
forever).
