# 09 — Decisions, open questions, gaps, risks

Updated 2026-08-18 after the follow-up session.

---

## A. Decided (locked into the Bible)

| ID | Decision |
| --- | --- |
| Q-AGE | **18+ only**, enforced at verification |
| Q-CITY | **Osijek**, slot days **Thursday / Friday / Saturday**, start times 16:00 / 17:30 / 19:00 |
| Q-ID | **AAI@EduHr deferred** (2026-08-18). An interim verifier ships behind the `IdentityVerifier` port; AAI remains the eventual target but is off the critical path (§C-1) |
| Q-BUILD | **Android first, iOS deferred** (2026-08-18). Cross-platform discipline enforced by lint, not by shipping order (§C-3) |
| Q-DESIGN | **The v2 visual design is scrapped in full.** No photographic backgrounds, no starfield, no carried-over theme. Direction and tokens are agreed through previews before any Flutter code |
| Q-GATE | **The rating gate blocks being matched again, never app access** |
| Q-COMPOSE | **Composition is a ring draw, not a score maximisation** — see [03_MATCHMAKER.md](03_MATCHMAKER.md). Ratio over {enjoyed · friend-of-enjoyed · stranger} is config |
| Q-GENDER | **One invariant replaces "2+2 or 4-same": no person is ever the only one of their gender in a group,** at every group size. Resolves C-4 and C-5 together |
| Q-SEED | **Starvation credit accrues only in good standing; a sanctioned person is never a seed.** Otherwise the frequency throttle inverts into first pick of every run |
| Q-ENTITY | **No company for now. The app is free.** If it works, it becomes €1–2/month with a one-month free trial, and *then* an obrt or equivalent is opened (§C-8) |
| Q-INFRA | **No paid infrastructure until then.** Tier-0 stack: GitHub Actions cron + `pg_cron` + Supabase free tier + FCM ([01_ARCHITECTURE.md §2](01_ARCHITECTURE.md)) |
| Q-REVIEW | **CodeRabbit reviews every pull request**; rules encoded in `.coderabbit.yaml` |
| Q-PROJECT | **Fresh Supabase project.** The v2 project is abandoned, not migrated |
| Q-RUNTIME | Dart worker sharing `ekipa_core`, **network-isolated** ([11_SECURITY.md §3](11_SECURITY.md)) |
| Q-FLIRT | **Advances, flirting and contact exchange are allowed in dating hangouts.** Governed by the *ask once* rule ([07_DATING.md §2](07_DATING.md)) |
| Q-RESPECT | Respect signal **unusable below 12 ratings** |
| Q-MODERATION | **No manual moderation queue.** Automatic adjudication on independence-weighted evidence; humans calibrate and handle appeals ([04_TRUST.md](04_TRUST.md)) |
| Q-VENUES | Self-generated venue quality (structural proxies + our own post-hangout feedback); **clusters are the matching unit** ([05_PLACES.md](05_PLACES.md)) |
| Q-2PERSON | Backfill down to two → **cancel**, unless the remaining two already have an edge |
| Q-SEVERE | *Superseded.* The old "severe bypasses everything" proposal is replaced by the graduated ladder: R0–R2 (pair exclusion, dating removal, aggressive throttle) fire immediately on one report; **nothing above R2 can fire from a single hangout** |

---

## B. Still open — I need an answer

### C-1 · Identity — AAI@EduHr deferred, what ships instead

**Decision 2026-08-18: flagged, not on the critical path.** What ships now, behind the same
`IdentityVerifier` port, so the swap costs one adapter:

**`.edu.hr` email one-time code, plus address normalisation.** A six-digit code to an
address on an allow-listed Croatian academic domain. The allow-list is config, so adding
FERIT, PFOS, FOOZOS etc. is a console edit, not a deploy.

**The part that is easy to get wrong and matters most:** without normalisation this is not
an identity at all. Before hashing, the address must be lower-cased, `+tag` suffixes
stripped, and the local part checked against the existing hash set — otherwise
`ime.prezime+1@`, `+2@`, `+3@` are three free accounts and every ban is a thirty-second
inconvenience. Ban evasion resistance is now carried **entirely** by this one function, so
it gets property tests and a pgTAP uniqueness constraint, not a code review.

**Rejected — phone/SMS as the primary anchor:** stronger against sybils, but it costs money
per signup, it is trivially rentable, and it drops the "students only" property that makes
the launch population coherent. Worth adding as a *second* factor later if evasion is
observed; not worth the cost now.

**Rejected — social login (Google/Apple):** free and frictionless, and worth nothing here —
a new account takes two minutes, so it verifies nothing that matters to us.

The original AAI notes are kept below because they are what a future conversation with
SRCE will need.

#### Background: AAI@EduHr — the access path (whenever we return to it)
AAI@EduHr is Croatia's academic identity federation, run by **SRCE**: ~230 institutions,
~1M electronic identities, built on SAML 2.0 with the hrEduPerson schema. Technically it
is ideal — a verified, institution-issued identity that is expensive to re-acquire, which
is exactly what makes ban evasion hard.

The blocker is not technical, it is administrative: a service provider normally has to be
run by, or sponsored by, a member institution, and the registration procedure is not
published in a form I could verify. **What I need from you:** contact SRCE
(`aai@srce.hr` / the AAI@EduHr support centre) or FERIT's AAI coordinator and ask three
questions — (1) can a non-institutional service be registered as an SP, and under what
sponsorship; (2) which attributes are released to an SP (specifically: a stable unique
identifier, and **date of birth**, which we need for the 18+ gate); (3) what the approval
timeline looks like. Everything else is designed around the answer, and the
`IdentityVerifier` port means the interim `.edu.hr` path costs nothing when we swap.

### C-2 · Q-STATE · Riverpod or Bloc?
Recommendation stands: **Riverpod**. Say nothing and that ships.

### C-3 · Q-BUILD · iOS — deferred, Android first
**Decided 2026-08-18.** Apple only allows iOS apps to be compiled and signed on macOS, and
an Apple Developer Program membership ($99/year) is required to reach TestFlight at all.
Google Play is a one-time $25.

The risk of "later" is that Android-only assumptions get baked in silently, so the
mitigation is structural rather than scheduled:

- **No `Platform.isAndroid` / `dart:io` platform branch outside `apps/mobile/lib/platform/`,**
  enforced by the dependency lint. Every platform difference lives behind one interface,
  in one folder, and is therefore countable.
- **No Android-only package** without a stated iOS equivalent in the same PR. `firebase_messaging`,
  `geolocator`, `permission_handler` and `flutter_secure_storage` all cover both.
- **CI still runs `flutter build ios --no-codesign` is not possible on Linux** — so instead
  CI runs `flutter analyze` with the iOS target enabled and keeps `ios/` in the repo,
  configured, from P0. The project must never *stop* being an iOS project.

When it resumes: a hosted macOS runner (Codemagic or GitHub Actions) is the cheaper route
and enough to ship; a second-hand Mac Mini is the better route the first time an
iOS-specific bug needs debugging.

### C-4 · Non-binary participants under a 2+2 rule — **decided** (Q-GENDER)
Your composition rule is "2 women + 2 men, or 4 of the same". What happens to someone who
registers as `other`?

**Recommendation:** stop encoding the rule in genders and encode it in the thing you
actually care about. The composition rule becomes one line — **no person may be the only
one of their gender in a group** — which reproduces 2+2 and 4-same exactly for a
male/female population, needs no special case for a third value, and states the safety
intention directly instead of implying it. A non-binary person is then matched into a
group containing at least one other, or into an all-same group, or waits — the same rule
everyone else is under.

**Why this beats a wildcard rule:** a wildcard that "can complete either" quietly makes
non-binary users the padding the matcher reaches for when a group is short, which is both
unfair and exactly the kind of thing that becomes a screenshot. The invariant above has no
such asymmetry. **Cost, stated:** with very few non-binary registrations they will rarely
match, and the app must say that honestly rather than pretending. That is the same
liquidity honesty G4 requires for everyone.

### C-5 · The 3-person composition problem — **decided** (Q-GENDER)
Your rule is 2+2 or 4-same. If one person declines the morning of and backfill fails, the
hangout runs with **three** — which for a 2+2 group means **1 woman and 2 men**, exactly
the configuration every safety principle in this product says to avoid. Options:

1. **Backfill only with the same gender**, and if that fails, cancel. Safest, most
   cancellations.
2. Run with three **only if** no member is left alone in their gender; cancel otherwise.
3. Run with three regardless, disclose the composition, let anyone withdraw for free.

**Recommendation: option 2, expressed as the same invariant as C-4** — *no person is ever
the only one of their gender in a group*, applied at every size. A 2+2 losing a woman
becomes 1W+2M and is cancelled; losing a man becomes 2W+1M and is likewise cancelled;
a 4-same losing anyone is fine. Backfill therefore prefers same-gender replacements first,
and cancellation is the honest fallback.

**Why not option 3 with disclosure:** the withdrawal is free in the app and expensive
socially — the person who withdraws knows the other three will notice. "You may leave" is
not a real option when leaving is visible, so the system must not create the situation.

**Why one invariant instead of two rules:** C-4 and C-5 are the same requirement at
different group sizes. Writing it once means the 3-person path cannot drift from the
4-person path, which is exactly how this hole appeared in the first place.

This needs your answer before P2, because it decides how backfill behaves.

### C-6 · Winter and the 19:00 slot
In Osijek, 19:00 in December is dark. The visibility rule ([05_PLACES.md §6](05_PLACES.md))
says stranger groups meet in daylight.

**Recommendation: make it a property of light, not of the calendar.** Compute sunset for
the city and date; a slot is `dark` if it starts after `sunset − 30 min`. Dark slots
(a) only use venues flagged indoor-tolerable and on a lit, populated street, and (b) are
not offered to all-stranger groups — a group where at least one pair already has an edge
may take them.

**Why derive it rather than configure "winter":** Osijek's 19:00 slot is fine in June and
dark in December, and a hard-coded winter window is wrong twice a year and wrong again in a
second city at a different latitude. Sunset is a function we already have inputs for.
**Cost:** the 19:00 slot loses most of its supply from November to February. That is real,
and it is an argument for launching Thu/Fri only (Risk 1) rather than for keeping the slot.

### C-7 · The safety brief wording (D12)
The meaning is canonical; the Croatian and English wording is not written.

**Recommendation, so this does not sit unwritten:** I draft all seven points in Croatian
first — short second-person sentences, no legal register, no "the Company advises" — and
you edit them as a native speaker. Drafting in English and translating produces text that
reads like a translation, and text that reads like a translation reads like a disclaimer.

Three constraints on the draft, all testable: **no sentence longer than twelve words**;
**no conditional or hedge** ("we recommend", "please consider"); **the whole brief fits on
one screen without scrolling at the largest supported dynamic type size** — because a brief
that requires scrolling is a brief whose last point is never read, and point 6 (how to
report) is near the end.

Then show it to five students who have never seen the app and ask them to say back what it
told them. Anything nobody repeats is not in the brief; it is on the screen.

### C-8 · Legal entity and data controller
Who is the controller — you personally, an obrt, a d.o.o.? This determines the privacy
policy, the DPA with any processor (Supabase, Google Cloud, FCM, Sentry), and who carries
liability.

**Decided 2026-08-18: no entity for now.** The app is free; if it works it becomes €1–2 per
month with a one-month free trial, and the entity is opened at that point. That is the right
call — an obrt to run a free pilot is a cost with no counterparty. Three consequences that
follow from it, so the decision does not quietly create problems:

1. **The pilot must not reach a public store listing under your personal name.** An
   individual Google Play developer account **publishes the developer's address on the
   listing**, and yours is your home address. **Recommendation: distribute the pilot through
   Firebase App Distribution** — free, no developer account, no address, testers install
   from a link. The Play listing waits for the entity, which also means the $25 is not spent
   yet and the account is opened in the right name the first time. Transferring a live
   listing between accounts later is a support ticket and a wait.
2. **Free changes nothing about GDPR.** A natural person operating this service is a
   controller; the household exemption does not cover it. Privacy policy, processor terms,
   and a **DPIA** are still required before real users — automated suspensions plus
   special-category data (orientation, if dating ships) put us squarely in DPIA territory
   at any user count. This is the one cost that does not scale down with the pilot.
3. **The trigger to revisit is the first euro, not the first user.** Taking payment is what
   makes an entity non-optional, and it arrives with VAT/OSS questions that need a Croatian
   accountant — obrt vs j.d.o.o. vs d.o.o., capital, tax treatment. Not something to take
   from me.

**Free now, paid later has one design consequence worth deciding early:** people who joined
free will be asked to start paying. Decide *before* launch whether early users are
grandfathered, because "we will figure it out later" becomes an announcement that reads as a
betrayal to exactly the cohort that carried the network through its thinnest phase. My
recommendation is to say it in the pilot invite: *free during the pilot, and pilot users keep
it free for a year.* Cheap now, and it converts the awkward conversation into a reason to
join early.

---

## C. Gaps still carrying their default

Unchanged from the previous round unless marked. Say nothing and the default ships.

| # | Gap | Default |
| --- | --- | --- |
| G1 | Withdrawal after locking | Explicit "can't make it" before start = late decline, not a no-show |
| G2 | "Running 10 minutes late" | One-tap canned signal with an ETA bucket. Not a chat |
| G3 | **The first week** (signup → first hangout is 4–7 days of nothing) | Biggest churn hole in the product. Show next run timing, slots marked, what happens next. Never an empty screen |
| G4 | Never matched for weeks | Never "we're having trouble finding you a group". Show honest supply info and a radius suggestion |
| G5 | Notification budget | Max 4 per hangout + quiet hours 22:00–08:00 |
| G6 | Weather | Indoor-tolerable flag on venues; rain/cold prefers them. See C-6 |
| G7 | Language | **Croatian first**, English second, i18n wired from P0 |
| G8 | Accessibility | Step-free/quiet flags on venues; screen reader + dynamic type from P0 |
| G9 | Pre-emptive blocking | Block by code-scan or after a hangout. No people-search, ever |
| G10 | Bringing a friend | Not in v1. Once the graph exists this is close to a seeded R1 draw with the pair pre-set, so revisit it then rather than building a separate invite flow |
| G11 | Frequency cap | Max 2 hangouts per person per week |
| G12 | Standby pool | Opt-in "notify me if a place opens" per slot |
| G14 | Two people with the same masked name | Disambiguate with a sigil-coloured dot, never with more surname |
| G15 | Meeting-point photos | User-submitted at arrival, auto-promoted when several agree; no console queue |
| G16 | Venue drift | One-tap "this place was wrong" → automatic demotion |
| G17 | Support channel | Required by both stores; email + form, stated SLA |
| G18 | Incident protocol | Written before the first hangout |
| G19 | Safety companion | **Now part of the mandatory safety brief** (D12 item 3) |
| G20 | Analytics + crash reporting | EU-hosted analytics + Sentry, consent-gated, PII-scrubbed |
| G21 | Console access control | Roles + MFA + audit log ([12_CONSOLE.md §5](12_CONSOLE.md)) |
| G22 | ToS, privacy policy, DPIA | Required before real users. Automated sanctions + special-category data ⇒ DPIA is not optional |
| G23 | Liability / duty of care | Terms explicit about what we do and do not guarantee |
| G24 | Rating people who did not attend | You rate only people who were present |
| G25 | Availability persistence | Repeats weekly with a one-tap confirmation; stale availability causes no-shows |
| G26 | Travel / timezone | Slots follow the city, not the device |
| G27 | Multiple devices | Token rows per device, prune on failure |
| G28 | Product name | `ekipa` assumed; change it before the store listing, not after |
| **G29** | **Gender ratio makes 2+2 infeasible** | **Recommendation: treat 4-same as a first-class outcome, not a fallback.** If men outnumber women 3:1, the surplus is absorbed by all-men groups — which is a good evening, and the app must say so in plain copy rather than implying the user got the consolation prize. Monitored on the console ratio screen from week one; if the ratio passes ~2.5:1, recruit the scarce side directly rather than letting the matcher silently starve it. **Never** solve it by relaxing the composition invariant |
| **G30** | **Cost budget** | **Settled: €0.** Tier-0 stack (Q-INFRA) has no paid component and needs no card — deliberately, since Google Cloud requires a card even for its free tier. Play's $25 and Apple's $99/yr are both deferred with the store listing (C-8, C-3). The number to watch is not spend, it is **the free tier's ceilings**: Supabase free pauses after 7 days of inactivity and caps database size, and a silently failing scheduler is what pauses it. Alert on the run, not on the bill |
| **G31** | **Backup and recovery** | **Recommendation: nightly `pg_dump`, encrypted in the job, pushed to a private store — never a CI artifact,** because artifacts on a public repository are downloadable by anyone and a backup job is the most plausible way this database ends up published. Plus **one rehearsed restore before launch, timed and written down**. Managed PITR needs a paid Supabase tier and waits for the entity. An untested backup is a hope, and the number that matters — how long a restore takes — is unknown until someone does it once |

---

## D. Risks

1. **Liquidity is the whole game.** Every mechanism degrades gracefully except the one
   needing 30–50 available people *per slot*. Below that, the app is a beautifully
   engineered "no hangouts this week".

   **Recommendation: launch with Thursday and Friday only, and one start time — 17:30.**
   Three days × three start times is nine buckets; with 50 signups at 60% availability
   that is ~3 people per bucket and the matcher forms nothing. Two days × one time is two
   buckets, ~15 people each, which is a functioning market. Saturday and the 16:00/19:00
   slots are **config**, added the week the console shows a bucket consistently oversupplied.

   **Why one start time rather than three:** a person choosing among three times splits
   themselves, not just the population — most people mark one. Concentration is the only
   free liquidity in the product, and it is reversible in a config edit.
2. **Fully automatic trust is the right call and it will produce a wrong ban eventually.**
   The independence gate makes it rare; the appeal path makes it recoverable; the
   calibration sampling makes it visible. What it cannot be is *impossible*.
3. **The trust system can strangle a young network** — suspending ten people in a city of
   sixty removes a sixth of supply. Start lenient, tighten with density; the simulator
   must show the suspension rate before launch.
4. **Dating changes who downloads the app.** Unlock threshold, minority budget, kill
   switch. Keep it a flag forever.
5. **Gender/orientation data is special-category** under GDPR. Explicit separable consent,
   and a DPIA.
6. **You are one person.** Even with no moderation queue, appeals + venue cold start +
   support + config tuning is real weekly time. Design the console so a second person can
   be handed a role, and budget the hours honestly.
7. **The `really_enjoyed` channel will be gamed** — accepted per your decision, and safe
   because it carries no friend-matching weight. Watch the distribution anyway; if it goes
   above ~60% of ratings, dating seeding needs a different input.
