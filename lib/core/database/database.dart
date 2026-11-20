import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'tables.dart';

part 'database.g.dart';

const currentSchemaVersion = 1;

class DatabaseTooNewException implements Exception {
  DatabaseTooNewException(this.found, this.supported);
  final int found;
  final int supported;
  @override
  String toString() =>
      'Database schema $found is newer than supported version $supported.';
}

@DriftDatabase(
  tables: [
    Folders,
    Notes,
    Tags,
    NoteTags,
    Attachments,
    RecentSearches,
    SettingsEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens a file-backed database. A copy of the file is taken before any
  /// schema upgrade so a failed migration never destroys user data.
  factory AppDatabase.file(File file) {
    backupBeforeMigration(file);
    return AppDatabase(NativeDatabase.createInBackground(file));
  }

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createFts();
    },
    onUpgrade: (m, from, to) async {
      // Future schema changes go here as `if (from < N)` steps.
      await _createFts();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.versionBefore != null &&
          details.versionBefore! > currentSchemaVersion) {
        throw DatabaseTooNewException(
          details.versionBefore!,
          currentSchemaVersion,
        );
      }
      await _createFts();
    },
  );

  Future<void> _createFts() => customStatement(
    'CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5('
    'note_id UNINDEXED, title, body, '
    "tokenize = 'unicode61 remove_diacritics 2')",
  );
}

/// Copies [file] to `<file>.bak-v<N>` when its schema is older than the
/// current one. Returns the backup file, or null when none was needed.
File? backupBeforeMigration(File file) {
  if (!file.existsSync()) return null;
  final db = sqlite.sqlite3.open(file.path);
  try {
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version > 0 && version < currentSchemaVersion) {
      return file.copySync('${file.path}.bak-v$version');
    }
  } finally {
    db.close();
  }
  return null;
}
