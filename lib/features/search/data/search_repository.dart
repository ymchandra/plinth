import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';

enum ArchiveFilter { hide, include, only }

class SearchFilters {
  const SearchFilters({
    this.folderId,
    this.tagId,
    this.pinnedOnly = false,
    this.archive = ArchiveFilter.hide,
  });

  final String? folderId;
  final String? tagId;
  final bool pinnedOnly;
  final ArchiveFilter archive;

  bool get isEmpty =>
      folderId == null &&
      tagId == null &&
      !pinnedOnly &&
      archive == ArchiveFilter.hide;

  SearchFilters copyWith({
    Object? folderId = _keep,
    Object? tagId = _keep,
    bool? pinnedOnly,
    ArchiveFilter? archive,
  }) => SearchFilters(
    folderId: identical(folderId, _keep) ? this.folderId : folderId as String?,
    tagId: identical(tagId, _keep) ? this.tagId : tagId as String?,
    pinnedOnly: pinnedOnly ?? this.pinnedOnly,
    archive: archive ?? this.archive,
  );

  static const _keep = Object();

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.folderId == folderId &&
      other.tagId == tagId &&
      other.pinnedOnly == pinnedOnly &&
      other.archive == archive;

  @override
  int get hashCode => Object.hash(folderId, tagId, pinnedOnly, archive);
}

class SearchHit {
  const SearchHit({
    required this.noteId,
    required this.title,
    required this.snippet,
    required this.folderName,
    required this.isPinned,
    required this.isArchived,
    required this.updatedAt,
  });

  final String noteId;

  /// Title with [highlightStart]/[highlightEnd] markers around matches.
  final String title;
  final String snippet;
  final String? folderName;
  final bool isPinned;
  final bool isArchived;
  final DateTime updatedAt;
}

const highlightStart = '\u0001';
const highlightEnd = '\u0002';

class HighlightSpan {
  const HighlightSpan(this.text, this.isMatch);
  final String text;
  final bool isMatch;
}

List<HighlightSpan> parseHighlights(String marked) {
  final spans = <HighlightSpan>[];
  final buffer = StringBuffer();
  var inMatch = false;
  void flush() {
    if (buffer.isNotEmpty) {
      spans.add(HighlightSpan(buffer.toString(), inMatch));
      buffer.clear();
    }
  }

  for (final rune in marked.runes) {
    final c = String.fromCharCode(rune);
    if (c == highlightStart) {
      flush();
      inMatch = true;
    } else if (c == highlightEnd) {
      flush();
      inMatch = false;
    } else {
      buffer.write(c);
    }
  }
  flush();
  return spans;
}

/// Converts free text to a safe FTS5 prefix query: every word must match.
String buildFtsQuery(String input) {
  final tokens = RegExp(
    r'[\p{L}\p{N}]+',
    unicode: true,
  ).allMatches(input).map((m) => m.group(0)!).toList();
  return tokens.map((t) => '"$t"*').join(' ');
}

class SearchRepository {
  SearchRepository(this._db, {DateTime Function()? now, Uuid? uuid})
    : _now = now ?? DateTime.now,
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DateTime Function() _now;
  final Uuid _uuid;

  static const maxRecent = 10;

  Future<List<SearchHit>> search(
    String query, {
    SearchFilters filters = const SearchFilters(),
    int limit = 30,
    int offset = 0,
  }) async {
    final match = buildFtsQuery(query);
    if (match.isEmpty) return const [];
    final vars = <Variable>[
      Variable<String>(highlightStart),
      Variable<String>(highlightEnd),
      Variable<String>(highlightStart),
      Variable<String>(highlightEnd),
    ];
    final where = StringBuffer('notes_fts MATCH ? AND n.deleted_at IS NULL');
    var cte = '';
    final whereVars = <Variable>[Variable<String>(match)];
    switch (filters.archive) {
      case ArchiveFilter.hide:
        where.write(' AND n.is_archived = 0');
      case ArchiveFilter.only:
        where.write(' AND n.is_archived = 1');
      case ArchiveFilter.include:
        break;
    }
    if (filters.pinnedOnly) where.write(' AND n.is_pinned = 1');
    final cteVars = <Variable>[];
    if (filters.folderId != null) {
      cte =
          'WITH RECURSIVE sub(id) AS (SELECT ? UNION ALL '
          'SELECT f.id FROM folders f JOIN sub ON f.parent_folder_id = sub.id) ';
      cteVars.add(Variable<String>(filters.folderId!));
      where.write(' AND n.folder_id IN (SELECT id FROM sub)');
    }
    if (filters.tagId != null) {
      where.write(
        ' AND n.id IN (SELECT note_id FROM note_tags WHERE tag_id = ?)',
      );
      whereVars.add(Variable<String>(filters.tagId!));
    }
    final sql =
        '${cte}SELECT n.id AS id, n.title AS title, n.derived_title AS derived, '
        'f.name AS folder_name, n.is_pinned AS pinned, n.is_archived AS archived, '
        'n.updated_at AS updated, '
        'highlight(notes_fts, 1, ?, ?) AS t_hl, '
        'snippet(notes_fts, 2, ?, ?, \'…\', 14) AS snip '
        'FROM notes_fts JOIN notes n ON n.id = notes_fts.note_id '
        'LEFT JOIN folders f ON f.id = n.folder_id '
        'WHERE $where ORDER BY rank, n.updated_at DESC LIMIT ? OFFSET ?';
    final rows = await _db
        .customSelect(
          sql,
          variables: [
            ...cteVars,
            ...vars,
            ...whereVars,
            Variable<int>(limit),
            Variable<int>(offset),
          ],
          readsFrom: {_db.notes, _db.folders, _db.noteTags},
        )
        .get();
    return rows.map((r) {
      final title = r.read<String?>('title');
      final hl = r.read<String?>('t_hl') ?? '';
      return SearchHit(
        noteId: r.read<String>('id'),
        title: (title == null || title.isEmpty)
            ? (r.read<String?>('derived') ?? '')
            : hl,
        snippet: r.read<String?>('snip') ?? '',
        folderName: r.read<String?>('folder_name'),
        isPinned: r.read<bool>('pinned'),
        isArchived: r.read<bool>('archived'),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          r.read<int>('updated') * 1000,
        ),
      );
    }).toList();
  }

  Stream<List<String>> watchRecent() =>
      (_db.select(_db.recentSearches)
            ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
            ..limit(maxRecent))
          .watch()
          .map((rows) => rows.map((r) => r.query).toList());

  Future<void> addRecent(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    await _db.transaction(() async {
      await (_db.delete(
        _db.recentSearches,
      )..where((r) => r.query.equals(q))).go();
      await _db
          .into(_db.recentSearches)
          .insert(
            RecentSearchesCompanion.insert(
              id: _uuid.v4(),
              query: q,
              createdAt: _now(),
            ),
          );
      await _db.customStatement(
        'DELETE FROM recent_searches WHERE id NOT IN '
        '(SELECT id FROM recent_searches ORDER BY created_at DESC, rowid DESC LIMIT $maxRecent)',
      );
    });
  }

  Future<void> clearRecent() => _db.delete(_db.recentSearches).go();
}
