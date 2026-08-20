import 'package:console/src/data/console_gateway.dart';
import 'package:console/src/widgets/console_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

void main() {
  setUpAll(loadZarFonts);

  testWidgets('a session the database does not know gets the two reasons', (
    tester,
  ) async {
    // `role()` answering null is not an error and must not be shown as one. It
    // is the normal result for an operator who signed in without a second
    // factor, and the screen has to say so, because the next action differs:
    // sign in again with MFA, versus ask for a role.
    await pumpConsole(
      tester,
      const ConsoleShell(),
      gateway: FakeConsoleGateway(heldRole: null),
    );

    expect(find.text('The database does not recognise you here'), findsOne);
    expect(find.textContaining('second factor'), findsWidgets);
    expect(find.textContaining('admin_roles'), findsOne);
  });

  testWidgets('a viewer sees every section, because the server is the gate', (
    tester,
  ) async {
    // Rule 6: if the UI hides it, the server must also refuse it. The server
    // does refuse the writes — every one re-checks `admin_at_least` — so the
    // shell is free to show a viewer the whole tool. Hiding tabs by role would
    // be a client-side permission and a second, quieter copy of the ladder.
    await pumpConsole(
      tester,
      const ConsoleShell(),
      gateway: FakeConsoleGateway(
        heldRole: 'viewer',
        versions: [liveVersion],
        values: layeredValues,
        cityList: const [osijek],
      ),
    );

    expect(find.text('The week'), findsOne);
    expect(find.text('The trail'), findsOne);
    expect(find.text('Configuration'), findsWidgets);
    // And the role is on screen, so a refusal later is not a surprise.
    expect(find.text('VIEWER'), findsOne);
  });

  testWidgets('a server refusal is shown as a refusal, not a crash', (
    tester,
  ) async {
    await pumpConsole(
      tester,
      const ConsoleShell(),
      gateway: FakeConsoleGateway(
        refusal: const ConsoleFailure(
          'permission denied for function console_config_versions',
          code: '42501',
        ),
      ),
    );

    // The wording separates "you may not" from "it broke", and the message is
    // Postgres's own. A console that paraphrased this would be inventing a
    // second explanation of a rule it does not own.
    expect(find.text('REFUSED BY THE SERVER'), findsOne);
    expect(
      find.text('permission denied for function console_config_versions'),
      findsOne,
    );
    expect(find.text('FAILED'), findsNothing);
  });

  testWidgets('a failure that is not a refusal reads differently', (
    tester,
  ) async {
    await pumpConsole(
      tester,
      const ConsoleShell(),
      gateway: FakeConsoleGateway(
        refusal: const ConsoleFailure('connection closed', code: '08006'),
      ),
    );

    expect(find.text('FAILED'), findsOne);
    expect(find.text('REFUSED BY THE SERVER'), findsNothing);
  });

  testWidgets('the rail moves between sections', (tester) async {
    await pumpConsole(
      tester,
      const ConsoleShell(),
      gateway: FakeConsoleGateway(
        versions: [liveVersion],
        values: layeredValues,
        cityList: const [osijek],
        auditList: auditRows,
      ),
    );

    await tester.tap(find.widgetWithText(InkWell, 'The trail'));
    await tester.pumpAndSettle();

    expect(
      find.text('Append-only. Nothing here can be edited or removed.'),
      findsOne,
    );
  });
}
