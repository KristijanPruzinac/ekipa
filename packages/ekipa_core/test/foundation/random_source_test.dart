import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

void main() {
  group('SeededRandomSource', () {
    test('the same seed produces the same sequence', () {
      final a = SeededRandomSource(42);
      final b = SeededRandomSource(42);
      final fromA = List.generate(50, (_) => a.nextInt(1000));
      final fromB = List.generate(50, (_) => b.nextInt(1000));
      expect(fromA, fromB);
    });

    test('different seeds diverge', () {
      final a = SeededRandomSource(1);
      final b = SeededRandomSource(2);
      final fromA = List.generate(50, (_) => a.nextInt(1000));
      final fromB = List.generate(50, (_) => b.nextInt(1000));
      expect(fromA, isNot(fromB));
    });

    test('forks are reproducible from the parent seed and label', () {
      final childA = SeededRandomSource(7).fork('ring-draw');
      final childB = SeededRandomSource(7).fork('ring-draw');
      expect(
        List.generate(20, (_) => childA.nextDouble()),
        List.generate(20, (_) => childB.nextDouble()),
      );
    });

    test('different labels fork to independent streams', () {
      final parent = SeededRandomSource(7);
      final seeds = <int>{
        for (final label in ['seed-policy', 'ring-draw', 'completion'])
          (parent.fork(label) as SeededRandomSource).seed,
      };
      expect(seeds, hasLength(3));
    });

    test('drawing from the parent does not shift an already-taken fork', () {
      // The property that makes stage-local randomness safe: adding one draw in
      // seed selection must not move the ring draw's sequence, or every golden
      // test fails for a reason unrelated to the change that broke it.
      final child = SeededRandomSource(11).fork('ring-draw');
      final before = List.generate(10, (_) => child.nextDouble());

      final parent = SeededRandomSource(11)..nextInt(100);
      final child2 = parent.fork('ring-draw');
      final after = List.generate(10, (_) => child2.nextDouble());

      expect(after, before);
    });

    test('stableHash is pinned and independent of String.hashCode', () {
      // Canonical FNV-1a 32-bit vectors. If these change, every recorded
      // match_run becomes unreplayable — a breaking change, not a nuisance.
      expect(SeededRandomSource.stableHash(''), 0x811c9dc5);
      expect(SeededRandomSource.stableHash('a'), 0xe40c292c);
      expect(SeededRandomSource.stableHash('foobar'), 0xbf9cf968);
    });

    test('fromString is deterministic across constructions', () {
      expect(
        SeededRandomSource.fromString('osijek-2026-09-03').seed,
        SeededRandomSource.fromString('osijek-2026-09-03').seed,
      );
    });

    test('nextDouble stays inside [0, 1)', () {
      final source = SeededRandomSource(3);
      for (var i = 0; i < 500; i++) {
        final value = source.nextDouble();
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(1));
      }
    });
  });
}
