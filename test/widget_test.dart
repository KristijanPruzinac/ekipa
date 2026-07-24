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
}
