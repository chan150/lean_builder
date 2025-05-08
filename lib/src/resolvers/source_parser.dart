import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/asset/asset.dart';

/// {@template source_parser}
/// A parser that caches parsed Dart compilation units.
///
/// This class provides methods to parse Dart source code and cache the
/// resulting AST structures for efficient reuse. It can parse both Asset
/// objects and raw string content.
/// {@endtemplate}
class SourceParser {
  /// Internal cache of parsed compilation units, keyed by a string identifier.
  final Map<String, CompilationUnit> _cache = <String, CompilationUnit>{};

  /// {@template source_parser.get}
  /// Retrieves a cached compilation unit for the given key.
  ///
  /// @param key The identifier for the cached compilation unit
  /// @return The cached compilation unit, or null if not found
  /// {@endtemplate}
  CompilationUnit? get(String key) => _cache[key];

  /// {@template source_parser.parse}
  /// Parses a Dart asset into a compilation unit, with caching.
  ///
  /// If the asset has been previously parsed, returns the cached result.
  /// Otherwise, parses the content and caches the result.
  ///
  /// @param src The asset to parse
  /// @param allowSyntaxErrors Whether to continue parsing even with syntax errors
  /// @return The parsed compilation unit
  /// {@endtemplate}
  CompilationUnit parse(Asset src, {bool allowSyntaxErrors = false}) {
    return parseContent(src.readAsStringSync, key: src.id, throwIfDiagnostics: !allowSyntaxErrors);
  }

  /// {@template source_parser.parse_content}
  /// Parses Dart source content into a compilation unit, with caching.
  ///
  /// If the content with the given key has been previously parsed, returns the cached result.
  /// Otherwise, parses the content and caches the result.
  ///
  /// @param content Function that provides the source content to parse
  /// @param key Identifier to use for caching the parsed unit
  /// @param throwIfDiagnostics Whether to throw an exception if diagnostics are present
  /// @return The parsed compilation unit
  /// {@endtemplate}
  CompilationUnit parseContent(String Function() content, {required String key, bool throwIfDiagnostics = false}) {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }
    final CompilationUnit unit = parseString(content: content(), throwIfDiagnostics: throwIfDiagnostics).unit;
    _cache[key] = unit;
    return unit;
  }

  /// {@template source_parser.invalidate}
  /// Removes a cached compilation unit for the given key.
  ///
  /// @param key The identifier for the compilation unit to invalidate
  /// {@endtemplate}
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// {@template source_parser.clear}
  /// Removes all cached compilation units.
  /// {@endtemplate}
  void clear() {
    _cache.clear();
  }
}
