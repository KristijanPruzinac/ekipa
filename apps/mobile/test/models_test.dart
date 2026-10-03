import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as timezone;
import 'package:wagz_mobile/models.dart';
import 'package:wagz_mobile/discovery.dart';
import 'fixtures.dart';

void main() {
  setUpAll(() async {
    timezone.initializeTimeZones();
    await initializeDateFormatting('hr');
  });

  test('optional discovery is compatible with older backend responses', () {
    final event = WagzEvent.fromJson({...eventJson, 'discovery': null});
    expect(event.discovery.audienceEvidence, isEmpty);
    expect(event.price, isNull);
    expect(event.venue, 'Kampus Osijek');
  });

  test('Osijek time handles midnight, DST and date-only unknown time', () {
    expect(formatTime('2026-10-03T23:30:00Z'), '01:30');
    expect(dayOnly('2026-10-03T23:30:00Z'), DateTime.utc(2026, 10, 4));
    expect(formatTime('2026-10-25T00:30:00Z'), '02:30');
    expect(formatTime('2026-10-25T01:30:00Z'), '02:30');
    expect(formatTime('2026-10-03'), 'Vrijeme nije navedeno');
    expect(dayOnly('2026-10-03'), DateTime.utc(2026, 10, 3));
  });

  test('date filters include spanning events and Friday through Sunday', () {
    const sunday = '2026-10-04T12:00:00Z';
    const spanning = WagzEvent(
      id: '1',
      title: 'Izložba',
      startsAt: '2026-10-02',
      endsAt: '2026-10-06',
    );
    const monday = WagzEvent(id: '2', title: 'Koncert', startsAt: '2026-10-05');
    const friday = WagzEvent(id: '3', title: 'Koncert', startsAt: '2026-10-02');
    expect(inDateFilter(spanning, DateFilter.today, sunday), isTrue);
    expect(inDateFilter(friday, DateFilter.weekend, sunday), isTrue);
    expect(inDateFilter(monday, DateFilter.weekend, sunday), isFalse);
    expect(inDateFilter(monday, DateFilter.week, sunday), isFalse);
  });

  test(
    'source labels require matching evidence and ignore genres, free entry and bare audiences',
    () {
      final student = WagzEvent.fromJson(eventJson);
      expect(sourceAudienceLabels(student), ['Studenti']);
      WagzEvent example(
        List<Map<String, String>> evidence, {
        String source = 'https://example.org/koncert',
      }) => WagzEvent.fromJson({
        ...eventJson,
        'sources': [
          {'sourceName': 'Organizator', 'url': source},
        ],
        'discovery': {
          'audiences': ['students'],
          'free': true,
          'audienceEvidence': evidence,
        },
      });
      final valid = {
        'audience': 'students',
        'reason': 'Studentski popust.',
        'sourceUrl': 'https://example.org/koncert',
      };
      expect(
        sourceAudienceLabels(
          example([
            {...valid, 'audience': 'seniors'},
            valid,
            valid,
          ]),
        ),
        ['Studenti', 'Stariji'],
      );
      expect(sourceAudienceLabels(example([])), isEmpty);
      for (final invalid in [
        {...valid, 'reason': ' '},
        {...valid, 'audience': 'unknown'},
        {...valid, 'sourceUrl': 'https://other.example/event'},
      ]) {
        expect(sourceAudienceLabels(example([invalid])), isEmpty);
      }
      for (final url in [
        'javascript:alert(1)',
        'https://user:password@example.org/event',
        'https://example.invalid/event',
      ]) {
        expect(
          sourceAudienceLabels(
            example([
              {...valid, 'sourceUrl': url},
            ], source: url),
          ),
          isEmpty,
        );
      }
      for (final audience in ['all', 'students', 'adults', 'seniors']) {
        expect(
          rankForAudience(
            PublicFeed.fromJson(feedJson()).events,
            audience: audience,
          ).map((row) => row.event.id),
          ['theatre', 'student-concert'],
        );
      }
    },
  );

  test('source links reject executable schemes and credentials', () {
    expect(safeLink('javascript:alert(1)'), isNull);
    expect(safeLink('https://user:password@example.org'), isNull);
    expect(safeLink('https://example.invalid'), isNull);
    expect(safeLink('https://example.org/event'), isNotNull);
    expect(normalize('Šećer Čepin Đakovo'), 'secer cepin dakovo');
  });
}
