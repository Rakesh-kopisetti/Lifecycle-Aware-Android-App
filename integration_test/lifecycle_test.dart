import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lifecycle_master_app/main.dart';
import 'package:lifecycle_master_app/models/app_state_provider.dart';
import 'package:provider/provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Lifecycle Master Integration Tests', () {
    late AppStateProvider appState;

    setUp(() async {
      appState = AppStateProvider();
      await appState.initialize();
    });

    tearDown(() {
      appState.dispose();
    });

    testWidgets('App launches successfully', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the app title is displayed
      expect(find.text('Lifecycle Master'), findsOneWidget);
      
      // Verify bottom navigation is present
      expect(find.byKey(const Key('bottom-navigation')), findsOneWidget);
    });

    testWidgets('Lifecycle status dashboard displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify lifecycle status dashboard is present
      expect(find.byKey(const Key('lifecycle-status-dashboard')), findsOneWidget);
      
      // Verify current state is displayed
      expect(find.byKey(const Key('current-lifecycle-state')), findsOneWidget);
      
      // Verify the state shows RESUMED (app is active)
      expect(find.text('RESUMED'), findsOneWidget);
    });

    testWidgets('Event timeline displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify event timeline is present
      expect(find.byKey(const Key('event-timeline')), findsOneWidget);
      
      // Verify timeline title
      expect(find.text('Event Timeline'), findsOneWidget);
    });

    testWidgets('Navigation between tabs works', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to Services tab
      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();

      // Verify Services tab content
      expect(find.byKey(const Key('service-controls')), findsOneWidget);
      expect(find.byKey(const Key('background-task-manager')), findsOneWidget);
      expect(find.byKey(const Key('alarm-scheduler')), findsOneWidget);

      // Navigate to State tab
      await tester.tap(find.text('State'));
      await tester.pumpAndSettle();

      // Verify State tab content
      expect(find.byKey(const Key('state-persistence-panel')), findsOneWidget);
      expect(find.byKey(const Key('configuration-changes-card')), findsOneWidget);
    });

    testWidgets('Theme toggle works', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Get initial theme mode
      final initialThemeMode = appState.themeMode;

      // Tap the theme toggle button
      await tester.tap(find.byKey(const Key('toggle-theme-button')));
      await tester.pumpAndSettle();

      // Verify theme changed
      expect(appState.themeMode, isNot(equals(initialThemeMode)));
    });

    testWidgets('Form data persists correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to State tab
      await tester.tap(find.text('State'));
      await tester.pumpAndSettle();

      // Find form fields
      final nameField = find.byKey(const Key('form-name-field'));
      final emailField = find.byKey(const Key('form-email-field'));
      final notesField = find.byKey(const Key('form-notes-field'));

      // Enter test data
      await tester.enterText(nameField, 'Test User');
      await tester.pumpAndSettle();

      await tester.enterText(emailField, 'test@example.com');
      await tester.pumpAndSettle();

      await tester.enterText(notesField, 'Test notes');
      await tester.pumpAndSettle();

      // Save snapshot
      await tester.tap(find.byKey(const Key('save-snapshot-button')));
      await tester.pumpAndSettle();

      // Verify snapshot was saved
      expect(appState.stateRecoveryManager.currentSnapshot, isNotNull);
      expect(
        appState.stateRecoveryManager.currentSnapshot?.formData['name'],
        equals('Test User'),
      );
    });

    testWidgets('State retention during configuration changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to State tab and enter form data
      await tester.tap(find.text('State'));
      await tester.pumpAndSettle();

      final nameField = find.byKey(const Key('form-name-field'));
      await tester.enterText(nameField, 'Config Test');
      await tester.pumpAndSettle();

      // Save state
      await tester.tap(find.byKey(const Key('save-snapshot-button')));
      await tester.pumpAndSettle();

      // Simulate configuration change (theme toggle as proxy for any config change)
      await tester.tap(find.byKey(const Key('toggle-theme-button')));
      await tester.pumpAndSettle();

      // Verify data is still present
      expect(
        appState.stateRecoveryManager.currentSnapshot?.formData['name'],
        equals('Config Test'),
      );

      // Verify configuration change was logged
      expect(appState.configurationHandler.changes.length, greaterThan(0));
    });

    testWidgets('Foreground service controls are displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to Services tab
      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();

      // Verify service controls
      expect(find.byKey(const Key('start-service-button')), findsOneWidget);
      expect(find.byKey(const Key('stop-service-button')), findsOneWidget);
      expect(find.byKey(const Key('service-status')), findsOneWidget);
    });

    testWidgets('Background task manager displays tasks', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to Services tab
      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();

      // Verify background task cards are present
      expect(find.byKey(const Key('task-card-syncDataTask')), findsOneWidget);
      expect(find.byKey(const Key('task-card-cleanupTask')), findsOneWidget);
      expect(find.byKey(const Key('task-card-healthCheckTask')), findsOneWidget);
    });

    testWidgets('Alarm scheduler is functional', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to Services tab
      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();

      // Scroll down to alarm scheduler
      await tester.drag(
        find.byKey(const Key('services-scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      // Verify alarm scheduler is present
      expect(find.byKey(const Key('alarm-scheduler')), findsOneWidget);
      expect(find.byKey(const Key('schedule-alarm-button')), findsOneWidget);
    });

    testWidgets('Clear all state works', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // First save some state
      await tester.tap(find.text('State'));
      await tester.pumpAndSettle();

      final nameField = find.byKey(const Key('form-name-field'));
      await tester.enterText(nameField, 'Clear Test');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save-snapshot-button')));
      await tester.pumpAndSettle();

      // Verify state was saved
      expect(
        appState.stateRecoveryManager.currentSnapshot?.formData['name'],
        equals('Clear Test'),
      );

      // Clear state
      await tester.tap(find.byKey(const Key('clear-state-button')));
      await tester.pumpAndSettle();

      // Verify state was cleared
      expect(appState.stateRecoveryManager.currentSnapshot, isNull);
    });

    testWidgets('Lifecycle manager tracks events correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify lifecycle manager has recorded at least the app start event
      expect(appState.lifecycleManager.events.length, greaterThan(0));

      // Check that the current state is resumed
      expect(
        appState.lifecycleManager.lifecycleStateString,
        equals('resumed'),
      );
    });

    testWidgets('Scroll views are present and functional', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
          child: const LifecycleMasterApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Overview scroll
      expect(find.byKey(const Key('overview-scroll')), findsOneWidget);

      // Navigate to Services and verify scroll
      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('services-scroll')), findsOneWidget);

      // Navigate to State and verify scroll
      await tester.tap(find.text('State'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('state-scroll')), findsOneWidget);
    });
  });
}
