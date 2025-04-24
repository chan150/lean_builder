import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/builder/build_step.dart';
import 'package:lean_builder/src/builder/builder.dart';
import 'package:lean_builder/src/builder/output_writer.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/isolate_symbols_scanner.dart';
import 'package:lean_builder/src/graph/symbols_scanner.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/runner/builder_entry.dart';
import 'package:lean_builder/src/utils.dart';

import 'build_result.dart';

Future<void> runBuilders(List<BuilderEntry> builders, List<String> args) async {
  final stopWatch = Stopwatch()..start();

  final fileResolver = PackageFileResolver.forRoot();
  final assetsGraph = AssetsGraph.init(fileResolver.packagesHash);

  final parser = ArgParser();
  parser.addFlag(
    'dev',
    abbr: 'd',
    negatable: false,
    help: 'Run in development mode, this will use JIT compilation and delete all build outputs before each run.',
  );
  parser.addFlag('help', abbr: 'h', negatable: false, help: 'Display this help message.');

  final argResults = parser.parse(args);

  if (argResults['help'] as bool) {
    print(parser.usage);
    exit(0);
  }

  final isDevMode = argResults['dev'] as bool;
  final assets = await scanPackageAssets(
    rootPackageName: rootPackageName,
    assetsGraph: assetsGraph,
    fileResolver: fileResolver,
  );

  if (isDevMode) {
    for (final key in assetsGraph.outputs.keys) {
      final uri = assetsGraph.uriForAssetOrNull(key);
      if (uri == null) continue;
      final input = fileResolver.assetForUri(uri);
      assets.add(ProcessableAsset(input, AssetState.needUpdate, true));
    }
  }

  if (assets.isEmpty) {
    Logger.success('No assets to process');
    return;
  }

  try {
    final buildResult = await buildAssets(
      assets: assets,
      builders: builders,
      assetsGraph: assetsGraph,
      fileResolver: fileResolver,
    );
    final outputCount = await _finalizeBuild(assetsGraph, fileResolver, buildResult.outputs);
    final errors = buildResult.fieldAssets;
    if (errors.isNotEmpty) {
      Logger.error('Errors while building assets:');
      for (final error in errors) {
        assetsGraph.invalidateDigest(error.asset.id);
        Logger.error('${error.error} while processing: ${error.asset.shortUri}');
      }
    }
    await assetsGraph.save();
    if (errors.isNotEmpty) {
      exit(1);
    }

    Logger.success('Done with ($outputCount) outputs, took ${stopWatch.elapsed.inMilliseconds} ms');
  } catch (e) {
    await assetsGraph.save();
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
      assetsGraph.invalidateDigest(output.id);
      scanner.scan(output);
      assetsGraph.addOutput(entry.key, output);
    }
  }
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
  );

  if (scannedAssets.isNotEmpty) {
    await assetsGraph.save();
  }

  return processableAssets;
}

Future<BuildResult> buildAssets({
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

  final outputResults = <Future<BuildResult>>[];

  for (final chunk in chunks) {
    final future = Isolate.run<BuildResult>(() async {
      final chunkOutputs = HashMap<Asset, Set<Uri>>();
      final chunkErrors = <FieldAsset>[];
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
          chunkErrors.add(FieldAsset(entry.asset, e));
        }
      }
      return BuildResult(chunkOutputs, chunkErrors);
    });
    outputResults.add(future);
  }

  final allResults = BuildResult.empty();
  for (final result in await Future.wait(outputResults)) {
    allResults.append(result);
  }
  return allResults;
}
