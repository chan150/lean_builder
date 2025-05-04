import 'dart:io';

import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/build_script/build_script.dart';
import 'package:lean_builder/src/graph/asset_scan_manager.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/runner/command/utils.dart';
import 'package:lean_builder/src/utils.dart';

Future<void> main(List<String> args) async {
  try {
    final scriptPath = prepareBuildScript();
    if (scriptPath == null) {
      Logger.info('No valid build script found. Exiting.');
      exit(2);
    }
    final stopWatch = Stopwatch()..start();
    final fileResolver = PackageFileResolver.forRoot();
    final AssetsGraph graph = AssetsGraph.init(fileResolver.packagesHash);
    final scanManager = AssetScanManager(assetsGraph: graph, fileResolver: fileResolver, rootPackage: rootPackageName);

    Logger.info('Syncing assets graph...');
    await scanManager.scanAssets();
    await graph.save();
    Logger.info("Assets graph synced in ${stopWatch.elapsed.formattedMS}.");
    exit(graph.hasProcessableAssets() ? 0 : 2);
  } catch (e, stack) {
    Logger.error('Error: $e', stackTrace: stack);
    exit(1);
  }
}
