# 07 — The dating layer

Rewritten 2026-08-18. **Your call on in-person advances is adopted**: in a dating hangout,
where every person has opted in, flirting, advances and exchanging contacts are allowed.
My post-hoc-only proposal is withdrawn — the amendment is logged in
[00_BIBLE.md](00_BIBLE.md). What follows is that decision, engineered.

---

## 1. What this layer is for

Your framing, which is the design brief and is more clear-eyed than most dating products
manage:

> The purpose is **a pressure valve**, not a great dating experience. People want to date;
> if there is nowhere to do it, that intent leaks into friend hangouts as hints and subtle
> pressure — the exact thing that ruins the friend product. Give it a room of its own, and
> the friend product stays clean.

**Therefore the success metric is not matches made. It is romantic conduct *leaving* friend
hangouts.** That is what the pilot measures ([12_CONSOLE.md §4](12_CONSOLE.md)): does the
rate of romantic-conduct reports in friend hangouts fall for people who have dating
available? If yes, the layer works even if nobody ever pairs off.

This reframing also settles the signal-gaming question. Men will press `really_enjoyed` on
women they find attractive. Accepted, priced in, and harmless — because `really_enjoyed`
carries **no weight in friend matching** ([02_DOMAIN.md §5](02_DOMAIN.md)), so the
friend graph cannot be corrupted by it. The only thing it corrupts is dating seeding, and
dating seeding is a soft preference, not a promise.

---

## 2. The rule that makes "advances allowed" enforceable

Permission without a norm is just ambiguity, and ambiguity is what this population cannot
afford. So the rule stated to everyone, at confirmation and at reveal, is one sentence:

> **You may ask. Ask once. Then take the answer.**

- **Allowed:** flirting, complimenting, asking someone out, offering your number, saying
  you had a good time and would like to see them again.
- **Reportable:** asking again after a no. Not letting a topic drop. Touching without
  invitation. Isolating someone from the group. Following someone, or following them out.
  Pressuring for contact details. Anything continuing after "no", "maybe another time", or
  a change of subject.

**Why "ask once" is the right line:** it is observable, it is memorable, it survives being
explained in one line, and it precisely separates the thing you want to permit (interest,
which can be misread in either direction) from the thing that actually harms people
(persistence, which cannot be misread). It also gives the reported person a fair defence
that the system can evaluate — *did it happen once, or did it keep happening* — which a
vaguer rule like "don't be creepy" never could.

**Leeway, as you asked for:** a first-time `CONDUCT` report inside a dating hangout is
weighted lower than the same report in a friend hangout, because signals genuinely get
misread when advances are permitted. What is **not** discounted: the independence gate
([04_TRUST.md §4.3](04_TRUST.md)) still applies, and reports across two independent
contexts still escalate at full weight. One awkward evening is forgiven; a pattern is not.
Severe categories (touching, following, threats) get no leeway at all.

---

## 3. The shy path stays open

The post-hangout mutual signal survives — not as a replacement for asking in person, but
as an *additional* channel:

At the end of a dating hangout, alongside the normal ratings, one private question per
compatible member: **"Would you like to meet them one to one?"** Mutual yes → both are
told, contact exchange offered. Non-mutual → nothing happens, to anyone, ever.

**Why keep it when in-person asking is allowed:** the people this product exists for are
frequently the ones who will not ask in the moment, and losing them would make dating mode
a room where only the confident participate — which is the dating app they already
declined. Two channels cost nothing and cover both temperaments. A `no` here never affects
the friend graph.

---

## 4. Unlock

Dating becomes available when all hold (all config):

- `completed_hangouts ≥ dating_unlock_hangouts` (default 5, your range was 4–8) **with at
  least 4 distinct people**, so the threshold cannot be farmed with one friend
- reliability standing clean
- respect posterior above `respect_floor_dating` **and** at least **12 respect ratings**
  (your number — below that the signal is noise)
- explicit, separately revocable consent for storing orientation data (GDPR Art. 9 special
  category; cannot be bundled into general terms)
- 18+, verified

**Why an unlock:** the friend product becomes the on-ramp rather than a lobby, we get
behavioural evidence before putting anyone in a higher-stakes room, and someone who joins
*for* dating must first be a decent participant in ordinary hangouts — a filter no
questionnaire replicates.

---

## 5. Composition, and the ratio problem you raised

**The constraint** (generalises your 2+2 without a special case):

```
compatible(a,b) ⟺ b.gender ∈ a.interestedIn ∧ a.gender ∈ b.interestedIn
                  ∧ ¬excluded ∧ standing ok ∧ respect ok

∀ member m: |{x ∈ group : compatible(m,x)}| ≥ min_dating_candidates   (default 2)
```

For four straight people this yields 2W+2M automatically; it also handles an all-women
group where everyone is interested in women, and bi participants, with no branching.

### The imbalance, addressed directly

You are right that men will outnumber women, and right that a man going through four
dating hangouts with no signal is the failure mode. Four mechanisms, each aimed at a
different part of it:

1. **The scarce side sets throughput.** A dating hangout forms only when the composition
   constraint is satisfiable — so the number of dating hangouts is bounded by how many
   women opt in for that slot. There is no mode where the system runs dating hangouts by
   stretching. Fewer, real hangouts beat more, hollow ones.
2. **Fair queueing on the abundant side.** Men are selected by longest-waiting-first, not
   by score. Without this, a handful of men with strong `really_enjoyed` signals absorb
   every dating hangout and everyone else waits forever — the dating-app dynamic you are
   trying to escape, reproduced inside our app.
3. **A per-person cooldown on dating hangouts** (default 1 dating per 3 friend hangouts).
   This is not only about supply: it stops anyone burning through five dating hangouts in
   a month and concluding the product is a failure. Scarcity here protects the experience.
4. **The floor is a decent evening, not a match.** A dating hangout is still a hangout: an
   activity, four people, ninety minutes — and **it still forms friend edges**. Someone
   who never gets a romantic signal still leaves with people they liked. This is the
   single most important design decision for the imbalance problem, and it must be said
   plainly in the app: *"This is an evening out with people who are open to more. Most
   evenings will just be a good evening."*

**What we do not do:** we never fabricate signals, never show "someone liked you"
teasers, never rank by attractiveness, never charge for visibility. Every one of those is
how the dating-app dynamic gets imported, and importing it would defeat the point of
having a valve at all.

---

## 6. Frequency

Two independent controls:

1. **Per person:** at most one dating hangout per `dating_ratio` friend hangouts
   (default 1:3).
2. **Global per run:** at most `dating_share` of a run's hangouts (default ≤25%), and only
   where the compatible pool is deep enough.

**Why a global budget as well:** an unbudgeted matcher would consume the scarce side to
build dating hangouts and degrade the friend product for everyone. The friend product is
the foundation; the valve is not allowed to cannibalise it.

---

## 7. Safety profile

| Mechanism | Friend hangout | Dating hangout |
| --- | --- | --- |
| Respect gate | throttle below floor | **hard exclusion** below floor |
| Reliability standing | `WATCHED` allowed | clean only |
| Meeting point | vetted | vetted **and** public **and** populated; daylight-leaning for first ones |
| Conduct reports | standard weights | first-offence leeway; **no leeway** on severe or on persistence |
| Composition | per rule | never a lone woman; never someone who is the only member of both their gender *and* their orientation |
| Safety brief (D12) | full | full, plus the ask-once rule and *"you are never obliged to give your number"* |
| Group size | 3–4 | **4 only** — a 3-person dating hangout with one compatible pair is a date with an audience |

**The risk we are not pretending away:** a dating layer changes who downloads the app, and
their behaviour will be different. Defences, in order: the unlock threshold (you cannot
arrive and immediately date), the minority-share budget, and the kill switch. **The kill
switch is the real one** — the whole layer stays behind a config flag permanently, and the
pilot's guardrail metrics can turn it off automatically.
