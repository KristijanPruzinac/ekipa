import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as timezone;
import 'package:wagz_mobile/models.dart';
import 'package:wagz_mobile/discovery.dart';
import 'package:wagz_mobile/preferences.dart';
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
    'source evidence outranks transparent recommendations and ignores legacy interests',
    () {
      final student = WagzEvent.fromJson(eventJson);
      const students = DiscoveryProfile(audience: 'students');
      expect(recommendation(student, students).score, 102);
      expect(recommendation(student, students).kind, 'source');
      expect(
        recommendation(
          student,
          const DiscoveryProfile(audience: 'seniors'),
        ).score,
        1,
      );
      expect(
        recommendation(
          student,
          const DiscoveryProfile(interests: ['music']),
        ).score,
        0,
      );
      expect(
        recommendation(
          student,
          const DiscoveryProfile(audience: 'students', interests: ['music']),
        ).score,
        102,
      );
      final unverified = WagzEvent.fromJson({
        ...eventJson,
        'discovery': {
          'audiences': ['students'],
        },
      });
      expect(recommendation(unverified, students).score, 2);
      expect(recommendation(unverified, students).kind, 'suggestion');
      expect(recommendation(unverified, students).personal, isFalse);
      final cancelled = WagzEvent.fromJson({
        ...eventJson,
        'status': 'cancelled',
      });
      expect(recommendation(cancelled, students).score, 0);
      final festival = WagzEvent.fromJson({
        ...eventJson,
        'discovery': {
          'prominence': {
            'kind': 'festival',
            'label': 'Festival',
            'reason': 'Najavljen festival.',
            'sourceUrl': 'https://example.org',
          },
        },
      });
      expect(recommendation(festival, students).score, 2);
      expect(recommendation(festival, students).personal, isFalse);
    },
  );

  test(
    'personal sorting reorders all events without removing unmatched ones',
    () {
      final feed = PublicFeed.fromJson(feedJson());
      final dates = rankForAudience(feed.events);
      expect(dates.first.event.id, 'theatre');
      final personal = rankForAudience(feed.events, audience: 'students');
      expect(personal.map((row) => row.event.id), [
        'student-concert',
        'theatre',
      ]);
      expect(
        audienceProfile(
          const DiscoveryProfile(audience: 'students', interests: ['theatre']),
        ).interests,
        isEmpty,
      );
    },
  );

  test('local preferences persist and tolerate malformed storage', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    const profile = DiscoveryProfile(audience: 'seniors', interests: ['sport']);
    await profile.save(preferences);
    expect(DiscoveryProfile.load(preferences).audience, 'seniors');
    expect(DiscoveryProfile.load(preferences).interests, ['sport']);
    await preferences.setString('wagz.discovery.v1', '{broken');
    expect(DiscoveryProfile.load(preferences).isSet, isFalse);
  });

  test('source links reject executable schemes and credentials', () {
    expect(safeLink('javascript:alert(1)'), isNull);
    expect(safeLink('https://user:password@example.org'), isNull);
    expect(safeLink('https://example.invalid'), isNull);
    expect(safeLink('https://example.org/event'), isNotNull);
    expect(normalize('Šećer Čepin Đakovo'), 'secer cepin dakovo');
  });
}
