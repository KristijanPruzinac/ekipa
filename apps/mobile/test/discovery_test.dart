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
    'audience ordering retains everything, respects Zagreb days and requires evidence',
    () {
      expect(rankForAudience(events).map((row) => row.event.id), [
        'unknown',
        'late',
        'unverified',
        'cancelled',
        'student',
      ]);
      final selected = rankForAudience(events, audience: 'students');
      expect(selected.map((row) => row.event.id), [
        'student',
        'unknown',
        'late',
        'unverified',
        'cancelled',
      ]);
      expect(selected.where((row) => row.recommendation.personal).length, 1);
      expect(
        rankForAudience(events, audience: 'seniors').map((row) => row.event.id),
        rankForAudience(events).map((row) => row.event.id),
      );
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

  testWidgets('all audience choices work on a 320px phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var audience = 'all';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StatefulBuilder(
                builder: (context, setState) => AudienceSelector(
                  audience: audience,
                  onChanged: (value) => setState(() => audience = value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (final value in ['students', 'adults', 'seniors', 'all']) {
      final choice = find.byKey(ValueKey('audience-$value'));
      expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(audience, value);
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Studenti'), findsOneWidget);
    expect(find.textContaining('mladi'), findsNothing);
  });

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
      final late = find.byKey(const ValueKey('timeline-event-late'));
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
      expect(tester.takeException(), isNull);
    },
  );
}
