# The Bible — founding transcript, v3

**Status: canonical. Nothing in this repo may contradict this document.**

This is the verbatim vision transcript from the user, recorded **2026-08-18**. Every
other document in `docs/v3/` is derived from it and must cite it. When a derived
document and this document disagree, this document wins and the derived document is
wrong and must be corrected.

Rules for this file:

1. **Never edit the transcript body.** It is a record of what was said, not a spec that
   drifts. Corrections, refinements and decisions go in the *Amendments* log at the
   bottom, each dated, each stating what it supersedes.
2. **Every design decision elsewhere must trace to a line here, or to an amendment.**
   If it traces to neither, it is invention, and invention needs approval before it is
   built.
3. Where the transcript is deliberately open ("we need to think about this", "make it
   configurable", "suggest"), that openness is itself the requirement — it means the
   mechanism must be a *parameter*, not a hard-coded constant. See
   [09_OPEN_QUESTIONS.md](09_OPEN_QUESTIONS.md).

---

## Transcript — 2026-08-18

> we need to redesign the whole thing. some aspects stay the same but i want you to
> review the code and flag all previous code we had as BAD CODE. We want GOOD CODE, and
> we want to reuse existing logic but mostly make from scratch.
>
> This is the new idea, I will present it in mechanisms i think of on the spot, i want
> the app to be written with clean code and oop patterns where applicable to make it
> modular, testable, reusable etc. Algorithms need to be uncoupled from the code so they
> can be resued throughout the app etc. And same applies for the database and backend.
>
> So there should be signup or onboarding with some kind of ID, for now we could use
> AAIeduhr for students or suggest some, but later we will probably use personal ID card
> verification or another card.
>
> The user should set times they are available for a hangout this week. The times should
> be simple to select, so make them slots of 1.5 hours. We can pick a few days from the
> master console, suggest 2-3 days of the week. The hangouts should be in the afternoon
> or early evening, so my guess is 16:00 to 19:00, thats 3 slots, 16:00, 17:30, 19:00,
> these are start times, and we put them 2-3 days of the week. That should be good for
> now. Also it should be expandable so at some point we may put an indicator background
> behind slot that indicates its a good time to pick as you are likely to find a hang
> out.
>
> A meetup event should be called a hangout. A hangout consists of 4 people, 2 guys and
> 2 girls or 4 of same gender. Make this expandable so we could later easily add other
> options.
>
> There should be a matchmaker, this is code on the backend that periodically (maybe
> once a day but suggest or make it easily changeable in master console) creates
> matches, this is a complex algorithm.
>
> The app should have locations, for cities, like Osijek etc., there should be areas,
> now these areas are hard to do manually as the app will possibly grow, and i want it
> to work automatically, so suggest how we can find a city's area on a map and pick a
> few busy areas in the city, what i mean by that is, for example downtown, upper city,
> lower city. So when a hangout is formed the users will select their preferred areas to
> have the hang out.
>
> The morning of the hang out (make it easily changeable from master console when), the
> users of the specific hangout will receive a notification to confirm they will be able
> to attend the meet. If they all agree, then the meet location will be selected from a
> list of popular bars / restaurants / hangout spots in the city, the point is not
> hanging out in the bar (at least in summer), but actually meeting there and hanging
> out wherever, its up to the group, because its impossible or hard to find good spots
> automatically for all cities around the world.
>
> If one of the users declines the confirmation, the algorithm should try to fill in one
> extra person or if it cant, the meet should still happen with 3 people. We need to
> track users' activity, so if a user declines 2 morning confirmations in a row (2
> separate meets they got into), they should be penalised, we have to think about this.
>
> If the user is from a smaller place that is maybe not an official city on our app etc.
> Maybe still pick some nearby restaurants etc? Or actually the areas approach needs
> focus, because areas are abstract and potentially unnecessary.
>
> The meeting spots / restaurants etc. should be automatically picked for the city based
> on popularity or something. Maybe actually regarding areas, we ask the users to pick a
> nearby restaurant / meeting spot on a map, to mark their approximate location or we
> use location permission to get their location, and then we can use it as a signal to
> be considered when matchmaking.
>
> Regarding hangout activities, i have some off the top of my mind, the best one for
> introverts in my mind is card games, so there should be a way for a person to bring
> cards to the meet, we need at least 2 people with cards in a normal card game meet,
> because one can dip.
>
> Another activity i can think of is talking / getting to know someone new, we could do
> this with those best questions to get to know someone in an hour you mentioned from
> research paper, we could do 3 easy ones from a list of like 10 premade ones, then run
> the rest from that list from research paper, but skipping some, for example, we pick 3
> easy ones from the easy list made off of easy question from that paper first, then we
> pick randomly selected ones from the paper for the rest, but do them in the same order
> as the test, so no shuffling, because im guessing theyre progressive. A talking
> activity doesnt restrict the people to doing those questions, theyre just a template
> for something to do so its not undefined. The template should be available to the
> people in app once they press theyve found the group when a meeting starts.
>
> The 2 activities are fine for now. Also We need to think the activity itself, when the
> meet is about to start for example hour to half an hour before, the app should show
> the participant the location of the meeting point on the map, and their group's
> symbol, we need to be careful not to have 2 groups meet at the same meeting point or
> at least not have the same symbol.
>
> Then when all of them press theyve arrived, they get their question templates if they
> are in talking activity etc.
>
> If not all members arrive within 15 minutes they should have the option to press that
> in the first half hour of the activity, they should be able to report someone being
> late or dipped, the app should make it clear this is their duty and every participant
> has to press it on their own phone, not just 1 per group. The person who dipped or is
> late gets penalised.
>
> At the end of the activity, each participant ranks every other member by how much they
> liked hanging out with them (Really enjoyed it, Enjoyed it, No preference, Id prefer
> not to see them again or similar).
>
> The positive two will be used for matchamking in the first place. Those two become
> friend connections, we will need to think how to correctly weigh them when
> matchmaking.
>
> The participants should also rank every other member by Were they respectful? (Yes,
> No), this will be used as a cheap signal for quality of person. For example, we often
> tend to view people as pleasant or unpleasant, and while a good part of it SHOULD be
> accounted for by friend networks (because bad people would hang out with their own
> kind and good with their own), respectfulness could be a useful signal for throttling
> the match frequency someone gets, so the meets remain civil.
>
> The algorithm has to take all of this in account, and it should create meets of 2
> people who know each other and 2 who know each other but the two groups dont know each
> other? Make it configurable, we need to think about this. Also there is edge case
> where the other 2 are strangers or first time using app.
>
> What i would like to add, but we can definitely hold off on it for enabling for now,
> but im really leaning towards enabling it, is dating. YES, i know you said buddy dont
> add dating its going to ruin the show. The thing is, if i make the app EXPLICITLY SAY
> NO DATING OR ADVANCES IN A MEET OR YOU GET BANNED (Yes, forgot to mention but make
> this explicit when the meet is about to start or morning of etc..), then im afraid you
> will just get guys who are quiet about their feelings which is fine, but they might
> start GIVING HINTS OR SUBTLY FLIRTING, to me this a bad case. But if you say dating is
> explicitly forbidden in meets, but after 4-8 meets you unlock it, and you can then
> enable the option that you are available for dating it could work.
>
> My idea is that when you unlock it and you enabled it, you still get normal meets, but
> occasionally (once every 3 meets for example but it wont be that easy to regulate so
> we need to think about it, maybe the matchmaker will decide globally and then determine
> frequency that way), you get date meets, where there are 4 people who can pair 2 on 2.
>
> So this part is tricky, because you need their preferences for which gender they want
> to meet (could include both since bi) and which gender they identify as (we already
> have this part since its used in normal meet). So my idea was, lets think straight
> people, then you have 2 girls and 2 guys in a meet. And dating and exchanging numbers
> is explicitly allowed but flirting is forbidden or do we allow it? Im not sure how to
> algorithmically properly mix the people so that every person has 2 potential dates /
> future partners in that meet or if its possible.
>
> Also regarding dating meet, the whole point i think, is that it matches you based on
> your previous liked connections, specifically the really enjoyed ones. My idea was that
> as you meet people you naturally press you really enjoyed hanging out with those who
> could be potential partners. Note how you said this corrupts likeness signal, but id
> argue it might make it better, because enjoyed and really enjoyed we could make it so
> they dont carry any difference regarding normal meets, but really enjoyed is only used
> for dates, this way its actually a signal, you said we risk having them press really
> enjoyed on people they would date and it would corrupt signal, but what if we want them
> to do that, we still use it as a normal signal theyd hang out again AND a signal that
> theyre open to dating them.
>
> Also here is where the were they respectful? signal comes in handy, we could maybe
> categorize people by how respectful they are and match respectful ones with other
> respectful ones, this would filter for bad apples hitting on the opposite match
> participants in creepy ways etc. but might need testing to confirm we have enough data
> about them to use the signal, for example if they have 3 ratings the noise is high. Its
> worth looking into this for friend meets as well, not just dating ones, but id be
> cautious cause this could corrupt our algorithm which is very simple and should be
> effective in nature.
>
> Also i just forgot to tell you, the after meet rating are mandatory, the app should
> demand them as its your duty to keep the environment of quality, but if you force the
> user to rate others they might randomly press the ratings just to get through it, maybe
> we make a mandatory delay of 2 seconds per rating, so they have to sit through it
> regardless?
>
> Now thinking about it, if 2 people dip the morning of, should we still try to scrap
> together a match for a few hours then send a notification in case we couldnt, maybe
> there should always be a few hours buffer after the invite where the matchmaker pays
> attention, also after that period if someone didnt accept or decline the confirmation
> they should be penalised immediately?
>
> Regarding the nature of the algorithm, it should take the signals we mentioned into
> account, like distance between participants in meet and select them from peoples friend
> connections nodes list. This will need some real work to make sure its well designed
> specifically the signals cause they affect the core model.
>
> Regarding privacy, only thing stored in the app should be a hash or some kind of coded
> value that uniquely identifies that person, regardless if they used personal ID or
> aaiEDUhr or other, so that if they are penalised they cant evade it. Also we should
> store their first name from such document and the last letter of their last name. In
> app this will be shown as Marko ****n for example. Also maybe their location when using
> the app from the location permission, and their identified gender and if they selected
> dating then their interest genders as well. Make dating a separate tab up top to the
> normal meet tab.
>
> Regarding penalising we need to talk about it, i think for smaller offences it should
> maybe ban the user for a week or something (must be configurable) and for repeat
> offences for a longer time, some algorithm where it gets progressively worse. Also
> regarding creep behaviour, there should be a button after meet where you can report any
> user, if that user gets reported in 2 meets in a row in total by at least 4 people we
> need to immediately ban them for 3 months, also if a user reports 2 meets in a row we
> should put a silent ban on their reports for 2 weeks, and possibly think about
> progressive bans? The ban / penalising system appears in many places so maybe we should
> think carefully, it might be a single reusable code.
>
> Tell me which parts i missed or need clarification.
>
> The app should be available for google play store and IOS.
>
> The app is going to be written in flutter.
>
> I attached reference app images to use as inspiration. I want you to split them into
> separate screens / views since theyre a set of views side by side in images, and group
> by app.
>
> I want you to make a plan how to do this. Think like a systems engineer. Everything is
> systems, nothing is just do it like this, there has to be WHY are why doing it like
> this, INTENTION.
>
> Suggest mcps i could add that will help you design properly. You must suggest.
>
> Save this transcript in a file and treat it like the bible. Lets talk about the plan.

**Attachments:** eight side-by-side reference screenshots (Opal ×2, Posh ×2,
Polarsteps ×2, Places ×2), split per-frame into
[`docs/reference/`](../reference/README.md).

---

## Transcript — 2026-08-18, follow-up (canonical)

> The matchmaker should have nothing to do with the app the user receives, the matchmaker
> should run somewhere safe where no user could touch it or see it. To me this seems
> logical to be on the backend. If you need to make an interface for it in dart thats
> fine. I just want a rigid security framework here and strong principles to make sure we
> dont mess this up.
>
> Also there needs to be a master console where i can view everything and adjust
> configuration of parameters i mentioned. When i say view, i mean i want to be able to
> see the ratio of guys / girls and be able to see matches made and feedback, and what
> they rated others etc. the core privacy model is in no personally identifiable data
> stored on server, which means i can look at all the data rent free without invading
> their privacy. Also at some point for dating for example i would want to run tests on a
> limited amount of people in the city, so we would need to randomly select a percentage
> of users to run different funcionality on etc. You dont have to implement it now, but i
> want the console funcionality.
>
> We need a huge emphasis on safety and security in the app. I dont want someone hacking
> it or altering it. I want you to find me resources like a list of mobile app security
> measures for ai coding so you have a checklist and that youre rigid on that. Also i
> forgot to mention, in app before a meet, the app should always disclose to stay safe
> and not ride home with anyone etc. Add this part to bible.
>
> 1. Ideally i want the app to be self sufficient, so if it would be possible to pull for
> example all bars or restaurants with at least 10 ratings and 4.5 stars for example then
> plot them on the map and divide into areas or maybe better, simplify them into clusters
> by distance maybe and then the matchmaker pairs users based on cluster distances and
> before meet the matchmaker picks a bar / restaurant out of that cluster.
>
> 2. Ideally id like the app to be self sufficient. This could be configurable behavior
> and we tune it, but manual review is tough, although valid but its tough for an app
> that only one or two people moderate. So maybe manual review can be used to determine
> how the configured settings are doing, but not more? We could make it so as a user uses
> the app more they get more trust score so they are more immune to random reports, but
> problem is, there are from my own experience people who like to harass others, and if
> you get reported by 2 people who know each other in a single meet, that shouldnt ban
> you for a long time and maybe not even a week, 2 meets gives better chances that you
> actually are the offender. Like i said possibly a trust system here, its complicated we
> need to think about it.
>
> 3. Again, manual review is a no no
>
> 4. Agreed.
> 5. Agreed
>
> 6. Im worried about this one because im guessing men are going to be more populous in
> the app, and that would mean a guy could go through 3-4 or more dating meets (which are
> by their nature probably going to be more rare than normal) without getting any signal
> from anyone, seems like we are back at dating apps then and im afraid the guys will get
> desperate, on the other hand, if a girl picked she is down for dating, and the guy did
> as well, who am i to say no flirting or advances or exchaning numbers? The whole point
> of the mode is so they have a vent to do it. Of course if someone is pushy etc. they
> will get reported and penalised just like in normal meet, maybe we can add leeway to
> date mode cause advances can be misread etc. Im not sure i agree with you on this one
> bub.
>
> 7. i understand the gaming effect. and im sure since dating app mechanism will translate
> probably, that guys will be really enjoying all girls they like, its fine, i dont care
> about this. For me, the point of the dating mode isnt necessarily awesome dating
> experience, i dont think that is possible. I think its purpose should maybe be just a
> vent to date, cause people want that and it fills them up, so girls will get matches
> easily which is good cause they are the fewer population, while guys might find it hard
> to find matches but will still get to hang out sometimes, if guys find they dont like
> the dating mode i dont care. I care that they move their business away from normal
> friend mode.
>
> 8. Should be unusable below 12 ratings, cause most people are going to press respect.
>
> 9. explain this one to me. i dont understand you
>
> 10. again, not sure i understand.
>
> age 18+, yes for now. safest that way.
>
> lets do aaieduhr for now. im not sure how this works.
>
> yes burn supabase.
>
> ios build capabilty, im not sure what this means
>
> Osijek, Croatia, maybe do thursday, friday, saturday?
>
> What else didnt i adress?

---

## Standing directives extracted from the transcript

These are the sentences that constrain *how* we build, as opposed to *what*. They apply
to every file in the repo.

| # | Directive | Consequence |
| --- | --- | --- |
| D1 | "flag all previous code we had as BAD CODE" | Everything pre-2026-08-18 is quarantined, never imported, never extended. [LEGACY_AUDIT.md](LEGACY_AUDIT.md) |
| D2 | "clean code and oop patterns where applicable… modular, testable, reusable" | Ports-and-adapters, dependency rule points inward, no IO in domain. [01_ARCHITECTURE.md](01_ARCHITECTURE.md) |
| D3 | "Algorithms need to be uncoupled from the code so they can be reused throughout the app" | Algorithms are pure functions in `ekipa_core`, runnable in app, worker, console and simulator alike. |
| D4 | "same applies for the database and backend" | Schema is versioned and owned by migrations; invariants live in the DB, not in callers. |
| D5 | "make it easily changeable in master console" (repeated ×4) | Every number in the product is a versioned config value, never a literal. [01_ARCHITECTURE.md §Config](01_ARCHITECTURE.md) |
| D6 | "Make this expandable so we could later easily add other options" | Composition, activities, identity providers and sanctions are registries of strategies, not `if` chains. |
| D7 | "there has to be WHY… INTENTION" | Every doc states the rejected alternative next to the chosen one. A decision without a discarded option is not a decision. |
| D8 | "The app should be available for google play store and IOS" | Both stores remain the destination. **Shipping order deferred 2026-08-18 to Android-first**; the no-Android-only-shortcuts requirement stands and is enforced by lint, not by schedule (see the amendment log). |
| D9 | "The matchmaker should have nothing to do with the app the user receives… run somewhere safe where no user could touch it or see it" | **The matchmaker is unreachable.** No client-callable path to it, no public endpoint, no service-role credential in any user build. Enforced structurally, not by convention. [11_SECURITY.md](11_SECURITY.md) |
| D10 | "manual review is a no no" · "manual review can be used to determine how the configured settings are doing, but not more" | **Automation adjudicates; humans calibrate.** Trust decisions are automatic. Human attention goes to tuning thresholds against sampled outcomes, and to appeals — never to a per-case queue. [04_TRUST.md](04_TRUST.md) |
| D11 | "Ideally i want the app to be self sufficient" (×2) | No ongoing per-city manual labour in the venue pipeline, moderation queue, or matching. Every mechanism must degrade to something automatic. [05_PLACES.md](05_PLACES.md) |
| D12 | "in app before a meet, the app should always disclose to stay safe and not ride home with anyone etc." | **The safety brief is mandatory and unskippable**, shown at confirmation and again at reveal. Not a settings page, not a one-time onboarding card. [SB below](#the-safety-brief-d12) |
| D13 | "i want a rigid security framework here and strong principles" | Security is a checklist with named controls, verification methods and CI gates — not an intention. [11_SECURITY.md](11_SECURITY.md) |

---

## The safety brief (D12)

Mandatory, unskippable, shown **twice**: on the morning-of confirmation screen, and again
on the reveal screen an hour before. Both times it must be read past, not dismissed by
reflex — a short deliberate scroll or a hold-to-continue, never a checkbox that a thumb
finds without the eyes.

Content, fixed (wording to be finalised in Croatian and English, meaning is canonical):

1. **Meet at the meeting point. Do not go anywhere private with someone you just met.**
2. **Do not accept a ride home, and do not offer one.** Leave the way you arrived.
3. **Tell someone where you are.** One tap shares the place, time and end time with a
   contact of your choosing.
4. **You can leave at any time, for any reason, with no explanation.** Saying "I'm going
   to head off" is normal and nobody will be told why.
5. **Nobody in this group has been checked by us beyond a verified student identity.**
   Say the true thing about what verification does and does not mean.
6. **Report anything that felt wrong** — it is private, the person is never told, and you
   will never be matched with them again.
7. *(Friend hangouts)* **No advances, no flirting, no asking anyone out.** If you want
   that, dating mode exists.

Rationale: the two most dangerous moments in a stranger meeting are *leaving the public
place* and *the journey home*. Everything else in this product's safety design is
statistical; this is the one place where a sentence read at the right moment is the whole
control.

---

## Amendments

Append only. Format: date · what changed · what it supersedes · who decided.

| Date | Amendment | Supersedes |
| --- | --- | --- |
| 2026-08-18 | Bible created from the founding transcript. v1/v2 docs archived under `docs/legacy/`. | `docs/PLAN.md`, `docs/GRAPH.md`, `docs/PRODUCT.md`, `docs/DESIGN.md`, `docs/REBUILD_PLAN.md`, `docs/FINALIZATION_PLAN.md` |
| 2026-08-18 | **Follow-up transcript added** (above) with directives D9–D13 and the safety brief. | — |
| 2026-08-18 | **Decisions locked:** 18+ only · launch Osijek, Croatia · slot days Thu/Fri/Sat · AAI@EduHr is the identity target (interim `.edu.hr` email code while federation access is obtained) · fresh Supabase project, old one abandoned · respect signal unusable below **12** ratings. | Q-AGE, Q-CITY, Q-ID, Q-PROJECT open questions |
| 2026-08-18 | **Dating: advances, flirting and contact exchange are ALLOWED in dating hangouts** by both-parties opt-in. Pushiness remains reportable, with stated leeway for misread signals. | My recommendation in [07_DATING.md](07_DATING.md) §1 that interest be expressed post-hoc only. User reaffirmed after the concern was raised; their call, implemented as stated. |
| 2026-08-18 | **Dating mode's purpose is a pressure valve, not a dating product.** Its success criterion is that romantic intent leaves friend hangouts — not that anyone finds a partner. Signal gaming (`really_enjoyed` on everyone attractive) is accepted and priced in. | — |
| 2026-08-18 | **No manual moderation queue** (D10). Trust and reports are adjudicated automatically on independence-weighted evidence; humans see sampled decisions for calibration and handle appeals only. | [04_TRUST.md](04_TRUST.md) §6 as originally written |
| 2026-08-18 | **Venue catalogue must be self-generated** (D11). Star ratings from Google are not legally storable and no permissive source carries them; quality signal comes from structural proxies plus our own post-hangout meeting-point feedback. Clusters are the matching unit. | [05_PLACES.md](05_PLACES.md) §4 as originally written |
| 2026-08-18 | **The rating gate blocks *being matched again*, never app access.** An unrated past hangout makes you ineligible for the next match run and nothing else. | — |
| 2026-08-18 | **AAI@EduHr deferred.** Ship an interim verifier now behind the `IdentityVerifier` port; AAI remains the target but is not on the critical path. | Q-ID as locked earlier the same day |
| 2026-08-18 | **iOS deferred; Android first.** Cross-platform discipline is preserved by lint (no `Platform.is*` branch outside `apps/mobile/lib/platform/`), not by shipping both at once. | D8's "day one" reading |
| 2026-08-18 | **Venue pipeline approved with a simplicity constraint:** *"dont overcomplicate the filtering because it could produce shit results."* Ingestion filters are a short, auditable list; ranking refinement comes from real post-hangout feedback, not from more filters. | [05_PLACES.md](05_PLACES.md) §3 structural-proxy scoring as originally specified |
| 2026-08-18 | **The v2 visual design is scrapped in full** — no photographic backgrounds, no starfield, no carried-over theme. The design system is rebuilt from scratch, agreed through previews *before* any Flutter code is written. | `lib/widgets/starfield.dart`, `assets/backgrounds/*`, the v2 theme, and the "reference direction" wording in [08_ROADMAP.md](08_ROADMAP.md) P0 |
| 2026-08-18 | **Composition is a ring draw, not a score maximisation.** Each group is seeded on one person and their partner is drawn from a configured ratio over three rings — people they enjoyed, friends of people they enjoyed, strangers. Named the single most important algorithm in the app. | [03_MATCHMAKER.md](03_MATCHMAKER.md) §3 group score and §4 template registry, pending confirmation of the restatement |
| 2026-08-18 | **Tooling:** Appium MCP, UI/UX Pro MCP and Context7 added to `.mcp.json`; **CodeRabbit reviews every pull request** via `.coderabbit.yaml`. | [10_TOOLING.md](10_TOOLING.md) §1 as originally written |
| 2026-08-18 | **Seed selection is standing-gated.** Starvation credit accrues only in good standing and a sanctioned person is never a seed — otherwise the frequency throttle inverts into first pick of every run, silently. User's catch. | "Assembly — greedy, seeded by starvation" in [03_MATCHMAKER.md](03_MATCHMAKER.md) §⑤ |
| 2026-08-18 | **One composition invariant replaces "2+2 or 4-same": no person is ever the only one of their gender in a group,** at every group size. Resolves the 3-person backfill hole and the non-binary question with the same rule. | The 2+2 / 4-same rule as a pair of cases; the "at least one unconnected member" invariant, deleted as contradicting the requested 2+2 |
| 2026-08-18 | **No company, no paid infrastructure, app is free.** Monetisation, if it comes, is €1–2/month with a one-month trial, and the entity opens then. Tier-0 stack: GitHub Actions cron + `pg_cron` + Supabase free tier + FCM; pilot distribution via Firebase App Distribution, not a Play listing. | [01_ARCHITECTURE.md](01_ARCHITECTURE.md) Cloud Run topology; [09_OPEN_QUESTIONS.md](09_OPEN_QUESTIONS.md) C-8 "form a company before the listing" |
| 2026-08-18 | **Visual direction locked: "Zar"** — deep slate ground (`#131719`), ember accent (`#FF6B3F`), sand reserved for people and places, and a serif used only for the names of people and venues. Chosen after four proof rounds; the register comes from the reference set in [docs/reference](../reference/README.md), not from a metaphor. | Proofs 01–03 (Papir/Sumrak/Riso, five dark directions, the chalk ladder), all rejected |
| 2026-08-18 | **Legibility is a product requirement, not a preference.** No script or decorative face anywhere; nothing below 14.5sp; no texture noise behind text. Twice user-reported as physically uncomfortable, so it is a constraint on every future screen rather than a note on one. | The handwriting rungs of proof 03 |
