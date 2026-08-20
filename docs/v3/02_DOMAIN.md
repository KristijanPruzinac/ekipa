# 02 — Domain model, lifecycle, identity

Derived from [00_BIBLE.md](00_BIBLE.md). Vocabulary here is binding: if the code says
`meetup`, the code is wrong.

---

## 1. Ubiquitous language

| Term | Meaning | Never call it |
| --- | --- | --- |
| **Hangout** | One scheduled meeting of 3–4 people in one slot | meetup, event, match |
| **Slot** | A concrete 90-minute window in one city on one date (e.g. Osijek, Thu 2026-09-03, 17:30–19:00) | time, session |
| **Availability** | A person's claim that they *could* attend a given slot | preference |
| **Match run** | One execution of the matchmaker over one snapshot | matching, batch |
| **Confirmation** | The morning-of yes/no on an already-formed hangout | RSVP (that was v1) |
| **Backfill** | The repair pass that replaces someone who declined | rematch |
| **Meeting point** | The vetted venue where the group physically converges | venue *(internal term is fine)*, spot |
| **Sigil** | The group's symbol shown at reveal, unique per meeting point per window | icon, badge |
| **Rating** | The post-hangout enjoyment + respect answers | review, score |
| **Edge** | A mutual friend connection formed from mutual positive ratings | friendship, match |
| **Standing** | A person's current trust tier | reputation, karma |
| **Infraction** | One recorded bad event (no-show, silence, upheld report…) | strike |
| **Sanction** | The consequence derived from standing (throttle, suspension, ban) | punishment |

---

## 2. Core entities

Sealed, immutable value types in `ekipa_core`. Mapping to/from rows happens in
`ekipa_data` — **the domain never parses a database row** (v1 put `fromRow` on domain
types; that is an infrastructure leak that makes the domain untestable without a schema).

```
Person
  id              PersonId            (surrogate, internal)
  identityHash    IdentityHash        (unique, see §6)
  displayName     DisplayName         ("Marko", "n")  -> renders "Marko ····n"
  gender          Gender              (registry-backed, not an enum baked into rules)
  homeAnchor      GeoPoint            (coarsened; see 05_PLACES)
  cityId          CityId
  standing        Standing            (tier + score + expiry)  — never shown to anyone
  datingProfile   DatingProfile?      (null until unlocked & enabled)
  joinedAt        Instant
  stats           PersonStats         (completed, no-shows, ratings given/received)

Slot
  id              SlotId
  cityId, startsAt (tz-resolved), duration (90m), weekday, localStartTime

Availability   (personId, slotId, markedAt, source: manual|repeat)

Hangout
  id, slotId, cityId
  state           HangoutState        (see §3)
  composition     CompositionRule     (which shape it was built to)
  seedPersonId    PersonId            (who the ring draw was run around)
  activity        ActivityTemplateId
  meetingPointId  VenueId?            (assigned at lock, not at match)
  sigil           Sigil?              (assigned with meeting point)
  members         List<HangoutMember>
  deadlines       HangoutDeadlines    (confirm open/close, backfill until, reveal, grace, rating due)
  matchRunId, configVersionId

HangoutMember
  personId, slotRole (seed|partner|backfill), joinedAt
  ringIntended    Ring?   (r1_enjoyed | r2_leaf | r3_stranger)  — what the draw asked for
  ringRealised    Ring?   —  what the graph could actually supply; differs on fallback
  viaPersonId     PersonId?  (the intermediary, for an r2 draw — never shown to anyone)
  confirmation    Confirmation?       (yes/no/silent + at)
  arrival         Arrival?            (self-reported + peer attestations)
  ratingsSubmitted bool

Edge   (a<b canonical, weight, lastMetAt, meetCount)   — mutual only, direction never stored
Exclusion (a, b, reason: rather_not|block|report_upheld) — symmetric in effect, permanent
```

**Why `Gender` is registry-backed rather than a hard enum:** directive D6. The
composition rule "2+2 or 4 same" is a *policy over a gender registry*, so adding a
non-binary handling policy later is a registry + rule change, not a migration of every
`switch` in the codebase. The registry ships with `woman | man | other` and the *rules*
declare how each is treated (see [03_MATCHMAKER.md §Composition](03_MATCHMAKER.md)).

---

## 3. The hangout lifecycle (the spine of the product)

```
                    ┌──────────┐
                    │ PLANNED  │  matchmaker emitted it; nobody notified yet
                    └────┬─────┘
       notify group      │
                    ┌────▼─────┐
                    │ PROPOSED │  members know a hangout exists for slot X
                    └────┬─────┘
   confirm_opens_at      │  (morning of, configurable)
                    ┌────▼──────┐
                    │CONFIRMING │  push sent; each member answers yes/no
                    └────┬──────┘
      confirm_deadline_at│
             ┌───────────┼─────────────┐
      all yes│           │some no/silent│
        ┌────▼────┐  ┌───▼────────┐    │
        │ LOCKED  │  │ BACKFILLING│────┘  repair passes until backfill_until
        └────┬────┘  └───┬────────┘
             │           │ ≥3 confirmed → LOCKED
             │           │ <3 and cannot repair → CANCELLED (everyone told, before they leave home)
      reveal_at (T-60…T-30, configurable)
        ┌────▼────┐
        │ REVEALED│  meeting point on map + sigil + names + rules screen
        └────┬────┘
      starts_at
        ┌────▼────┐
        │  LIVE   │  arrival taps; grace window; late/dip reports
        └────┬────┘
      ends_at
        ┌────▼────┐
        │ RATING  │  mandatory ratings; rating_due_at
        └────┬────┘
        ┌────▼────┐
        │ CLOSED  │  edges formed, infractions written, metrics final
        └─────────┘
```

**Every arrow is a row in a transition table with a guard and a set of effects**
(notifications to send, infractions to record, timers to arm). Intention: the answer to
"when does the app send X" lives in exactly one place, and adding a state later (e.g.
`WAITLISTED`) does not mean auditing the whole codebase for missed cases.

Terminal side branches from any state: `CANCELLED` (system) and `ABANDONED` (nobody
arrived). Both are recorded, never silently deleted — cancellations are input to trust.

### The confirmation → backfill window, concretely

The transcript asks whether there should be a buffer after the confirmation invite. Yes,
and here is the intention behind each boundary:

| Boundary | Default | Why this value is the *shape* it is |
| --- | --- | --- |
| `confirm_opens_at` | 09:00 local, day-of | Early enough that a decline leaves repair time; late enough that the answer reflects the actual day. |
| `confirm_deadline_at` | +3h (12:00) | The deadline exists to convert **silence into information**. Without it the system cannot distinguish "coming" from "asleep" until it is too late to fix. |
| `backfill_until` | start − 2h | Repair needs to stop while a replacement can still realistically show up; being invited 20 minutes before is worse than not being invited. |
| `reveal_at` | start − 60m | Late enough to prevent pre-judgement and last-minute quiet filtering, early enough to travel. |
| `arrival_grace` | start + 15m | Matches the transcript's 15-minute rule. |
| `late_report_window` | start + 30m | Matches the transcript. Reports outside it are not accepted — memory and motive both degrade. |
| `rating_due_at` | end + 24h | One reminder, then the gate (see [04_TRUST.md](04_TRUST.md)). |

All seven are config keys (D5). All are recorded on the hangout at creation so a mid-day
config change never moves a deadline someone is already inside.

**A silent member is treated as worse than a declining member.** Intention: the system's
scarce resource is *time to repair*. An early "no" is cooperative — it is information
delivered when it is still actionable. Silence destroys the repair window and then
usually becomes a no-show. Pricing them identically would teach people that ignoring the
push is free. See [04_TRUST.md](04_TRUST.md) for the weights.

---

## 4. Arrival, attestation, and who gets penalised

The transcript is specific: everyone taps for themselves; it is a duty; a dip or a late
arrival is penalised. The mechanism has to survive both honest error and malice.

- **Arrival is peer-attested, not self-declared.** Each member taps "I'm here"; each
  member can mark another as *not yet here* / *left*. A person is treated as present if
  they tapped **and** at least one other member did not contradict it, or if a majority
  of other members attest their presence.
- **Why not self-report alone:** a no-show can tap "arrived" from home and the system
  cannot tell. Attendance drives edges, trust and sanctions; a self-reported input to a
  sanction system is an open invitation.
- **Why not majority-only:** in a group of 3 where two arrive late themselves, a
  majority is easy to abuse. Requiring self-tap *plus* absence of contradiction makes the
  common case one tap and the contested case explicit.
- **Contested cases go to the console**, not to an automatic ban. Volume will be tiny;
  the cost of a wrong automatic ban is a lost user and a story told about the app.
- **Optional proximity assertion:** if location permission is granted, the app may assert
  "device within R metres of the meeting point at tap time" and store **only the
  boolean**. Never the coordinates, never a trace. Intention: raise the cost of a false
  arrival without building a tracking product.

---

## 5. Ratings — what is collected and what it means

Two questions per other member, both mandatory, exactly as the transcript specifies:

1. **Enjoyment:** `really_enjoyed | enjoyed | no_preference | rather_not`
2. **Respect:** `yes | no`

Plus an optional **report** (a separate, heavier action — see [04_TRUST.md](04_TRUST.md)).

Semantics, and this is the load-bearing part:

| Signal | Used for friend matching | Used for dating | Ever shown to anyone |
| --- | --- | --- | --- |
| `enjoyed` | yes — full weight | no | never |
| `really_enjoyed` | yes — **identical weight to `enjoyed`** | yes — this is the dating signal | never |
| `no_preference` | neutral, nothing recorded | no | never |
| `rather_not` | permanent exclusion for the pair | excluded | never |
| respect `no` | throttle input, not a ranking input | gate input | never |

**Why `enjoyed` and `really_enjoyed` weigh the same for friendship** (the user's own
proposal, and it is correct): it makes `really_enjoyed` a *costless-to-give, honest*
dating signal. If the two levels differed for friendship, a person who wants to see
someone again as a friend would be forced to choose between an accurate friend signal
and an accurate dating signal, and the two channels would corrupt each other. Collapsing
them for friendship is what buys a clean second channel. This is a genuinely good design
move and it survives review.

**The residual risk, stated honestly:** once people learn that `really_enjoyed` feeds
dating, the *friend* meaning of the top level is gone — which we have already priced in
by making it irrelevant to friend matching — but a person who wants dating matches has
an incentive to press it indiscriminately. Countermeasures live in
[07_DATING.md](07_DATING.md): mutual requirement, unlock threshold, respect gate,
non-deterministic pairing, and a per-person cap on how many `really_enjoyed` can carry
dating intent per period.

**Anti-satisficing on mandatory ratings.** The transcript proposes a 2-second delay per
rating. Adopted, plus:

- randomised order of the people being rated (defeats muscle memory),
- no bulk "same for everyone" control,
- **straight-lining detection** — identical answers submitted at near-minimum dwell time
  across several hangouts down-weights that rater's influence rather than rejecting the
  input. Intention: you cannot force sincerity, but you can make insincerity cheap to
  detect and harmless to the graph. Rejecting it outright would just teach people to add
  jitter.

---

## 6. Identity and privacy

### What we store about a person

| Field | Why it exists | Sensitivity |
| --- | --- | --- |
| `identity_hash` | ban evasion resistance, one account per human | pseudonymous identifier |
| `first_name` | the group has to greet each other | personal data |
| `last_initial` (final letter of surname) | disambiguates two Markos without publishing a surname | personal data |
| `gender` | composition rules; dating | special category under GDPR Art. 9 if read as sexual-orientation-adjacent — treat as sensitive |
| `dating_preferences` | dating matching | **special category** (sexual orientation) — explicit consent required, separately revocable |
| `home_anchor` (coarsened) | distance signal in matching | location data |
| `push_token`, `platform` | notifications | device data |
| trust/rating aggregates | sanctions, matching | derived, never shown |

**Not stored:** photos, free-text bio, surname in full, exact address, precise location
traces, message content (there is no chat).

### The identity hash

```
identity_hash = HMAC-SHA256(pepper, provider_id || ':' || normalised_subject_id)
```

- `pepper` lives in a **KMS / secret manager, not in Postgres**. A hash whose secret is
  stored beside it protects nothing from a database compromise.
- Unique index ⇒ one account per verified human ⇒ a ban survives account deletion,
  which is exactly the transcript's requirement.
- **Say the true thing:** this is *pseudonymisation*, not anonymisation. The data is
  still personal data under GDPR. It reduces breach impact and blocks casual re-lookup;
  it is not a get-out from data-protection obligations.

### Identity providers (strategy registry, D6)

| Provider | Reality check | Verdict |
| --- | --- | --- |
| **`.edu.hr` email code** | Send a one-time code to a university address; subject = normalised address | **v1 choice.** Ships in days, proves student status, gives a stable subject. |
| **AAI@EduHr (SAML 2.0)** | The real Croatian academic federation. Requires being (or being sponsored by) a member institution, service registration, SAML metadata exchange | **v2.** Strictly better identity, materially slower to obtain. Needs a SAML broker (e.g. Keycloak) because SAML in a mobile app alone is unpleasant. |
| **Document / eID KYC** | Veriff / Sumsub / Persona, or Croatian eOsobna via NIAS | **v3, gated on funding.** Real identity, real cost per check, real DPA obligations. |
| **Phone (SMS)** | Cheap, near-zero identity value — numbers are disposable | **Not an identity provider.** May be an auth convenience only. |

The port is one interface: `IdentityVerifier.verify(challenge) -> VerifiedIdentity{
providerId, subjectId, firstName, lastInitial, dateOfBirth? }`. Everything downstream
sees only `VerifiedIdentity`, so swapping providers never touches product code.

**Consequence to decide early:** university identity means a real chance of 17-year-olds.
Either enforce 18+ (and get date of birth from the provider, which email verification
cannot give) or design an under-18 policy — a mixed-age stranger-meeting product with
minors has a different safety and legal profile entirely. See
[09_OPEN_QUESTIONS.md](09_OPEN_QUESTIONS.md) Q-AGE.

### Display

`Marko ····n` — first name, dot-masked surname, final letter shown. Rendered by one
`DisplayName` value object so the format is impossible to get wrong in one screen.

**Reveal timing:** names appear at `reveal_at` (T−60m), not at match time. Intention
carried from v2: early names invite pre-judgement and quiet last-minute filtering, which
is both unkind and a load-bearing failure mode for a product about not being screened.

### Privacy invariants (each gets a pgTAP test)

1. A person can read **only their own** availability, confirmations, ratings, reports,
   standing, infractions.
2. Before `REVEALED`, a member can learn only their hangout's **shape** (size, gender mix
   where relevant), never identities.
3. **Nobody can ever read how anyone rated them** — not the value, not the existence, not
   an aggregate that leaks it.
4. Direction of an edge is not stored and cannot be derived by any client-callable RPC.
5. A decline is invisible: no member can determine who declined or was replaced.
6. Reports are invisible to the reported person, including the count.
7. Standing, trust score and any respect aggregate are service-role only.

---

## 7. Schema sketch (v3, fresh)

Not the migration — the shape, so the pieces are visible at once.

```
identities(id, identity_hash unique, provider, verified_at, dob?, revoked_at)
people(id, identity_id → identities, first_name, last_initial, gender,
       city_id, home_anchor geography(Point,4326), joined_at, deleted_at)
devices(id, person_id, push_token, platform, last_seen_at)

cities(id, name, country, timezone, centroid, active)
venues(id, city_id, source, source_ref, name, kind, location, opening_hours,
       popularity, vetted_at, vetted_by, active)
venue_clusters(id, city_id, label, centroid)      -- derived "areas", never authored

slots(id, city_id, starts_at, ends_at, local_weekday, local_time, generated_by)
availability(person_id, slot_id, marked_at, primary key(person_id, slot_id))

hangouts(id, slot_id, city_id, state, composition_rule, group_template, activity_id,
         meeting_point_id, sigil_id, match_run_id, config_version_id,
         confirm_opens_at, confirm_deadline_at, backfill_until, reveal_at,
         arrival_grace_until, rating_due_at, created_at)
hangout_members(hangout_id, person_id, slot_role, joined_at,
                ring_intended, ring_realised, via_person_id,
                confirmation, confirmed_at, arrived_at, arrival_attested,
                rated_at, primary key(hangout_id, person_id))
                -- ring_* and via_person_id are matcher diagnostics: never selectable by
                -- any client-facing policy, because via_person_id leaks an edge
hangout_events(id, hangout_id, type, payload, actor, occurred_at, config_version_id)

ratings(hangout_id, rater_id, subject_id, enjoyment, respect, dwell_ms, created_at,
        primary key(hangout_id, rater_id, subject_id))
edges(a_id, b_id, weight, meet_count, last_met_at, primary key(a_id,b_id) with a_id<b_id)
exclusions(a_id, b_id, reason, created_at, primary key(a_id,b_id) with a_id<b_id)

reports(id, reporter_id, subject_id, hangout_id, category, note, created_at,
        reviewed_at, outcome)
infractions(id, person_id, type, weight, hangout_id?, occurred_at, config_version_id)
sanctions(id, person_id, kind, reason, starts_at, ends_at, source_infraction_ids[],
          issued_by, appealed_at, overturned_at)
standing(person_id, tier, score, computed_at)         -- projection, recomputable

config_versions(id, created_at, created_by, note)
config_values(version_id, key, value)
match_runs(id, city_id, started_at, seed, snapshot_hash, config_version_id, stats)
match_run_groups(match_run_id, hangout_id, seed_person_id, ring_mix jsonb,
                 score_components jsonb, rejected_alternates jsonb)
```

Constraints doing real work (not application checks):

- `unique(person_id, slot_id)` on hangout membership via an exclusion constraint —
  **a person cannot be in two hangouts in the same slot**, enforced by the database.
- `unique(meeting_point_id, sigil_id, time_window)` — **two groups never share a sigil at
  the same place**, the transcript's explicit requirement, enforced where it cannot be
  raced.
- `edges` and `exclusions` keyed on `least/greatest` so symmetry is structural.
- Partial indexes on the deadline columns for the sweeper (`where state = 'CONFIRMING'`
  etc.), because the sweeper's query runs every few minutes forever.

---

## 8. What "expandable" means here, concretely

Directive D6 shows up in five places; each is a registry, each has a default entry, and
each is chosen per-city by config:

| Extension point | v1 entries | Adding an option means |
| --- | --- | --- |
| `CompositionRule` | `NO_LONE_GENDER` (the single invariant — see [03_MATCHMAKER.md §⑥](03_MATCHMAKER.md)) | new class + registry entry + config value |
| `SeedPolicy` | `STARVATION_WEIGHTED_GOOD_STANDING` | same |
| `ActivityTemplate` | `CARDS`, `CONVERSATION_DECK` | same, plus its content pack |
| `IdentityVerifier` | `EDU_EMAIL` | same |
| `SanctionLadder` | `PROGRESSIVE_GEOMETRIC` | same |

None of these are `switch` statements in the matchmaker. The matchmaker asks the registry
for the rule named in config and calls it.
