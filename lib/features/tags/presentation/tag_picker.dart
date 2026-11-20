import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/errors.dart';
import '../../../core/util/l10n_ext.dart';
import '../../../core/widgets/widgets.dart';

/// Sheet to toggle tags on a note and create new ones.
Future<void> showTagPicker(BuildContext context, WidgetRef ref, String noteId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _TagPickerSheet(noteId: noteId),
  );
}

class _TagPickerSheet extends ConsumerWidget {
  const _TagPickerSheet({required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(tagsProvider).value ?? const [];
    final selected = (ref.watch(noteTagsProvider(noteId)).value ?? const [])
        .map((t) => t.id)
        .toSet();
    final repo = ref.read(tagRepositoryProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(context.l10n.newTag),
              onTap: () async {
                final name = await promptText(
                  context,
                  title: context.l10n.newTag,
                  hint: context.l10n.tagNameHint,
                  confirmLabel: context.l10n.create,
                );
                if (name == null) return;
                final tag = await repo.create(name);
                await repo.addToNote(noteId, tag.id);
              },
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in all)
                    CheckboxListTile(
                      value: selected.contains(t.id),
                      title: Text(t.name),
                      onChanged: (v) => v == true
                          ? repo.addToNote(noteId, t.id)
                          : repo.removeFromNote(noteId, t.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prompts for a tag name, reporting duplicates and invalid names.
Future<void> promptRenameTag(
  BuildContext context,
  WidgetRef ref,
  String id,
  String current,
) async {
  final name = await promptText(
    context,
    title: context.l10n.renameTag,
    hint: context.l10n.tagNameHint,
    confirmLabel: context.l10n.save,
    initial: current,
  );
  if (name == null) return;
  try {
    await ref.read(tagRepositoryProvider).rename(id, name);
  } on DuplicateTagException {
    if (context.mounted) showMessage(context, context.l10n.tagNameExists);
  } on ValidationException {
    if (context.mounted) showMessage(context, context.l10n.nameRequired);
  }
}
