# 13 — Gap register

Every requirement in `docs/v3/` checked against what is actually in the repo on
**2026-08-20**. Written because the P1 build had drifted from the docs in three
different ways at once — invented requirements, missing requirements, and
requirements implemented in a shape the reference set already rejected — and a
verbal "we'll fix it" does not survive a compaction.

Status vocabulary: **WRONG** (built, contradicts canon) · **MISSING** (canon
requires it, nothing exists) · **STUB** (exists, does nothing real) ·
**PARTIAL** (exists, incomplete against its own spec).

---

## A. WRONG — built against something nobody agreed to

### A-1 · The travel-radius question · `05_PLACES.md §2`

`NeighbourhoodStep` asks *"how far are you willing to go"* with three choices.
No line of the Bible asks for it. It entered through a derived document —
`05_PLACES.md §2`'s "plus one control … → the person's `max_travel`" — and a
derived document that adds a user-facing decision the transcript never asked for
is invention (Bible rule 2).

**The requirement, restated from the user, 2026-08-20:** *match users anywhere
in town, ranked by closest distance.*

Consequences:

- The onboarding step is deleted. The anchor pin stays — it is the distance
  signal, and the Bible does ask for it.
- `max_travel_m` stops being a person's answer and becomes a **city config
  value** (`geo.max_travel_m`, D5). The matcher's shape is unchanged: it still
  computes reachable clusters per person, it just reads the bound from the city
  instead of from a question nobody wanted to answer.
- The village case `05_PLACES.md §4` is unaffected: a person with no reachable
  cluster is still not matched and still told so honestly.
- `05_PLACES.md §2` is corrected and the Bible gets an amendment.

**Why config rather than deleting the bound entirely:** "anywhere in town" is
a bound — it is the town. Removing the number would make the matcher's
reachability query unbounded and silently propose a hangout across a county.

### A-2 · The availability picker is a list of chips · `00_BIBLE`, `05_PLACES.md §7`

The transcript asks for slots that are **"simple to select"**, and for the
picker to later carry a *background indicator behind a slot that shows it is a
good time to pick*. What was built is a vertical list of day blocks with time
chips — a form, not a calendar. It reads as a settings screen, it cannot show
a week at a glance, and it has nowhere to put the density indicator that
`05_PLACES.md §7` already specifies.

**Replaced by a month calendar**: the operating days are the only live cells,
each carrying its slot count and a density wash; tapping a day opens its three
times. That is the surface the indicator was designed for, and it is how a
person actually thinks about "which evenings am I around this week".

### A-3 · Onboarding asks for the city · `02_DOMAIN.md §6`

`CityStep` asks a person to pick their city from a list. Osijek is the only
active city and the Bible locks it. Worse, `people.city_id` is not
client-settable by design (`0002_v3_people.sql`: *"a client that could update
its own city_id could relocate itself into a denser city on the morning of a
match run"*), so the screen asks a question whose answer the server refuses to
take. Replaced by the anchor pin, from which the server derives the city.

---

## B. MISSING — canon requires it, nothing exists

| # | What | Canon | Notes |
| --- | --- | --- | --- |
| B-1 | **The safety brief**, mandatory and unskippable, shown at confirmation *and* at reveal, read past rather than dismissed | `00_BIBLE` D12 + §"The safety brief" | Seven fixed points. The single highest-priority missing screen in the app: it is the one control that is not statistical. |
| B-2 | **Confirmation screen** — morning-of yes/no, with the decline-is-nearly-free incentive stated in plain words | `02_DOMAIN.md §3`, `04_TRUST.md §3.1` | RPC `confirm_hangout` already exists and is untouched by any screen. |
| B-3 | **Reveal screen** — themed map, meeting point, walking time, the group's sigil, first names, "what happens" | `05_PLACES.md §8`, `06_ACTIVITIES.md §4`, reference set (`places/04-place-detail`, `polarsteps/04-trip-map-plan`) | RPC `hangout_reveal` exists, nothing calls it. |
| B-4 | **Sigil rendering** — 24 symbols × 6 colours, describable out loud | `05_PLACES.md §8` | Table `sigils` exists (`0007`). No symbol set, no widget. |
| B-5 | **Arrival + peer attestation** — everyone taps for themselves; mark another not-here/left; 15-minute grace; 30-minute report window | `00_BIBLE`, `02_DOMAIN.md §4` | No RPC, no screen. |
| B-6 | **Activity templates** — `CARDS` and `CONVERSATION_DECK`, with brief / arrival script / session / **exit script** | `06_ACTIVITIES.md` | Nothing exists, including the `ActivityTemplate` contract. The exit script is not decoration: `01_ARCHITECTURE.md §12.6` names ambiguity the tax this population cannot afford. |
| B-7 | **Our own conversation deck** — three warm-ups shuffled, escalating set sampled but never reordered, pass always available | `06_ACTIVITIES.md §3` | Content is ours to write; the 36-question instrument is copyrighted. |
| B-8 | **Ratings** — enjoyment + respect per member, mandatory, 2s dwell, randomised order, no bulk control | `02_DOMAIN.md §5`, `04_TRUST.md §8` | No RPC, no screen. Blocks every downstream signal. |
| B-9 | **Reports** — separate heavier action, invisible to the subject | `04_TRUST.md §4.2` | Table exists, no path to it. |
| B-10 | **Venue feedback** — "was it easy to find?", "did it feel like a good place to meet?" | `05_PLACES.md §3` | Table `venue_feedback` exists (`0004`), nothing writes it. This is the self-sufficiency mechanism (D11); without it the venue model never improves. |
| B-11 | **The rules screen** — no advances in a friend hangout — shown at confirmation and at reveal | `00_BIBLE`, `06_ACTIVITIES.md §4` | Explicit in the transcript. |
| B-12 | **Hangouts / Dating top tabs** | `00_BIBLE` ("Make dating a separate tab up top") | Dating stays locked until 4–8 meets; the tab's existence is what the transcript asked for. |
| B-13 | **The mill's jobs** — match run, sweeper, backfill, lock + meeting point + sigil, notifications | `01_ARCHITECTURE.md §2`, `03_MATCHMAKER.md §3–4` | `services/mill` is a single `throw UnimplementedError`. |
| B-14 | **Venue ingestion + clustering** — OSM/Overpass, three gates, DBSCAN | `05_PLACES.md §3–4` | Nothing. The matcher's cluster eligibility has no data to run on. |
| B-15 | **Trust engine** — two accumulators, response ladder R0–R5, sanction ladder, credibility | `04_TRUST.md` | Tables exist; no code computes standing or issues a sanction. |
| B-16 | **Client RPCs for the rest of the loop** — create profile, catalogues, arrival, attestation, ratings, reports, venue feedback, repeat-last-week | `02_DOMAIN.md`, `04_TRUST.md` | Only `my_hangouts`, `hangout_reveal`, `set_availability`, `confirm_hangout` exist. |
| B-17 | **Push (FCM) and Realtime** | `01_ARCHITECTURE.md §10` | Nothing. Confirmation is a push-driven flow; without it the morning-of does not happen. |
| B-18 | **`go_router` + the session state machine** | `01_ARCHITECTURE.md §10` | The shell is a `switch` on an enum. Fine for four screens, not for twenty. |

---

## C. STUB / PARTIAL

| # | What | State |
| --- | --- | --- |
| C-1 | `IdentityVerifier` | Port is right. Only implementation accepts any typed name. `.edu.hr` code path and AAI@EduHr both unwritten — see §D. |
| C-2 | Address normalisation | Unwritten. `09_OPEN_QUESTIONS.md` C-1: ban-evasion resistance rests **entirely** on this one function, and it gets property tests plus a pgTAP uniqueness constraint. |
| C-3 | `MemberGateway` | Only implementation is in-memory. No Supabase adapter exists; the app has never spoken to the database. |
| C-4 | Location permission | `NeighbourhoodStep` hard-codes Osijek's centroid instead of asking. |
| C-5 | Matchmaker | `ekipa_core/matching/` implements partition, eligibility, seed policy, ring draw, composition, plan. **Not wired to anything** — no snapshot loader, no persistence, no run trigger. |
| C-6 | Simulator | Runs 12 synthetic weeks. Its ratios were reported wrong in commit `6f6678a` and never re-tuned. |
| C-7 | Equipment (`deck_of_cards`, `minCarriers = 2`) | Table `equipment` and `person_equipment` exist; nothing sets them, and the matcher has no carrier constraint. |
| C-8 | `ekipa_ui` | Six primitives. Missing everything the hangout loop needs: map surface, sigil, chips, segmented tabs, bottom sheet, calendar, avatar-less person row. |

---

## D. Identity — AAI@EduHr, corrected

`09_OPEN_QUESTIONS.md` C-1 says the registration procedure "is not published in a
form I could verify" and asks the user to email SRCE. **That was wrong and is
corrected here.** The procedure is published, and the parts that matter to a
Flutter app are better than assumed:

1. **OIDC is supported**, alongside SAML, CAS and WS-FED. A mobile app therefore
   needs an authorization-code + PKCE flow and **no SAML broker** — the Keycloak
   dependency C-1 assumed is not required.
2. **Registration is self-service** through the Resource Registry at
   `registar.aaiedu.hr`: register the resource, pull metadata, configure, then
   request production status.
3. **`AAI@EduHr Lab`** is a full test federation — test SSO, test LDAP, test
   accounts — usable for development before any production approval exists.
4. **The real gate is organisational, and it is real:** the SP must belong to a
   *partner sustava* or a *matična ustanova*. An individual cannot register a
   production SP. FERIT is a matična ustanova, so the route is its AAI
   coordinator, not a cold email to SRCE.
5. **Attributes:** `hrEduPersonPersistentID` is **mandatory** and permanent —
   that is the identity anchor, and it is strictly better than an email address.
   `givenName` and `sn` are mandatory, which gives the display name without
   asking. `hrEduPersonPrimaryAffiliation` is mandatory, which proves *student*.
   **`hrEduPersonDateOfBirth` is optional**, so the 18+ gate cannot rely on it —
   that stays an attested date plus the affiliation, and `09_OPEN_QUESTIONS.md`
   Q-AGE keeps its answer.

**What ships now:** `AaiEduHrVerifier`, an OIDC adapter behind the existing
port, pointed at Lab. The interim `.edu.hr` email-code verifier stays written
and available, because Lab access is not production access.

---

## E. What this register does not cover

The dating layer (`07_DATING.md`) beyond the tab, and the console's people list.
Both are downstream of ratings existing, and ratings are B-8.
