import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as timezone;
import 'package:wagz_mobile/api.dart';
import 'package:wagz_mobile/discovery.dart';
import 'package:wagz_mobile/discovery_widgets.dart';
import 'package:wagz_mobile/main.dart';
import 'package:wagz_mobile/models.dart';
import 'fixtures.dart';

void main() {
  setUpAll(() async {
    timezone.initializeTimeZones();
    await initializeDateFormatting('hr');
  });

  test('film and literature have distinct readable category colors', () {
    final colors = <Color>{};
    for (final category in [
      'film',
      'literature',
      'dance',
      'workshop',
      'culture',
    ]) {
      final event = WagzEvent(
        id: category,
        title: category,
        category: category,
        startsAt: '2026-10-04',
      );
      final color = themeColor(themeForCategory(category));
      colors.add(color);
      expect(
        (eventPaper(event).computeLuminance() + 0.05) /
            (color.computeLuminance() + 0.05),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(colors.length, 5);
    expect(categoryNames['film'], 'Film');
    expect(categoryNames['literature'], 'Književnost');
  });

  testWidgets(
    '200% text on 320px phone preserves film/literature cards, details and accessible actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      final feed = {
        ...feedJson(),
        'events': [
          {
            ...eventJson,
            'id': 'film',
            'title': 'Projekcija dokumentarnog filma',
            'category': 'film',
            'startsAt': '2026-10-04T18:00:00+02:00',
            'endsAt': '2026-10-04T19:30:00+02:00',
          },
          {
            ...eventJson,
            'id': 'literature',
            'title': 'Književna večer i razgovor s autorom',
            'category': 'literature',
            'startsAt': '2026-10-05',
            'endsAt': null,
          },
        ],
      };
      final api = WagzApi(
        baseUrl: 'https://wagz.example',
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode(jsonEncode(feed)), 200),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(WagzApp(api: api));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Film · 1'), findsOneWidget);
      expect(find.text('Književnost · 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('activity-filter-workshop')),
        findsNothing,
      );

      for (final title in [
        'Projekcija dokumentarnog filma',
        'Književna večer i razgovor s autorom',
      ]) {
        await tester.scrollUntilVisible(
          find.text(title),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel(RegExp('Detalji: $title')),
          findsOneWidget,
        );
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.text('Detalji događaja'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Otvori izvornu najavu'),
          300,
          scrollable: find.byType(Scrollable).last,
          maxScrolls: 60,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
