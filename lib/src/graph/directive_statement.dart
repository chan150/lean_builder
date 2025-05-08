import 'package:lean_builder/src/asset/asset.dart';

/// {@template directive_statement}
/// Represents a Dart directive statement found during source code scanning.
///
/// Directives are special statements that affect how a Dart program is organized
/// and interpreted. This class represents the different types of directives:
/// - library declarations (`library name;`)
/// - imports (`import 'uri';`)
/// - exports (`export 'uri';`)
/// - part directives (`part 'uri';`)
/// - part-of directives (`part of 'uri';` or `part of library;`)
///
/// It captures all relevant information about the directive, including
/// any show/hide clauses, prefixes, and deferral status.
/// {@endtemplate}
class DirectiveStatement {
  /// Constant representing a library directive (`library name;`)
  static const int library = 0;

  /// Constant representing an import directive (`import 'uri';`)
  static const int import = 1;

  /// Constant representing an export directive (`export 'uri';`)
  static const int export = 2;

  /// Constant representing a part directive (`part 'uri';`)
  static const int part = 3;

  /// Constant representing a part-of directive with URI (`part of 'uri';`)
  static const int partOf = 4;

  /// Constant representing a part-of directive with library name (`part of library;`)
  static const int partOfLibrary = 5;

  /// The type of directive (one of the constants defined above)
  final int type;

  /// The asset referenced by this directive
  final Asset asset;

  /// The list of identifiers in the show clause (e.g., `show A, B` → ['A', 'B'])
  final List<String> show;

  /// The list of identifiers in the hide clause (e.g., `hide C, D` → ['C', 'D'])
  final List<String> hide;

  /// The prefix used in an import directive (e.g., `import 'foo.dart' as bar` → 'bar')
  final String? prefix;

  /// Whether this import is deferred (e.g., `import 'foo.dart' deferred as bar`)
  final bool deferred;

  /// The original string URI as it appears in the directive (e.g., 'package:foo/bar.dart')
  final String stringUri;

  /// {@macro directive_statement}
  DirectiveStatement({
    required this.type,
    required this.asset,
    required this.stringUri,
    this.show = const <String>[],
    this.hide = const <String>[],
    this.prefix,
    this.deferred = false,
  });

  @override
  String toString() {
    return 'ExportStatement{path: $asset, show: $show, hide: $hide}';
  }
}
