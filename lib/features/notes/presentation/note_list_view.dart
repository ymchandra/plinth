import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/util/l10n_ext.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/note.dart';
import 'note_actions.dart';

typedef _Key = ({NoteQuery query, int limit});

final _noteListProvider = StreamProvider.autoDispose
    .family<List<NoteSummary>, _Key>(
      (ref, key) => ref
          .watch(noteRepositoryProvider)
          .watchList(
            withSort(key.query, ref.watch(settingsProvider)),
            limit: key.limit,
          ),
    );

/// Paginated list of notes. Grows its page when scrolled near the end.
class NoteListView extends ConsumerStatefulWidget {
  const NoteListView({
    super.key,
    required this.query,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptyBody,
    this.emptyAction,
    this.header,
    this.pageSize = 40,
  });

  final NoteQuery query;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyBody;
  final Widget? emptyAction;
  final Widget? header;
  final int pageSize;

  @override
  ConsumerState<NoteListView> createState() => _NoteListViewState();
}

class _NoteListViewState extends ConsumerState<NoteListView> {
  late int _limit = widget.pageSize;

  @override
  void didUpdateWidget(NoteListView old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _limit = widget.pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      _noteListProvider((query: widget.query, limit: _limit)),
    );
    final notes = async.value;
    if (notes == null) {
      return async.hasError
          ? EmptyState(
              icon: Icons.error_outline,
              title: context.l10n.genericError,
            )
          : const Center(child: CircularProgressIndicator());
    }
    if (notes.isEmpty) {
      return EmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        body: widget.emptyBody,
        action: widget.emptyAction,
      );
    }
    final mayHaveMore = notes.length >= _limit;
    return CenteredContent(
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (mayHaveMore && n.metrics.extentAfter < 400) {
            setState(() => _limit += widget.pageSize);
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(Space.md),
          itemCount: notes.length + (widget.header == null ? 0 : 1),
          separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
          itemBuilder: (context, i) {
            if (widget.header != null) {
              if (i == 0) return widget.header!;
              i--;
            }
            return NoteTile(note: notes[i]);
          },
        ),
      ),
    );
  }
}

class NoteTile extends ConsumerWidget {
  const NoteTile({super.key, required this.note});
  final NoteSummary note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = Theme.of(context);
    final title = note.displayTitle.isEmpty ? l10n.untitled : note.displayTitle;
    final preview = note.preview.isEmpty ? l10n.noAdditionalText : note.preview;
    final date = formatNoteDate(context, note.updatedAt);
    final trashed = note.deletedAt != null;
    return Semantics(
      container: true,
      label: [
        if (note.isPinned) l10n.pinned,
        title,
        preview,
        l10n.editedAt(date),
      ].join(', '),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => trashed
              ? showNoteActions(context, ref, note)
              : openNote(context, note.id),
          onLongPress: () => showNoteActions(context, ref, note),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.md,
              Space.md,
              Space.xs,
              Space.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (note.isPinned)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: Space.xs,
                                ),
                                child: Icon(
                                  Icons.push_pin,
                                  size: 16,
                                  color: t.colorScheme.primary,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: Space.sm),
                        Text(
                          [date, ?note.folderName].join(' · '),
                          style: t.textTheme.labelSmall?.copyWith(
                            color: t.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.more,
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => showNoteActions(context, ref, note),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
