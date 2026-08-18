import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:test/test.dart';

import '../support/world.dart';

/// Names, so a failure reads as a sentence rather than as a list of ids.
const ana = PersonId('ana');
const bruno = PersonId('bruno');
const cvita = PersonId('cvita');
const dario = PersonId('dario');
const eva = PersonId('eva');

void main() {
  final config = defaultConfig();

  /// Builds the rings of `ana` over everybody in [snapshot].
  RingSets ringsOfAna(MatchSnapshot snapshot) => RingSets.of(
    ana,
    snapshot.people.map((p) => p.id),
    snapshot,
    config,
  );

  group('R1 is a mutual edge and nothing else', () {
    test('somebody with an edge is in R1', () {
      final snapshot = aSnapshot(
        [aPerson('ana'), aPerson('bruno', gender: man)],
        edges: [anEdge('ana', 'bruno')],
      );
      expect(ringsOfAna(snapshot).enjoyed, {bruno});
    });

    test('somebody with no edge is not', () {
      // Edges only exist when both sides said yes, so "no edge" covers the
      // one-sided case without this code needing to know about ratings. A
      // one-sided "I enjoyed them" never causes a re-match — and the reason is
      // privacy, not manners: if it could, being re-matched would leak that
      // they liked you, and *not* being re-matched would leak the opposite.
      final snapshot = aSnapshot([aPerson('ana'), aPerson('bruno')]);
      expect(ringsOfAna(snapshot).enjoyed, isEmpty);
      expect(ringsOfAna(snapshot).strangers, {bruno});
    });

    test('somebody not in the candidate set is not in any ring', () {
      // A ring is only useful if its members can be placed tonight. Computing
      // over the whole city would produce sets whose size tells you about the
      // graph rather than about the evening.
      final snapshot = aSnapshot(
        [aPerson('ana')],
        edges: [anEdge('ana', 'bruno')],
      );
      final rings = ringsOfAna(snapshot);
      expect(rings.enjoyed, isEmpty);
      expect(rings.isEmpty, isTrue);
    });

    test('nobody is in their own rings', () {
      final snapshot = aSnapshot([aPerson('ana'), aPerson('bruno')]);
      final rings = ringsOfAna(snapshot);
      expect(rings.membersOf(Ring.r1Enjoyed), isNot(contains(ana)));
      expect(rings.membersOf(Ring.r2Leaf), isNot(contains(ana)));
      expect(rings.membersOf(Ring.r3Stranger), isNot(contains(ana)));
    });
  });

  group('R2 is the product thesis, and it carries its intermediary', () {
    test('a friend of a friend lands in R2, named by who introduced them', () {
      // The one genuinely non-obvious move in the whole design: propose
      // somebody you have no evidence about, on evidence from somebody you
      // liked.
      final snapshot = aSnapshot(
        [aPerson('ana'), aPerson('bruno', gender: man), aPerson('cvita')],
        edges: [anEdge('ana', 'bruno'), anEdge('bruno', 'cvita')],
      );
      final rings = ringsOfAna(snapshot);
      expect(rings.enjoyed, {bruno});
      expect(rings.leaves.keys, {cvita});
      expect(rings.intermediaryFor(cvita), bruno);
      expect(rings.strangers, isEmpty);
    });

    test('somebody already in R1 never appears in R2', () {
      // Otherwise a triangle would put the same person in two rings and the
      // ratio would be measuring something that is not a partition.
      final snapshot = aSnapshot(
        [aPerson('ana'), aPerson('bruno', gender: man), aPerson('cvita')],
        edges: [
          anEdge('ana', 'bruno'),
          anEdge('ana', 'cvita'),
          anEdge('bruno', 'cvita'),
        ],
      );
      final rings = ringsOfAna(snapshot);
      expect(rings.enjoyed, {bruno, cvita});
      expect(rings.leaves, isEmpty);
    });

    test('the intermediary need not be available tonight', () {
      // Deliberate: they are evidence, not a guest. Requiring the intermediary
      // to be placeable would make R2 collapse on exactly the thin nights it is
      // most useful on.
      final snapshot = aSnapshot(
        [aPerson('ana'), aPerson('cvita')],
        edges: [anEdge('ana', 'bruno'), anEdge('bruno', 'cvita')],
      );
      final rings = ringsOfAna(snapshot);
      expect(rings.leaves.keys, {cvita});
      expect(rings.intermediaryFor(cvita), bruno);
    });

    test('with two paths, the stronger one names the intermediary', () {
      final snapshot = aSnapshot(
        [
          aPerson('ana'),
          aPerson('bruno', gender: man),
          aPerson('cvita'),
          aPerson('dario', gender: man),
        ],
        edges: [
          anEdge('ana', 'bruno', weight: 0.9, daysAgo: 1),
          anEdge('ana', 'cvita', weight: 0.2, daysAgo: 1),
          anEdge('bruno', 'dario', weight: 0.9, daysAgo: 1),
          anEdge('cvita', 'dario', weight: 0.2, daysAgo: 1),
        ],
      );
      expect(ringsOfAna(snapshot).intermediaryFor(dario), bruno);
    });

    test('a chain is as strong as its weaker link', () {
      // The minimum rather than the product or the mean: "I liked B a lot, B
      // barely knows C" is weak evidence however enthusiastic the first half
      // was.
      final snapshot = aSnapshot(
        [aPerson('ana'), aPerson('bruno', gender: man), aPerson('cvita')],
        edges: [
          anEdge('ana', 'bruno', weight: 1, daysAgo: 0),
          anEdge('bruno', 'cvita', weight: 0.3, daysAgo: 0),
        ],
      );
      final leaf = ringsOfAna(snapshot).leaves[cvita]!;
      expect(leaf.strength, closeTo(0.3 * config.bridgeDiscount, 1e-9));
    });

    test('a tie is broken by id, so a replay agrees with itself', () {
      // An unstable tie-break would make a replay disagree about *why* somebody
      // was invited, which is the one thing the emission record exists to be
      // able to say.
      final snapshot = aSnapshot(
        [
          aPerson('ana'),
          aPerson('bruno', gender: man),
          aPerson('cvita'),
          aPerson('dario', gender: man),
        ],
        edges: [
          anEdge('ana', 'bruno', weight: 0.5, daysAgo: 0),
          anEdge('ana', 'cvita', weight: 0.5, daysAgo: 0),
          anEdge('bruno', 'dario', weight: 0.5, daysAgo: 0),
          anEdge('cvita', 'dario', weight: 0.5, daysAgo: 0),
        ],
      );
      expect(ringsOfAna(snapshot).intermediaryFor(dario), bruno);
    });
  });

  group('R3 is everyone else, and it is what keeps the graph open', () {
    test('a three-hop acquaintance is a stranger', () {
      // R2 is deliberately one hop, not transitive closure. Two hops is
      // "somebody my friend likes"; three is "somebody in my town".
      final snapshot = aSnapshot(
        [
          aPerson('ana'),
          aPerson('bruno', gender: man),
          aPerson('cvita'),
          aPerson('dario', gender: man),
        ],
        edges: [
          anEdge('ana', 'bruno'),
          anEdge('bruno', 'cvita'),
          anEdge('cvita', 'dario'),
        ],
      );
      final rings = ringsOfAna(snapshot);
      expect(rings.leaves.keys, {cvita});
      expect(rings.strangers, {dario});
    });

    test('the three rings partition the candidate set exactly', () {
      // A property, checked over a small graph: every candidate is in exactly
      // one ring. If they were not, the configured ratio would be measuring
      // overlapping sets and could not sum to anything.
      final snapshot = aSnapshot(
        [
          aPerson('ana'),
          aPerson('bruno', gender: man),
          aPerson('cvita'),
          aPerson('dario', gender: man),
          aPerson('eva'),
        ],
        edges: [
          anEdge('ana', 'bruno'),
          anEdge('bruno', 'cvita'),
          anEdge('cvita', 'dario'),
        ],
      );
      final rings = ringsOfAna(snapshot);
      final union = {
        ...rings.enjoyed,
        ...rings.leaves.keys,
        ...rings.strangers,
      };
      expect(union, {bruno, cvita, dario, eva});
      expect(
        rings.enjoyed.length + rings.leaves.length + rings.strangers.length,
        union.length,
        reason: 'the rings overlap, so they are not a partition',
      );
    });

    test('every stranger weighs the same', () {
      // There is no evidence about a stranger, and inventing a preference among
      // strangers would be the matcher expressing an opinion it has no basis
      // for.
      final snapshot = aSnapshot([
        aPerson('ana'),
        aPerson('bruno', gender: man),
        aPerson('cvita'),
      ]);
      final rings = ringsOfAna(snapshot);
      expect(
        rings.weightWithin(Ring.r3Stranger, bruno, snapshot, config),
        rings.weightWithin(Ring.r3Stranger, cvita, snapshot, config),
      );
    });

    test('an R1 weight decays with the edge', () {
      final fresh = aSnapshot(
        [aPerson('ana'), aPerson('bruno', gender: man)],
        edges: [anEdge('ana', 'bruno', daysAgo: 0)],
      );
      final stale = aSnapshot(
        [aPerson('ana'), aPerson('bruno', gender: man)],
        edges: [anEdge('ana', 'bruno', daysAgo: 240)],
      );
      expect(
        ringsOfAna(fresh).weightWithin(Ring.r1Enjoyed, bruno, fresh, config),
        greaterThan(
          ringsOfAna(stale).weightWithin(Ring.r1Enjoyed, bruno, stale, config),
        ),
      );
    });
  });

  group('counting the pairs a group already knows', () {
    test('an edge counts as having met', () {
      final snapshot = aSnapshot(
        [aPerson('ana'), aPerson('bruno', gender: man), aPerson('cvita')],
        edges: [anEdge('ana', 'bruno')],
      );
      expect(snapshot.knownPairsAmong([ana, bruno, cvita]), 1);
    });

    test('so does a past hangout with no edge from it', () {
      // Two people who met and did not enjoy each other have still met, and the
      // "at most half the pairs" rule is about familiarity rather than about
      // affection.
      final snapshot = aSnapshot(
        [aPerson('ana'), aPerson('bruno', gender: man), aPerson('cvita')],
        history: [
          aPastHangout(['ana', 'cvita'], daysAgo: 90),
        ],
      );
      expect(snapshot.knownPairsAmong([ana, bruno, cvita]), 1);
    });

    test('four strangers know nobody', () {
      final snapshot = aSnapshot([
        aPerson('ana'),
        aPerson('bruno', gender: man),
        aPerson('cvita'),
        aPerson('dario', gender: man),
      ]);
      expect(snapshot.knownPairsAmong([ana, bruno, cvita, dario]), 0);
    });
  });
}
