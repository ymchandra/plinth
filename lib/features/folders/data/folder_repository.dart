import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/errors/errors.dart';

class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.parentFolderId,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String name;
  final String? parentFolderId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// A folder together with its depth, for flattened tree display.
class FolderNode {
  const FolderNode(this.folder, this.depth);
  final Folder folder;
  final int depth;
}

/// Orders [folders] depth-first (siblings by name), tolerating orphans.
List<FolderNode> flattenFolderTree(
  List<Folder> folders, {
  String? excludeSubtreeOf,
}) {
  final byParent = <String?, List<Folder>>{};
  final ids = folders.map((f) => f.id).toSet();
  for (final f in folders) {
    final parent = ids.contains(f.parentFolderId) ? f.parentFolderId : null;
    byParent.putIfAbsent(parent, () => []).add(f);
  }
  for (final l in byParent.values) {
    l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  final out = <FolderNode>[];
  void walk(String? parent, int depth) {
    for (final f in byParent[parent] ?? const <Folder>[]) {
      if (f.id == excludeSubtreeOf) continue;
      out.add(FolderNode(f, depth));
      walk(f.id, depth + 1);
    }
  }

  walk(null, 0);
  return out;
}

class FolderRepository {
  FolderRepository(this._db, {DateTime Function()? now, Uuid? uuid})
    : _now = now ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _now;
  final Uuid _uuid;

  Stream<List<Folder>> watchAll() =>
      (_db.select(_db.folders)..orderBy([(f) => OrderingTerm.asc(f.name)]))
          .watch()
          .map((rows) => rows.map(_map).toList());

  Future<Folder?> getById(String id) async {
    final r = await (_db.select(
      _db.folders,
    )..where((f) => f.id.equals(id))).getSingleOrNull();
    return r == null ? null : _map(r);
  }

  Future<Folder> create(String name, {String? parentId}) async {
    final clean = _validName(name);
    if (parentId != null && await getById(parentId) == null) {
      throw NotFoundException('Parent folder');
    }
    final id = _uuid.v4();
    final now = _now();
    await _db
        .into(_db.folders)
        .insert(
          FoldersCompanion.insert(
            id: id,
            name: clean,
            parentFolderId: Value(parentId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getById(id))!;
  }

  Future<void> rename(String id, String name) async {
    final n = await (_db.update(_db.folders)..where((f) => f.id.equals(id)))
        .write(
          FoldersCompanion(
            name: Value(_validName(name)),
            updatedAt: Value(_now()),
          ),
        );
    if (n == 0) throw NotFoundException('Folder');
  }

  /// Moves [id] under [newParentId] (null = top level). Rejects cycles.
  Future<void> move(String id, String? newParentId) async {
    await _db.transaction(() async {
      if (newParentId != null) {
        var cursor = newParentId;
        final seen = <String>{};
        while (true) {
          if (cursor == id) throw CircularFolderException();
          if (!seen.add(cursor)) break; // Pre-existing loop; stop walking.
          final parent = await getById(cursor);
          if (parent == null) throw NotFoundException('Folder');
          if (parent.parentFolderId == null) break;
          cursor = parent.parentFolderId!;
        }
      }
      final n = await (_db.update(_db.folders)..where((f) => f.id.equals(id)))
          .write(
            FoldersCompanion(
              parentFolderId: Value(newParentId),
              updatedAt: Value(_now()),
            ),
          );
      if (n == 0) throw NotFoundException('Folder');
    });
  }

  /// Deletes a folder without deleting notes. Notes go to the parent folder
  /// when [moveNotesToParent], otherwise become unorganised. Subfolders are
  /// always re-parented to the deleted folder's parent.
  Future<void> delete(String id, {required bool moveNotesToParent}) async {
    await _db.transaction(() async {
      final folder = await getById(id);
      if (folder == null) throw NotFoundException('Folder');
      final parent = folder.parentFolderId;
      await (_db.update(_db.notes)..where((n) => n.folderId.equals(id))).write(
        NotesCompanion(folderId: Value(moveNotesToParent ? parent : null)),
      );
      await (_db.update(_db.folders)..where((f) => f.parentFolderId.equals(id)))
          .write(FoldersCompanion(parentFolderId: Value(parent)));
      await (_db.delete(_db.folders)..where((f) => f.id.equals(id))).go();
    });
  }

  String _validName(String name) {
    final t = name.trim();
    if (t.isEmpty) throw ValidationException('Name is required');
    return t;
  }

  Folder _map(FolderRow r) => Folder(
    id: r.id,
    name: r.name,
    parentFolderId: r.parentFolderId,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );
}
