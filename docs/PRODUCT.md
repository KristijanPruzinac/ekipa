# WagZ v1

Decided with the owner on 2026-10-03.

## Product

WagZ means **We Are Gen Z**. The wider ambition is a movement; the first practical release helps people find upcoming public events in Osijek. Matching is deferred and recoverable from the Ekipa Git milestone.

WagZ has a Croatian web interface and a native Flutter mobile client sharing the same events API, details and tip submissions. No account is required to browse or submit a tip. The owner has a separate protected web inbox and source-status screen.

## Personal discovery

The only public discovery control is **Svi · Studenti · Odrasli · Stariji**. It is visible directly above the feed, saved on the device, and never hides events. Svi shows chronological order. Audience choices are editorial recommendation presets using published category, explicitly named formats and known free entry. They are suggestions, not claims about demographic eligibility, personal taste, accessibility or affordability. Source audience evidence is a separate, stronger signal. General youth programmes are not automatically student programmes. Old saved category interests no longer affect the feed.

The local scoring rules are identical in TypeScript and Dart. Explicit matching audience evidence adds 100 points. Category weights (music/nightlife/theatre/culture/sport/community/other) are students 2/3/1/1/1/2/0, adults 2/1/3/2/2/2/0, seniors 1/0/3/3/1/2/0. Title formats add points: workshop/career/lecture/quiz 4/3/1; exhibition/books 1/2/3; music-category jazz/orchestra/choir/concert cycle 1/2/4 (students/adults/seniors). Explicit free entry adds 3/1/1; missing or conditionally free price text adds nothing. At most one format bonus applies. Scores of at least 3 receive a highlighted recommendation; lower factual scores can still affect order. Cards and details explain the cue. Cancelled/postponed events score zero. Score ties sort by Zagreb chronology, then original order. Festival prominence does not add ranking points. No per-visit AI, search or extra fetch is required.

Pastel category illustrations distinguish music/nightlife, stage/culture and sport/community; unclassified events stay neutral. These are visual cues, not more filters. A single chronological spine previews six events on desktop, plus each known endpoint. On phones the chart starts collapsed behind “Otvori vremensku crtu” so upcoming cards appear sooner; opening it previews three events with a clear close action. Category-colored branches reconnect at the real end; extra branch lanes represent overlapping ranges, never fixed categories. Exact timestamps show duration; date-only endpoints show calendar dates without guessed hours. Unknown endings stay unknown. Ongoing state uses API feed time and Zagreb dates. The axis has readable spacing, not a proportional elapsed-time scale, stated below the chart. One expand/collapse action reveals all events. Timeline entries and cards open the same details, and the timeline always stays chronological. There are no public date, category, search, price or sort controls.

Known ongoing events appear in a compact “U tijeku” section, initially two rows with an explicit total and expansion for more. Upcoming events get the full illustrated cards; audience order applies separately within both groups and all events remain reachable. An unknown end never qualifies as ongoing. Cards show supported duration: elapsed hours for a same-day timed range, inclusive calendar days for a multi-day date-only range, or the known ending date. A same-day date-only entry never claims 24 hours. Ongoing rows show when the event ends. Web and Flutter refresh every 60 seconds only in the foreground, refresh on return, avoid overlapping requests, and preserve the previous feed during transient failures.

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
- Hosting uses Vercel and a new Neon Free database. The owner authorized deployment on free tiers; paid upgrades and changes to the old Ekipa database are outside this release.
- Scheduled collection runs through GitHub Actions daily at 05:23 UTC. Mobile and web share hosted data and the persistent AI ledger.

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
