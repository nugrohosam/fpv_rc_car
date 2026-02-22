// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:fpv_rc_car/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FPVRCCarApp());

    // Verify that the home screen is displayed
    expect(find.text('FPV RC Car'), findsOneWidget);
  });
}
