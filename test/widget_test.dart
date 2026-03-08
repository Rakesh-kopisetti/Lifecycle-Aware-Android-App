// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifecycle_master_app/models/app_state_provider.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build a minimal widget for testing
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppStateProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Lifecycle Master'),
            ),
          ),
        ),
      ),
    );

    // Verify that our app title appears
    expect(find.text('Lifecycle Master'), findsOneWidget);
  });
}
