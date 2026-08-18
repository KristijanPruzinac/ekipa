import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

void main() {
  group('Result', () {
    test('ok carries its value and reports isOk', () {
      const result = Result<int, String>.ok(7);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 7);
      expect(result.errorOrNull, isNull);
    });

    test('err carries its error and reports isErr', () {
      const result = Result<int, String>.err('nope');
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull, 'nope');
    });

    test('fold collapses both branches', () {
      const ok = Result<int, String>.ok(2);
      const err = Result<int, String>.err('bad');
      expect(ok.fold(onOk: (v) => v * 10, onErr: (_) => -1), 20);
      expect(err.fold(onOk: (v) => v * 10, onErr: (_) => -1), -1);
    });

    test('map transforms only the success branch', () {
      expect(
        const Result<int, String>.ok(2).map((v) => v + 1),
        const Ok<int, String>(3),
      );
      expect(
        const Result<int, String>.err('e').map((v) => v + 1),
        const Err<int, String>('e'),
      );
    });

    test('flatMap chains and short-circuits on the first error', () {
      Result<int, String> half(int v) =>
          v.isEven ? Ok(v ~/ 2) : const Err<int, String>('odd');

      expect(
        const Result<int, String>.ok(8).flatMap(half),
        const Ok<int, String>(4),
      );
      expect(
        const Result<int, String>.ok(7).flatMap(half),
        const Err<int, String>('odd'),
      );
      expect(
        const Result<int, String>.err('first').flatMap(half),
        const Err<int, String>('first'),
      );
    });

    test('mapErr transforms only the error branch', () {
      expect(
        const Result<int, String>.err('e').mapErr((e) => e.length),
        const Err<int, int>(1),
      );
      expect(
        const Result<int, String>.ok(1).mapErr((e) => e.length),
        const Ok<int, int>(1),
      );
    });

    test('unwrapOr substitutes the fallback only on error', () {
      expect(const Result<int, String>.ok(5).unwrapOr(99), 5);
      expect(const Result<int, String>.err('x').unwrapOr(99), 99);
    });

    test('equality is by value, so tests can assert on whole results', () {
      expect(const Ok<int, String>(1), const Ok<int, String>(1));
      expect(const Err<int, String>('a'), const Err<int, String>('a'));
      expect(const Ok<int, String>(1), isNot(const Ok<int, String>(2)));
    });
  });
}
