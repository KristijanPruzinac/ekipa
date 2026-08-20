import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:ekipa_core/src/matching/matching_config.dart';
import 'package:ekipa_core/src/matching/ring.dart';
import 'package:ekipa_core/src/matching/snapshot.dart';
import 'package:meta/meta.dart';

/// One R2 candidate and the person they arrive through.
///
/// **The intermediary is why this is a type rather than a `Set<PersonId>`.** If
/// A is the seed and C is drawn from R2 by way of B, then **B is not placed in
/// that group**. A group of A, B and C has three known pairs of six and one
/// outsider — the worst possible shape, where a trio talks and the fourth
/// person watches.
///
/// *Rejected — including the intermediary (the "warm introduction").* It is how
/// introductions work in real life and may well be better. It is also a
/// different product shape, and it is named as a future variant to be measured
/// against this one rather than assumed into it.
@immutable
final class LeafCandidate {
  /// Records a two-hop candidate.
  const LeafCandidate({
    required this.person,
    required this.via,
    required this.strength,
  });

  /// The candidate — somebody the seed has no evidence about.
  final PersonId person;

  /// The person the evidence comes through. Excluded from the group.
  final PersonId via;

  /// `min(w₁, w₂)` after decay, before the bridge discount.
  ///
  /// The minimum rather than the product or the mean: a chain is as strong as
  /// its weaker link, and "I liked B a lot, B barely knows C" is weak evidence
  /// however enthusiastic the first half was.
  final double strength;

  @override
  String toString() =>
      'LeafCandidate(${person.value} via ${via.value}, '
      '${strength.toStringAsFixed(3)})';
}

/// One person's three rings over the mutual-edge graph.
///
/// **Intention.** These sets are the product's thesis, stated as data. A dating
/// app draws from R3 forever; a friend-of-a-friend app draws from R1 forever
/// and closes. Drawing from all three in a ratio somebody can tune is the bet,
/// and splitting them out like this is what lets the bet be *measured* — the
/// primary metric is edge yield sliced by realised ring (03_MATCHMAKER.md §9).
///
/// Computed against a **candidate set**, not against the whole city. A ring is
/// only useful if its members can actually be placed tonight, and computing
/// over everybody would produce sets whose size tells you about the graph
/// rather than about the evening.
@immutable
final class RingSets {
  const RingSets._({
    required this.of,
    required this.enjoyed,
    required this.leaves,
    required this.strangers,
  });

  /// Builds the rings of [person] over [candidates].
  ///
  /// [candidates] must already have passed the per-person hard filters; the
  /// pair filters are applied later, at the draw, because a pair rule can only
  /// be checked once there is a pair.
  factory RingSets.of(
    PersonId person,
    Iterable<PersonId> candidates,
    MatchSnapshot snapshot,
    MatchConfig config,
  ) {
    final pool = candidates.where((c) => c != person).toSet();

    // R1 — a **mutual** edge, per canon. A one-sided "I enjoyed them" never
    // causes a re-match, and that is load-bearing for privacy rather than for
    // manners: if one-sided liking could pull somebody back, being re-matched
    // would leak that they liked you, and *not* being re-matched would leak the
    // opposite. Edges only exist when both sides said yes, so this is simply
    // "who has an edge with me".
    final directWeights = <PersonId, double>{};
    for (final edge in snapshot.edges) {
      if (!edge.pair.contains(person)) continue;
      final friend = edge.pair.otherThan(person);
      directWeights[friend] = edge.decayedWeight(
        snapshot.takenAt,
        config.edgeHalfLife,
      );
    }
    final enjoyed = {
      for (final friend in directWeights.keys)
        if (pool.contains(friend)) friend,
    };

    // R2 — the R1 sets of my R1 people, minus my own R1 and me. The
    // intermediary need not be placeable tonight: they are evidence, not a
    // guest. That is deliberate, because requiring the intermediary to be
    // available would make R2 collapse on exactly the thin nights it is most
    // useful on.
    final best = <PersonId, LeafCandidate>{};
    for (final friendEntry in directWeights.entries) {
      final friend = friendEntry.key;
      final firstHop = friendEntry.value;
      for (final edge in snapshot.edges) {
        if (!edge.pair.contains(friend)) continue;
        final leaf = edge.pair.otherThan(friend);
        if (leaf == person || directWeights.containsKey(leaf)) continue;
        if (!pool.contains(leaf)) continue;

        final secondHop = edge.decayedWeight(
          snapshot.takenAt,
          config.edgeHalfLife,
        );
        final strength =
            (firstHop < secondHop ? firstHop : secondHop) *
            config.bridgeDiscount;

        final incumbent = best[leaf];
        // Strongest path wins; ties broken by id so the same graph always
        // produces the same intermediary. An unstable tie-break would make a
        // replay disagree with itself about *why* somebody was invited.
        if (incumbent == null ||
            strength > incumbent.strength ||
            (strength == incumbent.strength &&
                friend.value.compareTo(incumbent.via.value) < 0)) {
          best[leaf] = LeafCandidate(
            person: leaf,
            via: friend,
            strength: strength,
          );
        }
      }
    }

    // R3 — everyone else. Without this the graph closes: new people never
    // enter, separate components never merge, and the product becomes a tool
    // for the people who already know each other.
    final strangers = {
      for (final candidate in pool)
        if (!enjoyed.contains(candidate) && !best.containsKey(candidate))
          candidate,
    };

    return RingSets._(
      of: person,
      enjoyed: Set.unmodifiable(enjoyed),
      leaves: Map.unmodifiable(best),
      strangers: Set.unmodifiable(strangers),
    );
  }

  /// Whose rings these are.
  final PersonId of;

  /// R1: people with a mutual edge to [of].
  final Set<PersonId> enjoyed;

  /// R2: friends-of-friends, each with the intermediary they arrive through.
  final Map<PersonId, LeafCandidate> leaves;

  /// R3: everyone else in the candidate set.
  final Set<PersonId> strangers;

  /// The members of [ring].
  Set<PersonId> membersOf(Ring ring) => switch (ring) {
    Ring.r1Enjoyed => enjoyed,
    Ring.r2Leaf => leaves.keys.toSet(),
    Ring.r3Stranger => strangers,
  };

  /// The intermediary for [candidate], or `null` if they are not an R2 member.
  PersonId? intermediaryFor(PersonId candidate) => leaves[candidate]?.via;

  /// The relative strength of [candidate] within [ring], for weighted sampling.
  ///
  /// R3 members all weigh the same, deliberately: there is no evidence about a
  /// stranger, and inventing a preference among strangers would be the matcher
  /// expressing an opinion it has no basis for.
  double weightWithin(
    Ring ring,
    PersonId candidate,
    MatchSnapshot snapshot,
    MatchConfig config,
  ) {
    switch (ring) {
      case Ring.r1Enjoyed:
        final edge = snapshot.edgeBetween(of, candidate);
        return edge == null
            ? 0
            : edge.decayedWeight(snapshot.takenAt, config.edgeHalfLife);
      case Ring.r2Leaf:
        return leaves[candidate]?.strength ?? 0;
      case Ring.r3Stranger:
        return 1;
    }
  }

  /// Whether every ring is empty — this seed has nobody at all tonight.
  bool get isEmpty => enjoyed.isEmpty && leaves.isEmpty && strangers.isEmpty;

  @override
  String toString() =>
      'RingSets(${of.value}: r1=${enjoyed.length}, '
      'r2=${leaves.length}, r3=${strangers.length})';
}

/// Pair-level access to the graph, kept beside the rings because both are views
/// of the same edges.
extension GraphQueries on MatchSnapshot {
  /// Whether these two have a mutual edge.
  bool haveMetHappily(PersonId a, PersonId b) => edgeBetween(a, b) != null;

  /// How many pairs among [members] have already met.
  ///
  /// Feeds invariant 2 — at most half a group's pairs may have met before. A
  /// 2+2 gives two of six and holds by construction; this counts the case where
  /// it does not.
  int knownPairsAmong(Iterable<PersonId> members) {
    final people = members.toList();
    var known = 0;
    for (var i = 0; i < people.length; i++) {
      for (var j = i + 1; j < people.length; j++) {
        if (edgeBetween(people[i], people[j]) != null ||
            interveningHangoutsSince(people[i], people[j]) != null) {
          known++;
        }
      }
    }
    return known;
  }
}
