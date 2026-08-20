import 'package:ekipa_core/src/domain/person.dart';
import 'package:ekipa_core/src/domain/slot.dart';
import 'package:ekipa_core/src/matching/matching_config.dart';
import 'package:ekipa_core/src/matching/snapshot.dart';
import 'package:meta/meta.dart';

/// Why somebody, or some pair, was excluded.
///
/// **Intention.** Named rather than boolean, because the most useful thing the
/// console can say about a quiet night is *"nobody matched: 12 filtered by
/// cooldown, 3 by standing, 5 by distance"*. The least useful thing it can say
/// is "nothing happened", and that is exactly what an `if` chain returning
/// `false` produces.
enum FilterReason {
  /// Did not mark themselves available for this slot.
  notAvailable,

  /// Already placed in this slot, or one that overlaps it.
  alreadyPlaced,

  /// Suspended, banned, or a throttle quota already spent.
  standing,

  /// Has an unrated past hangout. The rating gate: it blocks *being matched
  /// again*, never app access.
  ratingGate,

  /// No verified identity, no anchor, or no gender yet.
  profileIncomplete,

  /// Not in this run's city.
  otherCity,

  /// An exclusion exists. Never overridden, for any reason, including backfill
  /// urgency.
  excluded,

  /// The pair met too recently.
  cooldown,

  /// No venue cluster both could reach.
  noSharedCluster,
}

/// One rejection, with the rule that produced it.
@immutable
final class Rejection {
  /// Records why a candidate was refused.
  const Rejection(this.reason, {this.detail});

  /// Which rule fired.
  final FilterReason reason;

  /// Optional, non-identifying elaboration for diagnostics.
  final String? detail;

  @override
  String toString() =>
      'Rejection(${reason.name}${detail == null ? '' : ': $detail'})';
}

/// Counts of rejections by reason — the eligibility funnel.
///
/// Written to `match_runs.stats`. Without it the console can only report that
/// nothing happened, which is the least useful sentence a matcher can produce.
final class FilterFunnel {
  /// An empty funnel.
  FilterFunnel();

  final Map<FilterReason, int> _counts = {};

  /// Records one rejection.
  void record(FilterReason reason) =>
      _counts[reason] = (_counts[reason] ?? 0) + 1;

  /// How many were rejected for [reason].
  int countOf(FilterReason reason) => _counts[reason] ?? 0;

  /// Total rejections recorded.
  int get total => _counts.values.fold(0, (sum, n) => sum + n);

  /// A JSON-ready map for `match_runs.stats`.
  Map<String, int> toJson() => {
    for (final entry in _counts.entries) entry.key.name: entry.value,
  };

  @override
  String toString() => 'FilterFunnel(${toJson()})';
}

/// A named, separately testable hard constraint on one person.
///
/// **Intention.** 03_MATCHMAKER.md §② asks for a `Specification` composition
/// rather than an `if` chain, for three reasons that all turn out to matter:
/// each rule is testable alone, the failing rule is *nameable* in diagnostics,
/// and adding a rule cannot silently reorder the existing ones.
///
/// Hard constraints are never scored. A person who fails one is not a worse
/// candidate, they are not a candidate — and blurring that distinction is how
/// an exclusion becomes "a strong negative weight" and then, on a thin night,
/// becomes a match.
@immutable
abstract interface class PersonRule {
  /// The reason this rule reports when it refuses.
  FilterReason get reason;

  /// Whether [person] passes, for [slot], given [snapshot] and [config].
  bool permits(
    Person person,
    Slot slot,
    MatchSnapshot snapshot,
    MatchConfig config,
  );
}

/// A named hard constraint on a pair.
@immutable
abstract interface class PairRule {
  /// The reason this rule reports when it refuses.
  FilterReason get reason;

  /// Whether [a] and [b] may sit together.
  bool permits(Person a, Person b, MatchSnapshot snapshot, MatchConfig config);
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-person rules.

/// Availability for this slot, as claimed by the person.
final class MustBeAvailable implements PersonRule {
  /// Constructs the rule.
  const MustBeAvailable();

  @override
  FilterReason get reason => FilterReason.notAvailable;

  @override
  bool permits(Person p, Slot slot, MatchSnapshot s, MatchConfig c) =>
      s.availableFor(slot.id).contains(p.id);
}

/// Not already placed in this slot or an overlapping one.
///
/// The overlap half is the part that is easy to omit. Two 90-minute windows
/// that touch are two groups holding the same person, and at least one of them
/// waits for somebody who is not coming.
final class MustNotBeDoubleBooked implements PersonRule {
  /// Constructs the rule.
  const MustNotBeDoubleBooked();

  @override
  FilterReason get reason => FilterReason.alreadyPlaced;

  @override
  bool permits(Person p, Slot slot, MatchSnapshot s, MatchConfig c) {
    final placed = s.placedSlotsOf(p.id);
    if (placed.contains(slot.id)) return false;
    for (final other in s.slots) {
      if (placed.contains(other.id) && other.overlaps(slot)) return false;
    }
    return true;
  }
}

/// Standing permits being matched at all.
final class MustBeInMatchableStanding implements PersonRule {
  /// Constructs the rule.
  const MustBeInMatchableStanding();

  @override
  FilterReason get reason => FilterReason.standing;

  @override
  bool permits(Person p, Slot slot, MatchSnapshot s, MatchConfig c) =>
      p.standing.mayBeMatched;
}

/// In the city this run is for.
final class MustBeInThisCity implements PersonRule {
  /// Constructs the rule.
  const MustBeInThisCity();

  @override
  FilterReason get reason => FilterReason.otherCity;

  @override
  bool permits(Person p, Slot slot, MatchSnapshot s, MatchConfig c) =>
      p.cityId == s.cityId && slot.cityId == s.cityId;
}

/// Reachable clusters exist at all.
///
/// A person with no reachable cluster is not unpopular, they are unreachable —
/// a structural problem with their anchor or their travel radius, and the
/// console's unmatched report is where they should surface. Silently scoring
/// them low would bury that.
final class MustReachSomewhere implements PersonRule {
  /// Constructs the rule.
  const MustReachSomewhere();

  @override
  FilterReason get reason => FilterReason.noSharedCluster;

  @override
  bool permits(Person p, Slot slot, MatchSnapshot s, MatchConfig c) =>
      p.reachableClusters.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-pair rules.

/// No exclusion, in either direction.
///
/// **Never overridden.** Not for backfill urgency, not to save a group from
/// cancellation, not because the alternative is a thin night. This is the rule
/// the whole `rather_not` answer is a promise about, and a promise with an
/// exception is not one.
final class MustNotBeExcluded implements PairRule {
  /// Constructs the rule.
  const MustNotBeExcluded();

  @override
  FilterReason get reason => FilterReason.excluded;

  @override
  bool permits(Person a, Person b, MatchSnapshot s, MatchConfig c) =>
      !s.isExcluded(a.id, b.id);
}

/// The cooldown: `max(cooldown_meetups, cooldown_days)`.
///
/// **Intention, twofold.** Repeated exposure is the only known mechanism by
/// which acquaintances become friends, so repetition must be *possible*; and
/// guaranteed repetition would leak rating information, so it must never be
/// *certain*. The cooldown also provides social cover — because even the best
/// pairs sit out a couple of rounds, "we have not been matched again" is the
/// normal experience for everyone and carries no signal.
final class MustBePastCooldown implements PairRule {
  /// Constructs the rule.
  const MustBePastCooldown();

  @override
  FilterReason get reason => FilterReason.cooldown;

  @override
  bool permits(Person a, Person b, MatchSnapshot s, MatchConfig c) {
    final edge = s.edgeBetween(a.id, b.id);
    final intervening = s.interveningHangoutsSince(a.id, b.id);
    if (edge == null && intervening == null) return true;

    if (intervening != null && intervening < c.cooldownMeetups) return false;

    final lastMet = edge?.lastMetAt ?? _lastMeeting(a, b, s);
    if (lastMet == null) return true;
    final daysSince = s.takenAt.difference(lastMet).inDays;
    return daysSince >= c.cooldownDays;
  }

  static DateTime? _lastMeeting(Person a, Person b, MatchSnapshot s) {
    DateTime? latest;
    for (final past in s.history) {
      if (!past.members.contains(a.id) || !past.members.contains(b.id)) {
        continue;
      }
      if (latest == null || past.endedAt.isAfter(latest)) latest = past.endedAt;
    }
    return latest;
  }
}

/// At least one venue cluster both could reach.
///
/// The geographic unit is the cluster, not raw pairwise distance, because the
/// cluster is what a meeting point will eventually be chosen from. Two people
/// 400 m apart on opposite sides of a river are further apart than the number
/// says; two people 3 km apart who both reach the same square are not.
final class MustShareACluster implements PairRule {
  /// Constructs the rule.
  const MustShareACluster();

  @override
  FilterReason get reason => FilterReason.noSharedCluster;

  @override
  bool permits(Person a, Person b, MatchSnapshot s, MatchConfig c) =>
      a.sharesClusterWith(b);
}

// ─────────────────────────────────────────────────────────────────────────────

/// The composed hard filter for one slot.
///
/// Order matters only for the funnel's readability, not for correctness: every
/// rule must pass, so a candidate rejected by two rules is reported under the
/// first. Cheap and common rules come first so the common case is fast and the
/// funnel reads in the order a person would ask the questions.
final class Eligibility {
  /// Composes the default rule set.
  Eligibility({List<PersonRule>? personRules, List<PairRule>? pairRules})
    : personRules =
          personRules ??
          const [
            MustBeInThisCity(),
            MustBeAvailable(),
            MustNotBeDoubleBooked(),
            MustBeInMatchableStanding(),
            MustReachSomewhere(),
          ],
      pairRules =
          pairRules ??
          const [
            MustNotBeExcluded(),
            MustBePastCooldown(),
            MustShareACluster(),
          ];

  /// The per-person rules, in evaluation order.
  final List<PersonRule> personRules;

  /// The per-pair rules, in evaluation order.
  final List<PairRule> pairRules;

  /// The first rule [person] fails, or `null` if they pass every one.
  Rejection? reject(
    Person person,
    Slot slot,
    MatchSnapshot snapshot,
    MatchConfig config,
  ) {
    for (final rule in personRules) {
      if (!rule.permits(person, slot, snapshot, config)) {
        return Rejection(rule.reason);
      }
    }
    return null;
  }

  /// The first rule the pair fails, or `null` if they may sit together.
  Rejection? rejectPair(
    Person a,
    Person b,
    MatchSnapshot snapshot,
    MatchConfig config,
  ) {
    for (final rule in pairRules) {
      if (!rule.permits(a, b, snapshot, config)) {
        return Rejection(rule.reason);
      }
    }
    return null;
  }

  /// Everyone eligible for [slot], with the funnel filled in.
  ///
  /// Returns them in snapshot order rather than sorted. Sorting here would
  /// invite the caller to treat the first entry as the best one, and there is
  /// no "best" at this stage — these are the people who are *allowed*, which is
  /// a different question from who should be chosen.
  List<Person> eligibleFor(
    Slot slot,
    MatchSnapshot snapshot,
    MatchConfig config, {
    FilterFunnel? funnel,
  }) {
    final passing = <Person>[];
    for (final person in snapshot.people) {
      final rejection = reject(person, slot, snapshot, config);
      if (rejection == null) {
        passing.add(person);
      } else {
        funnel?.record(rejection.reason);
      }
    }
    return passing;
  }
}
