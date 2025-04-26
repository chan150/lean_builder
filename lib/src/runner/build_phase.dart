import 'dart:collection';
import 'dart:isolate';

import 'package:lean_builder/builder.dart' show BuildCandidate, Resolver;
import 'package:lean_builder/runner.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/isolate_symbols_scanner.dart';
import 'package:lean_builder/src/graph/symbols_scanner.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/runner/build_utils.dart';

import 'build_result.dart';

class BuildPhase {
  final AssetsGraph assetsGraph;
  final PackageFileResolver fileResolver;
  final List<BuilderEntry> builders;

  BuildPhase(this.assetsGraph, this.fileResolver, this.builders);

  Future<PhaseResult> build(List<ProcessableAsset> assets) async {
    for (final entry in assets) {
      print('${entry.asset.uri} -> ${entry.state}');
    }
    Logger.debug('Running build phase for $builders, assets count: ${assets.length}');
    final chunks = calculateChunks(assets);
    final chunkResults = <Future<BuildResult>>[];

    for (final chunk in chunks) {
      final future = Isolate.run<BuildResult>(() async {
        final chunkOutputs = HashMap<Asset, Set<Uri>>();
        final chunkErrors = <FieldAsset>[];
        final chunkResolver = Resolver(assetsGraph, fileResolver, SourceParser());
        for (final entry in chunk) {
          // delete outputs of this asset
          final outputs = assetsGraph.outputs[entry.asset.id];
          if (outputs != null) {
            for (final output in outputs) {
              final outputUri = assetsGraph.uriForAssetOrNull(output);
              if (outputUri == null) continue;
              final outputAsset = fileResolver.assetForUri(outputUri);
              assetsGraph.outputs.remove(entry.asset.id);
              outputAsset.safeDelete();
            }
          }

          if (entry.state == AssetState.deleted) {
            continue;
          }

          try {
            final candidate = BuildCandidate(
              entry.asset,
              entry.hasTopLevelMetadata,
              assetsGraph.exportedSymbolsOf(entry.asset.id),
            );

            for (final builderEntry in builders) {
              if (!builderEntry.shouldGenerateFor(candidate)) continue;
              final generatedOutputs = await builderEntry.build(chunkResolver, entry.asset);
              chunkOutputs.putIfAbsent(entry.asset, () => <Uri>{}).addAll(generatedOutputs);
            }
          } catch (e) {
            chunkErrors.add(FieldAsset(entry.asset, e));
          }
        }
        return BuildResult(chunkOutputs, chunkErrors);
      });
      chunkResults.add(future);
    }

    final phaseOutputs = HashMap<Asset, Set<Uri>>();
    final failedAssets = <FieldAsset>[];
    for (final result in await Future.wait(chunkResults)) {
      phaseOutputs.addAll(result.outputs);
      failedAssets.addAll(result.fieldAssets);
    }
    return PhaseResult(await _finalizeBuild(phaseOutputs), failedAssets);
  }

  Future<List<ProcessableAsset>> _finalizeBuild(Map<Asset, Set<Uri>> outputs) async {
    final scanner = SymbolsScanner(assetsGraph, fileResolver);
    final outputAssets = <ProcessableAsset>[];
    for (final entry in outputs.entries) {
      for (final uri in entry.value) {
        final output = fileResolver.assetForUri(uri);
        assetsGraph.invalidateDigest(output.id);
        final (didScan, hasTLM) = scanner.scan(output);
        if (didScan) {
          outputAssets.add(ProcessableAsset(output, AssetState.inserted, hasTLM));
        }
        assetsGraph.addOutput(entry.key, output);
      }
    }
    return outputAssets;
  }
}
