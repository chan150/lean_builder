import 'dart:io';

import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/build_script/build_script.dart';
import 'package:lean_builder/src/graph/asset_scan_manager.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/runner/command/utils.dart';
import 'package:lean_builder/src/utils.dart';

Future<void> main(List<String> args) async {
  try {
    final stopWatch = Stopwatch()..start();
    final fileResolver = PackageFileResolver.forRoot();
    final AssetsGraph graph = AssetsGraph.init(fileResolver.packagesHash);
    final scanManager = AssetScanManager(assetsGraph: graph, fileResolver: fileResolver, rootPackage: rootPackageName);

    Logger.info('Syncing assets graph...');
    await scanManager.scanAssets();
    Logger.info("Assets graph synced in ${stopWatch.elapsed.formattedMS}.");
    final builderAssets = graph.getBuilderProcessableAssets(fileResolver);
    final resolver = ResolverImpl(graph, fileResolver, SourceParser());
    final scriptPath = prepareBuildScript(builderAssets, resolver);
    await graph.save();

    if (scriptPath == null) {
      Logger.error('No build script generated. existing.');
      exit(1);
    }
    exit(graph.hasProcessableAssets() ? 0 : 2);
  } catch (e, stack) {
    Logger.error('Error: $e', stackTrace: stack);
    exit(1);
  }
}
