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
  const dance = WagzEvent(
    id: 'dance',
    title: 'Radionica plesne improvizacije',
    category: 'dance',
    startsAt: '2026-10-04T10:00:00+02:00',
    endsAt: '2026-10-04T12:00:00+02:00',
  );
  const workshop = WagzEvent(
    id: 'workshop',
    title: 'Radionica keramike',
    category: 'workshop',
    startsAt: '2026-10-04T11:00:00+02:00',
    endsAt: '2026-10-04T13:00:00+02:00',
  );

  test(
    'dance workshops retain dance motif and both labels with contrasting distinct colors',
    () {
      expect(themeForCategory(dance.category), DiscoveryTheme.dance);
      expect(themeForCategory(workshop.category), DiscoveryTheme.workshop);
      expect(eventCategoryLabel(dance), 'Ples · Radionica');
      expect(eventCategoryLabel(workshop), 'Radionica');
      expect(
        eventCategoryLabel(
          const WagzEvent(
            id: 'social',
            title: 'Plesnjak',
            category: 'dance',
            startsAt: '2026-10-04',
            description: 'Poslije slijedi radionica za zainteresirane.',
          ),
        ),
        'Ples',
      );
      expect(
        eventCategoryLabel(
          const WagzEvent(
            id: 'festival',
            title: 'Festival plesa',
            category: 'dance',
            startsAt: '2026-10-04',
            description: 'Radionica je dio šireg programa.',
          ),
        ),
        'Ples',
      );
      expect(
        eventCategoryLabel(
          const WagzEvent(
            id: 'lesson',
            title: 'Bachata za početnike',
            category: 'dance',
            startsAt: '2026-10-04',
            description: 'Plesna radionica za početnike.',
          ),
        ),
        'Ples · Radionica',
      );
      expect(
        themeColor(DiscoveryTheme.dance),
        isNot(themeColor(DiscoveryTheme.workshop)),
      );
      for (final event in [dance, workshop]) {
        final foreground = themeColor(
          themeForCategory(event.category),
        ).computeLuminance();
        final background = eventPaper(event).computeLuminance();
        expect(
          (background + 0.05) / (foreground + 0.05),
          greaterThanOrEqualTo(4.5),
        );
      }
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('five-category timeline legend fits 320px at ${scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 900),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: EventTimeline(
                  events: const [dance, workshop],
                  now: '2026-10-03T10:00:00Z',
                  onOpen: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('timeline-toggle')));
      await tester.pumpAndSettle();
      for (final label in [
        'Izlasci',
        'Ples',
        'Radionice',
        'Kultura',
        'Druženje',
      ]) {
        expect(find.text(label), findsOneWidget);
        final rect = tester.getRect(find.text(label));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      expect(find.text('Ples · Radionica'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    '320px dance and workshop cards open details with matching labels',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final feed = {
        ...feedJson(),
        'events': [
          {
            ...eventJson,
            'id': 'dance',
            'title': dance.title,
            'category': 'dance',
            'startsAt': dance.startsAt,
            'endsAt': dance.endsAt,
            'discovery': null,
          },
          {
            ...eventJson,
            'id': 'workshop',
            'title': workshop.title,
            'category': 'workshop',
            'startsAt': workshop.startsAt,
            'endsAt': workshop.endsAt,
            'discovery': null,
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
      for (final entry in {
        'dance': 'PLES · RADIONICA',
        'workshop': 'RADIONICA',
      }.entries) {
        final card = find.byKey(ValueKey('event-card-${entry.key}'));
        await tester.scrollUntilVisible(
          card,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: card, matching: find.text(entry.value)),
          findsOneWidget,
        );
        final motif = tester.widget<EventMotif>(
          find.descendant(of: card, matching: find.byType(EventMotif)),
        );
        expect(
          motif.theme,
          entry.key == 'dance' ? DiscoveryTheme.dance : DiscoveryTheme.workshop,
        );
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );
}
