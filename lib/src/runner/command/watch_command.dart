import 'package:lean_builder/src/resolvers/resolver.dart';

import 'build_command.dart';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;
import 'package:hotreloader/hotreloader.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/asset_scan_manager.dart';
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

    if (isDevMode) {
      hotReloader = await HotReloader.create(
        automaticReload: false,
        debounceInterval: Duration.zero,
        onAfterReload: (ctx) async {
          Logger.info('Hot reload triggered');
          await processAssets(assets, resolver);
        },
      );
    }

    final fileResolver = resolver.fileResolver;
    final assetsGraph = resolver.graph;

    final scanManager = AssetScanManager(
      assetsGraph: assetsGraph,
      fileResolver: fileResolver,
      rootPackage: fileResolver.rootPackage,
    );

    final rootDir = fileResolver.pathFor(fileResolver.rootPackage);
    final rootUri = Uri.parse(rootDir);

    final watchStream = DirectoryWatcher(rootUri.path).events;
    final debouncer = Debouncer(const Duration(milliseconds: 150));
    final watchSub = watchStream.listen((event) async {
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
          final assetsToProcess = assetsGraph.getProcessableAssets(fileResolver);
          if (assetsToProcess.isEmpty) return;
          Logger.info('Starting build for ${assetsToProcess.length} effected assets');
          await processAssets(assetsToProcess, resolver);
        }
      });
    });

    StreamSubscription? sigintSub;
    sigintSub = ProcessSignal.sigint.watch().listen((signal) async {
      debouncer.cancel();
      await watchSub.cancel();
      await hotReloader?.stop();
      sigintSub?.cancel();
      exit(0);
    });
    return 0;
  }
}
