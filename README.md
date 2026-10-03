# WagZ — We Are Gen Z

A movement, starting with a simple way to find upcoming events in Osijek.

This v1 collects public event sources, keeps their evidence links, merges exact duplicates, and gives the owner an inbox for community tips and incomplete imports. Matching and dating are deferred.

## Run locally

Requires Node.js 24 or newer.

```powershell
npm ci
npm run admin-key
npm run dev
```

Open <http://127.0.0.1:3000>. The admin screen is at `/admin`; copy the `WAGZ_ADMIN_KEY` value from your local `.env`. The key is never printed or included in the browser build. Generating it again rotates access; restart the app afterwards.

Add an `OPENROUTER_API_KEY` to `.env` to enable AI. Set a **$1 monthly limit on this dedicated key in OpenRouter**, as well as the application's default $1 budget. No key means no paid calls. See [AI configuration](docs/AI.md).

Jina Reader is the fetching API. Anonymous basic fetching requires no key. Source pages are cached and unchanged AI inputs reuse previous results. Exact facts in structured source pages can be extracted without spending AI tokens. See [sources and coverage](docs/SOURCES.md).

```powershell
npm run check
npm test
npm run build
npm start
```

`npm run test:browser` checks the public-to-inbox-to-publication flow and mobile layout in an isolated database copy. It uses an installed Chrome on Windows, or Playwright Chromium (`npx playwright install chromium`). Run the build first. Screenshots go under `.artifacts/`; test submissions never enter the app database.

`npm run collect` performs a collection run from the terminal. Use it while the app is stopped; the v1 server is intended to run as a **single process** with a local persistent SQLite database. The app otherwise collects on startup and every six hours while running. It is not yet hosted; closing the process stops its schedule.

## What v1 does

- Public event list with date/category/search filters, details and source links.
- Dates follow `Europe/Zagreb`. Missing times and prices remain unknown.
- Source-backed imports with a title, valid date and venue can publish automatically. Incomplete imports can publish when their missing facts arrive. An operator's decision to hold or reject an event always survives re-fetching; drafts collected with the toggle off stay held.
- Repeated collection updates existing source records. Exact cross-source matches share an event; different performances remain separate. Human edits and publication decisions survive refetching.
- Source failures remain visible. Events never disappear just because an upstream site failed or removed a listing; explicit cancellation data can update their status.
- Tips are durable before processing. Obvious spam is archived, with restore available. Uncertain tips remain in the inbox. Source lookup and optional OpenRouter help prepare drafts. An operator approves publication.
- AI output is untrusted input. Invalid dates or fields are rejected, missing evidence stays unverified, and no AI tip publishes itself.

## Local data and deployment boundary

`data/` contains the SQLite database, fetching cache and AI usage accounting. It is intentionally excluded from Git. Back it up separately before moving machines. Do not delete it to restart the app: doing so loses saved events, tips and local usage accounting.

This is a local pilot with a shared admin key, no user accounts, and a simple per-process tip limit. Before public hosting, supply HTTPS, durable storage, a scheduled always-on process, proper operator sign-in, and a deployment-specific abuse limit. Nothing has been deployed or connected to the old Supabase database.

## Project history

The old Ekipa project is preserved at tag `milestone/ekipa-before-wagz` (commit `99445bb`). Commit `35e5159` clears the old implementation. The old product specifications are historical, not WagZ requirements.

To inspect the milestone without changing this checkout:

```powershell
git worktree add ../ekipa-milestone milestone/ekipa-before-wagz
```

Decisions and v1 acceptance criteria: [product brief](docs/PRODUCT.md).
