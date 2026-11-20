import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Files for attachments live in the app-private [root] directory. The
/// database only stores paths relative to it.
class AttachmentStorage {
  AttachmentStorage(this.root);

  final Directory root;

  File resolve(String relativePath) => File(p.join(root.path, relativePath));

  Future<void> _ensureRoot() async {
    if (!await root.exists()) await root.create(recursive: true);
  }

  static String safeExtension(String filename) {
    final ext = p.extension(filename).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext) ? ext : '';
  }

  Future<String> storeFile(File source, String id, String filename) async {
    await _ensureRoot();
    final rel = '$id${safeExtension(filename)}';
    await source.copy(resolve(rel).path);
    return rel;
  }

  Future<String> storeBytes(Uint8List bytes, String id, String filename) async {
    await _ensureRoot();
    final rel = '$id${safeExtension(filename)}';
    await resolve(rel).writeAsBytes(bytes, flush: true);
    return rel;
  }

  Future<String> copy(String relativePath, String newId) async {
    await _ensureRoot();
    final rel = '$newId${safeExtension(relativePath)}';
    await resolve(relativePath).copy(resolve(rel).path);
    return rel;
  }

  Future<void> delete(String relativePath) async {
    try {
      final f = resolve(relativePath);
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // Best effort: a stray file is harmless, a thrown error is not.
    }
  }
}
