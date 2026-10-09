import 'package:flutter_test/flutter_test.dart';
import 'package:senyas/main.dart';

void main() {
  testWidgets('Senyas smoke test - renders introduction screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SenyasApp());
    expect(find.text('Sign. Speak. Understand.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
