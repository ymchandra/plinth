import 'dart:convert';

/// Helpers for working with Quill delta JSON without depending on the editor.
class DeltaText {
  DeltaText._();

  static List<Map<String, dynamic>> parseOps(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Delta must be a JSON array');
    }
    final ops = <Map<String, dynamic>>[];
    for (final op in decoded) {
      if (op is! Map || !op.containsKey('insert')) {
        throw const FormatException('Invalid delta operation');
      }
      ops.add(Map<String, dynamic>.from(op));
    }
    return ops;
  }

  static bool isValid(String json) {
    try {
      parseOps(json);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Plain text of the document. Embeds are dropped.
  static String plainText(String json) {
    final buffer = StringBuffer();
    for (final op in parseOps(json)) {
      final insert = op['insert'];
      if (insert is String) buffer.write(insert);
    }
    return buffer.toString();
  }

  /// First non-empty line, shortened for display.
  static String derivedTitle(String plain, {int maxLength = 80}) {
    for (final line in plain.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) {
        return t.length > maxLength ? t.substring(0, maxLength).trimRight() : t;
      }
    }
    return '';
  }

  /// Whitespace-collapsed preview. When [skipFirstLine] the first non-empty
  /// line (used as derived title) is omitted.
  static String preview(
    String plain, {
    bool skipFirstLine = false,
    int maxLength = 200,
  }) {
    final lines = plain.split('\n');
    var started = !skipFirstLine;
    final parts = <String>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (!started) {
        started = true;
        continue;
      }
      parts.add(t);
      if (parts.join(' ').length >= maxLength) break;
    }
    final joined = parts.join(' ');
    return joined.length > maxLength ? joined.substring(0, maxLength) : joined;
  }

  static String fromPlainText(String text) {
    final normalized = text.endsWith('\n') ? text : '$text\n';
    return jsonEncode([
      {'insert': normalized},
    ]);
  }
}
