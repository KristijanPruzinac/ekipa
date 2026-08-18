# Bundled typefaces

All three families are licensed under the **SIL Open Font License 1.1**, which
permits bundling and redistribution inside an application.

| Family | Role | Files | Foundry |
| --- | --- | --- | --- |
| **Archivo** | System voice — every word the app says in its own voice | Regular / Medium / SemiBold / Bold | Omnibus-Type |
| **Instrument Serif** | Reserved register — the names of people and venues, nothing else | Regular | Instrument |
| **DM Mono** | Times, counts, codes | Regular / Medium | Colophon Foundry |

Downloaded from Google Fonts (`fonts.gstatic.com`) on 2026-08-18 and committed as
assets.

**Why bundled rather than fetched at runtime** (rejected: the `google_fonts`
package): it downloads a face on first use and falls back until it arrives, so a
first launch on a bad connection renders in a different typeface than every
screenshot we ever reviewed — and the reveal screen, the one screen that has to be
readable while someone is walking to a meeting point, is exactly where that would
happen. Bundling costs ~600 KB in the APK and removes a network dependency, a
race, a runtime failure mode, and a package (SC-2).
