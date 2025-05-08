import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/references_scan_manager.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';

import 'build_command.dart';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p show relative;
import 'package:hotreloader/hotreloader.dart' show HotReloader, AfterReloadContext;
import 'dart:async' show StreamSubscription;
import 'dart:collection';
import 'dart:io' show ProcessSignal, exit;

import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/runner/command/utils.dart';

class WatchCommand extends BuildCommand {
  @override
  String get name => 'watch';

  @override
  String get description => 'Executes a build and watches for changes.';

  @override
  String get invocation => 'lean_builder watch [options]';

  @override
  Future<int> onRun(Set<ProcessableAsset> assets, ResolverImpl resolver) async {
    HotReloader? hotReloader;
    await processAssets(assets, resolver);

    final PackageFileResolver fileResolver = resolver.fileResolver;
    final AssetsGraph graph = resolver.graph;

    if (isDevMode) {
      hotReloader = await HotReloader.create(
        automaticReload: false,
        debounceInterval: Duration.zero,
        onAfterReload: (AfterReloadContext ctx) async {
          Logger.info('Hot reload triggered');
          final Set<ProcessableAsset> builderConfigAssets = graph.getBuilderProcessableAssets(fileResolver);
          if (builderConfigAssets.any((ProcessableAsset e) => e.state != AssetState.processed)) {
            graph.invalidateProcessedAssetsOf(fileResolver.rootPackage);
            for (final ProcessableAsset entry in graph.getProcessableAssets(fileResolver)) {
              resolver.invalidateAssetCache(entry.asset);
            }
          }
          await processAssets(graph.getProcessableAssets(fileResolver), resolver);
        },
      );
    }

    final ReferencesScanManager scanManager = ReferencesScanManager(
      assetsGraph: graph,
      fileResolver: fileResolver,
      rootPackage: fileResolver.rootPackage,
    );

    final String rootDir = fileResolver.pathFor(fileResolver.rootPackage);
    final Uri rootUri = Uri.parse(rootDir);

    final Stream<WatchEvent> watchStream = DirectoryWatcher(rootUri.path).events;
    final Debouncer debouncer = Debouncer(const Duration(milliseconds: 150));
    final StreamSubscription<WatchEvent> watchSub = watchStream.listen((WatchEvent event) async {
      final String relative = p.relative(event.path, from: rootUri.path);
      final String? subDir = relative.split('/').firstOrNull;
      if (!PackageFileResolver.isDirSupported(subDir)) return;
      final Asset asset = fileResolver.assetForUri(Uri.file(event.path));

      if (graph.isAGeneratedSource(asset.id) && event.type != ChangeType.REMOVE) {
        // ignore generated sources changes
        return;
      }

      resolver.invalidateAssetCache(asset);
      switch (event.type) {
        case ChangeType.ADD:
          scanManager.handleInsertedAsset(asset);
          break;
        case ChangeType.REMOVE:
          scanManager.handleDeletedAsset(asset);
          break;
        case ChangeType.MODIFY:
          scanManager.handleUpdatedAsset(asset);
          break;
      }

      debouncer.run(() async {
        if (hotReloader != null) {
          // triggering a hot reload will process pending assets
          hotReloader.reloadCode();
        } else {
          final Set<ProcessableAsset> assetsToProcess = graph.getProcessableAssets(fileResolver);
          if (assetsToProcess.isEmpty) return;
          Logger.info('Starting build for ${assetsToProcess.length} effected assets');
          await processAssets(assetsToProcess, resolver);
        }
      });
    });

    StreamSubscription<ProcessSignal>? sigintSub;
    sigintSub = ProcessSignal.sigint.watch().listen((ProcessSignal signal) async {
      debouncer.cancel();
      await watchSub.cancel();
      await hotReloader?.stop();
      sigintSub?.cancel();
      exit(0);
    });
    return 0;
  }
}
