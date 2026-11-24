import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawcare/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> openApp(WidgetTester tester) async {
    // tall surface so the FAB does not cover list items and all cards build
    tester.view.physicalSize = const Size(1400, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PawCareApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
  }

  testWidgets('onboarding shows first and leads into the app', (tester) async {
    await tester.pumpWidget(const PawCareApp());
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Vet checkup'), findsOneWidget);
  });

  testWidgets('shows seeded tasks, stats and the tip card', (tester) async {
    await openApp(tester);
    expect(find.text('Vet checkup'), findsOneWidget);
    expect(find.text('Grooming'), findsWidgets); // task title and filter chip
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('Tip of the day'), findsOneWidget);
  });

  testWidgets('pets tab shows seeded pets', (tester) async {
    await openApp(tester);
    await tester.tap(find.byIcon(Icons.pets).last);
    await tester.pumpAndSettle();
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Rocky'), findsOneWidget);
    expect(find.text('Your pets'), findsOneWidget);
  });

  testWidgets('adding a task through the dialog shows it in the list', (tester) async {
    await openApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Nail trim');
    await tester.enterText(find.byType(TextField).at(1), '2027-01-20');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Nail trim'), findsOneWidget);
  });

  testWidgets('rejecting an empty task keeps the dialog open', (tester) async {
    await openApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('New care task'), findsOneWidget);
  });

  testWidgets('filtering by overdue hides non-overdue tasks', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Overdue only'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here. All caught up.'), findsOneWidget);
    expect(find.text('Vet checkup'), findsNothing);
  });

  testWidgets('completing a task starts a streak', (tester) async {
    await openApp(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Streak'), findsOneWidget);
    // streak of 1 shows in the hero stats
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('adding a pet makes it appear in the pets tab', (tester) async {
    await openApp(tester);
    await tester.tap(find.byIcon(Icons.pets).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Milo');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Milo'), findsOneWidget);
  });

  testWidgets('tasks and onboarding persist across a reload', (tester) async {
    await openApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Persistent task');
    await tester.enterText(find.byType(TextField).at(1), '2027-02-01');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // rebuild the app, simulating a restart with the same stored data
    await tester.pumpWidget(const PawCareApp());
    await tester.pumpAndSettle();
    // no onboarding the second time, and the task is still there
    expect(find.text('Get started'), findsNothing);
    expect(find.text('Persistent task'), findsOneWidget);
  });
}
