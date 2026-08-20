import 'package:console/src/data/console_gateway.dart';
import 'package:console/src/screens/schedule.dart';
import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

void main() {
  setUpAll(loadZarFonts);

  group('the city bar', () {
    testWidgets('the zone is on screen, because it is the input that can be '
        'an hour wrong', (tester) async {
      await pumpConsole(
        tester,
        const ScheduleScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [osijek],
          slotList: dstSlots,
        ),
      );

      expect(find.text('Europe/Zagreb'), findsOne);
      expect(find.text('18 slots ahead'), findsOne);
    });

    testWidgets('a city that is not open to anybody says so', (tester) async {
      // A city is inactive precisely while it is being set up, which is the
      // state in which somebody generates its first slots and then wonders why
      // nobody is answering.
      await pumpConsole(
        tester,
        const ScheduleScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [zagreb],
        ),
      );

      expect(find.text('INACTIVE'), findsOne);
    });

    testWidgets('with no city at all, generating is not offered', (
      tester,
    ) async {
      await pumpConsole(
        tester,
        const ScheduleScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: layeredValues,
        ),
      );

      expect(find.textContaining('No city exists yet'), findsOne);
      expect(buttonEnabled(tester, 'Generate the horizon'), isFalse);
    });
  });

  group('the rule', () {
    testWidgets('the schedule is shown as the four keys it is', (tester) async {
      await pumpConsole(
        tester,
        const ScheduleScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [osijek],
          slotList: dstSlots,
        ),
      );

      expect(find.text('Thu · Fri · Sat'), findsOne);
      expect(find.text('16:00 · 17:30 · 19:00'), findsOne);
      expect(find.text('90 min'), findsOne);
      expect(find.text('9 slots a week'), findsOne);
    });

    testWidgets('an unparseable schedule explains itself, in core words', (
      tester,
    ) async {
      // Two start times an hour apart, and a slot ninety minutes long. Such
      // a schedule generates nothing at all, which looks exactly like a quiet
      // week — so the screen has to say why, and `SlotSchedule` says it.
      await pumpConsole(
        tester,
        const ScheduleScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: [
            const ConfigValueRow(
              key: 'schedule.start_times',
              scope: ConfigScope.global(),
              value: '16:00,17:00',
            ),
          ],
          cityList: const [osijek],
        ),
      );

      expect(find.text('REFUSED'), findsOne);
      expect(
        find.text(
          '16:00 and 17:00 are 60 minutes apart, closer than the 90-minute '
          'slot they start. They would overlap, and one person could be '
          'available for both.',
        ),
        findsOne,
      );
      expect(buttonEnabled(tester, 'Generate the horizon'), isFalse);
    });
  });

  group('the week', () {
    testWidgets('both clocks are shown, so the daylight-saving jump is '
        'visible', (tester) async {
      // The same 17:30 in Osijek is 15:30Z on 23 October and 16:30Z on the
      // 30th, because the clocks go back on the 25th. This column pair is the
      // only place a human can see that happen, and the reason the local time
      // and the instant are both stored rather than one derived from the other.
      await pumpConsole(
        tester,
        const ScheduleScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [osijek],
          slotList: dstSlots,
        ),
      );

      expect(find.text('17:30'), findsNWidgets(2));
      expect(find.text('15:30Z'), findsOne);
      expect(find.text('16:30Z'), findsOne);
      // Three: the rule states its signature once, and each row it produced
      // repeats it. That is what lets a slot generated under last month's
      // schedule be told apart from one generated under this month's.
      expect(
        find.text('schedule:4,5,6@16:00,17:30,19:00/90m'),
        findsNWidgets(3),
      );
    });

    testWidgets('availability is a count and never a list', (tester) async {
      // The console has no view over who is free. `SlotRecord.available` is the
      // field where that would leak if it were going to, and it is an int.
      await pumpConsole(
        tester,
        const ScheduleScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [osijek],
          slotList: dstSlots,
        ),
      );

      expect(find.text('11'), findsOne);
      expect(find.text('7'), findsOne);
    });
  });

  group('generating', () {
    testWidgets('a viewer cannot, and an operator cannot without a reason', (
      tester,
    ) async {
      await pumpConsole(
        tester,
        const ScheduleScreen(),
        gateway: FakeConsoleGateway(
          heldRole: 'viewer',
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [osijek],
          slotList: dstSlots,
        ),
      );

      expect(buttonEnabled(tester, 'Generate the horizon'), isFalse);
    });

    testWidgets('an operator with a reason sends local slots, not instants', (
      tester,
    ) async {
      final gateway = FakeConsoleGateway(
        versions: [liveVersion],
        values: layeredValues,
        cityList: const [osijek],
        slotList: dstSlots,
      );
      await pumpConsole(tester, const ScheduleScreen(), gateway: gateway);

      expect(buttonEnabled(tester, 'Generate the horizon'), isFalse);

      await tester.enterText(
        // The only text field on this screen, and the one the audit row keeps.
        find.byType(TextField),
        'The horizon had run down to four days.',
      );
      await tester.pumpAndSettle();

      expect(buttonEnabled(tester, 'Generate the horizon'), isTrue);

      await tester.tap(find.text('Generate the horizon'));
      await tester.pumpAndSettle();

      expect(gateway.calls, contains('generateSlots'));
      // Two weeks of a three-evening, three-slot week: eighteen. Which weeks
      // those are is calendar arithmetic in `ekipa_core`; turning them into
      // instants is Postgres's job, so what crosses the wire is local.
      final sent = gateway.generatedSlots!;
      expect(sent, hasLength(18));
      expect(sent.first, isA<LocalSlot>());
      expect(sent.every((slot) => [4, 5, 6].contains(slot.weekday)), isTrue);
      expect(
        sent.every((slot) => slot.duration == const Duration(minutes: 90)),
        isTrue,
      );
    });

    testWidgets('a refused generate is printed rather than swallowed', (
      tester,
    ) async {
      final gateway = FakeConsoleGateway(
        versions: [liveVersion],
        values: layeredValues,
        cityList: const [osijek],
        slotList: dstSlots,
        writeRefusal: const ConsoleFailure(
          'permission denied for function console_generate_slots',
          code: '42501',
        ),
      );
      await pumpConsole(tester, const ScheduleScreen(), gateway: gateway);

      await tester.enterText(
        // The only text field on this screen, and the one the audit row keeps.
        find.byType(TextField),
        'Trying it as a viewer.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate the horizon'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'permission denied for function console_generate_slots',
        ),
        findsOne,
      );
    });
  });
}

/// Whether the button labelled [label] can be pressed.
bool buttonEnabled(WidgetTester tester, String label) {
  final matches = find.widgetWithText(EkipaButton, label);
  if (matches.evaluate().isEmpty) return false;
  return tester.widget<EkipaButton>(matches).onPressed != null;
}
