import '../../../core/database/database.dart';
import '../../notes/domain/note.dart';

enum ThemePreference { system, light, dark }

enum LandingScreen { home, search, folders }

enum EditorFontSize { small, medium, large }

class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.landing = LandingScreen.home,
    this.sortOrder = SortOrder.updatedDesc,
    this.editorFontSize = EditorFontSize.medium,

    /// Days before trashed notes are removed; 0 keeps them until deleted.
    this.trashRetentionDays = 30,
  });

  final ThemePreference theme;
  final LandingScreen landing;
  final SortOrder sortOrder;
  final EditorFontSize editorFontSize;
  final int trashRetentionDays;

  static const retentionOptions = [7, 30, 90, 0];

  AppSettings copyWith({
    ThemePreference? theme,
    LandingScreen? landing,
    SortOrder? sortOrder,
    EditorFontSize? editorFontSize,
    int? trashRetentionDays,
  }) => AppSettings(
    theme: theme ?? this.theme,
    landing: landing ?? this.landing,
    sortOrder: sortOrder ?? this.sortOrder,
    editorFontSize: editorFontSize ?? this.editorFontSize,
    trashRetentionDays: trashRetentionDays ?? this.trashRetentionDays,
  );

  double get editorScale => switch (editorFontSize) {
    EditorFontSize.small => 0.9,
    EditorFontSize.medium => 1.0,
    EditorFontSize.large => 1.2,
  };
}

class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  Future<AppSettings> load() async {
    final rows = await _db.select(_db.settingsEntries).get();
    final m = {for (final r in rows) r.key: r.value};
    T pick<T extends Enum>(List<T> values, String key, T fallback) {
      final v = m[key];
      for (final e in values) {
        if (e.name == v) return e;
      }
      return fallback;
    }

    final retention = int.tryParse(m['trashRetentionDays'] ?? '');
    return AppSettings(
      theme: pick(ThemePreference.values, 'theme', ThemePreference.system),
      landing: pick(LandingScreen.values, 'landing', LandingScreen.home),
      sortOrder: pick(SortOrder.values, 'sortOrder', SortOrder.updatedDesc),
      editorFontSize: pick(
        EditorFontSize.values,
        'editorFontSize',
        EditorFontSize.medium,
      ),
      trashRetentionDays: retention != null && retention >= 0 ? retention : 30,
    );
  }

  Future<void> save(AppSettings s) async {
    final entries = {
      'theme': s.theme.name,
      'landing': s.landing.name,
      'sortOrder': s.sortOrder.name,
      'editorFontSize': s.editorFontSize.name,
      'trashRetentionDays': '${s.trashRetentionDays}',
    };
    await _db.batch((b) {
      b.insertAllOnConflictUpdate(_db.settingsEntries, [
        for (final e in entries.entries)
          SettingsEntriesCompanion.insert(key: e.key, value: e.value),
      ]);
    });
  }
}
