import '../../notes/domain/delta_text.dart';

/// Converts a Quill delta (JSON) into Markdown.
///
/// Supports headings, bold, italic, underline (as `<u>`), strike, inline code,
/// links, bullet/ordered/checklists (with indentation), block quotes and code
/// blocks. Embeds (images) are omitted; attachments are exported separately.
class MarkdownExporter {
  MarkdownExporter._();

  static String export(String deltaJson, {String? title}) {
    final lines = _toLines(DeltaText.parseOps(deltaJson));
    final out = StringBuffer();
    final t = title?.trim() ?? '';
    if (t.isNotEmpty) out.write('# $t\n\n');

    var orderedCounters = <int, int>{};
    _Line? prev;
    var inCode = false;
    for (final line in lines) {
      final block = line.blockAttrs;
      final isCode =
          block['code-block'] != null && block['code-block'] != false;
      if (isCode) {
        if (!inCode) {
          if (prev != null) out.write('\n');
          out.write('```\n');
          inCode = true;
        }
        out.write('${line.plain}\n');
        prev = line;
        continue;
      }
      if (inCode) {
        out.write('```\n');
        inCode = false;
      }
      final text = line.inlineMarkdown();
      final list = block['list'];
      final indent = (block['indent'] as int?) ?? 0;
      final isList = list != null;
      if (!isList) orderedCounters = {};

      if (text.trim().isEmpty && !isList) continue;

      final prevWasList = prev != null && prev.blockAttrs['list'] != null;
      final prevWasQuote =
          prev != null && prev.blockAttrs['blockquote'] == true;
      final isQuote = block['blockquote'] == true;
      final sameFamily =
          isList &&
          prevWasList &&
          ((list == 'ordered') == (prev.blockAttrs['list'] == 'ordered')) &&
          ((list == 'unchecked' || list == 'checked') ==
              (prev.blockAttrs['list'] == 'unchecked' ||
                  prev.blockAttrs['list'] == 'checked'));
      final tight = sameFamily || (isQuote && prevWasQuote);
      if (prev != null && !tight) out.write('\n');

      final pad = '    ' * indent;
      String rendered;
      if (isList) {
        if (list == 'ordered') {
          orderedCounters.removeWhere((k, _) => k > indent);
          final n = (orderedCounters[indent] ?? 0) + 1;
          orderedCounters[indent] = n;
          rendered = '$pad$n. $text';
        } else {
          orderedCounters.removeWhere((k, _) => k > indent);
          final marker = list == 'checked'
              ? '- [x] '
              : list == 'unchecked'
              ? '- [ ] '
              : '- ';
          rendered = '$pad$marker$text';
        }
      } else if (block['header'] != null) {
        final level = (block['header'] as int).clamp(1, 6);
        rendered = '${'#' * level} $text';
      } else if (isQuote) {
        rendered = '> $text';
      } else {
        rendered = '$pad$text';
      }
      out.write('$rendered\n');
      prev = line;
    }
    if (inCode) out.write('```\n');
    return '${out.toString().trimRight()}\n';
  }

  static List<_Line> _toLines(List<Map<String, dynamic>> ops) {
    final lines = <_Line>[];
    var current = <_Segment>[];
    for (final op in ops) {
      final insert = op['insert'];
      final attrs = Map<String, dynamic>.from(
        (op['attributes'] as Map?) ?? const {},
      );
      if (insert is! String) continue;
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) current.add(_Segment(parts[i], attrs));
        if (i < parts.length - 1) {
          lines.add(_Line(current, attrs));
          current = [];
        }
      }
    }
    if (current.isNotEmpty) lines.add(_Line(current, const {}));
    return lines;
  }
}

class _Segment {
  _Segment(this.text, this.attrs);
  final String text;
  final Map<String, dynamic> attrs;
}

class _Line {
  _Line(this.segments, this.blockAttrs);
  final List<_Segment> segments;
  final Map<String, dynamic> blockAttrs;

  bool get isBlank => segments.every((s) => s.text.trim().isEmpty);
  String get plain => segments.map((s) => s.text).join();

  String inlineMarkdown() {
    final b = StringBuffer();
    for (final s in segments) {
      b.write(_format(s));
    }
    return b.toString();
  }

  String _format(_Segment s) {
    var text = s.text;
    final leading = RegExp(r'^\s*').stringMatch(text) ?? '';
    final trailing = RegExp(r'\s*$').stringMatch(text) ?? '';
    if (leading.length == text.length) return text;
    var core = text.substring(leading.length, text.length - trailing.length);
    final a = s.attrs;
    core = core.replaceAllMapped(RegExp(r'([\\*_`\[\]])'), (m) => '\\${m[1]}');
    if (a['code'] == true) core = '`$core`';
    if (a['bold'] == true) core = '**$core**';
    if (a['italic'] == true) core = '*$core*';
    if (a['strike'] == true) core = '~~$core~~';
    if (a['underline'] == true) core = '<u>$core</u>';
    final link = a['link'];
    if (link is String && link.isNotEmpty) core = '[$core]($link)';
    return '$leading$core$trailing';
  }
}
