import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:plinth/core/database/database.dart';
import 'package:plinth/core/storage/attachment_storage.dart';
import 'package:plinth/features/attachments/data/attachment_repository.dart';
import 'package:plinth/features/folders/data/folder_repository.dart';
import 'package:plinth/features/notes/data/note_repository.dart';
import 'package:plinth/features/search/data/search_repository.dart';
import 'package:plinth/features/settings/data/settings_repository.dart';
import 'package:plinth/features/tags/data/tag_repository.dart';

/// In-memory database plus repositories sharing one controllable clock.
class TestEnv {
  TestEnv() {
    db = AppDatabase(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('plinth_test_');
    storage = AttachmentStorage(Directory('${tmp.path}/attachments'));
    notes = NoteRepository(db, storage: storage, now: () => clock);
    folders = FolderRepository(db, now: () => clock);
    tags = TagRepository(db, now: () => clock);
    search = SearchRepository(db, now: () => clock);
    settings = SettingsRepository(db);
    attachments = AttachmentRepository(db, storage, now: () => clock);
  }

  DateTime clock = DateTime.utc(2025, 1, 1, 12);
  late final AppDatabase db;
  late final Directory tmp;
  late final AttachmentStorage storage;
  late final NoteRepository notes;
  late final FolderRepository folders;
  late final TagRepository tags;
  late final SearchRepository search;
  late final SettingsRepository settings;
  late final AttachmentRepository attachments;

  void tick([Duration d = const Duration(minutes: 1)]) => clock = clock.add(d);

  Future<void> dispose() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  }
}

/// Delta JSON for plain [text].
String deltaOf(String text) => jsonEncode([
  {'insert': '$text\n'},
]);
