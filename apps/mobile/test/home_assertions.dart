import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wagz_mobile/discovery_widgets.dart';

Future<void> expectHomeCards(WidgetTester tester, List<String> ids) async {
  expect(find.byType(EventTimeline), findsNothing);
  expect(find.byKey(const ValueKey('timeline-toggle')), findsNothing);
  final scrollable = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  var previousTop = -1.0;
  for (final id in ids) {
    final card = find.byKey(ValueKey('event-card-$id'));
    await tester.scrollUntilVisible(card, 180, scrollable: scrollable);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    final top =
        tester.getTopLeft(card).dy +
        tester.state<ScrollableState>(scrollable).position.pixels;
    expect(
      top,
      greaterThan(previousTop),
      reason: 'Cards retain chronological order',
    );
    previousTop = top;
    expect(
      find.descendant(of: card, matching: find.text('Detalji')),
      findsOneWidget,
    );
  }
  expect(
    tester
        .widget<SliverList>(find.byType(SliverList))
        .delegate
        .estimatedChildCount,
    ids.length,
  );
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
}
