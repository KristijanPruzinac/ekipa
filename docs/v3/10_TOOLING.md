# 10 — Tooling: MCPs, packages, dev environment

The transcript asks explicitly: *"Suggest mcps i could add that will help you design
properly. You must suggest."*

The filter I applied: an MCP earns its place only if it removes a category of error I
would otherwise make from stale memory or blind guessing. MCPs that merely re-expose what
Claude Code already has (files, shell, search) cost context and add nothing.

---

## 1. MCP servers — configured in `.mcp.json`

All four are declared in the repo's `.mcp.json`, so they travel with the project rather
than living in someone's personal Claude settings. Each needs approving once per machine.

### 1.1 Supabase MCP — *configured, not yet authorised*
Hosted, currently pointed at project `synezcumbimkztiatqjm`. Two caveats:

1. It needs an OAuth grant in an **interactive** session (`/mcp`, or the claude.ai
   connector settings). Until that happens I read `supabase/migrations/*.sql` instead.
2. That `project_ref` is the **abandoned v2 project** (Q-PROJECT). Repoint the URL the day
   the fresh project exists — before then, an authorised connection points at the wrong
   database, which is worse than no connection.

**Buys:** applying and verifying migrations, `get_advisors` security/performance passes
(the v1 project caught real RLS and index problems this way), log queries when a trigger
misbehaves, branch databases for schema experiments.

### 1.2 Appium MCP — real-device / emulator control
`npx -y appium-mcp@latest` · npm `appium-mcp` · needs `ANDROID_HOME` and a JDK
(Android Studio's bundled `jbr` is used).

**Buys:** the loop that is otherwise impossible for me — build the app, drive it on an
emulator, screenshot it, and *look at what I built*. Roughly 40 tools: session lifecycle,
element finding, gestures, screenshots, page source, app install/launch.

**What it is for here, specifically:** (a) closing the design loop, so a screen is judged
from a screenshot rather than from my description of it; (b) the arrival/confirmation
flows, which are timing- and permission-dependent and cannot be verified in a widget test;
(c) golden screenshots per phase, so a restyle that breaks a screen is visible in a diff.

**What it is not for:** it is not a substitute for widget and unit tests. Device
automation is slow and flaky; it verifies *integration and appearance*, never rules.

### 1.3 UI/UX Pro — design pattern and token corpus
`npx -y ui-ux-pro-mcp --stdio` · MIT · local CSV corpus, no API key, no network.

**Buys:** ~1,500 catalogued UI styles, colour palettes, typography pairings, icon sets and
UX guidelines, queryable as tools (`search_ui_styles`, `search_colors`,
`search_typography`, `search_ux_guidelines`, `get_design_system`, …).

**Why it earns its place:** the design direction for v3 is being built from scratch, and
the failure mode of an AI-authored design system is a plausible-looking palette with no
contrast discipline and type sizes that do not form a scale. A queryable corpus turns
"pick a colour" into "pick from a set that has already been checked", and gives us a
shared vocabulary to argue about a direction *before* any Flutter code is written.

**Caveat, stated honestly:** it is an unofficial community package. It is a read-only
knowledge source, so its blast radius is limited to bad advice — but it is not an
authority, and its output still goes through the accessibility checks in §7 below.

### 1.4 Context7 — up-to-date library documentation
`npx -y @upstash/context7-mcp`

**Buys:** current API surfaces for Flutter, Riverpod, go_router, supabase_flutter,
freezed, flutter_map. My training cutoff otherwise guarantees a deprecated Riverpod or
go_router API somewhere, and that class of error is silent until compile time.

### 1.5 GitHub MCP — *not yet added*
Hosted (`https://api.githubcopilot.com/mcp/`) or the local `github-mcp-server`. Worth
adding the moment more than one phase is in flight: the roadmap becomes issues with exit
criteria, and I can read failing CI logs instead of guessing.

---

## 2. MCP servers — add when the phase arrives

| MCP | When | Buys |
| --- | --- | --- |
| **Playwright MCP** (`@playwright/mcp`) | P1, for the console | Drives the Flutter-Web master console, takes screenshots, verifies admin flows. *Caveat:* Flutter Web renders to canvas, so DOM selectors do not work — enable the semantics tree, or treat it as a screenshot tool for visual review rather than a click-through harness. |
| **Sentry MCP** (`mcp.sentry.dev`) | first real users | Crash triage from inside the session: read an issue, find the frame, fix it. |
| **Figma Dev Mode MCP** (local, Figma desktop) | if UI is designed in Figma | Pulls frames, tokens and specs directly, so `ekipa_ui` tokens match the design instead of being eyeballed from a screenshot. If design stays in reference screenshots + code, skip it. |
| **Chrome DevTools MCP** | perf work on the console | Traces, not guesses. |

---

## 2b. Code review — CodeRabbit

**Decision (2026-08-18): CodeRabbit reviews every pull request.** Config lives in
`.coderabbit.yaml` at the repo root.

**Why an external reviewer at all, when the code is written by an AI:** because the author
and the reviewer being the same model is not review, it is spell-check. CodeRabbit runs a
different architecture over 40+ static analysers and — crucially — it reads the diff
without the conversation that produced it. That is exactly the reader who notices that a
threshold was hard-coded, that a migration created a table without RLS, or that a widget
quietly acquired a business rule. Those are the mistakes this project is most likely to
make, because they are invisible to whoever just wrote them.

**The configuration is the point, not the tool.** `.coderabbit.yaml` encodes the rules
from [11_SECURITY.md §8](11_SECURITY.md) and the dependency rule as `path_instructions`,
per directory:

| Path | What the reviewer is told to refuse |
| --- | --- |
| `packages/ekipa_core/**` | any IO import, `DateTime.now()`, unseeded `Random()`, behavioural literals |
| `…/matching/**` | impurity, order-dependent iteration, hard constraints expressed as scores, unexplainable matches |
| `supabase/migrations/**` | a table without RLS in the same migration; a `security definer` function missing a caller check, `set search_path`, or revoke/grant; weakened pgTAP privacy tests |
| `services/mill/**` | a client-reachable trigger, PII in logs, non-idempotent writes |
| `apps/mobile/**` | privacy decisions in the client, business rules in widgets, rendering anyone's rating of anyone |
| `apps/console/**` | joining identity data with rating data; reveal without a reason + audit write |

**Setup:**

1. Install the GitHub App on the repository — <https://github.com/apps/coderabbitai>.
   `ekipa` is a **public** repo, so the full Pro feature set is free indefinitely.
2. Work in branches and open a PR per roadmap phase. Reviews arrive on the PR.
3. Optional, later: the CodeRabbit CLI + Claude Code plugin gives an
   implement → review → fix loop without leaving the terminal. It is **not available on
   native Windows** — it requires WSL, and no distro is installed on this machine
   (`wsl --install -d Ubuntu`). The PR path needs none of that and is the one we rely on.

**What it does not replace:** CI. Analyse, format, dependency lint, `dart test`, and pgTAP
still gate merges. CodeRabbit finds judgement errors; CI finds facts.

---

## 3. The MCP worth *building* — `ekipa-sim`

This is the recommendation I would push hardest, because it changes how the design
conversation works.

A tiny stdio MCP server (Dart or TypeScript, ~200 lines) that wraps
`tools/simulator` and the matchmaker's dry-run entry point, exposing:

| Tool | Does |
| --- | --- |
| `simulate(population, config, weeks, seed)` | runs the real matchmaker over a synthetic city, returns the metric table |
| `dry_run(snapshot_ref, config)` | runs the real matchmaker over a *live* snapshot, writes nothing, returns the plan with explanations |
| `explain(person_id, run_id)` | why this person was or was not matched — which constraint filtered them |
| `diff_config(a, b)` | metric delta between two config versions on the same population |

**Why this is worth building:** every weight in [03_MATCHMAKER.md](03_MATCHMAKER.md) is
currently an argument between two people's intuitions. With this, a design question
("what happens to newcomer wait time if the cooldown goes from 2 to 3?") becomes a tool
call with a number attached, inside the same conversation where the decision is made. It
also becomes your permanent regression harness and the console's dry-run backend — so it
is not throwaway tooling, it is a product component with an MCP face.

**Cost:** roughly a day once the simulator exists (P4, or earlier if we want it for
tuning during P2).

---

## 4. MCPs deliberately *not* suggested

| Skipped | Why |
| --- | --- |
| Filesystem / shell MCPs | Claude Code already has native file and shell tools; adding these duplicates capability and burns context. |
| "Memory" / knowledge-graph MCPs | This repo's memory is `docs/v3/` under version control. A second, invisible memory that disagrees with the docs is a liability. |
| Sequential-thinking MCP | Adds ceremony, not capability. |
| Generic web-search MCPs | Native `WebSearch`/`WebFetch` already cover this. |
| Google Maps MCP | We are standardising on OSM/Overpass for licensing reasons ([05_PLACES.md](05_PLACES.md)); pulling Google data into the catalogue creates a terms problem, not a capability. |

---

## 5. Flutter / Dart package choices (with the reason)

| Concern | Choice | Why this one |
| --- | --- | --- |
| State + DI | `flutter_riverpod` + `riverpod_generator` | compile-safe DI, first-class test overrides, modelled async state |
| Routing | `go_router` (typed routes) | declarative guards driven by one session state machine |
| Immutable models | `freezed` + `json_serializable` | value equality and exhaustive `switch` over sealed unions; DTOs stay out of the domain |
| Backend client | `supabase_flutter` | Auth + PostgREST + Realtime in one, RLS-aware |
| Maps | `flutter_map` + OSM/MapTiler tiles | licence-consistent with the venue catalogue; no Google Maps SDK billing or terms coupling |
| Push | `firebase_messaging` | FCM covers Android and iOS-via-APNs with one integration |
| Location | `geolocator` + `permission_handler` | one-shot coarse fix only; never background |
| Local secrets | `flutter_secure_storage` | session tokens |
| Property tests | `glados` | property-based testing in Dart — the technique the matchmaker needs |
| Fakes | `mocktail` | no codegen, readable failures |
| Golden tests | `alchemist` or `golden_toolkit` | deterministic goldens in CI |
| Monorepo | Dart pub workspaces (+ `melos` if needed) | one `dart test` across all packages in CI |
| Lints | `very_good_analysis` + a custom dependency-rule lint | the dependency rule must be machine-enforced, not cultural |
| Backend jobs | plain Dart + `postgres` / `supabase` package on Cloud Run | no framework needed for a stateless worker |
| DB tests | `pgTAP` via Supabase CLI | RLS invariants proven, not reviewed |

**Not chosen, and why:** `bloc` (fine, heavier DI story), `get_it` (runtime service
location hides missing dependencies until runtime), `injectable` (unnecessary with
Riverpod), `google_maps_flutter` (licence coupling), `drift`/`isar` at P0 (a local DB
before a measured need buys sync bugs).

---

## 6. Dev environment

- **FVM** to pin the Flutter version; CI and local must match or goldens fight forever.
- **Supabase CLI** for local Postgres + migrations + pgTAP, so schema work does not touch
  a shared project.
- **CI (GitHub Actions):** analyse → format check → dependency lint → `dart test` across
  the workspace → pgTAP against a local Supabase → build Android; iOS build on a macOS
  runner once Q-BUILD is answered.
- **Coverage floor on `ekipa_core` only** (start at 80%). Coverage targets on UI code
  produce tests written for the metric; coverage on pure policy code is meaningful.
