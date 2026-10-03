# Optional OpenRouter integration

WagZ can use OpenRouter for two tasks: extracting events from content already fetched by the source adapters, and preparing a draft from a community tip. All tip drafts remain **unverified** and require an administrator's review. A model response, a plausible classification, and a citation do not establish that an event is true. An incomplete tip stays available for review; AI does not publish or delete it.

The implementation is in `server/ai/openrouter.ts`. It uses the ordinary Chat Completions HTTP API, with no additional SDK. Development and tests do not require a key and make no paid calls.

## Enable it

Put these settings in the local, ignored `.env` file and restart the server:

```dotenv
OPENROUTER_API_KEY=your_private_openrouter_key
OPENROUTER_MODEL=google/gemini-2.5-flash-lite
WAGZ_AI_MONTHLY_BUDGET_USD=1
WAGZ_AI_SEARCH_ENABLED=true
```

Create a dedicated OpenRouter key and set its provider-side spending limit to **$1 with a monthly reset**. Keep the key on the server. Do not commit it or include it in frontend environment variables. Setting the application budget to zero, or leaving the key empty, disables AI calls. Set `WAGZ_AI_SEARCH_ENABLED=false` to prepare tips from their submitted text without web search. Page extraction never requests web search.

The default model is `google/gemini-2.5-flash-lite`. Its listed input/output rates are $0.10/$0.40 per million tokens, checked on 2026-10-03. Changing the model can change both price and compatibility. Use an explicit model name; the adapter rejects the deprecated `:online` variant. See [OpenRouter model pricing](https://openrouter.ai/google/gemini-2.5-flash-lite/pricing).

## Spending and failures

Before every HTTP request, the adapter asks the supplied persistent ledger to reserve **$0.03**. An unavailable ledger, a refused reservation, an invalid configuration, or insufficient configured budget means no request is sent. The repository owns the atomic monthly accounting and cache, shared by extraction and tips.

After the response, finite, nonnegative numeric `usage.cost` replaces the reservation, including when output validation fails. Zero is a valid reported cost. Missing, negative, nonnumeric, or nonfinite cost leaves the reservation charged by calling `settle(id, null)`. Network errors and unknown provider charges retain the reservation as well. This deliberately favors avoiding unaccounted spending over maximizing the remaining allowance. The response cost field is documented in the [Chat Completions API reference](https://openrouter.ai/docs/api/api-reference/chat/create-a-chat-completion).

The $0.03 reservation is a conservative estimate, **not a provider billing ceiling**. An actual charge can exceed it, especially with a different model or changed provider pricing, and the ledger records the full actual amount. Use the separate OpenRouter key limit to enforce the intended provider-side allowance. A failed or timed-out request might still incur a provider charge. There is one HTTP attempt, no automatic retry, and a 45-second timeout.

Tip search uses the current `openrouter:web_search` server tool with Parallel `basic`, one tool call, one search, at most three results, and at most 2,000 characters per result. Parallel basic currently costs $0.005 per search, plus model tokens. The model can elect not to search. The old web plugin is deprecated; the adapter does not use it. See [OpenRouter web search](https://openrouter.ai/docs/guides/features/server-tools/web-search).

## Input, evidence, and validation

Tips accept at most 2,000 characters and request at most 1,200 output tokens. Extraction accepts at most **12,000 characters per chunk** and requests at most 2,500 output tokens. `MAX_EXTRACTION_INPUT_CHARS` is exported for callers. Oversized input is rejected before reservation with an explicit reason. Callers must split longer content; the adapter never silently takes the first part of a page. Preserve event boundaries, source date context, and the trusted detail URL when building chunks.

The system prompt treats submitted text, fetched pages, and search results as untrusted data. It requests JSON under a strict schema. Runtime checks still validate every returned event field, allowed categories/statuses, Osijek city, real calendar dates, chronological end dates, and the actual Europe/Zagreb UTC offset, including DST gaps. Date-only events preserve their unknown time. Unknown venue, address, price, and end date remain null.

Every generated event must include a short exact `dateEvidence` quote from the supplied text, or from a provider citation excerpt for a tip. Its event year must be explicit in that quote. The current year, a URL year, and a copyright year are not valid reasons to guess an event year. Deterministic adapters may normalize an explicit source date such as `05/10/26` to `2026-10-05` before passing trusted text. The runtime validates the quote?s presence and requires the actual start and end calendar days. A month and year cannot justify an invented first day. A timestamp without a supported source time becomes date-only. Contextual accuracy of the event still needs source review.

Tip `evidenceUrls` come only from valid HTTP(S) `url_citation` annotations in the provider response, never a model-generated JSON URL list. A draft source link is the submitted link or a cited link. Extraction always uses the caller's fetched source URL and source ID. AI cannot replace them with generated values.

Malformed JSON, unauthorized responses, provider errors, incomplete output, and rejected event fields produce explicit reasons. Extraction also returns `complete` and `rejectedCount`; the caller must report a partial run when `complete` is false, even if some valid events were retained. `complete` means all returned rows passed validation, not proof that the model found every event on a page. An empty event list includes an explanation.

Extraction occurrence IDs use the source URL, normalized title, and each same-title occurrence's position after sorting by date/time and venue. This preserves a single event's identity when its time or venue is corrected and separates multiple showtimes. Without organizer occurrence IDs, adding, removing, or reordering repeated-title occurrences can make reconciliation ambiguous. Prefer deterministic source IDs, review ambiguous reschedules, and do not infer cancellation just because AI omitted a row. Cache keys belong to the caller and should include source content, model, and relevant settings so unchanged inputs do not incur another request.

## Tests

```powershell
npx tsx --test server/ai/openrouter.test.ts
```

All HTTP responses and ledger operations in this suite are mocked. Tests cover absent keys and budget refusal, reservations and settlements, search limits, fabricated citations, invalid JSON and authentication errors, date/DST validation, strict field types, unknown times/venues, input limits, repeated showtimes, and ledger failures. No test contacts OpenRouter.
