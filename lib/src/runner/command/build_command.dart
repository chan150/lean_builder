import 'dart:async';
import 'dart:io';

import 'package:lean_builder/builder.dart';
import 'package:lean_builder/runner.dart' show BuilderEntry;
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/asset_scan_manager.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
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

    final fileResolver = PackageFileResolver.forRoot();
    var assetsGraph = AssetsGraph.init(fileResolver.packagesHash);

    if (assetsGraph.shouldInvalidate) {
      Logger.info('Cache is invalidated, deleting old outputs...');
      _deleteExistingOutputs(assetsGraph, fileResolver);
      assetsGraph = AssetsGraph(assetsGraph.hash);
    }
    if (isDevMode) {
      _deleteExistingOutputs(assetsGraph, fileResolver);
    }

    final sourceParser = SourceParser();
    final resolver = Resolver(assetsGraph, fileResolver, sourceParser);
    final assets = assetsGraph.getProcessableAssets(fileResolver);
    return processAssets(assets, resolver);
  }

  Future<int> processAssets(Set<ProcessableAsset> assets, Resolver resolver) async {
    return processAssetsInternal(assets, resolver);
  }

  Future<int> processAssetsInternal(Set<ProcessableAsset> processableAssets, Resolver resolver) async {
    final stopWatch = Stopwatch()..start();

    for (final entry in processableAssets) {
      /// assume assets reaching this point are processed,
      /// if something goes wrong, we revert back to unprocessed
      resolver.graph.updateAssetState(entry.asset.id, AssetState.processed);
    }

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

    validateBuilderEntries(buildRunner.builderEntries);

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
      assetsGraph.updateAssetState(entry.key, AssetState.unProcessed);
      for (final output in entry.value) {
        final outputUri = assetsGraph.uriForAssetOrNull(output);
        if (outputUri == null) continue;
        assetsGraph.removeAsset(output);
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

    // handle deleted assets
    for (final entry in List.of(assets)) {
      if (entry.state == AssetState.deleted) {
        graph.removeAsset(entry.asset.id);
        assets.remove(entry);
      }
    }

    if (assets.isEmpty) {
      return 0;
    }

    final outputExtOfAllBuilders = <String>{};
    for (final builder in builders) {
      /// some builder entries might need to do some setup before the build
      builder.onPrepare(resolver);
      outputExtOfAllBuilders.addAll(builder.outputExtensions);
    }

    int outputCount = 0;
    final phases = calculateBuilderPhases(builders);
    final assetsToProcess = List.of(assets);
    for (var i = 0; i < phases.length; i++) {
      final phase = phases[i];
      final outputExtensionsOfPhase = phase.expand((e) => e.outputExtensions);
      final existingOutputs = <String>{};

      for (final entry in List.of(assets)) {
        final outputs = graph.outputs[entry.asset.id];
        if (outputs != null) {
          for (final output in outputs) {
            if (outputExtensionsOfPhase.any((e) => output.endsWith(e))) {
              existingOutputs.add(output);
              assets.removeWhere((entry) => entry.asset.id == output);
            } else if (!outputExtOfAllBuilders.any((e) => output.endsWith(e))) {
              // this output is not generated by any builder, so we need to delete it
              graph.removeAsset(output);
              assets.removeWhere((entry) => entry.asset.id == output);
              final outputUri = graph.uriForAssetOrNull(output);
              if (outputUri != null) {
                final outputAsset = fileResolver.assetForUri(outputUri);
                outputAsset.safeDelete();
              }
            }
          }
        }
      }

      final buildPhase = BuildPhase(resolver, phase);
      final result = await buildPhase.build(assetsToProcess);
      if (result.hasErrors) {
        for (final entry in result.failedAssets) {
          graph.updateAssetState(entry.asset.id, AssetState.unProcessed);
        }
        // todo: decide if we should throw here, all or first
        throw MultiFieldAssetsException(result.failedAssets.take(1).toList());
      }

      final outputUris = result.outputs;
      for (final output in existingOutputs) {
        final existingOutputUri = graph.uriForAssetOrNull(output);
        if (existingOutputUri == null) continue;
        final fileOutputUri = fileResolver.resolveFileUri(existingOutputUri);
        if (!outputUris.contains(fileOutputUri)) {
          final file = File.fromUri(fileOutputUri);
          if (file.existsSync()) {
            file.deleteSync();
          }
          graph.removeOutput(output);
        }
      }

      outputCount += result.outputs.length;
      if (result.outputs.isNotEmpty) {
        final nextPhase = i + 1 < phases.length ? phases[i + 1] : null;
        if (nextPhase != null) {
          for (final builder in phase) {
            // skip if this builder did not generate any outputs
            bool hasOutputs = false;
            for (final ext in builder.outputExtensions) {
              if (result.outputs.any((e) => e.path.endsWith(ext))) {
                hasOutputs = true;
                break;
              }
            }
            if (!hasOutputs) continue;

            for (final nextBuilder in nextPhase) {
              if (builder.applies.contains(nextBuilder.key)) {
                final packageAssets = graph.getAssetsForPackage(fileResolver.rootPackage);
                for (final asset in packageAssets) {
                  if (nextBuilder.outputExtensions.any((e) => asset.uri.path.endsWith(e))) {
                    final srcGenerator = graph.getGeneratorOfSource(asset.id);
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
      assetsToProcess.addAll(graph.getProcessableAssets(fileResolver));
    }
    return outputCount;
  }
}
