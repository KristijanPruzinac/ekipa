import 'package:ekipa_data/ekipa_data.dart';
import 'package:test/test.dart';

void main() {
  group('SystemClock', () {
    test('returns an instant in UTC', () {
      // The one place in the system that reads wall-clock time. It must hand
      // back UTC, because every instant is stored and compared in UTC and only
      // *rules* are expressed in a city's local timezone. A local DateTime
      // leaking out of here is how DST bugs start.
      expect(const SystemClock().nowUtc().isUtc, isTrue);
    });

    test('advances between reads', () {
      const clock = SystemClock();
      final first = clock.nowUtc();
      final second = clock.nowUtc();
      expect(second.isBefore(first), isFalse);
    });

    test('is close to the real current time', () {
      final drift = const SystemClock()
          .nowUtc()
          .difference(DateTime.now().toUtc())
          .abs();
      expect(drift, lessThan(const Duration(seconds: 5)));
    });
  });
}
