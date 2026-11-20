import 'dart:convert';

import '../../../l10n/app_localizations.dart';

enum NoteTemplate { blank, meeting, daily, ideas, journal, checklist }

class TemplateContent {
  const TemplateContent(this.title, this.deltaJson);
  final String? title;
  final String deltaJson;
}

String templateName(AppLocalizations l, NoteTemplate t) => switch (t) {
  NoteTemplate.blank => l.templateBlank,
  NoteTemplate.meeting => l.templateMeeting,
  NoteTemplate.daily => l.templateDaily,
  NoteTemplate.ideas => l.templateIdeas,
  NoteTemplate.journal => l.templateJournal,
  NoteTemplate.checklist => l.templateChecklist,
};

/// Builds the starting delta for a template in the user's language.
TemplateContent buildTemplate(AppLocalizations l, NoteTemplate t) {
  final ops = <Map<String, dynamic>>[];
  void heading(String text) {
    ops.add({'insert': text});
    ops.add({
      'insert': '\n',
      'attributes': {'header': 2},
    });
  }

  void para([String text = '']) => ops.add({'insert': '$text\n'});
  void bullet(String text) {
    ops.add({'insert': text});
    ops.add({
      'insert': '\n',
      'attributes': {'list': 'bullet'},
    });
  }

  void check(String text) {
    ops.add({'insert': text});
    ops.add({
      'insert': '\n',
      'attributes': {'list': 'unchecked'},
    });
  }

  switch (t) {
    case NoteTemplate.blank:
      return TemplateContent(
        null,
        jsonEncode([
          {'insert': '\n'},
        ]),
      );
    case NoteTemplate.meeting:
      heading(l.tplAttendees);
      bullet('');
      heading(l.tplAgenda);
      bullet('');
      heading(l.tplNotes);
      para();
      heading(l.tplActionItems);
      check('');
    case NoteTemplate.daily:
      heading(l.tplPriorities);
      check('');
      heading(l.tplNotes);
      para();
      heading(l.tplHighlights);
      para();
    case NoteTemplate.ideas:
      heading(l.tplIdea);
      para();
      heading(l.tplWhyItMatters);
      para();
      heading(l.tplNextSteps);
      check('');
    case NoteTemplate.journal:
      heading(l.tplHowIFeel);
      para();
      heading(l.tplGratefulFor);
      bullet('');
      heading(l.tplOnMyMind);
      para();
    case NoteTemplate.checklist:
      check('');
  }
  return TemplateContent(templateName(l, t), jsonEncode(ops));
}
