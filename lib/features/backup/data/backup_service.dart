import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/storage/attachment_storage.dart';
import '../../attachments/data/attachment_repository.dart'
    show mimeTypeForFilename;
import '../../notes/data/note_repository.dart';
import '../../notes/domain/delta_text.dart';
import '../domain/markdown_exporter.dart';

const exportFormat = 'plinth-export';
const exportVersion = 1;

class ImportException implements Exception {
  ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ExportResult {
  const ExportResult({
    required this.file,
    required this.notes,
    required this.attachments,
    required this.missingAttachments,
  });
  final File file;
  final int notes;
  final int attachments;
  final int missingAttachments;
}

class ImportPreview {
  const ImportPreview({
    required this.notes,
    required this.folders,
    required this.tags,
    required this.attachments,
    required this.warnings,
  });
  final int notes;
  final int folders;
  final int tags;
  final int attachments;
  final List<String> warnings;
}

class ImportResult {
  const ImportResult({
    required this.notes,
    required this.copiedBecauseIdExisted,
    required this.attachments,
  });
  final int notes;
  final int copiedBecauseIdExisted;
  final int attachments;
}

/// A validated archive awaiting confirmation. Nothing is written until
/// [commit]; dropping the session (or calling [cancel]) imports nothing.
class ImportSession {
  ImportSession._(this.preview, this._commit);
  final ImportPreview preview;
  final Future<ImportResult> Function(bool Function() cancelled) _commit;
  bool _cancelled = false;

  void cancel() => _cancelled = true;
  Future<ImportResult> commit() => _commit(() => _cancelled);
}

class BackupService {
  BackupService(
    this._db,
    this._storage,
    this._notes, {
    DateTime Function()? now,
    Uuid? uuid,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final AttachmentStorage _storage;
  final NoteRepository _notes;
  final DateTime Function() _now;
  final Uuid _uuid;

  // ---------------------------------------------------------------- export

  /// Writes `plinth-export-<timestamp>.zip` into [outDir].
  Future<ExportResult> exportAll(Directory outDir) async {
    final folders = await _db.select(_db.folders).get();
    final tags = await _db.select(_db.tags).get();
    final noteTags = await _db.select(_db.noteTags).get();
    final attachments = await _db.select(_db.attachments).get();
    final notes = await _db.select(_db.notes).get();

    final files = <String, Uint8List>{};
    final tagIdsByNote = <String, List<String>>{};
    for (final nt in noteTags) {
      tagIdsByNote.putIfAbsent(nt.noteId, () => []).add(nt.tagId);
    }
    final attsByNote = <String, List<Map<String, dynamic>>>{};
    var missing = 0;
    var exportedAtts = 0;
    for (final a in attachments) {
      final file = _storage.resolve(a.localPath);
      if (!await file.exists()) {
        missing++;
        continue;
      }
      final path = 'attachments/${a.noteId}/${a.id}${_ext(a.filename)}';
      files[path] = await file.readAsBytes();
      exportedAtts++;
      attsByNote.putIfAbsent(a.noteId, () => []).add({
        'id': a.id,
        'filename': a.filename,
        'mimeType': a.mimeType,
        'fileSize': a.fileSize,
        'createdAt': _iso(a.createdAt),
        'path': path,
      });
    }

    final noteEntries = <Map<String, dynamic>>[];
    for (final n in notes) {
      String md;
      Object content;
      try {
        md = MarkdownExporter.export(n.content, title: n.title);
        content = jsonDecode(n.content);
      } on FormatException {
        md = '';
        content = jsonDecode('[{"insert":"\\n"}]');
      }
      final mdPath =
          'notes/${_slug(n.title ?? n.derivedTitle)}-${n.id.substring(0, 8)}.md';
      files[mdPath] = Uint8List.fromList(utf8.encode(md));
      noteEntries.add({
        'id': n.id,
        'title': n.title,
        'content': content,
        'markdown': mdPath,
        'folderId': n.folderId,
        'isPinned': n.isPinned,
        'isArchived': n.isArchived,
        'createdAt': _iso(n.createdAt),
        'updatedAt': _iso(n.updatedAt),
        'deletedAt': n.deletedAt == null ? null : _iso(n.deletedAt!),
        'tagIds': tagIdsByNote[n.id] ?? <String>[],
        'attachments': attsByNote[n.id] ?? <Map<String, dynamic>>[],
      });
    }

    final manifest = {
      'format': exportFormat,
      'version': exportVersion,
      'exportedAt': _iso(_now()),
      'folders': [
        for (final f in folders)
          {
            'id': f.id,
            'name': f.name,
            'parentFolderId': f.parentFolderId,
            'createdAt': _iso(f.createdAt),
            'updatedAt': _iso(f.updatedAt),
          },
      ],
      'tags': [
        for (final t in tags)
          {'id': t.id, 'name': t.name, 'createdAt': _iso(t.createdAt)},
      ],
      'notes': noteEntries,
    };
    files['manifest.json'] = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)),
    );
    files['README.txt'] = Uint8List.fromList(utf8.encode(_readme));

    final zip = await _encodeInIsolate(files);
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final stamp = _now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final out = File('${outDir.path}/plinth-export-$stamp.zip');
    await out.writeAsBytes(zip, flush: true);
    return ExportResult(
      file: out,
      notes: notes.length,
      attachments: exportedAtts,
      missingAttachments: missing,
    );
  }

  // ---------------------------------------------------------------- import

  /// Parses and validates [zipBytes]. Throws [ImportException] when the
  /// archive is malformed or unsupported.
  Future<ImportSession> prepareImport(Uint8List zipBytes) async {
    Map<String, Uint8List> files;
    try {
      files = await _decodeInIsolate(zipBytes);
      if (files.isEmpty) throw const FormatException();
    } catch (_) {
      throw ImportException('The file is not a valid ZIP archive.');
    }
    final manifestBytes = files['manifest.json'];
    if (manifestBytes == null) {
      throw ImportException(
        'manifest.json is missing; this is not a Plinth export.',
      );
    }
    final Map<String, dynamic> manifest;
    try {
      final decoded = jsonDecode(utf8.decode(manifestBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      manifest = decoded;
    } on FormatException {
      throw ImportException('manifest.json is not valid JSON.');
    }
    if (manifest['format'] != exportFormat) {
      throw ImportException('Unrecognised export format.');
    }
    final version = manifest['version'];
    if (version is! int || version < 1) {
      throw ImportException('Missing or invalid export version.');
    }
    if (version > exportVersion) {
      throw ImportException(
        'This export (version $version) was made by a newer Plinth.',
      );
    }
    final parsed = _validate(manifest, files);
    return ImportSession._(
      parsed.preview,
      (cancelled) => _commit(parsed, files, cancelled),
    );
  }

  _Parsed _validate(Map<String, dynamic> m, Map<String, Uint8List> files) {
    List<Map<String, dynamic>> list(String key) {
      final v = m[key];
      if (v is! List) throw ImportException('"$key" must be a list.');
      return [
        for (final e in v)
          if (e is Map<String, dynamic>)
            e
          else
            throw ImportException('"$key" contains an invalid entry.'),
      ];
    }

    String str(Map<String, dynamic> e, String key, String ctx) {
      final v = e[key];
      if (v is! String || v.isEmpty) {
        throw ImportException('$ctx: "$key" is missing or invalid.');
      }
      return v;
    }

    DateTime date(Map<String, dynamic> e, String key, String ctx) {
      final d = DateTime.tryParse(str(e, key, ctx));
      if (d == null) throw ImportException('$ctx: "$key" is not a valid date.');
      return d;
    }

    final warnings = <String>[];
    final folders = <_PFolder>[];
    final folderIds = <String>{};
    for (final f in list('folders')) {
      final id = str(f, 'id', 'Folder');
      if (!folderIds.add(id)) throw ImportException('Duplicate folder id $id.');
      folders.add(
        _PFolder(
          id,
          str(f, 'name', 'Folder $id'),
          f['parentFolderId'] as String?,
          date(f, 'createdAt', 'Folder $id'),
          date(f, 'updatedAt', 'Folder $id'),
        ),
      );
    }
    for (final f in folders) {
      if (f.parentId != null && !folderIds.contains(f.parentId)) {
        throw ImportException('Folder ${f.id} references a missing parent.');
      }
    }
    final byId = {for (final f in folders) f.id: f};
    for (final f in folders) {
      var cur = f;
      final seen = <String>{};
      while (cur.parentId != null) {
        if (!seen.add(cur.id)) {
          throw ImportException('Folder hierarchy contains a cycle.');
        }
        cur = byId[cur.parentId]!;
      }
    }

    final tags = <_PTag>[];
    final tagIds = <String>{};
    for (final t in list('tags')) {
      final id = str(t, 'id', 'Tag');
      if (!tagIds.add(id)) throw ImportException('Duplicate tag id $id.');
      tags.add(
        _PTag(id, str(t, 'name', 'Tag $id'), date(t, 'createdAt', 'Tag $id')),
      );
    }

    final notes = <_PNote>[];
    final noteIds = <String>{};
    var attachmentCount = 0;
    for (final n in list('notes')) {
      final id = str(n, 'id', 'Note');
      final ctx = 'Note $id';
      if (!noteIds.add(id)) throw ImportException('Duplicate note id $id.');
      final content = n['content'];
      if (content is! List) {
        throw ImportException('$ctx: content must be a delta list.');
      }
      final contentJson = jsonEncode(content);
      if (!DeltaText.isValid(contentJson)) {
        throw ImportException('$ctx: content is not a valid document.');
      }
      final title = n['title'];
      if (title != null && title is! String) {
        throw ImportException('$ctx: title must be text.');
      }
      final folderId = n['folderId'] as String?;
      if (folderId != null && !folderIds.contains(folderId)) {
        throw ImportException('$ctx references a missing folder.');
      }
      final noteTagIds = <String>[];
      final rawTags = n['tagIds'] ?? const [];
      if (rawTags is! List) {
        throw ImportException('$ctx: tagIds must be a list.');
      }
      for (final t in rawTags) {
        if (t is! String || !tagIds.contains(t)) {
          throw ImportException('$ctx references a missing tag.');
        }
        noteTagIds.add(t);
      }
      final atts = <_PAttachment>[];
      final rawAtts = n['attachments'] ?? const [];
      if (rawAtts is! List) {
        throw ImportException('$ctx: attachments must be a list.');
      }
      for (final a in rawAtts) {
        if (a is! Map<String, dynamic>) {
          throw ImportException('$ctx has an invalid attachment.');
        }
        final aid = str(a, 'id', ctx);
        final path = str(a, 'path', '$ctx attachment $aid');
        if (!path.startsWith('attachments/') || path.contains('..')) {
          throw ImportException('$ctx: unsafe attachment path "$path".');
        }
        if (!files.containsKey(path)) {
          warnings.add(
            'Attachment ${a['filename']} of note $id is missing from the archive and was skipped.',
          );
          continue;
        }
        atts.add(
          _PAttachment(
            aid,
            str(a, 'filename', '$ctx attachment $aid'),
            files[path]!,
            date(a, 'createdAt', '$ctx attachment $aid'),
          ),
        );
        attachmentCount++;
      }
      notes.add(
        _PNote(
          id: id,
          title: title as String?,
          contentJson: contentJson,
          folderId: folderId,
          pinned: n['isPinned'] == true,
          archived: n['isArchived'] == true,
          createdAt: date(n, 'createdAt', ctx),
          updatedAt: date(n, 'updatedAt', ctx),
          deletedAt: n['deletedAt'] == null ? null : date(n, 'deletedAt', ctx),
          tagIds: noteTagIds,
          attachments: atts,
        ),
      );
    }
    return _Parsed(
      folders: folders,
      tags: tags,
      notes: notes,
      preview: ImportPreview(
        notes: notes.length,
        folders: folders.length,
        tags: tags.length,
        attachments: attachmentCount,
        warnings: warnings,
      ),
    );
  }

  Future<ImportResult> _commit(
    _Parsed p,
    Map<String, Uint8List> files,
    bool Function() cancelled,
  ) async {
    if (cancelled()) throw ImportException('Import cancelled.');
    final writtenFiles = <String>[];
    var copied = 0;
    var attachmentsImported = 0;
    try {
      await _db.transaction(() async {
        final existingNotes = (await _db.select(_db.notes).get())
            .map((n) => n.id)
            .toSet();
        final existingFolders = (await _db.select(_db.folders).get())
            .map((f) => f.id)
            .toSet();
        final existingAttachmentIds = (await _db.select(_db.attachments).get())
            .map((a) => a.id)
            .toSet();
        final tagRows = await _db.select(_db.tags).get();
        final tagByName = {for (final t in tagRows) t.name.toLowerCase(): t.id};
        final tagIdsInUse = tagRows.map((t) => t.id).toSet();

        // Folders: parents first. Existing ids are reused, never overwritten.
        final folderMap = <String, String>{};
        final pending = [...p.folders];
        while (pending.isNotEmpty) {
          final ready = pending
              .where(
                (f) => f.parentId == null || folderMap.containsKey(f.parentId),
              )
              .toList();
          if (ready.isEmpty) {
            throw ImportException('Folder hierarchy is invalid.');
          }
          for (final f in ready) {
            pending.remove(f);
            folderMap[f.id] = f.id;
            if (existingFolders.contains(f.id)) continue;
            await _db
                .into(_db.folders)
                .insert(
                  FoldersCompanion.insert(
                    id: f.id,
                    name: f.name,
                    parentFolderId: Value(f.parentId),
                    createdAt: f.createdAt,
                    updatedAt: f.updatedAt,
                  ),
                );
          }
        }

        final tagMap = <String, String>{};
        for (final t in p.tags) {
          final existing = tagByName[t.name.toLowerCase()];
          if (existing != null) {
            tagMap[t.id] = existing;
            continue;
          }
          final id = tagIdsInUse.contains(t.id) ? _uuid.v4() : t.id;
          await _db
              .into(_db.tags)
              .insert(
                TagsCompanion.insert(
                  id: id,
                  name: t.name,
                  createdAt: t.createdAt,
                ),
              );
          tagMap[t.id] = id;
          tagIdsInUse.add(id);
          tagByName[t.name.toLowerCase()] = id;
        }

        for (final n in p.notes) {
          if (cancelled()) throw ImportException('Import cancelled.');
          var id = n.id;
          if (existingNotes.contains(id)) {
            id = _uuid.v4();
            copied++;
          }
          await _notes.insertRaw(
            id: id,
            title: n.title,
            contentJson: n.contentJson,
            folderId: n.folderId == null ? null : folderMap[n.folderId],
            isPinned: n.pinned,
            isArchived: n.archived,
            createdAt: n.createdAt,
            updatedAt: n.updatedAt,
            deletedAt: n.deletedAt,
          );
          for (final t in n.tagIds.toSet()) {
            await _db
                .into(_db.noteTags)
                .insert(
                  NoteTagsCompanion.insert(noteId: id, tagId: tagMap[t]!),
                );
          }
          for (final a in n.attachments) {
            final aid = existingAttachmentIds.contains(a.id)
                ? _uuid.v4()
                : a.id;
            existingAttachmentIds.add(aid);
            final rel = await _storage.storeBytes(a.bytes, aid, a.filename);
            writtenFiles.add(rel);
            await _db
                .into(_db.attachments)
                .insert(
                  AttachmentsCompanion.insert(
                    id: aid,
                    noteId: id,
                    localPath: rel,
                    filename: a.filename,
                    mimeType: mimeTypeForFilename(a.filename),
                    fileSize: a.bytes.length,
                    createdAt: a.createdAt,
                  ),
                );
            attachmentsImported++;
          }
        }
      });
    } catch (_) {
      for (final f in writtenFiles) {
        await _storage.delete(f);
      }
      rethrow;
    }
    return ImportResult(
      notes: p.notes.length,
      copiedBecauseIdExisted: copied,
      attachments: attachmentsImported,
    );
  }

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  static String _ext(String filename) =>
      AttachmentStorage.safeExtension(filename);

  static String _slug(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (cleaned.isEmpty) return 'untitled';
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  static const _readme = '''Plinth export (format version $exportVersion)

manifest.json   Complete data: folders, tags, notes (Quill delta content),
                attachment metadata. This is the file Plinth imports.
notes/*.md      Each note rendered as Markdown for reading elsewhere.
attachments/    Image files, grouped by note id.

Importing never overwrites existing notes: a note whose id already exists is
imported as a new copy.
''';
}

// Top-level so the isolate closure cannot capture the service (and database).
Future<Uint8List> _encodeInIsolate(Map<String, Uint8List> files) =>
    Isolate.run(() => _encodeZip(files));

Future<Map<String, Uint8List>> _decodeInIsolate(Uint8List bytes) =>
    Isolate.run(() => _decodeZip(bytes));

Uint8List _encodeZip(Map<String, Uint8List> files) {
  final archive = Archive();
  files.forEach(
    (name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)),
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Map<String, Uint8List> _decodeZip(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  return {
    for (final f in archive)
      if (f.isFile) f.name: Uint8List.fromList(f.content),
  };
}

class _Parsed {
  _Parsed({
    required this.folders,
    required this.tags,
    required this.notes,
    required this.preview,
  });
  final List<_PFolder> folders;
  final List<_PTag> tags;
  final List<_PNote> notes;
  final ImportPreview preview;
}

class _PFolder {
  _PFolder(this.id, this.name, this.parentId, this.createdAt, this.updatedAt);
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class _PTag {
  _PTag(this.id, this.name, this.createdAt);
  final String id;
  final String name;
  final DateTime createdAt;
}

class _PAttachment {
  _PAttachment(this.id, this.filename, this.bytes, this.createdAt);
  final String id;
  final String filename;
  final Uint8List bytes;
  final DateTime createdAt;
}

class _PNote {
  _PNote({
    required this.id,
    required this.title,
    required this.contentJson,
    required this.folderId,
    required this.pinned,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.tagIds,
    required this.attachments,
  });
  final String id;
  final String? title;
  final String contentJson;
  final String? folderId;
  final bool pinned;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<String> tagIds;
  final List<_PAttachment> attachments;
}
