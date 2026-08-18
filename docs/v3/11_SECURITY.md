# 11 — Security framework

Directives **D9** (the matchmaker is unreachable) and **D13** (rigid framework, not
intentions).

This document is written to be **checkable**. Every control has an ID, an implementation,
a verification method, and a phase. A control without a verification method is an
intention, and intentions are what get skipped at 2am before a release.

---

## 1. Threat model — who actually attacks this

Not "hackers" in the abstract. Named adversaries, ranked by likelihood × damage:

| # | Adversary | Wants | Damage if they win |
| --- | --- | --- | --- |
| T1 | **A curious user with a proxy** (Burp, mitmproxy on their own phone) | To read other people's ratings, see who declined, find who rated them badly | **Product-ending.** The entire mechanism rests on ratings being unknowable. One screenshot of "here's what they really said about you" circulating in Osijek ends it. |
| T2 | **A stalker / obsessive** | To locate one specific person: their anchor, their slots, their next hangout | Physical danger to a user. The single worst outcome the system can produce. |
| T3 | **A banned user** | To get back in | Erodes every sanction; the trust system becomes theatre. |
| T4 | **A scraper** | The whole user base — who is on the app, gender ratio, names | Reputational; also enables T2 at scale. |
| T5 | **A client tamperer** | To fake arrivals, skip the rating gate, forge confirmations, self-boost in matching | Corrupts the graph and the trust system silently — the worst kind of failure because nothing looks broken. |
| T6 | **Database compromise** (leaked service key, misconfigured backup) | Everything | Regulatory + total loss of trust. |
| T7 | **Console compromise** (my laptop, my session, a weak admin password) | Ban people, unban themselves, read everything, change matching | Full system control. The console is the crown jewel and must be treated as such. |
| T8 | **Supply chain** (a malicious or hijacked pub/npm package) | Exfiltrate tokens, inject code | Silent, hard to detect, increasingly common. |
| T9 | **Report-system abuser** | To get someone banned, or to shield themselves | Covered by [04_TRUST.md](04_TRUST.md), listed here because it is a security control, not just a product rule. |

**Design consequence:** T1, T2 and T5 are all "the client is hostile" problems, and they
are the most likely. So the cardinal rule below is not paranoia — it is where the actual
risk is.

---

## 2. The cardinal rule: the client is a hostile display surface

> **Everything the app sends is a claim by an attacker who happens to be a user. Nothing
> the app displays is a permission. The server decides everything; the client renders.**

Concretely, the following are **claims**, not facts, and each has a server-side check:

| Client says | Server verifies |
| --- | --- |
| "I arrived" | Hangout is in `LIVE`, caller is a member, within the arrival window, and (if provided) the proximity assertion is server-evaluated against the venue — not a client-computed boolean |
| "I confirm" | Deadline not passed, hangout in `CONFIRMING`, caller is a member |
| "Here are my ratings" | Hangout is `RATING`, caller attended, subjects attended, one submission per pair, dwell timing is a *hint* only |
| "Mark X as absent" | Caller is a member, X is a member, inside the report window |
| "This is my availability" | Slot exists, is in the future, belongs to caller's city |
| "My standing is fine" | Never asked. Standing is server-side only and never round-trips |

**Dwell time and any client-measured timing is advisory.** It can be forged trivially. It
feeds a down-weighting heuristic, never a sanction on its own ([04_TRUST.md](04_TRUST.md)).

---

## 3. Trust boundaries — and why the matchmaker is unreachable (D9)

```
  ZONE 0 — HOSTILE                ZONE 1 — GUARDED                ZONE 2 — ISOLATED
 ┌────────────────────┐         ┌──────────────────────┐       ┌────────────────────────┐
 │  The user's phone  │  HTTPS  │  Postgres + RLS      │       │  services/mill         │
 │  · app binary      │ ──────► │  · PostgREST (RLS)   │ ◄──── │  · matchmaker          │
 │  · anything they   │  anon/  │  · RPC allowlist     │ svc   │  · sweeper             │
 │    can patch       │  authed │  · Realtime (RLS)    │ role  │  · venue ingest        │
 └────────────────────┘         └──────────────────────┘       │  NO inbound public port│
                                          ▲                    └────────────────────────┘
                                          │ separate auth, separate app, audited
                                ┌─────────┴────────────┐
                                │ apps/console (admin) │  ZONE 1.5 — PRIVILEGED
                                └──────────────────────┘
```

**Zone 2 has no user-reachable surface. This is structural, not a policy:**

1. **No public ingress.** The worker runs on Cloud Run with ingress restricted to internal
   + Cloud Scheduler, and the scheduler authenticates with an OIDC token. There is no URL
   a user can hit, authenticated or not. *Preferred alternative if we want zero exposed
   endpoints at all: the worker polls on a timer with no HTTP server whatsoever.*
2. **No client path invokes matching.** There is no RPC, no table write, and no realtime
   channel that causes a match run. Matching is time-triggered only.
3. **The service-role key exists in exactly one place** — the worker's secret manager.
   It is never in a Flutter build, never in `--dart-define`, never in the console client
   (the console calls audited RPCs, it does not hold the key), never in CI logs, never in
   this repo. A build that contains it fails CI (secret scanning).
4. **The matchmaker never reads user input directly.** It reads validated domain rows.
   There is no free text in the system at all except report notes, which the matcher never
   touches. This removes an entire injection class by construction.
5. **The matcher's outputs are written through one transactional RPC** that re-validates
   invariants server-side. Even a compromised worker cannot create a hangout that violates
   exclusions, because the RPC checks them again inside the transaction.
6. **Nothing about matching is discoverable from the client.** No score, no slot role, no
   template, no "why you were matched". A user cannot learn the algorithm's opinion of
   them, which is both a privacy control and an anti-gaming control.

**Why the Dart worker still satisfies "on the backend":** the language is not the security
boundary — the network topology and credential isolation are. The worker is backend
infrastructure that happens to be written in Dart so it can share the pure algorithm
package with the app's *tests*, not with the app's *binary*. `ekipa_core` compiled into
the app contains no matching code: the matcher lives in `ekipa_core/matching/`, which is a
separate library target that the mobile app does not import, and a CI rule enforces that.

---

## 4. Data-plane rules (Zone 1)

| ID | Control | Implementation | Verified by |
| --- | --- | --- | --- |
| DP-1 | **RLS on every table, no exceptions** | `alter table … enable row level security` in the same migration that creates the table | CI migration lint: a `create table` without a matching `enable row level security` fails the build |
| DP-2 | **Deny by default** | No permissive `using (true)` policy anywhere | pgTAP: anonymous and non-member roles get 0 rows from every table |
| DP-3 | **Sensitive tables are read-only or invisible to clients** | `ratings`, `reports`, `infractions`, `sanctions`, `standing`, `edges`, `match_runs`: **no client SELECT at all**; writes only via RPC | pgTAP per table |
| DP-4 | **Writes that carry consequences go through RPCs**, never PostgREST table writes | confirm, arrive, rate, report, set-availability | pgTAP: direct table `UPDATE` as `authenticated` is denied |
| DP-5 | **Every `security definer` function checks the caller** and is revoked from `anon` | explicit `auth.uid()` membership check as the first statement; `revoke execute … from anon, authenticated` then grant only where intended | CI: a `security definer` function without both a caller check and an explicit grant statement fails review; pgTAP calls each as `anon` |
| DP-6 | **Grants are revoked from role names, not `PUBLIC`** | the v1 lesson: Supabase writes per-role ACL entries, so `revoke … from public` is a silent no-op | pgTAP asserts `proacl` contents |
| DP-7 | **No cross-user reads outside the reveal window** | reveal-gated RPC returns names only inside T−60m and only to members | pgTAP with a frozen clock |
| DP-8 | **Aggregates that could de-anonymise are suppressed** | slot-demand indicator returns coarse buckets, never counts below a k-anonymity floor (k≥5) | unit test on the bucketing function |
| DP-9 | **Rate limits on every client RPC** | per-user token bucket in Postgres; hard caps on report submission and availability churn | integration test |
| DP-10 | **Advisor pass before every release** | Supabase `get_advisors` security + performance | release checklist, recorded in the PR |

**The seven privacy invariants** in [02_DOMAIN.md §6](02_DOMAIN.md) are the acceptance
criteria for this whole section, and each has a named pgTAP test. **A release that fails
one does not ship**, regardless of what else is in it.

---

## 5. Identity, session, and the ban-evasion boundary

| ID | Control |
| --- | --- |
| ID-1 | Identity hash = `HMAC-SHA256(pepper, provider ‖ subject)`; **pepper in a KMS**, never in Postgres, rotatable with a versioned hash column |
| ID-2 | Unique index on the hash: one human, one account. Deleting an account keeps the hash + sanction record and nothing else — disclosed in the privacy policy |
| ID-3 | Short-lived access tokens + refresh in `flutter_secure_storage` (Keychain / Keystore); no token in shared prefs, logs, or crash reports |
| ID-4 | Sign-out revokes server-side, not just locally |
| ID-5 | Device binding: a push token belongs to a device row; a new device on an existing identity is fine, but a *rapid* device/identity churn pattern is an abuse signal |
| ID-6 | 18+ enforced at verification time from a provider-asserted attribute where available; self-declared date of birth is a weak fallback and is recorded as such |

---

## 6. Client hardening (MASVS-mapped)

The client cannot be trusted (§2), so hardening is about **raising cost**, not creating
guarantees. Each control names what it actually buys.

| ID | Control | Buys | MASVS |
| --- | --- | --- | --- |
| CL-1 | `flutter build --obfuscate --split-debug-info` on release | Slows static analysis of our API shape. Not protection. | MASVS-RESILIENCE |
| CL-2 | No secrets in the binary — anon key only, which is designed to be public **because RLS is the real control** | Removes the highest-value binary target | MASVS-STORAGE |
| CL-3 | TLS only; **certificate pinning to the Supabase host** with a backup pin and a remote kill switch | Defeats casual proxy inspection (T1) | MASVS-NETWORK |
| CL-4 | No sensitive data at rest on device beyond the session token; no local cache of other people's names after a hangout closes | Limits loss on a stolen phone | MASVS-STORAGE |
| CL-5 | Screenshot/recording flag on the reveal + ratings screens (`FLAG_SECURE` on Android; iOS best-effort) | Raises cost of the "here's what they said" screenshot | MASVS-PLATFORM |
| CL-6 | Root/jailbreak signal reported to the server as **telemetry, not a gate** | Feeds abuse scoring; blocking outright annoys legitimate power users and is trivially bypassed | MASVS-RESILIENCE |
| CL-7 | No deep link accepts a domain object or an id that grants access; all deep links resolve server-side under RLS | Kills forced-browsing via links | MASVS-PLATFORM |
| CL-8 | No PII in logs, analytics, or crash reports; Sentry scrubbing configured and tested | Prevents third-party leakage | MASVS-PRIVACY |
| CL-9 | Permissions requested at point of use with honest purpose strings; location is one-shot coarse only | Store compliance + user trust | MASVS-PRIVACY |
| CL-10 | No WebViews, no dynamic code loading, no JS bridges | Removes an entire vulnerability class | MASVS-PLATFORM / CODE |

---

## 7. Supply chain and CI (T8)

| ID | Control |
| --- | --- |
| SC-1 | Lockfiles committed; dependency updates are separate, reviewed PRs |
| SC-2 | **A new dependency requires a written justification** in the PR: what it does, why not stdlib, maintenance status, transitive count. AI-written code adds packages casually; this is the brake |
| SC-3 | Automated vulnerability scan on every PR (`dart pub audit` / OSV / Dependabot) |
| SC-4 | Secret scanning (gitleaks) on every push; a hit fails the build |
| SC-5 | Static analysis gate: `very_good_analysis` + custom lints, warnings are errors |
| SC-6 | **Dependency-rule lint**: `ekipa_core` imports no Flutter/IO; the mobile app imports no `matching/` library; the console imports no service-role client |
| SC-7 | Signing keys in CI secrets only; release builds reproducible from a tag |
| SC-8 | MobSF (or equivalent) scan on release artifacts, at least per store release |

---

## 8. Hard rules for AI-written code

This section exists because most of this codebase will be written by me, quickly, and
speed is exactly how these mistakes happen. These are **refusal conditions**: if a change
requires one of these, the change is wrong, not the rule.

1. **Never write a query that bypasses RLS.** No service-role client in app or console code.
2. **Never create a table without RLS in the same migration.**
3. **Never create a `security definer` function without (a) a caller check as the first
   statement, (b) `set search_path = public`, and (c) explicit revoke/grant.**
4. **Never return another user's row from an RPC without a membership check and a
   time-window check where one applies.**
5. **Never log, print, or send to analytics: names, identity hashes, anchors, ratings,
   reports, standing.**
6. **Never move a privacy or trust decision into the client.** If the UI hides it, the
   server must also refuse it.
7. **Never add a behavioural constant as a literal** — it is a config key (D5).
8. **Never add a package without SC-2's justification.**
9. **Never weaken a pgTAP privacy test to make a feature pass.** The test is the spec.
10. **Never write a migration that drops or alters a trust/audit table without an explicit
    instruction** — infractions, sanctions, reports and event logs are evidence.
11. **Never let free text reach the matcher, the notification body, or a display name.**
12. **When uncertain whether something leaks, assume it leaks and ask.**

Each of 1–4, 7 and 8 has a mechanical check in CI; the rest are review rules stated here
so there is something to point at.

---

## 9. Monitoring and abuse detection

- Anomaly alerts on: report rate per city, no-show rate, new-account rate per identity
  provider, RPC error/denial spikes (someone probing RLS), unusual availability churn.
- **A spike in RLS denials is a security event**, not noise — it is what T1 looks like.
- Console shows a security tab: recent denials, rate-limit hits, device churn outliers.
- Structured audit log for every privileged action (console, worker, RPC), append-only.

## 10. Incident response

Written before launch, because the middle of an incident is the worst time to design one:
who is contacted, how the app is put into a safe mode (matching paused, hangouts
cancelled with notice), how users are told, what regulator/notification duties apply
(GDPR: 72 hours for a personal-data breach), and what evidence is preserved. One page,
rehearsed once.

---

## 11. The reference checklist

The standards this project holds itself to, and what each is for:

| Resource | Use it for |
| --- | --- |
| [OWASP MASVS](https://mas.owasp.org/MASVS/) — v2.1.0, 8 categories (STORAGE, CRYPTO, AUTH, NETWORK, PLATFORM, CODE, RESILIENCE, PRIVACY) | **The requirement list.** §6 above maps to it; the gaps are the backlog. |
| [OWASP MASTG](https://mas.owasp.org/MASTG/) — v2.0 (June 2026), machine-readable, 860+ components mapped to MASVS controls | **How to verify each control**, per platform. This is the test procedure, not reading material. |
| [OWASP Mobile Top 10 (2024)](https://owasp.org/www-project-mobile-top-10/) — improper credential usage, inadequate supply-chain security, insecure auth/authz, insufficient input/output validation, insecure communication, inadequate privacy controls, insufficient binary protection, security misconfiguration, insecure data storage, insufficient cryptography | **The prioritisation.** If a control maps to nothing here, it is probably not urgent. |
| [Supabase RLS + production guidance](https://supabase.com/docs/guides/database/postgres/row-level-security) and the built-in advisors | The data plane; run advisors every release |
| [Flutter obfuscation docs](https://docs.flutter.dev/deployment/obfuscate) | CL-1 |
| MobSF (open-source mobile scanner) | SC-8 |
| [Google Play data safety](https://support.google.com/googleplay/android-developer/answer/10787469) · [Apple privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files) | Store declarations must match §4's data classification exactly |

**How this gets used, not just cited:** at each phase exit, we walk the MASVS category
list and record, per control, *implemented / not applicable / deferred with a date*. That
record lives in the PR. A deferred control with no date is not deferred, it is forgotten.

---

## 12. Phasing (security is not a phase, but some of it needs an order)

| Phase | Security work that must land in it |
| --- | --- |
| **P0** | RLS-by-default migration lint, pgTAP harness, secret scanning, dependency lint, no-service-key-in-client rule, §8 written into `CONTRIBUTING` |
| **P1** | Identity + pepper in KMS, token handling, rate limits, purpose strings |
| **P2** | The seven privacy invariants tested, RPC allowlist complete, worker isolation as described in §3, cert pinning, `FLAG_SECURE` |
| **P3** | Abuse monitoring, audit log, console access control + MFA |
| **P4+** | MobSF in release pipeline, incident-response rehearsal, external review before any significant growth |
