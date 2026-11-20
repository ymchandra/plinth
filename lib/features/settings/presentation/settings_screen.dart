import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../core/util/l10n_ext.dart';
import '../../../core/widgets/widgets.dart';
import '../../backup/data/backup_service.dart';
import '../../notes/domain/note.dart';
import '../data/settings_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);

    Widget choice<T>({
      required String title,
      required T value,
      required Map<T, String> options,
      required void Function(T) onChanged,
    }) => ListTile(
      title: Text(title),
      subtitle: Text(options[value] ?? ''),
      onTap: () async {
        final picked = await showDialog<T>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(title),
            children: [
              RadioGroup<T>(
                groupValue: value,
                onChanged: (v) => Navigator.pop(ctx, v),
                child: Column(
                  children: [
                    for (final e in options.entries)
                      RadioListTile<T>(value: e.key, title: Text(e.value)),
                  ],
                ),
              ),
            ],
          ),
        );
        if (picked != null) onChanged(picked);
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: CenteredContent(
        child: ListView(
          children: [
            SectionHeader(l10n.appearance),
            choice<ThemePreference>(
              title: l10n.theme,
              value: s.theme,
              options: {
                ThemePreference.system: l10n.themeSystem,
                ThemePreference.light: l10n.themeLight,
                ThemePreference.dark: l10n.themeDark,
              },
              onChanged: (v) => ctl.update((s) => s.copyWith(theme: v)),
            ),
            choice<EditorFontSize>(
              title: l10n.editorFontSize,
              value: s.editorFontSize,
              options: {
                EditorFontSize.small: l10n.sizeSmall,
                EditorFontSize.medium: l10n.sizeMedium,
                EditorFontSize.large: l10n.sizeLarge,
              },
              onChanged: (v) =>
                  ctl.update((s) => s.copyWith(editorFontSize: v)),
            ),
            SectionHeader(l10n.general),
            choice<LandingScreen>(
              title: l10n.landingScreen,
              value: s.landing,
              options: {
                LandingScreen.home: l10n.navHome,
                LandingScreen.search: l10n.navSearch,
                LandingScreen.folders: l10n.navFolders,
              },
              onChanged: (v) => ctl.update((s) => s.copyWith(landing: v)),
            ),
            choice<SortOrder>(
              title: l10n.sortOrder,
              value: s.sortOrder,
              options: {
                SortOrder.updatedDesc: l10n.sortUpdated,
                SortOrder.createdDesc: l10n.sortCreated,
                SortOrder.titleAsc: l10n.sortTitle,
              },
              onChanged: (v) => ctl.update((s) => s.copyWith(sortOrder: v)),
            ),
            choice<int>(
              title: l10n.trashRetention,
              value: s.trashRetentionDays,
              options: {
                for (final d in AppSettings.retentionOptions)
                  d: d == 0 ? l10n.retentionForever : l10n.retentionDays(d),
              },
              onChanged: (v) =>
                  ctl.update((s) => s.copyWith(trashRetentionDays: v)),
            ),
            SectionHeader(l10n.dataSection),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l10n.exportAll),
              subtitle: Text(l10n.exportAllSub),
              onTap: () => _export(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.importArchive),
              subtitle: Text(l10n.importArchiveSub),
              onTap: () => _import(context, ref),
            ),
            SectionHeader(l10n.privacySection),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(l10n.privacyTitle),
              subtitle: Text(l10n.privacyBody),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    showMessage(context, l10n.exporting);
    try {
      final tmp = await getTemporaryDirectory();
      final dir = await Directory('${tmp.path}/export').create(recursive: true);
      final result = await ref.read(backupServiceProvider).exportAll(dir);
      if (context.mounted) {
        showMessage(
          context,
          result.missingAttachments > 0
              ? l10n.exportMissingFiles(result.missingAttachments)
              : l10n.exportReady(result.notes, result.attachments),
        );
      }
      await SharePlus.instance.share(
        ShareParams(files: [XFile(result.file.path)]),
      );
    } catch (e) {
      if (context.mounted) showMessage(context, l10n.exportFailed('$e'));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final backup = ref.read(backupServiceProvider);
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    ImportSession session;
    try {
      session = await backup.prepareImport(await File(path).readAsBytes());
    } on ImportException catch (e) {
      if (context.mounted) showMessage(context, l10n.importInvalid(e.message));
      return;
    } catch (e) {
      if (context.mounted) showMessage(context, l10n.importInvalid('$e'));
      return;
    }
    if (!context.mounted) return;
    final pv = session.preview;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importReviewTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.importSummary(
                  pv.notes,
                  pv.folders,
                  pv.tags,
                  pv.attachments,
                ),
              ),
              if (pv.warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.importWarnings(pv.warnings.length)),
                for (final w in pv.warnings.take(5)) Text('• $w'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.importConfirm),
          ),
        ],
      ),
    );
    if (ok != true) {
      session.cancel();
      return;
    }
    if (context.mounted) showMessage(context, l10n.importing);
    try {
      final r = await session.commit();
      if (context.mounted) {
        showMessage(
          context,
          r.copiedBecauseIdExisted > 0
              ? '${l10n.importDone(r.notes)} ${l10n.importCopies(r.copiedBecauseIdExisted)}'
              : l10n.importDone(r.notes),
        );
      }
    } catch (e) {
      if (context.mounted) showMessage(context, l10n.importInvalid('$e'));
    }
  }
}
