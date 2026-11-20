import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/database/database.dart';
import 'core/storage/attachment_storage.dart';
import 'features/notes/data/note_repository.dart';
import 'features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppDatabase? db;
  try {
    final support = await getApplicationSupportDirectory();
    db = AppDatabase.file(File(p.join(support.path, 'plinth.sqlite')));
    final storage = AttachmentStorage(
      Directory(p.join(support.path, 'attachments')),
    );
    final settingsRepo = SettingsRepository(db);
    final settings = await settingsRepo.load();
    await _purgeTrash(db, storage, settings);
    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          attachmentStorageProvider.overrideWithValue(storage),
          initialSettingsProvider.overrideWithValue(settings),
        ],
        child: const PlinthApp(),
      ),
    );
  } catch (e) {
    await db?.close();
    runApp(StartupErrorApp(error: e));
  }
}

/// Removes notes that have been in the trash longer than the user's setting.
Future<void> _purgeTrash(
  AppDatabase db,
  AttachmentStorage storage,
  AppSettings settings,
) async {
  if (settings.trashRetentionDays <= 0) return;
  try {
    await NoteRepository(
      db,
      storage: storage,
    ).purgeExpiredTrash(Duration(days: settings.trashRetentionDays));
  } catch (_) {
    // A failed purge must never block startup.
  }
}
