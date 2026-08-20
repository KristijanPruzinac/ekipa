import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:test/test.dart';

import '../support/world.dart';

void main() {
  const composition = Composition();
  final config = defaultConfig();

  group('invariant 1: nobody is the only one of their gender', () {
    // This single rule replaces "2+2 or 4-same", covers the 3-person backfill
    // case, and needs no special case for a third gender value. It holds at
    // *any* group size, which is what makes it survive a group that shrinks.

    test('2+2 is valid', () {
      final members = [
        aPerson('a'),
        aPerson('b'),
        aPerson('c', gender: man),
        aPerson('d', gender: man),
      ];
      expect(
        composition.verdict(members, aSnapshot(members), config).isValid,
        isTrue,
      );
    });

    test('four of one gender is valid', () {
      final members = [
        for (var i = 0; i < 4; i++) aPerson('m-$i', gender: man),
      ];
      expect(
        composition.verdict(members, aSnapshot(members), config).isValid,
        isTrue,
      );
    });

    test('3+1 is rejected', () {
      final members = [
        aPerson('a'),
        aPerson('b'),
        aPerson('c'),
        aPerson('d', gender: man),
      ];
      expect(
        composition.verdict(members, aSnapshot(members), config).failures,
        contains(CompositionFailure.loneGender),
      );
    });

    test('the 2+1 a lost confirmation produces is rejected', () {
      // The case the invariant exists for, and the reason backfill ranks
      // same-gender replacements first: a 2+2 that loses one woman is 1W+2M,
      // and the honest response is to cancel rather than run it.
      final members = [
        aPerson('a'),
        aPerson('b', gender: man),
        aPerson('c', gender: man),
      ];
      expect(
        composition.verdict(members, aSnapshot(members), config).failures,
        contains(CompositionFailure.loneGender),
      );
    });

    test('a three of one gender is valid', () {
      final members = [for (var i = 0; i < 3; i++) aPerson('w-$i')];
      expect(
        composition.verdict(members, aSnapshot(members), config).isValid,
        isTrue,
      );
    });

    test('a gender nobody anticipated needs no special case', () {
      final members = [
        aPerson('a', gender: const Gender('nonbinary')),
        aPerson('b', gender: const Gender('nonbinary')),
        aPerson('c', gender: man),
        aPerson('d', gender: man),
      ];
      expect(
        composition.verdict(members, aSnapshot(members), config).isValid,
        isTrue,
      );
    });
  });

  group('invariant 2: at most half the pairs have met before', () {
    test('a 2+2 of two known dyads holds by construction', () {
      // Two known pairs of six is a third, comfortably under the ceiling. This
      // is the shape the product was asked for, so it had better be legal.
      final members = [
        aPerson('a'),
        aPerson('b'),
        aPerson('c', gender: man),
        aPerson('d', gender: man),
      ];
      final snapshot = aSnapshot(
        members,
        edges: [anEdge('a', 'b', daysAgo: 200), anEdge('c', 'd', daysAgo: 200)],
      );
      expect(composition.verdict(members, snapshot, config).isValid, isTrue);
    });

    test('a group where everybody already knows everybody is rejected', () {
      // The closed clique this rule exists to prevent. Six known pairs of six
      // is not a hangout, it is an existing friend group using the app as a
      // diary.
      final members = [
        aPerson('a'),
        aPerson('b'),
        aPerson('c', gender: man),
        aPerson('d', gender: man),
      ];
      final snapshot = aSnapshot(
        members,
        edges: [
          for (final pair in [
            ['a', 'b'],
            ['a', 'c'],
            ['a', 'd'],
            ['b', 'c'],
            ['b', 'd'],
            ['c', 'd'],
          ])
            anEdge(pair[0], pair[1], daysAgo: 200),
        ],
      );
      expect(
        composition.verdict(members, snapshot, config).failures,
        contains(CompositionFailure.tooFamiliar),
      );
    });

    test('having met without forming an edge still counts as familiar', () {
      // The rule is about familiarity, not affection. Two people who met and
      // did not enjoy each other have still met.
      final members = [
        aPerson('a'),
        aPerson('b'),
        aPerson('c', gender: man),
      ];
      final snapshot = aSnapshot(
        members,
        history: [
          aPastHangout(['a', 'b'], daysAgo: 200),
          aPastHangout(['a', 'c'], daysAgo: 190),
        ],
      );
      expect(
        composition.verdict(members, snapshot, config).failures,
        contains(CompositionFailure.tooFamiliar),
      );
    });

    test(
      'the ceiling is a fraction, so it scales without a table of cases',
      () {
        final members = [
          aPerson('a'),
          aPerson('b'),
          aPerson('c', gender: man),
          aPerson('d', gender: man),
        ];
        final snapshot = aSnapshot(
          members,
          edges: [
            anEdge('a', 'b', daysAgo: 200),
            anEdge('c', 'd', daysAgo: 200),
            anEdge('a', 'c', daysAgo: 200),
          ],
        );
        // Three of six pairs known: allowed at 0.5, refused at 0.25.
        expect(composition.verdict(members, snapshot, config).isValid, isTrue);
        expect(
          composition
              .verdict(
                members,
                snapshot,
                configWith({'matching.max_known_pair_fraction': 0.25}),
              )
              .failures,
          contains(CompositionFailure.tooFamiliar),
        );
      },
    );
  });

  group('the group-wide cluster check is not implied by the pairwise one', () {
    test('three people who pair up geographically may still have nowhere', () {
      // A and B share the north, B and C the south, and there is nowhere all
      // three can go. Every pair passes; the group does not. This failure is
      // invisible to any per-pair rule, which is why the check lives here.
      final members = [
        aPerson('a', clusters: {north}),
        aPerson('b', clusters: {north, south}),
        aPerson('c', gender: man, clusters: {south}),
      ];
      expect(
        composition.verdict(members, aSnapshot(members), config).failures,
        contains(CompositionFailure.noSharedCluster),
      );
    });

    test('a valid group reports where it could meet', () {
      // Reported rather than chosen. The meeting point is picked at lock time
      // from one of these, because if somebody declines and is backfilled the
      // replacement only has to reach the *cluster*.
      final members = [
        aPerson('a', clusters: {centre, north}),
        aPerson('b', clusters: {centre, north, south}),
        aPerson('c', clusters: {centre, north}),
      ];
      final verdict = composition.verdict(members, aSnapshot(members), config);
      expect(verdict.isValid, isTrue);
      expect(verdict.sharedClusters, {centre, north});
    });
  });

  group('an exclusion inside a group is fatal', () {
    test('a rather_not between two members rejects the group', () {
      // Never overridden. Not for backfill urgency, not to save a group from
      // cancellation, not because the alternative is a thin night.
      final members = [aPerson('a'), aPerson('b'), aPerson('c')];
      final snapshot = aSnapshot(members, exclusions: [anExclusion('a', 'c')]);
      expect(
        composition.verdict(members, snapshot, config).failures,
        contains(CompositionFailure.excludedPair),
      );
    });
  });

  group('an R2 intermediary is never in the group they introduced', () {
    test('placing the intermediary rejects the group', () {
      // If A is the seed and C arrives via B, then A, B and C is three known
      // pairs of six and one outsider — the worst possible shape, where a trio
      // talks and the fourth person watches.
      final members = [
        aPerson('a'),
        aPerson('b', gender: man),
        aPerson('c'),
      ];
      expect(
        composition
            .verdict(
              members,
              aSnapshot(members),
              config,
              barredIntermediaries: {const PersonId('b')},
            )
            .failures,
        contains(CompositionFailure.intermediaryPresent),
      );
    });

    test('an intermediary who is not in the group is fine', () {
      final members = [aPerson('a'), aPerson('b'), aPerson('c')];
      expect(
        composition
            .verdict(
              members,
              aSnapshot(members),
              config,
              barredIntermediaries: {const PersonId('elsewhere')},
            )
            .isValid,
        isTrue,
      );
    });
  });

  group('size and sanity', () {
    test('a pair is too small', () {
      // Three is a conversation; two is a date, and it is a different, higher
      // pressure social event than the one they agreed to.
      final members = [aPerson('a'), aPerson('b')];
      expect(
        composition.verdict(members, aSnapshot(members), config).failures,
        contains(CompositionFailure.tooSmall),
      );
    });

    test('five is too large', () {
      final members = [for (var i = 0; i < 5; i++) aPerson('w-$i')];
      expect(
        composition.verdict(members, aSnapshot(members), config).failures,
        contains(CompositionFailure.tooLarge),
      );
    });

    test('the bounds are config, not literals', () {
      final members = [for (var i = 0; i < 5; i++) aPerson('w-$i')];
      expect(
        composition
            .verdict(
              members,
              aSnapshot(members),
              configWith({'matching.max_group_size': 6}),
            )
            .isValid,
        isTrue,
      );
    });

    test('the same person twice is caught', () {
      final ana = aPerson('a');
      final members = [ana, ana, aPerson('b'), aPerson('c')];
      expect(
        composition.verdict(members, aSnapshot(members), config).failures,
        contains(CompositionFailure.duplicateMember),
      );
    });
  });

  group('a rejection names every rule it breaks, not the first', () {
    test('so one rebuild is informed by all of them', () {
      // A group rejected for one reason and rebuilt into a group rejected for
      // another is two wasted rebuilds and a diagnostic that only ever names
      // one problem.
      final members = [
        aPerson('a', clusters: {north}),
        aPerson('b', gender: man, clusters: {south}),
      ];
      final verdict = composition.verdict(members, aSnapshot(members), config);
      expect(verdict.failures, contains(CompositionFailure.tooSmall));
      expect(verdict.failures, contains(CompositionFailure.loneGender));
      expect(verdict.failures, contains(CompositionFailure.noSharedCluster));
    });

    test('a verdict renders as the list of what is wrong', () {
      final members = [aPerson('a'), aPerson('b')];
      expect(
        composition.verdict(members, aSnapshot(members), config).toString(),
        contains('tooSmall'),
      );
    });
  });
}
