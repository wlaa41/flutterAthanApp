import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/main.dart';

void main() {
  testWidgets('AthanQuranApp builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const AthanQuranApp());
    expect(find.byType(AthanQuranApp), findsOneWidget);
  });
}
