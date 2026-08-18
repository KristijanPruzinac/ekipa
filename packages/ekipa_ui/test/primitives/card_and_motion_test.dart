import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  setUpAll(loadZarFonts);

  group('EkipaCard', () {
    testWidgets('a plain card is inert and takes no taps', (tester) async {
      await tester.pumpWidget(
        harness(const Center(child: EkipaCard(child: Text('a fact')))),
      );
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('a tappable card reports itself as a button', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          Center(
            child: EkipaCard(onTap: () => taps++, child: const Text('Thu')),
          ),
        ),
      );
      await tester.tap(find.text('Thu'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('the live tone is the only one that borders in ember', (
      tester,
    ) async {
      for (final tone in EkipaCardTone.values) {
        await tester.pumpWidget(
          harness(
            Center(
              child: EkipaCard(tone: tone, child: const Text('x')),
            ),
          ),
        );
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(EkipaCard),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final border = (box.decoration as BoxDecoration).border! as Border;
        expect(
          border.top.color == ZarColors.ember,
          tone == EkipaCardTone.live,
          reason: '$tone',
        );
      }
    });

    testWidgets('no card casts a shadow', (tester) async {
      // Value separates the layers, not elevation — a drop shadow on a
      // near-black ground is either invisible or a grey smear.
      await tester.pumpWidget(
        harness(const Center(child: EkipaCard(child: Text('x')))),
      );
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(EkipaCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).boxShadow, isNull);
    });
  });

  group('Appear', () {
    testWidgets('arrives once and then holds', (tester) async {
      await tester.pumpWidget(
        harness(const Center(child: Appear(child: Text('hello')))),
      );

      double opacityAt() => tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(Appear),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;

      expect(opacityAt(), 0);
      await tester.pumpAndSettle();
      expect(opacityAt(), 1);
    });

    testWidgets('reduced motion skips the animation entirely', (tester) async {
      // Someone who asked their phone to reduce motion usually asked for a
      // medical reason. They see the end state and never a frame of movement.
      await tester.pumpWidget(
        harness(
          reduceMotion: true,
          const Center(child: Appear(child: Text('hello'))),
        ),
      );
      await tester.pump();
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(Appear),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 1);
    });

    testWidgets('staggered() numbers its children in order', (tester) async {
      await tester.pumpWidget(
        harness(
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: staggered(const [Text('a'), Text('b'), Text('c')]),
            ),
          ),
        ),
      );
      final indices = tester
          .widgetList<Appear>(find.byType(Appear))
          .map((a) => a.index)
          .toList();
      expect(indices, [0, 1, 2]);
      await tester.pumpAndSettle();
    });
  });

  group('ZarMotion', () {
    test('every duration collapses under reduced motion', () {
      for (final d in [
        ZarMotion.quick,
        ZarMotion.base,
        ZarMotion.slow,
        ZarMotion.ambient,
      ]) {
        expect(ZarMotion.scale(d, reduceMotion: true), Duration.zero);
        expect(ZarMotion.scale(d, reduceMotion: false), d);
      }
    });

    test('nothing lasts long enough to be waited on', () {
      // Motion as atmosphere, not spectacle. Anything past ~450ms stops being
      // texture and starts being a delay someone is sitting through.
      for (final d in [ZarMotion.quick, ZarMotion.base, ZarMotion.slow]) {
        expect(d.inMilliseconds, lessThanOrEqualTo(450));
      }
    });
  });
}
