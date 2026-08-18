import 'dart:math' as math;

/// A source of randomness that is reproducible from a seed.
///
/// **Intention.** The matchmaker's contract is that the same snapshot plus the
/// same seed produces a byte-identical plan (`docs/v3/01_ARCHITECTURE.md` §8).
/// That is the only reason a match run can be replayed to answer "why was I put
/// in that group?" months later, and the only reason a golden test of the
/// matcher means anything.
///
/// **Rejected — `math.Random()` unseeded.** Reproducibility gone, goldens
/// impossible, and a matcher nobody can replay is a matcher nobody can debug.
abstract interface class RandomSource {
  /// A uniform integer in `[0, max)`. [max] must be positive.
  int nextInt(int max);

  /// A uniform double in `[0, 1)`.
  double nextDouble();

  /// A child stream, deterministically derived from this one and [label].
  ///
  /// **Why forking rather than sharing one stream.** Pipeline stages that draw
  /// from a single shared generator are coupled through it: adding one draw in
  /// seed selection silently shifts every subsequent ring draw, and a golden
  /// test that was passing fails for a reason unrelated to the change. Forked
  /// streams make each stage's randomness independent, so a diff in stage ⑤
  /// cannot move stage ⑥.
  RandomSource fork(String label);
}

/// The default [RandomSource]: a seeded PRNG with deterministic forking.
final class SeededRandomSource implements RandomSource {
  /// Creates a source from a numeric [seed].
  SeededRandomSource(this.seed) : _random = math.Random(seed);

  /// Creates a source from a textual [seed], hashed stably.
  factory SeededRandomSource.fromString(String seed) =>
      SeededRandomSource(stableHash(seed));

  /// The seed this source was created from. Recorded on every `match_run`.
  final int seed;

  final math.Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  double nextDouble() => _random.nextDouble();

  @override
  RandomSource fork(String label) =>
      SeededRandomSource(_mix(seed, stableHash(label)));

  /// FNV-1a, 32-bit.
  ///
  /// **Why not `String.hashCode`.** Dart does not guarantee that
  /// `String.hashCode` is stable across isolates, releases, or platforms, and
  /// on some backends it is deliberately randomised. A fork keyed on it would
  /// produce a different plan in CI than on a laptop, which is precisely the
  /// property this whole class exists to prevent — and it would fail
  /// *silently*, as a golden that only breaks sometimes.
  static int stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static int _mix(int a, int b) {
    var h = (a ^ b) & 0xFFFFFFFF;
    h = (h ^ (h >> 16)) & 0xFFFFFFFF;
    h = (h * 0x7feb352d) & 0xFFFFFFFF;
    h = (h ^ (h >> 15)) & 0xFFFFFFFF;
    h = (h * 0x846ca68b) & 0xFFFFFFFF;
    return (h ^ (h >> 16)) & 0xFFFFFFFF;
  }
}
