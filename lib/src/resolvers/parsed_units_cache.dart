import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';

class SrcParser {
  final _cache = <String, CompilationUnit>{};

  CompilationUnit? get(String key) => _cache[key];

  CompilationUnit parse(AssetSrc src) {
    return parseContent(src.readAsStringSync, key: src.id);
  }

  CompilationUnit parseContent(String Function() content, {required String key}) {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }
    final unit = parseString(content: content()).unit;
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
