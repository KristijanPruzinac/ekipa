import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as timezone;
import 'package:wagz_mobile/api.dart';
import 'package:wagz_mobile/main.dart';
import 'fixtures.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    timezone.initializeTimeZones();
    await initializeDateFormatting('hr');
  });

  testWidgets(
    'narrow phone cards show directly, details and tip submission work',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? tip;
      final api = WagzApi(
        baseUrl: 'https://wagz.example',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            tip = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{"ok":true}', 201);
          }
          return http.Response.bytes(utf8.encode(jsonEncode(feedJson())), 200);
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(WagzApp(api: api));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('event-timeline')), findsNothing);
      expect(find.byKey(const ValueKey('timeline-toggle')), findsNothing);
      final card = find.byKey(const ValueKey('event-card-student-concert'));
      await tester.scrollUntilVisible(
        card,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Tvoj radar'), findsNothing);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Detalji događaja'), findsOneWidget);
      expect(find.textContaining('20:00'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Organizator'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Otvori izvornu najavu'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dojavi događaj'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Koncert sutra u Osijeku',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'https://example.org/najava',
      );
      await tester.scrollUntilVisible(
        find.text('Pošalji dojavu'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Pošalji dojavu'));
      await tester.pumpAndSettle();
      expect(find.text('Dobra dojava.\nHvala!'), findsOneWidget);
      expect(tip?['note'], 'Koncert sutra u Osijeku');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'foreground refresh moves real start/end boundaries, pauses in background and keeps last feed on failure',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var requests = 0;
      var fail = false;
      var current = <String, dynamic>{
        ...feedJson(),
        'events': [
          {
            ...eventJson,
            'id': 'timed',
            'title': 'Kratki program',
            'startsAt': '2026-10-03T12:01:00Z',
            'endsAt': '2026-10-03T12:02:00Z',
          },
        ],
        'meta': {...(feedJson()['meta'] as Map), 'now': '2026-10-03T12:00:30Z'},
      };
      final api = WagzApi(
        baseUrl: 'https://wagz.example',
        client: MockClient((_) async {
          requests++;
          return fail
              ? http.Response('{"error":"Test outage"}', 503)
              : http.Response.bytes(utf8.encode(jsonEncode(current)), 200);
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(WagzApp(api: api));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('event-card-timed')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('ongoing-event-timed')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('event-card-timed')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('event-card-timed')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail-ongoing')), findsNothing);
      current = {
        ...current,
        'meta': {...(current['meta'] as Map), 'now': '2026-10-03T12:01:30Z'},
      };
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail-ongoing')), findsOneWidget);
      expect(find.text('U tijeku'), findsOneWidget);
      expect(find.text('Danas do 14:02'), findsOneWidget);
      fail = true;
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail-ongoing')), findsOneWidget);
      fail = false;
      current = {
        ...current,
        'events': [],
        'meta': {...(current['meta'] as Map), 'now': '2026-10-03T12:02:00Z'},
      };
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ongoing-event-timed')), findsNothing);
      expect(find.text('Detalji događaja'), findsNothing);
      final beforePause = requests;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 120));
      await tester.pumpAndSettle();
      expect(requests, beforePause);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(requests, beforePause + 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'activity labels and source details remain without audience tags or profile controls',
    (tester) async {
      final api = WagzApi(
        baseUrl: 'https://wagz.example',
        client: MockClient(
          (_) async =>
              http.Response.bytes(utf8.encode(jsonEncode(feedJson())), 200),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(WagzApp(api: api));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('audience-students')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('event-card-theatre')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('audience-label-theatre')),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('event-card-student-concert')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('audience-label-student-concert')),
        findsNothing,
      );
      expect(find.text('Studenti'), findsNothing);
      expect(find.text('GLAZBA'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('event-card-student-concert')),
      );
      await tester.tap(
        find.byKey(const ValueKey('event-card-student-concert')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Otvori izvornu najavu'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Organizator izričito poziva studente.'), findsNothing);
      expect(find.textContaining('Publika navedena u najavi'), findsNothing);
      expect(find.text('Organizator'), findsOneWidget);
      expect(find.text('Koncert u dvorištu kampusa.'), findsOneWidget);
      expect(find.textContaining('Prijedlog za tebe'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed tip keeps entered text available for retry', (
    tester,
  ) async {
    final api = WagzApi(
      baseUrl: 'https://wagz.example',
      client: MockClient(
        (request) async => request.method == 'POST'
            ? http.Response('{"error":"Pokusaj kasnije."}', 429)
            : http.Response.bytes(utf8.encode(jsonEncode(feedJson())), 200),
      ),
    );
    addTearDown(api.close);
    await tester.pumpWidget(WagzApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dojavi događaj'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Dobra dojava ostaje ovdje',
    );
    await tester.scrollUntilVisible(
      find.text('Pošalji dojavu'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Pošalji dojavu'));
    await tester.pumpAndSettle();
    expect(find.text('Pokusaj kasnije.'), findsOneWidget);
    expect(find.text('Dobra dojava ostaje ovdje'), findsOneWidget);
    expect(find.text('Dobra dojava.\nHvala!'), findsNothing);
  });
}
