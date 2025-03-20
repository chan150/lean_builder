import 'dart:io';

import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../../bin/scanner/assets_graph.dart';
import '../../bin/scanner/top_level_scanner.dart';
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
    final file = File('test/scanner/samples/sample_1.dart');
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
      'Annotation',
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
  });

  // expect has at least one top level annotation
  test('TopLevelScanner should scan a file with top level annotation', () {
    final file = File('test/scanner/samples/sample_1.dart');
    scanner.scanFile(file);
    expect(assetsGraph.assets.values.first[2], 1);
  });
}
