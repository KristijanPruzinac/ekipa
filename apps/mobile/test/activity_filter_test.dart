import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as timezone;
import 'package:wagz_mobile/api.dart';
import 'package:wagz_mobile/discovery_widgets.dart';
import 'package:wagz_mobile/main.dart';
import 'fixtures.dart';
import 'home_assertions.dart';

Map<String, dynamic> activityFeed() => {
  ...feedJson(),
  'events': [
    {
      ...eventJson,
      'id': 'dance-late',
      'title': 'Kasniji plesnjak',
      'category': 'dance',
      'startsAt': '2026-10-05T18:00:00+02:00',
    },
    {
      ...eventJson,
      'id': 'workshop',
      'title': 'Radionica keramike',
      'category': 'workshop',
      'startsAt': '2026-10-04T15:00:00+02:00',
    },
    {
      ...eventJson,
      'id': 'dance-ongoing',
      'title': 'Plesni susret',
      'category': 'dance',
      'startsAt': '2026-10-02',
      'endsAt': '2026-10-04',
    },
    {
      ...eventJson,
      'id': 'dance-early',
      'title': 'Radionica plesne improvizacije',
      'category': 'dance',
      'startsAt': '2026-10-04T13:00:00+02:00',
    },
    {
      ...eventJson,
      'id': 'music',
      'title': 'Večernji koncert',
      'category': 'music',
      'startsAt': '2026-10-04T20:00:00+02:00',
    },
  ],
};

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    timezone.initializeTimeZones();
    await initializeDateFormatting('hr');
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'activity filters fit 320px at ${scale}x text and show cards and ongoing directly without a timeline',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final api = WagzApi(
          baseUrl: 'https://wagz.example',
          client: MockClient(
            (_) async => http.Response.bytes(
              utf8.encode(jsonEncode(activityFeed())),
              200,
            ),
          ),
        );
        addTearDown(api.close);
        await tester.pumpWidget(WagzApp(api: api));
        await tester.pumpAndSettle();
        final chips = find.byType(ChoiceChip);
        expect(chips, findsNWidgets(4));
        expect(find.text('Izdvojeno · 5'), findsOneWidget);
        expect(find.text('Ples · 3'), findsOneWidget);
        expect(find.text('Radionica · 1'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('activity-filter-sport')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('audience-students')), findsNothing);
        for (final element in chips.evaluate()) {
          final rect = tester.getRect(find.byWidget(element.widget));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
          expect(rect.height, greaterThanOrEqualTo(48));
        }

        Future<void> select(String value) async {
          final chip = find.byKey(ValueKey('activity-filter-$value'));
          if (chip.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              chip,
              -250,
              scrollable: find.byType(Scrollable).first,
            );
          }
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
          expect(
            tester
                .widgetList<ChoiceChip>(chips)
                .where((item) => item.selected)
                .length,
            1,
          );
        }

        await select('dance');
        await expectHomeCards(tester, ['dance-early', 'dance-late']);
        await tester.scrollUntilVisible(
          find.byType(OngoingEvents),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester
              .widget<OngoingEvents>(find.byType(OngoingEvents))
              .events
              .map((event) => event.id),
          ['dance-ongoing'],
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('event-card-dance-early')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester
              .widget<SliverList>(find.byType(SliverList))
              .delegate
              .estimatedChildCount,
          2,
        );
        await select('workshop');
        await expectHomeCards(tester, ['workshop']);
        expect(find.byType(OngoingEvents), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('event-card-workshop')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester
              .widget<SliverList>(find.byType(SliverList))
              .delegate
              .estimatedChildCount,
          1,
        );
        expect(
          find.byKey(const ValueKey('event-card-dance-early')),
          findsNothing,
        );
        await select('featured');
        await expectHomeCards(tester, [
          'dance-early',
          'workshop',
          'music',
          'dance-late',
        ]);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('event-card-dance-early')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester
              .widget<SliverList>(find.byType(SliverList))
              .delegate
              .estimatedChildCount,
          4,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'refresh preserves the selected activity with an explicit empty state and reset when it disappears',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var current = activityFeed();
      final api = WagzApi(
        baseUrl: 'https://wagz.example',
        client: MockClient(
          (_) async =>
              http.Response.bytes(utf8.encode(jsonEncode(current)), 200),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(WagzApp(api: api));
      await tester.pumpAndSettle();
      final dance = find.byKey(const ValueKey('activity-filter-dance'));
      await tester.ensureVisible(dance);
      await tester.tap(dance);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(dance).selected, isTrue);
      current = {
        ...current,
        'events': (current['events'] as List)
            .where((event) => event['category'] == 'workshop')
            .toList(),
      };
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(dance, findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('activity-filter-featured')),
            )
            .selected,
        isFalse,
      );
      expect(find.byType(EventTimeline), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Prikaži izdvojeno'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Nema događaja ove vrste.'), findsOneWidget);
      await tester.tap(find.text('Prikaži izdvojeno'));
      await tester.pumpAndSettle();
      await expectHomeCards(tester, ['workshop']);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('activity-filter-featured')),
            )
            .selected,
        isTrue,
      );
      expect(find.text('Izdvojeno · 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
