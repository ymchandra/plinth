import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../core/util/l10n_ext.dart';
import '../../../core/widgets/widgets.dart';
import '../../backup/domain/markdown_exporter.dart';
import '../../folders/presentation/folder_picker.dart';
import '../domain/note.dart';
import '../../tags/presentation/tag_picker.dart';

/// Bottom sheet with every action available for a note in a list.
Future<void> showNoteActions(
  BuildContext context,
  WidgetRef ref,
  NoteSummary note,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                note.displayTitle.isEmpty
                    ? ctx.l10n.untitled
                    : note.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final a in _actionsFor(note))
              ListTile(
                leading: Icon(a.icon),
                title: Text(a.label(ctx)),
                onTap: () {
                  Navigator.pop(ctx);
                  a.run(context, ref, note);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _Action {
  const _Action(this.icon, this.label, this.run);
  final IconData icon;
  final String Function(BuildContext) label;
  final Future<void> Function(BuildContext, WidgetRef, NoteSummary) run;
}

List<_Action> _actionsFor(NoteSummary n) {
  if (n.deletedAt != null) {
    return [
      _Action(
        Icons.restore_from_trash_outlined,
        (c) => c.l10n.restore,
        _restore,
      ),
      _Action(
        Icons.delete_forever_outlined,
        (c) => c.l10n.deleteForever,
        _deleteForever,
      ),
    ];
  }
  return [
    _Action(
      n.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
      (c) => n.isPinned ? c.l10n.unpin : c.l10n.pin,
      (c, r, n) => r.read(noteRepositoryProvider).setPinned(n.id, !n.isPinned),
    ),
    _Action(Icons.drive_file_move_outlined, (c) => c.l10n.moveToFolder, _move),
    _Action(Icons.sell_outlined, (c) => c.l10n.manageTags, (c, r, n) async {
      await showTagPicker(c, r, n.id);
    }),
    _Action(
      n.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
      (c) => n.isArchived ? c.l10n.unarchive : c.l10n.archive,
      _toggleArchive,
    ),
    _Action(Icons.copy_outlined, (c) => c.l10n.duplicate, (c, r, n) async {
      final msg = c.l10n.noteDuplicated;
      await r
          .read(noteRepositoryProvider)
          .duplicate(n.id, copySuffix: c.l10n.copySuffix);
      if (c.mounted) showMessage(c, msg);
    }),
    _Action(Icons.ios_share, (c) => c.l10n.exportMarkdown, exportNoteMarkdown),
    _Action(Icons.delete_outline, (c) => c.l10n.moveToTrash, trashWithUndo),
  ];
}

Future<void> _restore(BuildContext c, WidgetRef r, NoteSummary n) async {
  final msg = c.l10n.noteRestored;
  await r.read(noteRepositoryProvider).restore(n.id);
  if (c.mounted) showMessage(c, msg);
}

Future<void> _deleteForever(BuildContext c, WidgetRef r, NoteSummary n) async {
  final ok = await confirmDialog(
    c,
    title: c.l10n.confirmDeleteForeverTitle,
    body: c.l10n.confirmDeleteForeverBody,
    confirmLabel: c.l10n.deleteForever,
    destructive: true,
  );
  if (ok) await r.read(noteRepositoryProvider).deletePermanently(n.id);
}

Future<void> _toggleArchive(BuildContext c, WidgetRef r, NoteSummary n) async {
  final repo = r.read(noteRepositoryProvider);
  final msg = n.isArchived ? c.l10n.noteUnarchived : c.l10n.noteArchived;
  await repo.setArchived(n.id, !n.isArchived);
  if (c.mounted) {
    showMessage(c, msg, onUndo: () => repo.setArchived(n.id, n.isArchived));
  }
}

Future<void> _move(BuildContext c, WidgetRef r, NoteSummary n) async {
  final choice = await showFolderPicker(c, r, currentId: n.folderId);
  if (choice != null) {
    await r.read(noteRepositoryProvider).moveToFolder(n.id, choice.folderId);
  }
}

/// Trashing is reversible, so it uses an undo snackbar rather than a dialog.
Future<void> trashWithUndo(BuildContext c, WidgetRef r, NoteSummary n) async {
  final repo = r.read(noteRepositoryProvider);
  final msg = c.l10n.noteMovedToTrash;
  await repo.trash(n.id);
  if (c.mounted) showMessage(c, msg, onUndo: () => repo.restore(n.id));
}

Future<void> exportNoteMarkdown(
  BuildContext c,
  WidgetRef r,
  NoteSummary n,
) async {
  final failed = c.l10n.exportNoteFailed;
  try {
    final note = await r.read(noteRepositoryProvider).getById(n.id);
    if (note == null) return;
    final md = MarkdownExporter.export(note.content, title: note.title);
    final dir = await Directory.systemTemp.createTemp('plinth_note_');
    final safe = n.displayTitle.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    final file = File(p.join(dir.path, '${safe.isEmpty ? 'note' : safe}.md'));
    await file.writeAsString(md);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  } catch (_) {
    if (c.mounted) showMessage(c, failed);
  }
}

void openNote(BuildContext context, String id) => context.push('/note/$id');
