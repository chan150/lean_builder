import 'dart:async';
import 'dart:convert';
import 'package:code_genie/src/resolvers/assets_reader.dart';
import 'package:code_genie/src/resolvers/element_resolver.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/resolvers/parsed_units_cache.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/isolate_scanner.dart';
import 'package:code_genie/src/scanner/top_level_scanner.dart';
import 'package:code_genie/src/utils.dart';

final testFile = '/Users/milad/StudioProjects/code_genie/lib/test/test.dart';

void main(List<String> args) async {
  Future;
  final stopWatch = Stopwatch()..start();
  print('Running Fresh Version');
  // if (AssetsGraph.cacheFile.existsSync()) {
  //   AssetsGraph.cacheFile.deleteSync(recursive: true);
  // }
  final fileResolver = PackageFileResolver.forCurrentRoot(rootPackageName);
  final assetsGraph = AssetsGraph.init(fileResolver.packagesHash);

  // final scanner = TopLevelScanner(assetsGraph, fileResolver);
  // final asset = fileResolver.buildAssetUri(Uri.parse('package:code_genie/test/test.dart'));
  // final asset2 = fileResolver.buildAssetUri(Uri.parse('package:code_genie/test/test2.dart'));
  //
  // scanner.scanFile(asset);
  // scanner.scanFile(asset2);
  //
  // final reader = FileAssetReader(fileResolver);
  //
  // for (final asset in reader.listAssetsFor({r'$sdk'}).values.first) {
  //   scanner.scanFile(asset);
  // }
  // AssetsGraph.cacheFile.writeAsString(jsonEncode(assetsGraph.toJson()));
  //
  // print(assetsGraph.getIdentifierRef('num', ''));
  //
  // return;

  final isoTlScanner = IsolateTLScanner(assetsGraph: assetsGraph, fileResolver: fileResolver);
  await isoTlScanner.scanAssets();

  final parser = SrcParser();
  final resolver = ElementResolver(assetsGraph, fileResolver, parser);
  final packageAssets = assetsGraph.getAssetsForPackage('mofad_dashboard');

  for (final asset in packageAssets) {
    if (asset.hasAnnotation) {
      final assetFile = fileResolver.buildAssetUri(asset.uri);
      final library = resolver.resolveLibrary(assetFile);
      for (final clazz in library.classes) {
        if (clazz.fields.isNotEmpty) {
          print(clazz.fields.map((e) => '${e.type.toString()} ${e.name} '));
        }
        if (clazz.methods.isNotEmpty) {
          print(clazz.methods.map((e) => e.name));
        }
      }
    }
  }

  // await assetsGraphFile.writeAsString(jsonEncode(assetsGraph.toJson()));
  print('Time taken: ${stopWatch.elapsed.inMilliseconds} ms');
}
