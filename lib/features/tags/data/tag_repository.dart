import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/errors/errors.dart';

class Tag {
  const Tag({required this.id, required this.name, this.noteCount = 0});
  final String id;
  final String name;
  final int noteCount;
}

class TagRepository {
  TagRepository(this._db, {DateTime Function()? now, Uuid? uuid})
    : _now = now ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _now;
  final Uuid _uuid;

  /// All tags with the number of live (non-trashed) notes using them.
  Stream<List<Tag>> watchAll() {
    return _db
        .customSelect(
          'SELECT t.id AS id, t.name AS name, '
          '(SELECT COUNT(*) FROM note_tags nt JOIN notes n ON n.id = nt.note_id '
          'WHERE nt.tag_id = t.id AND n.deleted_at IS NULL) AS cnt '
          'FROM tags t ORDER BY t.name COLLATE NOCASE',
          readsFrom: {_db.tags, _db.noteTags, _db.notes},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (r) => Tag(
                  id: r.read<String>('id'),
                  name: r.read<String>('name'),
                  noteCount: r.read<int>('cnt'),
                ),
              )
              .toList(),
        );
  }

  Stream<List<Tag>> watchForNote(String noteId) {
    final q =
        _db.select(_db.tags).join([
            innerJoin(_db.noteTags, _db.noteTags.tagId.equalsExp(_db.tags.id)),
          ])
          ..where(_db.noteTags.noteId.equals(noteId))
          ..orderBy([OrderingTerm.asc(_db.tags.name)]);
    return q.watch().map(
      (rows) => rows
          .map((r) => r.readTable(_db.tags))
          .map((t) => Tag(id: t.id, name: t.name))
          .toList(),
    );
  }

  /// Creates a tag, or returns the existing one with the same name
  /// (case-insensitive).
  Future<Tag> create(String name) async {
    final clean = _validName(name);
    final existing = await _findByName(clean);
    if (existing != null) return existing;
    final id = _uuid.v4();
    await _db
        .into(_db.tags)
        .insert(TagsCompanion.insert(id: id, name: clean, createdAt: _now()));
    return Tag(id: id, name: clean);
  }

  Future<void> rename(String id, String name) async {
    final clean = _validName(name);
    final existing = await _findByName(clean);
    if (existing != null && existing.id != id) {
      throw DuplicateTagException(clean);
    }
    final n = await (_db.update(
      _db.tags,
    )..where((t) => t.id.equals(id))).write(TagsCompanion(name: Value(clean)));
    if (n == 0) throw NotFoundException('Tag');
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();

  Future<void> addToNote(String noteId, String tagId) => _db
      .into(_db.noteTags)
      .insert(
        NoteTagsCompanion.insert(noteId: noteId, tagId: tagId),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> removeFromNote(String noteId, String tagId) => (_db.delete(
    _db.noteTags,
  )..where((t) => t.noteId.equals(noteId) & t.tagId.equals(tagId))).go();

  Future<Tag?> _findByName(String name) async {
    final rows = await _db
        .customSelect(
          'SELECT id, name FROM tags WHERE name = ? COLLATE NOCASE',
          variables: [Variable<String>(name)],
        )
        .get();
    if (rows.isEmpty) return null;
    return Tag(
      id: rows.first.read<String>('id'),
      name: rows.first.read<String>('name'),
    );
  }

  String _validName(String name) {
    final t = name.trim();
    if (t.isEmpty) throw ValidationException('Name is required');
    return t;
  }
}
