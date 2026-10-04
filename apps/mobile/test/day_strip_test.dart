import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as timezone;
import 'package:wagz_mobile/day_strip.dart';
import 'package:wagz_mobile/discovery.dart';
import 'package:wagz_mobile/models.dart';

List<String> strip(String start, [String? end, DailyHours? daily]) => dayStrip(
  WagzEvent(
    id: 'e',
    title: 'Event',
    startsAt: start,
    endsAt: end,
    dailyHours: daily,
  ),
).map((c) => '${c.kind} ${c.weekday} ${c.date} ${c.time ?? '-'} ${c.hidden ?? ''}'.trim()).toList();

void main() {
  setUpAll(() async {
    timezone.initializeTimeZones();
    await initializeDateFormatting('hr');
  });

  test('same day, past midnight, ranges and missing data match the web strip', () {
    expect(strip('2026-10-04T17:00:00+02:00', '2026-10-04T18:20:00+02:00'), [
      'single nedjelja 4.10. 17:00–18:20',
    ]);
    expect(strip('2026-10-24T20:30:00+02:00', '2026-10-25T02:30:00+02:00'), [
      'start sub 24.10. 20:30',
      'end ned 25.10. 02:30',
    ]);
    expect(strip('2026-10-22', '2026-10-24'), [
      'start čet 22.10. -',
      'mid pet 23.10. -',
      'end sub 24.10. -',
    ]);
    expect(strip('2026-10-02T10:00:00+02:00', '2026-11-15'), [
      'start pet 2.10. 10:00',
      'gap   - 43',
      'end ned 15.11. -',
    ]);
    expect(strip('2026-10-09T19:00:00+02:00'), [
      'start pet 9.10. 19:00',
      'open kraj ? -',
    ]);
    expect(strip('2026-10-10'), ['single subota 10.10. -']);
  });

  test('daily hours print once below; "in progress" only during them', () {
    const daily = DailyHours('18:00', '21:00');
    final result = ticket(
      const WagzEvent(
        id: 'd',
        title: 'D',
        startsAt: '2026-10-22T18:00:00+02:00',
        endsAt: '2026-10-24T21:00:00+02:00',
        dailyHours: daily,
      ),
    );
    expect(result.daily, '18:00–21:00');
    expect(
      ticketLabel(
        const WagzEvent(
          id: 'n',
          title: 'N',
          startsAt: '2026-10-24T20:30:00+02:00',
          endsAt: '2026-10-25T02:30:00+02:00',
        ),
      ),
      'Početak: subota 24.10. u 20:30. Kraj: nedjelja 25.10. u 02:30.',
    );
    expect(
      result.stubs.map((s) => '${s.tone} ${s.big ?? '-'} ${s.small}'),
      ['main 22.10. čet', 'mid 23. pet', 'main 24.10. sub'],
    );
    const festival = WagzEvent(
      id: 'f',
      title: 'Festival',
      startsAt: '2026-10-22T18:00:00+02:00',
      endsAt: '2026-10-24T21:00:00+02:00',
      dailyHours: daily,
    );
    expect(isOngoing(festival, '2026-10-23T17:30:00Z'), isTrue);
    expect(isOngoing(festival, '2026-10-23T01:00:00Z'), isFalse);
  });

  testWidgets('strip and map fit a 320px phone at large text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: Column(
              children: [
                DayStripView(
                  event: const WagzEvent(
                    id: 'x',
                    title: 'X',
                    startsAt: '2026-10-22T18:00:00+02:00',
                    endsAt: '2026-10-25T21:00:00+02:00',
                  ),
                ),
                DayStripView(
                  event: const WagzEvent(
                    id: 'y',
                    title: 'Y',
                    startsAt: '2026-10-24T20:30:00+02:00',
                    endsAt: '2026-10-24T21:30:00+02:00',
                  ),
                ),
                const EventMapView(
                  event: WagzEvent(
                    id: 'm',
                    title: 'M',
                    startsAt: '2026-10-22',
                    location: GeoLocation(45.559, 18.679),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('day-strip')), findsNWidgets(2));
    expect(find.byKey(const ValueKey('event-map')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
