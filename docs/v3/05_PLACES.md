# 05 — Geography, clusters, meeting points, sigils

Rewritten 2026-08-18 to adopt your cluster model and directive **D11** (self-sufficient —
no ongoing manual labour).

**The model in one line:** people have an **anchor point**; venues are pulled
automatically and grouped into **clusters**; the matchmaker matches on *shared reachable
clusters*; a specific **meeting point** inside the winning cluster is picked at lock time.

That is your proposal, and it is better than what I had — because a cluster is a stable,
automatically-derived unit that both the matcher and the venue picker can use, while
"areas" were a hand-authored taxonomy and raw pairwise distance gave the matcher nothing
to name.

---

## 1. Why not hand-authored areas

| Problem | Consequence |
| --- | --- |
| Per-city taxonomy someone must author | Contradicts D11 outright |
| Do not exist in villages | Your own edge case has no answer |
| Coarse and unstable | Two people in one "area" can be further apart than two across a boundary |
| Adds a user decision | Every choice before a hangout is a place it can dissolve |

Clusters have none of these: derived from venue positions, recomputed on ingestion,
nameable-if-convenient, meaningless-if-not.

---

## 2. The anchor point

At onboarding: *"Where do you usually set out from?"* — a draggable pin, optionally
seeded by a one-shot coarse location fix.

- Stored **snapped to a ~500 m grid**. Useful for "twenty minutes away", never a home
  address in the database.
- Never displayed to anyone. Matching input only.
- Location permission is optional and never a gate — a pin is as good and cheaper in
  trust. Denial paths are first-class.
- Plus one control: **how far are you willing to go** (walk / short ride / anywhere in
  town) → the person's `max_travel`.

**Rejected — background location:** far more sensitive, store-justification burden,
battery cost, and it buys nothing, because hangouts are planned days ahead from where a
person usually is.

---

## 3. Where venue data can legally come from

You asked to *"pull all bars or restaurants with at least 10 ratings and 4.5 stars"*. I
checked, because building on this and finding out later would be expensive:

| Source | Licence | Has ratings? | Can we store it? |
| --- | --- | --- | --- |
| **OpenStreetMap / Overpass** | ODbL | ❌ none | ✅ yes, with attribution + share-alike on derived DBs |
| **Foursquare OS Places** | Apache 2.0 | ❌ — the open schema is 26 fields (id, name, coords, address, contact, categories, dates); ratings/popularity are Pro/Premium only | ✅ yes |
| **Overture Maps places** | CDLA-Permissive 2.0 (+Apache for FSQ-sourced) | ❌ confidence score, not ratings | ✅ yes |
| **Google Places** | Google ToS | ✅ ratings + review counts | ❌ **no.** Only `place_id` may be stored indefinitely, and coordinates for ≤30 days. Names, ratings, reviews and photos have **no caching exception** — they must be fetched live and displayed with attribution |

**So the "≥10 ratings, ≥4.5 stars, stored in our database" catalogue is not legally
available from any source.** Google has the data and forbids keeping it; everyone who
permits keeping it does not have the data. Building a filtered catalogue from Google
ratings would also run into their prohibition on using content to build competing place
datasets — which is precisely what our catalogue is.

### What we do instead — and why it is better anyway

**A star rating answers the wrong question.** We do not need to know whether a bar serves
good coffee. The transcript is explicit that the point is *meeting*, not staying. What we
need is: **can four strangers find this place, is it public, is it open, and is it safe to
stand outside of.** Google's rating measures none of those. A 4.7-star wine bar down an
unlit courtyard is a worse meeting point than a 3.9-star café on the main square.

So the quality signal is built from things that are storable and that measure the right
property. **Deliberately kept small** — your constraint, and it is the right one: *"dont
overcomplicate the filtering because it could produce shit results."*

**A pile of hand-weighted proxies is worse than three blunt ones.** Seven weighted signals
with invented coefficients look rigorous and are not: nothing validates the weights, a bad
one is invisible inside the sum, and when a venue turns out to be terrible nobody can say
which term did it. So the bootstrap does the least it can get away with.

**Three gates. A venue is in the catalogue or it is not:**

| Gate | Why |
| --- | --- |
| Category is one of `cafe · bar · pub · restaurant · square · park` | Anything else is not legible as "meet me at ___" |
| It has a **name** | An unnamed node cannot be said out loud or found |
| It is publicly accessible — no `access=private`, not inside a building requiring entry | The meeting point must be reachable without asking permission |

**One ordering signal until we have our own data: POI density within 150 m.** Busy places
are populated, lit, and easy to describe. That is the entire bootstrap ranking. If two
venues tie, prefer the one whose `opening_hours` parses and covers the slot; unknown hours
rank below known-open but are not excluded, because OSM hours are patchy and excluding on
missing data would empty the catalogue.

Everything else — `wikidata`, website, transit stop within 200 m, pedestrian-street
adjacency, a nearby landmark node — is **recorded as an attribute and used for nothing
yet.** Storing them costs nothing and lets us later ask *"did any of these actually
predict 'easy to find'?"* against real answers. Promoting one into the ranking is then a
measurement, not a guess. **Intention: proxies are hypotheses, and hypotheses are stored,
not trusted.**

**Self-improving signal — our own data** (this is what makes it genuinely self-sufficient,
and it is data nobody else has):

After every hangout, one extra tap on the rating screen: **"Was it easy to find?"** and
**"Did it feel like a good place to meet?"** Those two questions produce, within a few
weeks, a venue quality model that is *specific to our exact use case* — four strangers
converging at 17:30 — which no star rating anywhere measures. Venues that confuse people
sink automatically; venues that work rise and get used more.

**Once a venue has `min_venue_uses` outcomes (default 3), its own feedback replaces the
structural signal entirely.** The bootstrap exists only to survive the first month.

**The cold-start rule:** a venue with no outcome data is used only when it passes the gates
**and** the group is not all-strangers-in-the-dark (§6). Its first use is its audition, and
one clear "hard to find" is enough to demote it — a false demotion costs us one venue out
of hundreds, while a false promotion costs four people an evening.

**Human vetting is now optional, not required.** A ten-minute pass in the console when
opening a city accelerates the bootstrap and is worth doing once; the pipeline runs
without it. That satisfies D11 while leaving the accelerator available.

---

## 4. Clusters — the matching unit

```
venues ──DBSCAN(ε ≈ 250–400 m, minPts ≈ 4)──► clusters
                                               │
                    each cluster: centroid, venue count, aggregate quality,
                                  H3 cell, optional label from nearest
                                  OSM place=suburb|neighbourhood node
```

Why DBSCAN and not k-means: cluster count is unknown per city, shapes are irregular
(streets, riverfronts), and isolated venues *should* be left unclustered as noise rather
than forced into a group. A lone bar in a suburb is not a meeting zone.

**How the matchmaker uses it:**

1. For each person, precompute **reachable clusters** = clusters whose centroid is within
   that person's `max_travel` of their anchor, with a travel estimate attached.
2. **Eligibility (hard):** two people are geographically compatible iff they share at
   least one reachable cluster.
3. **Proximity score (soft):** for a candidate group, the best shared cluster is the one
   minimising the **worst member's travel**; the score is a function of that worst travel.
4. The chosen cluster is recorded on the hangout at match time. **The specific venue is
   not chosen yet** — that happens at lock, after confirmations, when we know who is
   actually coming.

**Why cluster-first, venue-later is the right sequencing:** matching over ~15 clusters
instead of ~400 venues is orders of magnitude cheaper and more stable, and if someone
declines and is backfilled, the replacement only has to reach the *cluster*. Choosing a
venue early would mean re-choosing it every time the group changed.

**Small towns and villages:** identical mechanism. Fewer venues means fewer clusters,
possibly one, possibly none. If a person has no reachable cluster they are not matched,
and the app says so honestly rather than inventing a place. That is the correct answer to
"the user is from a smaller place" — no special case, just less supply.

---

## 5. Choosing the meeting point (at lock)

```
score(v) = − max_i travel(anchor_i, v)          fairness first
           − β · mean_i travel(anchor_i, v)
           + γ · quality(v)                      structural + outcome-based
           − δ · recent_use(v)                   rotate; don't wear one place out
           + ε · proven_with_strangers(v)
subject to: v ∈ chosen cluster
            open at slot time (or public open space)
            accessibility flags satisfied if any member requires them
            not already hosting another group in the same window
            daylight/visibility rule if the group is all strangers
```

**Why `max` before `mean`:** a group is a conjunction. The person with the forty-minute
walk is the one who does not come; optimising the average quietly sacrifices them.

**Venue failure loop:** one tap on the reveal screen — *"this place was wrong"* (closed,
gone, could not find it) — demotes the venue immediately and, past a threshold,
deactivates it pending re-ingestion. Automatic, no queue.

---

## 6. The daylight / visibility rule

Groups where nobody has an existing edge get a meeting point that is public, populated and
preferably still in daylight at the slot's end. **Visibility is the safety mechanism, not
indoorness** — a busy square beats a quiet interior. This interacts with the Thu/Fri/Sat
19:00 slot in Croatian winter, where it will bind hard; the config resolves it per city
and season, and in deep winter the 19:00 slot may simply not run for stranger groups.

---

## 7. Supply and demand accounting

Aggregate on an **H3 hex grid** (global, hierarchical, no authoring) rather than on city
boundaries. That gives, for free: whether a hex has enough density to run hangouts, launch
decisions per neighbourhood, and the slot-quality indicator behind the availability
picker — *"you're likely to get a hangout at this time"* — as a coarse bucket, never a raw
count (raw counts are gameable and reveal how small the network is).

---

## 8. Sigils

- `(symbol, colour)` from a curated, culturally neutral, describable-out-loud set. 24 × 6 =
  144 combinations, far more than a venue will ever need at once.
- Allocation is enforced by a **database uniqueness constraint** on
  `(meeting_point_id, time_window, sigil_id)` — a collision is impossible, not unlikely.
  Assigned in the same transaction as the meeting point.
- Prefer not to reuse a venue in the same slot at all while the city has alternatives;
  sigil disambiguation is the second line of defence, not the first.
- Shown at reveal with the map pin, walking time, and a photo of the exact standing spot
  where one exists.

**Why a symbol rather than a name or a table number:** language-independent, survives being
read aloud badly, the phone screen *is* the sign, and it gives the group a shared object
in the first thirty seconds — which is the moment the product has to carry.
