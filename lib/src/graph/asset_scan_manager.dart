import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/assets_reader.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/graph/assets_scanner.dart';
import 'package:xxh3/xxh3.dart';

import 'assets_graph.dart';

class ScanningTask {
  final List<Asset> assets;
  final Map<String, dynamic> packageResolverData;

  ScanningTask(this.assets, this.packageResolverData);
}

// Worker function that runs in each isolate
Future<void> scannerWorker(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    if (message is ScanningTask) {
      final fileResolver = PackageFileResolver.fromJson(message.packageResolverData);
      final resultsCollector = AssetsScanResults();
      final scanner = AssetsScanner(resultsCollector, fileResolver);
      final processableAssets = <ProcessableAsset>[];
      for (final asset in message.assets) {
        final (didScane, hasAnnotation) = scanner.scan(asset);
        if (didScane) {
          processableAssets.add(ProcessableAsset(asset, AssetState.inserted, hasAnnotation));
        }
      }
      // Send results back to main isolate
      sendPort.send({
        'results': resultsCollector.toJson(),
        'assets': processableAssets.map((e) => e.toJson()).toList(),
      });
    } else if (message == 'exit') {
      break;
    }
  }

  receivePort.close();
}

class AssetScanManager {
  final AssetsGraph assetsGraph;
  final PackageFileResolver fileResolver;
  final String rootPackage;

  AssetScanManager({required this.assetsGraph, required this.fileResolver, required this.rootPackage});

  Future<Set<ProcessableAsset>> scanAssets({bool scanOnlyRoot = false}) async {
    final assetsReader = FileAssetReader(fileResolver);
    final packagesToScan = scanOnlyRoot ? {rootPackage} : fileResolver.packages;

    final assets = assetsReader.listAssetsFor(packagesToScan);
    final assetsList = assets.values.expand((e) => e).toList();
    final Set<ProcessableAsset> results;
    // Only distribute work if building from scratch
    if (!assetsGraph.loadedFromCache) {
      results = await scanWithIsolates(assetsList, fileResolver.toJson());
    } else {
      final processableAssets = <ProcessableAsset>[];
      // Use single-threaded approach for incremental updates
      final scanner = AssetsScanner(assetsGraph, fileResolver);
      for (final asset in assetsList) {
        final (didScan, hasAnnotation) = scanner.scan(asset);
        if (didScan) {
          processableAssets.add(ProcessableAsset(asset, AssetState.inserted, hasAnnotation));
        }
      }
      results = {...processableAssets, ...getIncrementallyUpdatedAssets(assetsGraph.getAssetsForPackage(rootPackage))};
    }

    return results;
  }

  Future<Set<ProcessableAsset>> scanWithIsolates(List<Asset> assets, Map<String, dynamic> packageResolverData) async {
    final isolateCount = Platform.numberOfProcessors - 1; // Leave one core free
    final actualIsolateCount = isolateCount.clamp(1, assets.length);

    // Calculate chunk size - each isolate gets roughly equal work
    final chunkSize = (assets.length / actualIsolateCount).ceil();
    final chunks = <List<Asset>>[];

    // Split assets into chunks
    for (int i = 0; i < assets.length; i += chunkSize) {
      final end = (i + chunkSize < assets.length) ? i + chunkSize : assets.length;
      chunks.add(assets.sublist(i, end));
    }

    final futures = <Future<Iterable<ProcessableAsset>>>[];

    // Create and start isolates
    for (final chunk in chunks) {
      futures.add(processChunkInIsolate(chunk, packageResolverData));
    }
    // Wait for all isolates to complete
    final results = await Future.wait(futures);
    return Set.unmodifiable(results.expand((e) => e));
  }

  Future<List<ProcessableAsset>> processChunkInIsolate(
    List<Asset> chunk,
    Map<String, dynamic> packageResolverData,
  ) async {
    Set<ProcessableAsset> processableAssets = {};

    // Create the receive port
    final receivePort = ReceivePort();
    final completer = Completer();

    // Set up listener BEFORE spawning the isolate
    var gotSendPort = false;
    SendPort? workerSendPort;

    receivePort.listen((message) {
      if (!gotSendPort) {
        // First message is always the SendPort
        workerSendPort = message as SendPort;
        gotSendPort = true;

        // Now that we have the SendPort, send the task
        workerSendPort!.send(ScanningTask(chunk, packageResolverData));
      } else if (message is Map<String, dynamic>) {
        // Process results
        final results = AssetsScanResults.fromJson(message['results']);
        for (final assetJson in message['assets'] as List<dynamic>) {
          processableAssets.add(ProcessableAsset.fromJson(assetJson));
        }
        assetsGraph.merge(results);
        completer.complete();
      }
    });

    // Spawn the isolate with our already-configured receive port
    final isolate = await Isolate.spawn(scannerWorker, receivePort.sendPort);

    // Wait for the result
    await completer.future;

    // Clean up
    if (workerSendPort != null) {
      workerSendPort!.send('exit');
    }
    isolate.kill();
    receivePort.close();
    return List.of(processableAssets);
  }

  Set<ProcessableAsset> getIncrementallyUpdatedAssets(List<ScannedAsset> entries) {
    final processableAssets = <ProcessableAsset>{};
    for (final entry in entries) {
      final asset = fileResolver.assetForUri(entry.uri);
      if (!asset.existsSync()) {
        processableAssets.addAll(handleDeletedAsset(asset));
        continue;
      }
      final content = asset.readAsBytesSync();
      final currentDigest = xxh3String(content);

      if (currentDigest != entry.digest) {
        processableAssets.addAll(handleUpdatedAsset(asset));
      }
    }
    return processableAssets;
  }

  Set<ProcessableAsset> handleUpdatedAsset(Asset asset) {
    final scanner = AssetsScanner(assetsGraph, fileResolver);
    final processableAssets = <ProcessableAsset>{};
    assetsGraph.invalidateDigest(asset.id);
    final dependents = assetsGraph.dependentsOf(asset.id);
    final (didScane, hasAnnotation) = scanner.scan(asset);
    if (didScane) {
      processableAssets.add(ProcessableAsset(asset, AssetState.updated, hasAnnotation));
    }
    for (final dep in dependents) {
      final asset = fileResolver.assetForUri(Uri.parse(dep[GraphIndex.assetUri]));
      processableAssets.add(ProcessableAsset(asset, AssetState.needsUpdate, dep[GraphIndex.assetAnnotationFlag] == 1));
    }
    return processableAssets;
  }

  Set<ProcessableAsset> handleDeletedAsset(Asset asset) {
    final processableAssets = <ProcessableAsset>{};
    final generatingAssetArr = assetsGraph.getGeneratedSourceOf(asset.id);
    if (generatingAssetArr != null) {
      final uri = Uri.parse(generatingAssetArr[GraphIndex.assetUri]);
      final generatedAsset = fileResolver.assetForUri(uri);
      processableAssets.add(
        ProcessableAsset(
          generatedAsset,
          AssetState.needsUpdate,
          generatingAssetArr[GraphIndex.assetAnnotationFlag] == 1,
        ),
      );
    }
    assetsGraph.removeAsset(asset.id);
    processableAssets.add(ProcessableAsset(asset, AssetState.deleted, false));
    return processableAssets;
  }

  ProcessableAsset handleInsertedAsset(Asset asset) {
    final scanner = AssetsScanner(assetsGraph, fileResolver);
    final (didScane, hasAnnotation) = scanner.scan(asset);
    if (didScane) {
      return ProcessableAsset(asset, AssetState.inserted, hasAnnotation);
    }
    return ProcessableAsset(asset, AssetState.inserted, false);
  }
}

class ProcessableAsset {
  final Asset asset;
  final bool hasTopLevelMetadata;

  final AssetState state;

  ProcessableAsset(this.asset, this.state, this.hasTopLevelMetadata);

  ProcessableAsset.fromJson(Map<String, dynamic> json)
    : asset = FileAsset.fromJson(json['asset'] as Map<String, dynamic>),
      state = AssetState.values[json['state'] as int],
      hasTopLevelMetadata = json['hasTopLevelMetadata'] as bool;

  Map<String, dynamic> toJson() {
    return {'asset': asset.toJson(), 'state': state.index, 'hasTopLevelMetadata': hasTopLevelMetadata};
  }

  @override
  String toString() {
    return 'Asset{uri: ${asset.uri}, state: ${state.name}, hasTopLevelMetadata: $hasTopLevelMetadata}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProcessableAsset) return false;
    return asset == other.asset;
  }

  @override
  int get hashCode {
    return asset.hashCode;
  }
}

enum AssetState { inserted, updated, deleted, needsUpdate }
