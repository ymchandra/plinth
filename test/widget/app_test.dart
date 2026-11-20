import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plinth/features/notes/domain/note.dart';

import '../support/app_harness.dart';
import '../support/test_env.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  void app(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      await body(t);
      // Dispose the tree so drift's stream-cleanup timers can fire.
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 100));
    });
  }

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  app('empty home shows onboarding and creates a note', (t) async {
    final env = TestEnv();
    addTearDown(() => t.runAsync(env.dispose));
    await t.pumpWidget(harness(env));
    await settle(t);
    expect(find.text('Write your first note'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await t.tap(find.widgetWithText(FilledButton, 'New note'));
    await settle(t);
    expect(find.text('Title'), findsOneWidget);
    expect(await t.runAsync(env.notes.countAll), 1);

    // Leaving an untouched new note discards it.
    await t.pageBack();
    await settle(t);
    expect(await t.runAsync(env.notes.countAll), 0);
  });

  app('list shows notes, trash confirm and undo', (t) async {
    final env = TestEnv();
    addTearDown(() => t.runAsync(env.dispose));
    await t.runAsync(() async {
      await env.notes.create(title: 'Groceries', contentJson: deltaOf('milk and eggs'));
      env.tick();
      await env.notes.create(title: 'Plans', contentJson: deltaOf('travel'), pinned: true);
    });
    await t.pumpWidget(harness(env));
    await settle(t);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);

    await t.longPress(find.text('Groceries'));
    await settle(t);
    await t.tap(find.text('Move to trash'));
    await settle(t);
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('Moved to trash'), findsOneWidget);
    await t.tap(find.text('Undo'));
    await settle(t);
    expect(find.text('Groceries'), findsOneWidget);
  });

  app('search finds notes and shows empty state', (t) async {
    final env = TestEnv();
    addTearDown(() => t.runAsync(env.dispose));
    await t.runAsync(() => env.notes.create(title: 'Recipe', contentJson: deltaOf('banana bread')));
    await t.pumpWidget(harness(env));
    await settle(t);
    await t.tap(find.text('Search').last);
    await settle(t);
    expect(find.text('Search all your notes'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'banana');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    expect(find.textContaining('Recipe'), findsWidgets);
    await t.enterText(find.byType(TextField), 'zzzz');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    expect(find.text('No matching notes'), findsOneWidget);
  });

  app('folders: create, and delete asks where notes go', (t) async {
    final env = TestEnv();
    addTearDown(() => t.runAsync(env.dispose));
    await t.pumpWidget(harness(env));
    await settle(t);
    await t.tap(find.text('Folders').last);
    await settle(t);
    expect(find.textContaining('No folders yet'), findsOneWidget);
    await t.tap(find.byTooltip('New folder'));
    await settle(t);
    await t.enterText(find.byType(TextField), 'Work');
    await t.tap(find.text('Create'));
    await settle(t);
    expect(find.text('Work'), findsOneWidget);
    await t.tap(find.byTooltip('More actions'));
    await settle(t);
    await t.tap(find.text('Delete folder'));
    await settle(t);
    expect(find.text('Move notes to the parent folder'), findsOneWidget);
    await t.tap(find.text('Leave notes unorganised'));
    await settle(t);
    expect(find.text('Work'), findsNothing);
  });

  app('settings: theme change applies', (t) async {
    final env = TestEnv();
    addTearDown(() => t.runAsync(env.dispose));
    await t.pumpWidget(harness(env));
    await settle(t);
    await t.tap(find.text('Settings').last);
    await settle(t);
    await t.tap(find.text('Theme'));
    await settle(t);
    await t.tap(find.text('Dark'));
    await settle(t);
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    await t.scrollUntilVisible(
      find.textContaining('never connects to the internet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('never connects to the internet'), findsOneWidget);
  });

  app('trash: delete forever requires confirmation', (t) async {
    final env = TestEnv();
    addTearDown(() => t.runAsync(env.dispose));
    await t.runAsync(() async {
      final n = await env.notes.create(title: 'Old', contentJson: deltaOf('x'));
      await env.notes.trash(n.id);
    });
    await t.pumpWidget(harness(env));
    await settle(t);
    await t.tap(find.text('Folders').last);
    await settle(t);
    await t.tap(find.text('Trash'));
    await settle(t);
    await t.tap(find.text('Old'));
    await settle(t);
    await t.tap(find.text('Delete permanently'));
    await settle(t);
    expect(find.text('Delete permanently?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(await t.runAsync(env.notes.countAll), 1);
  });

  app('editor autosaves title and body, and persists on reopen', (t) async {
    final env = TestEnv();
    addTearDown(() => t.runAsync(env.dispose));
    await t.pumpWidget(harness(env));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'New note'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextField, '').first, 'My title');
    await t.pump(const Duration(milliseconds: 1000));
    await settle(t);
    final all = await t.runAsync(() => env.notes.watchList(const NoteQuery()).first);
    expect(all!.single.title, 'My title');
    expect(find.text('Saved'), findsOneWidget);
    await t.pageBack();
    await settle(t);
    expect(find.text('My title'), findsOneWidget);
  });
}
