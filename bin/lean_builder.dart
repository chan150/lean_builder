import 'dart:io';
import 'dart:isolate';

import 'package:lean_builder/src/builder/build_step.dart';
import 'package:lean_builder/src/builder/builder_impl.dart';
import 'package:lean_builder/src/builder/output_writer.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/scanner/assets_graph.dart';
import 'package:lean_builder/src/scanner/isolate_scanner.dart';
import 'my_builder.dart';

void main(List<String> args) async {
  final stopWatch = Stopwatch()..start();
  // print('Running Fresh Version');
  // if (AssetsGraph.cacheFile.existsSync()) {
  //   AssetsGraph.cacheFile.deleteSync(recursive: true);
  // }

  final rootPackageName = 'gen_benchmark';

  final fileResolver = PackageFileResolver.forCurrentRoot(rootPackageName);
  final assetsGraph = AssetsGraph.init(fileResolver.packagesHash);

  final isoTlScanner = IsolateTLScanner(assetsGraph: assetsGraph, fileResolver: fileResolver);
  final scannedAssets = await isoTlScanner.scanAssets();

  final rootAssets = scannedAssets.where((e) => e.asset.packageName == rootPackageName);
  final toProcess = List.of(rootAssets.where((e) => e.state == AssetState.deleted || e.hasTopLevelAnnotation));
  if (toProcess.isEmpty) {
    print('No assets to process');
    return;
  }

  print('Updating Graph took: ${stopWatch.elapsed.inMilliseconds} ms');
  stopWatch.reset();

  final parser = SrcParser();
  print('Resolving assets inside $rootPackageName');
  final isolateCount = Platform.numberOfProcessors - 1;
  final actualIsolateCount = isolateCount.clamp(1, toProcess.length);
  final chunkSize = (toProcess.length / actualIsolateCount).ceil();
  final chunks = <List<ProcessableAsset>>[];

  for (int i = 0; i < toProcess.length; i += chunkSize) {
    final end = (i + chunkSize < toProcess.length) ? i + chunkSize : toProcess.length;
    chunks.add(toProcess.sublist(i, end));
  }

  final builders = [
    SharedPartBuilder([MyGenerator()]),
  ];

  final futures = <Future>[];
  for (final chunk in chunks) {
    final future = Isolate.run(() async {
      final chunkResolver = Resolver(assetsGraph, fileResolver, parser);
      for (final entry in chunk) {
        if (entry.state == AssetState.deleted) {
          // delete all possible generated files
          for (final builder in builders) {
            for (final ext in builder.outputExtensions) {
              final generatedAsset = File.fromUri(entry.asset.changeUriExtension(ext));
              if (generatedAsset.existsSync()) {
                print('Deleting ${generatedAsset.path}');
                generatedAsset.deleteSync();
              }
            }
          }
        }
        final outputWriter = DeferredOutputWriter(entry.asset);
        for (final builder in builders) {
          final buildStep = BuildStepImpl(
            entry.asset,
            chunkResolver,
            outputWriter,
            allowedExtensions: builder.outputExtensions,
          );
          await builder.build(buildStep);
        }
        await outputWriter.flush();
      }
    });
    futures.add(future);
  }
  if (futures.isNotEmpty) {
    await Future.wait(futures);
  }

  print('Resolving took: ${stopWatch.elapsed.inMilliseconds} ms');
}
