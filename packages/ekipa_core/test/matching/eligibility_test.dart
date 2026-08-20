import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:test/test.dart';

import '../support/world.dart';

void main() {
  final eligibility = Eligibility();
  final config = defaultConfig();

  group('each person rule refuses exactly the thing it is about', () {
    // One test per rule, which is the whole reason the rules are separate
    // objects rather than an if chain: a rule nobody has watched refuse is
    // indistinguishable from a rule that permits everything.

    test('somebody who did not mark the slot is not available', () {
      final ana = aPerson('ana');
      final snapshot = aSnapshot([ana], availability: {testSlot.id: {}});
      expect(
        eligibility.reject(ana, testSlot, snapshot, config)?.reason,
        FilterReason.notAvailable,
      );
    });

    test('somebody already placed in this slot is not placed again', () {
      final ana = aPerson('ana');
      final snapshot = aSnapshot(
        [ana],
        alreadyPlaced: {
          ana.id: {testSlot.id},
        },
      );
      expect(
        eligibility.reject(ana, testSlot, snapshot, config)?.reason,
        FilterReason.alreadyPlaced,
      );
    });

    test('somebody placed in an overlapping slot is not placed either', () {
      // The half that is easy to omit. Two 90-minute windows that touch are
      // two groups holding one person, and at least one of them waits for
      // somebody who is not coming.
      final ana = aPerson('ana');
      final snapshot = aSnapshot(
        [ana],
        slots: [testSlot, overlappingSlot],
        alreadyPlaced: {
          ana.id: {overlappingSlot.id},
        },
      );
      expect(
        eligibility.reject(ana, testSlot, snapshot, config)?.reason,
        FilterReason.alreadyPlaced,
      );
    });

    test('a non-overlapping second slot is not a conflict', () {
      final ana = aPerson('ana');
      final snapshot = aSnapshot(
        [ana],
        slots: [testSlot, laterSlot],
        alreadyPlaced: {
          ana.id: {laterSlot.id},
        },
      );
      expect(eligibility.reject(ana, testSlot, snapshot, config), isNull);
    });

    test('a suspended person is not matched', () {
      final ana = aPerson(
        'ana',
        standing: const Standing(tier: StandingTier.suspended),
      );
      expect(
        eligibility.reject(ana, testSlot, aSnapshot([ana]), config)?.reason,
        FilterReason.standing,
      );
    });

    test('a banned person is not matched', () {
      final ana = aPerson(
        'ana',
        standing: const Standing(tier: StandingTier.banned),
      );
      expect(
        eligibility.reject(ana, testSlot, aSnapshot([ana]), config)?.reason,
        FilterReason.standing,
      );
    });

    test('an exhausted throttle quota stops placement', () {
      final ana = aPerson(
        'ana',
        standing: const Standing(
          tier: StandingTier.throttled,
          remainingQuota: 0,
        ),
      );
      expect(
        eligibility.reject(ana, testSlot, aSnapshot([ana]), config)?.reason,
        FilterReason.standing,
      );
    });

    test('a throttled person with quota left is still placeable', () {
      // The sanction is fewer evenings, not none. Reading it as "throttled
      // means excluded" turns a mild response into a suspension nobody chose.
      final ana = aPerson(
        'ana',
        standing: const Standing(
          tier: StandingTier.throttled,
          remainingQuota: 1,
        ),
      );
      expect(
        eligibility.reject(ana, testSlot, aSnapshot([ana]), config),
        isNull,
      );
    });

    test('somebody with no reachable cluster surfaces as unreachable', () {
      final ana = aPerson('ana', clusters: const {});
      expect(
        eligibility.reject(ana, testSlot, aSnapshot([ana]), config)?.reason,
        FilterReason.noSharedCluster,
      );
    });

    test('somebody from another city is not in this run', () {
      final ana = aPerson('ana', city: const CityId('elsewhere'));
      expect(
        eligibility.reject(ana, testSlot, aSnapshot([ana]), config)?.reason,
        FilterReason.otherCity,
      );
    });
  });

  group('each pair rule refuses exactly the thing it is about', () {
    test('an exclusion is absolute', () {
      final ana = aPerson('ana');
      final bruno = aPerson('bruno', gender: man);
      final snapshot = aSnapshot(
        [ana, bruno],
        exclusions: [anExclusion('ana', 'bruno')],
      );
      expect(
        eligibility.rejectPair(ana, bruno, snapshot, config)?.reason,
        FilterReason.excluded,
      );
    });

    test('and it holds whichever way round it is asked', () {
      // Symmetry is structural — the key is ordered — so this cannot regress
      // by somebody forgetting the second direction in a query.
      final ana = aPerson('ana');
      final bruno = aPerson('bruno', gender: man);
      final snapshot = aSnapshot(
        [ana, bruno],
        exclusions: [anExclusion('bruno', 'ana')],
      );
      expect(
        eligibility.rejectPair(ana, bruno, snapshot, config)?.reason,
        FilterReason.excluded,
      );
    });

    test('a pair who met last week is inside the day cooldown', () {
      final ana = aPerson('ana');
      final bruno = aPerson('bruno', gender: man);
      final snapshot = aSnapshot(
        [ana, bruno],
        edges: [anEdge('ana', 'bruno', daysAgo: 7)],
        history: [
          aPastHangout(['ana', 'bruno']),
        ],
      );
      expect(
        eligibility.rejectPair(ana, bruno, snapshot, config)?.reason,
        FilterReason.cooldown,
      );
    });

    test('a pair who met long ago and sat out enough hangouts may meet', () {
      final ana = aPerson('ana');
      final bruno = aPerson('bruno', gender: man);
      final snapshot = aSnapshot(
        [ana, bruno],
        edges: [anEdge('ana', 'bruno', daysAgo: 40)],
        history: [
          aPastHangout(['ana', 'bruno'], daysAgo: 40),
          aPastHangout(['ana', 'cvita'], daysAgo: 30),
          aPastHangout(['bruno', 'dario'], daysAgo: 25),
        ],
      );
      expect(eligibility.rejectPair(ana, bruno, snapshot, config), isNull);
    });

    test('enough days but not enough intervening hangouts still refuses', () {
      // `max(cooldown_meetups, cooldown_days)` — the *longer* of the two. A
      // pair who met once six weeks ago and have done nothing since have not
      // had the exposure the cooldown is measuring.
      final ana = aPerson('ana');
      final bruno = aPerson('bruno', gender: man);
      final snapshot = aSnapshot(
        [ana, bruno],
        edges: [anEdge('ana', 'bruno', daysAgo: 45)],
        history: [
          aPastHangout(['ana', 'bruno'], daysAgo: 45),
        ],
      );
      expect(
        eligibility.rejectPair(ana, bruno, snapshot, config)?.reason,
        FilterReason.cooldown,
      );
    });

    test('two people who have never met have no cooldown to satisfy', () {
      final ana = aPerson('ana');
      final bruno = aPerson('bruno', gender: man);
      expect(
        eligibility.rejectPair(ana, bruno, aSnapshot([ana, bruno]), config),
        isNull,
      );
    });

    test('two people with no cluster in common cannot meet anywhere', () {
      final ana = aPerson('ana', clusters: {north});
      final bruno = aPerson('bruno', gender: man, clusters: {south});
      expect(
        eligibility
            .rejectPair(ana, bruno, aSnapshot([ana, bruno]), config)
            ?.reason,
        FilterReason.noSharedCluster,
      );
    });

    test('one shared cluster is enough', () {
      final ana = aPerson('ana', clusters: {north, centre});
      final bruno = aPerson(
        'bruno',
        gender: man,
        clusters: {south, centre},
      );
      expect(
        eligibility.rejectPair(ana, bruno, aSnapshot([ana, bruno]), config),
        isNull,
      );
    });
  });

  group('the funnel says why the night was quiet', () {
    test('it counts each reason separately', () {
      // The whole point: "nobody matched" is the least useful sentence a
      // matcher can produce, and it is what a boolean filter produces.
      final people = [
        aPerson('available'),
        aPerson(
          'suspended',
          standing: const Standing(tier: StandingTier.suspended),
        ),
        aPerson('banned', standing: const Standing(tier: StandingTier.banned)),
        aPerson('unreachable', clusters: const {}),
        aPerson('elsewhere', city: const CityId('other-city')),
      ];
      final snapshot = aSnapshot(people);
      final funnel = FilterFunnel();

      final passing = eligibility.eligibleFor(
        testSlot,
        snapshot,
        config,
        funnel: funnel,
      );

      expect(passing.map((p) => p.id.value), ['available']);
      expect(funnel.countOf(FilterReason.standing), 2);
      expect(funnel.countOf(FilterReason.noSharedCluster), 1);
      expect(funnel.countOf(FilterReason.otherCity), 1);
      expect(funnel.total, 4);
    });

    test('it serialises to something the console can render', () {
      final funnel = FilterFunnel()
        ..record(FilterReason.cooldown)
        ..record(FilterReason.cooldown)
        ..record(FilterReason.standing);
      expect(funnel.toJson(), {'cooldown': 2, 'standing': 1});
    });
  });

  group('the rule set is composable, which is why it is objects', () {
    test('a run can add a rule without touching the existing ones', () {
      // The dating round's stricter filter, and the backfill's tighter
      // proximity bound, both arrive this way. Adding a rule cannot silently
      // reorder the others because each one is asked independently.
      final eligibility = Eligibility(
        personRules: const [MustBeAvailable(), _MustHaveMetSomeone()],
      );
      final newcomer = aPerson('newcomer', completedHangouts: 0);
      expect(
        eligibility
            .reject(newcomer, testSlot, aSnapshot([newcomer]), config)
            ?.reason,
        FilterReason.profileIncomplete,
      );
    });
  });
}

/// A rule that exists only to prove the set is open for extension.
final class _MustHaveMetSomeone implements PersonRule {
  const _MustHaveMetSomeone();

  @override
  FilterReason get reason => FilterReason.profileIncomplete;

  @override
  bool permits(Person p, Slot slot, MatchSnapshot s, MatchConfig c) =>
      p.completedHangouts > 0;
}
