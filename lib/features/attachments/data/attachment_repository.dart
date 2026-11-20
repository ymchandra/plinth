import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/errors/errors.dart';
import '../../../core/storage/attachment_storage.dart';

class Attachment {
  const Attachment({
    required this.id,
    required this.noteId,
    required this.localPath,
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    required this.createdAt,
  });
  final String id;
  final String noteId;
  final String localPath;
  final String filename;
  final String mimeType;
  final int fileSize;
  final DateTime createdAt;
}

String mimeTypeForFilename(String filename) {
  final f = filename.toLowerCase();
  if (f.endsWith('.png')) return 'image/png';
  if (f.endsWith('.gif')) return 'image/gif';
  if (f.endsWith('.webp')) return 'image/webp';
  if (f.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}

class AttachmentRepository {
  AttachmentRepository(
    this._db,
    this.storage, {
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final AttachmentStorage storage;
  final DateTime Function() _now;
  final Uuid _uuid;

  Stream<List<Attachment>> watchForNote(String noteId) =>
      (_db.select(_db.attachments)
            ..where((a) => a.noteId.equals(noteId))
            ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .watch()
          .map((rows) => rows.map(_map).toList());

  /// Copies [source] into private storage and records its metadata.
  Future<Attachment> addFromFile(
    String noteId,
    File source, {
    String? filename,
  }) async {
    final name = filename ?? source.uri.pathSegments.last;
    final id = _uuid.v4();
    final rel = await storage.storeFile(source, id, name);
    return _insert(noteId, id, rel, name, await storage.resolve(rel).length());
  }

  Future<Attachment> addFromBytes(
    String noteId,
    Uint8List bytes,
    String filename,
  ) async {
    final id = _uuid.v4();
    final rel = await storage.storeBytes(bytes, id, filename);
    return _insert(noteId, id, rel, filename, bytes.length);
  }

  Future<Attachment> _insert(
    String noteId,
    String id,
    String rel,
    String name,
    int size,
  ) async {
    final now = _now();
    try {
      await _db.transaction(() async {
        final exists = await (_db.select(
          _db.notes,
        )..where((n) => n.id.equals(noteId))).getSingleOrNull();
        if (exists == null) throw NotFoundException('Note');
        await _db
            .into(_db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: id,
                noteId: noteId,
                localPath: rel,
                filename: name,
                mimeType: mimeTypeForFilename(name),
                fileSize: size,
                createdAt: now,
              ),
            );
        await (_db.update(_db.notes)..where((n) => n.id.equals(noteId))).write(
          NotesCompanion(updatedAt: Value(now)),
        );
      });
    } catch (_) {
      await storage.delete(rel);
      rethrow;
    }
    return Attachment(
      id: id,
      noteId: noteId,
      localPath: rel,
      filename: name,
      mimeType: mimeTypeForFilename(name),
      fileSize: size,
      createdAt: now,
    );
  }

  Future<void> remove(String id) async {
    final row = await (_db.select(
      _db.attachments,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
    await storage.delete(row.localPath);
  }

  File fileFor(Attachment a) => storage.resolve(a.localPath);

  Attachment _map(AttachmentRow r) => Attachment(
    id: r.id,
    noteId: r.noteId,
    localPath: r.localPath,
    filename: r.filename,
    mimeType: r.mimeType,
    fileSize: r.fileSize,
    createdAt: r.createdAt,
  );
}
