# Plinth

A local-first notes app for iOS and Android, built with Flutter. Everything lives on the device: **no account, no server, no analytics, no AI, no network access.**

## Features

- Rich-text notes (headings, bold/italic/underline, lists, checklists, quotes, links) with debounced **autosave** (800 ms, flush on leave/background, retry on failure) and a visible save status.
- Pin, archive, duplicate, trash (restorable, configurable auto-purge) and permanent delete with confirmation.
- Nested **folders** (cycle-safe moves, choose what happens to notes on delete) and **tags** (case-insensitive unique).
- **Full-text search** (SQLite FTS5) over titles and bodies with highlighted snippets, recent searches and filters (folder, tag, pinned, archived).
- Image **attachments** from gallery or camera, stored in private app storage.
- Six **templates** (blank, meeting, daily, ideas, journal, checklist).
- **Export** everything as a ZIP (Markdown + JSON manifest + images) and **import** it back with a preview; imports never overwrite existing notes.
- Light / dark / system themes, editor text size, sort order, landing screen, trash retention.
- Accessibility: semantic labels, 48 dp touch targets, tooltips on icon buttons, text scaling, live-region save status.
- All strings via Flutter l10n (`lib/l10n/app_en.arb`).

## Architecture

Feature-first layers; the UI never touches SQLite directly.

```
lib/
  app/            app widget, GoRouter shell, Riverpod providers, theme + tokens
  core/           database (Drift), storage, errors, shared widgets
  features/
    notes/ folders/ tags/ search/ attachments/ settings/ backup/ editor/ home/
      data/         repositories (the only code that uses the database)
      domain/       models + pure logic (delta text, Markdown export, autosave)
      presentation/ screens and widgets
```

- **State:** Riverpod. Repositories are plain classes provided via providers; lists use Drift `watch()` streams so UI updates automatically.
- **Navigation:** GoRouter `StatefulShellRoute` (4 tabs; bottom bar on phones, rail ≥ 600 dp). Editor and detail screens are full-screen routes.
- **Storage:** Drift on SQLite. Note bodies are stored as Quill delta JSON; `title`, derived title and preview are denormalised for fast lists. The FTS5 table `notes_fts` is maintained by `NoteRepository` **inside the same transaction** as each write (plain text cannot be derived in SQL).
- **Editor:** `flutter_quill`. New notes are persisted immediately; an untouched empty note is discarded on leave.
- **Attachments:** files are copied into app support storage and referenced by *relative* path, so they survive app-container path changes.

### Dependency notes

- `drift` is pinned to `>=2.32 <2.33` because newer versions conflict with the `meta` version pinned by the Flutter SDK in use (3.41).
- `sqlite3` v3 bundles SQLite via build hooks, so `sqlite3_flutter_libs` is not used.
- Packages used: flutter_riverpod, go_router, drift, sqlite3, path_provider, path, uuid, archive, image_picker, flutter_quill, flutter_localizations/intl, share_plus, file_picker (url_launcher is declared for link handling).

## Export format

`plinth-export-<timestamp>.zip`:

```
manifest.json            format "plinth-export", version 1, folders, tags, notes, attachments
notes/<slug>-<id8>.md    one Markdown file per note
attachments/<noteId>/<attachmentId>.<ext>
README.txt
```

Import validates the manifest (version, dangling references, duplicate ids, folder cycles, unsafe attachment paths), shows a preview, and only writes on confirm, in a single transaction. Notes whose id already exists are added as copies; existing folders are reused; tags match by name.

## Privacy and permissions

- No `INTERNET` permission is declared by the app (Android debug builds add it only for tooling).
- iOS: photo-library and camera usage strings are set; the camera is used only when you choose "Take a photo".
- Android: `allowBackup="false"`; no storage permissions are needed (system pickers).
- **Encryption:** the database is **not encrypted** by Plinth. It relies on OS sandboxing and device lock/storage encryption. SQLCipher was evaluated and deferred: it adds native build complexity and key-management/loss-of-data risks that need a product decision. Exports are plain ZIPs; share them carefully.

## Running

```sh
flutter pub get
dart run build_runner build   # regenerates lib/core/database/database.g.dart
flutter gen-l10n
flutter analyze
flutter test                  # unit + widget tests
flutter test integration_test # needs a simulator/device
flutter run
```

## Known limitations

- Only schema v1 exists, so there are **no real migration steps yet**. The infrastructure is in place and tested: a file backup is made before opening an older DB, and a database from a *newer* app version is refused with a clear startup error.
- Cursor position is not restored when reopening a note.
- FTS uses the `unicode61` tokenizer: CJK text is not word-segmented, so only whole-run prefix matches work.
- Inline images are not embedded in the editor body; images are shown in an attachment strip above it and exported with the note.
- Single English locale; RTL layout uses directional widgets but is untested.
- Android is not built or verified in this environment (no Android SDK).

## Verification status

Executed in this environment (macOS, Flutter 3.41.9):

- `flutter analyze`: no issues.
- `flutter test`: 71 unit/widget tests passing (repositories, FTS search, backup export/import validation, Markdown export, autosave, screens).
- `flutter build ios --no-codesign --debug`: succeeds (iOS 15.0 minimum).

Not executed: `integration_test/app_flow_test.dart` (written; needs a simulator/device), any Android build (no Android SDK), release builds, and manual accessibility testing with VoiceOver/TalkBack.
