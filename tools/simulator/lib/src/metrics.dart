import 'dart:math' as math;

import 'package:ekipa_core/ekipa_core.dart';

/// What one simulated week did.
///
/// **Only the numbers §8 asks for.** A simulator that reports everything it can
/// compute is a simulator whose output nobody reads, and the difference between
/// a metric and a number is that somebody has already said what decision it
/// changes. Each field below has one.
final class WeekMetrics {
  /// Records a week.
  const WeekMetrics({
    required this.week,
    required this.active,
    required this.available,
    required this.planned,
    required this.held,
    required this.cancelled,
    required this.placed,
    required this.confirmed,
    required this.attended,
    required this.cancelReasons,
    required this.newEdges,
    required this.newExclusions,
    required this.departures,
    required this.arrivals,
    required this.filtered,
    required this.ringRealised,
    required this.unplaced,
  });

  /// Which week, counted from zero.
  final int week;

  /// Agents still in the city.
  final int active;

  /// Agents who marked at least one slot.
  ///
  /// The denominator of the match rate. Using [active] instead would blame the
  /// matcher for people who never asked for anything.
  final int available;

  /// Hangouts the matcher proposed.
  final int planned;

  /// Hangouts that actually happened.
  final int held;

  /// Hangouts that collapsed before they ran.
  final int cancelled;

  /// People the matcher placed in a group.
  final int placed;

  /// People who said yes, whether or not their group survived.
  ///
  /// **Separate from [attended] on purpose, and it took a run to notice.** The
  /// first version of this report divided people-in-a-held-hangout by
  /// people-placed and called it attendance, which folded the cancellation rule
  /// into the attendance number: a population that always turned up would still
  /// have shown 55%, because a 2+2 that loses one member is cancelled by the
  /// composition rule rather than run. Two different failures wearing one
  /// number is how a tuning harness misleads the person tuning.
  final int confirmed;

  /// People who sat in a hangout that actually happened.
  final int attended;

  /// Why groups collapsed, by `CompositionFailure` name.
  ///
  /// The interesting half of the cancellation rate. "Six groups collapsed"
  /// invites a shrug; "six groups collapsed on loneGender" is a decision about
  /// what backfill has to prioritise.
  final Map<String, int> cancelReasons;

  /// Mutual edges formed this week.
  final int newEdges;

  /// Permanent exclusions created this week.
  ///
  /// Watched because it only ever goes up. In a city this size an exclusion
  /// rate that looks small per week is a matching constraint that compounds,
  /// and it shows up months later as a match rate nobody can explain.
  final int newExclusions;

  /// Agents who left.
  final int departures;

  /// Agents who joined.
  final int arrivals;

  /// The matcher's filter funnel, by reason.
  final Map<String, int> filtered;

  /// The realised ring mix, by storage code.
  final Map<String, int> ringRealised;

  /// Eligible people the matcher could not place.
  final int unplaced;

  /// Share of available people who got a group.
  double get matchRate => available == 0 ? 0 : placed / available;

  /// Share of proposed hangouts that collapsed.
  double get cancellationRate => planned == 0 ? 0 : cancelled / planned;

  /// Share of placed people who said yes.
  double get attendanceRate => placed == 0 ? 0 : confirmed / placed;
}

/// The whole run, reduced to the questions `03_MATCHMAKER.md` §8 asks.
final class SimulationReport {
  /// Records a run.
  const SimulationReport({
    required this.seed,
    required this.weeks,
    required this.timeToFirstHangout,
    required this.neverMatchedShare,
    required this.repeatSaturation,
    required this.edgesPerHangout,
    required this.closedTriadShare,
    required this.hangoutGini,
    required this.finalActive,
    required this.totalHeld,
    required this.ringConfigured,
  });

  /// The seed the run came from. Printed so a surprising table is re-runnable.
  final int seed;

  /// Week by week.
  final List<WeekMetrics> weeks;

  /// Weeks from joining to first hangout, as `(p50, p90)`, over agents who ever
  /// got one.
  final (double, double) timeToFirstHangout;

  /// Share of agents who left, or finished the run, having never been matched.
  ///
  /// **The number that decides whether the product works at launch.** A healthy
  /// median time-to-first-hangout means nothing if a fifth of the city is in
  /// the tail that never appears in it.
  final double neverMatchedShare;

  /// Mean share of a person's hangouts that contained somebody they had already
  /// met, over people with at least two hangouts.
  ///
  /// Both ends are failures: zero means the ring ratios did nothing and every
  /// evening is strangers; near one means the graph closed and the app became a
  /// group chat with a venue.
  final double repeatSaturation;

  /// Mutual edges formed per hangout held.
  final double edgesPerHangout;

  /// Share of edges that sit in at least one triangle.
  ///
  /// The clique measure. A rising line here with a falling match rate is
  /// clique capture, which is the specific way this matcher fails.
  final double closedTriadShare;

  /// Gini concentration of hangouts across agents who were ever available.
  ///
  /// Zero is everyone equal, one is one person taking everything. It answers
  /// "is the top decile absorbing the hangouts" without needing a decile.
  final double hangoutGini;

  /// Agents still in the city at the end.
  final int finalActive;

  /// Hangouts held across the run.
  final int totalHeld;

  /// The configured ring shares, so the report can print configured beside
  /// realised — the comparison the whole ledger exists for.
  final Map<String, double> ringConfigured;

  /// The realised ring mix summed over the run.
  Map<String, int> get ringRealised {
    final total = <String, int>{};
    for (final week in weeks) {
      for (final entry in week.ringRealised.entries) {
        total[entry.key] = (total[entry.key] ?? 0) + entry.value;
      }
    }
    return total;
  }

  /// Why groups collapsed, summed over the run.
  Map<String, int> get cancelReasons {
    final total = <String, int>{};
    for (final week in weeks) {
      for (final entry in week.cancelReasons.entries) {
        total[entry.key] = (total[entry.key] ?? 0) + entry.value;
      }
    }
    return total;
  }

  /// The filter funnel summed over the run.
  Map<String, int> get filtered {
    final total = <String, int>{};
    for (final week in weeks) {
      for (final entry in week.filtered.entries) {
        total[entry.key] = (total[entry.key] ?? 0) + entry.value;
      }
    }
    return total;
  }

  /// A JSON-ready form, so `--json` output can be diffed between two configs.
  Map<String, Object?> toJson() => {
    'seed': seed,
    'weeks': [
      for (final week in weeks)
        {
          'week': week.week,
          'active': week.active,
          'available': week.available,
          'planned': week.planned,
          'held': week.held,
          'cancelled': week.cancelled,
          'placed': week.placed,
          'confirmed': week.confirmed,
          'attended': week.attended,
          'cancel_reasons': week.cancelReasons,
          'unplaced': week.unplaced,
          'new_edges': week.newEdges,
          'new_exclusions': week.newExclusions,
          'arrivals': week.arrivals,
          'departures': week.departures,
          'match_rate': week.matchRate,
        },
    ],
    'time_to_first_hangout_p50': timeToFirstHangout.$1,
    'time_to_first_hangout_p90': timeToFirstHangout.$2,
    'never_matched_share': neverMatchedShare,
    'repeat_saturation': repeatSaturation,
    'edges_per_hangout': edgesPerHangout,
    'closed_triad_share': closedTriadShare,
    'hangout_gini': hangoutGini,
    'final_active': finalActive,
    'total_held': totalHeld,
    'ring_configured': ringConfigured,
    'ring_realised': ringRealised,
    'filtered': filtered,
    'cancel_reasons': cancelReasons,
  };
}

/// The statistics the report needs, written out rather than depended on.
///
/// Three functions is not worth a package under SC-2, and a percentile whose
/// interpolation rule you cannot read is a number you cannot defend.
abstract final class Stats {
  /// The [fraction] quantile of [values], by linear interpolation.
  ///
  /// Returns `0` for an empty list rather than throwing: an empty list here
  /// means "nobody ever matched", which is a result the report must be able to
  /// print, not an error it should die on.
  static double percentile(List<num> values, double fraction) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    if (sorted.length == 1) return sorted.first.toDouble();
    final position = fraction * (sorted.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower].toDouble();
    final weight = position - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  /// The Gini coefficient of [values]. Zero is perfect equality.
  static double gini(List<num> values) {
    if (values.length < 2) return 0;
    final sorted = [...values]..sort();
    final total = sorted.fold<double>(0, (sum, v) => sum + v);
    if (total == 0) return 0;
    var weighted = 0.0;
    for (var i = 0; i < sorted.length; i++) {
      weighted += (i + 1) * sorted[i];
    }
    final n = sorted.length;
    return (2 * weighted) / (n * total) - (n + 1) / n;
  }

  /// The share of edges that belong to at least one triangle.
  ///
  /// Triangles rather than a clustering coefficient because the failure has a
  /// shape: three people who all know each other are the seed of a group the
  /// composition rule will keep refusing, and counting them directly says how
  /// much of the graph has already closed.
  static double closedTriadShare(Iterable<PairKey> pairs) {
    final edges = pairs.toSet();
    if (edges.isEmpty) return 0;
    final neighbours = <PersonId, Set<PersonId>>{};
    for (final edge in edges) {
      (neighbours[edge.low] ??= {}).add(edge.high);
      (neighbours[edge.high] ??= {}).add(edge.low);
    }
    var closed = 0;
    for (final edge in edges) {
      final shared = (neighbours[edge.low] ?? const <PersonId>{}).intersection(
        neighbours[edge.high] ?? const <PersonId>{},
      );
      if (shared.isNotEmpty) closed++;
    }
    return closed / edges.length;
  }

  /// The mean of [values], or zero when there are none.
  static double mean(Iterable<num> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.fold<double>(0, (sum, v) => sum + v) / list.length;
  }

  /// Clamps a probability into `[0, 1]`.
  static double probability(double value) => math.min(1, math.max(0, value));
}
