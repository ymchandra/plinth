import 'dart:async';

enum SaveStatus { idle, dirty, saving, saved, error }

class NoteDraft {
  const NoteDraft({required this.title, required this.contentJson});
  final String title;
  final String contentJson;

  @override
  bool operator ==(Object other) =>
      other is NoteDraft &&
      other.title == title &&
      other.contentJson == contentJson;

  @override
  int get hashCode => Object.hash(title, contentJson);
}

/// Debounced, serialised autosave. Edits are coalesced; saves never run
/// concurrently, so the last edit always wins. A failed save keeps the draft
/// pending and is retried on the next edit or [flush].
class AutosaveController {
  AutosaveController({
    required this.save,
    this.debounce = const Duration(milliseconds: 800),
    NoteDraft? initial,
  }) : _lastSaved = initial;

  final Future<void> Function(NoteDraft draft) save;
  final Duration debounce;

  final _status = StreamController<SaveStatus>.broadcast();
  Stream<SaveStatus> get statusStream => _status.stream;
  SaveStatus _current = SaveStatus.idle;
  SaveStatus get status => _current;

  Timer? _timer;
  NoteDraft? _pending;
  NoteDraft? _lastSaved;
  Future<void> _chain = Future.value();
  bool _disposed = false;

  bool get hasPendingChanges => _pending != null;

  void _emit(SaveStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  void schedule(NoteDraft draft) {
    if (_disposed) return;
    if (draft == _lastSaved && _pending == null) return;
    _pending = draft;
    _emit(SaveStatus.dirty);
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// Writes any pending draft now and waits for all in-flight saves.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final draft = _pending;
    if (draft != null) {
      _pending = null;
      if (draft == _lastSaved) {
        _emit(SaveStatus.saved);
      } else {
        _chain = _chain.then((_) => _write(draft));
      }
    }
    return _chain;
  }

  Future<void> _write(NoteDraft draft) async {
    _emit(SaveStatus.saving);
    try {
      await save(draft);
      _lastSaved = draft;
      _emit(_pending == null ? SaveStatus.saved : SaveStatus.dirty);
    } catch (_) {
      // Keep the draft unless a newer edit has superseded it.
      _pending ??= draft;
      _emit(SaveStatus.error);
    }
  }

  Future<void> dispose() async {
    await flush();
    _disposed = true;
    await _status.close();
  }
}
