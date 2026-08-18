import 'package:console/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the shell builds', (tester) async {
    await tester.pumpWidget(const ConsoleApp());
    expect(find.text('ekipa console'), findsOneWidget);
  });
}
