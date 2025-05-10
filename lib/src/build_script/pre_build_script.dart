import 'dart:isolate' show SendPort;

import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/build_script/build_script.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/references_scan_manager.dart' show ProcessableAsset, ReferencesScanManager;
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/source_parser.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/runner/command/utils.dart';

Future<void> main(List<String> args, SendPort? port) async {
  try {
    final Stopwatch stopWatch = Stopwatch()..start();
    final PackageFileResolver fileResolver = PackageFileResolver.forRoot();
    final AssetsGraph graph = AssetsGraph.init(fileResolver.packagesHash);
    final ReferencesScanManager scanManager = ReferencesScanManager(
      assetsGraph: graph,
      fileResolver: fileResolver,
      rootPackage: fileResolver.rootPackage,
    );
    Logger.info('Syncing assets graph...');
    await scanManager.scanAssets();
    Logger.info("Assets graph synced in ${stopWatch.elapsed.formattedMS}.");
    final Set<ProcessableAsset> builderAssets = graph.getBuilderProcessableAssets(fileResolver);
    final ResolverImpl resolver = ResolverImpl(graph, fileResolver, SourceParser());
    final String? scriptPath = prepareBuildScript(builderAssets, resolver);
    await graph.save();

    if (scriptPath == null) {
      Logger.error('No build script generated. existing.');
      port?.send(1);
    }
    port?.send(graph.hasProcessableAssets() ? 0 : 2);
  } catch (e, stack) {
    Logger.error('Error: $e', stackTrace: stack);
    port?.send(1);
  }
}
