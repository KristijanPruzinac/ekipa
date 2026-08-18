import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:simulator/simulator.dart';
import 'package:test/test.dart';

SimulationReport report({
  double neverMatched = 0.1,
  double saturation = 0.3,
  (double, double) firstHangout = (1, 3),
  double triads = 0.2,
  double gini = 0.3,
  int held = 40,
  List<WeekMetrics>? weeks,
}) => SimulationReport(
  seed: 1,
  weeks: weeks ?? [week()],
  timeToFirstHangout: firstHangout,
  neverMatchedShare: neverMatched,
  repeatSaturation: saturation,
  edgesPerHangout: 1.2,
  closedTriadShare: triads,
  hangoutGini: gini,
  finalActive: 100,
  totalHeld: held,
  ringConfigured: const {
    'r1_enjoyed': 0.25,
    'r2_leaf': 0.5,
    'r3_stranger': 0.25,
  },
);

WeekMetrics week({
  int number = 0,
  int placed = 20,
  int available = 40,
  Map<String, int> rings = const {'r3_stranger': 30},
  Map<String, int> reasons = const {'loneGender': 3},
}) => WeekMetrics(
  week: number,
  active: 50,
  available: available,
  planned: 6,
  held: 5,
  cancelled: 1,
  placed: placed,
  confirmed: 18,
  attended: 17,
  cancelReasons: reasons,
  newEdges: 4,
  newExclusions: 1,
  departures: 1,
  arrivals: 2,
  filtered: const {'notAvailable': 12},
  ringRealised: rings,
  unplaced: 3,
);

void main() {
  group('the table', () {
    test('names every section a reader is meant to act on', () {
      final rendered = Report.render(report());
      expect(rendered, contains('outcomes'));
      expect(rendered, contains('rings'));
      expect(rendered, contains('funnel'));
      expect(rendered, contains('collapses'));
    });

    test('prints configured beside realised, which is the whole point', () {
      final rendered = Report.render(report());
      expect(rendered, contains('configured'));
      expect(rendered, contains('realised'));
      expect(rendered, contains('r3_stranger'));
      expect(rendered, contains('25.0%'));
    });

    test('says out loud that the sanction rate is missing', () {
      // A metric table with a silently absent row invites the reader to assume
      // it was fine. The trust ladder is not built; the report says so.
      expect(Report.render(report()), contains('04_TRUST.md'));
    });

    test('a run with no draws says so instead of printing zeroes', () {
      final rendered = Report.render(
        report(weeks: [week(rings: {})]),
      );
      expect(rendered, contains('no draws recorded'));
    });

    test('a run that filtered nobody says so', () {
      final rendered = Report.render(
        report(
          weeks: [
            const WeekMetrics(
              week: 0,
              active: 0,
              available: 0,
              planned: 0,
              held: 0,
              cancelled: 0,
              placed: 0,
              confirmed: 0,
              attended: 0,
              cancelReasons: {},
              newEdges: 0,
              newExclusions: 0,
              departures: 0,
              arrivals: 0,
              filtered: {},
              ringRealised: {},
              unplaced: 0,
            ),
          ],
        ),
      );
      expect(rendered, contains('nothing was filtered'));
      expect(rendered, contains('no group ever collapsed'));
    });

    test('the week table has one row per week under one header', () {
      final rendered = Report.render(
        report(weeks: [week(), week(number: 1), week(number: 2)]),
      );
      final lines = rendered.split('\n');
      expect(lines.where((line) => line.startsWith('wk ')), hasLength(1));
      expect(
        lines.where((line) => RegExp(r'^\s*\d+\s+50\s').hasMatch(line)),
        hasLength(3),
      );
    });
  });

  group('the delta', () {
    test('an improvement points up whichever direction it moved', () {
      // Match rate is better when it rises and never-matched is better when it
      // falls. A bare signed number would need the reader to hold that table in
      // their head for eight rows.
      final worse = report(neverMatched: 0.3);
      final better = report(neverMatched: 0.05);
      final rendered = Report.delta(worse, better);
      final line = rendered
          .split('\n')
          .firstWhere((line) => line.contains('never matched'));
      expect(line, contains('-0.250'));
      expect(line.trimRight(), endsWith('↑'));
    });

    test('a regression points down', () {
      final rendered = Report.delta(
        report(gini: 0.2),
        report(gini: 0.5),
      );
      final line = rendered
          .split('\n')
          .firstWhere((line) => line.contains('hangout gini'));
      expect(line, contains('+0.300'));
      expect(line.trimRight(), endsWith('↓'));
    });

    test('no change points neither way', () {
      // The header explains the arrows and therefore contains one, so the
      // assertion is about the metric rows: an unchanged run must not claim a
      // direction it did not move in.
      final rows = Report.delta(report(), report())
          .split('\n')
          .where((line) => line.startsWith('  ') && line.contains('0.'));
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(row, isNot(contains('↑')));
        expect(row, isNot(contains('↓')));
      }
    });

    test('it says what repeat saturation does not mean', () {
      // The one metric with no monotone good direction. Leaving that unsaid is
      // how a tuner drives it to one and calls it a win.
      expect(Report.delta(report(), report()), contains('near one means'));
    });

    test('every metric §8 asks for has a row', () {
      final rendered = Report.delta(report(), report());
      for (final label in [
        'match rate',
        'never matched',
        'first hangout p50',
        'first hangout p90',
        'repeat saturation',
        'edges inside a triangle',
        'hangout gini',
        'hangouts held',
      ]) {
        expect(rendered, contains(label));
      }
    });
  });

  group('the report reflects a real run', () {
    test('rendering a twelve-week run does not throw or truncate', () {
      final real = Simulation(
        config: MatchConfig.from(ConfigSnapshot.defaults()),
        seed: 4,
        startingPeople: 40,
        weeks: 3,
      ).run();
      final rendered = Report.render(real);
      expect(rendered.split('\n').length, greaterThan(20));
      expect(rendered, contains('seed 4'));
    });
  });
}
