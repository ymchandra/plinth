import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plinth/app/app.dart';
import 'package:plinth/app/providers.dart';
import 'package:plinth/core/database/database.dart';
import 'package:plinth/core/storage/attachment_storage.dart';

/// End-to-end flow against a real file-backed database. Run on a device or
/// simulator: `flutter test integration_test`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create, edit, restart, search, trash and restore', (t) async {
    final dir = await Directory.systemTemp.createTemp('plinth_it_');
    Future<void> launch() async {
      final db = AppDatabase.file(File('${dir.path}/plinth.sqlite'));
      await t.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            databaseProvider.overrideWithValue(db),
            attachmentStorageProvider.overrideWithValue(
              AttachmentStorage(Directory('${dir.path}/attachments')),
            ),
          ],
          child: const PlinthApp(),
        ),
      );
      await t.pumpAndSettle();
    }

    await launch();
    expect(find.text('Write your first note'), findsOneWidget);

    await t.tap(find.widgetWithText(FilledButton, 'New note'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, '').first, 'Trip plan');
    await t.pump(const Duration(seconds: 2));
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Trip plan'), findsOneWidget);

    // Simulated restart: rebuild the whole app on the same files.
    await launch();
    expect(find.text('Trip plan'), findsOneWidget);

    await t.tap(find.text('Search').last);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'trip');
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    expect(find.textContaining('Trip plan'), findsWidgets);

    await t.tap(find.text('Home').last);
    await t.pumpAndSettle();
    await t.longPress(find.text('Trip plan'));
    await t.pumpAndSettle();
    await t.tap(find.text('Move to trash'));
    await t.pumpAndSettle();
    expect(find.text('Trip plan'), findsNothing);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(find.text('Trip plan'), findsOneWidget);
  });
}
