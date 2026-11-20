// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Plinth';

  @override
  String get tagline =>
      'Your personal space for notes, ideas and everyday information.';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navFolders => 'Folders';

  @override
  String get navSettings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get rename => 'Rename';

  @override
  String get delete => 'Delete';

  @override
  String get done => 'Done';

  @override
  String get ok => 'OK';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get more => 'More actions';

  @override
  String get back => 'Back';

  @override
  String get untitled => 'Untitled';

  @override
  String get noAdditionalText => 'No additional text';

  @override
  String get newNote => 'New note';

  @override
  String get newFromTemplate => 'New from template';

  @override
  String get chooseTemplate => 'Start from a template';

  @override
  String get homeSearchHint => 'Search notes';

  @override
  String get homePinned => 'Pinned';

  @override
  String get homeRecent => 'Recent';

  @override
  String get homeFolders => 'Folders';

  @override
  String get emptyHomeTitle => 'Write your first note';

  @override
  String get emptyHomeBody =>
      'Tap New note and start typing. Plinth saves as you go, and everything stays on this device.';

  @override
  String get loadMore => 'Show more';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get pinned => 'Pinned';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get moveToFolder => 'Move to folder';

  @override
  String get noFolder => 'No folder';

  @override
  String get restore => 'Restore';

  @override
  String get deleteForever => 'Delete permanently';

  @override
  String get manageTags => 'Tags';

  @override
  String get exportMarkdown => 'Export as Markdown';

  @override
  String get moveToTrash => 'Move to trash';

  @override
  String get confirmTrashTitle => 'Move to trash?';

  @override
  String get confirmTrashBody =>
      'You can restore this note from Trash until it is permanently removed.';

  @override
  String get confirmDeleteForeverTitle => 'Delete permanently?';

  @override
  String get confirmDeleteForeverBody =>
      'This note and its attachments will be deleted for good. This can\'t be undone.';

  @override
  String get emptyTrash => 'Empty trash';

  @override
  String get confirmEmptyTrashTitle => 'Empty trash?';

  @override
  String get confirmEmptyTrashBody =>
      'All notes in Trash will be deleted for good. This can\'t be undone.';

  @override
  String get noteMovedToTrash => 'Moved to trash';

  @override
  String get noteRestored => 'Note restored';

  @override
  String get noteArchived => 'Archived';

  @override
  String get noteUnarchived => 'Moved out of archive';

  @override
  String get noteDuplicated => 'Note duplicated';

  @override
  String get undo => 'Undo';

  @override
  String get copySuffix => ' (copy)';

  @override
  String get redo => 'Redo';

  @override
  String editedAt(String date) {
    return 'Edited $date';
  }

  @override
  String get titleHint => 'Title';

  @override
  String get bodyHint => 'Start writing…';

  @override
  String get saving => 'Saving…';

  @override
  String get saved => 'Saved';

  @override
  String get unsavedChanges => 'Unsaved';

  @override
  String get saveFailed =>
      'Couldn\'t save. Your text is kept and will be retried.';

  @override
  String get bold => 'Bold';

  @override
  String get italic => 'Italic';

  @override
  String get underline => 'Underline';

  @override
  String get heading1 => 'Heading 1';

  @override
  String get heading2 => 'Heading 2';

  @override
  String get heading3 => 'Heading 3';

  @override
  String get bulletList => 'Bulleted list';

  @override
  String get numberedList => 'Numbered list';

  @override
  String get checklist => 'Checklist';

  @override
  String get quote => 'Quote';

  @override
  String get link => 'Link';

  @override
  String get removeLink => 'Remove link';

  @override
  String get linkDialogTitle => 'Add link';

  @override
  String get linkUrlHint => 'https://example.com';

  @override
  String get dismissKeyboard => 'Hide keyboard';

  @override
  String get attachments => 'Attachments';

  @override
  String get addPhoto => 'Photo from library';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get removeAttachment => 'Remove image';

  @override
  String get confirmRemoveAttachmentTitle => 'Remove this image?';

  @override
  String get confirmRemoveAttachmentBody =>
      'The image will be deleted from this note.';

  @override
  String get attachmentMissing => 'Image file is missing';

  @override
  String get attachmentFailed => 'Couldn\'t add the image.';

  @override
  String noteImagePreview(String name) {
    return 'Attached image $name';
  }

  @override
  String get foldersTitle => 'Folders';

  @override
  String get library => 'Library';

  @override
  String get allNotes => 'All notes';

  @override
  String get archiveTitle => 'Archive';

  @override
  String get trashTitle => 'Trash';

  @override
  String trashRetentionHint(int days) {
    return 'Notes in Trash are removed automatically after $days days.';
  }

  @override
  String get trashKeptHint => 'Notes in Trash stay until you delete them.';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get newFolder => 'New folder';

  @override
  String get newSubfolder => 'New subfolder';

  @override
  String get renameFolder => 'Rename folder';

  @override
  String get folderNameHint => 'Folder name';

  @override
  String get deleteFolder => 'Delete folder';

  @override
  String get moveFolder => 'Move folder';

  @override
  String get topLevel => 'Top level';

  @override
  String deleteFolderTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteFolderBody =>
      'The notes inside won\'t be deleted. Where should they go?';

  @override
  String get moveNotesToParent => 'Move notes to the parent folder';

  @override
  String get leaveNotesUnorganised => 'Leave notes unorganised';

  @override
  String get noFolders => 'No folders yet. Create one to group related notes.';

  @override
  String get noTags => 'No tags yet. Tags let you label notes across folders.';

  @override
  String get newTag => 'New tag';

  @override
  String get renameTag => 'Rename tag';

  @override
  String get tagNameHint => 'Tag name';

  @override
  String get deleteTag => 'Delete tag';

  @override
  String confirmDeleteTagTitle(String name) {
    return 'Delete tag “$name”?';
  }

  @override
  String get confirmDeleteTagBody =>
      'It will be removed from all notes. The notes themselves stay.';

  @override
  String get tagNameExists => 'A tag with that name already exists.';

  @override
  String get nameRequired => 'Please enter a name.';

  @override
  String get circularFolder =>
      'A folder can\'t be moved into itself or its subfolders.';

  @override
  String get emptyFolderTitle => 'Nothing here yet';

  @override
  String get emptyFolderBody =>
      'Notes you move to this folder will show up here.';

  @override
  String get emptyListTitle => 'No notes';

  @override
  String get emptyArchiveBody =>
      'Archived notes are kept here, out of the way.';

  @override
  String get emptyTrashBody => 'Trash is empty.';

  @override
  String notesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
      zero: 'No notes',
    );
    return '$_temp0';
  }

  @override
  String get searchHint => 'Search titles and content';

  @override
  String get searchPrompt => 'Search all your notes';

  @override
  String get searchPromptBody =>
      'Type to find notes by title or content. Search works offline.';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get clearRecent => 'Clear';

  @override
  String get noResultsTitle => 'No matching notes';

  @override
  String get noResultsBody => 'Try different words or remove a filter.';

  @override
  String get filterPinned => 'Pinned';

  @override
  String get filterArchived => 'Include archived';

  @override
  String get filterFolder => 'Folder';

  @override
  String get filterTag => 'Tag';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get searchFilters => 'Filters';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get general => 'General';

  @override
  String get landingScreen => 'Open on';

  @override
  String get sortOrder => 'Sort notes by';

  @override
  String get sortUpdated => 'Last edited';

  @override
  String get sortCreated => 'Date created';

  @override
  String get sortTitle => 'Title';

  @override
  String get editorFontSize => 'Editor text size';

  @override
  String get sizeSmall => 'Small';

  @override
  String get sizeMedium => 'Medium';

  @override
  String get sizeLarge => 'Large';

  @override
  String get trashRetention => 'Keep deleted notes for';

  @override
  String retentionDays(int days) {
    return '$days days';
  }

  @override
  String get retentionForever => 'Until I delete them';

  @override
  String get dataSection => 'Your data';

  @override
  String get exportAll => 'Export all data';

  @override
  String get exportAllSub =>
      'Notes, folders, tags and images in one ZIP archive.';

  @override
  String get importArchive => 'Import from archive';

  @override
  String get importArchiveSub =>
      'Restore a Plinth export. Existing notes are never overwritten.';

  @override
  String get privacySection => 'Privacy';

  @override
  String get privacyTitle => 'Private by design';

  @override
  String get privacyBody =>
      'Plinth has no account, server, analytics or ads, and never connects to the internet. Everything is stored in the app\'s private storage on this device. The database is not encrypted by Plinth; it relies on your device\'s lock and storage protection.';

  @override
  String get exporting => 'Preparing export…';

  @override
  String exportReady(int notes, int attachments) {
    return 'Export ready: $notes notes, $attachments images.';
  }

  @override
  String exportMissingFiles(int count) {
    return '$count image files were missing and were left out.';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get importReviewTitle => 'Import this archive?';

  @override
  String importSummary(int notes, int folders, int tags, int attachments) {
    return '$notes notes, $folders folders, $tags tags and $attachments images will be added. Nothing existing is overwritten.';
  }

  @override
  String get importConfirm => 'Import';

  @override
  String get importing => 'Importing…';

  @override
  String importDone(int count) {
    return 'Imported $count notes.';
  }

  @override
  String importCopies(int count) {
    return '$count notes already existed and were added as copies.';
  }

  @override
  String importInvalid(String reason) {
    return 'Can\'t import: $reason';
  }

  @override
  String importWarnings(int count) {
    return '$count warnings';
  }

  @override
  String get exportNoteFailed => 'Couldn\'t export this note.';

  @override
  String get templateBlank => 'Blank note';

  @override
  String get templateMeeting => 'Meeting notes';

  @override
  String get templateDaily => 'Daily notes';

  @override
  String get templateIdeas => 'Ideas';

  @override
  String get templateJournal => 'Journal entry';

  @override
  String get templateChecklist => 'Checklist';

  @override
  String get tplAttendees => 'Attendees';

  @override
  String get tplAgenda => 'Agenda';

  @override
  String get tplNotes => 'Notes';

  @override
  String get tplActionItems => 'Action items';

  @override
  String get tplPriorities => 'Priorities';

  @override
  String get tplTasks => 'Tasks';

  @override
  String get tplHighlights => 'Highlights';

  @override
  String get tplIdea => 'Idea';

  @override
  String get tplWhyItMatters => 'Why it matters';

  @override
  String get tplNextSteps => 'Next steps';

  @override
  String get tplHowIFeel => 'How I\'m feeling';

  @override
  String get tplGratefulFor => 'Grateful for';

  @override
  String get tplOnMyMind => 'On my mind';

  @override
  String get tplItem => 'Item';

  @override
  String get startupErrorTitle => 'Plinth couldn\'t open your data';

  @override
  String startupErrorBody(String error) {
    return 'Your notes have not been changed. Details: $error';
  }

  @override
  String get genericError => 'Something went wrong.';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';
}
