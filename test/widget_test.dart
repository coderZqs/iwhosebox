import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const IWhoseboxApp());
    expect(find.text('iwhosebox'), findsOneWidget);
  });
}
