import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

final ConfigKey<int> _cooldown = ConfigKey.integer(
  'matching.cooldown_meetups',
  defaultValue: 2,
  description: 'test key',
);

const _osijek = CityId('osijek');
const _zagreb = CityId('zagreb');

ConfigValueRow _row(String key, ConfigScope scope, Object? value) =>
    ConfigValueRow(key: key, scope: scope, value: value);

ConfigResolution _resolve(
  List<ConfigValueRow> rows,
  ConfigTarget target,
) => ConfigResolver.resolve(
  versionId: const ConfigVersionId('v1'),
  rows: rows,
  target: target,
);

void main() {
  group('scope shape', () {
    test('global carries no reference and everything else must', () {
      expect(const ConfigScope.global().isWellFormed, isTrue);
      expect(const ConfigScope.country('HR').isWellFormed, isTrue);
      expect(ConfigScope.city(_osijek).isWellFormed, isTrue);
      expect(const ConfigScope.country('').isWellFormed, isFalse);
      expect(const ConfigScope.cohort('').isWellFormed, isFalse);
    });

    test('specificity runs global < country < city < cohort', () {
      final ladder = [
        const ConfigScope.global(),
        const ConfigScope.country('HR'),
        ConfigScope.city(_osijek),
        const ConfigScope.cohort('dating-pilot'),
      ];
      for (var i = 1; i < ladder.length; i++) {
        expect(
          ladder[i].specificity,
          greaterThan(ladder[i - 1].specificity),
          reason: '${ladder[i]} must outrank ${ladder[i - 1]}',
        );
      }
    });

    test('two scopes of the same kind and reference are the same scope', () {
      expect(ConfigScope.city(_osijek), ConfigScope.city(_osijek));
      expect(ConfigScope.city(_osijek), isNot(ConfigScope.city(_zagreb)));
      // Different kinds, same reference. If these collided, a cohort named
      // after a city would silently inherit the city's overrides.
      expect(
        const ConfigScope.country('osijek'),
        isNot(ConfigScope.city(_osijek)),
      );
    });
  });

  group('resolution', () {
    test('the most specific admitted layer wins', () {
      final resolution = _resolve(
        [
          _row(_cooldown.name, const ConfigScope.global(), 2),
          _row(_cooldown.name, const ConfigScope.country('HR'), 3),
          _row(_cooldown.name, ConfigScope.city(_osijek), 1),
        ],
        const ConfigTarget(countryCode: 'HR', cityId: _osijek),
      );

      expect(resolution.snapshot.get(_cooldown), 1);
      expect(resolution.originOf(_cooldown.name), ConfigScope.city(_osijek));
    });

    test('row order does not decide anything', () {
      final rows = [
        _row(_cooldown.name, ConfigScope.city(_osijek), 1),
        _row(_cooldown.name, const ConfigScope.global(), 2),
      ];
      final forwards = _resolve(rows, const ConfigTarget(cityId: _osijek));
      final backwards = _resolve(
        rows.reversed.toList(),
        const ConfigTarget(cityId: _osijek),
      );

      // A resolution that depended on insertion order would make a match run
      // depend on when somebody happened to save a row, which is the one thing
      // `snapshot_hash` cannot detect.
      expect(forwards.snapshot.get(_cooldown), 1);
      expect(backwards.snapshot.get(_cooldown), 1);
    });

    test("another city's override is not visible", () {
      final resolution = _resolve(
        [
          _row(_cooldown.name, const ConfigScope.global(), 2),
          _row(_cooldown.name, ConfigScope.city(_zagreb), 9),
        ],
        const ConfigTarget(cityId: _osijek),
      );

      expect(resolution.snapshot.get(_cooldown), 2);
      expect(resolution.originOf(_cooldown.name), const ConfigScope.global());
    });

    test('a cohort outranks the city it lives in', () {
      final resolution = _resolve(
        [
          _row(_cooldown.name, ConfigScope.city(_osijek), 2),
          _row(_cooldown.name, const ConfigScope.cohort('dating-pilot'), 0),
        ],
        const ConfigTarget(cityId: _osijek, cohort: 'dating-pilot'),
      );

      expect(resolution.snapshot.get(_cooldown), 0);
    });

    test('a target in no city sees only the global layer', () {
      final resolution = _resolve(
        [
          _row(_cooldown.name, const ConfigScope.global(), 2),
          _row(_cooldown.name, const ConfigScope.country('HR'), 3),
          _row(_cooldown.name, ConfigScope.city(_osijek), 1),
        ],
        const ConfigTarget.everywhere(),
      );

      expect(resolution.snapshot.get(_cooldown), 2);
    });

    test('a key nobody stores falls back to its default with no origin', () {
      final resolution = _resolve([], const ConfigTarget.everywhere());

      expect(resolution.snapshot.get(_cooldown), _cooldown.defaultValue);
      expect(resolution.originOf(_cooldown.name), isNull);
      expect(resolution.explicitKeys, isEmpty);
    });

    test('the version id travels with the snapshot', () {
      final resolution = ConfigResolver.resolve(
        versionId: const ConfigVersionId('2026-08-18-a'),
        rows: const [],
        target: const ConfigTarget.everywhere(),
      );

      expect(resolution.snapshot.versionId.value, '2026-08-18-a');
    });
  });
}
