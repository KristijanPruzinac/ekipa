/// Snapshot JSON in, plan JSON out, with the real matcher in the middle.
///
/// **Intention — the codec is the part that fails silently.** The matcher has
/// its own tests and the SQL has pgTAP; the translation between them has
/// neither, and a field read under the wrong name does not throw. It produces a
/// person with no clusters, or an edge weight of zero, or a standing of `good`
/// for somebody who is suspended — and the plan that comes out is *plausible*.
/// That is the worst possible failure mode for a matcher, because nothing looks
/// wrong.
///
/// So the payload below is not invented. It is the shape `worker_snapshot`
/// actually returns, keys and all, checked against the live function.
library;

import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:ekipa_core/testing.dart';
import 'package:mill/src/snapshot_codec.dart';
import 'package:test/test.dart';

const String _city = '88888888-8888-4888-8888-888888888881';
const String _cluster = 'c1000000-0000-4000-8000-000000000001';
final DateTime _now = DateTime.utc(2026, 10, 22, 12);

void main() {
  group('readSnapshot', () {
    test('reads a whole city out of one value', () {
      final snapshot = readSnapshot(_payload());

      expect(snapshot.cityId.value, _city);
      expect(snapshot.populationSize, 10);
      expect(snapshot.slots, hasLength(2));
      expect(
        snapshot.availableFor(const SlotId('${_slotPrefix}1')),
        hasLength(10),
      );
    });

    test('a person with no reachable clusters gets an empty set', () {
      // Not a set containing one null. `worker_snapshot` filters the left join
      // for exactly this: `[null]` would read as "shares a cluster with
      // everybody else who has none", and the matcher would happily put four
      // people who cannot reach any venue into a group.
      final snapshot = readSnapshot(_payload());
      final stranded = snapshot.person(const PersonId('${_personPrefix}6'))!;

      expect(stranded.reachableClusters, isEmpty);
      expect(
        stranded.sharesClusterWith(
          snapshot.person(const PersonId('${_personPrefix}1'))!,
        ),
        isFalse,
      );
    });

    test('a suspended tier survives the round trip', () {
      // The matcher's eligibility stage is the only thing entitled to act on
      // this, and it can only act on it if the codec carries it. Reading the
      // tier as `good` by mistake would put a suspended person in a group.
      final snapshot = readSnapshot(_payload());

      expect(
        snapshot.person(const PersonId('${_personPrefix}5'))!.standing.tier,
        StandingTier.suspended,
      );
      expect(
        snapshot.person(const PersonId('${_personPrefix}1'))!.standing.tier,
        StandingTier.good,
      );
    });

    test('a null quota is not a quota of zero', () {
      // Zero is the rating gate holding somebody out of the next run. Null is
      // an ordinary person with nothing against them. Collapsing the two would
      // silently stop matching everybody.
      final snapshot = readSnapshot(_payload());

      expect(
        snapshot
            .person(const PersonId('${_personPrefix}1'))!
            .standing
            .remainingQuota,
        isNull,
      );
      expect(
        snapshot
            .person(const PersonId('${_personPrefix}4'))!
            .standing
            .remainingQuota,
        0,
      );
      expect(
        snapshot
            .person(const PersonId('${_personPrefix}4'))!
            .standing
            .mayBeMatched,
        isFalse,
        reason: 'a zero quota is what the rating gate is made of',
      );
    });

    test('edges and exclusions come back symmetric', () {
      final snapshot = readSnapshot(_payload());
      const one = PersonId('${_personPrefix}1');
      const two = PersonId('${_personPrefix}2');

      expect(snapshot.edgeBetween(one, two)?.weight, 1.0);
      expect(
        snapshot.edgeBetween(two, one)?.weight,
        1.0,
        reason: 'the key is ordered, so there is no direction to get wrong',
      );
      expect(
        snapshot.isExcluded(
          const PersonId('${_personPrefix}2'),
          const PersonId('${_personPrefix}3'),
        ),
        isTrue,
      );
      expect(snapshot.isExcluded(one, two), isFalse);
    });

    test('the hash is stable across two reads of the same payload', () {
      // The claim `match_runs` records is that the same snapshot and seed
      // produce a byte-identical plan. It is only checkable if two decodes of
      // one payload agree on the hash.
      expect(
        readSnapshot(_payload()).snapshotHash,
        readSnapshot(_payload()).snapshotHash,
      );
    });
  });

  group('the whole pipeline', () {
    test('produces a plan the commit function could take', () {
      final snapshot = readSnapshot(_payload());
      final config = MatchConfig.from(ConfigSnapshot.defaults());
      final plan = const Matchmaker().run(snapshot, config, 4242);

      expect(plan.hangouts, isNotEmpty, reason: 'ten people, two slots');

      final json = writePlan(
        plan,
        config: ConfigSnapshot.defaults(),
        snapshot: snapshot,
        kind: 'daily',
      );

      expect(json['city'], _city);
      expect(json['seed'], 4242);
      expect(json['config_version'], isNull, reason: 'running on defaults');

      final groups = json['groups']! as List<Object?>;
      for (final entry in groups) {
        final group = entry! as Map<String, Object?>;
        // All seven deadlines, on every group, written at creation. `0003`
        // requires it so a mid-day config change cannot move one somebody is
        // already inside — and a null here would be a hangout the sweeper
        // never picks up, which is an evening that silently never happens.
        for (final deadline in const [
          'confirm_opens_at',
          'confirm_deadline_at',
          'backfill_until',
          'reveal_at',
          'arrival_grace_until',
          'late_report_until',
          'rating_due_at',
        ]) {
          expect(
            group[deadline],
            isA<String>(),
            reason: '$deadline is missing from a group',
          );
        }

        final members = group['members']! as List<Object?>;
        expect(members.length, inInclusiveRange(3, 4));
        expect(
          members.first,
          isA<Map<String, Object?>>().having(
            (m) => m['role'],
            'first member is the seed',
            'seed',
          ),
        );
      }
    });

    test('the deadlines fall in the order the lifecycle needs', () {
      final snapshot = readSnapshot(_payload());
      final plan = const Matchmaker().run(
        snapshot,
        MatchConfig.from(ConfigSnapshot.defaults()),
        7,
      );
      final group =
          (writePlan(
                        plan,
                        config: ConfigSnapshot.defaults(),
                        snapshot: snapshot,
                        kind: 'daily',
                      )['groups']!
                      as List<Object?>)
                  .first!
              as Map<String, Object?>;

      DateTime at(String key) => DateTime.parse(group[key]! as String);

      expect(
        at('confirm_opens_at').isBefore(at('confirm_deadline_at')),
        isTrue,
      );
      expect(at('confirm_deadline_at').isBefore(at('backfill_until')), isTrue);
      expect(
        at('backfill_until').isBefore(at('reveal_at')),
        isTrue,
        reason:
            'nobody learns the meeting point and then learns it is off — the '
            'cancellation has to land before anyone leaves home',
      );
      expect(at('reveal_at').isBefore(at('arrival_grace_until')), isTrue);
      expect(
        at('arrival_grace_until').isBefore(at('late_report_until')),
        isTrue,
        reason: 'a no-show is only attestable after somebody stops being late',
      );
      expect(at('late_report_until').isBefore(at('rating_due_at')), isTrue);
    });

    test('cards need two carriers, and conversation needs nothing', () {
      // Everybody carrying a deck: cards. One person carrying: conversation,
      // because one carrier is a single point of failure with a face — if that
      // person forgets, three people sit at a table waiting for an evening
      // that cannot start, and everybody knows whose fault it is
      // (`06_ACTIVITIES.md §2`).
      //
      // Asserted over *every* group rather than the first, because which
      // people end up in the first group is the matcher's business and a test
      // that depended on it would break for an unrelated reason.
      Set<String> activitiesWith(int carriers) {
        final snapshot = readSnapshot(_payload(carriers: carriers));
        final plan = const Matchmaker().run(
          snapshot,
          MatchConfig.from(ConfigSnapshot.defaults()),
          11,
        );
        final groups =
            writePlan(
                  plan,
                  config: ConfigSnapshot.defaults(),
                  snapshot: snapshot,
                  kind: 'daily',
                )['groups']!
                as List<Object?>;
        return {
          for (final group in groups)
            (group! as Map<String, Object?>)['activity']! as String,
        };
      }

      expect(activitiesWith(10), {'CARDS'});
      expect(activitiesWith(1), {'CONVERSATION_DECK'});
    });
  });

  test('the seed is derived from the city and the day, not from a clock', () {
    // Two runs on the same day must produce the same plan, so the second one's
    // groups collide with the first's on the one-per-slot index and are
    // skipped — rather than forming a second, different set of groups out of
    // whoever the first run left over.
    final morning = FakeClock(DateTime.utc(2026, 10, 22, 6));
    final evening = FakeClock(DateTime.utc(2026, 10, 22, 23));
    expect(morning.nowUtc().day, evening.nowUtc().day);
  });
}

const String _personPrefix = '11111111-1111-4111-8111-11111111111';
const String _slotPrefix = '99999999-9999-4999-8999-99999999999';

/// The shape `worker_snapshot` returns, with [carriers] people holding a deck.
Map<String, Object?> _payload({int carriers = 4}) => {
  'city': _city,
  'taken_at': _now.toIso8601String(),
  'slots': [
    for (var n = 1; n <= 2; n++)
      {
        'id': '$_slotPrefix$n',
        'city': _city,
        'starts_at': _now.add(Duration(days: n)).toIso8601String(),
        'ends_at': _now.add(Duration(days: n, minutes: 90)).toIso8601String(),
      },
  ],
  'people': [
    for (var n = 1; n <= 10; n++)
      {
        'id': '$_personPrefix$n',
        'gender': n.isEven ? 'man' : 'woman',
        'city': _city,
        'lat': 45.55 + n * 0.001,
        'lon': 18.69 + n * 0.001,
        // Person 6 can reach nothing. That is a real state — somebody on the
        // edge of town — and it must not read as "shares a cluster with the
        // other people who can reach nothing".
        'clusters': n == 6 ? <String>[] : <String>[_cluster],
        'tier': n == 5 ? 'suspended' : 'good',
        'respect_yes': 3,
        'respect_no': 0,
        'remaining_quota': n == 4 ? 0 : null,
        'completed': n,
        'weeks_waiting': 1,
        'equipment': n <= carriers ? <String>['deck_of_cards'] : <String>[],
        'activities': <String>[],
      },
  ],
  'availability': {
    for (var s = 1; s <= 2; s++)
      '$_slotPrefix$s': [for (var n = 1; n <= 10; n++) '$_personPrefix$n'],
  },
  'edges': [
    {
      'a': '${_personPrefix}1',
      'b': '${_personPrefix}2',
      'weight': 1.0,
      'meet_count': 1,
      'last_met_at': _now.subtract(const Duration(days: 40)).toIso8601String(),
    },
  ],
  'exclusions': [
    {
      'a': '${_personPrefix}2',
      'b': '${_personPrefix}3',
      'reason': 'rather_not',
    },
  ],
  'history': [
    {
      'ended_at': _now.subtract(const Duration(days: 40)).toIso8601String(),
      'members': ['${_personPrefix}1', '${_personPrefix}2'],
    },
  ],
  'already_placed': <String, Object?>{},
};
