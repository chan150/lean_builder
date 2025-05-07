import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:lean_builder/builder.dart' show BuildCandidate;
import 'package:lean_builder/runner.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/asset_scan_manager.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/assets_scanner.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/resolver.dart' show ResolverImpl;
import 'package:lean_builder/src/runner/build_utils.dart';
import 'package:path/path.dart' as p;

import 'build_result.dart';

class BuildPhase {
  final ResolverImpl resolver;
  final List<BuilderEntry> builders;

  BuildPhase(this.resolver, this.builders);

  final Set<String> _oldOutputs = {};

  AssetsGraph get graph => resolver.graph;

  PackageFileResolver get fileResolver => resolver.fileResolver;

  void beforeBuild(ResolverImpl resolver, List<ProcessableAsset> assets) {
    final outputExtensions = HashSet<String>();
    for (final builder in builders) {
      // some builder entries need to do stuff before the build
      builder.onPrepare(resolver);
      outputExtensions.addAll(builder.outputExtensions);
    }

    for (final entry in List.of(assets)) {
      final outputs = graph.outputs[entry.asset.id];
      if (outputs != null) {
        for (final output in outputs) {
          final outputUri = graph.uriForAssetOrNull(output);
          if (outputUri == null) continue;
          if (outputExtensions.any((e) => outputUri.path.endsWith(e))) {
            _oldOutputs.add(output);
            assets.removeWhere((entry) => entry.asset.id == output);
          }
        }
      }
    }
  }

  Future<PhaseResult> build(Set<ProcessableAsset> assets) async {
    Logger.debug('Running build phase for $builders, assets count: ${assets.length}');

    if (assets.length < 15) {
      final result = await _buildChunk(assets);
      return _finalizePhase(result.outputs, result.faildAssets);
    }

    final chunks = calculateChunks(assets);
    final chunkResults = <Future<BuildResult>>[];
    for (final chunk in chunks) {
      final future = Isolate.run<BuildResult>(() {
        return _buildChunk(chunk);
      });
      chunkResults.add(future);
    }

    final phaseOutputs = HashMap<Asset, Set<Uri>>();
    final failedAssets = <FailedAsset>[];
    for (final result in await Future.wait(chunkResults)) {
      phaseOutputs.addAll(result.outputs);
      failedAssets.addAll(result.faildAssets);
    }

    return _finalizePhase(phaseOutputs, failedAssets);
  }

  PhaseResult _finalizePhase(Map<Asset, Set<Uri>> outputs, List<FailedAsset> failedAssets) {
    final scanner = AssetsScanner(resolver.graph, resolver.fileResolver);
    final outputUris = <Uri>{};
    for (final entry in outputs.entries) {
      for (final uri in entry.value) {
        final output = resolver.fileResolver.assetForUri(uri);
        // if the output is a dart file, we need to scan it before the next phase
        if (p.extension(uri.path) == '.dart') {
          scanner.scan(output, forceOverride: true);
        }
        resolver.graph.addOutput(entry.key, output);
        outputUris.add(uri);
      }
    }
    final deletedOutputs = _cleanUp(outputUris);
    return PhaseResult(outputs: outputUris, failedAssets: failedAssets, deletedOutputs: deletedOutputs);
  }

  Set<Uri> _cleanUp(Set<Uri> outputUris) {
    final deletedOutputs = <Uri>{};
    for (final oldOutput in _oldOutputs) {
      final oldOutputUri = graph.uriForAssetOrNull(oldOutput);
      if (oldOutputUri == null) continue;
      final fileOutputUri = fileResolver.resolveFileUri(oldOutputUri);
      if (!outputUris.contains(fileOutputUri)) {
        deletedOutputs.add(fileOutputUri);
        final file = File.fromUri(fileOutputUri);
        if (file.existsSync()) {
          file.deleteSync();
        }
        graph.removeOutput(oldOutput);
      }
    }
    _oldOutputs.clear();
    return deletedOutputs;
  }

  Future<BuildResult> _buildChunk(Set<ProcessableAsset> chunk) async {
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
}
