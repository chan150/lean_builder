part of 'element.dart';

/// {@template directive_element}
/// Base class for representing directives within Dart libraries.
///
/// Directives are top-level constructs such as imports, exports,
/// and part declarations that control how libraries interact with each other.
/// This class provides access to the URI referenced by the directive and
/// the library it belongs to or references.
/// {@endtemplate}
abstract class DirectiveElement extends Element {
  /// {@template directive_element.string_uri}
  /// The string representation of the URI as it appears in the source code.
  ///
  /// For example, in `import 'package:example/example.dart'`,
  /// this would be `'package:example/example.dart'`.
  /// {@endtemplate}
  String get stringUri;

  /// {@template directive_element.src_id}
  /// A unique identifier for the source file containing this directive.
  ///
  /// Used to track references between files and for caching purposes.
  /// {@endtemplate}
  String get srcId;

  /// {@template directive_element.uri}
  /// The resolved URI object for this directive.
  ///
  /// This URI can be used to locate the physical file being referenced.
  /// {@endtemplate}
  Uri get uri;

  /// {@template directive_element.referenced_library}
  /// The library element referenced by this directive.
  ///
  /// This provides access to the elements defined in the target library.
  /// {@endtemplate}
  LibraryElement get referencedLibrary;
}

/// {@template directive_element_impl}
/// Implementation of a directive element within a Dart library.
///
/// This class provides common functionality for all directive types,
/// including URI resolution and access to the referenced library.
/// {@endtemplate}
class DirectiveElementImpl extends ElementImpl implements DirectiveElement {
  @override
  final String stringUri;

  @override
  final String srcId;

  @override
  final Uri uri;

  @override
  final LibraryElement library;

  /// {@template directive_element_impl.constructor}
  /// Creates a directive element with the specified parameters.
  ///
  /// @param library The library containing this directive
  /// @param uri The resolved URI for this directive
  /// @param srcId Source identifier for tracking references
  /// @param stringUri Original string representation of the URI
  /// {@endtemplate}
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

/// {@template import_element}
/// Represents an import directive in a Dart library.
///
/// Import directives bring declarations from other libraries into scope with
/// the `import` keyword. They can include optional show/hide combinators
/// to filter which declarations are imported, can use prefixes, and
/// can be marked as deferred.
/// {@endtemplate}
class ImportElement extends DirectiveElementImpl {
  /// {@template import_element.constructor}
  /// Creates an import directive element with the specified parameters.
  ///
  /// @param library The library containing this import
  /// @param uri The resolved URI for this import
  /// @param srcId Source identifier for tracking references
  /// @param stringUri Original string representation of the URI
  /// @param shownNames Names explicitly included via 'show' combinator
  /// @param hiddenNames Names explicitly excluded via 'hide' combinator
  /// @param isDeferred Whether this is a deferred import (with 'deferred' keyword)
  /// @param prefix The prefix for this import, if any
  /// {@endtemplate}
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

  /// {@template import_element.shown_names}
  /// Names explicitly included via the 'show' combinator.
  ///
  /// For an import with `show x, y`, this would contain ['x', 'y'].
  /// If no 'show' combinator is present, this will be null.
  /// {@endtemplate}
  final List<String>? shownNames;

  /// {@template import_element.hidden_names}
  /// Names explicitly excluded via the 'hide' combinator.
  ///
  /// For an import with `hide a, b`, this would contain ['a', 'b'].
  /// If no 'hide' combinator is present, this will be null.
  /// {@endtemplate}
  final List<String>? hiddenNames;

  /// {@template import_element.is_deferred}
  /// Whether this import is deferred.
  ///
  /// Deferred imports use the 'deferred as' syntax and load the library
  /// lazily when first used via the import prefix.
  /// {@endtemplate}
  final bool isDeferred;

  /// {@template import_element.prefix}
  /// The prefix for this import, if any.
  ///
  /// For an import with `as prefix`, this would be 'prefix'.
  /// If no prefix is specified, this will be null.
  /// {@endtemplate}
  final String? prefix;
}

/// {@template export_element}
/// Represents an export directive in a Dart library.
///
/// Export directives make declarations from other libraries available to libraries
/// that import the exporting library with the `export` keyword. They can include
/// optional show/hide combinators to filter which declarations are exported.
/// {@endtemplate}
class ExportElement extends DirectiveElementImpl {
  /// {@template export_element.constructor}
  /// Creates an export directive element with the specified parameters.
  ///
  /// @param library The library containing this export
  /// @param uri The resolved URI for this export
  /// @param srcId Source identifier for tracking references
  /// @param stringUri Original string representation of the URI
  /// @param shownNames Names explicitly included via 'show' combinator
  /// @param hiddenNames Names explicitly excluded via 'hide' combinator
  /// {@endtemplate}
  ExportElement({
    required super.library,
    required super.uri,
    required super.srcId,
    required super.stringUri,
    this.shownNames,
    this.hiddenNames,
  });

  /// {@macro import_element.shown_names}
  final List<String>? shownNames;

  /// {@macro import_element.hidden_names}
  final List<String>? hiddenNames;
}

/// {@template part_element}
/// Represents a part directive in a Dart library.
///
/// Part directives include files as part of the current library with
/// the `part` keyword. This allows splitting a library across multiple files.
/// {@endtemplate}
class PartElement extends DirectiveElementImpl {
  /// {@template part_element.constructor}
  /// Creates a part directive element with the specified parameters.
  ///
  /// @param library The library containing this part directive
  /// @param uri The resolved URI for this part
  /// @param srcId Source identifier for tracking references
  /// @param stringUri Original string representation of the URI
  /// {@endtemplate}
  PartElement({required super.library, required super.uri, required super.srcId, required super.stringUri});
}

/// {@template part_of_element}
/// Represents a part-of directive in a Dart library.
///
/// Part-of directives indicate that a file is part of another library with
/// the `part of` keyword. This can reference either a library by its URI or
/// by its name.
/// {@endtemplate}
class PartOfElement extends DirectiveElementImpl {
  /// {@template part_of_element.constructor}
  /// Creates a part-of directive element with the specified parameters.
  ///
  /// @param library The library containing this part-of directive
  /// @param uri The resolved URI for the containing library
  /// @param srcId Source identifier for tracking references
  /// @param stringUri Original string representation of the URI
  /// @param referencesLibraryDirective Whether this part-of references a library by name
  /// {@endtemplate}
  PartOfElement({
    required super.library,
    required super.uri,
    required super.srcId,
    required super.stringUri,
    this.referencesLibraryDirective = false,
  });

  /// {@template part_of_element.references_library_directive}
  /// Whether this part-of directive references a library by name rather than URI.
  ///
  /// When true, this indicates a `part of library_name` syntax was used rather
  /// than `part of 'uri.dart'`.
  /// {@endtemplate}
  final bool referencesLibraryDirective;
}

/// {@template library_directive_element}
/// Represents a library directive in a Dart library.
///
/// Library directives declare the name of a library with the `library` keyword,
/// allowing it to be referenced by name in part-of directives.
/// {@endtemplate}
class LibraryDirectiveElement extends DirectiveElementImpl {
  /// {@template library_directive_element.constructor}
  /// Creates a library directive element with the specified parameters.
  ///
  /// @param library The library containing this library directive
  /// @param uri The resolved URI for this library
  /// @param srcId Source identifier for tracking references
  /// @param stringUri Original string representation of the library name
  /// {@endtemplate}
  LibraryDirectiveElement({required super.library, required super.uri, required super.srcId, required super.stringUri});

  @override
  String get name => stringUri;
}
