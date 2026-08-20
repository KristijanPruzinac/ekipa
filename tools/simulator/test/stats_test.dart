import 'package:ekipa_core/ekipa_core.dart';
import 'package:simulator/simulator.dart';
import 'package:test/test.dart';

void main() {
  group('percentile', () {
    test('an empty sample is zero rather than an exception', () {
      // "Nobody ever matched" is a result the report has to be able to print.
      // Throwing here would turn the worst outcome into a crash and hide it.
      expect(Stats.percentile([], 0.5), 0);
    });

    test('a single value is itself at every quantile', () {
      expect(Stats.percentile([4], 0.5), 4);
      expect(Stats.percentile([4], 0.9), 4);
    });

    test('interpolates between neighbours', () {
      expect(Stats.percentile([0, 10], 0.5), 5);
      expect(Stats.percentile([0, 1, 2, 3, 4], 0.5), 2);
      expect(Stats.percentile([0, 1, 2, 3, 4], 0.25), 1);
    });

    test('does not care what order it was handed', () {
      expect(Stats.percentile([4, 1, 3, 2, 0], 0.5), 2);
    });
  });

  group('gini', () {
    test('everybody equal is zero', () {
      expect(Stats.gini([3, 3, 3, 3]), closeTo(0, 1e-9));
    });

    test('one person taking everything approaches one', () {
      expect(Stats.gini([0, 0, 0, 12]), closeTo(0.75, 1e-9));
      expect(
        Stats.gini([for (var i = 0; i < 99; i++) 0, 100]),
        greaterThan(0.9),
      );
    });

    test('nobody having anything is zero, not a division by zero', () {
      // The state of week zero in a city that matched nobody. A NaN here would
      // propagate silently into the JSON and poison a config comparison.
      expect(Stats.gini([0, 0, 0]), 0);
    });

    test('a sample of one is zero', () {
      expect(Stats.gini([7]), 0);
    });
  });

  group('closed triads', () {
    PairKey pair(String a, String b) => PairKey(PersonId(a), PersonId(b));

    test('a path closes nothing', () {
      expect(Stats.closedTriadShare([pair('a', 'b'), pair('b', 'c')]), 0);
    });

    test('a triangle closes all three of its edges', () {
      expect(
        Stats.closedTriadShare([
          pair('a', 'b'),
          pair('b', 'c'),
          pair('a', 'c'),
        ]),
        1,
      );
    });

    test('a triangle with a tail closes three of four', () {
      expect(
        Stats.closedTriadShare([
          pair('a', 'b'),
          pair('b', 'c'),
          pair('a', 'c'),
          pair('c', 'd'),
        ]),
        closeTo(0.75, 1e-9),
      );
    });

    test('an empty graph is zero', () {
      expect(Stats.closedTriadShare([]), 0);
    });
  });

  group('mean', () {
    test('an empty sample is zero', () {
      expect(Stats.mean([]), 0);
    });

    test('averages', () {
      expect(Stats.mean([1, 2, 3, 4]), 2.5);
    });
  });
}
