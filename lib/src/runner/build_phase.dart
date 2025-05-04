import 'dart:collection';
import 'dart:isolate';

import 'package:lean_builder/builder.dart' show BuildCandidate, Resolver;
import 'package:lean_builder/runner.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/graph/asset_scan_manager.dart';
import 'package:lean_builder/src/graph/assets_scanner.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/runner/build_utils.dart';

import 'build_result.dart';

class BuildPhase {
  final Resolver resolver;
  final List<BuilderEntry> builders;

  BuildPhase(this.resolver, this.builders);

  Future<PhaseResult> build(List<ProcessableAsset> assets) async {
    Logger.debug('Running build phase for $builders, assets count: ${assets.length}');

    if (assets.length < 15) {
      final result = await _buildChunk(assets);
      return PhaseResult(await _finalizePhase(result.outputs), result.fieldAssets);
    }

    final chunks = calculateChunks(assets);
    final chunkResults = <Future<BuildResult>>[];
    for (final chunk in chunks) {
      final future = Isolate.run<BuildResult>(() async {
        return _buildChunk(chunk);
      });
      chunkResults.add(future);
    }

    final phaseOutputs = HashMap<Asset, Set<Uri>>();
    final failedAssets = <FailedAsset>[];
    for (final result in await Future.wait(chunkResults)) {
      phaseOutputs.addAll(result.outputs);
      failedAssets.addAll(result.fieldAssets);
    }
    return PhaseResult(await _finalizePhase(phaseOutputs), failedAssets);
  }

  Future<BuildResult> _buildChunk(List<ProcessableAsset> chunk) async {
    final chunkOutputs = HashMap<Asset, Set<Uri>>();
    final chunkErrors = <FailedAsset>[];
    for (final entry in chunk) {
      try {
        final candidate = BuildCandidate(
          entry.asset,
          entry.tlmFlag.hasNormal,
          resolver.graph.exportedSymbolsOf(entry.asset.id),
        );
        for (final builderEntry in builders) {
          if (!builderEntry.shouldGenerateFor(candidate)) continue;
          final generatedOutputs = await builderEntry.build(resolver, entry.asset);
          chunkOutputs.putIfAbsent(entry.asset, () => <Uri>{}).addAll(generatedOutputs);
        }
      } catch (e, stack) {
        chunkErrors.add(FailedAsset(entry.asset, e, stack));
      }
    }
    return BuildResult(chunkOutputs, chunkErrors);
  }

  Future<List<Uri>> _finalizePhase(Map<Asset, Set<Uri>> outputs) async {
    final scanner = AssetsScanner(resolver.graph, resolver.fileResolver);
    final outputAssets = <Uri>[];
    for (final entry in outputs.entries) {
      for (final uri in entry.value) {
        final output = resolver.fileResolver.assetForUri(uri);
        scanner.scan(output, forceOverride: true);
        resolver.graph.addOutput(entry.key, output);
        outputAssets.add(uri);
      }
    }
    return outputAssets;
  }
}
