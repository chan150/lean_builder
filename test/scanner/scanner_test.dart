import 'dart:io';

import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/top_level_scanner.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../utils/mock_package_file_resolver.dart';

main() {
  late TopLevelScanner scanner;
  late AssetsGraph assetsGraph;
  setUp(() {
    final mockPackageFileResolver = MockPackageFileResolver();
    assetsGraph = AssetsGraph(mockPackageFileResolver);
    scanner = TopLevelScanner(assetsGraph);
  });

  test('TopLevelScanner should scan a file', () {
    final file = FileAsset(File('test/scanner/samples/general_identifiers.dart'), Uri(path: ''), '', false);
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
    final file = FileAsset(File('test/scanner/samples/with_annotation.dart'), Uri(path: ''), '', false);
    scanner.scanFile(file);
    expect(assetsGraph.assets.values.first[2], 0);
  });
}
