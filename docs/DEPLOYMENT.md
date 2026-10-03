# WagZ hosting

The public web client and API use **Vercel Hobby**, with a fresh **Neon Free** Postgres database in Frankfurt. The Flutter client calls the same HTTPS API. Source data, event edits, tips, settings, extraction cache and AI charges persist in `public.wagz_*` tables. The historical Ekipa database is not used.

Production origin: <https://wagz.vercel.app>. The operator inbox is `/admin`. The Android workflow uses this origin as its `api_base_url` input.

## Configuration

Server secrets are `DATABASE_URL`, `OPENROUTER_API_KEY` and `WAGZ_ADMIN_KEY`. Keep them in Vercel production environment variables. They never use a `VITE_` prefix or a Flutter define. A shared admin key is the pilot's operator sign-in; it is kept only in browser memory after entry.

The default OpenRouter model is `google/gemini-2.5-flash-lite`; the application monthly budget is $1. Also keep a provider-side key limit. The initial local AI ledger is migrated along with source data so test collection spend is accounted for. Local work that makes paid calls after launch must use the same hosted `DATABASE_URL` to share accounting. For isolated development, leave `DATABASE_URL` and `OPENROUTER_API_KEY` empty.

`scripts/migrate-local.ts` performs a one-time import from local SQLite into an empty hosted database. It refuses an already populated destination, uses one transaction, preserves AI charges and cache, and omits collection leases. Load the hosted URL without displaying it:

```powershell
node --env-file=.env.hosted.local --import tsx scripts/migrate-local.ts
```

## Collection

`.github/workflows/collect.yml` runs at minute 23 every six hours in UTC and supports manual dispatch. It requires repository secrets `WAGZ_DATABASE_URL` and `OPENROUTER_API_KEY`. Scheduled GitHub workflows run from the repository's default branch. GitHub can delay scheduled work and disables inactive public-repository schedules after 60 days; source status remains visible in the admin view. [GitHub schedule documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)

An admin refresh uses the same collector with a 240-second work deadline, inside Vercel's 300-second function limit. It preserves completed source work and reports deferred pages or AI enrichment. The scheduled runner permits longer complete collections. A shared database lease prevents overlapping collection runs, and each AI reservation is transactional. [Vercel function limits](https://vercel.com/docs/functions/limitations)

The source HTML cache on Vercel lives under `/tmp` and is disposable. The AI cache and spend ledger always live in Postgres. The scheduled runner restores its source cache through GitHub Actions caching.

## Checks and publishing

```powershell
npm run format:check
npm test
npm run build
npm run test:browser
npm run test:discovery
vercel deploy --prod --yes
```

Browser mutation tests explicitly disable `DATABASE_URL` and use an isolated SQLite copy. Never run synthetic tip publication tests against the public database. Hosted verification checks the real public feed and authenticated admin reads.

Vercel Hobby is intended for personal, noncommercial projects. Review plan terms before commercial operation. Both hosting services have free usage limits; there are no paid plan upgrades in this setup. [Vercel Hobby](https://vercel.com/docs/plans/hobby), [Neon plans](https://neon.com/pricing)

Android APK creation is available through the mobile GitHub Actions workflow. Only the public HTTPS API address is supplied to Flutter; provider and administrator keys stay on the server.
