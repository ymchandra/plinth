import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Plinth'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your personal space for notes, ideas and everyday information.'**
  String get tagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get navFolders;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get more;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @noAdditionalText.
  ///
  /// In en, this message translates to:
  /// **'No additional text'**
  String get noAdditionalText;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @newFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'New from template'**
  String get newFromTemplate;

  /// No description provided for @chooseTemplate.
  ///
  /// In en, this message translates to:
  /// **'Start from a template'**
  String get chooseTemplate;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get homeSearchHint;

  /// No description provided for @homePinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get homePinned;

  /// No description provided for @homeRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get homeRecent;

  /// No description provided for @homeFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get homeFolders;

  /// No description provided for @emptyHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Write your first note'**
  String get emptyHomeTitle;

  /// No description provided for @emptyHomeBody.
  ///
  /// In en, this message translates to:
  /// **'Tap New note and start typing. Plinth saves as you go, and everything stays on this device.'**
  String get emptyHomeBody;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get loadMore;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @moveToFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get moveToFolder;

  /// No description provided for @noFolder.
  ///
  /// In en, this message translates to:
  /// **'No folder'**
  String get noFolder;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deleteForever;

  /// No description provided for @manageTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get manageTags;

  /// No description provided for @exportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export as Markdown'**
  String get exportMarkdown;

  /// No description provided for @moveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get moveToTrash;

  /// No description provided for @confirmTrashTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to trash?'**
  String get confirmTrashTitle;

  /// No description provided for @confirmTrashBody.
  ///
  /// In en, this message translates to:
  /// **'You can restore this note from Trash until it is permanently removed.'**
  String get confirmTrashBody;

  /// No description provided for @confirmDeleteForeverTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently?'**
  String get confirmDeleteForeverTitle;

  /// No description provided for @confirmDeleteForeverBody.
  ///
  /// In en, this message translates to:
  /// **'This note and its attachments will be deleted for good. This can\'t be undone.'**
  String get confirmDeleteForeverBody;

  /// No description provided for @emptyTrash.
  ///
  /// In en, this message translates to:
  /// **'Empty trash'**
  String get emptyTrash;

  /// No description provided for @confirmEmptyTrashTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty trash?'**
  String get confirmEmptyTrashTitle;

  /// No description provided for @confirmEmptyTrashBody.
  ///
  /// In en, this message translates to:
  /// **'All notes in Trash will be deleted for good. This can\'t be undone.'**
  String get confirmEmptyTrashBody;

  /// No description provided for @noteMovedToTrash.
  ///
  /// In en, this message translates to:
  /// **'Moved to trash'**
  String get noteMovedToTrash;

  /// No description provided for @noteRestored.
  ///
  /// In en, this message translates to:
  /// **'Note restored'**
  String get noteRestored;

  /// No description provided for @noteArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get noteArchived;

  /// No description provided for @noteUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Moved out of archive'**
  String get noteUnarchived;

  /// No description provided for @noteDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Note duplicated'**
  String get noteDuplicated;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @copySuffix.
  ///
  /// In en, this message translates to:
  /// **' (copy)'**
  String get copySuffix;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @editedAt.
  ///
  /// In en, this message translates to:
  /// **'Edited {date}'**
  String editedAt(String date);

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleHint;

  /// No description provided for @bodyHint.
  ///
  /// In en, this message translates to:
  /// **'Start writing…'**
  String get bodyHint;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get unsavedChanges;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Your text is kept and will be retried.'**
  String get saveFailed;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @italic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get italic;

  /// No description provided for @underline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get underline;

  /// No description provided for @heading1.
  ///
  /// In en, this message translates to:
  /// **'Heading 1'**
  String get heading1;

  /// No description provided for @heading2.
  ///
  /// In en, this message translates to:
  /// **'Heading 2'**
  String get heading2;

  /// No description provided for @heading3.
  ///
  /// In en, this message translates to:
  /// **'Heading 3'**
  String get heading3;

  /// No description provided for @bulletList.
  ///
  /// In en, this message translates to:
  /// **'Bulleted list'**
  String get bulletList;

  /// No description provided for @numberedList.
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get numberedList;

  /// No description provided for @checklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get checklist;

  /// No description provided for @quote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get quote;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @removeLink.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get removeLink;

  /// No description provided for @linkDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get linkDialogTitle;

  /// No description provided for @linkUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com'**
  String get linkUrlHint;

  /// No description provided for @dismissKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Hide keyboard'**
  String get dismissKeyboard;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo from library'**
  String get addPhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @removeAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get removeAttachment;

  /// No description provided for @confirmRemoveAttachmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this image?'**
  String get confirmRemoveAttachmentTitle;

  /// No description provided for @confirmRemoveAttachmentBody.
  ///
  /// In en, this message translates to:
  /// **'The image will be deleted from this note.'**
  String get confirmRemoveAttachmentBody;

  /// No description provided for @attachmentMissing.
  ///
  /// In en, this message translates to:
  /// **'Image file is missing'**
  String get attachmentMissing;

  /// No description provided for @attachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the image.'**
  String get attachmentFailed;

  /// No description provided for @noteImagePreview.
  ///
  /// In en, this message translates to:
  /// **'Attached image {name}'**
  String noteImagePreview(String name);

  /// No description provided for @foldersTitle.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get foldersTitle;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @allNotes.
  ///
  /// In en, this message translates to:
  /// **'All notes'**
  String get allNotes;

  /// No description provided for @archiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveTitle;

  /// No description provided for @trashTitle.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trashTitle;

  /// No description provided for @trashRetentionHint.
  ///
  /// In en, this message translates to:
  /// **'Notes in Trash are removed automatically after {days} days.'**
  String trashRetentionHint(int days);

  /// No description provided for @trashKeptHint.
  ///
  /// In en, this message translates to:
  /// **'Notes in Trash stay until you delete them.'**
  String get trashKeptHint;

  /// No description provided for @tagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTitle;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @newSubfolder.
  ///
  /// In en, this message translates to:
  /// **'New subfolder'**
  String get newSubfolder;

  /// No description provided for @renameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get renameFolder;

  /// No description provided for @folderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderNameHint;

  /// No description provided for @deleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get deleteFolder;

  /// No description provided for @moveFolder.
  ///
  /// In en, this message translates to:
  /// **'Move folder'**
  String get moveFolder;

  /// No description provided for @topLevel.
  ///
  /// In en, this message translates to:
  /// **'Top level'**
  String get topLevel;

  /// No description provided for @deleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteFolderTitle(String name);

  /// No description provided for @deleteFolderBody.
  ///
  /// In en, this message translates to:
  /// **'The notes inside won\'t be deleted. Where should they go?'**
  String get deleteFolderBody;

  /// No description provided for @moveNotesToParent.
  ///
  /// In en, this message translates to:
  /// **'Move notes to the parent folder'**
  String get moveNotesToParent;

  /// No description provided for @leaveNotesUnorganised.
  ///
  /// In en, this message translates to:
  /// **'Leave notes unorganised'**
  String get leaveNotesUnorganised;

  /// No description provided for @noFolders.
  ///
  /// In en, this message translates to:
  /// **'No folders yet. Create one to group related notes.'**
  String get noFolders;

  /// No description provided for @noTags.
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Tags let you label notes across folders.'**
  String get noTags;

  /// No description provided for @newTag.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get newTag;

  /// No description provided for @renameTag.
  ///
  /// In en, this message translates to:
  /// **'Rename tag'**
  String get renameTag;

  /// No description provided for @tagNameHint.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagNameHint;

  /// No description provided for @deleteTag.
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get deleteTag;

  /// No description provided for @confirmDeleteTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete tag “{name}”?'**
  String confirmDeleteTagTitle(String name);

  /// No description provided for @confirmDeleteTagBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from all notes. The notes themselves stay.'**
  String get confirmDeleteTagBody;

  /// No description provided for @tagNameExists.
  ///
  /// In en, this message translates to:
  /// **'A tag with that name already exists.'**
  String get tagNameExists;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name.'**
  String get nameRequired;

  /// No description provided for @circularFolder.
  ///
  /// In en, this message translates to:
  /// **'A folder can\'t be moved into itself or its subfolders.'**
  String get circularFolder;

  /// No description provided for @emptyFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyFolderTitle;

  /// No description provided for @emptyFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Notes you move to this folder will show up here.'**
  String get emptyFolderBody;

  /// No description provided for @emptyListTitle.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get emptyListTitle;

  /// No description provided for @emptyArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'Archived notes are kept here, out of the way.'**
  String get emptyArchiveBody;

  /// No description provided for @emptyTrashBody.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty.'**
  String get emptyTrashBody;

  /// No description provided for @notesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No notes} =1{1 note} other{{count} notes}}'**
  String notesCount(int count);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles and content'**
  String get searchHint;

  /// No description provided for @searchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search all your notes'**
  String get searchPrompt;

  /// No description provided for @searchPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Type to find notes by title or content. Search works offline.'**
  String get searchPromptBody;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @clearRecent.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearRecent;

  /// No description provided for @noResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching notes'**
  String get noResultsTitle;

  /// No description provided for @noResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try different words or remove a filter.'**
  String get noResultsBody;

  /// No description provided for @filterPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get filterPinned;

  /// No description provided for @filterArchived.
  ///
  /// In en, this message translates to:
  /// **'Include archived'**
  String get filterArchived;

  /// No description provided for @filterFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get filterFolder;

  /// No description provided for @filterTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get filterTag;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @searchFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get searchFilters;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @landingScreen.
  ///
  /// In en, this message translates to:
  /// **'Open on'**
  String get landingScreen;

  /// No description provided for @sortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort notes by'**
  String get sortOrder;

  /// No description provided for @sortUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last edited'**
  String get sortUpdated;

  /// No description provided for @sortCreated.
  ///
  /// In en, this message translates to:
  /// **'Date created'**
  String get sortCreated;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortTitle;

  /// No description provided for @editorFontSize.
  ///
  /// In en, this message translates to:
  /// **'Editor text size'**
  String get editorFontSize;

  /// No description provided for @sizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get sizeSmall;

  /// No description provided for @sizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get sizeMedium;

  /// No description provided for @sizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get sizeLarge;

  /// No description provided for @trashRetention.
  ///
  /// In en, this message translates to:
  /// **'Keep deleted notes for'**
  String get trashRetention;

  /// No description provided for @retentionDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String retentionDays(int days);

  /// No description provided for @retentionForever.
  ///
  /// In en, this message translates to:
  /// **'Until I delete them'**
  String get retentionForever;

  /// No description provided for @dataSection.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get dataSection;

  /// No description provided for @exportAll.
  ///
  /// In en, this message translates to:
  /// **'Export all data'**
  String get exportAll;

  /// No description provided for @exportAllSub.
  ///
  /// In en, this message translates to:
  /// **'Notes, folders, tags and images in one ZIP archive.'**
  String get exportAllSub;

  /// No description provided for @importArchive.
  ///
  /// In en, this message translates to:
  /// **'Import from archive'**
  String get importArchive;

  /// No description provided for @importArchiveSub.
  ///
  /// In en, this message translates to:
  /// **'Restore a Plinth export. Existing notes are never overwritten.'**
  String get importArchiveSub;

  /// No description provided for @privacySection.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacySection;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Private by design'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Plinth has no account, server, analytics or ads, and never connects to the internet. Everything is stored in the app\'s private storage on this device. The database is not encrypted by Plinth; it relies on your device\'s lock and storage protection.'**
  String get privacyBody;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Preparing export…'**
  String get exporting;

  /// No description provided for @exportReady.
  ///
  /// In en, this message translates to:
  /// **'Export ready: {notes} notes, {attachments} images.'**
  String exportReady(int notes, int attachments);

  /// No description provided for @exportMissingFiles.
  ///
  /// In en, this message translates to:
  /// **'{count} image files were missing and were left out.'**
  String exportMissingFiles(int count);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @importReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Import this archive?'**
  String get importReviewTitle;

  /// No description provided for @importSummary.
  ///
  /// In en, this message translates to:
  /// **'{notes} notes, {folders} folders, {tags} tags and {attachments} images will be added. Nothing existing is overwritten.'**
  String importSummary(int notes, int folders, int tags, int attachments);

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importConfirm;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get importing;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} notes.'**
  String importDone(int count);

  /// No description provided for @importCopies.
  ///
  /// In en, this message translates to:
  /// **'{count} notes already existed and were added as copies.'**
  String importCopies(int count);

  /// No description provided for @importInvalid.
  ///
  /// In en, this message translates to:
  /// **'Can\'t import: {reason}'**
  String importInvalid(String reason);

  /// No description provided for @importWarnings.
  ///
  /// In en, this message translates to:
  /// **'{count} warnings'**
  String importWarnings(int count);

  /// No description provided for @exportNoteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export this note.'**
  String get exportNoteFailed;

  /// No description provided for @templateBlank.
  ///
  /// In en, this message translates to:
  /// **'Blank note'**
  String get templateBlank;

  /// No description provided for @templateMeeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting notes'**
  String get templateMeeting;

  /// No description provided for @templateDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily notes'**
  String get templateDaily;

  /// No description provided for @templateIdeas.
  ///
  /// In en, this message translates to:
  /// **'Ideas'**
  String get templateIdeas;

  /// No description provided for @templateJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal entry'**
  String get templateJournal;

  /// No description provided for @templateChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get templateChecklist;

  /// No description provided for @tplAttendees.
  ///
  /// In en, this message translates to:
  /// **'Attendees'**
  String get tplAttendees;

  /// No description provided for @tplAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get tplAgenda;

  /// No description provided for @tplNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get tplNotes;

  /// No description provided for @tplActionItems.
  ///
  /// In en, this message translates to:
  /// **'Action items'**
  String get tplActionItems;

  /// No description provided for @tplPriorities.
  ///
  /// In en, this message translates to:
  /// **'Priorities'**
  String get tplPriorities;

  /// No description provided for @tplTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tplTasks;

  /// No description provided for @tplHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get tplHighlights;

  /// No description provided for @tplIdea.
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get tplIdea;

  /// No description provided for @tplWhyItMatters.
  ///
  /// In en, this message translates to:
  /// **'Why it matters'**
  String get tplWhyItMatters;

  /// No description provided for @tplNextSteps.
  ///
  /// In en, this message translates to:
  /// **'Next steps'**
  String get tplNextSteps;

  /// No description provided for @tplHowIFeel.
  ///
  /// In en, this message translates to:
  /// **'How I\'m feeling'**
  String get tplHowIFeel;

  /// No description provided for @tplGratefulFor.
  ///
  /// In en, this message translates to:
  /// **'Grateful for'**
  String get tplGratefulFor;

  /// No description provided for @tplOnMyMind.
  ///
  /// In en, this message translates to:
  /// **'On my mind'**
  String get tplOnMyMind;

  /// No description provided for @tplItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get tplItem;

  /// No description provided for @startupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Plinth couldn\'t open your data'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Your notes have not been changed. Details: {error}'**
  String startupErrorBody(String error);

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get genericError;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
