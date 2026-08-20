import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the floor', () {
    test('no style is smaller than 14.5', () {
      // The second of the two hard legibility constraints. Stated as a test
      // because "we agreed not to go below 14.5" is the kind of agreement that
      // survives exactly until a caption does not fit.
      for (final style in ZarType.all) {
        expect(
          style.fontSize,
          greaterThanOrEqualTo(ZarType.minimumSize),
          reason: '${style.fontFamily} ${style.fontSize}',
        );
      }
    });

    test('every style states its size, height and colour explicitly', () {
      // An unset height inherits the font's own metrics, which differ per
      // family — so a line of Archivo and a line of Instrument Serif set at the
      // same size would not sit on the same rhythm, and nothing would say why.
      for (final style in ZarType.all) {
        expect(style.fontSize, isNotNull);
        expect(style.height, isNotNull);
        expect(style.color, isNotNull);
        expect(style.fontWeight, isNotNull);
      }
    });
  });

  group('the three families keep to their jobs', () {
    test('the serif is used only for names', () {
      final serif = ZarType.all
          .where((s) => s.fontFamily == ZarType.packaged(ZarType.nameFamily))
          .toList();
      expect(serif, hasLength(2));
      expect(serif, contains(ZarType.personName));
      expect(serif, contains(ZarType.personNameHero));
    });

    test('the mono is used only for times, counts and codes', () {
      final mono = ZarType.all
          .where((s) => s.fontFamily == ZarType.packaged(ZarType.monoFamily))
          .toList();
      expect(mono, hasLength(2));
      expect(mono, contains(ZarType.mono));
      expect(mono, contains(ZarType.monoKey));
    });

    test('everything the app says in its own voice is Archivo', () {
      const systemVoice = [
        ZarType.title,
        ZarType.heading,
        ZarType.body,
        ZarType.bodyStrong,
        ZarType.label,
        ZarType.caption,
      ];
      for (final style in systemVoice) {
        expect(style.fontFamily, ZarType.packaged(ZarType.systemFamily));
      }
    });

    test('every style resolves against the bundled faces', () {
      // Without the package attribution a consumer app renders the fallback
      // face silently, which is the failure mode that looks like "the design
      // just came out wrong" with nothing to point at.
      for (final style in ZarType.all) {
        expect(
          style.fontFamily,
          startsWith('packages/${ZarType.fontPackage}/'),
          reason: '${style.fontSize}',
        );
      }
    });
  });

  group('the two registers', () {
    test('the serif carries sand, and nothing else does', () {
      expect(ZarType.personName.color, ZarColors.sand);
      expect(ZarType.personNameHero.color, ZarColors.sand);

      final sandStyles = ZarType.all.where((s) => s.color == ZarColors.sand);
      expect(sandStyles, hasLength(2));
    });
  });

  group('the scale is a scale', () {
    test('sizes are distinct enough to read as different', () {
      // Two styles 1px apart are not a hierarchy, they are an accident that
      // nobody can see and everybody has to maintain.
      final sizes = ZarType.all.map((s) => s.fontSize!).toSet().toList()
        ..sort();
      for (var i = 1; i < sizes.length; i++) {
        expect(
          sizes[i] - sizes[i - 1],
          greaterThanOrEqualTo(1.5),
          reason: '${sizes[i - 1]} and ${sizes[i]} are too close apart',
        );
      }
    });

    test('digits that line up in columns are tabular', () {
      for (final style in [ZarType.mono, ZarType.monoKey]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });
  });

  group('layout constants the widgets depend on', () {
    test('the hairline is 1, which Border.all already defaults to', () {
      // EkipaButton and EkipaCard omit `width:` on their borders because the
      // default already equals this token. If the token ever moves, those two
      // borders would silently keep the old value — so the coupling is a test
      // rather than a comment.
      expect(ZarLayout.hairline, 1);
    });

    test('the tap target clears the platform minimum', () {
      expect(ZarLayout.minTapTarget, greaterThanOrEqualTo(48));
      expect(
        ZarLayout.controlHeight,
        greaterThanOrEqualTo(ZarLayout.minTapTarget),
      );
    });
  });
}
