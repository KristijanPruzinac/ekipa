import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:test/test.dart';

import '../support/world.dart';

/// Draws [trials] seeds and counts how often each person came first.
///
/// The policy is a *sampler*, so no single draw proves anything about it. These
/// tests assert distributions over a fixed seed — reproducible, and the only
/// honest way to test something whose whole point is not being deterministic.
Map<String, int> firstSeedCounts(
  List<Person> pool,
  MatchConfig config, {
  int trials = 4000,
}) {
  const policy = SeedPolicy();
  final counts = <String, int>{};
  for (var i = 0; i < trials; i++) {
    final drawn = policy.draw(
      pool,
      config,
      SeededRandomSource(i),
      count: 1,
    );
    if (drawn.isEmpty) continue;
    final id = drawn.first.id.value;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
}

void main() {
  const policy = SeedPolicy();
  final config = defaultConfig();

  group('the seed pool is good standing only', () {
    // This is the fix for the trap in 03_MATCHMAKER.md §④, and it is the single
    // most important test in this file.

    test('a throttled person never seeds, however long they waited', () {
      final throttled = aPerson(
        'throttled',
        weeksWaiting: 52,
        standing: const Standing(
          tier: StandingTier.throttled,
          remainingQuota: 5,
        ),
      );
      final ordinary = aPerson('ordinary', gender: man);

      final counts = firstSeedCounts([throttled, ordinary], config);

      expect(counts['throttled'], isNull);
      expect(counts['ordinary'], greaterThan(0));
    });

    test('and neither is a watched or segregated one', () {
      for (final tier in [StandingTier.watched, StandingTier.segregated]) {
        final person = aPerson('under-$tier', standing: Standing(tier: tier));
        expect(
          policy.poolFrom([person]),
          isEmpty,
          reason: '$tier must not seed',
        );
      }
    });

    test('a throttled person is still placeable, just never the centre', () {
      // The sanction reads honestly: fewer evenings, and never the evening
      // built around you. Excluding them from hangouts entirely would be a
      // suspension nobody chose.
      final throttled = aPerson(
        'throttled',
        standing: const Standing(
          tier: StandingTier.throttled,
          remainingQuota: 2,
        ),
      );
      expect(throttled.standing.mayBeMatched, isTrue);
      expect(throttled.standing.maySeed, isFalse);
    });

    test('waiting under sanction buys nothing at all', () {
      // A throttle is a reduction, not a delay. If waiting accrued credit while
      // sanctioned, the sanction would repay itself with interest the moment it
      // lifted.
      final patient = aPerson(
        'patient',
        standing: const Standing(
          tier: StandingTier.throttled,
          remainingQuota: 9,
        ),
      );
      final veryPatient = aPerson(
        'very-patient',
        weeksWaiting: 400,
        standing: const Standing(
          tier: StandingTier.throttled,
          remainingQuota: 9,
        ),
      );
      expect(policy.poolFrom([patient, veryPatient]), isEmpty);
    });
  });

  group('weights', () {
    test('waiting raises the weight, one gain per week', () {
      final fresh = aPerson('fresh');
      final waited = aPerson('waited', weeksWaiting: 3);
      expect(policy.weightOf(fresh, config).starvationFactor, 1);
      expect(policy.weightOf(waited, config).starvationFactor, 4);
    });

    test('the starvation credit is capped', () {
      // Uncapped, someone unmatchable for a structural reason — no reachable
      // cluster, a gender-ratio dead end — accrues unbounded priority,
      // permanently outranks everyone, and still never gets matched. The cap
      // keeps them on the unmatched report instead of buried in a weight.
      final structurallyStuck = aPerson('stuck', weeksWaiting: 500);
      expect(
        policy.weightOf(structurallyStuck, config).starvationFactor,
        1 + config.starveCapWeeks,
      );
    });

    test('a newcomer is multiplied, because they are the churn risk', () {
      final newcomer = aPerson('newcomer', completedHangouts: 0);
      final regular = aPerson('regular', completedHangouts: 6);
      expect(policy.weightOf(newcomer, config).newcomerFactor, 3);
      expect(policy.weightOf(regular, config).newcomerFactor, 1);
    });

    test('newcomers dominate in practice, not just on paper', () {
      final newcomer = aPerson('newcomer', completedHangouts: 0);
      final regulars = [
        for (var i = 0; i < 3; i++) aPerson('regular-$i', gender: man),
      ];

      final counts = firstSeedCounts([newcomer, ...regulars], config);
      final newcomerShare = counts['newcomer']! / 4000;

      // Weight 3 against three regulars at 1 each: 3/6 = 0.5.
      expect(newcomerShare, closeTo(0.5, 0.05));
    });

    test('a waited-for regular can out-weigh a newcomer', () {
      // Deliberate. The newcomer multiplier is a thumb on the scale, not a
      // queue-jump: somebody who has been ignored for a month should still get
      // a turn.
      final newcomer = aPerson('newcomer', completedHangouts: 0);
      final ignored = aPerson('ignored', gender: man, weeksWaiting: 4);
      expect(
        policy.weightOf(ignored, config).value,
        greaterThan(policy.weightOf(newcomer, config).value),
      );
    });
  });

  group('sampling, not sorting', () {
    test('the longest waiter does not always go first', () {
      // Property 3 of §④: a deterministic order makes composition predictable
      // from outside the system, and a predictable matcher is a gameable one.
      final waited = aPerson('waited', weeksWaiting: 4);
      final fresh = aPerson('fresh', gender: man);

      final counts = firstSeedCounts([waited, fresh], config);

      expect(counts['waited'], greaterThan(0));
      expect(
        counts['fresh'],
        greaterThan(0),
        reason: 'a sorted queue would give the fresh candidate zero draws',
      );
    });

    test('but it goes first more often, which is the point', () {
      final waited = aPerson('waited', weeksWaiting: 4);
      final fresh = aPerson('fresh', gender: man);
      final counts = firstSeedCounts([waited, fresh], config);
      expect(counts['waited'], greaterThan(counts['fresh']!));
    });

    test('the same pool and the same seed give the same sequence', () {
      // The matcher's contract: same snapshot plus same seed produces a
      // byte-identical plan. Without it a run cannot be replayed to answer
      // "why was I in that group?" months later.
      final pool = [
        for (var i = 0; i < 8; i++)
          aPerson('p-$i', weeksWaiting: i % 4, completedHangouts: i),
      ];
      final first = policy.draw(
        pool,
        config,
        SeededRandomSource(42),
        count: 5,
      );
      final second = policy.draw(
        pool,
        config,
        SeededRandomSource(42),
        count: 5,
      );
      expect(
        first.map((p) => p.id.value).toList(),
        second.map((p) => p.id.value).toList(),
      );
    });

    test('a different seed gives a different sequence', () {
      final pool = [for (var i = 0; i < 12; i++) aPerson('p-$i')];
      final a = policy.draw(pool, config, SeededRandomSource(1), count: 6);
      final b = policy.draw(pool, config, SeededRandomSource(2), count: 6);
      expect(
        a.map((p) => p.id.value).toList(),
        isNot(b.map((p) => p.id.value).toList()),
      );
    });

    test('nobody is drawn twice', () {
      final pool = [for (var i = 0; i < 10; i++) aPerson('p-$i')];
      final drawn = policy.draw(
        pool,
        config,
        SeededRandomSource(7),
        count: 10,
      );
      expect(drawn.map((p) => p.id).toSet(), hasLength(10));
    });

    test('asking for more seeds than the pool holds returns the pool', () {
      final pool = [aPerson('only-one')];
      expect(
        policy.draw(pool, config, SeededRandomSource(3), count: 5),
        hasLength(1),
      );
    });

    test('an empty pool draws nothing rather than throwing', () {
      // A city with nobody eligible is a normal Tuesday, not an error.
      expect(policy.draw([], config, SeededRandomSource(3), count: 4), isEmpty);
    });
  });

  group('the weights are inspectable', () {
    test('explain lists the pool with its factors', () {
      // A weight nobody can inspect is a weight nobody can argue with, and the
      // trap this policy exists to avoid was caught by arguing about one.
      final pool = [
        aPerson('newcomer', completedHangouts: 0),
        aPerson('waited', gender: man, weeksWaiting: 2),
        aPerson(
          'throttled',
          standing: const Standing(tier: StandingTier.throttled),
        ),
      ];
      final explained = policy.explain(pool, config);

      expect(explained.map((w) => w.person.value), ['newcomer', 'waited']);
      expect(explained.first.newcomerFactor, 3);
      expect(explained.last.starvationFactor, 3);
    });
  });

  group('configuration, not literals', () {
    test('turning the newcomer multiplier off is a config change', () {
      final config = configWith({'matching.newcomer_multiplier': 1.0});
      final newcomer = aPerson('newcomer', completedHangouts: 0);
      expect(policy.weightOf(newcomer, config).newcomerFactor, 1);
    });

    test('so is the starvation cap', () {
      final config = configWith({'matching.starve_cap_weeks': 10});
      final waited = aPerson('waited', weeksWaiting: 8);
      expect(policy.weightOf(waited, config).starvationFactor, 9);
    });
  });
}
