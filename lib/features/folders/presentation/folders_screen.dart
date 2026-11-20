import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/errors/errors.dart';
import '../../../core/util/l10n_ext.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/home_screen.dart';
import '../../notes/domain/note.dart';
import '../../notes/presentation/note_list_view.dart';
import '../../tags/data/tag_repository.dart';
import '../../tags/presentation/tag_picker.dart';
import '../data/folder_repository.dart';
import 'folder_picker.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final nodes = flattenFolderTree(folders);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.foldersTitle)),
      body: CenteredContent(
        child: ListView(
          children: [
            SectionHeader(l10n.library),
            _row(context, Icons.notes, l10n.allNotes, '/library/all'),
            _row(
              context,
              Icons.archive_outlined,
              l10n.archiveTitle,
              '/library/archive',
            ),
            _row(
              context,
              Icons.delete_outline,
              l10n.trashTitle,
              '/library/trash',
            ),
            SectionHeader(
              l10n.foldersTitle,
              trailing: IconButton(
                tooltip: l10n.newFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: () => createFolder(context, ref),
              ),
            ),
            if (nodes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noFolders),
              ),
            for (final n in nodes)
              ListTile(
                contentPadding: EdgeInsetsDirectional.only(
                  start: 16.0 + n.depth * 20,
                  end: 4,
                ),
                leading: const Icon(Icons.folder_outlined),
                title: Text(n.folder.name),
                onTap: () => context.push('/folder/${n.folder.id}'),
                trailing: PopupMenuButton<String>(
                  tooltip: l10n.more,
                  onSelected: (a) => _folderAction(context, ref, n.folder, a),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'sub', child: Text(l10n.newSubfolder)),
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(l10n.renameFolder),
                    ),
                    PopupMenuItem(value: 'move', child: Text(l10n.moveFolder)),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.deleteFolder),
                    ),
                  ],
                ),
              ),
            SectionHeader(
              l10n.tagsTitle,
              trailing: IconButton(
                tooltip: l10n.newTag,
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final name = await promptText(
                    context,
                    title: l10n.newTag,
                    hint: l10n.tagNameHint,
                    confirmLabel: l10n.create,
                  );
                  if (name != null) {
                    await ref.read(tagRepositoryProvider).create(name);
                  }
                },
              ),
            ),
            if (tags.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noTags),
              ),
            for (final t in tags)
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: Text(t.name),
                subtitle: Text(l10n.notesCount(t.noteCount)),
                onTap: () => context.push('/tag/${t.id}'),
                trailing: PopupMenuButton<String>(
                  tooltip: l10n.more,
                  onSelected: (a) async {
                    if (a == 'rename') {
                      await promptRenameTag(context, ref, t.id, t.name);
                    } else {
                      final ok = await confirmDialog(
                        context,
                        title: l10n.confirmDeleteTagTitle(t.name),
                        body: l10n.confirmDeleteTagBody,
                        confirmLabel: l10n.delete,
                        destructive: true,
                      );
                      if (ok) {
                        await ref.read(tagRepositoryProvider).delete(t.id);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(l10n.renameTag)),
                    PopupMenuItem(value: 'delete', child: Text(l10n.deleteTag)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext c, IconData icon, String label, String path) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () => c.push(path),
      );

  Future<void> _folderAction(
    BuildContext context,
    WidgetRef ref,
    Folder f,
    String action,
  ) async {
    final l10n = context.l10n;
    final repo = ref.read(folderRepositoryProvider);
    switch (action) {
      case 'sub':
        await createFolder(context, ref, parentId: f.id);
      case 'rename':
        final name = await promptText(
          context,
          title: l10n.renameFolder,
          hint: l10n.folderNameHint,
          confirmLabel: l10n.save,
          initial: f.name,
        );
        if (name != null) await repo.rename(f.id, name);
      case 'move':
        final c = await showFolderPicker(
          context,
          ref,
          currentId: f.parentFolderId,
          excludeSubtreeOf: f.id,
          noneLabel: l10n.topLevel,
        );
        if (c == null) return;
        try {
          await repo.move(f.id, c.folderId);
        } on CircularFolderException {
          if (context.mounted) showMessage(context, l10n.circularFolder);
        }
      case 'delete':
        final choice = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.deleteFolderTitle(f.name)),
            content: Text(l10n.deleteFolderBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.leaveNotesUnorganised),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.moveNotesToParent),
              ),
            ],
          ),
        );
        if (choice != null) await repo.delete(f.id, moveNotesToParent: choice);
    }
  }
}

Future<void> createFolder(
  BuildContext context,
  WidgetRef ref, {
  String? parentId,
}) async {
  final l10n = context.l10n;
  final name = await promptText(
    context,
    title: parentId == null ? l10n.newFolder : l10n.newSubfolder,
    hint: l10n.folderNameHint,
    confirmLabel: l10n.create,
  );
  if (name != null) {
    await ref.read(folderRepositoryProvider).create(name, parentId: parentId);
  }
}

/// Notes in one folder (opened from Home chips or the Folders tab).
class FolderDetailScreen extends ConsumerWidget {
  const FolderDetailScreen({super.key, required this.folderId});
  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folder = ref
        .watch(foldersProvider)
        .value
        ?.where((f) => f.id == folderId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(folder?.name ?? l10n.foldersTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-note-folder',
        onPressed: () => createNoteAndOpen(context, ref, folderId: folderId),
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.newNote),
      ),
      body: NoteListView(
        query: NoteQuery(folderId: folderId),
        emptyIcon: Icons.folder_open,
        emptyTitle: l10n.emptyFolderTitle,
        emptyBody: l10n.emptyFolderBody,
      ),
    );
  }
}

class TagDetailScreen extends ConsumerWidget {
  const TagDetailScreen({super.key, required this.tagId});
  final String tagId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tag = ref
        .watch(tagsProvider)
        .value
        ?.where((t) => t.id == tagId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(tag?.name ?? l10n.tagsTitle)),
      body: NoteListView(
        query: NoteQuery(tagId: tagId),
        emptyIcon: Icons.sell_outlined,
        emptyTitle: l10n.emptyListTitle,
      ),
    );
  }
}

/// All notes, archive, or trash.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, required this.scope});
  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final days = ref.watch(settingsProvider).trashRetentionDays;
    final (title, query, icon, body) = switch (scope) {
      'archive' => (
        l10n.archiveTitle,
        const NoteQuery(scope: NoteScope.archived),
        Icons.archive_outlined,
        l10n.emptyArchiveBody,
      ),
      'trash' => (
        l10n.trashTitle,
        const NoteQuery(scope: NoteScope.trashed),
        Icons.delete_outline,
        l10n.emptyTrashBody,
      ),
      _ => (
        l10n.allNotes,
        const NoteQuery(pinnedFirst: true),
        Icons.notes,
        l10n.emptyHomeBody,
      ),
    };
    final isTrash = scope == 'trash';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isTrash)
            TextButton(
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: l10n.confirmEmptyTrashTitle,
                  body: l10n.confirmEmptyTrashBody,
                  confirmLabel: l10n.emptyTrash,
                  destructive: true,
                );
                if (ok) await ref.read(noteRepositoryProvider).emptyTrash();
              },
              child: Text(l10n.emptyTrash),
            ),
        ],
      ),
      body: NoteListView(
        query: query,
        emptyIcon: icon,
        emptyTitle: scope == 'all' ? l10n.emptyHomeTitle : title,
        emptyBody: body,
        header: isTrash
            ? Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  days == 0
                      ? l10n.trashKeptHint
                      : l10n.trashRetentionHint(days),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            : null,
      ),
    );
  }
}
