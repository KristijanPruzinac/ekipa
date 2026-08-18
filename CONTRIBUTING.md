# Contributing

`docs/v3/` is canonical. If code and a document disagree, the document is right
until it is amended, and amendments are appended to
[`docs/v3/00_BIBLE.md`](docs/v3/00_BIBLE.md) with a date and a reason.

---

## The twelve hard rules

From [`docs/v3/11_SECURITY.md`](docs/v3/11_SECURITY.md) §8. These are **refusal
conditions**: if a change requires one of them, the change is wrong, not the rule.

They exist because most of this codebase is written quickly, by an AI, and speed
is exactly how these mistakes happen.

1. **Never write a query that bypasses RLS.** No service-role client in app or
   console code.
2. **Never create a table without RLS in the same migration.**
3. **Never create a `security definer` function** without (a) a caller check as
   the first statement, (b) `set search_path = public`, and (c) an explicit
   revoke/grant.
4. **Never return another user's row from an RPC** without a membership check,
   and a time-window check where one applies.
5. **Never log, print, or send to analytics**: names, identity hashes, anchors,
   ratings, reports, standing.
6. **Never move a privacy or trust decision into the client.** If the UI hides
   it, the server must also refuse it.
7. **Never add a behavioural constant as a literal** — it is a config key (D5).
8. **Never add a package** without the written justification in rule SC-2 below.
9. **Never weaken a pgTAP privacy test to make a feature pass.** The test is the
   spec.
10. **Never write a migration that drops or alters a trust or audit table**
    without an explicit instruction. Infractions, sanctions, reports and event
    logs are evidence.
11. **Never let free text reach** the matcher, a notification body, or a display
    name.
12. **When uncertain whether something leaks, assume it leaks and ask.**

Rules 1–4, 7 and 8 have mechanical checks. The rest are stated here so there is
something to point at in review.

---

## What CI enforces

| Gate | Command | Catches |
| --- | --- | --- |
| Format | `dart format --set-exit-if-changed .` | diff noise |
| Analyse | `flutter analyze` | warnings, as errors |
| **Dependency rule** | `dart run tools/lint/bin/dependency_lint.dart` | the eleven rules below |
| Tests | `dart test` / `flutter test` per package | behaviour |
| Coverage floor | 80% on `ekipa_core` only | untested policy |

### The dependency rules

Defined and tested in [`tools/lint/`](tools/lint/). Each rule carries the failure
it prevents; read that before working around one.

| ID | Refuses |
| --- | --- |
| `NO-LEGACY-IMPORT` | anything outside `legacy/` importing it (D1) |
| `CORE-NO-FLUTTER` | Flutter in the pure core |
| `CORE-NO-IO` | `dart:io`/`html`/`js`/`ffi`/`isolate` in the pure core |
| `CORE-NO-BACKEND` | a backend client in the pure core |
| `CORE-NO-WALL-CLOCK` | `DateTime.now()` in the pure core — inject a `Clock` |
| `CORE-NO-UNSEEDED-RANDOM` | `Random()` without a seed — use `RandomSource` |
| `CORE-NO-PRINT` | printing from the pure core |
| `MOBILE-NO-MATCHING` | `package:ekipa_core/matching.dart` in a user build (D9) |
| `MOBILE-NO-SERVICE-ROLE` | the service-role credential in a user build |
| `CONSOLE-NO-SERVICE-ROLE` | the service-role credential in the browser (AC-4) |
| `PLATFORM-BRANCH-CONFINED` | `Platform.is*` outside `apps/mobile/lib/platform/` |

Adding a rule means adding a test that proves it fires. `rules_test.dart` asserts
that the rule table and the tested-rule set are equal, so a rule without a test
fails the build.

---

## Adding a dependency (SC-2)

A new package needs a written justification **in the pull request**: what it does,
why the standard library will not do, its maintenance status, and its transitive
count. AI-written code adds packages casually; this is the brake.

`ekipa_core` has none, and the bar for its first one is very high — every
dependency there is compiled into four runtimes.

---

## Working shape

- Branch per chunk, one pull request each. **CodeRabbit reviews every PR**
  ([`.coderabbit.yaml`](.coderabbit.yaml)) — a reader who did not have the
  conversation that produced the diff is the one who notices a hard-coded
  threshold or a table without RLS.
- State the **intention** and the **rejected alternative** for anything
  structural (D7). A decision without a discarded option is not a decision, it is
  a default nobody examined.
- Vocabulary is binding ([`docs/v3/02_DOMAIN.md`](docs/v3/02_DOMAIN.md) §1). If
  the code says `meetup`, the code is wrong.
