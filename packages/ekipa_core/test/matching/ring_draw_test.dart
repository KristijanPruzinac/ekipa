import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:test/test.dart';

import '../support/world.dart';

void main() {
  const draw = RingDraw();

  /// Draws once for `ana` over everybody in [snapshot].
  DrawOutcome drawOnce(
    MatchSnapshot snapshot,
    MatchConfig config,
    RandomSource random, {
    RingLedger? ledger,
    bool Function(Person)? permits,
  }) {
    final seed = snapshot.person(const PersonId('ana'))!;
    final pool = {
      for (final person in snapshot.people)
        if (person.id != seed.id) person.id: person,
    };
    return draw.draw(
      seed: seed,
      rings: RingSets.of(seed.id, pool.keys, snapshot, config),
      pool: pool,
      snapshot: snapshot,
      config: config,
      random: random,
      ledger: ledger ?? RingLedger(),
      permits: permits ?? (_) => true,
    );
  }

  /// A graph with one friend, one friend-of-a-friend, and one stranger.
  MatchSnapshot threeRings() => aSnapshot(
    [
      aPerson('ana'),
      aPerson('bruno', gender: man),
      aPerson('cvita'),
      aPerson('dario', gender: man),
    ],
    edges: [anEdge('ana', 'bruno'), anEdge('bruno', 'cvita')],
  );

  group('the roll respects the configured shares', () {
    test('all-R1 configuration always draws the friend', () {
      final config = configWith({
        'matching.ring_share_enjoyed': 1.0,
        'matching.ring_share_leaf': 0.0,
        'matching.ring_deficit_gain': 0.0,
      });
      for (var i = 0; i < 50; i++) {
        final outcome = drawOnce(threeRings(), config, SeededRandomSource(i));
        expect(outcome.realised, Ring.r1Enjoyed);
        expect(outcome.partner!.id, const PersonId('bruno'));
      }
    });

    test('all-R2 configuration always draws the friend of the friend', () {
      final config = configWith({
        'matching.ring_share_enjoyed': 0.0,
        'matching.ring_share_leaf': 1.0,
        'matching.ring_deficit_gain': 0.0,
      });
      for (var i = 0; i < 50; i++) {
        final outcome = drawOnce(threeRings(), config, SeededRandomSource(i));
        expect(outcome.realised, Ring.r2Leaf);
        expect(outcome.partner!.id, const PersonId('cvita'));
        expect(
          outcome.via,
          const PersonId('bruno'),
          reason: 'an R2 draw must name the intermediary it bars',
        );
      }
    });

    test('the all-strangers control never draws a friend', () {
      // A = B = 0 is a control arm by construction, which is why the permanent
      // control needs no separate code path.
      final config = configWith({
        'matching.ring_share_enjoyed': 0.0,
        'matching.ring_share_leaf': 0.0,
      });
      for (var i = 0; i < 50; i++) {
        final outcome = drawOnce(threeRings(), config, SeededRandomSource(i));
        expect(outcome.realised, Ring.r3Stranger);
        expect(outcome.partner!.id, const PersonId('dario'));
      }
    });

    test('the default mix lands in all three rings over many draws', () {
      final config = configWith({'matching.ring_deficit_gain': 0.0});
      final seen = <Ring>{};
      for (var i = 0; i < 400; i++) {
        seen.add(
          drawOnce(threeRings(), config, SeededRandomSource(i)).realised!,
        );
      }
      expect(seen, {Ring.r1Enjoyed, Ring.r2Leaf, Ring.r3Stranger});
    });

    test('the realised mix tracks the configured shares', () {
      // Each draw uses a fresh ledger, so this measures the roll alone rather
      // than the roll plus the correction.
      final config = configWith({'matching.ring_deficit_gain': 0.0});
      final counts = <Ring, int>{};
      const trials = 3000;
      for (var i = 0; i < trials; i++) {
        final ring = drawOnce(
          threeRings(),
          config,
          SeededRandomSource(i),
        ).realised!;
        counts[ring] = (counts[ring] ?? 0) + 1;
      }
      expect(counts[Ring.r1Enjoyed]! / trials, closeTo(0.25, 0.03));
      expect(counts[Ring.r2Leaf]! / trials, closeTo(0.5, 0.03));
      expect(counts[Ring.r3Stranger]! / trials, closeTo(0.25, 0.03));
    });
  });

  group('fallback goes down, never up', () {
    // A stranger draw silently becoming a friend draw is the direction that
    // builds closed cliques. Falling outward costs one person one evening of
    // familiarity and increases exposure, which is the failure we can afford.

    test('an R1 draw with no friend available falls to R2', () {
      final config = configWith({
        'matching.ring_share_enjoyed': 1.0,
        'matching.ring_share_leaf': 0.0,
        'matching.ring_deficit_gain': 0.0,
      });
      // Bruno is the only R1 member; refuse him at the pair filter.
      final outcome = drawOnce(
        threeRings(),
        config,
        SeededRandomSource(1),
        permits: (p) => p.id != const PersonId('bruno'),
      );
      expect(outcome.intended, Ring.r1Enjoyed);
      expect(outcome.realised, Ring.r2Leaf);
      expect(outcome.fellBack, isTrue);
    });

    test('and to R3 when R2 is unavailable too', () {
      final config = configWith({
        'matching.ring_share_enjoyed': 1.0,
        'matching.ring_share_leaf': 0.0,
        'matching.ring_deficit_gain': 0.0,
      });
      final outcome = drawOnce(
        threeRings(),
        config,
        SeededRandomSource(1),
        permits: (p) =>
            p.id != const PersonId('bruno') && p.id != const PersonId('cvita'),
      );
      expect(outcome.intended, Ring.r1Enjoyed);
      expect(outcome.realised, Ring.r3Stranger);
    });

    test('an R3 draw never falls inward to a friend', () {
      // The load-bearing half. If it could, a thin stranger pool would quietly
      // become a friend night and the stranger share would be fiction.
      final config = configWith({
        'matching.ring_share_enjoyed': 0.0,
        'matching.ring_share_leaf': 0.0,
      });
      final outcome = drawOnce(
        threeRings(),
        config,
        SeededRandomSource(1),
        permits: (p) => p.id != const PersonId('dario'),
      );
      expect(outcome.intended, Ring.r3Stranger);
      expect(outcome.isFound, isFalse);
      expect(outcome.realised, isNull);
    });

    test('a draw that finds nobody is not recorded as a stranger draw', () {
      // Counting it as a realised R3 would make a thin night look like a
      // successful stranger night, which is exactly the measurement error the
      // ledger exists to prevent.
      final ledger = RingLedger();
      final config = configWith({
        'matching.ring_share_enjoyed': 0.0,
        'matching.ring_share_leaf': 0.0,
      });
      drawOnce(
        threeRings(),
        config,
        SeededRandomSource(1),
        ledger: ledger,
        permits: (_) => false,
      );
      expect(ledger.drawCount, 0);
      expect(ledger.realisedCount(Ring.r3Stranger), 0);
    });
  });

  group('within a ring the partner is sampled, never argmax', () {
    test('a weaker friend is still sometimes drawn', () {
      // Invariant 3: no pair is re-matched deterministically, however strong
      // the edge. If a strong pair always reappeared, its *absence* would
      // become information about how somebody rated — which breaks the
      // asymmetry invariant, the load-bearing privacy promise in the product.
      final snapshot = aSnapshot(
        [
          aPerson('ana'),
          aPerson('bruno', gender: man),
          aPerson('cvita'),
        ],
        edges: [
          anEdge('ana', 'bruno', weight: 0.95, daysAgo: 0),
          anEdge('ana', 'cvita', weight: 0.15, daysAgo: 0),
        ],
      );
      final config = configWith({
        'matching.ring_share_enjoyed': 1.0,
        'matching.ring_share_leaf': 0.0,
        'matching.ring_deficit_gain': 0.0,
      });

      final drawn = <PersonId>{};
      for (var i = 0; i < 200; i++) {
        drawn.add(
          drawOnce(snapshot, config, SeededRandomSource(i)).partner!.id,
        );
      }
      expect(drawn, {const PersonId('bruno'), const PersonId('cvita')});
    });

    test('but the stronger friend is drawn more often', () {
      final snapshot = aSnapshot(
        [aPerson('ana'), aPerson('bruno', gender: man), aPerson('cvita')],
        edges: [
          anEdge('ana', 'bruno', weight: 0.95, daysAgo: 0),
          anEdge('ana', 'cvita', weight: 0.15, daysAgo: 0),
        ],
      );
      final config = configWith({
        'matching.ring_share_enjoyed': 1.0,
        'matching.ring_share_leaf': 0.0,
        'matching.ring_deficit_gain': 0.0,
      });
      var strong = 0;
      for (var i = 0; i < 600; i++) {
        if (drawOnce(snapshot, config, SeededRandomSource(i)).partner!.id ==
            const PersonId('bruno')) {
          strong++;
        }
      }
      expect(strong / 600, closeTo(0.95 / 1.1, 0.05));
    });

    test('an edge decayed to nothing is still drawable', () {
      // A decayed edge is weak evidence, not an exclusion. Without the weight
      // floor, somebody you liked two years ago would become permanently
      // unreachable through R1 while still occupying the ring.
      final snapshot = aSnapshot(
        [aPerson('ana'), aPerson('bruno', gender: man)],
        edges: [anEdge('ana', 'bruno', weight: 1, daysAgo: 4000)],
      );
      final config = configWith({
        'matching.ring_share_enjoyed': 1.0,
        'matching.ring_share_leaf': 0.0,
        'matching.ring_deficit_gain': 0.0,
      });
      final outcome = drawOnce(snapshot, config, SeededRandomSource(1));
      expect(outcome.partner?.id, const PersonId('bruno'));
    });
  });

  group('the same seed draws the same partner', () {
    test('two identical runs agree completely', () {
      // The matcher's contract. Without it a run cannot be replayed to answer
      // "why was I in that group?" months later.
      final config = defaultConfig();
      final first = [
        for (var i = 0; i < 20; i++)
          drawOnce(threeRings(), config, SeededRandomSource(i)).toString(),
      ];
      final second = [
        for (var i = 0; i < 20; i++)
          drawOnce(threeRings(), config, SeededRandomSource(i)).toString(),
      ];
      expect(first, second);
    });
  });

  group(
    'deficit correction: the number you tune is the number that happened',
    () {
      test('a run starved of R1 pushes later rolls toward R1', () {
        // The failure this prevents: fallbacks bias systematically toward R3
        // exactly when the graph is thin, so a configured 0.25/0.50/0.25 can
        // realise as 0.05/0.15/0.80 with nothing anywhere saying so.
        final config = defaultConfig();
        final ledger = RingLedger();
        for (var i = 0; i < 8; i++) {
          ledger.record(intended: Ring.r1Enjoyed, realised: Ring.r3Stranger);
        }
        final adjusted = ledger.adjustedShares(config);
        expect(
          adjusted[Ring.r1Enjoyed],
          greaterThan(config.ringShareEnjoyed),
        );
        expect(adjusted[Ring.r2Leaf], greaterThan(config.ringShareLeaf));
        expect(adjusted[Ring.r3Stranger], 0);
      });

      test('the adjusted shares always sum to one', () {
        final config = defaultConfig();
        final ledger = RingLedger();
        for (var draws = 0; draws < 30; draws++) {
          final adjusted = ledger.adjustedShares(config);
          expect(
            adjusted.values.fold<double>(0, (sum, w) => sum + w),
            closeTo(1, 1e-9),
            reason: 'after $draws draws',
          );
          ledger.record(
            intended: Ring.values[draws % 3],
            realised: Ring.r3Stranger,
          );
        }
      });

      test('a run that is on target is left alone', () {
        final config = defaultConfig();
        // Exactly the configured mix over four draws: 1 R1, 2 R2, 1 R3.
        final ledger = RingLedger()
          ..record(intended: Ring.r1Enjoyed, realised: Ring.r1Enjoyed)
          ..record(intended: Ring.r2Leaf, realised: Ring.r2Leaf)
          ..record(intended: Ring.r2Leaf, realised: Ring.r2Leaf)
          ..record(intended: Ring.r3Stranger, realised: Ring.r3Stranger);
        final adjusted = ledger.adjustedShares(config);
        expect(adjusted[Ring.r1Enjoyed], closeTo(0.25, 1e-9));
        expect(adjusted[Ring.r2Leaf], closeTo(0.5, 1e-9));
        expect(adjusted[Ring.r3Stranger], closeTo(0.25, 1e-9));
      });

      test('correction can be turned off, which is how it gets measured', () {
        final off = configWith({'matching.ring_deficit_gain': 0.0});
        final ledger = RingLedger();
        for (var i = 0; i < 10; i++) {
          ledger.record(intended: Ring.r1Enjoyed, realised: Ring.r3Stranger);
        }
        final adjusted = ledger.adjustedShares(off);
        expect(adjusted[Ring.r1Enjoyed], off.ringShareEnjoyed);
        expect(adjusted[Ring.r3Stranger], off.ringShareStranger);
      });

      test('correction narrows the gap between configured and realised', () {
        // The end-to-end claim, over a graph where R1 is available but
        // thin: with correction on, the realised R1 share ends up closer to
        // the configured 0.25 than it does with correction off.
        double realisedR1({required bool corrected}) {
          final config = configWith({
            'matching.ring_deficit_gain': corrected ? 1.0 : 0.0,
          });
          final ledger = RingLedger();
          final random = SeededRandomSource(20260820);
          // Ana has one friend and a large stranger pool. Half the draws refuse
          // the friend, which is what a cooldown does in practice.
          final snapshot = aSnapshot(
            [
              aPerson('ana'),
              aPerson('bruno', gender: man),
              for (var i = 0; i < 10; i++) aPerson('stranger-$i', gender: man),
            ],
            edges: [anEdge('ana', 'bruno', daysAgo: 0)],
          );

          for (var i = 0; i < 200; i++) {
            drawOnce(
              snapshot,
              config,
              random,
              ledger: ledger,
              permits: (p) => p.id != const PersonId('bruno') || i.isEven,
            );
          }
          return ledger.realisedShare(Ring.r1Enjoyed)!;
        }

        final withCorrection = realisedR1(corrected: true);
        final without = realisedR1(corrected: false);
        expect(
          (withCorrection - 0.25).abs(),
          lessThan((without - 0.25).abs()),
          reason: 'correction should pull the realised share toward 0.25',
        );
      });

      test('both halves are reported, always', () {
        // Reporting only the realised mix would hide the question the console
        // exists to answer: did we get the ratio we asked for?
        final ledger = RingLedger()
          ..record(intended: Ring.r1Enjoyed, realised: Ring.r3Stranger)
          ..record(intended: Ring.r2Leaf, realised: Ring.r2Leaf);
        expect(ledger.toJson(), {
          'draws': 2,
          'intended': {'r1_enjoyed': 1, 'r2_leaf': 1, 'r3_stranger': 0},
          'realised': {'r1_enjoyed': 0, 'r2_leaf': 1, 'r3_stranger': 1},
        });
      });

      test('there is no realised share before the first draw', () {
        expect(RingLedger().realisedShare(Ring.r1Enjoyed), isNull);
      });
    },
  );
}
