import 'dart:io';

import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/top_level_scanner.dart';
import 'package:collection/collection.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../utils/mock_package_file_resolver.dart';

main() {
  late TopLevelScanner scanner;
  late AssetsGraph assetsGraph;
  setUp(() {
    final mockPackageFileResolver = MockPackageFileResolver();
    assetsGraph = AssetsGraph(mockPackageFileResolver.packagesHash);
    scanner = TopLevelScanner(assetsGraph, mockPackageFileResolver);
  });

  test('TopLevelScanner should scan a file', () {
    final file = AssetFile(File('test/scanner/samples/general_identifiers.dart'), Uri(path: ''), '', false);
    scanner.scanFile(file);
    final expected = [
      'kPi',
      'inferredConst',
      'constants',
      'Color',
      'JsonMap',
      'Map',
      'Record',
      'Callback',
      'Function',
      'GenericCallback',
      'StringExt',
      'Logger',
      'Shape',
      'Rectangle',
      'Box',
      'printMsg',
      'add',
      'configure',
      'List',
      'getRange',
      'identity',
      'fetchData',
      'countStream',
    ];
    expect(assetsGraph.identifiers.map((e) => e[0]).toList(), expected);
    expect(assetsGraph.assets.values.first[2], 0);
  });

  test('TopLevelScanner should scan a file with top level annotation', () {
    final file = AssetFile(File('test/scanner/samples/with_annotation.dart'), Uri(path: ''), '', false);
    scanner.scanFile(file);
    expect(assetsGraph.assets.values.first[2], 1);
  });

  test('TopLevelScanner should scan a file with directive', () {
    final file = AssetFile(File('test/scanner/samples/with_directives.dart'), Uri(path: ''), '', false);
    scanner.scanFile(file);
    final equals = ListEquality().equals;

    /// one exporting file
    expect(assetsGraph.exports.length, 1);
    final exports = assetsGraph.exports.values.first;

    /// one export without show/hide
    expect(exports.any((e) => e.length == 1), true);

    /// one export with show
    expect(exports.any((e) => e.length == 2 && equals(e[1], ['Annotation'])), true);

    /// one export with hide
    expect(exports.any((e) => e.length == 3 && equals(e[1], []) && equals(e[2], ['Annotation'])), true);

    /// one importing file
    expect(assetsGraph.imports.length, 1);
    final imports = assetsGraph.imports.values.first;

    /// one import without show/hide
    expect(imports.any((e) => e.length == 1), true);

    /// one import with show
    expect(imports.any((e) => e.length == 2 && equals(e[1], ['Annotation'])), true);

    /// one import with hide
    expect(imports.any((e) => e.length == 3 && equals(e[1], []) && equals(e[2], ['Annotation'])), true);
  });
}
