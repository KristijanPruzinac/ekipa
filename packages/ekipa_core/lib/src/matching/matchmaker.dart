import 'package:ekipa_core/src/domain/person.dart';
import 'package:ekipa_core/src/domain/slot.dart';
import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:ekipa_core/src/foundation/random_source.dart';
import 'package:ekipa_core/src/matching/composition.dart';
import 'package:ekipa_core/src/matching/eligibility.dart';
import 'package:ekipa_core/src/matching/matching_config.dart';
import 'package:ekipa_core/src/matching/plan.dart';
import 'package:ekipa_core/src/matching/ring.dart';
import 'package:ekipa_core/src/matching/ring_draw.dart';
import 'package:ekipa_core/src/matching/rings.dart';
import 'package:ekipa_core/src/matching/seed_policy.dart';
import 'package:ekipa_core/src/matching/snapshot.dart';

/// The matchmaker.
///
/// ```text
/// snapshot
///     │
/// ① partition → one sub-problem per (city, slot) ② eligibility → per-person
/// hard filters, then per-pair ③ candidate rings → R1 / R2 / R3 over the
/// mutual-edge graph ④ seed selection → who each group is built around ⑤ ring
/// draw → the seed's partner, by ratio ⑥ completion → second dyad by the same
/// draw; leftovers placed ⑦ validation → whole-group invariants; reject and
/// rebuild ⑧ emission → MatchPlan + explanations + run statistics
/// ```
///
/// **It writes nothing.** `MatchPlan run(snapshot, config, seed)` is a value-in
/// / value-out transform, which is what lets the same function run in the
/// worker, in a unit test, in the simulator over a synthetic city, and in the
/// console as a dry-run against live data. A matcher that wrote could not be
/// dry-run, could not be simulated, and could not be replayed to answer "why
/// was I put in that group?" months later.
///
/// **There is no group score and no search over candidate groups.** An earlier
/// draft had one, and it was wrong for this product: composition here is
/// *generated*, not optimised. Affinity survives only to answer the narrower
/// question — *given that we are drawing from ring R, which member of R?* —
/// which is what `RingSets.weightWithin` does. Deleting the hill-climbing pass
/// removed a wall-clock budget, a tuning knob, and a class of non-determinism,
/// and cost nothing, because there is no objective left to repair.
///
/// **One function, three uses.** A repair run is this function with a
/// restricted snapshot and `A = B = 0`; a dating round is a flag on the input.
/// Every extra matcher would be a place where the invariants get re-implemented
/// slightly differently, and the backfill path is exactly where a rushed second
/// implementation would forget the exclusion check.
final class Matchmaker {
  /// Constructs the matchmaker from its stages.
  ///
  /// The stages are injected so a test can substitute one — and so the reader
  /// can see that there are exactly five of them.
  const Matchmaker({
    this.eligibility,
    this.seedPolicy = const SeedPolicy(),
    this.ringDraw = const RingDraw(),
    this.composition = const Composition(),
  });

  /// Stage ②. Defaults to the standard rule set.
  final Eligibility? eligibility;

  /// Stage ④.
  final SeedPolicy seedPolicy;

  /// Stage ⑤.
  final RingDraw ringDraw;

  /// Stage ⑦.
  final Composition composition;

  /// Runs one plan over [snapshot].
  MatchPlan run(MatchSnapshot snapshot, MatchConfig config, int seed) {
    final rules = eligibility ?? Eligibility();
    final random = SeededRandomSource(seed);
    final funnel = FilterFunnel();
    final ledger = RingLedger();
    final hangouts = <PlannedHangout>[];
    final seedWeights = <SeedWeight>[];

    // Placed *this run*, carried across slots. The snapshot's own
    // `alreadyPlaced` covers earlier runs; this covers the run in progress.
    final placed = <PersonId>{};
    final abandoned = <RejectedAlternate>[];
    var eligibleConsidered = 0;
    var rebuildAttempts = 0;

    for (final slot in _partition(snapshot, config, rules)) {
      // A forked stream per slot, so adding a draw in one slot cannot shift the
      // sequence in another. Without this, a change to the first slot of the
      // evening silently rewrites every group after it, and a golden test fails
      // for a reason unrelated to the change.
      final slotRandom = random.fork('slot:${slot.id.value}');

      final eligible =
          rules
              .eligibleFor(slot, snapshot, config, funnel: funnel)
              .where((person) => !placed.contains(person.id))
              .toList()
            // Sorted so the weighted scans downstream are stable: the same
            // snapshot and seed must produce the same plan.
            ..sort((a, b) => a.id.value.compareTo(b.id.value));
      eligibleConsidered += eligible.length;

      final remaining = <PersonId, Person>{
        for (final person in eligible) person.id: person,
      };
      seedWeights.addAll(seedPolicy.explain(eligible, config));

      var index = 0;
      while (remaining.length >= config.minGroupSize) {
        final attempt = _buildGroup(
          slot: slot,
          remaining: remaining,
          snapshot: snapshot,
          config: config,
          random: slotRandom.fork('group:$index'),
          ledger: ledger,
          rules: rules,
        );
        rebuildAttempts += attempt.attempts;
        index++;

        if (attempt.hangout == null) {
          // Nothing legal could be assembled from what is left. The refusals
          // are kept on the run rather than discarded: this is the thin night
          // somebody will ask about, and it has no group to hang them on.
          abandoned.addAll(attempt.rejected);
          break;
        }

        final hangout = attempt.hangout!;
        hangouts.add(hangout);
        for (final id in hangout.memberIds) {
          remaining.remove(id);
          placed.add(id);
        }
      }

      // ⑥ Leftovers. **A matched person beats a marginally better group** —
      // that principle lives here, as a placement pass, rather than as a lambda
      // inside an objective that no longer exists.
      _placeLeftovers(
        hangouts: hangouts,
        slot: slot,
        remaining: remaining,
        snapshot: snapshot,
        config: config,
        rules: rules,
        placed: placed,
      );
    }

    return MatchPlan(
      city: snapshot.cityId,
      seed: seed,
      snapshotHash: snapshot.snapshotHash,
      configVersion: config.versionId,
      hangouts: List.unmodifiable(hangouts),
      seedWeights: List.unmodifiable(seedWeights),
      stats: RunStats(
        eligibleConsidered: eligibleConsidered,
        placed: placed.length,
        unplaced: eligibleConsidered - placed.length,
        funnel: funnel,
        ringLedger: ledger,
        rebuildAttempts: rebuildAttempts,
        abandonedAlternates: List.unmodifiable(abandoned),
      ),
    );
  }

  /// ① Slots in scarcity order — fewest available people first.
  ///
  /// Scarce slots get first pick of people; abundant slots absorb the
  /// remainder. The tie-break is the slot id, so the order is stable across
  /// runs.
  ///
  /// **Rejected — one global optimisation over the whole week.** Cross-slot
  /// trades ("this person would be better used on Thursday") are a real
  /// opportunity and a real trap: they make the problem global,
  /// non-decomposable and slow, and they make results incomprehensible. The
  /// marginal quality gain is dwarfed by "did the person turn up", which no
  /// optimiser controls.
  List<Slot> _partition(
    MatchSnapshot snapshot,
    MatchConfig config,
    Eligibility rules,
  ) {
    final supply = <SlotId, int>{
      for (final slot in snapshot.slots)
        slot.id: rules.eligibleFor(slot, snapshot, config).length,
    };
    return List<Slot>.of(snapshot.slots)..sort((a, b) {
      final byScarcity = (supply[a.id] ?? 0).compareTo(supply[b.id] ?? 0);
      return byScarcity != 0 ? byScarcity : a.id.value.compareTo(b.id.value);
    });
  }

  /// ④⑤⑥⑦ for one group: seed, dyad, second dyad, validate, rebuild.
  _GroupAttempt _buildGroup({
    required Slot slot,
    required Map<PersonId, Person> remaining,
    required MatchSnapshot snapshot,
    required MatchConfig config,
    required RandomSource random,
    required RingLedger ledger,
    required Eligibility rules,
  }) {
    final rejected = <RejectedAlternate>[];

    for (var attempt = 0; attempt < config.maxRebuildAttempts; attempt++) {
      final tries = random.fork('attempt:$attempt');
      final candidate = _assemble(
        slot: slot,
        remaining: remaining,
        snapshot: snapshot,
        config: config,
        random: tries,
        ledger: ledger,
        rules: rules,
      );
      if (candidate == null) {
        return _GroupAttempt(null, attempt + 1, rejected);
      }

      final verdict = composition.verdict(
        candidate.people,
        snapshot,
        config,
        barredIntermediaries: candidate.barred,
      );

      // ⑦ Reject and rebuild, never patch. Patching a group to satisfy a
      // composition rule is how you get technically-2+2 groups where the
      // swapped-in person satisfies nothing else.
      if (!verdict.isValid) {
        rejected.add(
          RejectedAlternate(
            members: [for (final p in candidate.people) p.id],
            failures: verdict.failures,
          ),
        );
        continue;
      }

      return _GroupAttempt(
        PlannedHangout(
          localKey: '${slot.id.value}#${rejected.length}',
          slot: slot.id,
          city: snapshot.cityId,
          members: List.unmodifiable(candidate.members),
          seed: candidate.members.first.person,
          clusterCandidates: verdict.sharedClusters,
          rejectedAlternates: List.unmodifiable(rejected),
        ),
        attempt + 1,
        rejected,
      );
    }
    return _GroupAttempt(null, config.maxRebuildAttempts, rejected);
  }

  /// One assembly attempt: two dyads, drawn.
  _Candidate? _assemble({
    required Slot slot,
    required Map<PersonId, Person> remaining,
    required MatchSnapshot snapshot,
    required MatchConfig config,
    required RandomSource random,
    required RingLedger ledger,
    required Eligibility rules,
  }) {
    final pool = Map<PersonId, Person>.of(remaining);
    final members = <PlannedMember>[];
    final people = <Person>[];
    final barred = <PersonId>{};

    bool permits(Person candidate) {
      for (final member in people) {
        if (rules.rejectPair(member, candidate, snapshot, config) != null) {
          return false;
        }
      }
      return !barred.contains(candidate.id);
    }

    // Two dyads, each a seed plus a drawn partner. "2 known + 2 known, dyads
    // strangers" is therefore not a template — it is what happens when both
    // draws succeed. One draw succeeding is one dyad plus two strangers.
    // Neither succeeding is four strangers. The four `GroupTemplate` entries of
    // an earlier draft were *outcomes* described as *modes*.
    for (var dyad = 0; dyad < 2; dyad++) {
      if (people.length >= config.maxGroupSize) break;

      final dyadRandom = random.fork('dyad:$dyad');
      final seedCandidates = _orderedPool(pool).where(permits).toList();
      final seeds = seedPolicy.draw(
        seedCandidates,
        config,
        dyadRandom.fork('seed'),
        count: 1,
      );
      if (seeds.isEmpty) break;

      final seedPerson = seeds.first;
      pool.remove(seedPerson.id);
      members.add(
        PlannedMember(
          person: seedPerson.id,
          role: dyad == 0 ? SlotRole.seed : SlotRole.partner,
        ),
      );
      people.add(seedPerson);

      if (people.length >= config.maxGroupSize) break;

      final outcome = ringDraw.draw(
        seed: seedPerson,
        rings: RingSets.of(seedPerson.id, pool.keys, snapshot, config),
        pool: pool,
        snapshot: snapshot,
        config: config,
        random: dyadRandom.fork('partner'),
        ledger: ledger,
        permits: (candidate) =>
            permits(candidate) &&
            _crossPairsAreStrangers(
              existing: people,
              candidate: candidate,
              snapshot: snapshot,
            ),
      );
      if (!outcome.isFound) continue;

      final partner = outcome.partner!;
      pool.remove(partner.id);
      if (outcome.via != null) barred.add(outcome.via!);
      members.add(
        PlannedMember(
          person: partner.id,
          role: SlotRole.partner,
          ringIntended: outcome.intended,
          ringRealised: outcome.realised,
          via: outcome.via,
        ),
      );
      people.add(partner);
    }

    if (people.length < config.minGroupSize) return null;
    return _Candidate(members: members, people: people, barred: barred);
  }

  /// Whether [candidate] is a stranger to everybody already in the group.
  ///
  /// The added constraint on the second dyad: every cross pair between dyad 1
  /// and dyad 2 must be strangers. Without it, the second draw could land on
  /// somebody the first dyad already knows, and the "at most half the pairs"
  /// invariant would be satisfied by luck rather than by construction.
  ///
  /// It applies to the *first* dyad's partner too, harmlessly: a seed with no
  /// group yet has no cross pairs to check.
  bool _crossPairsAreStrangers({
    required List<Person> existing,
    required Person candidate,
    required MatchSnapshot snapshot,
  }) {
    if (existing.length < 2) return true;
    // Everybody except the seed of the current dyad, which is the person the
    // draw is *for* — they are allowed to know their own partner, that is the
    // point of R1.
    for (final member in existing.take(existing.length - 1)) {
      if (snapshot.knownPairsAmong([member.id, candidate.id]) > 0) return false;
    }
    return true;
  }

  /// ⑥ Leftovers: a seat in an existing group beats no evening at all.
  ///
  /// Hard constraints only — no ring, no affinity. Ordered good standing first,
  /// then longest-waiting: starvation credit is a good-standing concept (§④),
  /// and a throttled person may still fill a seat when their quota allows.
  void _placeLeftovers({
    required List<PlannedHangout> hangouts,
    required Slot slot,
    required Map<PersonId, Person> remaining,
    required MatchSnapshot snapshot,
    required MatchConfig config,
    required Eligibility rules,
    required Set<PersonId> placed,
  }) {
    if (remaining.isEmpty) return;

    final waiting = _orderedPool(remaining)
      ..sort((a, b) {
        final byStanding = (b.standing.maySeed ? 1 : 0).compareTo(
          a.standing.maySeed ? 1 : 0,
        );
        if (byStanding != 0) return byStanding;
        final byWaiting = b.weeksWaiting.compareTo(a.weeksWaiting);
        return byWaiting != 0 ? byWaiting : a.id.value.compareTo(b.id.value);
      });

    for (final person in waiting) {
      for (var i = 0; i < hangouts.length; i++) {
        final hangout = hangouts[i];
        if (hangout.slot != slot.id) continue;
        if (hangout.size >= config.maxGroupSize) continue;

        final existing = [
          for (final id in hangout.memberIds) snapshot.person(id)!,
        ];
        if (existing.any(
          (member) =>
              rules.rejectPair(member, person, snapshot, config) != null,
        )) {
          continue;
        }

        final verdict = composition.verdict(
          [...existing, person],
          snapshot,
          config,
        );
        if (!verdict.isValid) continue;

        hangouts[i] = PlannedHangout(
          localKey: hangout.localKey,
          slot: hangout.slot,
          city: hangout.city,
          members: List.unmodifiable([
            ...hangout.members,
            PlannedMember(person: person.id, role: SlotRole.partner),
          ]),
          seed: hangout.seed,
          clusterCandidates: verdict.sharedClusters,
          rejectedAlternates: hangout.rejectedAlternates,
        );
        remaining.remove(person.id);
        placed.add(person.id);
        break;
      }
    }
  }

  List<Person> _orderedPool(Map<PersonId, Person> pool) =>
      pool.values.toList()..sort((a, b) => a.id.value.compareTo(b.id.value));
}

final class _Candidate {
  const _Candidate({
    required this.members,
    required this.people,
    required this.barred,
  });

  final List<PlannedMember> members;
  final List<Person> people;
  final Set<PersonId> barred;
}

final class _GroupAttempt {
  const _GroupAttempt(this.hangout, this.attempts, this.rejected);

  final PlannedHangout? hangout;
  final int attempts;
  final List<RejectedAlternate> rejected;
}
