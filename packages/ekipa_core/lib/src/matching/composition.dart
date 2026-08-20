import 'package:ekipa_core/src/domain/gender.dart';
import 'package:ekipa_core/src/domain/person.dart';
import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:ekipa_core/src/matching/matching_config.dart';
import 'package:ekipa_core/src/matching/rings.dart';
import 'package:ekipa_core/src/matching/snapshot.dart';
import 'package:meta/meta.dart';

/// Why a candidate group is not allowed to exist.
///
/// Named per rule, because a validation stage that answers "invalid" gives
/// nobody anything to fix. These are what
/// `match_run_groups.rejected_alternates` records — the alternates that were
/// considered and refused, with the reason, which is the only way anybody can
/// later ask why a thin night was thin.
enum CompositionFailure {
  /// Fewer people than [MatchingKeys.minGroupSize].
  tooSmall,

  /// More people than [MatchingKeys.maxGroupSize].
  tooLarge,

  /// Somebody is the only one of their gender. Invariant 1.
  loneGender,

  /// More than half the pairs have met before. Invariant 2.
  tooFamiliar,

  /// An exclusion exists between two members.
  excludedPair,

  /// No venue cluster every member can reach.
  noSharedCluster,

  /// An R2 intermediary was placed in the group they introduced somebody to.
  intermediaryPresent,

  /// The same person appears twice.
  duplicateMember,
}

/// The verdict on one candidate group.
@immutable
final class CompositionVerdict {
  /// A group that may exist.
  const CompositionVerdict.valid()
    : failures = const [],
      sharedClusters = const {};

  /// A group that may exist, in one of [sharedClusters].
  const CompositionVerdict.validIn(this.sharedClusters) : failures = const [];

  /// A group that may not exist, for [failures].
  const CompositionVerdict.invalid(this.failures) : sharedClusters = const {};

  /// Every rule the group breaks. **All of them**, not the first — a group
  /// rejected for one reason and rebuilt into a group rejected for another is
  /// two wasted rebuilds and a diagnostic that only ever names one problem.
  final List<CompositionFailure> failures;

  /// Clusters every member can reach. The meeting point is chosen from one of
  /// these at lock time, not now: if somebody declines and is backfilled, the
  /// replacement only has to reach the *cluster*.
  final Set<ClusterId> sharedClusters;

  /// Whether the group may exist.
  bool get isValid => failures.isEmpty;

  @override
  String toString() => isValid
      ? 'CompositionVerdict.valid(${sharedClusters.length} clusters)'
      : 'CompositionVerdict.invalid('
            '${failures.map((f) => f.name).join(', ')})';
}

/// The whole-group invariants, checked once at the end.
///
/// **Reject and rebuild, never patch.** A group that fails is discarded, not
/// repaired. Patching a group to satisfy a composition rule is how you get
/// technically-2+2 groups where the swapped-in person satisfies nothing else —
/// they live across the river, they met two of the others last week, and the
/// rule that was violated is now the only rule that holds.
///
/// The invariants, from 03_MATCHMAKER.md §⑥, permanent at every graph density:
///
/// 1. **No person is ever the only one of their gender**, at *any* group size.
///      This single rule replaces "2+2 or 4-same", covers the 3-person backfill
///      case, and needs no special case for a third gender value.
/// 2. **At most half the pairs may have met before.** A 2+2 gives two of six
///      and holds by construction; this catches the case where it does not.
/// 3. **No pair is re-matched deterministically** — enforced at the draw, by
///      sampling rather than by `argmax`, because it is a property of *how* a
///      group is built rather than of the group itself.
/// 4. **A person under sanction is never a seed** — enforced by
///      `SeedPolicy`, for the same reason.
///
/// > **Deleted invariant, and why.** An earlier draft required that *"at least
/// > one member of every group is not connected to anyone else in it."* It
/// > contradicts the 2+2 this product was explicitly asked for, and the job it
/// > was doing — preventing closed cliques — is done properly by the stranger
/// > share C and by the cooldown. An invariant that contradicts the
/// > specification is a bug in the invariant.
final class Composition {
  /// Constructs the validator.
  const Composition();

  /// Judges [members], excluding any [barredIntermediaries] from being present.
  CompositionVerdict verdict(
    List<Person> members,
    MatchSnapshot snapshot,
    MatchConfig config, {
    Set<PersonId> barredIntermediaries = const {},
  }) {
    final failures = <CompositionFailure>[];

    final ids = members.map((m) => m.id).toList();
    if (ids.toSet().length != ids.length) {
      failures.add(CompositionFailure.duplicateMember);
    }

    if (members.length < config.minGroupSize) {
      failures.add(CompositionFailure.tooSmall);
    }
    if (members.length > config.maxGroupSize) {
      failures.add(CompositionFailure.tooLarge);
    }

    // Invariant 1.
    if (GenderMix(members.map((m) => m.gender)).hasLoneGender) {
      failures.add(CompositionFailure.loneGender);
    }

    // Invariant 2. The ceiling is a *fraction* of the pairs, so it scales with
    // group size without a table of cases: a three has three pairs, a four has
    // six, and half of each is the same rule.
    final pairCount = members.length * (members.length - 1) ~/ 2;
    if (pairCount > 0) {
      final known = snapshot.knownPairsAmong(ids);
      if (known > pairCount * config.maxKnownPairFraction) {
        failures.add(CompositionFailure.tooFamiliar);
      }
    }

    for (var i = 0; i < members.length; i++) {
      for (var j = i + 1; j < members.length; j++) {
        if (snapshot.isExcluded(ids[i], ids[j])) {
          failures.add(CompositionFailure.excludedPair);
          break;
        }
      }
      if (failures.contains(CompositionFailure.excludedPair)) break;
    }

    if (barredIntermediaries.any(ids.contains)) {
      failures.add(CompositionFailure.intermediaryPresent);
    }

    // The group-wide geographic check. Pairwise reachability does not imply it:
    // A and B can share the north, B and C the south, and there is still
    // nowhere all three can go. That is the failure this catches, and it is
    // invisible to any per-pair rule.
    final shared = _sharedClusters(members);
    if (shared.isEmpty && members.isNotEmpty) {
      failures.add(CompositionFailure.noSharedCluster);
    }

    return failures.isEmpty
        ? CompositionVerdict.validIn(shared)
        : CompositionVerdict.invalid(List.unmodifiable(failures));
  }

  /// Clusters every member of [members] can reach.
  Set<ClusterId> _sharedClusters(List<Person> members) {
    if (members.isEmpty) return const {};
    var shared = members.first.reachableClusters;
    for (final member in members.skip(1)) {
      shared = shared.intersection(member.reachableClusters);
      if (shared.isEmpty) return const {};
    }
    return Set.unmodifiable(shared);
  }
}
