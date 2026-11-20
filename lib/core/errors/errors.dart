class ValidationException implements Exception {
  ValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CircularFolderException implements Exception {
  @override
  String toString() =>
      'A folder cannot be moved into itself or its subfolders.';
}

class DuplicateTagException implements Exception {
  DuplicateTagException(this.name);
  final String name;
  @override
  String toString() => 'A tag named "$name" already exists.';
}

class NotFoundException implements Exception {
  NotFoundException(this.what);
  final String what;
  @override
  String toString() => '$what not found.';
}
