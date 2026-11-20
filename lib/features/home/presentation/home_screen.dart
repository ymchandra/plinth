import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/util/l10n_ext.dart';
import '../../notes/domain/note.dart';
import '../../notes/domain/templates.dart';
import '../../notes/presentation/note_list_view.dart';

/// Creates a note (optionally from a template, in a folder) and opens it.
Future<void> createNoteAndOpen(
  BuildContext context,
  WidgetRef ref, {
  NoteTemplate template = NoteTemplate.blank,
  String? folderId,
}) async {
  final content = buildTemplate(context.l10n, template);
  final note = await ref
      .read(noteRepositoryProvider)
      .create(
        folderId: folderId,
        title: content.title,
        contentJson: content.deltaJson,
      );
  if (context.mounted) context.push('/note/${note.id}');
}

Future<void> showTemplateSheet(
  BuildContext context,
  WidgetRef ref, {
  String? folderId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                ctx.l10n.chooseTemplate,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final t in NoteTemplate.values)
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: Text(templateName(ctx.l10n, t)),
                onTap: () {
                  Navigator.pop(ctx);
                  createNoteAndOpen(
                    context,
                    ref,
                    template: t,
                    folderId: folderId,
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folders = ref.watch(foldersProvider).value ?? const [];
    final topFolders = folders.where((f) => f.parentFolderId == null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: l10n.homeSearchHint,
          child: ExcludeSemantics(
            child: SearchBar(
              hintText: l10n.homeSearchHint,
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              readOnly: true,
              onTap: () => context.go('/search'),
            ),
          ),
        ),
        if (topFolders.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          SizedBox(
            height: Sizes.touch,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in topFolders)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Space.sm),
                    child: ActionChip(
                      avatar: const Icon(Icons.folder_outlined, size: 18),
                      label: Text(f.name),
                      onPressed: () => context.push('/folder/${f.id}'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            tooltip: l10n.newFromTemplate,
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => showTemplateSheet(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-note',
        onPressed: () => createNoteAndOpen(context, ref),
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.newNote),
      ),
      body: _HomeBody(header: header),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.header});
  final Widget header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return NoteListView(
      query: const NoteQuery(pinnedFirst: true),
      emptyIcon: Icons.edit_note,
      emptyTitle: l10n.emptyHomeTitle,
      emptyBody: l10n.emptyHomeBody,
      emptyAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () => createNoteAndOpen(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l10n.newNote),
          ),
          TextButton(
            onPressed: () => showTemplateSheet(context, ref),
            child: Text(l10n.newFromTemplate),
          ),
        ],
      ),
      header: header,
    );
  }
}
