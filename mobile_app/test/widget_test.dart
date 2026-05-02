import 'package:flutter_test/flutter_test.dart';
import 'package:cypher/main.dart';

void main() {
  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CypherApp());

    // Verify that splash screen content is present
    expect(find.text('C'), findsOneWidget);
    expect(find.text('Y'), findsOneWidget);
  });
}
