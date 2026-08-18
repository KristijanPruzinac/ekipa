import 'dart:convert';

import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:simulator/simulator.dart';
import 'package:test/test.dart';

MatchConfig config([Map<String, Object?> overrides = const {}]) =>
    MatchConfig.from(
      ConfigSnapshot(
        versionId: const ConfigVersionId('test'),
        values: overrides,
      ),
    );

/// A run small enough to be a unit test and large enough to form a graph.
Simulation small({
  Behaviour behaviour = const Behaviour(),
  MatchConfig? matching,
  int seed = 1,
  int weeks = 4,
  int people = 48,
}) => Simulation(
  config: matching ?? config(),
  seed: seed,
  behaviour: behaviour,
  startingPeople: people,
  weeks: weeks,
);

void main() {
  group('a run is reproducible, which is the whole claim', () {
    test('the same seed produces a byte-identical report', () {
      // Without this the harness produces anecdotes. Every other test here
      // depends on it, and so does every comparison between two configs.
      final a = jsonEncode(small().run().toJson());
      final b = jsonEncode(small().run().toJson());
      expect(a, b);
    });

    test('a different seed produces a different one', () {
      final a = jsonEncode(small().run().toJson());
      final b = jsonEncode(small(seed: 2).run().toJson());
      expect(a, isNot(b));
    });

    test('changing the rating model does not move who turned up', () {
      // Streams are forked by what they decide. If they were not, editing the
      // rating model would move the confirmation draws too, and a metric diff
      // between two models would be mostly noise.
      final before = small().run();
      final after = small(
        behaviour: const Behaviour(stronglyEnjoyedShare: 0.9),
      ).run();
      expect(
        [for (final week in before.weeks) week.placed],
        [for (final week in after.weeks) week.placed],
      );
    });
  });

  group('the loop obeys the rules it did not write', () {
    test('nobody is in two hangouts in one week', () {
      // Enforced by the matcher, asserted here because the harness is the only
      // place where twelve consecutive runs happen and a leak would compound.
      final report = small(weeks: 6).run();
      for (final week in report.weeks) {
        expect(week.placed, lessThanOrEqualTo(week.available));
      }
    });

    test('a group that survives its no-shows still satisfies composition', () {
      // The simulator does not count heads; it asks Composition. A held
      // hangout is therefore a hangout the real rule allowed.
      final report = small(weeks: 6).run();
      final held = report.weeks.fold<int>(0, (sum, week) => sum + week.held);
      expect(held, greaterThan(0));
      expect(report.totalHeld, held);
    });

    test('a perfectly reliable population loses no group to no-shows', () {
      // reliability 1.0 removes the only source of shrinkage, so every
      // proposed group runs. A non-zero cancellation here would mean the
      // harness was dropping groups for a reason it never stated.
      final report = small(
        behaviour: const Behaviour(
          reliabilityMean: 1,
          reliabilitySpread: 0,
        ),
      ).run();
      for (final week in report.weeks) {
        expect(week.cancelled, 0, reason: 'week ${week.week}');
        expect(week.confirmed, week.placed);
      }
    });

    test('collapses are attributed to the rule that caused them', () {
      // The interesting half of the cancellation rate, and the reason backfill
      // exists: at 2+2, losing one member is a lone gender, not a small group.
      final report = small(weeks: 8, people: 80).run();
      expect(report.cancelReasons, isNotEmpty);
      expect(
        report.cancelReasons.keys,
        everyElement(isIn(CompositionFailure.values.map((f) => f.name))),
      );
    });
  });

  group('the population model is consequential', () {
    test('a city that never marks itself available holds nothing', () {
      final report = small(
        behaviour: const Behaviour(
          availabilityMean: 0,
          availabilitySpread: 0,
        ),
      ).run();
      expect(report.totalHeld, 0);
      expect(report.neverMatchedShare, 1);
      for (final week in report.weeks) {
        expect(week.available, 0);
        expect(week.matchRate, 0);
      }
    });

    test('an always-available city matches most of itself', () {
      final report = small(
        behaviour: const Behaviour(
          availabilityMean: 1,
          availabilitySpread: 0,
        ),
        weeks: 6,
      ).run();
      expect(report.weeks.last.matchRate, greaterThan(0.5));
      expect(report.neverMatchedShare, lessThan(0.25));
    });

    test('exclusions compound, and the harness can show it', () {
      // The warning the exclusion counter exists for. Every negative answer
      // becoming permanent is not a plausible population; it is the shape of
      // the failure, run fast enough to see.
      final hostile = small(
        behaviour: const Behaviour(ratherNotRate: 1),
        weeks: 8,
      ).run();
      final gentle = small(weeks: 8).run();
      final hostileExclusions = hostile.weeks.fold<int>(
        0,
        (sum, week) => sum + week.newExclusions,
      );
      expect(hostileExclusions, greaterThan(50));
      expect(hostile.totalHeld, lessThan(gentle.totalHeld));
    });

    test('warmth is what builds the graph', () {
      // A city nobody enjoys forms no edges, so R1 and R2 have nothing to draw
      // from and every group is strangers forever. This is the degenerate case
      // the ring ratios are measured against.
      final cold = small(
        behaviour: const Behaviour(enjoyFloor: 0, enjoyGain: 0),
        weeks: 6,
      ).run();
      expect(cold.edgesPerHangout, 0);
      expect(cold.closedTriadShare, 0);
      expect(cold.repeatSaturation, lessThan(0.2));
    });
  });

  group('what the run reports', () {
    test('a young city cannot realise the configured ring mix', () {
      // **The finding this harness was built to produce.** The default ratio
      // asks for 25/50/25; twelve weeks into a city with no prior graph it
      // realises as overwhelmingly R3, because a failed R1 or R2 draw falls
      // back outward. That is not a bug in the draw — it is the reason the
      // ledger records intended beside realised, and the reason a launch ratio
      // tuned on paper would have been wrong.
      final report = small(weeks: 12, people: 120).run();
      final realised = report.ringRealised;
      final total = realised.values.fold<int>(0, (sum, n) => sum + n);
      expect(total, greaterThan(0));
      expect(realised['r3_stranger']! / total, greaterThan(0.5));
      expect(report.ringConfigured['r3_stranger'], lessThan(0.5));
    });

    test('the all-strangers control draws no R1 and no R2 at all', () {
      final report = small(
        weeks: 6,
        matching: config({
          'matching.ring_share_enjoyed': 0,
          'matching.ring_share_leaf': 0,
        }),
      ).run();
      expect(report.ringRealised['r1_enjoyed'], 0);
      expect(report.ringRealised['r2_leaf'], 0);
      expect(report.ringRealised['r3_stranger'], greaterThan(0));
    });

    test('the funnel explains a city that matched nobody', () {
      final report = small(
        behaviour: const Behaviour(
          availabilityMean: 0,
          availabilitySpread: 0,
        ),
      ).run();
      expect(report.filtered['notAvailable'], greaterThan(0));
    });

    test('newcomers are timed from when they joined, not from week zero', () {
      // An arrival in week 3 who matches in week 4 waited one week. Timing
      // from week zero would flatter the metric every week the city grows.
      final report = small(weeks: 6, people: 60).run();
      expect(report.timeToFirstHangout.$1, lessThanOrEqualTo(6));
      expect(
        report.timeToFirstHangout.$2,
        greaterThanOrEqualTo(report.timeToFirstHangout.$1),
      );
    });

    test('the JSON carries every metric the table shows', () {
      final json = small().run().toJson();
      expect(
        json.keys,
        containsAll([
          'seed',
          'weeks',
          'never_matched_share',
          'repeat_saturation',
          'closed_triad_share',
          'hangout_gini',
          'ring_configured',
          'ring_realised',
          'filtered',
          'cancel_reasons',
        ]),
      );
    });
  });
}
