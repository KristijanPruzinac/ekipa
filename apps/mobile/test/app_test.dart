import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('the shell builds on the design system', (tester) async {
    await tester.pumpWidget(const EkipaApp());
    await tester.pumpAndSettle();

    expect(find.text('ekipa'), findsOneWidget);
    // Not a decorative assertion: it fails the moment someone builds a screen
    // out of a bare Scaffold and ad-hoc styling, which is how the v1 kit
    // stopped being a design system.
    expect(find.byType(EkipaScreen), findsOneWidget);
  });

  testWidgets('the primary action is present and not yet available', (
    tester,
  ) async {
    await tester.pumpWidget(const EkipaApp());
    await tester.pumpAndSettle();

    final button = tester.widget<EkipaButton>(find.byType(EkipaButton));
    expect(button.onPressed, isNull);
  });
}
