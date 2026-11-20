import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plinth/core/database/database.dart';
import 'package:plinth/core/errors/errors.dart';
import 'package:plinth/features/folders/data/folder_repository.dart';
import 'package:plinth/features/notes/data/note_repository.dart';
import 'package:plinth/features/notes/domain/note.dart';
import 'package:plinth/features/search/data/search_repository.dart';
import 'package:plinth/features/settings/data/settings_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../support/test_env.dart';

Future<List<NoteSummary>> list(TestEnv e, NoteQuery q) =>
    e.notes.watchList(q).first;

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.dispose());

  group('notes', () {
    test('create persists an empty note immediately', () async {
      final n = await env.notes.create();
      expect(n.title, isNull);
      expect(await env.notes.getById(n.id), isNotNull);
      expect(await env.notes.countAll(), 1);
    });

    test('update derives title/preview and bumps updatedAt', () async {
      final n = await env.notes.create();
      env.tick();
      await env.notes.updateContent(
        n.id,
        contentJson: deltaOf('Shopping list\nmilk and eggs'),
      );
      final s = (await list(env, const NoteQuery())).single;
      expect(s.title, isNull);
      expect(s.displayTitle, 'Shopping list');
      expect(s.preview, 'milk and eggs');
      expect(s.updatedAt.isAfter(n.updatedAt), isTrue);
    });

    test('explicit title wins and preview keeps all text', () async {
      final n = await env.notes.create();
      await env.notes.updateContent(
        n.id,
        title: '  Plan ',
        contentJson: deltaOf('line one\nline two'),
      );
      final s = (await list(env, const NoteQuery())).single;
      expect(s.displayTitle, 'Plan');
      expect(s.preview, 'line one line two');
    });

    test('updating a missing note throws', () {
      expect(
        env.notes.updateContent('nope', contentJson: deltaOf('x')),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('unicode and very long notes round-trip', () async {
      final n = await env.notes.create();
      final text = 'Héllo 🌍 日本語 ${'x' * 200000}';
      await env.notes.updateContent(n.id, contentJson: deltaOf(text));
      final loaded = await env.notes.getById(n.id);
      expect(loaded!.content, contains('🌍'));
      final s = (await list(env, const NoteQuery())).single;
      expect(s.preview.length, lessThanOrEqualTo(200));
    });

    test('pin and archive affect scopes and ordering', () async {
      final a = await env.notes.create(title: 'a');
      env.tick();
      final b = await env.notes.create(title: 'b');
      await env.notes.setPinned(a.id, true);
      final ordered = await list(env, const NoteQuery(pinnedFirst: true));
      expect(ordered.first.id, a.id);
      expect(
        (await list(env, const NoteQuery(pinned: true))).map((e) => e.id),
        [a.id],
      );
      await env.notes.setArchived(b.id, true);
      expect(await list(env, const NoteQuery()), hasLength(1));
      expect(
        (await list(env, const NoteQuery(scope: NoteScope.archived))).single.id,
        b.id,
      );
      await env.notes.setArchived(b.id, false);
      expect(await list(env, const NoteQuery()), hasLength(2));
    });

    test('sort orders', () async {
      final b = await env.notes.create(title: 'banana');
      env.tick();
      final a = await env.notes.create(title: 'Apple');
      final byTitle = await list(
        env,
        const NoteQuery(sort: SortOrder.titleAsc),
      );
      expect(byTitle.map((e) => e.id), [a.id, b.id]);
      final byCreated = await list(
        env,
        const NoteQuery(sort: SortOrder.createdDesc),
      );
      expect(byCreated.first.id, a.id);
    });

    test('limit paginates', () async {
      for (var i = 0; i < 5; i++) {
        await env.notes.create(title: 'n$i');
        env.tick();
      }
      expect(
        await env.notes.watchList(const NoteQuery(), limit: 3).first,
        hasLength(3),
      );
    });

    test('trash, restore and permanent delete', () async {
      final n = await env.notes.create(title: 'gone');
      await env.notes.trash(n.id);
      expect(await list(env, const NoteQuery()), isEmpty);
      expect(
        await list(env, const NoteQuery(scope: NoteScope.trashed)),
        hasLength(1),
      );
      await env.notes.restore(n.id);
      expect(await list(env, const NoteQuery()), hasLength(1));
      await env.notes.trash(n.id);
      await env.notes.deletePermanently(n.id);
      expect(await env.notes.countAll(), 0);
      expect(await env.search.search('gone'), isEmpty);
    });

    test(
      'purgeExpiredTrash only removes old items; emptyTrash removes all',
      () async {
        final old = await env.notes.create(title: 'old');
        await env.notes.trash(old.id);
        env.tick(const Duration(days: 40));
        final recent = await env.notes.create(title: 'recent');
        await env.notes.trash(recent.id);
        expect(await env.notes.purgeExpiredTrash(const Duration(days: 30)), 1);
        expect(await env.notes.getById(old.id), isNull);
        expect(await env.notes.getById(recent.id), isNotNull);
        expect(await env.notes.emptyTrash(), 1);
        expect(await env.notes.countAll(), 0);
      },
    );

    test('duplicate copies content, tags and attachment files', () async {
      final n = await env.notes.create(title: 'Orig');
      await env.notes.updateContent(
        n.id,
        title: 'Orig',
        contentJson: deltaOf('body text'),
      );
      final tag = await env.tags.create('work');
      await env.tags.addToNote(n.id, tag.id);
      final att = await env.attachments.addFromBytes(
        n.id,
        Uint8List.fromList([1, 2, 3]),
        'a.png',
      );
      await env.notes.setPinned(n.id, true);

      final copy = await env.notes.duplicate(n.id);
      expect(copy.id, isNot(n.id));
      expect(copy.title, 'Orig (copy)');
      expect(copy.isPinned, isFalse);
      expect(await env.tags.watchForNote(copy.id).first, hasLength(1));
      final copied = await env.attachments.watchForNote(copy.id).first;
      expect(copied.single.localPath, isNot(att.localPath));
      expect(env.attachments.fileFor(copied.single).existsSync(), isTrue);
      expect((await env.search.search('body')).length, 2);
    });

    test('permanent delete removes attachment files', () async {
      final n = await env.notes.create();
      final att = await env.attachments.addFromBytes(
        n.id,
        Uint8List.fromList([9]),
        'x.jpg',
      );
      final file = env.attachments.fileFor(att);
      expect(file.existsSync(), isTrue);
      await env.notes.deletePermanently(n.id);
      expect(file.existsSync(), isFalse);
    });
  });

  group('folders', () {
    test('create, rename, validate', () async {
      final f = await env.folders.create(' Work ');
      expect(f.name, 'Work');
      await env.folders.rename(f.id, 'Job');
      expect((await env.folders.getById(f.id))!.name, 'Job');
      expect(env.folders.create('  '), throwsA(isA<ValidationException>()));
    });

    test('nested folders and cycle prevention', () async {
      final a = await env.folders.create('a');
      final b = await env.folders.create('b', parentId: a.id);
      final c = await env.folders.create('c', parentId: b.id);
      expect(
        env.folders.move(a.id, c.id),
        throwsA(isA<CircularFolderException>()),
      );
      expect(
        env.folders.move(a.id, a.id),
        throwsA(isA<CircularFolderException>()),
      );
      await env.folders.move(c.id, null);
      expect((await env.folders.getById(c.id))!.parentFolderId, isNull);
      await env.folders.move(a.id, c.id); // now valid
    });

    test('delete moving notes to parent', () async {
      final a = await env.folders.create('a');
      final b = await env.folders.create('b', parentId: a.id);
      final c = await env.folders.create('c', parentId: b.id);
      final n = await env.notes.create(folderId: b.id);
      await env.folders.delete(b.id, moveNotesToParent: true);
      expect((await env.notes.getById(n.id))!.folderId, a.id);
      expect((await env.folders.getById(c.id))!.parentFolderId, a.id);
    });

    test('delete leaving notes unorganised keeps notes', () async {
      final a = await env.folders.create('a');
      final n = await env.notes.create(folderId: a.id);
      await env.folders.delete(a.id, moveNotesToParent: false);
      expect((await env.notes.getById(n.id))!.folderId, isNull);
      expect(await env.notes.countAll(), 1);
    });

    test('move note and list by folder', () async {
      final a = await env.folders.create('a');
      final n = await env.notes.create(title: 'x');
      await env.notes.moveToFolder(n.id, a.id);
      final l = await list(env, NoteQuery(folderId: a.id));
      expect(l.single.folderName, 'a');
      expect(await list(env, const NoteQuery(unfiledOnly: true)), isEmpty);
    });

    test('flattenFolderTree orders depth-first and can exclude a subtree', () {
      Folder f(String id, String n, String? p) => Folder(
        id: id,
        name: n,
        parentFolderId: p,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      final nodes = flattenFolderTree([
        f('1', 'b', null),
        f('2', 'a', null),
        f('3', 'child', '2'),
      ]);
      expect(nodes.map((n) => n.folder.id), ['2', '3', '1']);
      expect(nodes[1].depth, 1);
      expect(
        flattenFolderTree([
          f('1', 'a', null),
          f('2', 'b', '1'),
        ], excludeSubtreeOf: '1').length,
        0,
      );
    });
  });

  group('tags', () {
    test('create is case-insensitive idempotent; rename; delete', () async {
      final t = await env.tags.create('Idea');
      expect((await env.tags.create('idea')).id, t.id);
      final u = await env.tags.create('Other');
      expect(
        env.tags.rename(u.id, 'IDEA'),
        throwsA(isA<DuplicateTagException>()),
      );
      await env.tags.rename(u.id, 'Another');
      await env.tags.delete(u.id);
      expect(await env.tags.watchAll().first, hasLength(1));
    });

    test('assign, filter, remove and counts', () async {
      final n1 = await env.notes.create(title: 'one');
      final n2 = await env.notes.create(title: 'two');
      final t = await env.tags.create('x');
      await env.tags.addToNote(n1.id, t.id);
      await env.tags.addToNote(n1.id, t.id); // idempotent
      await env.tags.addToNote(n2.id, t.id);
      expect((await env.tags.watchAll().first).single.noteCount, 2);
      expect(await list(env, NoteQuery(tagId: t.id)), hasLength(2));
      await env.tags.removeFromNote(n2.id, t.id);
      expect(await list(env, NoteQuery(tagId: t.id)), hasLength(1));
      await env.notes.trash(n1.id);
      expect((await env.tags.watchAll().first).single.noteCount, 0);
    });

    test('deleting a note cascades its tag links', () async {
      final n = await env.notes.create();
      final t = await env.tags.create('x');
      await env.tags.addToNote(n.id, t.id);
      await env.notes.deletePermanently(n.id);
      expect((await env.tags.watchAll().first).single.noteCount, 0);
    });
  });

  group('search', () {
    test('finds notes by title and body with prefix matching', () async {
      final a = await env.notes.create();
      await env.notes.updateContent(
        a.id,
        title: 'Groceries',
        contentJson: deltaOf('buy avocados'),
      );
      final b = await env.notes.create();
      await env.notes.updateContent(
        b.id,
        contentJson: deltaOf('meeting notes'),
      );
      expect((await env.search.search('groc')).single.noteId, a.id);
      expect((await env.search.search('AVOCA')).single.noteId, a.id);
      expect((await env.search.search('meeting notes')).single.noteId, b.id);
      expect(await env.search.search('zzz'), isEmpty);
      expect(await env.search.search('   '), isEmpty);
    });

    test('index follows edits, trash and restore', () async {
      final n = await env.notes.create();
      await env.notes.updateContent(n.id, contentJson: deltaOf('alpha'));
      await env.notes.updateContent(n.id, contentJson: deltaOf('beta'));
      expect(await env.search.search('alpha'), isEmpty);
      expect(await env.search.search('beta'), hasLength(1));
      await env.notes.trash(n.id);
      expect(await env.search.search('beta'), isEmpty);
      await env.notes.restore(n.id);
      expect(await env.search.search('beta'), hasLength(1));
    });

    test('special characters do not break queries; accents fold', () async {
      final n = await env.notes.create();
      await env.notes.updateContent(n.id, contentJson: deltaOf('café au lait'));
      expect(await env.search.search('"AND" OR * ( -'), isEmpty);
      expect(await env.search.search('cafe'), hasLength(1));
    });

    test('highlights matches', () async {
      final n = await env.notes.create();
      await env.notes.updateContent(
        n.id,
        title: 'Trip plans',
        contentJson: deltaOf('book the flights soon'),
      );
      final hit = (await env.search.search('flig')).single;
      final spans = parseHighlights(hit.snippet);
      expect(spans.where((s) => s.isMatch).map((s) => s.text), ['flights']);
      final t = (await env.search.search('trip')).single;
      expect(parseHighlights(t.title).first.isMatch, isTrue);
    });

    test('filters: folder subtree, tag, pinned, archived', () async {
      final root = await env.folders.create('root');
      final sub = await env.folders.create('sub', parentId: root.id);
      final other = await env.folders.create('other');
      Future<String> mk(String folder) async {
        final n = await env.notes.create(folderId: folder);
        await env.notes.updateContent(n.id, contentJson: deltaOf('needle'));
        return n.id;
      }

      final inSub = await mk(sub.id);
      final inOther = await mk(other.id);
      final ids = (await env.search.search(
        'needle',
        filters: SearchFilters(folderId: root.id),
      )).map((h) => h.noteId);
      expect(ids, [inSub]);

      final tag = await env.tags.create('t');
      await env.tags.addToNote(inOther, tag.id);
      expect(
        (await env.search.search(
          'needle',
          filters: SearchFilters(tagId: tag.id),
        )).single.noteId,
        inOther,
      );

      await env.notes.setPinned(inSub, true);
      expect(
        (await env.search.search(
          'needle',
          filters: const SearchFilters(pinnedOnly: true),
        )).single.noteId,
        inSub,
      );

      await env.notes.setArchived(inOther, true);
      expect(await env.search.search('needle'), hasLength(1));
      expect(
        await env.search.search(
          'needle',
          filters: const SearchFilters(archive: ArchiveFilter.include),
        ),
        hasLength(2),
      );
      expect(
        (await env.search.search(
          'needle',
          filters: const SearchFilters(archive: ArchiveFilter.only),
        )).single.noteId,
        inOther,
      );
    });

    test('rebuildSearchIndex restores a wiped index', () async {
      final n = await env.notes.create();
      await env.notes.updateContent(n.id, contentJson: deltaOf('findme'));
      await env.db.customStatement('DELETE FROM notes_fts');
      expect(await env.search.search('findme'), isEmpty);
      await env.notes.rebuildSearchIndex();
      expect(await env.search.search('findme'), hasLength(1));
    });

    test('recent searches dedupe, cap and clear', () async {
      for (var i = 0; i < 12; i++) {
        await env.search.addRecent('q$i');
        env.tick();
      }
      await env.search.addRecent('q5');
      final recent = await env.search.watchRecent().first;
      expect(recent, hasLength(SearchRepository.maxRecent));
      expect(recent.first, 'q5');
      expect(recent.where((e) => e == 'q5'), hasLength(1));
      await env.search.clearRecent();
      expect(await env.search.watchRecent().first, isEmpty);
    });

    test('search stays fast with thousands of notes', () async {
      await env.db.batch((b) {
        for (var i = 0; i < 5000; i++) {
          b.customStatement(
            "INSERT INTO notes_fts(note_id, title, body) VALUES ('n$i', 'title $i', 'lorem ipsum dolor $i')",
          );
        }
      });
      final sw = Stopwatch()..start();
      await env.db
          .customSelect(
            "SELECT note_id FROM notes_fts WHERE notes_fts MATCH '\"dolor\"* \"4999\"*' LIMIT 30",
          )
          .get();
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('attachments', () {
    test('add, list and remove', () async {
      final n = await env.notes.create();
      final a = await env.attachments.addFromBytes(
        n.id,
        Uint8List.fromList([1, 2]),
        'pic.PNG',
      );
      expect(a.mimeType, 'image/png');
      expect(a.fileSize, 2);
      expect(a.localPath.endsWith('.png'), isTrue);
      expect(await env.attachments.watchForNote(n.id).first, hasLength(1));
      await env.attachments.remove(a.id);
      expect(await env.attachments.watchForNote(n.id).first, isEmpty);
      expect(env.attachments.fileFor(a).existsSync(), isFalse);
    });

    test('adding to a missing note cleans up the file', () async {
      expect(
        env.attachments.addFromBytes('nope', Uint8List.fromList([1]), 'a.jpg'),
        throwsA(isA<NotFoundException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final dir = env.storage.root;
      expect(!dir.existsSync() || dir.listSync().isEmpty, isTrue);
    });

    test('missing file is tolerated by metadata queries', () async {
      final n = await env.notes.create();
      final a = await env.attachments.addFromBytes(
        n.id,
        Uint8List.fromList([1]),
        'a.jpg',
      );
      env.attachments.fileFor(a).deleteSync();
      expect(await env.attachments.watchForNote(n.id).first, hasLength(1));
      await env.attachments.remove(a.id);
    });
  });

  group('settings', () {
    test('defaults, save and reload', () async {
      expect((await env.settings.load()).trashRetentionDays, 30);
      await env.settings.save(
        const AppSettings(
          theme: ThemePreference.dark,
          landing: LandingScreen.search,
          sortOrder: SortOrder.titleAsc,
          editorFontSize: EditorFontSize.large,
          trashRetentionDays: 0,
        ),
      );
      final s = await env.settings.load();
      expect(s.theme, ThemePreference.dark);
      expect(s.landing, LandingScreen.search);
      expect(s.sortOrder, SortOrder.titleAsc);
      expect(s.editorFontSize, EditorFontSize.large);
      expect(s.trashRetentionDays, 0);
      await env.settings.save(s.copyWith(theme: ThemePreference.light));
      expect((await env.settings.load()).theme, ThemePreference.light);
    });
  });

  group('database', () {
    test('foreign keys are enforced', () async {
      expect(
        env.db.customStatement(
          "INSERT INTO note_tags(note_id, tag_id) VALUES ('x', 'y')",
        ),
        throwsA(anything),
      );
    });

    test('file database persists across reopen', () async {
      final file = File('${env.tmp.path}/p.db');
      var db = AppDatabase.file(file);
      final repo = NoteRepository(db);
      final n = await repo.create(title: 'persist');
      await db.close();
      db = AppDatabase.file(file);
      expect(await NoteRepository(db).getById(n.id), isNotNull);
      await db.close();
      final raw = sqlite.sqlite3.open(file.path);
      expect(
        raw.select('PRAGMA user_version').first.values.first,
        currentSchemaVersion,
      );
      raw.close();
    });

    test(
      'refuses a database from a newer version without touching it',
      () async {
        final file = File('${env.tmp.path}/new.db');
        final raw = sqlite.sqlite3.open(file.path);
        raw.execute('PRAGMA user_version = 99');
        raw.close();
        final db = AppDatabase(NativeDatabase(file));
        await expectLater(
          db.customSelect('SELECT 1').get(),
          throwsA(isA<DatabaseTooNewException>()),
        );
        await db.close();
      },
    );

    test('backupBeforeMigration copies only older databases', () {
      final file = File('${env.tmp.path}/old.db');
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('CREATE TABLE t(x)');
      raw.execute('PRAGMA user_version = 0');
      raw.close();
      expect(backupBeforeMigration(file), isNull);
      expect(backupBeforeMigration(File('${env.tmp.path}/none.db')), isNull);
    });
  });
}
