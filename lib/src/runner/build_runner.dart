import 'dart:io';
import 'package:args/args.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/isolate_symbols_scanner.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/runner/build_phase.dart';
import 'package:lean_builder/src/runner/build_utils.dart';
import 'package:lean_builder/src/runner/builder_entry.dart';
import 'package:lean_builder/src/utils.dart';

Future<void> runBuilders(List<BuilderEntry> builders, List<String> args) async {
  final stopWatch = Stopwatch()..start();

  final fileResolver = PackageFileResolver.forRoot();
  final assetsGraph = AssetsGraph.init(fileResolver.packagesHash);

  final argResults = _parseArgs(args);

  final isDevMode = argResults['dev'] as bool;

  final assets = await scanPackageAssets(
    rootPackageName: rootPackageName,
    assetsGraph: assetsGraph,
    fileResolver: fileResolver,
  );

  if (isDevMode) {
    // invalidate all generated files
    for (final input in assetsGraph.outputs.keys) {
      final uri = assetsGraph.uriForAssetOrNull(input);
      if (uri == null) continue;
      final inputAsset = fileResolver.assetForUri(uri);
      assets.add(ProcessableAsset(inputAsset, AssetState.needUpdate, true));
    }
  }

  if (assets.isEmpty) {
    Logger.success('No assets to process');
    return;
  }

  try {
    final outputCount = await build(
      assets: assets,
      builders: builders,
      assetsGraph: assetsGraph,
      fileResolver: fileResolver,
    );
    await assetsGraph.save();
    Logger.success('Done with ($outputCount) outputs, took ${stopWatch.elapsed.inMilliseconds} ms');
  } catch (e) {
    await assetsGraph.save();
    Logger.error('Error while building assets: $e');
    rethrow;
  }
}

ArgResults _parseArgs(List<String> args) {
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
  return argResults;
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

Future<int> build({
  required List<ProcessableAsset> assets,
  required List<BuilderEntry> builders,
  required AssetsGraph assetsGraph,
  required PackageFileResolver fileResolver,
}) async {
  assert(assets.isNotEmpty);

  int outputCount = 0;
  final phases = calculateBuilderPhases(builders);
  print('Running build phases: phases, ${phases.length}, assets: ${assets.length}');
  final assetsToProcess = List.of(assets);

  for (final phase in phases) {
    final buildPhase = BuildPhase(assetsGraph, fileResolver, phase);
    final result = await buildPhase.build(assetsToProcess);
    if (result.hasErrors) {
      final errorMessages = [];
      for (final asset in result.failedAssets) {
        assetsGraph.invalidateDigest(asset.asset.id);
        errorMessages.add('${asset.error} while processing: ${asset.asset.shortUri}\n');
      }
      throw Exception('Errors while building assets:\n$errorMessages');
    }
    outputCount += result.outputs.length;

    /// update the target assets with the outputs of this phase
    assetsToProcess.addAll(result.outputs);
  }
  return outputCount;
}
