import 'package:ekipa_core/src/domain/person.dart';
import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:ekipa_core/src/foundation/random_source.dart';
import 'package:ekipa_core/src/matching/matching_config.dart';
import 'package:ekipa_core/src/matching/ring.dart';
import 'package:ekipa_core/src/matching/rings.dart';
import 'package:ekipa_core/src/matching/snapshot.dart';
import 'package:meta/meta.dart';

/// Running counts of what the draw asked for and what the graph supplied.
///
/// **This is the part that is easy to omit and expensive to omit.** The
/// per-dyad roll is unbiased, but the *fallbacks* are not: they push
/// systematically toward R3 exactly when the graph is thin. Left alone, a
/// configured `0.25 / 0.50 / 0.25` can realise as `0.05 / 0.15 / 0.80` with
/// nothing anywhere saying so.
///
/// So the ledger does two jobs. It records intended and realised per draw, so
/// the console can show **configured next to realised**; and it biases later
/// rolls in the same run toward whichever ring is running a deficit, up to what
/// the graph can actually supply.
///
/// **Intention: the number you tune must be the number that happened.** A ratio
/// you cannot verify is a comment, not a control.
final class RingLedger {
  /// An empty ledger for one run.
  RingLedger();

  final Map<Ring, int> _intended = {};
  final Map<Ring, int> _realised = {};

  /// Records one completed draw.
  void record({required Ring intended, required Ring realised}) {
    _intended[intended] = (_intended[intended] ?? 0) + 1;
    _realised[realised] = (_realised[realised] ?? 0) + 1;
  }

  /// How many draws asked for [ring].
  int intendedCount(Ring ring) => _intended[ring] ?? 0;

  /// How many draws actually landed in [ring].
  int realisedCount(Ring ring) => _realised[ring] ?? 0;

  /// Total draws recorded.
  int get drawCount => _realised.values.fold(0, (sum, n) => sum + n);

  /// The realised share of [ring], or `null` before the first draw.
  double? realisedShare(Ring ring) =>
      drawCount == 0 ? null : realisedCount(ring) / drawCount;

  /// The configured shares, adjusted toward whichever ring is short.
  ///
  /// After *n* draws the target count for a ring is `share · n`, so the deficit
  /// is `share · n − realised`. Spreading that deficit over the next draw gives
  /// a correction on the same scale as a share, which is why it is divided by
  /// `n + 1` rather than used raw — an uncorrected deficit of three draws would
  /// swamp the configured ratio entirely and turn a gentle correction into a
  /// hard switch.
  ///
  /// Negative adjustments clamp to zero rather than going negative, and if
  /// every ring clamps to zero the configured shares are used unchanged. A
  /// correction that could produce an empty distribution would be a correction
  /// that occasionally refuses to draw at all.
  Map<Ring, double> adjustedShares(MatchConfig config) {
    final configured = {
      Ring.r1Enjoyed: config.ringShareEnjoyed,
      Ring.r2Leaf: config.ringShareLeaf,
      Ring.r3Stranger: config.ringShareStranger,
    };
    final n = drawCount;
    if (n == 0 || config.ringDeficitGain == 0) return configured;

    final adjusted = <Ring, double>{};
    for (final entry in configured.entries) {
      final deficit = entry.value * n - realisedCount(entry.key);
      final correction = config.ringDeficitGain * deficit / (n + 1);
      adjusted[entry.key] = (entry.value + correction).clamp(0.0, 1.0);
    }

    final total = adjusted.values.fold<double>(0, (sum, w) => sum + w);
    if (total <= 0) return configured;
    return {
      for (final entry in adjusted.entries) entry.key: entry.value / total,
    };
  }

  /// A JSON-ready summary for `match_runs.stats`.
  ///
  /// Both halves, always. Reporting only the realised mix would hide the
  /// question the console exists to answer: *did we get the ratio we asked
  /// for?*
  Map<String, Object?> toJson() => {
    'draws': drawCount,
    'intended': {
      for (final ring in Ring.values) ring.storageCode: intendedCount(ring),
    },
    'realised': {
      for (final ring in Ring.values) ring.storageCode: realisedCount(ring),
    },
  };

  @override
  String toString() => 'RingLedger(${toJson()})';
}

/// The result of one dyad draw.
@immutable
final class DrawOutcome {
  /// A draw that found somebody.
  const DrawOutcome.found({
    required this.partner,
    required this.intended,
    required this.realised,
    this.via,
  });

  /// A draw that found nobody in any ring.
  const DrawOutcome.empty(this.intended)
    : partner = null,
      realised = null,
      via = null;

  /// The person drawn, or `null` if no ring could supply one.
  final Person? partner;

  /// The ring the roll asked for.
  final Ring intended;

  /// The ring the partner actually came from, or `null` if none did.
  final Ring? realised;

  /// For an R2 draw, the intermediary — **who must not be placed in this
  /// group**.
  final PersonId? via;

  /// Whether a partner was found.
  bool get isFound => partner != null;

  /// Whether the draw had to widen outward to find somebody.
  bool get fellBack => realised != null && realised != intended;

  @override
  String toString() => partner == null
      ? 'DrawOutcome.empty(${intended.storageCode})'
      : 'DrawOutcome(${partner!.id.value}, '
            '${intended.storageCode}→${realised!.storageCode}'
            '${via == null ? '' : ' via ${via!.value}'})';
}

/// The core algorithm: one partner, drawn from a ring chosen by a roll.
///
/// ```text
/// roll ~ U(0,1) from the run seed roll < A → partner drawn from R1 A ≤ roll <
/// A + B → partner drawn from R2 otherwise → partner drawn from R3
/// ```
///
/// Two properties matter more than the roll itself.
///
/// **Within the drawn ring the partner is *sampled*, weighted** by edge
/// strength after decay — never `argmax`. Invariant 3 forbids re-pairing
/// deterministically however strong the edge, because if a strong pair always
/// reappeared then its *absence* would become information about how somebody
/// rated. That breaks the asymmetry invariant, which is the load-bearing
/// privacy promise in the product.
///
/// **Fallback goes down, never up.** R1 → R2 → R3, never the other way. A
/// stranger draw silently becoming a friend draw is the direction that builds
/// closed cliques; falling outward costs one person one evening of familiarity
/// and increases exposure, which is the failure we can afford.
final class RingDraw {
  /// Constructs the draw.
  const RingDraw();

  /// Draws one partner for [seed] from [rings].
  ///
  /// [permits] is the pair filter — exclusions, cooldown, shared cluster —
  /// asked per candidate, because a pair rule can only be checked once there is
  /// a pair. It is passed in rather than reached for so that the completion
  /// stage can add "and not already in this group" without this function
  /// knowing what a group is.
  DrawOutcome draw({
    required Person seed,
    required RingSets rings,
    required Map<PersonId, Person> pool,
    required MatchSnapshot snapshot,
    required MatchConfig config,
    required RandomSource random,
    required RingLedger ledger,
    required bool Function(Person candidate) permits,
  }) {
    final intended = _rollRing(random, ledger, config);

    for (Ring? ring = intended; ring != null; ring = ring.widened) {
      final chosen = _sampleWithin(
        ring: ring,
        rings: rings,
        pool: pool,
        snapshot: snapshot,
        config: config,
        random: random,
        permits: permits,
      );
      if (chosen == null) continue;

      ledger.record(intended: intended, realised: ring);
      return DrawOutcome.found(
        partner: chosen,
        intended: intended,
        realised: ring,
        via: ring == Ring.r2Leaf ? rings.intermediaryFor(chosen.id) : null,
      );
    }

    // Nothing anywhere. Deliberately not recorded in the ledger: a draw that
    // found nobody is not a realised R3, and counting it as one would make a
    // thin night look like a successful stranger night.
    return DrawOutcome.empty(intended);
  }

  Ring _rollRing(RandomSource random, RingLedger ledger, MatchConfig config) {
    final shares = ledger.adjustedShares(config);
    final roll = random.nextDouble();
    var cumulative = 0.0;
    for (final ring in Ring.values) {
      cumulative += shares[ring] ?? 0;
      if (roll < cumulative) return ring;
    }
    // Floating-point residue only. The outermost ring is the safe landing:
    // falling outward is the direction we can afford.
    return Ring.r3Stranger;
  }

  Person? _sampleWithin({
    required Ring ring,
    required RingSets rings,
    required Map<PersonId, Person> pool,
    required MatchSnapshot snapshot,
    required MatchConfig config,
    required RandomSource random,
    required bool Function(Person candidate) permits,
  }) {
    // Sorted so the cumulative scan is stable: the same graph and the same seed
    // must produce the same partner, or a run cannot be replayed.
    final ids = rings.membersOf(ring).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final candidates = <Person>[];
    final weights = <double>[];
    for (final id in ids) {
      final person = pool[id];
      if (person == null || !permits(person)) continue;
      candidates.add(person);
      // A floor of a small positive weight, so a decayed-to-nothing edge still
      // makes somebody drawable rather than silently unreachable. An edge that
      // has decayed is weak evidence, not an exclusion.
      final weight = rings.weightWithin(ring, id, snapshot, config);
      weights.add(weight <= 0 ? 0.001 : weight);
    }
    if (candidates.isEmpty) return null;

    final total = weights.fold<double>(0, (sum, w) => sum + w);
    final target = random.nextDouble() * total;
    var cumulative = 0.0;
    for (var i = 0; i < candidates.length; i++) {
      cumulative += weights[i];
      if (target < cumulative) return candidates[i];
    }
    return candidates.last;
  }
}
