import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/database/tables.dart';
import '../../../core/errors/errors.dart';
import '../../../core/storage/attachment_storage.dart';
import '../domain/delta_text.dart';
import '../domain/note.dart';

class NoteRepository {
  NoteRepository(
    this._db, {
    AttachmentStorage? storage,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _storage = storage,
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final AttachmentStorage? _storage;
  final DateTime Function() _now;
  final Uuid _uuid;

  /// Creates and persists a note immediately, before any typing.
  Future<Note> create({
    String? folderId,
    String? title,
    String? contentJson,
    bool pinned = false,
  }) async {
    final id = _uuid.v4();
    final now = _now();
    final content = contentJson ?? emptyDeltaJson;
    await _db.transaction(() async {
      await _db
          .into(_db.notes)
          .insert(
            NotesCompanion.insert(
              id: id,
              title: Value(_cleanTitle(title)),
              content: Value(content),
              folderId: Value(folderId),
              isPinned: Value(pinned),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _reindex(id, _cleanTitle(title), content);
    });
    return (await getById(id))!;
  }

  /// Inserts a fully specified note (used by import). Call inside the
  /// caller's transaction; maintains derived fields and the search index.
  Future<void> insertRaw({
    required String id,
    String? title,
    required String contentJson,
    String? folderId,
    required bool isPinned,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) async {
    final clean = _cleanTitle(title);
    final plain = DeltaText.plainText(contentJson);
    await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            id: id,
            title: Value(clean),
            content: Value(contentJson),
            derivedTitle: Value(DeltaText.derivedTitle(plain)),
            preview: Value(
              DeltaText.preview(plain, skipFirstLine: clean == null),
            ),
            folderId: Value(folderId),
            isPinned: Value(isPinned),
            isArchived: Value(isArchived),
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: Value(deletedAt),
          ),
        );
    await _reindex(id, clean, contentJson, plain: plain);
  }

  Future<Note?> getById(String id) async {
    final row = await (_db.select(
      _db.notes,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toNote(row);
  }

  /// Persists title and content. Writes the FTS index in the same
  /// transaction. Throws [NotFoundException] if the note no longer exists.
  Future<void> updateContent(
    String id, {
    String? title,
    required String contentJson,
  }) async {
    final cleanTitle = _cleanTitle(title);
    final plain = DeltaText.plainText(contentJson);
    final derived = DeltaText.derivedTitle(plain);
    final preview = DeltaText.preview(plain, skipFirstLine: cleanTitle == null);
    await _db.transaction(() async {
      final updated =
          await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
            NotesCompanion(
              title: Value(cleanTitle),
              content: Value(contentJson),
              derivedTitle: Value(derived),
              preview: Value(preview),
              updatedAt: Value(_now()),
            ),
          );
      if (updated == 0) throw NotFoundException('Note');
      await _reindex(id, cleanTitle, contentJson, plain: plain);
    });
  }

  Future<void> touch(String id) =>
      (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(updatedAt: Value(_now())),
      );

  Future<void> setPinned(String id, bool value) =>
      _flag(id, NotesCompanion(isPinned: Value(value)));

  Future<void> setArchived(String id, bool value) =>
      _flag(id, NotesCompanion(isArchived: Value(value)));

  Future<void> moveToFolder(String id, String? folderId) =>
      _flag(id, NotesCompanion(folderId: Value(folderId)));

  Future<void> trash(String id) =>
      _flag(id, NotesCompanion(deletedAt: Value(_now())));

  Future<void> restore(String id) =>
      _flag(id, const NotesCompanion(deletedAt: Value(null)));

  Future<void> _flag(String id, NotesCompanion change) async {
    final n = await (_db.update(_db.notes)..where((t) => t.id.equals(id)))
        .write(change.copyWith(updatedAt: Value(_now())));
    if (n == 0) throw NotFoundException('Note');
  }

  Future<void> deletePermanently(String id) async {
    final paths = await _attachmentPaths([id]);
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM notes_fts WHERE note_id = ?', [
        id,
      ]);
      await (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();
    });
    await _deleteFiles(paths);
  }

  Future<int> emptyTrash() async {
    final ids = await _trashedIds(null);
    await _deleteMany(ids);
    return ids.length;
  }

  /// Permanently removes notes trashed more than [retention] ago.
  Future<int> purgeExpiredTrash(Duration retention) async {
    final ids = await _trashedIds(_now().subtract(retention));
    await _deleteMany(ids);
    return ids.length;
  }

  Future<List<String>> _trashedIds(DateTime? olderThan) async {
    final q = _db.selectOnly(_db.notes)
      ..addColumns([_db.notes.id])
      ..where(_db.notes.deletedAt.isNotNull());
    if (olderThan != null) {
      q.where(_db.notes.deletedAt.isSmallerThanValue(olderThan));
    }
    return (await q.get()).map((r) => r.read(_db.notes.id)!).toList();
  }

  Future<void> _deleteMany(List<String> ids) async {
    if (ids.isEmpty) return;
    final paths = await _attachmentPaths(ids);
    await _db.transaction(() async {
      for (final id in ids) {
        await _db.customStatement('DELETE FROM notes_fts WHERE note_id = ?', [
          id,
        ]);
      }
      await (_db.delete(_db.notes)..where((n) => n.id.isIn(ids))).go();
    });
    await _deleteFiles(paths);
  }

  Future<List<String>> _attachmentPaths(List<String> noteIds) async {
    final rows = await (_db.select(
      _db.attachments,
    )..where((a) => a.noteId.isIn(noteIds))).get();
    return rows.map((a) => a.localPath).toList();
  }

  Future<void> _deleteFiles(List<String> paths) async {
    final s = _storage;
    if (s == null) return;
    for (final p in paths) {
      await s.delete(p);
    }
  }

  /// Copies a note including tags and attachment files.
  Future<Note> duplicate(String id, {String? copySuffix}) async {
    final src = await getById(id);
    if (src == null) throw NotFoundException('Note');
    final newId = _uuid.v4();
    final now = _now();
    final tagRows = await (_db.select(
      _db.noteTags,
    )..where((t) => t.noteId.equals(id))).get();
    final attachments = await (_db.select(
      _db.attachments,
    )..where((a) => a.noteId.equals(id))).get();

    final copiedFiles = <String>[];
    final newAttachments = <AttachmentsCompanion>[];
    try {
      for (final a in attachments) {
        final attId = _uuid.v4();
        final storage = _storage;
        var rel = a.localPath;
        if (storage != null && await storage.resolve(a.localPath).exists()) {
          rel = await storage.copy(a.localPath, attId);
          copiedFiles.add(rel);
        } else {
          continue; // Missing source file: nothing to duplicate.
        }
        newAttachments.add(
          AttachmentsCompanion.insert(
            id: attId,
            noteId: newId,
            localPath: rel,
            filename: a.filename,
            mimeType: a.mimeType,
            fileSize: a.fileSize,
            createdAt: now,
          ),
        );
      }
      final title = src.title == null || src.title!.trim().isEmpty
          ? null
          : '${src.title}${copySuffix ?? ' (copy)'}';
      await _db.transaction(() async {
        await _db
            .into(_db.notes)
            .insert(
              NotesCompanion.insert(
                id: newId,
                title: Value(title),
                content: Value(src.content),
                folderId: Value(src.folderId),
                isPinned: const Value(false),
                isArchived: Value(src.isArchived),
                createdAt: now,
                updatedAt: now,
              ),
            );
        for (final t in tagRows) {
          await _db
              .into(_db.noteTags)
              .insert(NoteTagsCompanion.insert(noteId: newId, tagId: t.tagId));
        }
        for (final a in newAttachments) {
          await _db.into(_db.attachments).insert(a);
        }
        await _refreshDerived(newId, title, src.content);
      });
    } catch (_) {
      for (final f in copiedFiles) {
        await _storage?.delete(f);
      }
      rethrow;
    }
    return (await getById(newId))!;
  }

  Future<void> _refreshDerived(String id, String? title, String content) async {
    final plain = DeltaText.plainText(content);
    await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        derivedTitle: Value(DeltaText.derivedTitle(plain)),
        preview: Value(DeltaText.preview(plain, skipFirstLine: title == null)),
      ),
    );
    await _reindex(id, title, content, plain: plain);
  }

  Stream<List<NoteSummary>> watchList(NoteQuery query, {int limit = 50}) {
    final n = _db.notes;
    final f = _db.folders;
    final q = _db.selectOnly(n).join([
      leftOuterJoin(f, f.id.equalsExp(n.folderId)),
    ]);
    q.addColumns([
      n.id,
      n.title,
      n.derivedTitle,
      n.preview,
      n.folderId,
      f.name,
      n.isPinned,
      n.isArchived,
      n.createdAt,
      n.updatedAt,
      n.deletedAt,
    ]);
    switch (query.scope) {
      case NoteScope.active:
        q.where(n.deletedAt.isNull() & n.isArchived.equals(false));
      case NoteScope.archived:
        q.where(n.deletedAt.isNull() & n.isArchived.equals(true));
      case NoteScope.trashed:
        q.where(n.deletedAt.isNotNull());
    }
    if (query.folderId != null) q.where(n.folderId.equals(query.folderId!));
    if (query.unfiledOnly) q.where(n.folderId.isNull());
    if (query.pinned != null) q.where(n.isPinned.equals(query.pinned!));
    if (query.tagId != null) {
      final nt = _db.noteTags;
      q.where(
        n.id.isInQuery(
          _db.selectOnly(nt)
            ..addColumns([nt.noteId])
            ..where(nt.tagId.equals(query.tagId!)),
        ),
      );
    }
    final order = <OrderingTerm>[];
    if (query.pinnedFirst) {
      order.add(OrderingTerm.desc(n.isPinned));
    }
    if (query.scope == NoteScope.trashed) {
      order.add(OrderingTerm.desc(n.deletedAt));
    } else {
      switch (query.sort) {
        case SortOrder.updatedDesc:
          order.add(OrderingTerm.desc(n.updatedAt));
        case SortOrder.createdDesc:
          order.add(OrderingTerm.desc(n.createdAt));
        case SortOrder.titleAsc:
          order.add(
            OrderingTerm.asc(
              CustomExpression<String>(
                "lower(coalesce(nullif(trim(notes.title), ''), notes.derived_title))",
              ),
            ),
          );
      }
    }
    order.add(OrderingTerm.asc(n.id));
    q
      ..orderBy(order)
      ..limit(limit);
    return q.watch().map(
      (rows) => rows
          .map(
            (r) => NoteSummary(
              id: r.read(n.id)!,
              title: r.read(n.title),
              derivedTitle: r.read(n.derivedTitle) ?? '',
              preview: r.read(n.preview) ?? '',
              folderId: r.read(n.folderId),
              folderName: r.read(f.name),
              isPinned: r.read(n.isPinned) ?? false,
              isArchived: r.read(n.isArchived) ?? false,
              createdAt: r.read(n.createdAt)!,
              updatedAt: r.read(n.updatedAt)!,
              deletedAt: r.read(n.deletedAt),
            ),
          )
          .toList(),
    );
  }

  Future<int> countAll() async {
    final c = _db.notes.id.count();
    final row = await (_db.selectOnly(_db.notes)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  /// Rebuilds the full-text index from stored content (recovery tool).
  Future<void> rebuildSearchIndex() async {
    final rows = await _db.select(_db.notes).get();
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM notes_fts');
      for (final r in rows) {
        await _reindex(r.id, r.title, r.content);
      }
    });
  }

  Future<void> _reindex(
    String id,
    String? title,
    String content, {
    String? plain,
  }) async {
    String body;
    try {
      body = plain ?? DeltaText.plainText(content);
    } on FormatException {
      body = '';
    }
    await _db.customStatement('DELETE FROM notes_fts WHERE note_id = ?', [id]);
    await _db.customStatement(
      'INSERT INTO notes_fts(note_id, title, body) VALUES (?, ?, ?)',
      [id, title ?? '', body],
    );
  }

  String? _cleanTitle(String? t) {
    final s = t?.trim();
    return s == null || s.isEmpty ? null : s;
  }

  Note _toNote(NoteRow r) => Note(
    id: r.id,
    title: r.title,
    content: r.content,
    folderId: r.folderId,
    isPinned: r.isPinned,
    isArchived: r.isArchived,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    deletedAt: r.deletedAt,
  );
}
