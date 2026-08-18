import 'package:simulator/src/metrics.dart';

/// Renders a [SimulationReport] as the table a person reads in a terminal.
///
/// **Why this is a pure function returning a string.** The rendering is the
/// part most likely to be wrong in a way nobody notices — a column misaligned,
/// a rate printed as a count — and a function that prints cannot be asserted
/// on. `bin/simulate.dart` does the printing, in one line, and everything above
/// it is testable.
abstract final class Report {
  /// The full text report.
  static String render(SimulationReport report) => [
    'ekipa simulator — seed ${report.seed}, ${report.weeks.length} weeks',
    '',
    _weekTable(report),
    '',
    _outcomes(report),
    '',
    _rings(report),
    '',
    _funnel(report),
    '',
    _cancellations(report),
    '',
  ].join('\n');

  /// The metric delta between two runs of the same population.
  ///
  /// **Sign is stated, not implied.** Half these metrics are better when they
  /// fall (never-matched, time to first hangout, concentration) and half when
  /// they rise (match rate, hangouts held), so a bare `+0.04` next to a metric
  /// name is a number the reader has to hold a rule in their head to interpret.
  /// The arrow says which way is good.
  static String delta(SimulationReport before, SimulationReport after) {
    final rows = <String>[
      'delta (after − before; ↑ means the change helped)',
      '─' * 62,
    ];

    void row(String label, double a, double b, {required bool higherIsBetter}) {
      final change = b - a;
      final arrow = change == 0
          ? ' '
          : (change > 0) == higherIsBetter
          ? '↑'
          : '↓';
      final sign = change >= 0 ? '+' : '';
      rows.add(
        '  ${label.padRight(28)}'
        '${a.toStringAsFixed(3).padLeft(9)}'
        '${b.toStringAsFixed(3).padLeft(9)}'
        '${'$sign${change.toStringAsFixed(3)}'.padLeft(10)}'
        '  $arrow',
      );
    }

    row(
      'match rate (mean)',
      _meanMatchRate(before),
      _meanMatchRate(after),
      higherIsBetter: true,
    );
    row(
      'never matched',
      before.neverMatchedShare,
      after.neverMatchedShare,
      higherIsBetter: false,
    );
    row(
      'first hangout p50 (weeks)',
      before.timeToFirstHangout.$1,
      after.timeToFirstHangout.$1,
      higherIsBetter: false,
    );
    row(
      'first hangout p90 (weeks)',
      before.timeToFirstHangout.$2,
      after.timeToFirstHangout.$2,
      higherIsBetter: false,
    );
    row(
      'repeat saturation',
      before.repeatSaturation,
      after.repeatSaturation,
      higherIsBetter: true,
    );
    row(
      'edges inside a triangle',
      before.closedTriadShare,
      after.closedTriadShare,
      higherIsBetter: false,
    );
    row(
      'hangout gini',
      before.hangoutGini,
      after.hangoutGini,
      higherIsBetter: false,
    );
    row(
      'hangouts held',
      before.totalHeld.toDouble(),
      after.totalHeld.toDouble(),
      higherIsBetter: true,
    );

    rows
      ..add('')
      ..add(_saturationCaveat);
    return rows.join('\n');
  }

  static const _saturationCaveat =
      '  repeat saturation has no good direction at the extremes: zero means\n'
      '  the rings did nothing, near one means the graph closed. The arrow\n'
      '  assumes you are below the target, which at launch you are.';

  static const _sanctionCaveat =
      '  sanction rate is absent on purpose: the trust ladder in 04_TRUST.md\n'
      '  is not implemented yet, and approximating it here would be a second\n'
      '  copy of a rule that must have exactly one.';

  static String _weekTable(SimulationReport report) {
    const header =
        'wk  active  avail  plan  held  canc  placed  attend  match%  '
        'edges  excl  in  out';
    final rows = <String>[header, '─' * header.length];
    for (final week in report.weeks) {
      rows.add(
        [
          _pad('${week.week}', 2),
          _pad('${week.active}', 8),
          _pad('${week.available}', 7),
          _pad('${week.planned}', 6),
          _pad('${week.held}', 6),
          _pad('${week.cancelled}', 6),
          _pad('${week.placed}', 8),
          _pad('${week.attended}', 8),
          _pad(_percent(week.matchRate), 8),
          _pad('${week.newEdges}', 7),
          _pad('${week.newExclusions}', 6),
          _pad('${week.arrivals}', 4),
          _pad('${week.departures}', 5),
        ].join(),
      );
    }
    return rows.join('\n');
  }

  static String _outcomes(SimulationReport report) {
    final confirmation = _rateOver(
      report,
      (week) => week.confirmed,
      (week) => week.placed,
    );
    final cancellation = _rateOver(
      report,
      (week) => week.cancelled,
      (week) => week.planned,
    );
    final p50 = _weeks(report.timeToFirstHangout.$1);
    final p90 = _weeks(report.timeToFirstHangout.$2);
    return [
      'outcomes',
      '  time to first hangout      p50 $p50   p90 $p90',
      '  never matched              ${_percent(report.neverMatchedShare)}',
      '  repeat saturation          ${_percent(report.repeatSaturation)}',
      '  said yes when asked        ${_percent(confirmation)}',
      '  groups that collapsed      ${_percent(cancellation)}',
      '  edges per hangout          ${_fixed(report.edgesPerHangout)}',
      '  edges inside a triangle    ${_percent(report.closedTriadShare)}',
      '  hangout concentration      gini ${_fixed(report.hangoutGini)}',
      '  hangouts held              ${report.totalHeld}',
      '  still here at the end      ${report.finalActive}',
      '',
      _sanctionCaveat,
    ].join('\n');
  }

  static String _rings(SimulationReport report) {
    final realised = report.ringRealised;
    final total = realised.values.fold<int>(0, (sum, count) => sum + count);
    final rows = <String>['rings                configured   realised'];
    for (final entry in report.ringConfigured.entries) {
      final count = realised[entry.key] ?? 0;
      final share = total == 0 ? 0.0 : count / total;
      final left = _padRight(entry.key, 18);
      final middle = _pad(_percent(entry.value), 10);
      final right = _pad('${_percent(share)} ($count)', 14);
      rows.add('  $left $middle $right');
    }
    if (total == 0) {
      rows.add('  no draws recorded — every group was a leftover placement');
    }
    return rows.join('\n');
  }

  static String _cancellations(SimulationReport report) {
    final reasons = report.cancelReasons;
    if (reasons.isEmpty) return 'collapses  no group ever collapsed';
    final ordered = reasons.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      'collapses (which rule the surviving members broke)',
      for (final entry in ordered)
        '  ${_padRight(entry.key, 24)} ${entry.value}',
    ].join('\n');
  }

  static String _funnel(SimulationReport report) {
    final funnel = report.filtered;
    if (funnel.isEmpty) return 'funnel  nothing was filtered';
    final ordered = funnel.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      'funnel (why people were filtered, across the run)',
      for (final entry in ordered)
        '  ${_padRight(entry.key, 24)} ${entry.value}',
    ].join('\n');
  }

  static double _rateOver(
    SimulationReport report,
    int Function(WeekMetrics) numerator,
    int Function(WeekMetrics) denominator,
  ) {
    var top = 0;
    var bottom = 0;
    for (final week in report.weeks) {
      top += numerator(week);
      bottom += denominator(week);
    }
    return bottom == 0 ? 0 : top / bottom;
  }

  static double _meanMatchRate(SimulationReport report) {
    if (report.weeks.isEmpty) return 0;
    return report.weeks.fold<double>(0, (sum, w) => sum + w.matchRate) /
        report.weeks.length;
  }

  static String _percent(double value) =>
      '${(value * 100).toStringAsFixed(1)}%';

  static String _fixed(double value) => value.toStringAsFixed(3);

  static String _weeks(double value) => '${value.toStringAsFixed(1)}w';

  static String _pad(String value, int width) => value.padLeft(width);

  static String _padRight(String value, int width) => value.padRight(width);
}
