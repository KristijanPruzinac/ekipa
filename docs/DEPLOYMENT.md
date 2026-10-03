# WagZ hosting

The public web client and API use **Vercel Hobby**, with a fresh **Neon Free** Postgres database in Frankfurt. The Flutter client calls the same HTTPS API. Source data, event edits, tips, settings, extraction cache and AI charges persist in `public.wagz_*` tables. The historical Ekipa database is not used.

Canonical production origin: <https://wagz.com.hr>. The operator inbox for this release is `/ured-231b67e86427` (the `ADMIN_PATH` constant); bookmark the direct address. `/admin` and `/admin/` return 404 without redirecting. The existing <https://wagz.vercel.app> homepage/API remain available during DNS propagation; the current Android APK continues to use that HTTPS API origin.

**Domain activation, 3 October 2026:** the parent zone delegates `wagz.com.hr` to Vercel and both hostname configuration checks pass. Strict HTTPS checks using Google DNS answers passed at 09:44 Zagreb. Release `7d9dd21` deployed custom canonical/share/sitemap URLs and passed the live matrix at **09:51**: both apex and legacy homepage/detail return 200, the feed has 23 events, all 24 sitemap URLs use the custom origin, editor pages remain noindex and anonymous admin API reads return 401. `www` returns a path/query-preserving 308 to the apex. Local/default and Cloudflare resolver caches still failed at the latest 09:45 check, so old public-page redirects stay disabled and the existing homepage/API continue working. The Google verification TXT is public on both authorities and `8.8.8.8` as of 09:48; owner-side Search Console Verify/sitemap submission remain incomplete. Evidence: `.artifacts/domain-launch-report.json`; deployment `dpl_3bFRNAeGPqx1wHGZG5WJDodcTmej`. The [domain setup record](DOMAIN-SETUP.md) separates current facts from earlier failed lookups. Hosting remains Vercel + Neon; Railway is a possible later alternative, not a decided migration.

## Configuration

Release `219c4e9` subsequently deployed the public IndexNow ownership file (deployment `dpl_GdzZ1Nq22FLP2xE33vvwHgZJM4qB`). The live domain/SSR/API/sitemap/header matrix passed again at 10:01 Zagreb. The initial 24-page IndexNow notification returned HTTP 202, pending provider key validation. This does not establish indexing; see the [search-engine status](SEO-REVIEW.md#other-search-engines-and-indexnow).

Server secrets are `DATABASE_URL`, `OPENROUTER_API_KEY` and `WAGZ_ADMIN_KEY`. Keep them in Vercel production environment variables. They never use a `VITE_` prefix or a Flutter define. A shared admin key is the pilot's operator sign-in; it is kept only in browser memory after entry.

The editor page has no public navigation link or sitemap entry. Its shell uses no-store/noindex/CSP, including the trailing-slash address. The page address is discoverable in client assets and source; all private data and writes still require the API's bearer key. `/api/admin/*` addresses and authentication are unchanged.

The default OpenRouter extraction/structuring model is `google/gemini-2.5-flash-lite`; web lookup separately defaults to `google/gemini-3.1-flash-lite` (optional `OPENROUTER_LOOKUP_MODEL`). Both use the same $1 application monthly budget. Also keep a provider-side key limit. The initial local AI ledger is migrated along with source data so test collection spend is accounted for. Local work that makes paid calls after launch must use the same hosted `DATABASE_URL` to share accounting. For isolated development, leave `DATABASE_URL` and `OPENROUTER_API_KEY` empty.

`scripts/migrate-local.ts` performs a one-time import from local SQLite into an empty hosted database. It refuses an already populated destination, uses one transaction, preserves AI charges and cache, and omits collection leases. Load the hosted URL without displaying it:

```powershell
node --env-file=.env.hosted.local --import tsx scripts/migrate-local.ts
```

## Collection

`.github/workflows/collect.yml` runs daily at 05:23 UTC (06:23 in Croatia in winter, 07:23 in summer) and supports manual dispatch. It requires repository secrets `WAGZ_DATABASE_URL` and `OPENROUTER_API_KEY`. Scheduled GitHub workflows run from the repository's default branch. GitHub can delay scheduled work and disables inactive public-repository schedules after 60 days; source status remains visible in the admin view. [GitHub schedule documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)

An admin refresh uses the same collector with a 240-second work deadline, inside Vercel's 300-second function limit. It preserves completed source work and reports deferred pages or AI enrichment. The scheduled runner has a 20-minute collection deadline, leaving installation/shutdown margin within the 25-minute workflow. A shared 30-minute database lease prevents overlapping collection runs, and each AI reservation is transactional. [Vercel function limits](https://vercel.com/docs/functions/limitations)

The same daily pass processes queued community submissions after source imports, reserving up to two minutes within the run for that queue. At most 20 tips are checked per run, oldest waiting work first, at most once per Zagreb day. Confirmed upcoming candidates stay as review drafts; completed spam/no-event/invalid-event outcomes archive with reasons and restore. Source/provider/budget failures remain pending for a later day. Manual admin preparation can bypass the daily wait. Per-tip leases, persisted attempt times and revision guards prevent duplicate billing or overwriting operator changes. The CLI prints aggregate checked/drafted/archived/pending counts without submitted text.

The source HTML cache on Vercel lives under `/tmp` and is disposable. The AI cache and spend ledger always live in Postgres. The scheduled runner restores its source cache through GitHub Actions caching.

## Checks and publishing

`npm run build` emits the browser assets into `dist` and a separate self-contained Vite SSR bundle into ignored `.wagz-server`. The Vercel function includes both directories and imports the server bundle; the server bundle is outside the public asset directory. Local source tests do not depend on generated output. This avoids Vercel's TypeScript/TSX tracing gap, which produced a missing `src/App.js` runtime error in the first preview. The hosted builder supports TypeScript 7 through its compiler executable; no compiler downgrade is needed. Build-time Vite environment-file loading is disabled because this application uses server-only runtime configuration.

The homepage uses an explicit route before filesystem matching so that static `index.html` cannot override SSR. Robots and sitemap are generated by the server; no competing static copies belong in `public`.

**Preview verified, 3 October 2026:** [deployment `dpl_JCnZeWUq498qbA1WVUyAcd98TMmq`](https://wagz-bt9miif08-kristijanpruzinacs-projects.vercel.app) built with Vercel CLI 62.1.0 and TypeScript 7.0.2. Read-only checks found 23 events in initial homepage HTML, 29 event links, matching detail HTML/Event JSON-LD and 24 sitemap URLs. Both editor variants return an empty 200 shell with no-store/noindex/CSP; both old `/admin` variants return 404 without redirecting. Missing events/API paths return 404, `/index.html` redirects 308, and the server bundle is not publicly accessible. Headers/bodies, with response cookies removed, are in `.artifacts/preview-ssr-1791012049856`. This is preview proof; production promotion remains a separate step.

Preview admin API reads fail closed with 503 because no preview admin key is configured. Seven anonymous GETs against the existing production admin API returned 401 with error-only/no-store responses; no real key was read and no mutation API was called. Wrong-key, retry, cross-origin and authorized-operation checks use isolated fixtures.

**Earlier production verification, 3 October 2026 at 07:24 UTC:** release `f696ae2` was live at <https://wagz.vercel.app>. The deployment owner's GET-only matrix passed for the current assets and initial SSR HTML, 23 events from three sources, a real detail page with schema/canonical and 24 sitemap URLs. Both editor variants return 200 with no-store/noindex/CSP; old `/admin` variants return 404 without redirecting; anonymous admin access returns 401. Evidence: `.artifacts/release-live-report.json`. This earlier check preceded the domain activation recorded above. Search Console and residual operational/accessibility checks remain separate.

```powershell
npm run format:check
npm test
npm run build
npm run test:browser
npm run test:discovery
npm run test:review
npm run test:review -- --dev
vercel deploy --prod --yes
```

Browser mutation tests explicitly disable `DATABASE_URL` and use an isolated SQLite copy. Never run synthetic tip publication tests against the public database. Hosted verification checks the real public feed and authenticated admin reads.

The review regression uses an in-memory database with captured real source events and a fixed capture-date clock. It checks source-preserving duplicate approval, partial drafts, stale review conflicts, preparation progress, expired-event rejection and 320px layouts without live mutations or paid AI calls. Its report and screenshots are in `.artifacts/review-*`.

Vercel Hobby is intended for personal, noncommercial projects. Review plan terms before commercial operation. Both hosting services have free usage limits; there are no paid plan upgrades in this setup. [Vercel Hobby](https://vercel.com/docs/plans/hobby), [Neon plans](https://neon.com/pricing)

Android APK creation is available through the mobile GitHub Actions workflow. Only the public HTTPS API address is supplied to Flutter; provider and administrator keys stay on the server.
