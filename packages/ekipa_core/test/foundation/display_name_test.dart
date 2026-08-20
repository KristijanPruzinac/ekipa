import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

void main() {
  group('DisplayName', () {
    DisplayName build(String first, String initial) =>
        DisplayName.create(firstName: first, lastInitial: initial).valueOrNull!;

    test('renders first name, mask, and final surname letter', () {
      expect(build('Marko', 'n').masked, 'Marko ····n');
    });

    test('mask length is fixed, so it never leaks surname length', () {
      final short = build('Ana', 'c').masked;
      final long = build('Dora', 'z').masked;
      expect(short.split(' ')[1].length, long.split(' ')[1].length);
    });

    test('preserves Croatian diacritics in both parts', () {
      final name = build('Šime', 'ć');
      expect(name.firstName, 'Šime');
      expect(name.lastInitial, 'ć');
      expect(name.masked.endsWith('ć'), isTrue);
    });

    test('trims surrounding whitespace', () {
      expect(build('  Luka  ', ' p ').masked, 'Luka ····p');
    });

    test('rejects an empty or whitespace-only first name', () {
      expect(
        DisplayName.create(firstName: '', lastInitial: 'a').errorOrNull,
        DisplayNameError.emptyFirstName,
      );
      expect(
        DisplayName.create(firstName: '   ', lastInitial: 'a').errorOrNull,
        DisplayNameError.emptyFirstName,
      );
    });

    test('rejects a last initial that is not exactly one character', () {
      expect(
        DisplayName.create(firstName: 'Marko', lastInitial: '').errorOrNull,
        DisplayNameError.invalidLastInitial,
      );
      expect(
        DisplayName.create(firstName: 'Marko', lastInitial: 'ic').errorOrNull,
        DisplayNameError.invalidLastInitial,
      );
    });

    test('counts a multi-code-unit grapheme as one character', () {
      // Guards against a naive `length != 1`, which counts UTF-16 code units
      // and would reject a valid astral-plane initial as if it were two letters
      // — surfacing to the person as an unexplainable signup failure.
      final result = DisplayName.create(
        firstName: 'Iva',
        lastInitial: '\u{1D51E}',
      );
      expect(result.isOk, isTrue);
    });

    test('equality is by value', () {
      expect(build('Marko', 'n'), build('Marko', 'n'));
      expect(build('Marko', 'n'), isNot(build('Marko', 'c')));
    });
  });
}
