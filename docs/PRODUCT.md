# WagZ v1

Decided with the owner on 2026-10-03.

## Product

WagZ means **We Are Gen Z**. The wider ambition is a movement; the first practical release helps people find upcoming public events in Osijek. Matching is deferred and recoverable from the Ekipa Git milestone.

The first interface is a mobile-friendly web app, in Croatian, with a public feed, event details and a **Predloži događaj** form. No account is required to browse or submit a tip. The owner has a separate protected inbox and source-status screen.

## Collection

Use a fetching API rather than a self-operated browser/scraper service. Jina Reader was selected after successful no-key tests on the tourism calendar, culture-centre listing and event detail. OpenRouter extracts event facts from fetched content where structured parsing is insufficient. Keep source adapters small, evidence explicit, and fetching independent of publication.

An event needs a title, real date and venue to publish. Unknown times, prices and addresses remain unknown. Do not infer a new year because an old event's date is in the past. Distinguish an opening performance from the duration of an exhibition. Subscriptions and news announcements do not automatically become events.

Automatic publishing is **on by default and toggleable**. Incomplete imports remain drafts until sufficient source facts arrive or the owner resolves them. Community tips always need owner review. Operator draft/rejection decisions persist; drafts collected while automatic publishing was off stay held.

## Community tips

Accept a short note and optional URL. Save before attempting enrichment. Archive obvious automated junk and AI-classified spam with an explanation; retain an easy restore action. Missing details, no search result or uncertainty are not evidence of spam. Match an existing event only when unambiguous. Otherwise prepare a draft; the owner edits, accepts or rejects it. AI draft evidence does not equal verification.

## Cost decisions

- Fetching: Jina Reader's free basic API, conservatively paced and cached.
- AI provider: OpenRouter; default economical model is configurable.
- Monthly AI budget: **$1**. Reserve estimated costs before calls; retain reserves when the provider fails to report actual cost. Cache successful unchanged inputs. Configure the same cap on the provider key for authoritative billing protection.
- Avoid repeated web searches for regular sources. Search is an optional bounded aid for unmatched tips.
- No paid subscription, account purchase, deployment or remote database reset is authorised by implementing this local v1.

## Acceptance checks

1. Real Osijek sources produce dated events with links to supporting pages.
2. A repeat collection does not duplicate an occurrence; separate showtimes remain separate.
3. Failed fetching is visible and does not delete already collected events.
4. A user tip reaches the protected inbox; a complete approved draft appears publicly once.
5. Spam archive entries can be restored; uncertain entries remain reviewable.
6. The publishing toggle persists through restart and respects manual decisions.
7. Missing AI credentials or exhausted budget produce an explicit pending state, not invented results.
8. The public feed and admin flow work on a narrow mobile screen and desktop.

Coverage is measured against the configured sources. City-wide completeness is not guaranteed. Adding sources and auditing omissions is ongoing work; this v1 must show gaps instead of claiming every event was found.
