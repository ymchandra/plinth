import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plinth/features/backup/data/backup_service.dart';
import 'package:plinth/features/notes/domain/note.dart';

import '../support/test_env.dart';

Uint8List zipOf(Map<String, String> files) {
  final a = Archive();
  files.forEach((k, v) => a.addFile(ArchiveFile.string(k, v)));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

Map<String, dynamic> validManifest() => {
  'format': 'plinth-export',
  'version': 1,
  'folders': [],
  'tags': [],
  'notes': [
    {
      'id': 'n1',
      'title': 'T',
      'content': [
        {'insert': 'hello\n'},
      ],
      'createdAt': '2025-01-01T00:00:00Z',
      'updatedAt': '2025-01-01T00:00:00Z',
    },
  ],
};

void main() {
  late TestEnv src;
  late TestEnv dst;
  late BackupService srcSvc;
  late BackupService dstSvc;

  setUp(() {
    src = TestEnv();
    dst = TestEnv();
    srcSvc = BackupService(src.db, src.storage, src.notes);
    dstSvc = BackupService(dst.db, dst.storage, dst.notes);
  });
  tearDown(() async {
    await src.dispose();
    await dst.dispose();
  });

  Future<void> seed() async {
    final folder = await src.folders.create('Work');
    final sub = await src.folders.create('Deep', parentId: folder.id);
    final tag = await src.tags.create('urgent');
    final n = await src.notes.create(folderId: sub.id);
    await src.notes.updateContent(
      n.id,
      title: 'Plan',
      contentJson: deltaOf('ünïcode 🌍 searchable'),
    );
    await src.tags.addToNote(n.id, tag.id);
    await src.notes.setPinned(n.id, true);
    await src.attachments.addFromBytes(
      n.id,
      Uint8List.fromList([1, 2, 3, 4]),
      'photo.png',
    );
    final t = await src.notes.create();
    await src.notes.updateContent(t.id, contentJson: deltaOf('trashed one'));
    await src.notes.trash(t.id);
  }

  test('export -> import into a clean database preserves everything', () async {
    await seed();
    final result = await srcSvc.exportAll(Directory('${src.tmp.path}/out'));
    expect(result.notes, 2);
    expect(result.attachments, 1);

    final zip = ZipDecoder().decodeBytes(await result.file.readAsBytes());
    final names = zip.map((f) => f.name).toList();
    expect(names, contains('manifest.json'));
    expect(
      names.where((n) => n.startsWith('notes/') && n.endsWith('.md')),
      hasLength(2),
    );
    expect(names.where((n) => n.startsWith('attachments/')), hasLength(1));

    final session = await dstSvc.prepareImport(await result.file.readAsBytes());
    expect(session.preview.notes, 2);
    expect(session.preview.folders, 2);
    expect(session.preview.attachments, 1);
    final r = await session.commit();
    expect(r.notes, 2);
    expect(r.copiedBecauseIdExisted, 0);

    final active = await dst.notes.watchList(const NoteQuery()).first;
    expect(active.single.displayTitle, 'Plan');
    expect(active.single.isPinned, isTrue);
    expect(active.single.folderName, 'Deep');
    expect(
      (await dst.notes
          .watchList(const NoteQuery(scope: NoteScope.trashed))
          .first),
      hasLength(1),
    );
    final id = active.single.id;
    expect(await dst.tags.watchForNote(id).first, hasLength(1));
    final atts = await dst.attachments.watchForNote(id).first;
    expect(atts.single.filename, 'photo.png');
    expect(await dst.attachments.fileFor(atts.single).readAsBytes(), [
      1,
      2,
      3,
      4,
    ]);
    expect(await dst.search.search('searchable'), hasLength(1));
    final folders = await dst.folders.watchAll().first;
    final deep = folders.firstWhere((f) => f.name == 'Deep');
    expect(deep.parentFolderId, folders.firstWhere((f) => f.name == 'Work').id);
  });

  test('re-importing never overwrites: duplicates become copies', () async {
    await seed();
    final result = await srcSvc.exportAll(Directory('${src.tmp.path}/out'));
    final bytes = await result.file.readAsBytes();
    await (await srcSvc.prepareImport(bytes)).commit();
    expect(await src.notes.countAll(), 4);
    final folders = await src.folders.watchAll().first;
    expect(folders, hasLength(2)); // reused, not duplicated
    expect(await src.tags.watchAll().first, hasLength(1));
    expect(await src.search.search('searchable'), hasLength(2));
  });

  test('cancelling before commit imports nothing', () async {
    await seed();
    final result = await srcSvc.exportAll(Directory('${src.tmp.path}/out'));
    final session = await dstSvc.prepareImport(await result.file.readAsBytes());
    session.cancel();
    expect(session.commit(), throwsA(isA<ImportException>()));
    expect(await dst.notes.countAll(), 0);
  });

  test('missing attachment on export is counted, not fatal', () async {
    final n = await src.notes.create();
    final a = await src.attachments.addFromBytes(
      n.id,
      Uint8List.fromList([1]),
      'x.jpg',
    );
    src.attachments.fileFor(a).deleteSync();
    final r = await srcSvc.exportAll(Directory('${src.tmp.path}/out'));
    expect(r.missingAttachments, 1);
    expect(r.attachments, 0);
  });

  group('validation', () {
    Future<void> expectRejected(Uint8List bytes, Pattern message) async {
      await expectLater(
        dstSvc.prepareImport(bytes),
        throwsA(
          isA<ImportException>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
      expect(await dst.notes.countAll(), 0);
    }

    test(
      'not a zip',
      () => expectRejected(Uint8List.fromList([1, 2, 3]), 'ZIP'),
    );

    test(
      'missing manifest',
      () => expectRejected(zipOf({'a.txt': 'x'}), 'manifest'),
    );

    test(
      'invalid JSON',
      () => expectRejected(zipOf({'manifest.json': '{'}), 'JSON'),
    );

    test(
      'wrong format',
      () => expectRejected(
        zipOf({
          'manifest.json': jsonEncode({'format': 'other', 'version': 1}),
        }),
        'format',
      ),
    );

    test('newer version', () {
      final m = validManifest()..['version'] = 2;
      return expectRejected(zipOf({'manifest.json': jsonEncode(m)}), 'newer');
    });

    test('invalid note content', () {
      final m = validManifest();
      (m['notes'] as List).first['content'] = 'oops';
      return expectRejected(zipOf({'manifest.json': jsonEncode(m)}), 'content');
    });

    test('bad date', () {
      final m = validManifest();
      (m['notes'] as List).first['updatedAt'] = 'yesterday';
      return expectRejected(zipOf({'manifest.json': jsonEncode(m)}), 'date');
    });

    test('dangling references and duplicate ids', () async {
      var m = validManifest();
      (m['notes'] as List).first['folderId'] = 'nope';
      await expectRejected(zipOf({'manifest.json': jsonEncode(m)}), 'folder');
      m = validManifest();
      (m['notes'] as List).first['tagIds'] = ['nope'];
      await expectRejected(zipOf({'manifest.json': jsonEncode(m)}), 'tag');
      m = validManifest();
      (m['notes'] as List).add((m['notes'] as List).first);
      await expectRejected(
        zipOf({'manifest.json': jsonEncode(m)}),
        'Duplicate',
      );
    });

    test('folder cycles and unsafe attachment paths', () async {
      var m = validManifest();
      Map<String, dynamic> f(String id, String parent) => {
        'id': id,
        'name': id,
        'parentFolderId': parent,
        'createdAt': '2025-01-01T00:00:00Z',
        'updatedAt': '2025-01-01T00:00:00Z',
      };
      m['folders'] = [f('a', 'b'), f('b', 'a')];
      await expectRejected(zipOf({'manifest.json': jsonEncode(m)}), 'cycle');
      m = validManifest();
      (m['notes'] as List).first['attachments'] = [
        {
          'id': 'a1',
          'filename': 'x.png',
          'path': 'attachments/../../etc/passwd',
          'createdAt': '2025-01-01T00:00:00Z',
        },
      ];
      await expectRejected(zipOf({'manifest.json': jsonEncode(m)}), 'unsafe');
    });

    test('missing attachment file becomes a warning', () async {
      final m = validManifest();
      (m['notes'] as List).first['attachments'] = [
        {
          'id': 'a1',
          'filename': 'x.png',
          'path': 'attachments/n1/a1.png',
          'createdAt': '2025-01-01T00:00:00Z',
        },
      ];
      final s = await dstSvc.prepareImport(
        zipOf({'manifest.json': jsonEncode(m)}),
      );
      expect(s.preview.warnings, hasLength(1));
      expect(s.preview.attachments, 0);
      await s.commit();
      expect(await dst.notes.countAll(), 1);
    });

    test('failed commit rolls back the database transaction', () async {
      final m = validManifest();
      (m['notes'] as List).first['attachments'] = [
        {
          'id': 'a1',
          'filename': 'x.png',
          'path': 'attachments/n1/a.png',
          'createdAt': '2025-01-01T00:00:00Z',
        },
      ];
      final zip = Archive()
        ..addFile(ArchiveFile.string('manifest.json', jsonEncode(m)))
        ..addFile(ArchiveFile.bytes('attachments/n1/a.png', [1, 2, 3]));
      final session = await dstSvc.prepareImport(
        Uint8List.fromList(ZipEncoder().encode(zip)),
      );
      // A regular file where the attachments directory should be makes the
      // file write fail after the note row was inserted.
      File(dst.storage.root.path).writeAsStringSync('blocker');
      await expectLater(session.commit(), throwsA(anything));
      expect(await dst.notes.countAll(), 0);
      expect(await dst.search.search('hello'), isEmpty);
    });
  });
}
