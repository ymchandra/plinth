import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/util/l10n_ext.dart';
import '../../folders/data/folder_repository.dart';

/// Result wrapper so "no folder" (null id) differs from "cancelled".
class FolderChoice {
  const FolderChoice(this.folderId);
  final String? folderId;
}

Future<FolderChoice?> showFolderPicker(
  BuildContext context,
  WidgetRef ref, {
  String? currentId,
  String? excludeSubtreeOf,
  bool allowNone = true,
  String? noneLabel,
}) {
  final folders = ref.read(foldersProvider).value ?? const <Folder>[];
  final nodes = flattenFolderTree(folders, excludeSubtreeOf: excludeSubtreeOf);
  return showModalBottomSheet<FolderChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, controller) => ListView(
        controller: controller,
        children: [
          if (allowNone)
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: Text(noneLabel ?? ctx.l10n.noFolder),
              selected: currentId == null,
              onTap: () => Navigator.pop(ctx, const FolderChoice(null)),
            ),
          for (final n in nodes)
            ListTile(
              contentPadding: EdgeInsetsDirectional.only(
                start: 16.0 + n.depth * 20,
                end: 16,
              ),
              leading: const Icon(Icons.folder_outlined),
              title: Text(n.folder.name),
              selected: n.folder.id == currentId,
              onTap: () => Navigator.pop(ctx, FolderChoice(n.folder.id)),
            ),
        ],
      ),
    ),
  );
}
