import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/source/line_info.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/experiments.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/scanner/reader.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/scanner/scanner.dart';
// ignore: implementation_imports
import 'package:analyzer/src/generated/parser.dart';
// ignore: implementation_imports
import 'package:analyzer/src/string_source.dart';

class SrcParser {
  final _cache = <String, CompilationUnit>{};

  CompilationUnit? get(String path) => _cache[path];

  CompilationUnit parse(String path) {
    if (_cache.containsKey(path)) {
      return _cache[path]!;
    }
    final unit = parseString(content: File(path).readAsStringSync(), path: path);
    _cache[path] = unit;
    return unit;
  }

  void remove(String path) {
    _cache.remove(path);
  }

  void clear() {
    _cache.clear();
  }

  CompilationUnit parseString({required String content, FeatureSet? featureSet, String? path}) {
    featureSet ??= FeatureSet.latestLanguageVersion();
    var source = StringSource(content, path ?? '');
    var reader = CharSequenceReader(content);
    var errorCollector = BooleanErrorListener();
    var scanner = Scanner(source, reader, errorCollector)
      ..configureFeatures(featureSetForOverriding: featureSet, featureSet: featureSet);
    var token = scanner.tokenize();
    var languageVersion = LibraryLanguageVersion(
      package: ExperimentStatus.currentVersion,
      override: scanner.overrideVersion,
    );
    var lineInfo = LineInfo(scanner.lineStarts);
    var parser = Parser(
      source,
      errorCollector,
      featureSet: scanner.featureSet,
      languageVersion: languageVersion,
      lineInfo: lineInfo,
      allowNativeClause: false,
    );
    parser.parseFunctionBodies = false;
    return parser.parseCompilationUnit(token);
  }
}
