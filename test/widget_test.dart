// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:hoistbay/main.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AwsS3BrowserApp());

    // Verify that the profile selection screen is displayed
    expect(find.text('Hoistbay'), findsOneWidget);
    expect(find.text('AWS Profiles'), findsOneWidget);
    expect(find.text('Add New Profile'), findsOneWidget);
  });
}