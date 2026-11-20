import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plinth/features/backup/domain/markdown_exporter.dart';
import 'package:plinth/features/editor/domain/autosave_controller.dart';
import 'package:plinth/features/notes/domain/delta_text.dart';

String ops(List<Map<String, dynamic>> o) => jsonEncode(o);

void main() {
  group('DeltaText', () {
    test('plain text, derived title and preview', () {
      final json = ops([
        {'insert': '\n\n  First line  \nSecond  line\n'},
        {
          'insert': {'image': 'x'},
        },
      ]);
      final plain = DeltaText.plainText(json);
      expect(DeltaText.derivedTitle(plain), 'First line');
      expect(DeltaText.preview(plain, skipFirstLine: true), 'Second  line');
      expect(DeltaText.preview(plain), 'First line Second  line');
    });

    test('derivedTitle truncates; preview caps length', () {
      expect(DeltaText.derivedTitle('a' * 200).length, 80);
      expect(DeltaText.preview('word ' * 200).length, lessThanOrEqualTo(200));
    });

    test('validation', () {
      expect(DeltaText.isValid('[{"insert":"a\\n"}]'), isTrue);
      expect(DeltaText.isValid('{"a":1}'), isFalse);
      expect(DeltaText.isValid('[{"x":1}]'), isFalse);
      expect(DeltaText.isValid('nope'), isFalse);
      expect(DeltaText.plainText(DeltaText.fromPlainText('hi')), 'hi\n');
    });
  });

  group('MarkdownExporter', () {
    test('headings, inline formatting and links', () {
      final md = MarkdownExporter.export(
        ops([
          {'insert': 'Heading'},
          {
            'insert': '\n',
            'attributes': {'header': 2},
          },
          {'insert': 'plain '},
          {
            'insert': 'bold',
            'attributes': {'bold': true},
          },
          {'insert': ' '},
          {
            'insert': 'ital',
            'attributes': {'italic': true},
          },
          {'insert': ' '},
          {
            'insert': 'under',
            'attributes': {'underline': true},
          },
          {'insert': ' '},
          {
            'insert': 'site',
            'attributes': {'link': 'https://a.b'},
          },
          {'insert': '\n'},
        ]),
        title: 'My note',
      );
      expect(
        md,
        '# My note\n\n## Heading\n\nplain **bold** *ital* <u>under</u> [site](https://a.b)\n',
      );
    });

    test('lists keep numbering, checkbox state and nesting', () {
      final md = MarkdownExporter.export(
        ops([
          {'insert': 'one'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': 'nested'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 1},
          },
          {'insert': 'a'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered'},
          },
          {'insert': 'b'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered'},
          },
          {'insert': 'todo'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          },
          {'insert': 'done'},
          {
            'insert': '\n',
            'attributes': {'list': 'checked'},
          },
        ]),
      );
      expect(
        md,
        '- one\n    - nested\n\n1. a\n2. b\n\n- [ ] todo\n- [x] done\n',
      );
    });

    test('quotes, code blocks and paragraph separation', () {
      final md = MarkdownExporter.export(
        ops([
          {'insert': 'p1\n\np2\n'},
          {'insert': 'quote'},
          {
            'insert': '\n',
            'attributes': {'blockquote': true},
          },
          {'insert': 'code line'},
          {
            'insert': '\n',
            'attributes': {'code-block': true},
          },
        ]),
      );
      expect(md, 'p1\n\np2\n\n> quote\n\n```\ncode line\n```\n');
    });

    test('escapes markdown characters and keeps surrounding whitespace', () {
      final md = MarkdownExporter.export(
        ops([
          {'insert': 'a*b'},
          {
            'insert': ' bold ',
            'attributes': {'bold': true},
          },
          {'insert': 'c\n'},
        ]),
      );
      expect(md, 'a\\*b **bold** c\n');
    });

    test('empty document yields a newline only', () {
      expect(MarkdownExporter.export('[{"insert":"\\n"}]'), '\n');
    });
  });

  group('AutosaveController', () {
    NoteDraft d(String s) => NoteDraft(title: '', contentJson: s);

    test('debounces rapid edits into one write of the latest draft', () {
      fakeAsync((fake) {
        final saved = <NoteDraft>[];
        final c = AutosaveController(save: (x) async => saved.add(x));
        c.schedule(d('a'));
        fake.elapse(const Duration(milliseconds: 300));
        c.schedule(d('ab'));
        fake.elapse(const Duration(milliseconds: 300));
        c.schedule(d('abc'));
        expect(saved, isEmpty);
        expect(c.status, SaveStatus.dirty);
        fake.elapse(const Duration(seconds: 1));
        expect(saved, [d('abc')]);
        expect(c.status, SaveStatus.saved);
      });
    });

    test('flush saves immediately and skips unchanged drafts', () {
      fakeAsync((fake) {
        final saved = <NoteDraft>[];
        final c = AutosaveController(
          save: (x) async => saved.add(x),
          initial: d('same'),
        );
        c.schedule(d('same'));
        expect(c.hasPendingChanges, isFalse);
        c.schedule(d('new'));
        c.flush();
        fake.flushMicrotasks();
        expect(saved, [d('new')]);
        c.schedule(d('new'));
        fake.elapse(const Duration(seconds: 2));
        expect(saved, hasLength(1));
      });
    });

    test('saves are serialised and ordered', () {
      fakeAsync((fake) {
        final log = <String>[];
        var running = 0;
        var maxRunning = 0;
        final c = AutosaveController(
          debounce: Duration.zero,
          save: (x) async {
            running++;
            maxRunning = running > maxRunning ? running : maxRunning;
            await Future<void>.delayed(const Duration(milliseconds: 100));
            log.add(x.contentJson);
            running--;
          },
        );
        c.schedule(d('1'));
        fake.elapse(const Duration(milliseconds: 10));
        c.schedule(d('2'));
        fake.elapse(const Duration(seconds: 1));
        expect(log, ['1', '2']);
        expect(maxRunning, 1);
      });
    });

    test('failed save keeps the draft and retries on flush', () {
      fakeAsync((fake) {
        var fail = true;
        final saved = <NoteDraft>[];
        final c = AutosaveController(
          save: (x) async {
            if (fail) throw StateError('disk full');
            saved.add(x);
          },
        );
        c.schedule(d('x'));
        fake.elapse(const Duration(seconds: 1));
        expect(c.status, SaveStatus.error);
        expect(c.hasPendingChanges, isTrue);
        fail = false;
        c.flush();
        fake.flushMicrotasks();
        expect(saved, [d('x')]);
        expect(c.status, SaveStatus.saved);
      });
    });
  });
}
