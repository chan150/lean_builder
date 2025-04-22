import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:lean_builder/src/builder/build_step.dart';
import 'package:lean_builder/src/builder/builder.dart';
import 'package:lean_builder/src/builder/output_writer.dart';
import 'package:lean_builder/src/builder/runner/builder_entry.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/scanner/assets_graph.dart';
import 'package:lean_builder/src/scanner/isolate_symbols_scanner.dart';
import 'package:lean_builder/src/scanner/symbols_scanner.dart';
import 'package:lean_builder/src/utils.dart';

Future<void> runBuilders(List<BuilderEntry> builders, List<String> args) async {
  final stopWatch = Stopwatch()..start();

  final fileResolver = PackageFileResolver.forCurrentRoot(rootPackageName);
  final assetsGraph = AssetsGraph.init(fileResolver.packagesHash);

  final assets = await scanPackageAssets(
    rootPackageName: rootPackageName,
    assetsGraph: assetsGraph,
    fileResolver: fileResolver,
  );

  if (assets.isEmpty) {
    Logger.success('No assets to process');
    return;
  }
  try {
    final outputs = await buildAssets(
      assets: assets,
      builders: builders,
      assetsGraph: assetsGraph,
      fileResolver: fileResolver,
    );
    final outputCount = await _finalizeBuild(assetsGraph, fileResolver, outputs);
    Logger.success('Done with ($outputCount) outputs, took ${stopWatch.elapsed.inMilliseconds} ms');
  } catch (e) {
    Logger.error('Error while building assets: $e');
    rethrow;
  }
}

Future<int> _finalizeBuild(
  AssetsGraph assetsGraph,
  PackageFileResolver fileResolver,
  Map<Asset, Set<Uri>> outputs,
) async {
  int outputCount = 0;
  final scanner = SymbolsScanner(assetsGraph, fileResolver);
  for (final entry in outputs.entries) {
    for (final uri in entry.value) {
      outputCount++;
      final output = fileResolver.assetForUri(uri);
      assetsGraph.invalidateDigest(output);
      scanner.scan(output);
      assetsGraph.addOutput(entry.key, output);
    }
  }
  assetsGraph.save();
  return outputCount;
}

/// Scans assets from the root package and returns processable assets
Future<List<ProcessableAsset>> scanPackageAssets({
  required String rootPackageName,
  required AssetsGraph assetsGraph,
  required PackageFileResolver fileResolver,
}) async {
  final symbolsScanner = IsolateSymbolsScanner(
    assetsGraph: assetsGraph,
    fileResolver: fileResolver,
    targetPackage: rootPackageName,
  );
  final scannedAssets = await symbolsScanner.scanAssets();

  final processableAssets = List.of(
    scannedAssets.where((e) {
      final asset = e.asset;
      return asset.packageName == fileResolver.rootPackage && !asset.uri.path.endsWith('.g.dart');
    }),
    growable: false,
  );

  if (scannedAssets.isNotEmpty) {
    await assetsGraph.save();
  }

  return processableAssets;
}

Future<Map<Asset, Set<Uri>>> buildAssets({
  required List<ProcessableAsset> assets,
  required List<BuilderEntry> builders,
  required AssetsGraph assetsGraph,
  required PackageFileResolver fileResolver,
}) async {
  assert(assets.isNotEmpty);

  final parser = SrcParser();
  // Parallelize processing
  final isolateCount = Platform.numberOfProcessors - 1;
  final actualIsolateCount = isolateCount.clamp(1, assets.length);
  final chunkSize = (assets.length / actualIsolateCount).ceil();
  final chunks = <List<ProcessableAsset>>[];

  for (int i = 0; i < assets.length; i += chunkSize) {
    final end = (i + chunkSize < assets.length) ? i + chunkSize : assets.length;
    chunks.add(assets.sublist(i, end));
  }

  final outputResults = <Future<Map<Asset, Set<Uri>>>>[];

  for (final chunk in chunks) {
    final future = Isolate.run(() async {
      final chunkOutputs = HashMap<Asset, Set<Uri>>();
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

        final candidate = BuildCandidate(
          entry.asset,
          entry.hasTopLevelMetadata,
          assetsGraph.exportedSymbolsOf(entry.asset.id),
        );

        try {
          final outputWriter = DeferredOutputWriter(entry.asset);

          for (final builderEntry in builders) {
            if (!builderEntry.shouldGenerateFor(candidate)) continue;

            final buildStep = BuildStepImpl(
              entry.asset,
              chunkResolver,
              outputWriter,
              allowedExtensions: builderEntry.builder.outputExtensions,
            );

            await builderEntry.build(buildStep);
            final generatedOutputs = await outputWriter.flushOutputs();
            chunkOutputs.putIfAbsent(entry.asset, () => <Uri>{}).addAll(generatedOutputs);
          }

          final output = await outputWriter.flushSharedOutput();
          if (output != null) {
            chunkOutputs.putIfAbsent(entry.asset, () => <Uri>{}).add(output);
          }
        } catch (e) {
          assetsGraph.invalidateDigest(entry.asset);
          rethrow;
        }
      }
      return chunkOutputs;
    });
    outputResults.add(future);
  }

  final allOutputMap = <Asset, Set<Uri>>{};
  for (final output in await Future.wait(outputResults)) {
    allOutputMap.addAll(output);
  }
  return allOutputMap;
}
