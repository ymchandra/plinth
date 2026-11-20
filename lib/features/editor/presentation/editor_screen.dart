import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/util/l10n_ext.dart';
import '../../../core/widgets/widgets.dart';
import '../../attachments/data/attachment_repository.dart';
import '../../folders/presentation/folder_picker.dart';
import '../../notes/domain/note.dart';
import '../../notes/presentation/note_actions.dart';
import '../../tags/presentation/tag_picker.dart';
import '../domain/autosave_controller.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.noteId});
  final String noteId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver {
  Note? _note;
  bool _missing = false;
  QuillController? _quill;
  final _title = TextEditingController();
  final _bodyFocus = FocusNode();
  final _scroll = ScrollController();
  AutosaveController? _autosave;
  StreamSubscription<DocChange>? _changes;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final note = await ref.read(noteRepositoryProvider).getById(widget.noteId);
    if (!mounted) return;
    if (note == null) {
      setState(() => _missing = true);
      return;
    }
    Document doc;
    try {
      doc = Document.fromJson(jsonDecode(note.content) as List);
    } catch (_) {
      doc = Document();
    }
    final q = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: note.isTrashed,
    );
    _title.text = note.title ?? '';
    final repo = ref.read(noteRepositoryProvider);
    _autosave = AutosaveController(
      initial: NoteDraft(title: _title.text, contentJson: _contentJson(q)),
      save: (d) => repo.updateContent(
        note.id,
        title: d.title,
        contentJson: d.contentJson,
      ),
    );
    _changes = q.changes.listen((_) => _schedule());
    _title.addListener(_schedule);
    setState(() {
      _note = note;
      _quill = q;
    });
  }

  String _contentJson(QuillController q) =>
      jsonEncode(q.document.toDelta().toJson());

  void _schedule() {
    final q = _quill;
    if (q == null || _note == null || _note!.isTrashed) return;
    _autosave?.schedule(
      NoteDraft(title: _title.text, contentJson: _contentJson(q)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_autosave?.flush());
    }
  }

  /// Saves, and discards a note that was created but never filled in.
  Future<void> _finish() async {
    if (_leaving) return;
    _leaving = true;
    final note = _note;
    await _autosave?.flush();
    if (note == null || note.isTrashed) return;
    final q = _quill!;
    final empty =
        _title.text.trim().isEmpty && q.document.toPlainText().trim().isEmpty;
    if (empty) {
      final atts = await ref
          .read(attachmentRepositoryProvider)
          .watchForNote(note.id)
          .first;
      if (atts.isEmpty) {
        await ref.read(noteRepositoryProvider).deletePermanently(note.id);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changes?.cancel();
    _title.dispose();
    _bodyFocus.dispose();
    _scroll.dispose();
    _quill?.dispose();
    unawaited(_autosave?.dispose());
    super.dispose();
  }

  NoteSummary _summary() {
    final n = _note!;
    return NoteSummary(
      id: n.id,
      title: _title.text,
      derivedTitle: '',
      preview: '',
      folderId: n.folderId,
      folderName: null,
      isPinned: n.isPinned,
      isArchived: n.isArchived,
      createdAt: n.createdAt,
      updatedAt: n.updatedAt,
      deletedAt: n.deletedAt,
    );
  }

  Future<void> _refreshNote() async {
    final n = await ref.read(noteRepositoryProvider).getById(widget.noteId);
    if (mounted && n != null) setState(() => _note = n);
  }

  Future<void> _addPhoto(ImageSource source) async {
    final failed = context.l10n.attachmentFailed;
    final repo = ref.read(attachmentRepositoryProvider);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _autosave?.flush();
      await repo.addFromFile(
        widget.noteId,
        File(picked.path),
        filename: picked.name,
      );
    } catch (_) {
      if (mounted) showMessage(context, failed);
    }
  }

  Future<void> _photoSheet() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(ctx.l10n.addPhoto),
            onTap: () {
              Navigator.pop(ctx);
              _addPhoto(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(ctx.l10n.takePhoto),
            onTap: () {
              Navigator.pop(ctx);
              _addPhoto(ImageSource.camera);
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _menu(String action) async {
    final n = _summary();
    switch (action) {
      case 'pin':
        await ref.read(noteRepositoryProvider).setPinned(n.id, !n.isPinned);
      case 'move':
        final c = await showFolderPicker(context, ref, currentId: n.folderId);
        if (c != null) {
          await ref.read(noteRepositoryProvider).moveToFolder(n.id, c.folderId);
        }
      case 'tags':
        await showTagPicker(context, ref, n.id);
      case 'archive':
        await ref.read(noteRepositoryProvider).setArchived(n.id, !n.isArchived);
      case 'export':
        await _autosave?.flush();
        if (mounted) await exportNoteMarkdown(context, ref, n);
      case 'trash':
        await _autosave?.flush();
        if (!mounted) return;
        final ok = await confirmDialog(
          context,
          title: context.l10n.confirmTrashTitle,
          body: context.l10n.confirmTrashBody,
          confirmLabel: context.l10n.moveToTrash,
        );
        if (!ok || !mounted) return;
        await ref.read(noteRepositoryProvider).trash(n.id);
        _leaving = true;
        if (mounted) Navigator.of(context).pop();
        return;
    }
    await _refreshNote();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_missing) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.error_outline, title: l10n.genericError),
      );
    }
    final note = _note;
    final q = _quill;
    if (note == null || q == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final scale = ref.watch(settingsProvider).editorScale;
    final mq = MediaQuery.of(context);
    final trashed = note.isTrashed;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        await _finish();
        if (nav.mounted) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _SaveIndicator(autosave: _autosave!),
          actions: [
            if (!trashed)
              IconButton(
                tooltip: l10n.attachments,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: _photoSheet,
              ),
            if (!trashed)
              PopupMenuButton<String>(
                tooltip: l10n.more,
                onSelected: _menu,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(note.isPinned ? l10n.unpin : l10n.pin),
                  ),
                  PopupMenuItem(value: 'move', child: Text(l10n.moveToFolder)),
                  PopupMenuItem(value: 'tags', child: Text(l10n.manageTags)),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(
                      note.isArchived ? l10n.unarchive : l10n.archive,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Text(l10n.exportMarkdown),
                  ),
                  PopupMenuItem(value: 'trash', child: Text(l10n.moveToTrash)),
                ],
              ),
          ],
        ),
        body: SafeArea(
          child: CenteredContent(
            child: Column(
              children: [
                if (trashed)
                  MaterialBanner(
                    content: Text(l10n.trashTitle),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(noteRepositoryProvider)
                              .restore(note.id);
                          q.readOnly = false;
                          await _refreshNote();
                        },
                        child: Text(l10n.restore),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.md,
                    Space.sm,
                    Space.md,
                    0,
                  ),
                  child: TextField(
                    controller: _title,
                    readOnly: trashed,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    style: Theme.of(context).textTheme.headlineSmall,
                    maxLines: null,
                    decoration: InputDecoration.collapsed(
                      hintText: l10n.titleHint,
                    ),
                    onSubmitted: (_) => _bodyFocus.requestFocus(),
                  ),
                ),
                _TagsRow(noteId: note.id, enabled: !trashed),
                _AttachmentStrip(noteId: note.id, enabled: !trashed),
                Expanded(
                  child: MediaQuery(
                    data: mq.copyWith(
                      textScaler: TextScaler.linear(
                        mq.textScaler.scale(1) * scale,
                      ),
                    ),
                    child: QuillEditor(
                      controller: q,
                      focusNode: _bodyFocus,
                      scrollController: _scroll,
                      config: QuillEditorConfig(
                        padding: const EdgeInsets.all(Space.md),
                        placeholder: l10n.bodyHint,
                        autoFocus: note.title == null && q.document.isEmpty(),
                      ),
                    ),
                  ),
                ),
                if (!trashed) _Toolbar(controller: q),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.autosave});
  final AutosaveController autosave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<SaveStatus>(
      stream: autosave.statusStream,
      initialData: autosave.status,
      builder: (context, snap) {
        final (text, color) = switch (snap.data) {
          SaveStatus.saving => (l10n.saving, null),
          SaveStatus.dirty => (l10n.unsavedChanges, null),
          SaveStatus.saved => (l10n.saved, null),
          SaveStatus.error => (
            l10n.saveFailed,
            Theme.of(context).colorScheme.error,
          ),
          _ => ('', null),
        };
        return Semantics(
          liveRegion: true,
          child: Text(
            text,
            maxLines: 2,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: color),
          ),
        );
      },
    );
  }
}

class _TagsRow extends ConsumerWidget {
  const _TagsRow({required this.noteId, required this.enabled});
  final String noteId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(noteTagsProvider(noteId)).value ?? const [];
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: Space.sm,
          children: [
            for (final t in tags)
              InputChip(
                label: Text(t.name),
                onPressed: enabled
                    ? () => showTagPicker(context, ref, noteId)
                    : null,
                onDeleted: enabled
                    ? () => ref
                          .read(tagRepositoryProvider)
                          .removeFromNote(noteId, t.id)
                    : null,
                deleteButtonTooltipMessage: context.l10n.delete,
              ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentStrip extends ConsumerWidget {
  const _AttachmentStrip({required this.noteId, required this.enabled});
  final String noteId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atts = ref.watch(attachmentsProvider(noteId)).value ?? const [];
    if (atts.isEmpty) return const SizedBox.shrink();
    final repo = ref.read(attachmentRepositoryProvider);
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(Space.sm),
        itemCount: atts.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) => _Thumb(
          attachment: atts[i],
          file: repo.fileFor(atts[i]),
          onRemove: enabled
              ? () async {
                  final ok = await confirmDialog(
                    context,
                    title: context.l10n.confirmRemoveAttachmentTitle,
                    body: context.l10n.confirmRemoveAttachmentBody,
                    confirmLabel: context.l10n.delete,
                    destructive: true,
                  );
                  if (ok) await repo.remove(atts[i].id);
                }
              : null,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.attachment, required this.file, this.onRemove});
  final Attachment attachment;
  final File file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exists = file.existsSync();
    return Semantics(
      label: l10n.noteImagePreview(attachment.filename),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.chip),
            child: SizedBox(
              width: 80,
              height: 80,
              child: exists
                  ? InkWell(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => Dialog(
                          child: InteractiveViewer(
                            child: Image.file(
                              file,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        cacheWidth: 240,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    )
                  : Tooltip(
                      message: l10n.attachmentMissing,
                      child: ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          ),
          if (onRemove != null)
            PositionedDirectional(
              top: -4,
              end: -4,
              child: IconButton.filledTonal(
                tooltip: l10n.removeAttachment,
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});
  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final attrs = controller.getSelectionStyle().attributes;
            bool on(Attribute a) =>
                attrs[a.key]?.value == a.value ||
                (a.value == true && attrs.containsKey(a.key));
            Widget toggle(IconData icon, String label, Attribute a) =>
                _ToolButton(
                  icon: icon,
                  label: label,
                  active: on(a),
                  onPressed: () => controller.formatSelection(
                    on(a) ? Attribute.clone(a, null) : a,
                  ),
                );
            return Row(
              children: [
                _ToolButton(
                  icon: Icons.undo,
                  label: l10n.undo,
                  onPressed: controller.hasUndo ? controller.undo : null,
                ),
                _ToolButton(
                  icon: Icons.redo,
                  label: l10n.redo,
                  onPressed: controller.hasRedo ? controller.redo : null,
                ),
                toggle(Icons.format_bold, l10n.bold, Attribute.bold),
                toggle(Icons.format_italic, l10n.italic, Attribute.italic),
                toggle(
                  Icons.format_underline,
                  l10n.underline,
                  Attribute.underline,
                ),
                toggle(Icons.looks_one_outlined, l10n.heading1, Attribute.h1),
                toggle(Icons.looks_two_outlined, l10n.heading2, Attribute.h2),
                toggle(Icons.looks_3_outlined, l10n.heading3, Attribute.h3),
                toggle(
                  Icons.format_list_bulleted,
                  l10n.bulletList,
                  Attribute.ul,
                ),
                toggle(
                  Icons.format_list_numbered,
                  l10n.numberedList,
                  Attribute.ol,
                ),
                toggle(Icons.checklist, l10n.checklist, Attribute.unchecked),
                toggle(Icons.format_quote, l10n.quote, Attribute.blockQuote),
                _ToolButton(
                  icon: Icons.link,
                  label: l10n.link,
                  active: attrs.containsKey(Attribute.link.key),
                  onPressed: () => _editLink(context, attrs),
                ),
                _ToolButton(
                  icon: Icons.keyboard_hide_outlined,
                  label: l10n.dismissKeyboard,
                  onPressed: () =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editLink(
    BuildContext context,
    Map<String, Attribute> attrs,
  ) async {
    final current = attrs[Attribute.link.key]?.value as String?;
    final url = await promptText(
      context,
      title: context.l10n.linkDialogTitle,
      hint: context.l10n.linkUrlHint,
      confirmLabel: context.l10n.save,
      initial: current ?? '',
      keyboardType: TextInputType.url,
    );
    if (url == null) return;
    controller.formatSelection(LinkAttribute(url));
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    isSelected: active,
    icon: Icon(icon),
    style: IconButton.styleFrom(minimumSize: const Size.square(Sizes.touch)),
    onPressed: onPressed,
  );
}
