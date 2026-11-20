import 'package:drift/drift.dart';

const emptyDeltaJson = '[{"insert":"\\n"}]';

@TableIndex(name: 'idx_folders_parent', columns: {#parentFolderId})
@DataClassName("FolderRow")
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentFolderId =>
      text().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_notes_folder', columns: {#folderId})
@TableIndex(name: 'idx_notes_updated', columns: {#updatedAt})
@TableIndex(name: 'idx_notes_created', columns: {#createdAt})
@TableIndex(
  name: 'idx_notes_list',
  columns: {#deletedAt, #isArchived, #isPinned, #updatedAt},
)
@DataClassName("NoteRow")
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().nullable()();

  /// Quill delta serialised as a JSON array.
  TextColumn get content =>
      text().withDefault(const Constant(emptyDeltaJson))();

  /// First meaningful line, used when [title] is empty.
  TextColumn get derivedTitle => text().withDefault(const Constant(''))();
  TextColumn get preview => text().withDefault(const Constant(''))();
  TextColumn get folderId =>
      text().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName("TagRow")
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_note_tags_tag', columns: {#tagId})
class NoteTags extends Table {
  TextColumn get noteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

@TableIndex(name: 'idx_attachments_note', columns: {#noteId})
@DataClassName("AttachmentRow")
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get noteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();

  /// Path relative to the private attachments directory.
  TextColumn get localPath => text()();
  TextColumn get filename => text()();
  TextColumn get mimeType => text()();
  IntColumn get fileSize => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName("RecentSearchRow")
class RecentSearches extends Table {
  TextColumn get id => text()();
  TextColumn get query => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SettingsEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
