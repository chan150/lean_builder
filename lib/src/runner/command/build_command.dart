import 'dart:async';

import 'package:lean_builder/runner.dart' show BuilderEntry;
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/references_scan_manager.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/source_parser.dart';
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/runner/build_phase.dart' show BuildPhase;
import 'package:lean_builder/src/runner/build_result.dart';
import 'package:lean_builder/src/runner/build_utils.dart';
import 'package:lean_builder/src/runner/command/base_command.dart';
import 'package:lean_builder/src/runner/command/utils.dart';

import 'lean_command_runner.dart';

class BuildCommand extends BaseCommand<int> {
  @override
  String get name => 'build';

  @override
  String get description => 'Executes a one time build.';

  @override
  String get invocation => 'lean_builder build [options]';

  LeanCommandRunner get buildRunner => runner as LeanCommandRunner;

  bool get isDevMode => argResults?['dev'] == true;

  @override
  Future<int>? run() async {
    prepare();
    return runZoned(() {
      final PackageFileResolver fileResolver = PackageFileResolver.forRoot();
      AssetsGraph assetsGraph = AssetsGraph.init(fileResolver.packagesHash);

      if (assetsGraph.shouldInvalidate) {
        Logger.info('Cache is invalidated, deleting old outputs...');
        _deleteExistingOutputs(assetsGraph, fileResolver);
        assetsGraph = AssetsGraph(assetsGraph.hash);
      }
      if (isDevMode) {
        assetsGraph.invalidateProcessedAssetsOf(fileResolver.rootPackage);
      }

      final sourceParser = SourceParser();
      final ResolverImpl resolver = ResolverImpl(assetsGraph, fileResolver, sourceParser);
      final Set<ProcessableAsset> assets = assetsGraph.getProcessableAssets(fileResolver);
      return onRun(assets, resolver);
    }, zoneValues: <Object?, Object?>{#isDevMode: isDevMode});
  }

  Future<int> onRun(Set<ProcessableAsset> assets, ResolverImpl resolver) async {
    return processAssets(assets, resolver);
  }

  Future<int> processAssets(Set<ProcessableAsset> assets, ResolverImpl resolver) async {
    final Stopwatch stopWatch = Stopwatch()..start();

    for (final ProcessableAsset entry in assets) {
      /// assume assets reaching this point are processed,
      /// if something goes wrong, we revert back to unprocessed
      if (entry.state != AssetState.deleted) {
        resolver.graph.updateAssetState(entry.asset.id, AssetState.processed);
      }
    }

    final List<ProcessableAsset> rootAssets = List.of(
      assets.where((ProcessableAsset e) {
        final Asset asset = e.asset;
        return asset.packageName == resolver.fileResolver.rootPackage;
      }),
    );

    if (rootAssets.isEmpty) {
      Logger.success('Build succeeded with no outputs ${stopWatch.elapsed.formattedMS}');
      return 0;
    }

    validateBuilderEntries(buildRunner.builderEntries);

    try {
      final int outputCount = await build(assets: rootAssets, builders: buildRunner.builderEntries, resolver: resolver);
      await resolver.graph.save();
      Logger.success('Build succeeded in ${stopWatch.elapsed.formattedMS}, with ($outputCount) outputs');
      return 0;
    } catch (e, stk) {
      await resolver.graph.save();
      if (e is MultiFailedAssetsException) {
        for (final FailedAsset failure in e.assets) {
          Logger.error(failure.error.toString(), stackTrace: failure.stackTrace ?? stk);
        }
      } else {
        Logger.error(e.toString(), stackTrace: stk);
      }
      return 1;
    }
  }

  void _deleteExistingOutputs(AssetsGraph assetsGraph, PackageFileResolver fileResolver) {
    for (final MapEntry<String, Set<String>> entry in List.of(assetsGraph.outputs.entries)) {
      assetsGraph.updateAssetState(entry.key, AssetState.unProcessed);
      for (final String output in entry.value) {
        final Uri? outputUri = assetsGraph.uriForAssetOrNull(output);
        if (outputUri == null) continue;
        assetsGraph.removeAsset(output);
        final Asset outputAsset = fileResolver.assetForUri(outputUri);
        outputAsset.safeDelete();
      }
    }
  }

  Future<int> build({
    required List<ProcessableAsset> assets,
    required List<BuilderEntry> builders,
    required ResolverImpl resolver,
  }) async {
    assert(assets.isNotEmpty);

    final PackageFileResolver fileResolver = resolver.fileResolver;
    final AssetsGraph graph = resolver.graph;

    final Iterable<String> allOutputExtensions = builders.expand((BuilderEntry e) => e.outputExtensions);

    for (final ProcessableAsset entry in List.of(assets)) {
      // handle deleted assets
      if (entry.state == AssetState.deleted) {
        graph.removeAsset(entry.asset.id);
        assets.remove(entry);
      }

      final Set<String>? outputs = graph.outputs[entry.asset.id];
      if (outputs != null) {
        for (final String output in outputs) {
          final Uri? outputUri = graph.uriForAssetOrNull(output);
          if (outputUri == null) continue;
          if (!allOutputExtensions.any((String e) => outputUri.path.endsWith(e))) {
            // this output is not generated by any builder, so we need to delete it now
            graph.removeAsset(output);
            assets.removeWhere((ProcessableAsset entry) => entry.asset.id == output);
            fileResolver.assetForUri(outputUri).safeDelete();
          }
        }
      }
    }

    if (assets.isEmpty) return 0;

    int outputCount = 0;
    final List<List<BuilderEntry>> phases = calculateBuilderPhases(builders);
    final Set<ProcessableAsset> assetsToProcess = Set.of(assets);
    for (int i = 0; i < phases.length; i++) {
      final List<BuilderEntry> phase = phases[i];
      final BuildPhase buildPhase = BuildPhase(resolver, phase);
      buildPhase.beforeBuild(resolver, assets);
      final PhaseResult result = await buildPhase.build(assetsToProcess);
      if (result.hasErrors) {
        for (final FailedAsset entry in result.failedAssets) {
          graph.updateAssetState(entry.asset.id, AssetState.unProcessed);
        }
        // todo: decide if we should throw here, all or just first
        throw MultiFailedAssetsException(result.failedAssets.take(1).toList());
      }

      outputCount += result.outputs.length;
      if (result.containsAnyChanges) {
        final List<BuilderEntry>? nextPhase = i + 1 < phases.length ? phases[i + 1] : null;
        if (nextPhase != null) {
          for (final BuilderEntry builder in phase) {
            // skip if this builder did not do anything
            if (!result.containsChangesFromBuilder(builder)) continue;

            for (final BuilderEntry nextBuilder in nextPhase) {
              if (builder.applies.contains(nextBuilder.key)) {
                final List<ScannedAsset> packageAssets = graph.getAssetsForPackage(fileResolver.rootPackage);
                for (final ScannedAsset asset in packageAssets) {
                  if (nextBuilder.outputExtensions.any((String e) => asset.uri.path.endsWith(e))) {
                    final String? srcGenerator = graph.getGeneratorOfOutput(asset.id);
                    if (srcGenerator != null) {
                      // mark the source as unprocessed to force the next phase to reprocess it
                      graph.updateAssetState(srcGenerator, AssetState.unProcessed);
                    }
                  }
                }
              }
            }
          }
        }
      }
      // add new outputs to the assets to be processed by the next phase
      final Set<ProcessableAsset> newAssets = graph.getProcessableAssets(fileResolver);
      assetsToProcess.addAll(newAssets);
      // we assume that the new assets will be processed in the next phase
      // if something goes wrong, we revert back to unprocessed
      for (final ProcessableAsset entry in newAssets) {
        if (entry.state != AssetState.deleted) {
          graph.updateAssetState(entry.asset.id, AssetState.processed);
        }
      }
    }
    return outputCount;
  }
}
