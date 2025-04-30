import 'dart:collection';
import 'dart:io';

import 'package:lean_builder/builder.dart';
import 'package:lean_builder/runner.dart' show BuilderEntry;
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/asset_scan_manager.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/runner/build_phase.dart' show BuildPhase;
import 'package:lean_builder/src/runner/build_result.dart';
import 'package:lean_builder/src/runner/build_utils.dart';
import 'package:lean_builder/src/runner/command/base_command.dart';
import 'package:lean_builder/src/runner/command/utils.dart';
import 'package:lean_builder/src/utils.dart';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;

import 'lean_command_runner.dart';

class BuildCommand extends BaseCommand<int> {
  @override
  String get name => 'build';

  @override
  String get description => 'Executes a one time build.';

  @override
  String get invocation => 'lean_builder build [options]';

  LeanCommandRunner get buildRunner => runner as LeanCommandRunner;

  @override
  Future<int>? run() async {
    prepare();
    final stopWatch = Stopwatch()..start();

    final fileResolver = PackageFileResolver.forRoot();
    var assetsGraph = AssetsGraph.init('${fileResolver.packagesHash}-${buildRunner.buildScriptHash}');

    if (assetsGraph.shouldInvalidate) {
      Logger.info('Cache is invalidated, deleting old outputs...');
      _deleteExistingOutputs(assetsGraph, fileResolver);
      assetsGraph = AssetsGraph(assetsGraph.hash);
    }
    if (argResults?['dev'] == true) {
      _deleteExistingOutputs(assetsGraph, fileResolver);
    }

    final scanManager = AssetScanManager(
      assetsGraph: assetsGraph,
      fileResolver: fileResolver,
      rootPackage: rootPackageName,
    );

    Logger.info('Syncing assets graph...');
    final assets = await scanManager.scanAssets(scanOnlyRoot: assetsGraph.loadedFromCache);
    Logger.info("Assets graph synced in ${stopWatch.elapsed.formattedMS}.");

    final sourceParser = SourceParser();
    final resolver = Resolver(assetsGraph, fileResolver, sourceParser);

    return processAssets(assets, resolver, scanManager);
  }

  Future<int> processAssets(Set<ProcessableAsset> assets, Resolver resolver, AssetScanManager scanManager) async {
    return _processAssets(assets, resolver);
  }

  Future<int> _processAssets(Set<ProcessableAsset> processableAssets, Resolver resolver) async {
    final stopWatch = Stopwatch()..start();

    final assets = List.of(
      processableAssets.where((e) {
        final asset = e.asset;
        return asset.packageName == resolver.fileResolver.rootPackage;
      }),
    );

    if (assets.isEmpty) {
      Logger.success('Build succeeded with no outputs ${stopWatch.elapsed.formattedMS}');
      return 0;
    }

    try {
      final outputCount = await build(assets: assets, builders: buildRunner.builderEntries, resolver: resolver);
      await resolver.graph.save();
      Logger.success('Build succeeded in ${stopWatch.elapsed.formattedMS}, with ($outputCount) outputs');
      return 0;
    } catch (e, stk) {
      await resolver.graph.save();
      if (e is MultiFieldAssetsException) {
        for (final failure in e.assets) {
          Logger.error(failure.error.toString(), stackTrace: failure.stackTrace ?? stk);
        }
      } else {
        Logger.error(e.toString(), stackTrace: stk);
      }
      return 1;
    }
  }

  void _deleteExistingOutputs(AssetsGraph assetsGraph, PackageFileResolver fileResolver) {
    for (final entry in List.of(assetsGraph.outputs.entries)) {
      for (final output in entry.value) {
        assetsGraph.removeAsset(entry.key);
        final outputUri = assetsGraph.uriForAssetOrNull(output);
        if (outputUri == null) continue;
        final outputAsset = fileResolver.assetForUri(outputUri);
        outputAsset.safeDelete();
      }
    }
  }

  Future<int> build({
    required List<ProcessableAsset> assets,
    required List<BuilderEntry> builders,
    required Resolver resolver,
  }) async {
    assert(assets.isNotEmpty);

    final fileResolver = resolver.fileResolver;
    final graph = resolver.graph;
    // delete existing outputs for all possible inputs
    final existingOutputs = <String>{};
    for (final entry in List.of(assets)) {
      final outputs = graph.outputs[entry.asset.id];
      if (outputs != null) {
        for (final output in outputs) {
          existingOutputs.add(output);
          assets.removeWhere((entry) => entry.asset.id == output);
        }
      }
      if (entry.state == AssetState.deleted) {
        assets.remove(entry);
      }
    }

    if (assets.isEmpty) {
      return 0;
    }

    int outputCount = 0;
    final phases = calculateBuilderPhases(builders);
    final assetsToProcess = List.of(assets);
    for (final phase in phases) {
      final buildPhase = BuildPhase(resolver, phase);
      final result = await buildPhase.build(assetsToProcess);
      if (result.hasErrors) {
        for (final asset in result.failedAssets) {
          graph.invalidateDigest(asset.asset.id);
        }
        throw MultiFieldAssetsException(result.failedAssets);
      }
      final outputUris = result.outputs.map((e) => e.asset.shortUri);
      for (final output in existingOutputs) {
        final outputUri = graph.uriForAssetOrNull(output);
        if (outputUri == null) continue;
        if (!outputUris.contains(outputUri)) {
          final file = File.fromUri(fileResolver.resolveFileUri(outputUri));
          if (file.existsSync()) {
            file.deleteSync();
          }
          graph.removeOutput(output);
        }
      }

      outputCount += result.outputs.length;

      /// add new outputs to the assets to process
      assetsToProcess.addAll(result.outputs);
    }
    return outputCount;
  }
}

class WatchCommand extends BuildCommand {
  @override
  String get name => 'watch';

  @override
  String get description => 'Executes a build and watches for changes.';

  @override
  String get invocation => 'lean_builder watch [options]';

  @override
  Future<int> processAssets(Set<ProcessableAsset> assets, Resolver resolver, AssetScanManager scanManager) async {
    await _processAssets(assets, resolver);

    final fileResolver = resolver.fileResolver;
    final assetsGraph = resolver.graph;
    final rootDir = fileResolver.pathFor(fileResolver.rootPackage);
    final rootUri = Uri.parse(rootDir);

    final watchStream = DirectoryWatcher(rootUri.path).events;
    final pendingAssets = <ProcessableAsset>{};
    final debouncer = Debouncer(const Duration(milliseconds: 150));
    watchStream.listen((event) async {
      final relative = p.relative(event.path, from: rootUri.path);
      final subDir = relative.split('/').firstOrNull;
      if (!PackageFileResolver.isDirSupported(subDir)) return;
      final asset = fileResolver.assetForUri(Uri.file(event.path));

      if (assetsGraph.isAGeneratedSource(asset.id) && event.type != ChangeType.REMOVE) {
        // ignore generated sources changes
        return;
      }

      resolver.invalidateAssetCache(asset);
      switch (event.type) {
        case ChangeType.ADD:
          pendingAssets.add(scanManager.handleInsertedAsset(asset));

          break;
        case ChangeType.REMOVE:
          pendingAssets.addAll(scanManager.handleDeletedAsset(asset));
          break;
        case ChangeType.MODIFY:
          pendingAssets.addAll(scanManager.handleUpdatedAsset(asset));

          break;
      }

      debouncer.run(() async {
        if (pendingAssets.isEmpty) return;
        final assetsToProcess = Set.of(pendingAssets);
        pendingAssets.clear();
        Logger.info('Starting build for ${assetsToProcess.length} effected assets');
        await _processAssets(assetsToProcess, resolver);
      });
    });
    return 0;
  }
}
