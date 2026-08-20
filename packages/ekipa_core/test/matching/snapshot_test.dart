import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

import '../support/world.dart';

void main() {
  group('the snapshot is immutable once taken', () {
    test('mutating the list handed in does not change the snapshot', () {
      // A run must not be able to have its input changed halfway through. This
      // is not paranoia about malice; it is the difference between a plan you
      // can replay and a plan you cannot explain.
      final people = [aPerson('ana')];
      final snapshot = aSnapshot(people);
      people.add(aPerson('bruno', gender: man));
      expect(snapshot.populationSize, 1);
    });

    test('the exposed collections refuse writes', () {
      final snapshot = aSnapshot([aPerson('ana')]);
      expect(() => snapshot.slots.add(laterSlot), throwsUnsupportedError);
    });
  });

  group('the snapshot hash makes reproducibility checkable', () {
    test('the same inputs give the same hash', () {
      final a = aSnapshot([aPerson('ana'), aPerson('bruno', gender: man)]);
      final b = aSnapshot([aPerson('ana'), aPerson('bruno', gender: man)]);
      expect(a.snapshotHash, b.snapshotHash);
    });

    test('the order people were listed in does not change it', () {
      // Otherwise a replay of the same night would disagree with itself, and
      // nobody could tell whether the algorithm changed or the input did.
      final ana = aPerson('ana');
      final bruno = aPerson('bruno', gender: man);
      expect(
        aSnapshot([ana, bruno]).snapshotHash,
        aSnapshot([bruno, ana]).snapshotHash,
      );
    });

    test('one more available person changes it', () {
      final ana = aPerson('ana');
      final bruno = aPerson('bruno', gender: man);
      expect(
        aSnapshot([ana]).snapshotHash,
        isNot(aSnapshot([ana, bruno]).snapshotHash),
      );
    });

    test('an added exclusion changes it', () {
      final people = [aPerson('ana'), aPerson('bruno', gender: man)];
      expect(
        aSnapshot(people).snapshotHash,
        isNot(
          aSnapshot(
            people,
            exclusions: [anExclusion('ana', 'bruno')],
          ).snapshotHash,
        ),
      );
    });

    test('an added edge changes it', () {
      final people = [aPerson('ana'), aPerson('bruno', gender: man)];
      expect(
        aSnapshot(people).snapshotHash,
        isNot(
          aSnapshot(people, edges: [anEdge('ana', 'bruno')]).snapshotHash,
        ),
      );
    });

    test('it is a fixed-width hex digest', () {
      expect(aSnapshot([aPerson('ana')]).snapshotHash, hasLength(8));
      expect(
        aSnapshot([aPerson('ana')]).snapshotHash,
        matches(RegExp(r'^[0-9a-f]{8}$')),
      );
    });
  });

  group('exclusions are symmetric without anyone remembering to be', () {
    test('asked either way round, the answer is the same', () {
      final snapshot = aSnapshot(
        [aPerson('ana'), aPerson('bruno', gender: man)],
        exclusions: [anExclusion('bruno', 'ana')],
      );
      const ana = PersonId('ana');
      const bruno = PersonId('bruno');
      expect(snapshot.isExcluded(ana, bruno), isTrue);
      expect(snapshot.isExcluded(bruno, ana), isTrue);
    });

    test('nobody is excluded from themselves', () {
      final snapshot = aSnapshot([aPerson('ana')]);
      expect(
        snapshot.isExcluded(const PersonId('ana'), const PersonId('ana')),
        isFalse,
      );
    });
  });

  group('the two cooldown clocks', () {
    test('a pair who never met has no intervening count', () {
      // `null` is not "a very long time ago". Collapsing the two would give
      // every stranger pair a satisfied cooldown for the wrong reason.
      final snapshot = aSnapshot([aPerson('ana'), aPerson('bruno')]);
      expect(
        snapshot.interveningHangoutsSince(
          const PersonId('ana'),
          const PersonId('bruno'),
        ),
        isNull,
      );
    });

    test('it counts hangouts either of them attended since they met', () {
      // Their hangouts, not the city's: the rule is about how much has happened
      // to these two, and a busy city would otherwise clear a cooldown for a
      // pair who did nothing in the meantime.
      final snapshot = aSnapshot(
        [aPerson('ana'), aPerson('bruno')],
        history: [
          aPastHangout(['ana', 'bruno'], daysAgo: 60),
          aPastHangout(['cvita', 'dario'], daysAgo: 50),
          aPastHangout(['ana', 'cvita'], daysAgo: 40),
          aPastHangout(['bruno', 'dario'], daysAgo: 30),
        ],
      );
      expect(
        snapshot.interveningHangoutsSince(
          const PersonId('ana'),
          const PersonId('bruno'),
        ),
        2,
      );
    });
  });

  group('edge decay', () {
    test('an edge at its half-life is worth half', () {
      final edge = anEdge('ana', 'bruno', daysAgo: 120);
      expect(
        edge.decayedWeight(testNow, const Duration(days: 120)),
        closeTo(0.4, 1e-6),
      );
    });

    test('a fresh edge is worth its full weight', () {
      final edge = anEdge('ana', 'bruno', daysAgo: 0);
      expect(
        edge.decayedWeight(testNow, const Duration(days: 120)),
        closeTo(0.8, 1e-6),
      );
    });

    test('a very old edge decays toward nothing without ever vanishing', () {
      // Decay rather than expiry, so the evidence is never deleted — an edge
      // from two years ago describes two people who have both changed, which is
      // a different statement from "they never met".
      final edge = anEdge('ana', 'bruno', weight: 1, daysAgo: 1200);
      final decayed = edge.decayedWeight(testNow, const Duration(days: 120));
      expect(decayed, lessThan(0.001));
      expect(decayed, greaterThan(0));
    });
  });
}
