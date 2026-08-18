import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('the shell builds', (tester) async {
    await tester.pumpWidget(const EkipaApp());
    expect(find.text('ekipa'), findsOneWidget);
  });
}
