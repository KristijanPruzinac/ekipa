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
import 'home_assertions.dart';

const sourceUrl = 'https://example.org/screening';
Map<String, dynamic> screeningEvent(
  String id,
  String title, {
  String? kind,
  String city = 'Osijek',
  String category = 'film',
}) => {
  ...eventJson,
  'id': id,
  'title': title,
  'category': category,
  'city': city,
  'startsAt': '2026-10-04T18:00:00+02:00',
  'sources': [
    {'sourceName': 'Organizator', 'url': sourceUrl},
  ],
  'discovery': {
    'audiences': [],
    'audienceEvidence': [],
    'prominence': null,
    'free': false,
    if (kind != null)
      'screening': {
        'kind': kind,
        'reason': 'Izvor potvrđuje kontekst projekcije.',
        'sourceUrl': sourceUrl,
      },
  },
};

void main() {
  setUpAll(() async {
    timezone.initializeTimeZones();
    await initializeDateFormatting('hr');
  });

  test(
    'Featured is city-agnostic and retains special, absent, malformed and unverified evidence',
    () {
      for (final city in ['Osijek', 'Zagreb', 'Rijeka']) {
        expect(
          isFeaturedEvent(
            WagzEvent.fromJson(
              screeningEvent(
                'routine',
                'Filmska projekcija',
                kind: 'routine',
                city: city,
              ),
            ),
          ),
          isFalse,
        );
        expect(
          isFeaturedEvent(
            WagzEvent.fromJson(
              screeningEvent(
                'other',
                'Susret',
                kind: 'routine',
                city: city,
                category: 'other',
              ),
            ),
          ),
          isTrue,
        );
      }
      for (final title in [
        'Kino na otvorenom',
        'Rooftop projekcija',
        'Film uz razgovor s autorom',
      ]) {
        expect(
          isFeaturedEvent(
            WagzEvent.fromJson(
              screeningEvent('special', title, kind: 'special'),
            ),
          ),
          isTrue,
        );
        expect(
          isFeaturedEvent(WagzEvent.fromJson(screeningEvent('unknown', title))),
          isTrue,
        );
      }
      for (final evidence in [
        null,
        {},
        {'kind': 'routine'},
        {'kind': 'routine', 'reason': 42, 'sourceUrl': sourceUrl},
        {'kind': 'routine', 'reason': '', 'sourceUrl': sourceUrl},
        {
          'kind': 'routine',
          'reason': 'Program',
          'sourceUrl': 'https://example.org/unrelated',
        },
        {
          'kind': 'routine',
          'reason': 'Program',
          'sourceUrl': 'javascript:alert(1)',
        },
      ]) {
        final event = screeningEvent('unknown', 'Filmska projekcija');
        (event['discovery'] as Map<String, dynamic>)['screening'] = evidence;
        expect(isFeaturedEvent(WagzEvent.fromJson(event)), isTrue);
      }
    },
  );

  testWidgets(
    'Featured and Film retain their own counts, route selection and empty reset',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final routine = screeningEvent(
        'routine',
        'Redovni kino termin',
        kind: 'routine',
        city: 'Zagreb',
      );
      var current = {
        ...feedJson(),
        'events': [
          routine,
          screeningEvent('outdoor', 'Kino na otvorenom', kind: 'special'),
          screeningEvent(
            'rooftop',
            'Rooftop filmska večer',
            kind: 'special',
            city: 'Zagreb',
          ),
          screeningEvent('unknown', 'Projekcija bez potvrđenog konteksta'),
          screeningEvent('other', 'Susret u susjedstvu', category: 'other'),
        ],
      };
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
      expect(find.text('Izdvojeno · 4'), findsOneWidget);
      expect(find.text('Film · 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-filter-other')), findsNothing);
      await expectHomeCards(tester, ['outdoor', 'rooftop', 'unknown', 'other']);
      Future<void> select(String id) async {
        final chip = find.byKey(ValueKey('activity-filter-$id'));
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }

      await select('film');
      await expectHomeCards(tester, [
        'routine',
        'outdoor',
        'rooftop',
        'unknown',
      ]);
      final card = find.byKey(const ValueKey('event-card-routine'));
      await tester.scrollUntilVisible(
        card,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Detalji događaja'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('activity-filter-film')),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('activity-filter-film')),
            )
            .selected,
        isTrue,
      );
      await select('featured');
      current = {
        ...current,
        'events': [routine],
      };
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(find.text('Izdvojeno · 0'), findsOneWidget);
      expect(find.byType(EventTimeline), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Prikaži filmove'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Prikaži filmove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prikaži filmove'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('activity-filter-film')),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await expectHomeCards(tester, ['routine']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
