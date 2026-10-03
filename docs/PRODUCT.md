# WagZ v1

Decided with the owner on 2026-10-03.

## Product

WagZ means **We Are Gen Z**. The wider ambition is a movement; the first practical release helps people find upcoming public events in Osijek. Matching is deferred and recoverable from the Ekipa Git milestone.

WagZ has a Croatian web interface and a native Flutter mobile client sharing the same events API, details and tip submissions. No account is required to browse or submit a tip. The owner has a separate protected web inbox and source-status screen.

## Event discovery

Every event stays in stable Zagreb chronological order. There are no audience selectors, personal ranking rules or stored discovery choices. Legacy saved choices are ignored. Audience facts are displayed directly on cards as a small, flat label: **Studenti · Odrasli · Stariji**, including multiple audiences when supported. Only explicit source audience evidence qualifies: a recognized audience, a nonblank reason, and a safe evidence URL present among the event's sources. Bare audience arrays, genre, price and inferred age preferences never create a label. Unknown/general audiences get no label, including no “Za sve” claim. Details use “Publika navedena u najavi” and link to the source wording; a mention or discount does not imply exclusive eligibility. Tags never change order, counts or visibility. These rules match in TypeScript and Dart, with no per-visit AI, search or extra fetch.

Pastel category illustrations distinguish music/nightlife, dance, workshops, stage/culture and sport/community; unclassified events stay neutral. Dance has its own rose palette; workshops use blue. An explicit dance workshop keeps the dance type and adds a secondary ?Radionica? label. Only primary-event evidence determines these types; incidental workshop mentions in a festival or open-day programme do not reclassify the whole event. A single chronological spine previews six events on desktop, plus each known endpoint. On phones the chart starts collapsed into a compact row behind “Otvori vremensku crtu” so upcoming cards appear sooner; opening it previews three events with a clear close action. Category-colored branches reconnect at the real end; extra branch lanes represent overlapping ranges, never fixed categories. Exact timestamps show duration; date-only endpoints show calendar dates without guessed hours. Unknown endings stay unknown. Ongoing state uses API feed time and Zagreb dates. The axis has readable spacing, not a proportional elapsed-time scale, stated above the chart alongside a filled-start/hollow-end legend. One expand/collapse action reveals all events. Web timeline entries, ongoing rows and cards link to stable `/dogadaji/:id` pages. Ordinary clicks enhance these links into the same event dialog; refresh, open-in-new-tab and direct navigation render the standalone event. The initial homepage and event HTML contain the same visible React content used for hydration. Published past events retain a clear historical notice and links back to current events; missing or unpublished pages return 404. The timeline always stays chronological. A single activity-type selection offers ?Sve? plus only the primary categories present in the published feed, with counts. It filters ongoing rows, upcoming cards and timeline together without changing chronological order. It has no saved preference or audience filtering. A selected type disappearing on refresh shows an explicit empty state and reset. There are no public date, search, price or sort controls.

Known ongoing events appear in a compact “U tijeku” section, initially two rows with an explicit total and expansion for more. Upcoming events get the full illustrated cards; chronological order applies separately within both groups and all events remain reachable. An unknown end never qualifies as ongoing. Cards show supported duration: elapsed hours for a same-day timed range, inclusive calendar days for a multi-day date-only range, or the known ending date. A same-day date-only entry never claims 24 hours. Ongoing rows show when the event ends. Web and Flutter refresh every 60 seconds only in the foreground, refresh on return, avoid overlapping requests, and preserve the previous feed during transient failures.

## Collection

Use a fetching API rather than a self-operated browser/scraper service. Jina Reader was selected after successful no-key tests on the tourism calendar, culture-centre listing and event detail. OpenRouter extracts event facts from fetched content where structured parsing is insufficient. Keep source adapters small, evidence explicit, and fetching independent of publication.

An event needs a title, real date and venue to publish. Unknown times, prices and addresses remain unknown. Do not infer a new year because an old event's date is in the past. Distinguish an opening performance from the duration of an exhibition. Subscriptions and news announcements do not automatically become events.

Include public social nights, workshops, dated course starts and open days. The owner confirmed that regular weekly lessons should not crowd the event feed. A course start still needs a concrete dated announcement; do not expand an ordinary weekly timetable into events. Preserve registration, membership, age and public-access conditions. Registration deadlines and recaps are not event dates. See the [city coverage audit](COVERAGE-AUDIT.md) for examples and source candidates.

Automatic publishing is **on by default and toggleable**. Incomplete imports remain drafts until sufficient source facts arrive or the owner resolves them. Community tips always need owner review. Operator draft/rejection decisions persist; drafts collected while automatic publishing was off stay held.

## Community tips

Accept a short note and optional URL. Save immediately, with cheap bot screening; normal source investigation happens with the daily collection, after source imports. A completed check prepares a draft only for a scheduled, upcoming Osijek event with a valid title/date, venue and external date/year evidence. The owner must approve publication. A completed check that finds spam, no confirmed event, a past/cancelled event or insufficient evidence archives the submission with a reason and restore action. Uncertainty is not labelled spam. Provider/source failures, malformed or incomplete output, disabled lookup and exhausted budget stay queued for retry.

Before any scraping or AI, local checks archive obvious profanity-only abuse, repetitive junk and promotional spam. Real event titles with profanity are retained when they have meaningful event context. Submission variants differing only in case, spacing, punctuation or common tracking parameters deduplicate for 24 hours without paid processing.

The admin inbox defaults to ready drafts, with separate queued and archived views and counts. Manual preparation remains available. Restore returns an archived raw submission to the daily queue, or a preserved draft to review. Automatic checks do not reprocess drafts or overwrite operator edits. Each queued tip is attempted at most once per Zagreb calendar day; a run processes at most 20 tips within its remaining deadline, oldest waiting work first. Overflow and failed work stay queued.

An unambiguous already-published match archives as already listed. A valid unpublished match becomes a linked review draft; fresh source evidence can complete a missing venue. Ambiguous same-day occurrences stay for review and cannot publish as duplicates. Approval checks for intervening imports/approvals and changes to linked events. AI draft evidence still requires human source review.

Public submissions allow **five requests per client address per hour**, enforced atomically in the shared database across API instances and restarts. Excess requests return HTTP 429 before tip preparation. Quota records contain SHA-256 client keys rather than raw addresses; each request removes at most 128 expired records. Authentication and administrator collection request limits remain per process.

## Cost decisions

- Fetching: Jina Reader's free basic API, conservatively paced and cached.
- AI provider: OpenRouter; default economical model is configurable.
- Monthly AI budget: **$1**. Reserve estimated costs before calls; retain reserves when the provider fails to report actual cost. Cache successful unchanged inputs. Configure the same cap on the provider key for authoritative billing protection.
- Avoid repeated web searches for regular sources. Search is an optional bounded aid for unmatched tips.
- Hosting uses Vercel and a new Neon Free database. The owner authorized deployment on free tiers; paid upgrades and changes to the old Ekipa database are outside this release.
- Scheduled collection runs through GitHub Actions daily at 05:23 UTC. Mobile and web share hosted data and the persistent AI ledger.

## Acceptance checks

1. Real Osijek sources produce dated events with links to supporting pages.
2. A repeat collection does not duplicate an occurrence; separate showtimes remain separate.
3. Failed fetching is visible and does not delete already collected events.
4. A user tip reaches the protected inbox; a complete approved draft appears publicly once.
5. Archived spam/no-event submissions retain reasons and can be restored; operational failures stay queued.
6. The publishing toggle persists through restart and respects manual decisions.
7. Missing AI credentials or exhausted budget produce an explicit pending state, not invented results.
8. The public feed and admin flow work on a narrow mobile screen and desktop.

Coverage is measured against the configured sources. City-wide completeness is not guaranteed. Adding sources and auditing omissions is ongoing work; this v1 must show gaps instead of claiming every event was found.
