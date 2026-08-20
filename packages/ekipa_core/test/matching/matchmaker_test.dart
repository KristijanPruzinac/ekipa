import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:test/test.dart';

import '../support/world.dart';

/// A city of [count] people, alternating gender so a valid group always exists.
List<Person> aCity(
  int count, {
  Set<ClusterId>? clusters,
  int completedHangouts = 3,
}) => [
  for (var i = 0; i < count; i++)
    aPerson(
      'p${i.toString().padLeft(3, '0')}',
      gender: i.isEven ? woman : man,
      clusters: clusters,
      completedHangouts: completedHangouts,
      weeksWaiting: i % 5,
    ),
];

void main() {
  const matchmaker = Matchmaker();
  final config = defaultConfig();

  group('what the matchmaker must never do (03_MATCHMAKER.md §7)', () {
    // Each of these is a property over the whole plan, not a check of one
    // branch. They are the seven rules the document says must be
    // property-tested rather than reviewed.

    test('it never places a suspended or banned person', () {
      final people = [
        ...aCity(16),
        aPerson(
          'suspended',
          standing: const Standing(tier: StandingTier.suspended),
        ),
        aPerson(
          'banned',
          gender: man,
          standing: const Standing(tier: StandingTier.banned),
        ),
      ];
      final plan = matchmaker.run(aSnapshot(people), config, 20260820);
      expect(plan.placedPeople, isNot(contains(const PersonId('suspended'))));
      expect(plan.placedPeople, isNot(contains(const PersonId('banned'))));
    });

    test('it never places somebody whose throttle quota is spent', () {
      final people = [
        ...aCity(12),
        aPerson(
          'spent',
          standing: const Standing(
            tier: StandingTier.throttled,
            remainingQuota: 0,
          ),
        ),
      ];
      final plan = matchmaker.run(aSnapshot(people), config, 7);
      expect(plan.placedPeople, isNot(contains(const PersonId('spent'))));
    });

    test('it never violates an exclusion, in either direction', () {
      // Never overridden, for any reason, including a thin night. Checked over
      // every seed rather than one, because a single seed proves nothing about
      // a sampler.
      final people = aCity(12);
      final exclusions = [
        anExclusion('p000', 'p001'),
        anExclusion('p003', 'p002'),
        anExclusion('p005', 'p008'),
      ];
      final snapshot = aSnapshot(people, exclusions: exclusions);

      for (var seed = 0; seed < 40; seed++) {
        final plan = matchmaker.run(snapshot, config, seed);
        for (final hangout in plan.hangouts) {
          for (final exclusion in exclusions) {
            final both =
                hangout.memberIds.contains(exclusion.pair.low) &&
                hangout.memberIds.contains(exclusion.pair.high);
            expect(both, isFalse, reason: 'seed $seed placed $exclusion');
          }
        }
      }
    });

    test('it never emits a group whose composition rule fails', () {
      // ⑦ is reject-and-rebuild, so this is the assertion that the rebuild
      // actually happens rather than the group being patched through.
      const composition = Composition();
      final snapshot = aSnapshot(aCity(20));

      for (var seed = 0; seed < 25; seed++) {
        final plan = matchmaker.run(snapshot, config, seed);
        for (final hangout in plan.hangouts) {
          final members = [
            for (final id in hangout.memberIds) snapshot.person(id)!,
          ];
          expect(
            composition.verdict(members, snapshot, config).failures,
            isEmpty,
            reason: 'seed $seed emitted an invalid group: $hangout',
          );
        }
      }
    });

    test('it never places a person in two groups in the same slot', () {
      // Two groups holding one person means at least one group waits for
      // somebody who is not coming — the single outcome the product cannot
      // survive at launch.
      final snapshot = aSnapshot(
        aCity(24),
        slots: [testSlot, laterSlot],
      );
      for (var seed = 0; seed < 20; seed++) {
        final plan = matchmaker.run(snapshot, config, seed);
        for (final slot in [testSlot, laterSlot]) {
          final placed = <PersonId>[];
          for (final hangout in plan.hangouts) {
            if (hangout.slot == slot.id) placed.addAll(hangout.memberIds);
          }
          expect(placed.toSet().length, placed.length, reason: 'seed $seed');
        }
      }
    });

    test('it never places somebody twice across slots either', () {
      // The 90-minute windows here do not overlap, so this is not the
      // double-booking rule — it is the "one evening per run" rule, carried
      // across the partition.
      final snapshot = aSnapshot(aCity(24), slots: [testSlot, laterSlot]);
      for (var seed = 0; seed < 20; seed++) {
        final plan = matchmaker.run(snapshot, config, seed);
        final all = [
          for (final h in plan.hangouts) ...h.memberIds,
        ];
        expect(all.toSet().length, all.length, reason: 'seed $seed');
      }
    });

    test('a person under sanction is never the seed', () {
      // Invariant 4. The throttled person may fill a seat; they are never the
      // evening built around them.
      final people = [
        ...aCity(10),
        for (var i = 0; i < 4; i++)
          aPerson(
            'throttled-$i',
            gender: i.isEven ? woman : man,
            weeksWaiting: 40,
            standing: const Standing(
              tier: StandingTier.throttled,
              remainingQuota: 5,
            ),
          ),
      ];
      final snapshot = aSnapshot(people);
      for (var seed = 0; seed < 30; seed++) {
        final plan = matchmaker.run(snapshot, config, seed);
        for (final hangout in plan.hangouts) {
          expect(
            hangout.seed.value,
            isNot(startsWith('throttled')),
            reason: 'seed $seed built a group around a sanctioned person',
          );
        }
      }
    });

    test('an R2 intermediary is never in the group they introduced', () {
      // A, B and C where C arrived via B is three known pairs of six and one
      // outsider — a trio talking while the fourth person watches.
      final people = aCity(16);
      final snapshot = aSnapshot(
        people,
        edges: [
          for (var i = 0; i < 14; i += 2)
            anEdge(
              'p${i.toString().padLeft(3, '0')}',
              'p${(i + 1).toString().padLeft(3, '0')}',
              daysAgo: 300,
            ),
          for (var i = 1; i < 13; i += 2)
            anEdge(
              'p${i.toString().padLeft(3, '0')}',
              'p${(i + 2).toString().padLeft(3, '0')}',
              daysAgo: 300,
            ),
        ],
      );

      for (var seed = 0; seed < 30; seed++) {
        final plan = matchmaker.run(snapshot, config, seed);
        for (final hangout in plan.hangouts) {
          for (final member in hangout.members) {
            final via = member.via;
            if (via == null) continue;
            expect(
              hangout.memberIds,
              isNot(contains(via)),
              reason: 'seed $seed placed the intermediary',
            );
          }
        }
      }
    });
  });

  group('determinism is the property everything else depends on', () {
    test('the same snapshot and seed produce the same plan', () {
      final snapshot = aSnapshot(aCity(20));
      final first = matchmaker.run(snapshot, config, 4242);
      final second = matchmaker.run(snapshot, config, 4242);
      expect(_render(first), _render(second));
    });

    test('a different seed produces a different plan', () {
      final snapshot = aSnapshot(aCity(20));
      expect(
        _render(matchmaker.run(snapshot, config, 1)),
        isNot(_render(matchmaker.run(snapshot, config, 2))),
      );
    });

    test('the plan carries the snapshot digest and the config version', () {
      // Together with the seed, these are what make a replay able to say which
      // side changed when it disagrees.
      final snapshot = aSnapshot(aCity(8));
      final plan = matchmaker.run(snapshot, config, 5);
      expect(plan.snapshotHash, snapshot.snapshotHash);
      expect(plan.configVersion, config.versionId);
      expect(plan.seed, 5);
    });

    test('the order slots arrive in does not change the plan', () {
      // Slots are processed in scarcity order and each gets its own forked
      // random stream, keyed by slot id. So the caller's ordering is not an
      // input — which matters because the worker builds that list from a query
      // whose order nobody has pinned.
      //
      // Note what is *not* claimed: adding a person to Thursday can change
      // Friday, because scarcity ordering couples the slots on purpose. That
      // coupling is the cheap approximation of cross-slot optimisation, and it
      // is the whole reason a thin slot gets first pick.
      final base = aCity(16);
      final forwards = matchmaker.run(
        aSnapshot(base, slots: [testSlot, laterSlot]),
        config,
        99,
      );
      final backwards = matchmaker.run(
        aSnapshot(base, slots: [laterSlot, testSlot]),
        config,
        99,
      );
      expect(_render(forwards), _render(backwards));
    });
  });

  group('what the plan reports', () {
    test('groups are within the configured size bounds', () {
      final plan = matchmaker.run(aSnapshot(aCity(24)), config, 11);
      expect(plan.hangouts, isNotEmpty);
      for (final hangout in plan.hangouts) {
        expect(hangout.size, greaterThanOrEqualTo(config.minGroupSize));
        expect(hangout.size, lessThanOrEqualTo(config.maxGroupSize));
      }
    });

    test('the funnel explains a night where nobody could be matched', () {
      // "Nothing happened" is the least useful sentence a matcher can produce.
      final people = [
        for (var i = 0; i < 6; i++)
          aPerson(
            'suspended-$i',
            standing: const Standing(tier: StandingTier.suspended),
          ),
      ];
      final plan = matchmaker.run(aSnapshot(people), config, 3);
      expect(plan.hangouts, isEmpty);
      expect(plan.stats.funnel.countOf(FilterReason.standing), 6);
      expect(plan.stats.toJson()['filtered'], {'standing': 6});
    });

    test('the ring ledger reports configured next to realised', () {
      final snapshot = aSnapshot(
        aCity(20),
        edges: [
          for (var i = 0; i < 18; i += 2)
            anEdge(
              'p${i.toString().padLeft(3, '0')}',
              'p${(i + 1).toString().padLeft(3, '0')}',
              daysAgo: 300,
            ),
        ],
      );
      final plan = matchmaker.run(snapshot, config, 77);
      final rings = plan.stats.toJson()['rings']! as Map<String, Object?>;
      expect(rings['intended'], isA<Map<String, Object?>>());
      expect(rings['realised'], isA<Map<String, Object?>>());
      expect(plan.stats.ringLedger.drawCount, greaterThan(0));
    });

    test('every group names the clusters it could meet in', () {
      // A set rather than a choice: the meeting point is picked at lock time,
      // so a backfilled replacement only has to reach the cluster.
      final plan = matchmaker.run(
        aSnapshot(aCity(12, clusters: {centre, north})),
        config,
        13,
      );
      for (final hangout in plan.hangouts) {
        expect(hangout.clusterCandidates, isNotEmpty);
      }
    });

    test('the unplaced count is the number that matters on a thin night', () {
      // Five people, a gender split that allows one group of four. The fifth is
      // eligible and goes home, and the plan says so.
      final people = [
        aPerson('a'),
        aPerson('b'),
        aPerson('c', gender: man),
        aPerson('d', gender: man),
        aPerson('e', gender: other),
      ];
      final plan = matchmaker.run(aSnapshot(people), config, 21);
      expect(plan.stats.eligibleConsidered, 5);
      expect(plan.stats.placed + plan.stats.unplaced, 5);
      expect(plan.stats.unplaced, greaterThan(0));
    });

    test('a refused group is recorded with the rule it broke', () {
      // This cannot be reconstructed later, which is why it is written before
      // the first real hangout rather than after the first question about one.
      final people = [
        for (var i = 0; i < 3; i++) aPerson('w-$i'),
        aPerson('lone', gender: man),
      ];
      final snapshot = aSnapshot(people);
      final recorded = <CompositionFailure>{};
      for (var seed = 0; seed < 40; seed++) {
        final plan = matchmaker.run(snapshot, config, seed);
        for (final hangout in plan.hangouts) {
          for (final rejection in hangout.rejectedAlternates) {
            recorded.addAll(rejection.failures);
          }
        }
        // The case that is easiest to lose: a slot that gives up entirely has
        // no successful group to hang its refusals on, and that is precisely
        // the night somebody will ask about.
        for (final rejection in plan.stats.abandonedAlternates) {
          recorded.addAll(rejection.failures);
        }
      }
      expect(recorded, contains(CompositionFailure.loneGender));
    });

    test('a rejection serialises for the console', () {
      const rejection = RejectedAlternate(
        members: [PersonId('a'), PersonId('b')],
        failures: [CompositionFailure.loneGender],
      );
      expect(rejection.toJson(), {
        'members': ['a', 'b'],
        'failures': ['loneGender'],
      });
    });
  });

  group('scarce slots get first pick', () {
    test('the thin slot is filled before the abundant one', () {
      // Cross-slot optimisation is rejected; this is the cheap approximation of
      // it that keeps the problem decomposable. A thin slot processed second
      // would lose its few candidates to a slot that had plenty.
      final people = aCity(10);
      final snapshot = aSnapshot(
        people,
        slots: [testSlot, laterSlot],
        availability: {
          // Everyone is free later; only four are free at the earlier slot.
          testSlot.id: {for (final p in people.take(4)) p.id},
          laterSlot.id: {for (final p in people) p.id},
        },
      );
      final plan = matchmaker.run(snapshot, config, 31);
      final earlyGroups = plan.hangouts.where((h) => h.slot == testSlot.id);
      expect(
        earlyGroups,
        isNotEmpty,
        reason: 'the scarce slot must not be starved by the abundant one',
      );
    });
  });

  group('one function, several uses', () {
    test('the all-strangers control produces only stranger draws', () {
      // A = B = 0. The permanent control arm is a config value on a fraction of
      // runs, not a second code path — which is why the retreat, if ring-drawn
      // groups never beat it, is a console edit rather than a refactor.
      final control = configWith({
        'matching.ring_share_enjoyed': 0.0,
        'matching.ring_share_leaf': 0.0,
      });
      final snapshot = aSnapshot(
        aCity(16),
        edges: [
          for (var i = 0; i < 14; i += 2)
            anEdge(
              'p${i.toString().padLeft(3, '0')}',
              'p${(i + 1).toString().padLeft(3, '0')}',
              daysAgo: 300,
            ),
        ],
      );
      final plan = matchmaker.run(snapshot, control, 55);
      expect(plan.stats.ringLedger.realisedCount(Ring.r1Enjoyed), 0);
      expect(plan.stats.ringLedger.realisedCount(Ring.r2Leaf), 0);
      expect(
        plan.stats.ringLedger.realisedCount(Ring.r3Stranger),
        greaterThan(0),
      );
    });

    test('a repair run is the same function with a narrower snapshot', () {
      // The backfill path, expressed as input rather than as a second matcher —
      // which is exactly where a rushed second implementation would forget the
      // exclusion check.
      final repair = configWith({
        'matching.ring_share_enjoyed': 0.0,
        'matching.ring_share_leaf': 0.0,
        'matching.min_group_size': 3,
      });
      final standby = aCity(4);
      final plan = matchmaker.run(aSnapshot(standby), repair, 8);
      expect(plan.hangouts, hasLength(1));
      expect(plan.hangouts.single.size, greaterThanOrEqualTo(3));
    });

    test('an empty city is a normal Tuesday, not an error', () {
      final plan = matchmaker.run(aSnapshot(const []), config, 1);
      expect(plan.hangouts, isEmpty);
      expect(plan.stats.placed, 0);
      expect(plan.stats.unplaced, 0);
    });

    test('a city too small for one group produces nothing', () {
      final plan = matchmaker.run(
        aSnapshot([aPerson('a'), aPerson('b')]),
        config,
        1,
      );
      expect(plan.hangouts, isEmpty);
    });
  });
}

/// A stable rendering of a plan, for equality assertions.
String _render(MatchPlan plan) => [
  for (final hangout in plan.hangouts) _renderGroup(hangout),
].join(' | ');

String _renderGroup(PlannedHangout hangout) {
  final members = [
    for (final m in hangout.members) _renderMember(m),
  ];
  return '${hangout.slot.value}:${members.join(',')}';
}

String _renderMember(PlannedMember member) {
  final ring = member.ringRealised?.storageCode ?? '-';
  return '${member.person.value}/${member.role.name}/$ring';
}
