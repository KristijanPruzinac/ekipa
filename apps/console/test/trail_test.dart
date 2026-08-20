import 'package:console/src/data/records.dart';
import 'package:console/src/screens/trail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/fixtures.dart';
import 'support/harness.dart';

void main() {
  setUpAll(loadZarFonts);

  testWidgets('an operator appears as a label, never as an identifier', (
    tester,
  ) async {
    // `12_CONSOLE.md` §2: analytical surfaces show a short pseudonym. The trail
    // is the surface most likely to be read *about* a colleague, and the two
    // questions it needs to answer — was this the same person twice, did
    // anybody give a reason — do not require knowing who.
    await pumpConsole(
      tester,
      const TrailScreen(),
      gateway: FakeConsoleGateway(auditList: auditRows),
    );

    expect(find.text('OP-7F3A'), findsNWidgets(2));
    expect(find.text('OP-B21D'), findsOne);
    for (final entry in auditRows) {
      expect(find.text(entry.actor), findsNothing);
    }
  });

  test('the label is derived, so two rows by one person match', () {
    // Stable is the whole point: a random pseudonym per row would answer no
    // question at all, and a stored one would be a column an operator could
    // set.
    final first = AuditRecord(
      id: 1,
      actor: '7f3a91c2-0000-4000-8000-000000000001',
      action: 'config.publish',
      target: null,
      reason: 'a',
      occurredAt: _stamp,
    );
    expect(first.actorLabel, 'OP-7F3A');
    expect(
      AuditRecord(
        id: 2,
        actor: '7f3a91c2-ffff-4000-8000-00000000ffff',
        action: 'slots.generate',
        target: null,
        reason: 'b',
        occurredAt: _stamp,
      ).actorLabel,
      first.actorLabel,
    );
  });

  testWidgets('every row carries the reason its operator typed', (
    tester,
  ) async {
    await pumpConsole(
      tester,
      const TrailScreen(),
      gateway: FakeConsoleGateway(auditList: auditRows),
    );

    for (final entry in auditRows) {
      expect(find.text(entry.reason), findsOne);
    }
    // Printed as typed. This column is the reason the reason field is
    // mandatory, and paraphrasing it would defeat the point of keeping it.
    expect(
      find.text('Three evenings was too few for the number of people waiting.'),
      findsOne,
    );
  });

  testWidgets('times are stamped in UTC, with the Z said out loud', (
    tester,
  ) async {
    // Every instant on this screen is UTC, and it says so. An operator in
    // Zagreb reading an unmarked "14:02" would reasonably assume local, and be
    // two hours out when comparing it against a slot.
    await pumpConsole(
      tester,
      const TrailScreen(),
      gateway: FakeConsoleGateway(auditList: auditRows),
    );

    expect(find.text('2026-10-19 14:02Z'), findsOne);
  });

  testWidgets('an empty trail is empty, not an error', (tester) async {
    await pumpConsole(
      tester,
      const TrailScreen(),
      gateway: FakeConsoleGateway(),
    );

    expect(find.text('Nothing here yet.'), findsOne);
    expect(find.text('FAILED'), findsNothing);
  });
}

final DateTime _stamp = DateTime.utc(2026, 10, 19, 14, 2);
