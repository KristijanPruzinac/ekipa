import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as timezone;
import 'package:wagz_mobile/discovery.dart';
import 'package:wagz_mobile/discovery_widgets.dart';
import 'package:wagz_mobile/models.dart';

void main() {
  setUpAll(() async {
    timezone.initializeTimeZones();
    await initializeDateFormatting('hr');
  });

  const evidence = EventDiscovery(
    audienceEvidence: [
      DiscoveryReason(
        'Program za studente.',
        'https://example.org/event',
        audience: 'students',
      ),
    ],
  );
  final events = [
    const WagzEvent(
      id: 'student',
      title: 'Radionica',
      startsAt: '2026-10-07',
      category: 'community',
      discovery: evidence,
    ),
    const WagzEvent(
      id: 'cancelled',
      title: 'Otkazani program',
      startsAt: '2026-10-06',
      status: 'cancelled',
      discovery: evidence,
    ),
    const WagzEvent(
      id: 'unverified',
      title: 'Studentski koncert',
      startsAt: '2026-10-05',
      category: 'nightlife',
      discovery: EventDiscovery(audiences: ['students']),
    ),
    const WagzEvent(
      id: 'late',
      title: 'Kasni plan',
      startsAt: '2026-10-03T23:30:00Z',
    ),
    const WagzEvent(
      id: 'unknown',
      title: 'Nepoznato vrijeme',
      startsAt: '2026-10-04',
    ),
  ];

  test(
    'all legacy audience choices retain every event in stable Zagreb chronology',
    () {
      for (final audience in ['all', 'students', 'adults', 'seniors']) {
        expect(
          rankForAudience(
            events,
            audience: audience,
          ).map((row) => row.event.id),
          ['unknown', 'late', 'unverified', 'cancelled', 'student'],
        );
      }
      final tied = [
        const WagzEvent(
          id: 'first',
          title: 'B',
          startsAt: '2026-10-25T02:30:00+02:00',
        ),
        const WagzEvent(
          id: 'second',
          title: 'A',
          startsAt: '2026-10-25T00:30:00Z',
        ),
        const WagzEvent(
          id: 'later',
          title: 'C',
          startsAt: '2026-10-25T02:30:00+01:00',
        ),
      ];
      expect(rankForAudience(tied).map((row) => row.event.id), [
        'first',
        'second',
        'later',
      ]);
    },
  );

  test(
    'known intervals preserve date-only ends, exact hours, ongoing state and overlapping branches',
    () {
      const festival = WagzEvent(
        id: 'festival',
        title: 'HeadOnEast',
        startsAt: '2026-10-02T18:00:00+02:00',
        endsAt: '2026-10-04',
        category: 'music',
      );
      const cycling = WagzEvent(
        id: 'cycling',
        title: 'Febire',
        startsAt: '2026-10-04T11:00:00+02:00',
        endsAt: '2026-10-04T16:00:00+02:00',
        category: 'sport',
      );
      const unknown = WagzEvent(
        id: 'unknown',
        title: 'Program',
        startsAt: '2026-10-04T17:00:00+02:00',
      );
      final data = timelineFor([festival, cycling, unknown]);
      expect(data.moments.map((item) => '${item.event.id}:${item.ending}'), [
        'festival:false',
        'cycling:false',
        'cycling:true',
        'unknown:false',
        'festival:true',
      ]);
      expect(data.ranges.map((range) => [range.start, range.end, range.lane]), [
        [0, 4, 0],
        [1, 2, 1],
      ]);
      expect(durationLabel(festival), isNull);
      expect(durationLabel(cycling), '5 h');
      expect(eventDurationText(cycling), 'Traje 5 h');
      expect(
        eventDurationText(cycling, '2026-10-04T12:00:00Z'),
        'Danas do 16:00',
      );
      expect(
        eventDurationText(festival, '2026-10-03T12:00:00Z'),
        'Traje do 4.10.',
      );
      expect(
        eventDurationText(
          const WagzEvent(
            id: 'dates',
            title: 'Dates',
            startsAt: '2026-10-02',
            endsAt: '2026-10-04',
          ),
        ),
        'Traje 3 dana',
      );
      expect(eventDurationText(unknown), 'Kraj nije naveden');
      expect(durationLabel(unknown), isNull);
      expect(isOngoing(festival, '2026-10-03T12:00:00Z'), isTrue);
      expect(isOngoing(festival, '2026-10-04T23:00:00Z'), isFalse);
      expect(isOngoing(cycling, '2026-10-04T14:00:00Z'), isFalse);
      expect(isOngoing(unknown, '2026-10-04T18:00:00Z'), isFalse);
      expect(
        durationLabel(
          const WagzEvent(
            id: 'DST',
            title: 'DST',
            startsAt: '2026-10-25T02:30:00+02:00',
            endsAt: '2026-10-25T02:30:00+01:00',
          ),
        ),
        '1 h',
      );
    },
  );

  testWidgets(
    '320px timeline shows a real duration and date-only ending without overflow at large text',
    (tester) async {
      WagzEvent? opened;
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: SingleChildScrollView(
                child: EventTimeline(
                  events: const [
                    WagzEvent(
                      id: 'festival',
                      title: 'HeadOnEast festival',
                      startsAt: '2026-10-02T18:00:00+02:00',
                      endsAt: '2026-10-04',
                      category: 'music',
                    ),
                    WagzEvent(
                      id: 'cycling',
                      title: 'Febire',
                      startsAt: '2026-10-04T11:00:00+02:00',
                      endsAt: '2026-10-04T16:00:00+02:00',
                      category: 'sport',
                    ),
                  ],
                  now: '2026-10-03T12:00:00Z',
                  onOpen: (event) => opened = event,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timeline-end-festival')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('timeline-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('↳ 5 h'), findsOneWidget);
      expect(find.text('U TIJEKU'), findsOneWidget);
      expect(find.text('sat nije naveden'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('timeline-end-festival')),
        findsOneWidget,
      );
      for (final endpoint in ['end', 'event']) {
        final marker = find.byKey(ValueKey('timeline-$endpoint-festival'));
        await tester.ensureVisible(marker);
        await tester.tap(marker);
        expect(opened?.id, 'festival');
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ongoing summary is compact, expands every entry and opens details',
    (tester) async {
      WagzEvent? opened;
      final ongoing = List.generate(
        3,
        (index) => WagzEvent(
          id: '$index',
          title: 'Program $index',
          startsAt: '2026-10-02',
          endsAt: '2026-10-04',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OngoingEvents(
                events: ongoing,
                now: '2026-10-03T12:00:00Z',
                onOpen: (event) => opened = event,
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('ongoing-event-2')), findsNothing);
      expect(find.text('Prikaži sve u tijeku (3)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ongoing-expand')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ongoing-event-2')));
      expect(opened?.id, '2');
      await tester.tap(find.byKey(const ValueKey('ongoing-expand')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ongoing-event-2')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'timeline expands, collapses and opens the chosen chronological event',
    (tester) async {
      WagzEvent? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventTimeline(
                events: events,
                onOpen: (event) => opened = event,
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('timeline-event-late')), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('event-timeline'))).height,
        lessThanOrEqualTo(80),
      );
      await tester.tap(find.byKey(const ValueKey('timeline-toggle')));
      await tester.pumpAndSettle();
      final late = find.byKey(const ValueKey('timeline-event-late'));
      expect(find.text('Početak'), findsOneWidget);
      expect(find.text('Kraj'), findsOneWidget);
      expect(
        tester
            .getTopLeft(
              find.text(
                'Luk spaja početak i kraj. Razmaci nisu mjerilo trajanja.',
              ),
            )
            .dy,
        lessThan(tester.getTopLeft(late).dy),
      );
      expect(
        find.byKey(const ValueKey('timeline-event-student')),
        findsNothing,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('timeline-event-unknown')))
            .dy,
        lessThan(tester.getTopLeft(late).dy),
      );
      await tester.tap(late);
      expect(opened?.id, 'late');
      await tester.ensureVisible(find.byKey(const ValueKey('timeline-expand')));
      await tester.tap(find.byKey(const ValueKey('timeline-expand')));
      await tester.pumpAndSettle();
      final student = find.byKey(const ValueKey('timeline-event-student'));
      await tester.ensureVisible(student);
      await tester.tap(student);
      expect(opened?.id, 'student');
      final collapse = find.byKey(const ValueKey('timeline-expand'));
      await tester.ensureVisible(collapse);
      await tester.tap(collapse);
      await tester.pumpAndSettle();
      expect(student, findsNothing);
      final closeChart = find.byKey(const ValueKey('timeline-toggle'));
      await tester.ensureVisible(closeChart);
      await tester.tap(closeChart);
      await tester.pumpAndSettle();
      expect(late, findsNothing);
      expect(find.text('Otvori vremensku crtu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
