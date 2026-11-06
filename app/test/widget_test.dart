import 'package:flutter_test/flutter_test.dart';
import 'package:saarthi_ai/main.dart';

void main() {
  testWidgets('app shows the app name', (WidgetTester tester) async {
    await tester.pumpWidget(const SaarthiApp());
    expect(find.text('Saarthi.AI'), findsOneWidget);
  });
}