import 'package:ekipa_core/src/domain/person.dart';
import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:ekipa_core/src/foundation/random_source.dart';
import 'package:ekipa_core/src/matching/matching_config.dart';
import 'package:meta/meta.dart';

/// One candidate's sampling weight, with the reasoning attached.
///
/// The components are kept separate rather than multiplied into a single number
/// because the console has to be able to answer "why was that person a seed",
/// and a product of three factors answers it with a number nobody can read back
/// into a sentence.
@immutable
final class SeedWeight {
  /// Records the weight of one candidate.
  const SeedWeight({
    required this.person,
    required this.starvationFactor,
    required this.newcomerFactor,
  });

  /// Who.
  final PersonId person;

  /// `1 + starve_gain · min(weeks_waiting, starve_cap)`.
  final double starvationFactor;

  /// `newcomer_multiplier` for a first hangout, otherwise 1.
  final double newcomerFactor;

  /// The sampling weight.
  double get value => starvationFactor * newcomerFactor;

  @override
  String toString() =>
      'SeedWeight(${person.value}, '
      'starve=${starvationFactor.toStringAsFixed(2)}, '
      'newcomer=${newcomerFactor.toStringAsFixed(2)})';
}

/// Chooses the people that groups are built around.
///
/// **The seed decides the group's shape**, because the ring draw runs over *the
/// seed's* rings. So seed choice is a policy decision, not an implementation
/// detail, and it has one trap in it that is worth stating in full.
///
/// **The trap.** Our conduct sanction at R2 is a *throttle*: we reduce how
/// often someone is matched. A throttled person is therefore, by construction,
/// among the longest-waiting people in the city. A naive "seed on whoever has
/// waited longest" rule hands them the first group of every run and first pick
/// of everyone's evening. The sanction inverts into a privilege — and it does
/// so **silently**, because the throttle still looks correct in the logs (fewer
/// hangouts permitted) while each permitted hangout is the best one available.
///
/// **The fix: starvation credit accrues only in good standing.** Throttled
/// people are excluded from *seeding*, not from hangouts. They may still fill a
/// seat when their quota allows. Stated honestly, the sanction reads: *fewer
/// evenings, and never the evening built around you.*
///
/// **Rejected — seeding on the best-connected person.** Serves the happiest
/// users and starves the rest: the classic recommender death spiral, arriving
/// here as "the app never matched me".
///
/// **Rejected — strict longest-waiting-first.** The trap above, plus a second
/// problem: a deterministic order makes composition predictable from outside
/// the system, and a predictable matcher is a gameable one. Weighted sampling
/// also removes the need to invent tie-breaks.
final class SeedPolicy {
  /// Constructs the policy.
  const SeedPolicy();

  /// Everyone in [eligible] who may be a seed.
  ///
  /// `seed_pool = eligible(slot) ∧ standing == GOOD`.
  List<Person> poolFrom(Iterable<Person> eligible) => [
    for (final person in eligible)
      if (person.standing.maySeed) person,
  ];

  /// The sampling weight of [person].
  SeedWeight weightOf(Person person, MatchConfig config) {
    final weeks = person.weeksWaiting.clamp(0, config.starveCapWeeks);
    return SeedWeight(
      person: person.id,
      starvationFactor: 1 + config.starveGain * weeks,
      newcomerFactor: person.isNewcomer ? config.newcomerMultiplier : 1,
    );
  }

  /// Draws seeds from [eligible], most-likely first, without replacement.
  ///
  /// Returns as many as the pool allows, up to [count]. Sampling without
  /// replacement rather than repeatedly sampling with it, because a run needs a
  /// *sequence* of distinct seeds and rejecting duplicates would bias the tail
  /// toward whoever happened to be sampled early.
  ///
  /// Determinism note: the order of [eligible] is respected in the cumulative
  /// scan, so the same pool in the same order with the same [random] produces
  /// the same sequence. Callers must therefore hand this a stably ordered
  /// list — the pipeline sorts by person id before calling.
  List<Person> draw(
    Iterable<Person> eligible,
    MatchConfig config,
    RandomSource random, {
    required int count,
  }) {
    final pool = poolFrom(eligible);
    if (pool.isEmpty || count <= 0) return const [];

    final remaining = List<Person>.of(pool);
    final weights = [
      for (final person in remaining) weightOf(person, config).value,
    ];
    final drawn = <Person>[];

    while (drawn.length < count && remaining.isNotEmpty) {
      final total = weights.fold<double>(0, (sum, w) => sum + w);
      if (total <= 0) break;

      final target = random.nextDouble() * total;
      var cumulative = 0.0;
      var chosen = remaining.length - 1;
      for (var i = 0; i < remaining.length; i++) {
        cumulative += weights[i];
        if (target < cumulative) {
          chosen = i;
          break;
        }
      }

      drawn.add(remaining.removeAt(chosen));
      weights.removeAt(chosen);
    }
    return drawn;
  }

  /// The weights the policy would use, for the console's explain view.
  ///
  /// Exposed deliberately: a weight nobody can inspect is a weight nobody can
  /// argue with, and the trap above was caught by arguing about one.
  List<SeedWeight> explain(Iterable<Person> eligible, MatchConfig config) => [
    for (final person in poolFrom(eligible)) weightOf(person, config),
  ];
}
