import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  setUpAll(loadZarFonts);

  testWidgets('a primary button calls back once per tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      harness(
        Center(
          child: EkipaButton(label: "I'll be there", onPressed: () => taps++),
        ),
      ),
    );

    await tester.tap(find.text("I'll be there"));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('a null callback disables it', (tester) async {
    await tester.pumpWidget(
      harness(
        const Center(child: EkipaButton(label: 'Confirm', onPressed: null)),
      ),
    );

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // A disabled control announces itself as a button that cannot be used —
    // not as inert text. Someone on a screen reader needs to know the decision
    // exists and is not available yet, which is the same thing the sighted
    // treatment says by keeping the words readable.
    expect(
      tester.getSemantics(find.byType(EkipaButton)),
      matchesSemantics(label: 'Confirm', isButton: true, hasEnabledState: true),
    );
  });

  testWidgets('a screen reader hears the label once, not twice', (
    tester,
  ) async {
    // Regression: the press wrapper and the label both used to publish
    // semantics, so the button announced "Confirm, Confirm". Invisible to
    // everyone who does not depend on it, which is why it needs a test.
    await tester.pumpWidget(
      harness(
        Center(
          child: EkipaButton(label: 'Confirm', onPressed: () {}),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(EkipaButton)).label,
      'Confirm',
    );
  });

  testWidgets('a busy button refuses a second tap', (tester) async {
    // Every action in this product is a write with a consequence. A double tap
    // on "I've arrived" is a duplicate the server would have to defend against;
    // it is cheaper to make it impossible here.
    var taps = 0;
    await tester.pumpWidget(
      harness(
        Center(
          child: EkipaButton(
            label: 'Confirm',
            busy: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(EkipaButton));
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('a disabled button keeps its words readable', (tester) async {
    await tester.pumpWidget(
      harness(
        const Center(child: EkipaButton(label: 'Confirm', onPressed: null)),
      ),
    );

    final style = tester.widget<Text>(find.text('Confirm')).style!;
    expect(style.color, ZarColors.inkFaint);
    // Not ghosted away: the same colour the contrast test holds to AA.
    expect(style.color, isNot(ZarColors.hairline));
  });

  testWidgets('every tone meets the minimum tap target', (tester) async {
    for (final tone in EkipaButtonTone.values) {
      await tester.pumpWidget(
        harness(
          Center(
            child: EkipaButton(label: 'Ok', tone: tone, onPressed: () {}),
          ),
        ),
      );
      final size = tester.getSize(find.byType(EkipaButton));
      expect(size.height, greaterThanOrEqualTo(ZarLayout.minTapTarget));
      expect(size.width, greaterThanOrEqualTo(ZarLayout.minTapTarget));
    }
  });

  testWidgets('only the primary tone is filled', (tester) async {
    // "Which one is the answer" must never be a reading exercise.
    Color? fillOf(EkipaButtonTone tone) {
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EkipaButton),
          matching: find.byType(Container),
        ),
      );
      return (container.decoration! as BoxDecoration).color;
    }

    await tester.pumpWidget(
      harness(
        Center(
          child: EkipaButton(label: 'Yes', onPressed: () {}),
        ),
      ),
    );
    expect(fillOf(EkipaButtonTone.primary), ZarColors.ember);

    for (final tone in [EkipaButtonTone.secondary, EkipaButtonTone.quiet]) {
      await tester.pumpWidget(
        harness(
          Center(
            child: EkipaButton(label: 'No', tone: tone, onPressed: () {}),
          ),
        ),
      );
      expect(fillOf(tone), isNull, reason: '$tone must not be filled');
    }
  });

  testWidgets('a long label wraps rather than overflowing', (tester) async {
    await tester.pumpWidget(
      harness(
        Center(
          child: SizedBox(
            width: 200,
            child: EkipaButton(
              label: 'I can make it, but I might be a few minutes late',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('it survives 200% text scale', (tester) async {
    // Dynamic type is a P0 requirement (09_OPEN_QUESTIONS.md G8), and a control
    // that clips its own label at the accessibility sizes is a control that
    // cannot be used by the people who need it most.
    await tester.pumpWidget(
      harness(
        textScale: 2,
        Center(
          child: EkipaButton(label: "I'll be there", onPressed: () {}),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text("I'll be there"), findsOneWidget);
  });
}
