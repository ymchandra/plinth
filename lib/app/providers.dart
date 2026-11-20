import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart';
import '../core/storage/attachment_storage.dart';
import '../features/attachments/data/attachment_repository.dart';
import '../features/backup/data/backup_service.dart';
import '../features/folders/data/folder_repository.dart';
import '../features/notes/data/note_repository.dart';
import '../features/notes/domain/note.dart';
import '../features/search/data/search_repository.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/tags/data/tag_repository.dart';

// Overridden in main() / tests with real instances.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);
final attachmentStorageProvider = Provider<AttachmentStorage>(
  (ref) => throw UnimplementedError('attachmentStorageProvider'),
);
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

final noteRepositoryProvider = Provider(
  (ref) => NoteRepository(
    ref.watch(databaseProvider),
    storage: ref.watch(attachmentStorageProvider),
  ),
);
final folderRepositoryProvider = Provider(
  (ref) => FolderRepository(ref.watch(databaseProvider)),
);
final tagRepositoryProvider = Provider(
  (ref) => TagRepository(ref.watch(databaseProvider)),
);
final searchRepositoryProvider = Provider(
  (ref) => SearchRepository(ref.watch(databaseProvider)),
);
final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);
final attachmentRepositoryProvider = Provider(
  (ref) => AttachmentRepository(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
  ),
);
final backupServiceProvider = Provider(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    ref.watch(attachmentStorageProvider),
    ref.watch(noteRepositoryProvider),
  ),
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  Future<void> update(AppSettings Function(AppSettings) change) async {
    final next = change(state);
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

final foldersProvider = StreamProvider(
  (ref) => ref.watch(folderRepositoryProvider).watchAll(),
);
final tagsProvider = StreamProvider(
  (ref) => ref.watch(tagRepositoryProvider).watchAll(),
);
final noteTagsProvider = StreamProvider.family(
  (ref, String noteId) => ref.watch(tagRepositoryProvider).watchForNote(noteId),
);
final attachmentsProvider = StreamProvider.family(
  (ref, String noteId) =>
      ref.watch(attachmentRepositoryProvider).watchForNote(noteId),
);
final recentSearchesProvider = StreamProvider(
  (ref) => ref.watch(searchRepositoryProvider).watchRecent(),
);

/// Sort order from settings applied to a list query.
NoteQuery withSort(NoteQuery q, AppSettings s) => NoteQuery(
  scope: q.scope,
  folderId: q.folderId,
  unfiledOnly: q.unfiledOnly,
  tagId: q.tagId,
  pinned: q.pinned,
  sort: s.sortOrder,
  pinnedFirst: q.pinnedFirst,
);
