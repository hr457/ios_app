import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safl/main.dart';

void main() {
  testWidgets('Login Page Test', (WidgetTester tester) async {
    // Load the app
    await tester.pumpWidget(const MyApp());

    // Verify login page widgets
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Login to continue'), findsOneWidget);

    expect(find.byType(TextField), findsNWidgets(2));

    expect(find.text('Login'), findsOneWidget);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.phone), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });
}