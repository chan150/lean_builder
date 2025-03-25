import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

class SrcParser {
  final _cache = <String, CompilationUnit>{};
  CompilationUnit? get(String path) => _cache[path];

  CompilationUnit parse(String path) {
    if (_cache.containsKey(path)) {
      return _cache[path]!;
    }
    final unit = parseFile(path: path, featureSet: FeatureSet.latestLanguageVersion()).unit;
    _cache[path] = unit;
    return unit;
  }

  void remove(String path) {
    _cache.remove(path);
  }

  void clear() {
    _cache.clear();
  }
}
