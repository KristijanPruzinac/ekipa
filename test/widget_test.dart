import 'package:ekipa/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Welcome screen renders the arrival state and primary action', (tester) async {
    await tester.pumpWidget(const EkipaApp());
    // The constellation field and arrival pulse animate forever, so pump a
    // fixed number of frames rather than pumpAndSettle (which would hang).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("You're in."), findsOneWidget);
    expect(find.text('See my invitation'), findsOneWidget);
  });

  testWidgets('Mock-mode invite flow: welcome -> home -> invite detail', (tester) async {
    // No SUPABASE_URL/ANON_KEY defined in the test environment, so this runs
    // the same offline mock-data path unauthenticated users never leave.
    await tester.pumpWidget(const EkipaApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('See my invitation'));
    await tester.pump();
    await tester.pump(); // let HomeScreen's FutureBuilder resolve the mock future
    await tester.pump(const Duration(milliseconds: 500));

    // 'A new invitation' renders as a per-character AnimatedHeadline, so assert
    // on the stable section label + the invitation card instead.
    expect(find.text('OSIJEK'), findsOneWidget);
    expect(find.text('Walking'), findsOneWidget);

    await tester.tap(find.text('Walking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // A 'proposed' meetup should never reveal attendee identities pre-confirmation.
    expect(find.text("Yes, I'll come"), findsOneWidget);
    expect(
      find.text("Private until everyone accepts. As soon as the group is set, you'll see who's in."),
      findsOneWidget,
    );
    expect(find.text('Lucija'), findsNothing);
  });
}
