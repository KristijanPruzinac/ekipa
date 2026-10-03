# Optional OpenRouter integration

WagZ can use OpenRouter for two tasks: extracting events from content already fetched by the source adapters, and preparing a draft from a community tip. All tip drafts remain **unverified** and require an administrator's review. A model response, a plausible classification, and a citation do not establish that an event is true. An incomplete tip stays available for review; AI does not publish or delete it.

The implementation is in `server/ai/openrouter.ts`. It uses the ordinary Chat Completions HTTP API, with no additional SDK. Development and tests do not require a key and make no paid calls.

## Enable it

Put these settings in the local, ignored `.env` file and restart the server:

```dotenv
OPENROUTER_API_KEY=your_private_openrouter_key
OPENROUTER_MODEL=google/gemini-2.5-flash-lite
OPENROUTER_LOOKUP_MODEL=google/gemini-3.1-flash-lite
WAGZ_AI_MONTHLY_BUDGET_USD=1
WAGZ_AI_SEARCH_ENABLED=true
```

Create a dedicated OpenRouter key and set its provider-side spending limit to **$1 with a monthly reset**. Keep the key on the server. Do not commit it or include it in frontend environment variables. Setting the application budget to zero, or leaving the key empty, disables AI calls. Set `WAGZ_AI_SEARCH_ENABLED=false` to prepare tips from their submitted text without web search. Page extraction never requests web search.

Extraction and structured tip preparation default to `google/gemini-2.5-flash-lite`, with listed input/output rates of $0.10/$0.40 per million tokens. The separate lookup stage defaults to `google/gemini-3.1-flash-lite`, at $0.25/$1.50 per million tokens; `OPENROUTER_LOOKUP_MODEL` optionally overrides it. Prices were checked on 2026-10-03. The 3.1 lookup model executed the bounded search in a live test where 2.5 returned an unexecuted client-style tool call. Both stages use the same ledger and monthly limit. Changing either model can change price and compatibility. Use explicit model names; the adapter rejects `:online` variants. See [2.5 Flash Lite pricing](https://openrouter.ai/google/gemini-2.5-flash-lite/pricing) and [3.1 Flash Lite pricing](https://openrouter.ai/google/gemini-3.1-flash-lite/pricing).

## Spending and failures

Before every HTTP request, the adapter asks the supplied persistent ledger to reserve **$0.03**. An unavailable ledger, a refused reservation, an invalid configuration, or insufficient configured budget means no request is sent. The repository owns the atomic monthly accounting and cache, shared by extraction and tips.

After the response, finite, nonnegative numeric `usage.cost` replaces the reservation, including when output validation fails. Zero is a valid reported cost. Missing, negative, nonnumeric, or nonfinite cost leaves the reservation charged by calling `settle(id, null)`. Network errors and unknown provider charges retain the reservation as well. This deliberately favors avoiding unaccounted spending over maximizing the remaining allowance. The response cost field is documented in the [Chat Completions API reference](https://openrouter.ai/docs/api/api-reference/chat/create-a-chat-completion).

The $0.03 reservation is a conservative estimate, **not a provider billing ceiling**. An actual charge can exceed it, especially with a different model or changed provider pricing, and the ledger records the full actual amount. Use the separate OpenRouter key limit to enforce the intended provider-side allowance. A failed or timed-out request might still incur a provider charge. Each stage has one HTTP attempt, no retry loop, and a 45-second timeout.

Tips with web lookup use two bounded stages. The lookup request has the web tool and **no JSON response schema**. A second request has **no tools** and prepares strict JSON from the original note and actual provider citation excerpts. Lookup prose and proposed facts never become evidence. The second stage also runs when lookup returns no citations, so unrelated text can still be classified as spam and incomplete real events can stay uncertain. Each stage reserves and settles independently; a failed first stage stops the pipeline, and a denied second reservation never sends another request. The result reports the total known cost, or null if any attempted stage has an unknown charge. Extraction uses one tools-disabled request.

Tip search uses the current `openrouter:web_search` server tool with Parallel `basic`, one tool call, one search, at most three results, and at most 2,000 characters per result. Parallel basic currently costs $0.005 per search, plus model tokens. The model can elect not to search. The old web plugin is deprecated; the adapter does not use it. See [OpenRouter web search](https://openrouter.ai/docs/guides/features/server-tools/web-search).

## Input, evidence, and validation

Tips accept at most 2,000 characters and request at most 600 lookup output tokens and 1,200 structured output tokens. Extraction accepts at most **12,000 characters per chunk** and requests at most 2,500 output tokens. `MAX_EXTRACTION_INPUT_CHARS` is exported for callers. Oversized input is rejected before reservation with an explicit reason. Callers must split longer content; the adapter never silently takes the first part of a page. Preserve event boundaries, source date context, and the trusted detail URL when building chunks.

For submitted URLs on the existing source-reader allowlist, the service fetches the page through Jina Reader before AI preparation, with a 20-second deadline. Navigation, scripts and footer boilerplate are removed; at most 12,000 characters of page text are supplied without truncation. The existing host allowlist, reader byte limit and six-hour cache remain in force. These tips use one tools-disabled structured request, avoiding a search that might substitute another event. A failed/oversized source read is explained and does not trigger a replacement-event search. Other URLs can be investigated through the bounded provider lookup; the application does not fetch arbitrary hosts directly.

The system prompt treats submitted text, fetched pages, and search results as untrusted data. It requests JSON under a strict schema. Runtime checks still validate every returned event field, allowed categories/statuses, Osijek city, real calendar dates, chronological end dates, and the actual Europe/Zagreb UTC offset, including DST gaps. Date-only events preserve their unknown time. Unknown venue, address, price, and end date remain null.

Every generated event must include one contiguous exact `dateEvidence` quote from the supplied text, fetched source text, or one provider citation excerpt for a tip. Combining fragments from several excerpts is rejected. Its event year must be explicit in that quote. The current year, a URL year, and a copyright year are not valid reasons to guess an event year. Deterministic adapters may normalize an explicit source date such as `05/10/26` to `2026-10-05` before passing trusted text. The runtime validates the quote's presence and requires the actual start and end calendar days. A month and year cannot justify an invented first day. A timestamp without a supported source time becomes date-only. An AI draft conflicting with an explicitly submitted date/year is rejected rather than silently selecting another edition. Contextual accuracy of the event still needs source review.

Historical events retain their actual dates and get an explicit ended-event reason. They can be saved for review, but acceptance rejects a draft that has already ended because it cannot appear in the upcoming feed. Real but incomplete events remain uncertain; unrelated products and nonsense can be archived as spam and restored. Subscription sales and registration windows are not treated as public events merely because they contain dates.

Tip `evidenceUrls` come only from valid HTTP(S) `url_citation` annotations in the provider response, never a model-generated JSON URL list. A draft preserves the submitted link. If no link was submitted, it uses the citation containing the exact date-evidence quote rather than blindly choosing the first search result. Extraction always uses the caller's fetched source URL and source ID. AI cannot replace them with generated values.

End times require their own evidence: an explicit closing label, structured `endDate`/`endsAt`, or a time-interval endpoint. A multi-day listing with one shared start clock retains a date-only end. In the real Geek Gathering source, 1–2 October 2026 followed by `08:00` supports an 08:00 start and an unknown closing time on 2 October. Tip preparation version 3 and extraction version 4 invalidate earlier cached interpretations of this evidence.

Malformed JSON, unauthorized responses, provider errors, incomplete output, and rejected event fields produce explicit reasons. A single complete JSON Markdown fence can be unwrapped, including surrounding prose; multiple/ambiguous fences, malformed JSON and unsupported fields remain failures. No JSON values are repaired. Tips return `complete` separately from their classification: a valid uncertain/spam decision is complete, while provider/validation failures are not. Only complete results with known cost are cached. Tip cache keys include the preparation version and fetched source text, so prior cached failures and changed pages are reconsidered. An administrator's explicit refresh bypasses both preparation and reader caches; the database lease still prevents concurrent duplicate charges.

Extraction also returns `complete` and `rejectedCount`; the caller must report a partial run when `complete` is false, even if some valid events were retained. `complete` means all returned rows passed validation, not proof that the model found every event on a page. An empty event list includes an explanation.

Extraction occurrence IDs use the source URL, normalized title, and each same-title occurrence's position after sorting by date/time and venue. This preserves a single event's identity when its time or venue is corrected and separates multiple showtimes. Without organizer occurrence IDs, adding, removing, or reordering repeated-title occurrences can make reconciliation ambiguous. Prefer deterministic source IDs, review ambiguous reschedules, and do not infer cancellation just because AI omitted a row. Cache keys belong to the caller and should include source content, model, and relevant settings so unchanged inputs do not incur another request.

## Tests

```powershell
npx tsx --test server/ai/openrouter.test.ts
```

All HTTP responses and ledger operations in this suite are mocked. Tests cover absent keys and budget refusal, independently accounted lookup/structure stages, no-results classification, search limits, fabricated citations, ambiguous JSON envelopes, invalid JSON and authentication errors, date/DST validation, old-edition conflicts, historical dates, strict field types, unknown times/venues, input limits, repeated showtimes, and ledger failures. Service/reader tests cover source-fetch evidence, explicit retry and cache invalidation, historical publication rejection, concurrent edits, and preserving source discovery when accepting an unchanged match. No automated test contacts OpenRouter.
