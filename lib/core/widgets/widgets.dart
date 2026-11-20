import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../util/l10n_ext.dart';

/// Centred empty/placeholder state with optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 56, color: t.colorScheme.outline),
              ),
              const SizedBox(height: Space.md),
              Text(
                title,
                style: t.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (body != null) ...[
                const SizedBox(height: Space.sm),
                Text(
                  body!,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: Space.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Constrains content to a readable width on tablets.
class CenteredContent extends StatelessWidget {
  const CenteredContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Sizes.contentMaxWidth),
      child: child,
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Confirmation dialog; returns true when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10n.cancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single-line text prompt; returns trimmed text or null if cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  String initial = '',
  TextInputType? keyboardType,
  String? Function(String)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _PromptDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      initial: initial,
      keyboardType: keyboardType,
      validator: validator,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.initial,
    this.keyboardType,
    this.validator,
  });
  final String title;
  final String hint;
  final String confirmLabel;
  final String initial;
  final TextInputType? keyboardType;
  final String? Function(String)? validator;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _c = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    final err = v.isEmpty
        ? context.l10n.nameRequired
        : widget.validator?.call(v);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _c,
      autofocus: true,
      keyboardType: widget.keyboardType,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(hintText: widget.hint, errorText: _error),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
    ],
  );
}

void showMessage(BuildContext context, String text, {VoidCallback? onUndo}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(text),
      action: onUndo == null
          ? null
          : SnackBarAction(label: context.l10n.undo, onPressed: onUndo),
    ),
  );
}
