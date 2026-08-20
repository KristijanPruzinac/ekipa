import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:test/test.dart';

import '../support/world.dart';

void main() {
  group('the three ring shares can never fail to sum', () {
    // C is derived, never configured. Three numbers that must sum to one,
    // stored independently, are three numbers that will not sum to one — and
    // the failure is silent, because the draw still works, just not in the
    // ratio anybody chose.

    test('the defaults leave a quarter for strangers', () {
      final config = defaultConfig();
      expect(config.ringShareEnjoyed, 0.25);
      expect(config.ringShareLeaf, 0.5);
      expect(config.ringShareStranger, closeTo(0.25, 1e-9));
    });

    test('they sum to one for any pair of values', () {
      for (final a in [0.0, 0.1, 0.33, 0.5, 0.9]) {
        for (final b in [0.0, 0.1, 0.33, 0.5]) {
          if (a + b > 1) continue;
          final config = configWith({
            'matching.ring_share_enjoyed': a,
            'matching.ring_share_leaf': b,
          });
          expect(
            config.ringShareEnjoyed +
                config.ringShareLeaf +
                config.ringShareStranger,
            closeTo(1, 1e-9),
            reason: 'A=$a B=$b',
          );
        }
      }
    });

    test('an impossible version runs with no strangers, it does not crash', () {
      // A version that sets A + B above 1 is a mistake. The honest response is
      // to clamp and keep going: a malformed row must not take a nightly match
      // run down, because nobody is awake to restart it.
      final config = configWith({
        'matching.ring_share_enjoyed': 0.8,
        'matching.ring_share_leaf': 0.8,
      });
      expect(config.ringShareStranger, 0);
    });
  });

  group('the all-strangers control arm is a config value', () {
    test('A = B = 0 is recognised as the control', () {
      final config = configWith({
        'matching.ring_share_enjoyed': 0.0,
        'matching.ring_share_leaf': 0.0,
      });
      expect(config.isAllStrangersControl, isTrue);
      expect(config.ringShareStranger, 1);
    });

    test('and the default configuration is not', () {
      expect(defaultConfig().isAllStrangersControl, isFalse);
    });

    // Why this matters more than it looks: if ring-drawn groups never beat the
    // control, the honest response is to leave A = B = 0 in place. That retreat
    // being a config change rather than a refactor is the reason it could
    // actually happen.
  });

  group('every key is declared once and reachable', () {
    test('the registry has no duplicate names', () {
      final names = MatchingKeys.all.map((k) => k.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('every declared key is namespaced', () {
      for (final key in MatchingKeys.all) {
        expect(
          key.name,
          anyOf(startsWith('matching.'), startsWith('trust.')),
          reason: '${key.name} belongs to no namespace',
        );
      }
    });

    test('every key carries a description the console can render', () {
      for (final key in MatchingKeys.all) {
        expect(
          key.description.length,
          greaterThan(20),
          reason: '${key.name} has no usable description',
        );
      }
    });

    test('a typo in a stored key is reported, not silently absorbed', () {
      // The failure this prevents: somebody writes `matching.ring_share_enjoy`,
      // the matcher reads the default, everything works, and the ratio nobody
      // changed is the ratio that ships.
      final snapshot = ConfigSnapshot(
        versionId: const ConfigVersionId('typo'),
        values: const {'matching.ring_share_enjoyed': 'not a number'},
      );
      expect(
        snapshot.malformedKeys(MatchingKeys.all),
        ['matching.ring_share_enjoyed'],
      );
      // And the run still proceeds on the default rather than failing.
      expect(MatchConfig.from(snapshot).ringShareEnjoyed, 0.25);
    });
  });

  group('nothing behavioural is a literal (D5)', () {
    test('every number the matcher acts on comes from a key', () {
      // A change of heart about group size, cooldown, or the newcomer thumb on
      // the scale is a console edit, not a release.
      final config = configWith({
        'matching.min_group_size': 4,
        'matching.max_group_size': 6,
        'matching.cooldown_days': 7,
        'matching.cooldown_meetups': 0,
        'matching.max_known_pair_fraction': 0.25,
      });
      expect(config.minGroupSize, 4);
      expect(config.maxGroupSize, 6);
      expect(config.cooldownDays, 7);
      expect(config.cooldownMeetups, 0);
      expect(config.maxKnownPairFraction, 0.25);
    });

    test('the config version travels with the resolved values', () {
      // Recorded on every run, sanction and hangout, so a historical decision
      // can be re-read under the rules that actually applied to it.
      final config = configWith(const {});
      expect(config.versionId, const ConfigVersionId('test'));
    });
  });
}
