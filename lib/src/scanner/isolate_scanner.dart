import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:lean_builder/src/resolvers/assets_reader.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:lean_builder/src/scanner/assets_graph.dart';
import 'package:lean_builder/src/scanner/scan_results.dart';
import 'package:lean_builder/src/scanner/top_level_scanner.dart';
import 'package:xxh3/xxh3.dart';

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
      final scanner = TopLevelScanner(resultsCollector, fileResolver);
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

class IsolateTLScanner {
  final AssetsGraph assetsGraph;
  final PackageFileResolver fileResolver;

  IsolateTLScanner({required this.assetsGraph, required this.fileResolver});

  Future<List<ProcessableAsset>> scanAssets() async {
    final assetsReader = FileAssetReader(fileResolver);
    final packagesToScan = assetsGraph.loadedFromCache ? {fileResolver.rootPackage} : fileResolver.packages;

    final assets = assetsReader.listAssetsFor(packagesToScan);
    final assetsList = assets.values.expand((e) => e).toList();
    final List<ProcessableAsset> results;
    // Only distribute work if building from scratch
    if (!assetsGraph.loadedFromCache) {
      results = await scanWithIsolates(assetsList, fileResolver.toJson());
    } else {
      final processableAssets = <ProcessableAsset>[];
      // Use single-threaded approach for incremental updates
      final scanner = TopLevelScanner(assetsGraph, fileResolver);
      for (final asset in assetsList) {
        final (didScan, hasAnnotation) = scanner.scan(asset);
        if (didScan) {
          processableAssets.add(ProcessableAsset(asset, AssetState.inserted, hasAnnotation));
        }
      }
      results = [...processableAssets, ...updateIncrementalAssets(scanner)];
    }

    return results;
  }

  Future<List<ProcessableAsset>> scanWithIsolates(List<Asset> assets, Map<String, dynamic> packageResolverData) async {
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
    return List.unmodifiable(results.expand((e) => e));
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

  List<ProcessableAsset> updateIncrementalAssets(TopLevelScanner scanner) {
    final processableAssets = <ProcessableAsset>[];
    for (final entry in assetsGraph.getAssetsForPackage(fileResolver.rootPackage)) {
      final asset = fileResolver.assetForUri(entry.uri);
      if (!asset.existsSync()) {
        final generatingAssetArr = assetsGraph.getGeneratingSourceOf(asset.id);
        if (generatingAssetArr != null) {
          final uri = Uri.parse(generatingAssetArr[GraphIndex.assetUri]);
          final generatedAsset = fileResolver.assetForUri(uri);
          processableAssets.add(
            ProcessableAsset(
              generatedAsset,
              AssetState.needUpdate,
              generatingAssetArr[GraphIndex.assetAnnotationFlag] == 1,
            ),
          );
        }
        assetsGraph.removeAsset(asset.id);
        processableAssets.add(ProcessableAsset(asset, AssetState.deleted, entry.hasAnnotation));
        continue;
      }
      final content = asset.readAsBytesSync();
      final currentHash = xxh3String(content);
      if (currentHash != entry.digest) {
        final dependents = assetsGraph.dependentsOf(asset.id);
        assetsGraph.visitedAssets.remove(asset.id);
        final (didScane, hasAnnotation) = scanner.scan(asset);
        if (didScane) {
          processableAssets.add(ProcessableAsset(asset, AssetState.updated, hasAnnotation));
        }
        for (final dep in dependents) {
          final asset = fileResolver.assetForUri(Uri.parse(dep[GraphIndex.assetUri]));
          processableAssets.add(
            ProcessableAsset(asset, AssetState.needUpdate, dep[GraphIndex.assetAnnotationFlag] == 1),
          );
        }
      }
    }
    return processableAssets;
  }
}

class ProcessableAsset {
  final Asset asset;
  final bool hasTopLevelAnnotation;

  final AssetState state;

  ProcessableAsset(this.asset, this.state, this.hasTopLevelAnnotation);

  ProcessableAsset.fromJson(Map<String, dynamic> json)
    : asset = FileAsset.fromJson(json['asset'] as Map<String, dynamic>),
      state = AssetState.values[json['state'] as int],
      hasTopLevelAnnotation = json['hasTopLevelAnnotation'] as bool;

  Map<String, dynamic> toJson() {
    return {'asset': asset.toJson(), 'state': state.index, 'hasTopLevelAnnotation': hasTopLevelAnnotation};
  }
}

enum AssetState { inserted, updated, deleted, needUpdate }
