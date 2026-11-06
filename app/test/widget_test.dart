import 'package:flutter_test/flutter_test.dart';
import 'package:saarthi_ai/main.dart';

void main() {
  testWidgets('role screen shows both choices and reacts to a tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SaarthiApp());

    expect(find.text('Saarthi.AI'), findsOneWidget);
    expect(find.text('Who are you?'), findsOneWidget);
    expect(find.text('Senior Citizen'), findsOneWidget);
    expect(find.text('Nominee (Family Member)'), findsOneWidget);

    await tester.tap(find.text('Senior Citizen'));
    await tester.pump();
    expect(find.text('Selected: senior'), findsOneWidget);
  });
}