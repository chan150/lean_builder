part of 'element.dart';

abstract class DirectiveElement extends Element {
  String get stringUri;

  String get srcId;

  Uri get uri;

  LibraryElement get referencedLibrary;
}

class DirectiveElementImpl extends ElementImpl implements DirectiveElement {
  @override
  final String stringUri;

  @override
  final String srcId;

  @override
  final Uri uri;

  @override
  final LibraryElement library;

  DirectiveElementImpl({required this.library, required this.uri, required this.srcId, required this.stringUri});

  @override
  Element? get enclosingElement => library;

  @override
  String get name => stringUri;

  LibraryElement? _referencedLibrary;

  @override
  LibraryElement get referencedLibrary {
    if (_referencedLibrary != null) {
      return _referencedLibrary!;
    }
    _referencedLibrary = library.resolver.libraryForDirective(this);
    return _referencedLibrary!;
  }
}

class ImportElement extends DirectiveElementImpl {
  ImportElement({
    required super.library,
    required super.uri,
    required super.srcId,
    required super.stringUri,
    this.shownNames,
    this.hiddenNames,
    this.isDeferred = false,
    this.prefix,
  });

  final List<String>? shownNames;
  final List<String>? hiddenNames;

  final bool isDeferred;

  final String? prefix;
}

class ExportElement extends DirectiveElementImpl {
  ExportElement({
    required super.library,
    required super.uri,
    required super.srcId,
    required super.stringUri,
    this.shownNames,
    this.hiddenNames,
  });

  final List<String>? shownNames;
  final List<String>? hiddenNames;
}

class PartElement extends DirectiveElementImpl {
  PartElement({required super.library, required super.uri, required super.srcId, required super.stringUri});
}

class PartOfElement extends DirectiveElementImpl {
  PartOfElement({
    required super.library,
    required super.uri,
    required super.srcId,
    required super.stringUri,
    this.referencesLibraryDirective = false,
  });

  final bool referencesLibraryDirective;
}
