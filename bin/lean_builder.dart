import 'dart:io';
import 'dart:isolate';

import 'package:lean_builder/src/builder/build_step.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/scanner/assets_graph.dart';
import 'package:lean_builder/src/scanner/isolate_scanner.dart';
import 'package:lean_builder/src/utils.dart';
import 'my_builder.dart';

void main(List<String> args) async {
  final stopWatch = Stopwatch()..start();
  // print('Running Fresh Version');
  // if (AssetsGraph.cacheFile.existsSync()) {
  //   AssetsGraph.cacheFile.deleteSync(recursive: true);
  // }

  // final rootPackageName = 'gen_benchmark';

  final fileResolver = PackageFileResolver.forCurrentRoot(rootPackageName);
  final assetsGraph = AssetsGraph.init(fileResolver.packagesHash);

  final isoTlScanner = IsolateTLScanner(assetsGraph: assetsGraph, fileResolver: fileResolver);
  await isoTlScanner.scanAssets();

  print('Updating Graph took: ${stopWatch.elapsed.inMilliseconds} ms');
  stopWatch.reset();

  final parser = SrcParser();
  print('Resolving assets inside $rootPackageName');
  final assets = assetsGraph.getAssetsForPackage(rootPackageName).where((e) => e.hasAnnotation).toList();
  final isolateCount = Platform.numberOfProcessors - 1;
  final actualIsolateCount = isolateCount.clamp(1, assets.length);
  final chunkSize = (assets.length / actualIsolateCount).ceil();
  final chunks = <List<ScannedAsset>>[];

  for (int i = 0; i < assets.length; i += chunkSize) {
    final end = (i + chunkSize < assets.length) ? i + chunkSize : assets.length;
    chunks.add(assets.sublist(i, end));
  }

  final builders = [MyBuilder()];

  final futures = <Future>[];
  for (final chunk in chunks) {
    final future = Isolate.run(() async {
      final chunkResolver = Resolver(assetsGraph, fileResolver, parser);
      for (final asset in chunk) {
        final assetFile = fileResolver.assetSrcFor(asset.uri);

        for (final builder in builders) {
          final buildStep = BuildStepImpl(assetFile, chunkResolver, allowedExtensions: builder.generatedExtensions);
          final result = await builder.build(buildStep);
        }
      }
    });
    futures.add(future);
  }
  await Future.wait(futures);

  print('Resolving took: ${stopWatch.elapsed.inMilliseconds} ms');
}
