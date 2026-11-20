import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Short, locale-aware date: time for today, otherwise a medium date.
String formatNoteDate(BuildContext context, DateTime date, {DateTime? now}) {
  final locale = Localizations.localeOf(context).toString();
  final n = now ?? DateTime.now();
  final local = date.toLocal();
  final sameDay =
      local.year == n.year && local.month == n.month && local.day == n.day;
  return sameDay
      ? DateFormat.jm(locale).format(local)
      : DateFormat.yMMMd(locale).format(local);
}
