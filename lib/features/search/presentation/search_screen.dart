import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/util/l10n_ext.dart';
import '../../../core/widgets/widgets.dart';
import '../../folders/presentation/folder_picker.dart';
import '../../notes/presentation/note_actions.dart';
import '../data/search_repository.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  SearchFilters _filters = const SearchFilters();
  List<SearchHit>? _hits;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    setState(() => _query = text);
    _debounce = Timer(const Duration(milliseconds: 250), _run);
  }

  Future<void> _run() async {
    final q = _query.trim();
    final gen = ++_generation;
    if (q.isEmpty) {
      setState(() => _hits = null);
      return;
    }
    final hits = await ref
        .read(searchRepositoryProvider)
        .search(q, filters: _filters);
    // Ignore results of superseded searches.
    if (mounted && gen == _generation) setState(() => _hits = hits);
  }

  void _setFilters(SearchFilters f) {
    setState(() => _filters = f);
    _run();
  }

  void _useRecent(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _query = q);
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final folders = ref.watch(foldersProvider).value ?? const [];
    final tags = ref.watch(tagsProvider).value ?? const [];
    final folderName = folders
        .where((f) => f.id == _filters.folderId)
        .firstOrNull
        ?.name;
    final tagName = tags.where((t) => t.id == _filters.tagId).firstOrNull?.name;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: false,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (v) {
            final q = v.trim();
            if (q.isNotEmpty) ref.read(searchRepositoryProvider).addRecent(q);
          },
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.cancel,
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
        ),
      ),
      body: CenteredContent(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                children: [
                  _chip(
                    label: l10n.filterPinned,
                    selected: _filters.pinnedOnly,
                    onTap: () => _setFilters(
                      _filters.copyWith(pinnedOnly: !_filters.pinnedOnly),
                    ),
                  ),
                  _chip(
                    label: l10n.filterArchived,
                    selected: _filters.archive == ArchiveFilter.include,
                    onTap: () => _setFilters(
                      _filters.copyWith(
                        archive: _filters.archive == ArchiveFilter.include
                            ? ArchiveFilter.hide
                            : ArchiveFilter.include,
                      ),
                    ),
                  ),
                  _chip(
                    label: folderName ?? l10n.filterFolder,
                    selected: _filters.folderId != null,
                    onTap: () async {
                      final c = await showFolderPicker(
                        context,
                        ref,
                        currentId: _filters.folderId,
                        noneLabel: l10n.allNotes,
                      );
                      if (c != null) {
                        _setFilters(_filters.copyWith(folderId: c.folderId));
                      }
                    },
                  ),
                  _chip(
                    label: tagName ?? l10n.filterTag,
                    selected: _filters.tagId != null,
                    onTap: () => _pickTag(tags),
                  ),
                  if (!_filters.isEmpty)
                    TextButton(
                      onPressed: () => _setFilters(const SearchFilters()),
                      child: Text(l10n.clearFilters),
                    ),
                ],
              ),
            ),
            Expanded(child: _results(context)),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsetsDirectional.only(end: Space.sm),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );

  Future<void> _pickTag(List tags) async {
    final l10n = context.l10n;
    final id = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(l10n.allNotes),
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final t in tags)
            ListTile(
              leading: const Icon(Icons.sell_outlined),
              title: Text(t.name),
              selected: t.id == _filters.tagId,
              onTap: () => Navigator.pop(ctx, t.id as String),
            ),
        ],
      ),
    );
    if (id != null) {
      _setFilters(_filters.copyWith(tagId: id.isEmpty ? null : id));
    }
  }

  Widget _results(BuildContext context) {
    final l10n = context.l10n;
    final hits = _hits;
    if (_query.trim().isEmpty) {
      final recents = ref.watch(recentSearchesProvider).value ?? const [];
      if (recents.isEmpty) {
        return EmptyState(
          icon: Icons.search,
          title: l10n.searchPrompt,
          body: l10n.searchPromptBody,
        );
      }
      return ListView(
        children: [
          SectionHeader(
            l10n.recentSearches,
            trailing: TextButton(
              onPressed: () => ref.read(searchRepositoryProvider).clearRecent(),
              child: Text(l10n.clearRecent),
            ),
          ),
          for (final r in recents)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(r),
              onTap: () => _useRecent(r),
            ),
        ],
      );
    }
    if (hits == null) return const Center(child: CircularProgressIndicator());
    if (hits.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: l10n.noResultsTitle,
        body: l10n.noResultsBody,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Space.md),
      itemCount: hits.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
      itemBuilder: (context, i) => _HitTile(
        hit: hits[i],
        onOpen: () {
          final q = _query.trim();
          if (q.isNotEmpty) ref.read(searchRepositoryProvider).addRecent(q);
          openNote(context, hits[i].noteId);
        },
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onOpen});
  final SearchHit hit;
  final VoidCallback onOpen;

  List<TextSpan> _spans(String marked, TextStyle? base, Color color) => [
    for (final s in parseHighlights(marked))
      TextSpan(
        text: s.text,
        style: s.isMatch
            ? base?.copyWith(
                fontWeight: FontWeight.bold,
                backgroundColor: color,
              )
            : base,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final l10n = context.l10n;
    final hl = t.colorScheme.primaryContainer;
    final plainTitle = parseHighlights(hit.title).map((s) => s.text).join();
    final plainSnippet = parseHighlights(hit.snippet).map((s) => s.text).join();
    return Semantics(
      button: true,
      label: [
        plainTitle.isEmpty ? l10n.untitled : plainTitle,
        plainSnippet,
      ].join(', '),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: plainTitle.isEmpty
                          ? [TextSpan(text: l10n.untitled)]
                          : _spans(hit.title, t.textTheme.titleMedium, hl),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (plainSnippet.isNotEmpty) ...[
                    const SizedBox(height: Space.xs),
                    Text.rich(
                      TextSpan(
                        children: _spans(
                          hit.snippet,
                          t.textTheme.bodyMedium,
                          hl,
                        ),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (hit.folderName != null || hit.isArchived) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      [
                        ?hit.folderName,
                        if (hit.isArchived) l10n.archiveTitle,
                      ].join(' · '),
                      style: t.textTheme.labelSmall?.copyWith(
                        color: t.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
