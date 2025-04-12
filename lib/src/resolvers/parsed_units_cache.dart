import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

class SrcParser {
  final _cache = <String, CompilationUnit>{};

  CompilationUnit? get(String key) => _cache[key];

  CompilationUnit parse(String path, {required String key}) {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }
    final unit = parseFile(path: path, featureSet: FeatureSet.latestLanguageVersion()).unit;
    _cache[key] = unit;
    return unit;
  }

  void remove(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }
}
