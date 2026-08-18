import 'dart:math' as math;

import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:meta/meta.dart';

/// An unordered pair of people.
///
/// **Intention.** Everything the graph holds about two people is symmetric —
/// edges and exclusions both — and the symmetry has to be **structural** rather
/// than maintained. The database enforces it with `check (a_id < b_id)`; this
/// is the same rule in Dart, so a lookup cannot miss a row by asking in the
/// wrong order.
///
/// That is not tidiness. If the order of the key could carry a direction, then
/// invariant 4 — *the direction of an edge is not stored and cannot be derived*
/// — becomes a convention rather than a fact, and a convention is something a
/// future query can quietly break.
@immutable
final class PairKey {
  /// Orders [one] and [other] canonically.
  factory PairKey(PersonId one, PersonId other) {
    assert(one != other, 'a pair is two different people');
    return one.value.compareTo(other.value) <= 0
        ? PairKey._(one, other)
        : PairKey._(other, one);
  }

  const PairKey._(this.low, this.high);

  /// The lexicographically smaller id.
  final PersonId low;

  /// The lexicographically larger id.
  final PersonId high;

  /// Whether [person] is one of the two.
  bool contains(PersonId person) => person == low || person == high;

  /// The other member of the pair, given one of them.
  PersonId otherThan(PersonId person) {
    assert(contains(person), 'asked for the partner of a non-member');
    return person == low ? high : low;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PairKey && other.low == low && other.high == high);

  @override
  int get hashCode => Object.hash(PairKey, low, high);

  @override
  String toString() => 'PairKey(${low.value}, ${high.value})';
}

/// A mutual positive connection between two people.
///
/// Formed only when **both** sides rated the other positively. A one-sided "I
/// enjoyed them" creates nothing, and the reason is privacy rather than
/// manners: if one-sided liking could pull someone back, being re-matched would
/// leak that they liked you, and *not* being re-matched would leak the
/// opposite.
@immutable
final class Edge {
  /// Records an edge between the two people in [pair].
  const Edge({
    required this.pair,
    required this.weight,
    required this.meetCount,
    required this.lastMetAt,
  });

  /// Who.
  final PairKey pair;

  /// Strength in `[0, 1]`, before decay.
  final double weight;

  /// How many times they have met.
  final int meetCount;

  /// When they last met. Feeds the decay in the `friend` affinity component.
  final DateTime lastMetAt;

  /// The weight as of [now], halving every [halfLife].
  ///
  /// **Intention.** Repetition is the only known mechanism by which
  /// acquaintances become friends, so an edge has to keep meaning something —
  /// but an edge from eighteen months ago describes two people who have both
  /// changed. Decay says both things with one number instead of an expiry date
  /// that would delete the evidence.
  double decayedWeight(DateTime now, Duration halfLife) {
    final elapsed = now.difference(lastMetAt).inSeconds;
    if (elapsed <= 0) return weight;
    final halves = elapsed / halfLife.inSeconds;
    return weight * math.pow(0.5, halves);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Edge &&
          other.pair == pair &&
          other.weight == weight &&
          other.meetCount == meetCount &&
          other.lastMetAt == lastMetAt);

  @override
  int get hashCode => Object.hash(Edge, pair, weight, meetCount, lastMetAt);

  @override
  String toString() =>
      'Edge($pair, w=${weight.toStringAsFixed(3)}, met=$meetCount)';
}

/// Why two people must never be matched again.
enum ExclusionReason {
  /// One of them answered `rather_not`. Invisible to its subject, which is what
  /// makes the answer safe to give honestly.
  ratherNot,

  /// An explicit block.
  block,

  /// A report that the trust system substantiated.
  reportUpheld,
}

/// A permanent, symmetric bar between two people.
///
/// Permanent on purpose. A time-limited exclusion would mean telling someone
/// who once said `rather_not` that the person is back, which is the one thing
/// the answer promises will not happen.
@immutable
final class Exclusion {
  /// Records the bar.
  const Exclusion({required this.pair, required this.reason});

  /// Who.
  final PairKey pair;

  /// Why. Never shown to either person.
  final ExclusionReason reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exclusion && other.pair == pair && other.reason == reason);

  @override
  int get hashCode => Object.hash(Exclusion, pair, reason);

  @override
  String toString() => 'Exclusion($pair, ${reason.name})';
}
