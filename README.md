# WagZ — We Are Gen Z

A movement, starting with a simple way to find upcoming events in Osijek.

Live pilot: <https://wagz.com.hr>. Owner inbox: <https://wagz.com.hr/ured-231b67e86427>.

Custom-domain canonical/share/sitemap URLs were deployed and verified at 09:51 Zagreb on 3 October 2026. Some resolver caches are still propagating; <https://wagz.vercel.app> and its API remain available without an old-host redirect. See the [domain activation record](docs/DOMAIN-SETUP.md).

This v1 collects public event sources, keeps their evidence links, merges exact duplicates, and gives the owner an inbox for community tips and incomplete imports. Matching and dating are deferred.

## Run locally

Requires Node.js 24.

```powershell
npm ci
npm run admin-key
npm run dev
```

Open <http://127.0.0.1:3000>. The admin screen is at `/ured-231b67e86427`; copy the `WAGZ_ADMIN_KEY` value from your local `.env`. The key is never printed or included in the browser build. Generating it again rotates access; restart the app afterwards.

Add an `OPENROUTER_API_KEY` to `.env` to enable AI. Set a **$1 monthly limit on this dedicated key in OpenRouter**, as well as the application's default $1 budget. No key means no paid calls. See [AI configuration](docs/AI.md).

Jina Reader is the fetching API. Anonymous basic fetching requires no key. Source pages are cached and unchanged AI inputs reuse previous results. Exact facts in structured source pages can be extracted without spending AI tokens. See [sources and coverage](docs/SOURCES.md).

```powershell
npm run check
npm test
npm run build
npm start
```

`npm run test:browser` checks the public-to-inbox-to-publication flow and mobile layout in an isolated database copy. It uses an installed Chrome on Windows, or Playwright Chromium (`npx playwright install chromium`). Run the build first. Screenshots go under `.artifacts/`; test submissions never enter the app database.

`npm run test:discovery` checks chronological discovery, activity filters, absence of audience tags, retained source descriptions and narrow-screen layouts with isolated fixtures.

`npm run test:review` uses real captured source events in an in-memory database to check submission, background refresh, preparation feedback, incomplete saves, concurrent review conflicts, source-preserving approval, duplicate prevention, archive/restore and 320px layouts. It also verifies that an actual past performance can be saved but cannot publish as upcoming. Run the build first; the server clock is fixed to the fixture capture date (2026-10-03), and no production database or paid AI is used. Reports and screenshots go under `.artifacts/review-*`.

Run `npm run test:review -- --dev` to repeat these checks with React StrictMode, including modal Back/Forward, rapid close/reopen, focus restoration and keyboard navigation.

`npm run collect` performs a collection run from the terminal. Local development uses SQLite; the hosted API and scheduled collector share Neon Postgres through `DATABASE_URL`. **Hosted collection runs Tuesday and Friday at 18:00 Europe/Zagreb**, with automatic daylight-saving adjustment and manual refresh available in the admin screen or GitHub Actions. Two UTC cron entries are gated before dependency installation so only the seasonal slot collects; delayed jobs still run. The public health check permits 108 hours between successful source checks, covering the four-day Friday-to-Tuesday gap. This schedule applies to hosted collection only: the local development server still collects on startup and every 24 hours while running by default (`WAGZ_FETCH_INTERVAL_MINUTES=1440`); set `WAGZ_FETCH_ON_START=false` to disable its startup collection.

## What v1 does

- Public event cards with pastel category illustrations, a single chronological timeline with colored duration branches, details and source links. Known ends connect back to the spine; unknown ends stay unknown.
- All events stay chronological. Single-select activity filters show present categories with counts and apply to cards, ongoing events and the timeline together. Audience labels and controls are hidden; original event descriptions and source data remain intact.
- A Flutter Android/iOS client uses the same public API. See [mobile setup and Android builds](apps/mobile/README.md).
- Dates follow `Europe/Zagreb`. Missing times and prices remain unknown.
- Source-backed imports with a title, valid date and venue can publish automatically. Incomplete imports can publish when their missing facts arrive. An operator's decision to hold or reject an event always survives re-fetching; drafts collected with the toggle off stay held.
- Repeated collection updates existing source records. Exact cross-source matches share an event; different performances remain separate. Human edits and publication decisions survive refetching.
- Source failures remain visible. Events never disappear just because an upstream site failed or removed a listing; explicit cancellation data can update their status.
- Tips are saved immediately and checked with the daily collection, after source imports. Valid upcoming, sourced events become drafts for owner approval; completed spam/no-event/past-event checks archive with a reason and restore action. Provider, source, validation or budget failures remain queued for retry. The admin inbox separates ready drafts from queued submissions and archives; manual source checking remains available.
- AI output is untrusted input. Invalid dates or fields are rejected, missing evidence stays unverified, and no AI tip publishes itself.

## Data and hosting

`data/` contains the SQLite database, fetching cache and AI usage accounting. It is intentionally excluded from Git. Back it up separately before moving machines. Do not delete it to restart the app: doing so loses saved events, tips and local usage accounting.

The deployment uses Vercel Hobby and a fresh Neon Free database, with collection scheduled through GitHub Actions. Events, tips, settings and AI accounting persist in Postgres; collection leases and AI reservations coordinate multiple instances. The old Supabase database is not connected. See [deployment configuration](docs/DEPLOYMENT.md).

This pilot uses a shared administrator key and has no user accounts. Public tips have basic spam screening and request limits. The hosting setup does not include paid plans; review the providers' limits before expanding beyond the pilot.

## Project history

The old Ekipa project is preserved at tag `milestone/ekipa-before-wagz` (commit `99445bb`). Commit `35e5159` clears the old implementation. The old product specifications are historical, not WagZ requirements.

To inspect the milestone without changing this checkout:

```powershell
git worktree add ../ekipa-milestone milestone/ekipa-before-wagz
```

Decisions and v1 acceptance criteria: [product brief](docs/PRODUCT.md).

## Planned reviews

- [Release review queue](docs/RELEASE-QUEUE.md): access, security, reliability, SEO and accessibility checks requested for the next review; these are not completed audits.
- [Domain options](docs/DOMAIN-OPTIONS.md): dated `.hr` registration/renewal comparison, eligibility and the exact-name lookup result; no domain purchased.
