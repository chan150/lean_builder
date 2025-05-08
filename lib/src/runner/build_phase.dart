import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:lean_builder/builder.dart' show BuildCandidate;
import 'package:lean_builder/runner.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/references_scan_manager.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/resolver.dart' show ResolverImpl;
import 'package:lean_builder/src/runner/build_utils.dart';
import 'package:path/path.dart' as p;

import 'build_result.dart';

class BuildPhase {
  final ResolverImpl resolver;
  final List<BuilderEntry> builders;

  BuildPhase(this.resolver, this.builders);

  final Set<String> _oldOutputs = <String>{};

  AssetsGraph get graph => resolver.graph;

  PackageFileResolver get fileResolver => resolver.fileResolver;

  void beforeBuild(ResolverImpl resolver, List<ProcessableAsset> assets) {
    final HashSet<String> outputExtensions = HashSet<String>();
    for (final BuilderEntry builder in builders) {
      // some builder entries need to do stuff before the build
      builder.onPrepare(resolver);
      outputExtensions.addAll(builder.outputExtensions);
    }

    for (final ProcessableAsset entry in List.of(assets)) {
      final Set<String>? outputs = graph.outputs[entry.asset.id];
      if (outputs != null) {
        for (final String output in outputs) {
          final Uri? outputUri = graph.uriForAssetOrNull(output);
          if (outputUri == null) continue;
          if (outputExtensions.any((String e) => outputUri.path.endsWith(e))) {
            _oldOutputs.add(output);
            assets.removeWhere((ProcessableAsset entry) => entry.asset.id == output);
          }
        }
      }
    }
  }

  Future<PhaseResult> build(Set<ProcessableAsset> assets) async {
    Logger.debug('Running build phase for $builders, assets count: ${assets.length}');

    if (assets.length < 15) {
      final BuildResult result = await _buildChunk(assets);
      return _finalizePhase(result.outputs, result.faildAssets);
    }

    final List<Set<ProcessableAsset>> chunks = calculateChunks(assets);
    final List<Future<BuildResult>> chunkResults = <Future<BuildResult>>[];
    for (final Set<ProcessableAsset> chunk in chunks) {
      final Future<BuildResult> future = Isolate.run<BuildResult>(() {
        return _buildChunk(chunk);
      });
      chunkResults.add(future);
    }

    final HashMap<Asset, Set<Uri>> phaseOutputs = HashMap<Asset, Set<Uri>>();
    final List<FailedAsset> failedAssets = <FailedAsset>[];
    for (final BuildResult result in await Future.wait(chunkResults)) {
      phaseOutputs.addAll(result.outputs);
      failedAssets.addAll(result.faildAssets);
    }

    return _finalizePhase(phaseOutputs, failedAssets);
  }

  PhaseResult _finalizePhase(Map<Asset, Set<Uri>> outputs, List<FailedAsset> failedAssets) {
    final ReferencesScanner scanner = ReferencesScanner(resolver.graph, resolver.fileResolver);
    final Set<Uri> outputUris = <Uri>{};
    for (final MapEntry<Asset, Set<Uri>> entry in outputs.entries) {
      for (final Uri uri in entry.value) {
        final Asset output = resolver.fileResolver.assetForUri(uri);
        // if the output is a dart file, we need to scan it before the next phase
        if (p.extension(uri.path) == '.dart') {
          scanner.scan(output, forceOverride: true);
        }
        resolver.graph.addOutput(entry.key, output);
        outputUris.add(uri);
      }
    }
    final Set<Uri> deletedOutputs = _cleanUp(outputUris);
    return PhaseResult(outputs: outputUris, failedAssets: failedAssets, deletedOutputs: deletedOutputs);
  }

  Set<Uri> _cleanUp(Set<Uri> outputUris) {
    final Set<Uri> deletedOutputs = <Uri>{};
    for (final String oldOutput in _oldOutputs) {
      final Uri? oldOutputUri = graph.uriForAssetOrNull(oldOutput);
      if (oldOutputUri == null) continue;
      final Uri fileOutputUri = fileResolver.resolveFileUri(oldOutputUri);
      if (!outputUris.contains(fileOutputUri)) {
        deletedOutputs.add(fileOutputUri);
        final File file = File.fromUri(fileOutputUri);
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
    final HashMap<Asset, Set<Uri>> chunkOutputs = HashMap<Asset, Set<Uri>>();
    final List<FailedAsset> chunkErrors = <FailedAsset>[];
    for (final ProcessableAsset entry in chunk) {
      try {
        final BuildCandidate candidate = BuildCandidate(
          entry.asset,
          entry.tlmFlag.hasNormal,
          resolver.graph.exportedSymbolsOf(entry.asset.id),
        );
        for (final BuilderEntry builderEntry in builders) {
          if (!builderEntry.shouldGenerateFor(candidate)) continue;
          final Set<Uri> generatedOutputs = await builderEntry.build(resolver, entry.asset);
          chunkOutputs.putIfAbsent(entry.asset, () => <Uri>{}).addAll(generatedOutputs);
        }
      } catch (e, stack) {
        chunkErrors.add(FailedAsset(entry.asset, e, stack));
      }
    }
    return BuildResult(chunkOutputs, chunkErrors);
  }
}
