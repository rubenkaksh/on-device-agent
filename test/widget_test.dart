import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gemma_poc/main.dart';

void main() {
  testWidgets('App loads and shows chat screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GemmaPocApp());

    // Verify the app title is shown
    expect(find.text('Gemma Chat'), findsOneWidget);
  });
}
