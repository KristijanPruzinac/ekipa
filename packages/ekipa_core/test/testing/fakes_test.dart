import 'package:ekipa_core/testing.dart';
import 'package:test/test.dart';

void main() {
  group('FakeClock', () {
    test('reports the instant it was started at, normalised to UTC', () {
      final clock = FakeClock(DateTime.utc(2026, 9, 3, 17, 30));
      expect(clock.nowUtc(), DateTime.utc(2026, 9, 3, 17, 30));
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('normalises a local start instant to UTC', () {
      final local = DateTime(2026, 9, 3, 17, 30);
      expect(FakeClock(local).nowUtc(), local.toUtc());
    });

    test('advance moves time forward', () {
      final clock = FakeClock(DateTime.utc(2026, 9, 3, 9))
        ..advance(const Duration(hours: 3));
      expect(clock.nowUtc(), DateTime.utc(2026, 9, 3, 12));
    });

    test('advance accumulates across successive deadlines', () {
      final clock = FakeClock(DateTime.utc(2026, 9, 3, 9));
      for (var i = 0; i < 7; i++) {
        clock.advance(const Duration(minutes: 30));
      }
      expect(clock.nowUtc(), DateTime.utc(2026, 9, 3, 12, 30));
    });

    test('refuses to move backwards via advance', () {
      final clock = FakeClock(DateTime.utc(2026, 9, 3));
      expect(
        () => clock.advance(const Duration(hours: -1)),
        throwsArgumentError,
      );
    });

    test('refuses to move backwards via setTo', () {
      final clock = FakeClock(DateTime.utc(2026, 9, 3, 12));
      expect(
        () => clock.setTo(DateTime.utc(2026, 9, 3, 11)),
        throwsArgumentError,
      );
    });

    test('setTo jumps forward', () {
      final clock = FakeClock(DateTime.utc(2026, 9, 3, 9))
        ..setTo(DateTime.utc(2026, 9, 5, 16));
      expect(clock.nowUtc(), DateTime.utc(2026, 9, 5, 16));
    });
  });

  group('ScriptedRandomSource', () {
    test('replays doubles in order', () {
      final source = ScriptedRandomSource(doubles: [0.1, 0.6, 0.9]);
      expect(source.nextDouble(), 0.1);
      expect(source.nextDouble(), 0.6);
      expect(source.nextDouble(), 0.9);
    });

    test('replays ints, wrapped into range', () {
      final source = ScriptedRandomSource(ints: [7, 12]);
      expect(source.nextInt(5), 2);
      expect(source.nextInt(5), 2);
    });

    test('a fork replays the same script', () {
      final source = ScriptedRandomSource(doubles: [0.4, 0.8]);
      final forked = source.fork('ring-draw');
      expect(forked.nextDouble(), 0.4);
      expect(source.nextDouble(), 0.8);
    });

    test('counts draws, so a stage can assert what it consumed', () {
      final source = ScriptedRandomSource(doubles: [0.1, 0.2], ints: [3])
        ..nextDouble()
        ..nextInt(10);
      expect(source.drawCount, 2);
    });

    test('exhaustion fails loudly and says why', () {
      final source = ScriptedRandomSource(doubles: [0.1])..nextDouble();
      expect(
        source.nextDouble,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('exhausted'),
          ),
        ),
      );
    });

    test('rejects a non-positive bound', () {
      final source = ScriptedRandomSource(ints: [1]);
      expect(() => source.nextInt(0), throwsArgumentError);
    });
  });
}
