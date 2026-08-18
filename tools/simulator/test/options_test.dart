import 'package:simulator/simulator.dart';
import 'package:test/test.dart';

void main() {
  group('defaults', () {
    test('no arguments is twelve weeks of a hundred and twenty people', () {
      final options = Options.parse([]);
      expect(options.weeks, 12);
      expect(options.people, 120);
      expect(options.seed, 1);
      expect(options.overrides, isEmpty);
      expect(options.asJson, isFalse);
      expect(options.compare, isFalse);
    });
  });

  group('flags', () {
    test('the scalars parse', () {
      final options = Options.parse([
        '--weeks=4',
        '--people=30',
        '--seed=99',
        '--json',
        '--compare',
      ]);
      expect(options.weeks, 4);
      expect(options.people, 30);
      expect(options.seed, 99);
      expect(options.asJson, isTrue);
      expect(options.compare, isTrue);
    });

    test('--set takes a key=value, in either spelling, repeatably', () {
      final options = Options.parse([
        '--set',
        'matching.ring_share_enjoyed=0.4',
        '--set=matching.cooldown_meetups=3',
      ]);
      expect(options.overrides, {
        'matching.ring_share_enjoyed': 0.4,
        'matching.cooldown_meetups': 3,
      });
    });

    test('an override actually reaches the config', () {
      final options = Options.parse([
        '--set=matching.ring_share_enjoyed=0.4',
      ]);
      expect(options.config.ringShareEnjoyed, 0.4);
      expect(options.baseline.ringShareEnjoyed, isNot(0.4));
    });
  });

  group('a typo is refused rather than absorbed', () {
    test('an unknown config key throws and names itself', () {
      // The failure this check exists for: an unknown key would otherwise be
      // stored, ignored by the config, and the run would faithfully report that
      // the change did nothing. True, and the most misleading output the tool
      // could produce.
      expect(
        () => Options.parse(['--set=matching.ring_share_enjoyd=0.4']),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('matching.ring_share_enjoyd'),
          ),
        ),
      );
    });

    test('a value of the wrong type is refused', () {
      expect(
        () => Options.parse(['--set=matching.min_group_size=lots']),
        throwsA(isA<FormatException>()),
      );
    });

    test('a --set with no pair is refused', () {
      expect(
        () => Options.parse(['--set']),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Options.parse(['--set=nonsense']),
        throwsA(isA<FormatException>()),
      );
    });

    test('an unknown flag is refused rather than ignored', () {
      expect(
        () => Options.parse(['--wekes=4']),
        throwsA(isA<FormatException>()),
      );
    });

    test('a negative or non-numeric count is refused', () {
      expect(
        () => Options.parse(['--weeks=-1']),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Options.parse(['--people=many']),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
