import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

final ConfigKey<int> _starveCap = ConfigKey.integer(
  'matching.starve_cap_weeks',
  defaultValue: 4,
  description: 'Weeks of starvation credit a seed candidate may accrue.',
);
final ConfigKey<double> _ringA = ConfigKey.decimal(
  'matching.ring_a_enjoyed',
  defaultValue: 0.25,
  description: 'Chance a dyad partner is drawn from R1.',
);
final ConfigKey<bool> _datingEnabled = ConfigKey.boolean(
  'dating.enabled',
  defaultValue: false,
  description: 'Master switch for the dating layer.',
);
final ConfigKey<Duration> _confirmWindow = ConfigKey.duration(
  'lifecycle.confirm_window',
  defaultValue: const Duration(hours: 3),
  description: 'How long a member has to answer the morning-of confirmation.',
);

void main() {
  group('ConfigSnapshot', () {
    test('defaults() returns every declared default', () {
      final config = ConfigSnapshot.defaults();
      expect(config.get(_starveCap), 4);
      expect(config.get(_ringA), 0.25);
      expect(config.get(_datingEnabled), isFalse);
      expect(config.get(_confirmWindow), const Duration(hours: 3));
    });

    test('an explicit value overrides the default', () {
      final config = ConfigSnapshot(
        versionId: const ConfigVersionId('v7'),
        values: const {'matching.starve_cap_weeks': 6},
      );
      expect(config.get(_starveCap), 6);
      expect(config.hasExplicitValue(_starveCap), isTrue);
      expect(config.hasExplicitValue(_ringA), isFalse);
    });

    test('durations round-trip through whole seconds', () {
      final config = ConfigSnapshot(
        versionId: const ConfigVersionId('v7'),
        values: const {'lifecycle.confirm_window': 5400},
      );
      expect(config.get(_confirmWindow), const Duration(minutes: 90));
    });

    test('an integer key accepts a JSON number that is whole', () {
      final config = ConfigSnapshot(
        versionId: const ConfigVersionId('v7'),
        values: const {'matching.starve_cap_weeks': 6.0},
      );
      expect(config.get(_starveCap), 6);
    });

    test('a malformed value falls back rather than taking the run down', () {
      // A single bad row must not stop the nightly match run: no hangouts at
      // all is a worse outcome than one key running at its default.
      final config = ConfigSnapshot(
        versionId: const ConfigVersionId('v7'),
        values: const {'matching.starve_cap_weeks': 'not a number'},
      );
      expect(config.get(_starveCap), 4);
    });

    test('a malformed value is reported, so it degrades loudly', () {
      final config = ConfigSnapshot(
        versionId: const ConfigVersionId('v7'),
        values: const {
          'matching.starve_cap_weeks': 'not a number',
          'matching.ring_a_enjoyed': 0.4,
        },
      );
      expect(
        config.malformedKeys([_starveCap, _ringA, _datingEnabled]),
        ['matching.starve_cap_weeks'],
      );
    });

    test('an explicit null falls back to the default', () {
      final config = ConfigSnapshot(
        versionId: const ConfigVersionId('v7'),
        values: const {'matching.ring_a_enjoyed': null},
      );
      expect(config.get(_ringA), 0.25);
    });

    test('the version id is carried, so a decision can be re-read later', () {
      final config = ConfigSnapshot(
        versionId: const ConfigVersionId('2026-08-18T21:00'),
        values: const {},
      );
      expect(config.versionId, const ConfigVersionId('2026-08-18T21:00'));
    });

    test('values are copied, so a later mutation cannot change a live run', () {
      final mutable = <String, Object?>{'matching.starve_cap_weeks': 6};
      final config = ConfigSnapshot(
        versionId: const ConfigVersionId('v7'),
        values: mutable,
      );
      mutable['matching.starve_cap_weeks'] = 99;
      expect(config.get(_starveCap), 6);
    });
  });
}
