import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  setUpAll(loadZarFonts);

  testWidgets('the decision stays on screen when the body does not fit', (
    tester,
  ) async {
    // The v2 bug, fixed structurally rather than per screen: content on a short
    // viewport used to push the action off the bottom, and someone who cannot
    // see the button concludes the app is broken, not that they should scroll.
    await onSurface(tester, const Size(360, 480), () async {
      await tester.pumpWidget(
        harness(
          EkipaScreen(
            title: 'Thursday, 17:30',
            lede: 'Four people, ninety minutes, somewhere in the centre.',
            action: EkipaButton(label: "I'll be there", onPressed: () {}),
            secondaryAction: const EkipaButton(
              label: "I can't make it",
              tone: EkipaButtonTone.quiet,
              onPressed: null,
            ),
            child: Column(
              children: [
                for (var i = 0; i < 30; i++)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: ZarSpace.md),
                    child: Text('A line of body copy that takes up room.'),
                  ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.text("I'll be there"));
      expect(button.bottom, lessThanOrEqualTo(480));
      expect(button.top, greaterThanOrEqualTo(0));
    });
  });

  testWidgets('the body scrolls when it overflows', (tester) async {
    await onSurface(tester, const Size(360, 480), () async {
      await tester.pumpWidget(
        harness(
          EkipaScreen(
            title: 'Availability',
            action: EkipaButton(label: 'Save', onPressed: () {}),
            child: Column(
              children: [
                for (var i = 0; i < 40; i++) Text('Slot $i'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Slot 0'), findsOneWidget);
      await tester.drag(find.text('Slot 0'), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('Slot 39'), findsOneWidget);
      // Still there, after all that scrolling.
      expect(find.text('Save'), findsOneWidget);
    });
  });

  testWidgets('a tall viewport does not stretch the content sideways', (
    tester,
  ) async {
    // A foldable or a tablet would otherwise run every paragraph to the glass,
    // which loses the reader between lines.
    await onSurface(tester, const Size(1200, 900), () async {
      await tester.pumpWidget(
        harness(const EkipaScreen(title: 'Wide', child: Text('body'))),
      );

      final width = tester.getSize(find.text('Wide')).width;
      expect(width, lessThanOrEqualTo(ZarLayout.maxContentWidth));
    });
  });

  testWidgets('a screen without an action has no footer', (tester) async {
    await tester.pumpWidget(
      harness(const EkipaScreen(title: 'Reading', child: Text('body'))),
    );
    expect(find.byType(EkipaButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('title and lede use the scale, not ad-hoc styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const EkipaScreen(
          title: 'Thursday, 17:30',
          lede: 'Four people.',
          child: SizedBox.shrink(),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Thursday, 17:30')).style,
      ZarType.title,
    );
    expect(
      tester.widget<Text>(find.text('Four people.')).style!.fontSize,
      ZarType.body.fontSize,
    );
  });

  testWidgets('it holds at 200% text scale on a small phone', (tester) async {
    await onSurface(tester, const Size(320, 568), () async {
      await tester.pumpWidget(
        harness(
          textScale: 2,
          EkipaScreen(
            title: 'Confirm tonight',
            lede: 'Say yes now and the group is locked.',
            action: EkipaButton(label: "I'll be there", onPressed: () {}),
            child: const Text('Meeting point is a five minute walk.'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
