import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/references_scan_manager.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';

import 'build_command.dart';
import 'package:watcher/watcher.dart' show WatchEvent, ChangeType, DirectoryWatcher;
import 'package:path/path.dart' as p show relative;
import 'package:hotreloader/hotreloader.dart' show HotReloader, AfterReloadContext;
import 'dart:async' show StreamSubscription;
import 'dart:io' show ProcessSignal, exit;

import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/runner/command/utils.dart';

/// {@template watch_command}
/// A command that executes a build and then watches for changes.
///
/// The watch command:
/// 1. Performs an initial build (using [BuildCommand])
/// 2. Sets up file system watchers to detect changes
/// 3. Re-runs builders incrementally when files change
/// 4. Optionally supports hot reloading in development mode
///
/// This command is ideal for development workflows, as it automatically
/// regenerates code as you modify your source files.
/// {@endtemplate}
class WatchCommand extends BuildCommand {
  /// {@template watch_command.name}
  /// The name of the command, used to invoke it from the command line.
  ///
  /// This command is invoked as `lean_builder watch`.
  /// {@endtemplate}
  @override
  String get name => 'watch';

  /// {@template watch_command.description}
  /// A description of what the watch command does.
  ///
  /// This appears in the help text when running `lean_builder --help`.
  /// {@endtemplate}
  @override
  String get description => 'Executes a build and watches for changes.';

  /// {@template watch_command.invocation}
  /// The invocation pattern for this command.
  ///
  /// This appears in the help text to show users how to run the command.
  /// {@endtemplate}
  @override
  String get invocation => 'lean_builder watch [options]';

  /// {@template watch_command.on_run}
  /// Executes the initial build and then sets up file watchers.
  ///
  /// This method:
  /// 1. Runs the initial build using the parent class implementation
  /// 2. Sets up hot reloading if in development mode
  /// 3. Creates a file system watcher to monitor for changes
  /// 4. Handles file system events (add, modify, remove)
  /// 5. Debounces rapid file changes to avoid excessive rebuilds
  /// 6. Sets up signal handling to gracefully exit
  ///
  /// [assets] The set of assets to process in the initial build
  /// [resolver] The resolver to use for analyzing Dart code
  ///
  /// Returns an exit code (0 for success, non-zero for failure).
  /// {@endtemplate}
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
