import 'package:ekipa_core/src/foundation/random_source.dart';

/// A [RandomSource] that returns a scripted sequence.
///
/// **Intention.** The ring draw (`docs/v3/03_MATCHMAKER.md` §⑤) branches on a
/// single uniform roll: below `A` draw from R1, below `A + B` draw from R2,
/// otherwise a stranger. Testing "a roll of 0.1 with A = 0.25 selects R1" needs
/// a roll of exactly 0.1, not a seed that happens to produce one — otherwise
/// the test documents a seed rather than the rule, and re-tuning the ratio
/// silently invalidates it.
///
/// Seeded sources stay the right tool for property and golden tests; this one
/// is for pinning a specific branch.
final class ScriptedRandomSource implements RandomSource {
  /// Replays [doubles] and [ints] in order.
  ScriptedRandomSource({
    List<double> doubles = const [],
    List<int> ints = const [],
  }) : _doubles = List.of(doubles),
       _ints = List.of(ints);

  final List<double> _doubles;
  final List<int> _ints;
  int _doubleCursor = 0;
  int _intCursor = 0;

  /// Values drawn so far, for asserting a stage consumed what was expected.
  int get drawCount => _doubleCursor + _intCursor;

  @override
  double nextDouble() {
    if (_doubleCursor >= _doubles.length) {
      throw StateError(
        'ScriptedRandomSource exhausted after $_doubleCursor doubles. '
        'The code under test drew more randomness than the script supplies, '
        'which usually means a stage changed how many draws it makes.',
      );
    }
    return _doubles[_doubleCursor++];
  }

  @override
  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'must be positive');
    }
    if (_intCursor >= _ints.length) {
      throw StateError(
        'ScriptedRandomSource exhausted after $_intCursor ints. '
        'The code under test drew more randomness than the script supplies.',
      );
    }
    return _ints[_intCursor++] % max;
  }

  /// Returns this same source, so a forked stage replays the same script.
  @override
  RandomSource fork(String label) => this;
}
