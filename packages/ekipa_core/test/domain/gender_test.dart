import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

import '../support/world.dart';

void main() {
  group('Gender is a registry code, not a closed set', () {
    test('two codes are equal exactly when the strings are', () {
      expect(const Gender('woman'), const Gender('woman'));
      expect(const Gender('woman'), isNot(const Gender('man')));
    });

    test('a value nobody anticipated works like any other', () {
      // The point of the registry: adding a gender is a row, not a migration of
      // every switch in the codebase (D6).
      final mix = GenderMix(const [
        Gender('nonbinary'),
        Gender('nonbinary'),
        Gender('man'),
        Gender('man'),
      ]);
      expect(mix.hasLoneGender, isFalse);
      expect(mix.countOf(const Gender('nonbinary')), 2);
    });
  });

  group('the composition invariant, at every group size', () {
    // Invariant 1 of 03_MATCHMAKER.md §⑥. It has to hold at 3 and at 4, which
    // is what makes it survive the backfill case a "2+2 or 4-same" rule cannot
    // express.

    test('2+2 is fine', () {
      expect(GenderMix(const [woman, woman, man, man]).hasLoneGender, isFalse);
    });

    test('four of one gender is fine', () {
      expect(GenderMix(const [man, man, man, man]).hasLoneGender, isFalse);
    });

    test('three of one gender plus one is not', () {
      final mix = GenderMix(const [woman, woman, woman, man]);
      expect(mix.hasLoneGender, isTrue);
      expect(mix.loneGenders, [man]);
    });

    test('a three of the same gender is fine', () {
      expect(GenderMix(const [woman, woman, woman]).hasLoneGender, isFalse);
    });

    test('the 2+1 a backfill produces is not', () {
      // The exact case the invariant exists for: a 2+2 that loses one woman is
      // 1W + 2M, and the honest response is to cancel rather than to run it.
      final mix = GenderMix(const [woman, man, man]);
      expect(mix.hasLoneGender, isTrue);
      expect(mix.loneGenders, [woman]);
    });

    test('one person alone is not a violation', () {
      // Degenerate, and deliberately allowed: the rule is about being
      // outnumbered alone in a room, and there is no room.
      expect(GenderMix(const [woman]).hasLoneGender, isFalse);
    });

    test('three different genders is three violations', () {
      final mix = GenderMix(const [woman, man, other]);
      expect(mix.hasLoneGender, isTrue);
      expect(mix.loneGenders, hasLength(3));
    });
  });
}
