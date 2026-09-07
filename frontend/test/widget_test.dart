import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('MediQ App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MediQApp());
    expect(find.text('MediQ - OPD Queue Management'), findsOneWidget);
  });
}
