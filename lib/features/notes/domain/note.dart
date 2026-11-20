enum NoteScope { active, archived, trashed }

enum SortOrder { updatedDesc, createdDesc, titleAsc }

class NoteQuery {
  const NoteQuery({
    this.scope = NoteScope.active,
    this.folderId,
    this.unfiledOnly = false,
    this.tagId,
    this.pinned,
    this.sort = SortOrder.updatedDesc,
    this.pinnedFirst = false,
  });

  final NoteScope scope;
  final String? folderId;
  final bool unfiledOnly;
  final String? tagId;

  /// null = any, true = pinned only, false = unpinned only.
  final bool? pinned;
  final SortOrder sort;
  final bool pinnedFirst;

  @override
  bool operator ==(Object other) =>
      other is NoteQuery &&
      other.scope == scope &&
      other.folderId == folderId &&
      other.unfiledOnly == unfiledOnly &&
      other.tagId == tagId &&
      other.pinned == pinned &&
      other.sort == sort &&
      other.pinnedFirst == pinnedFirst;

  @override
  int get hashCode => Object.hash(
    scope,
    folderId,
    unfiledOnly,
    tagId,
    pinned,
    sort,
    pinnedFirst,
  );
}

/// Lightweight note representation for lists (no full content).
class NoteSummary {
  const NoteSummary({
    required this.id,
    required this.title,
    required this.derivedTitle,
    required this.preview,
    required this.folderId,
    required this.folderName,
    required this.isPinned,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String? title;
  final String derivedTitle;
  final String preview;
  final String? folderId;
  final String? folderName;
  final bool isPinned;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Title shown in the UI; empty when the note has nothing to show.
  String get displayTitle {
    final t = title?.trim() ?? '';
    return t.isNotEmpty ? t : derivedTitle;
  }
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.folderId,
    required this.isPinned,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String? title;
  final String content;
  final String? folderId;
  final bool isPinned;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isTrashed => deletedAt != null;
}
