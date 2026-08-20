import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

DisplayName named(String first, String initial) =>
    DisplayName.create(firstName: first, lastInitial: initial).valueOrNull!;

void main() {
  setUpAll(loadZarFonts);

  testWidgets('renders the one format the product ever shows', (tester) async {
    await tester.pumpWidget(
      harness(Center(child: PersonName(named('Marko', 'n')))),
    );
    expect(find.text('Marko ····n'), findsOneWidget);
  });

  testWidgets('a screen reader is given the sayable form', (tester) async {
    // "Marko dot dot dot dot n" is noise. The mask is a visual privacy
    // affordance; it carries no information a screen reader needs to voice.
    await tester.pumpWidget(
      harness(Center(child: PersonName(named('Marko', 'n')))),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.semanticsLabel, 'Marko n');
  });

  testWidgets('names are set in the reserved register', (tester) async {
    await tester.pumpWidget(
      harness(Center(child: PersonName(named('Ana', 'ć')))),
    );
    final style = tester.widget<Text>(find.byType(Text)).style!;
    expect(style.fontFamily, ZarType.packaged(ZarType.nameFamily));
    expect(style.color, ZarColors.sand);
  });

  testWidgets('a Croatian diacritic survives as the initial', (tester) async {
    await tester.pumpWidget(
      harness(Center(child: PersonName(named('Ana', 'ć')))),
    );
    expect(find.text('Ana ····ć'), findsOneWidget);
  });

  testWidgets('a venue name shares the register but not the type', (
    tester,
  ) async {
    // Deliberately a different widget from PersonName, so no call site can
    // render a person through the venue path — which takes a raw String,
    // because venue names come from the OSM catalogue and never from a person.
    await tester.pumpWidget(
      harness(const Center(child: VenueName('Kavana Waldinger'))),
    );
    final style = tester.widget<Text>(find.byType(Text)).style!;
    expect(style.fontFamily, ZarType.packaged(ZarType.nameFamily));
    expect(find.text('Kavana Waldinger'), findsOneWidget);
  });

  testWidgets('a very long venue name is clipped, not overflowed', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const Center(
          child: SizedBox(
            width: 200,
            child: VenueName(
              'Restoran i kavana kod starog mosta na desnoj obali Drave',
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.byType(Text)).maxLines, 2);
  });
}
