import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  setUpAll(loadZarFonts);

  const facts = [
    Fact('When', 'Thu 17:30'),
    Fact('Where', 'Centre'),
    Fact('Who', '4 people'),
  ];

  testWidgets('keys are set in caps and values in mono', (tester) async {
    await tester.pumpWidget(harness(const Center(child: FactStrip(facts))));

    expect(find.text('WHEN'), findsOneWidget);
    expect(find.text('Thu 17:30'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Thu 17:30')).style!.fontFamily,
      ZarType.packaged(ZarType.monoFamily),
    );
  });

  testWidgets('a state colour reaches the value, never the key', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const Center(
          child: FactStrip([Fact('Status', 'Confirmed', tone: ZarColors.mint)]),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('Confirmed')).style!.color,
      ZarColors.mint,
    );
    expect(
      tester.widget<Text>(find.text('STATUS')).style!.color,
      ZarColors.inkMuted,
    );
  });

  testWidgets('each fact is one semantics node with a key and a value', (
    tester,
  ) async {
    await tester.pumpWidget(harness(const Center(child: FactStrip(facts))));
    final node = tester.getSemantics(find.text('Thu 17:30').first);
    expect(node.label, 'When');
    expect(node.value, 'Thu 17:30');
  });

  testWidgets('three facts fit across a narrow phone', (tester) async {
    await onSurface(tester, const Size(320, 568), () async {
      await tester.pumpWidget(
        harness(
          const Padding(
            padding: EdgeInsets.all(ZarSpace.xl),
            child: FactStrip(facts),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('at large text scale it stacks rather than ellipsising', (
    tester,
  ) async {
    // A fact that has been cut off is not a fact. Below the threshold it is a
    // row; above it, a column — because the alternative is "Thu 17…" on the one
    // screen someone reads while deciding whether they can make it.
    //
    // The strip measures real space rather than reacting to scale alone (see
    // the class comment on `FactStrip`), so this has to give it real space to
    // measure: `harness` alone renders on the 800-wide default test surface,
    // where three short facts still fit even doubled. The narrow phone from
    // "three facts fit" above is what actually runs out of room.
    await onSurface(tester, const Size(320, 568), () async {
      await tester.pumpWidget(
        harness(
          textScale: 2,
          const Padding(
            padding: EdgeInsets.all(ZarSpace.xl),
            child: FactStrip(facts),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Row), findsNothing);
    });
  });
}
