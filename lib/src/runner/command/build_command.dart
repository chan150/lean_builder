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
import 'package:lean_builder/src/utils.dart';
import 'package:synchronized/synchronized.dart';
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
  Future<int> run() async {
    final stopWatch = Stopwatch()..start();

    final fileResolver = PackageFileResolver.forRoot();
    var assetsGraph = AssetsGraph.init('${fileResolver.packagesHash}-${buildRunner.buildScriptHash}');

    // if (assetsGraph.shouldInvalidate) {
    //   Logger.info('Cache is invalidated, deleting old outputs...');
    //   _deleteExistingOutputs(assetsGraph, fileResolver);
    //   assetsGraph = AssetsGraph(assetsGraph.hash);
    // }
    // if (argResults?['dev'] == true) {
    //   _deleteExistingOutputs(assetsGraph, fileResolver);
    // }

    final scanManager = AssetScanManager(
      assetsGraph: assetsGraph,
      fileResolver: fileResolver,
      rootPackage: rootPackageName,
    );

    Logger.info('Scanning assets...');
    final assets = await scanManager.scanAssets(scanOnlyRoot: assetsGraph.loadedFromCache);
    Logger.info('Finished scanning assets in: ${stopWatch.elapsed.inMilliseconds} ms');

    final sourceParser = SourceParser();
    final resolver = Resolver(assetsGraph, fileResolver, sourceParser);

    return processAssets(assets, resolver, scanManager);
  }

  Future<int> processAssets(Set<ProcessableAsset> assets, Resolver resolver, AssetScanManager scanManager) async {
    return _processAssets(assets, resolver);
  }

  Future<int> _processAssets(Set<ProcessableAsset> processableAssets, Resolver resolver) async {
    final stopWatch = Stopwatch()..start();
    if (processableAssets.isEmpty) {
      Logger.success('No assets to process, took ${stopWatch.elapsed.inMilliseconds} ms');
      return 0;
    }

    final assets = List.of(
      processableAssets.where((e) {
        final asset = e.asset;
        return asset.packageName == resolver.fileResolver.rootPackage;
      }),
    );

    if (assets.isEmpty) {
      Logger.success('Done with (0) outputs, took ${stopWatch.elapsed.inMilliseconds} ms');
      return 0;
    }

    try {
      final outputCount = await build(assets: assets, builders: buildRunner.builderEntries, resolver: resolver);
      await resolver.graph.save();
      Logger.success('Done with ($outputCount) outputs, took ${stopWatch.elapsed.inMilliseconds} ms');
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
    for (final entry in assetsGraph.outputs.entries) {
      for (final output in entry.value) {
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

    // delete existing outputs for all possible inputs
    for (final entry in List.of(assets)) {
      final outputs = resolver.graph.outputs.remove(entry.asset.id);
      if (outputs != null) {
        for (final output in outputs) {
          final outputUri = resolver.graph.uriForAssetOrNull(output);
          if (outputUri == null) continue;
          final outputAsset = resolver.fileResolver.assetForUri(outputUri);
          outputAsset.safeDelete();
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
          resolver.graph.invalidateDigest(asset.asset.id);
        }
        throw MultiFieldAssetsException(result.failedAssets);
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
    final watchLock = Lock();

    watchStream.listen((event) async {
      return watchLock.synchronized(() async {
        final relative = p.relative(event.path, from: rootUri.path);
        final subDir = relative.split('/').firstOrNull;
        if (!PackageFileResolver.isDirSupported(subDir)) return;
        final asset = fileResolver.assetForUri(Uri.file(event.path));
        resolver.invalidateAssetCache(asset);

        if (assetsGraph.isAGeneratedSource(asset.id) && event.type != ChangeType.REMOVE) {
          // skip generated sources, unless they are deleted
          return;
        }

        final assetsToProcess = <ProcessableAsset>{};
        switch (event.type) {
          case ChangeType.ADD:
            assetsToProcess.add(scanManager.handleInsertedAsset(asset));
            break;
          case ChangeType.REMOVE:
            assetsToProcess.addAll(scanManager.handleDeletedAsset(asset));
            break;
          case ChangeType.MODIFY:
            assetsToProcess.addAll(scanManager.handleUpdatedAsset(asset));
            break;
        }
        if (assetsToProcess.isEmpty) return;

        Logger.info('Detected changes in ${asset.shortUri}, processing...');
        await _processAssets(assetsToProcess, resolver);
      });
    });
    Logger.info('Watching for changes in ${rootUri.path}...');
    return 0;
  }
}
