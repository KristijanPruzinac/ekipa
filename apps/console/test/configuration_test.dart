import 'package:console/src/data/console_gateway.dart';
import 'package:console/src/screens/configuration.dart';
import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

void main() {
  setUpAll(loadZarFonts);

  group('which version is deciding things', () {
    testWidgets('a published version that has started is LIVE', (tester) async {
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [osijek],
        ),
      );

      expect(find.text('LIVE'), findsOne);
    });

    testWidgets('a published version that has not started is SCHEDULED', (
      tester,
    ) async {
      // The distinction the whole `config_versions` table exists for. A console
      // that showed only "published" would report a change as landed while
      // every hangout in flight was still being decided by the previous rules.
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: FakeConsoleGateway(
          versions: [scheduledVersion, liveVersion],
          values: layeredValues,
          cityList: const [osijek],
        ),
      );

      expect(find.text('SCHEDULED'), findsOne);
      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('a version nobody released is UNPUBLISHED', (tester) async {
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: FakeConsoleGateway(
          versions: [unpublishedVersion, liveVersion],
          values: layeredValues,
          cityList: const [osijek],
        ),
      );

      expect(find.text('UNPUBLISHED'), findsOne);
    });

    testWidgets('with no versions at all, the screen says the defaults hold', (
      tester,
    ) async {
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: FakeConsoleGateway(cityList: const [osijek]),
      );

      expect(find.text('No configuration has been published'), findsOne);
      // Not an error state, and the screen says so: every key is running on a
      // compiled default, which is a valid way for the system to be.
      expect(
        find.textContaining('That is a valid state, not an error'),
        findsOne,
      );
      // The keys are still listed, at their defaults.
      expect(find.text('matching.min_group_size'), findsOne);
    });
  });

  group('where a value came from', () {
    testWidgets('the chip names the layer that answered, not just the value', (
      tester,
    ) async {
      // `matching.max_group_size` is 4 globally and 3 in Osijek. Both facts are
      // on screen: the resolved 3, and the reason it is 3. Without the chip an
      // operator would edit the global layer, see nothing move, and have no way
      // to find out why.
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [osijek],
        ),
      );

      expect(find.text('city:c0000000'), findsOne);
      expect(find.text('global'), findsWidgets);
      // A key nothing sets reads as a default, which is a different claim from
      // "set globally to the same number".
      expect(find.text('default'), findsWidgets);
    });

    testWidgets('a safety-critical key is marked, from the key itself', (
      tester,
    ) async {
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [osijek],
        ),
      );

      // Three keys carry the mark in `MatchingKeys`; the screen must not carry
      // its own list of which ones.
      final marked = MatchingKeys.all.where((key) => key.safetyCritical).length;
      expect(
        find.byTooltip('Safety-critical. Changing this needs a typed reason.'),
        findsNWidgets(marked),
      );
    });
  });

  group('starting a change', () {
    testWidgets('a viewer is not offered one', (tester) async {
      // The tab is visible — see the shell test — but the write is not offered,
      // and the server refuses it independently. The UI hiding it is the
      // courtesy; `admin_at_least('operator')` is the control.
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: FakeConsoleGateway(
          heldRole: 'viewer',
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [osijek],
        ),
      );

      expect(find.text('Start a change'), findsNothing);
    });

    testWidgets('an operator is', (tester) async {
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [osijek],
        ),
      );

      expect(find.text('Start a change'), findsOne);
    });

    testWidgets('an empty draft is refused in the validator own words', (
      tester,
    ) async {
      final gateway = FakeConsoleGateway(
        versions: [liveVersion],
        values: layeredValues,
        cityList: const [osijek],
        inFlightList: inFlightObjects,
      );
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: gateway,
        size: wholePage,
      );

      await tester.tap(find.text('Start a change'));
      await tester.pumpAndSettle();

      // Two things are wrong with a draft the operator just started: it has no
      // note, and it changes nothing. Both sentences come from `ConfigDraft`,
      // and the panel prints them rather than paraphrasing.
      expect(find.text('REFUSED'), findsOne);
      expect(
        find.text('A version needs a note saying why it exists.'),
        findsOne,
      );
      expect(
        find.text('This draft is identical to the version it is based on.'),
        findsOne,
      );
      expect(enabledButton(tester, 'Write this version'), isFalse);
      expect(gateway.calls, isNot(contains('publishConfig')));
    });

    testWidgets('the blast radius is stated before the decision, not after', (
      tester,
    ) async {
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: FakeConsoleGateway(
          versions: [liveVersion],
          values: layeredValues,
          cityList: const [osijek],
          inFlightList: inFlightObjects,
        ),
        size: wholePage,
      );

      await tester.tap(find.text('Start a change'));
      await tester.pumpAndSettle();

      expect(find.text('BLAST RADIUS'), findsOne);
      // `BlastRadius` composes the sentence and the screen only prints it, so
      // this asserts the two agree rather than asserting a string the console
      // invented.
      final radius = BlastRadius.estimate(
        inFlight: inFlightObjects,
        effectiveFrom: testNow.add(const Duration(hours: 1)),
      );
      expect(find.text(radius.describe()), findsOne);
    });
  });

  group('publishing', () {
    testWidgets('an edit becomes a diff line naming the layer it lands at', (
      tester,
    ) async {
      final gateway = FakeConsoleGateway(
        versions: [liveVersion],
        values: layeredValues,
        cityList: const [osijek],
        inFlightList: inFlightObjects,
      );
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: gateway,
        size: wholePage,
      );

      await tester.tap(find.text('Start a change'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('value:schedule.horizon_weeks')),
        '3',
      );
      await tester.pumpAndSettle();

      // The key now appears twice: once in the key table, once in the diff.
      expect(find.text('schedule.horizon_weeks'), findsNWidgets(2));
      // Nothing was stored at the global layer before, and "—" is a different
      // fact from "was 2": the compiled default is not a row anybody wrote.
      expect(find.text('—'), findsOne);
      expect(
        find.text('This draft is identical to the version it is based on.'),
        findsNothing,
      );
    });

    testWidgets('the write is refused until a reason is typed', (tester) async {
      final gateway = FakeConsoleGateway(
        versions: [liveVersion],
        values: layeredValues,
        cityList: const [osijek],
        inFlightList: inFlightObjects,
      );
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: gateway,
        size: wholePage,
      );

      await tester.tap(find.text('Start a change'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('value:schedule.horizon_weeks')),
        '3',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('field:note')),
        'Three weeks of horizon so a schedule change has room.',
      );
      await tester.pumpAndSettle();

      // A valid, noted, non-empty change — and still not writable, because
      // nobody has said why. The reason is what the trail keeps, so it is
      // required before the button and not after it.
      expect(find.text('REFUSED'), findsNothing);
      expect(enabledButton(tester, 'Write this version'), isFalse);

      await tester.enterText(
        find.byKey(const ValueKey<String>('field:reason')),
        'Operators kept running the horizon down to four days.',
      );
      await tester.pumpAndSettle();

      expect(enabledButton(tester, 'Write this version'), isTrue);
    });

    testWidgets('publishing sends the reason, and a whole value set', (
      tester,
    ) async {
      final gateway = FakeConsoleGateway(
        versions: [liveVersion],
        values: layeredValues,
        cityList: const [osijek],
        inFlightList: inFlightObjects,
      );
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: gateway,
        size: wholePage,
      );

      await tester.tap(find.text('Start a change'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('value:schedule.horizon_weeks')),
        '3',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('field:note')),
        'Three weeks of horizon.',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('field:reason')),
        'The horizon kept running down to four days.',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write this version'));
      await tester.pumpAndSettle();

      expect(gateway.calls, contains('publishConfig'));
      expect(
        gateway.publishedReason,
        'The horizon kept running down to four days.',
      );
      final draft = gateway.publishedDraft!;
      // The note says what the version is; the reason says why it was made.
      // They are separate on purpose, and both reach the server.
      expect(draft.note, 'Three weeks of horizon.');
      // The version starts in the future, because `console_publish_config`
      // refuses one that starts in the past and the screen must not hand it
      // a value it is going to reject.
      expect(draft.effectiveFrom.isAfter(testNow), isTrue);
      // A whole picture of the rules, not a delta: the base rows carried
      // forward, plus the edit.
      expect(
        draft.rows,
        contains(
          const ConfigValueRow(
            key: 'schedule.horizon_weeks',
            scope: ConfigScope.global(),
            value: 3,
          ),
        ),
      );
      expect(
        draft.rows,
        contains(
          const ConfigValueRow(
            key: 'matching.min_group_size',
            scope: ConfigScope.global(),
            value: 3,
          ),
        ),
      );
      // And the panel closed, because the draft was consumed.
      expect(find.text('Write this version'), findsNothing);
    });

    testWidgets('a server refusal is printed, and the draft is kept', (
      tester,
    ) async {
      final gateway = FakeConsoleGateway(
        versions: [liveVersion],
        values: layeredValues,
        cityList: const [osijek],
        inFlightList: inFlightObjects,
        writeRefusal: const ConsoleFailure(
          'new row violates row-level security policy for table '
          '"config_versions"',
          code: '42501',
        ),
      );
      await pumpConsole(
        tester,
        const ConfigurationScreen(),
        gateway: gateway,
        size: wholePage,
      );

      await tester.tap(find.text('Start a change'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('value:schedule.horizon_weeks')),
        '3',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('field:note')),
        'Three weeks of horizon.',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('field:reason')),
        'Because it kept running down.',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write this version'));
      await tester.pumpAndSettle();

      // The console's own validation passed, so anything arriving here is
      // something the client did not know. Paraphrasing it would lose exactly
      // the information worth keeping.
      expect(
        find.textContaining('new row violates row-level security policy'),
        findsOne,
      );
      // Nothing was discarded — the operator can fix it and try again.
      expect(find.text('Write this version'), findsOne);
    });
  });
}

/// Whether the button labelled [label] can be pressed.
bool enabledButton(WidgetTester tester, String label) {
  final button = tester.widget<EkipaButton>(
    find.widgetWithText(EkipaButton, label),
  );
  return button.onPressed != null;
}

/// A surface tall enough to lay out the whole editor at once.
///
/// The publish panel sits below every key in the catalogue, and a `ListView`
/// builds only what it can show — so a test that scrolled to reach the panel
/// would be testing the scroll. This makes the page one screen instead.
const Size wholePage = Size(1400, 5200);
