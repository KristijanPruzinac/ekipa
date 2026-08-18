import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:ekipa_core/src/matching/composition.dart';
import 'package:ekipa_core/src/matching/eligibility.dart';
import 'package:ekipa_core/src/matching/ring.dart';
import 'package:ekipa_core/src/matching/ring_draw.dart';
import 'package:ekipa_core/src/matching/seed_policy.dart';
import 'package:meta/meta.dart';

/// One member of a proposed hangout, with the reason they are in it.
///
/// **`ringIntended` and `ringRealised` are both stored**, and that is the whole
/// point of the type. Fallbacks bias systematically toward R3 exactly when the
/// graph is thin, so a configured ratio can realise as something else entirely
/// with nothing anywhere saying so. Keeping both halves per member is what lets
/// the console show configured next to realised.
///
/// `via` is the intermediary of an R2 draw. It is **never selectable by any
/// client-facing policy**: it names an edge, which is the whole friend graph in
/// one column.
@immutable
final class PlannedMember {
  /// Records one member.
  const PlannedMember({
    required this.person,
    required this.role,
    this.ringIntended,
    this.ringRealised,
    this.via,
  });

  /// Who.
  final PersonId person;

  /// Why they are here: the seed, a drawn partner, or a leftover placement.
  final SlotRole role;

  /// The ring the roll asked for, or `null` for a seed or a leftover.
  final Ring? ringIntended;

  /// The ring they actually came from, or `null` for a seed or a leftover.
  final Ring? ringRealised;

  /// The intermediary of an R2 draw. Server-side only, forever.
  final PersonId? via;

  @override
  String toString() =>
      'PlannedMember(${person.value}, ${role.name}'
      '${ringRealised == null ? '' : ', ${ringRealised!.storageCode}'})';
}

/// A group the matcher considered and refused, with the reason.
///
/// **This cannot be reconstructed later**, which is why it is written before
/// the first real hangout rather than after the first question about one.
/// Without it, the only available answer to "why was the night thin" is "the
/// matcher produced nothing", which is the least useful sentence a matcher can
/// produce.
@immutable
final class RejectedAlternate {
  /// Records a refusal.
  const RejectedAlternate({required this.members, required this.failures});

  /// Who was in the group that was refused.
  final List<PersonId> members;

  /// Every rule it broke.
  final List<CompositionFailure> failures;

  /// A JSON-ready form for `match_run_groups.rejected_alternates`.
  Map<String, Object?> toJson() => {
    'members': [for (final member in members) member.value],
    'failures': [for (final failure in failures) failure.name],
  };

  @override
  String toString() =>
      'RejectedAlternate(${members.length} members, '
      '${failures.map((f) => f.name).join(', ')})';
}

/// One proposed hangout.
///
/// Carries no `HangoutId`: the matcher returns a plan and the worker persists
/// it transactionally. **A matcher that writes cannot be dry-run, cannot be
/// simulated, and cannot be rolled back** (rule 6 of 03_MATCHMAKER.md §7), so
/// it does not get to invent identities either.
@immutable
final class PlannedHangout {
  /// Records a proposed hangout.
  const PlannedHangout({
    required this.localKey,
    required this.slot,
    required this.city,
    required this.members,
    required this.seed,
    required this.clusterCandidates,
    this.rejectedAlternates = const [],
  });

  /// A key unique within this plan, so the worker can correlate a persisted
  /// hangout with the reasoning recorded beside it.
  final String localKey;

  /// Which slot.
  final SlotId slot;

  /// Which city.
  final CityId city;

  /// Who, in the order they joined.
  final List<PlannedMember> members;

  /// The person the group was built around.
  final PersonId seed;

  /// Clusters every member can reach.
  ///
  /// A *set*, not a choice. The meeting point is picked at lock time from one
  /// of these, because if somebody declines and is backfilled the replacement
  /// only has to reach the cluster — choosing a venue now would mean
  /// re-choosing it every time the group changed.
  final Set<ClusterId> clusterCandidates;

  /// Groups considered and refused on the way to this one.
  final List<RejectedAlternate> rejectedAlternates;

  /// How many people are in it.
  int get size => members.length;

  /// Everybody's id.
  List<PersonId> get memberIds => [for (final m in members) m.person];

  /// The realised ring mix, for `match_run_groups.ring_mix`.
  Map<String, int> get ringMix {
    final counts = <String, int>{};
    for (final member in members) {
      final ring = member.ringRealised;
      if (ring == null) continue;
      counts[ring.storageCode] = (counts[ring.storageCode] ?? 0) + 1;
    }
    return counts;
  }

  @override
  String toString() =>
      'PlannedHangout($localKey, ${members.length} members, '
      'seed=${seed.value})';
}

/// What a run did, and why it did not do more.
///
/// **Intention.** The eligibility funnel lives here — filtered by cooldown 12,
/// by standing 3, by distance 8, unmatched for lack of a composition-compatible
/// partner 5. Without it the console can only say "nothing happened", and a
/// matcher whose quiet nights are unexplainable is a matcher nobody can tune.
@immutable
final class RunStats {
  /// Records a run's statistics.
  const RunStats({
    required this.eligibleConsidered,
    required this.placed,
    required this.unplaced,
    required this.funnel,
    required this.ringLedger,
    required this.rebuildAttempts,
    this.abandonedAlternates = const [],
  });

  /// How many people passed the per-person hard filters, across all slots.
  final int eligibleConsidered;

  /// How many people ended up in a group.
  final int placed;

  /// How many were eligible and still went home.
  ///
  /// The number that matters most on a thin night, and the one a boolean filter
  /// cannot explain.
  final int unplaced;

  /// Why people were filtered out.
  final FilterFunnel funnel;

  /// Configured versus realised ring mix.
  final RingLedger ringLedger;

  /// How many candidate groups were built and discarded.
  ///
  /// A rising number here means the constraints and the population disagree —
  /// usually a gender ratio or a cluster split — and it is visible before it
  /// becomes "the app stopped matching me".
  final int rebuildAttempts;

  /// Groups that were built, refused, and never replaced by a successful one.
  ///
  /// **The case the console most needs and the easiest one to lose.** A group
  /// that is refused on the way to a good group has its reasoning recorded on
  /// that group. A slot that gives up entirely has no group to record it on —
  /// and that is precisely the night somebody will ask about. Without this, the
  /// answer to "why did nobody match on Thursday" is the funnel, which says who
  /// was *filtered*, and says nothing about the four people who passed every
  /// filter and still had no legal group between them.
  final List<RejectedAlternate> abandonedAlternates;

  /// A JSON-ready form for `match_runs.stats`.
  Map<String, Object?> toJson() => {
    'eligible_considered': eligibleConsidered,
    'placed': placed,
    'unplaced': unplaced,
    'rebuild_attempts': rebuildAttempts,
    'filtered': funnel.toJson(),
    'rings': ringLedger.toJson(),
    'abandoned': [
      for (final alternate in abandonedAlternates) alternate.toJson(),
    ],
  };

  @override
  String toString() => 'RunStats($placed placed, $unplaced unplaced)';
}

/// The output of one match run.
///
/// A value. It writes nothing, and the worker persists it in one transaction
/// that re-validates the invariants server-side — so even a compromised worker
/// cannot create a hangout that violates an exclusion.
@immutable
final class MatchPlan {
  /// Records a plan.
  const MatchPlan({
    required this.city,
    required this.seed,
    required this.snapshotHash,
    required this.configVersion,
    required this.hangouts,
    required this.stats,
    required this.seedWeights,
  });

  /// Which city this plan is for.
  final CityId city;

  /// The run seed. With [snapshotHash] this makes the plan reproducible, and
  /// reproducibility is the only reason a surprising run can be replayed.
  final int seed;

  /// A digest of the inputs, so a replay that disagrees can say *which* side
  /// changed.
  final String snapshotHash;

  /// The config version in force.
  final ConfigVersionId configVersion;

  /// The proposed hangouts.
  final List<PlannedHangout> hangouts;

  /// What the run did.
  final RunStats stats;

  /// The seed weights the policy used, for the console's explain view.
  final List<SeedWeight> seedWeights;

  /// Everybody the plan places.
  Set<PersonId> get placedPeople => {
    for (final hangout in hangouts)
      for (final member in hangout.members) member.person,
  };

  @override
  String toString() =>
      'MatchPlan(${city.value}, ${hangouts.length} hangouts, '
      'seed=$seed, snapshot=$snapshotHash)';
}
