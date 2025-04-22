import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:lean_builder/src/builder/build_step.dart';
import 'package:lean_builder/src/builder/builder_impl.dart';
import 'package:lean_builder/src/builder/output_writer.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/scanner/assets_graph.dart';
import 'package:lean_builder/src/scanner/isolate_scanner.dart';
import 'package:lean_builder/src/scanner/top_level_scanner.dart';
import 'package:lean_builder/src/utils.dart';
import 'my_builder.dart';

void main(List<String> args) async {
  final stopWatch = Stopwatch()..start();

  final rootPackageName = 'gen_benchmark';

  final fileResolver = PackageFileResolver.forCurrentRoot(rootPackageName);
  final assetsGraph = AssetsGraph.init(fileResolver.packagesHash);

  final isoTlScanner = IsolateTLScanner(assetsGraph: assetsGraph, fileResolver: fileResolver);
  final scannedAssets = await isoTlScanner.scanAssets();

  final rootAssets = scannedAssets.where((e) => e.asset.packageName == fileResolver.rootPackage);
  final toProcess = List.of(
    rootAssets.where(
      (e) => (e.state == AssetState.deleted || e.hasTopLevelAnnotation) && !e.asset.uri.path.endsWith('.g.dart'),
    ),
  );

  if (scannedAssets.isNotEmpty) {
    await assetsGraph.save();
  }

  if (toProcess.isEmpty) {
    Logger.success('All assets are up to date');

    return;
  }

  print('Updating Graph took: ${stopWatch.elapsed.inMilliseconds} ms');
  stopWatch.reset();

  final parser = SrcParser();
  print('Resolving assets inside ${fileResolver.rootPackage}');
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
  final scanner = TopLevelScanner(assetsGraph, fileResolver);
  final futures = <Future<Map<Asset, Set<Uri>>>>[];

  for (final chunk in chunks) {
    final future = Isolate.run(() async {
      final allOutputs = HashMap<Asset, Set<Uri>>();
      final chunkResolver = Resolver(assetsGraph, fileResolver, parser);
      for (final entry in chunk) {
        // delete all possible generated files

        final outputs = assetsGraph.outputs[entry.asset.id];
        if (outputs != null) {
          for (final output in outputs) {
            final outputUri = assetsGraph.uriForAssetOrNull(output);
            if (outputUri == null) continue;
            final outputAsset = fileResolver.assetForUri(outputUri);
            assetsGraph.outputs.remove(entry.asset.id);
            outputAsset.safeDelete();
          }
        }

        if (entry.state == AssetState.deleted) {
          continue;
        }
        try {
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
          final outputs = await outputWriter.flush();

          allOutputs[entry.asset] = outputs;
        } catch (e) {
          assetsGraph.invalidateDigest(entry.asset);
          rethrow;
        }
      }
      return allOutputs;
    });
    futures.add(future);
  }
  if (futures.isNotEmpty) {
    final results = await Future.wait(futures);
    for (final result in results) {
      for (final entry in result.entries) {
        for (final uri in entry.value) {
          final output = fileResolver.assetForUri(uri);
          assetsGraph.invalidateDigest(output);
          scanner.scan(output);
          assetsGraph.addOutput(entry.key, output);
        }
      }
    }
  }
  await assetsGraph.save();

  print('Resolving took: ${stopWatch.elapsed.inMilliseconds} ms');
}
