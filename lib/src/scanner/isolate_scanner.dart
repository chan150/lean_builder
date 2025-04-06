import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:code_genie/src/resolvers/assets_reader.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/scan_results.dart';
import 'package:code_genie/src/scanner/top_level_scanner.dart';
import 'package:code_genie/src/utils.dart';
import 'package:xxh3/xxh3.dart';

class ScanningTask {
  final List<AssetSrc> assets;
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
      for (final asset in message.assets) {
        scanner.scanFile(asset);
      }
      // Send results back to main isolate
      sendPort.send(resultsCollector.toJson());
    } else if (message == 'exit') {
      break;
    }
  }

  receivePort.close();
}

class IsolateTLScanner {
  final AssetsGraph assetsGraph;
  final PackageFileResolver fileResolver;

  final assetsGraphFile = File('.dart_tool/build/assets_graph.json');

  IsolateTLScanner({required this.assetsGraph, required this.fileResolver});

  Future<void> scanAssets() async {
    final assetsReader = FileAssetReader(fileResolver);
    final packagesToScan = assetsGraph.loadedFromCache ? {rootPackageName} : fileResolver.packages;

    final assets = assetsReader.listAssetsFor(packagesToScan);
    final assetsList = assets.values.expand((e) => e).toList();

    // Only distribute work if building from scratch
    if (!assetsGraph.loadedFromCache) {
      await scanWithIsolates(assetsList, fileResolver.toJson());
    } else {
      // Use single-threaded approach incremental updates
      final scanner = TopLevelScanner(assetsGraph, fileResolver);
      for (final asset in assetsList) {
        scanner.scanFile(asset);
      }
      updateIncrementalAssets(scanner);
    }

    await assetsGraphFile.writeAsString(jsonEncode(assetsGraph.toJson()));
  }

  Future<void> scanWithIsolates(List<AssetSrc> assets, Map<String, dynamic> packageResolverData) async {
    final isolateCount = Platform.numberOfProcessors - 1; // Leave one core free
    final actualIsolateCount = isolateCount.clamp(1, assets.length);

    // Calculate chunk size - each isolate gets roughly equal work
    final chunkSize = (assets.length / actualIsolateCount).ceil();
    final chunks = <List<AssetSrc>>[];

    // Split assets into chunks
    for (int i = 0; i < assets.length; i += chunkSize) {
      final end = (i + chunkSize < assets.length) ? i + chunkSize : assets.length;
      chunks.add(assets.sublist(i, end));
    }

    final futures = <Future>[];

    // Create and start isolates
    for (final chunk in chunks) {
      futures.add(processChunkInIsolate(chunk, packageResolverData));
    }

    // Wait for all isolates to complete
    await Future.wait(futures);
  }

  Future<void> processChunkInIsolate(List<AssetSrc> chunk, Map<String, dynamic> packageResolverData) async {
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
        final results = AssetsScanResults.fromJson(message);
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
  }

  void updateIncrementalAssets(TopLevelScanner scanner) {
    for (final entry in assetsGraph.getAssetsForPackage(rootPackageName)) {
      final asset = fileResolver.buildAssetUri(entry.uri);
      if (!asset.existsSync()) {
        assetsGraph.removeAsset(asset.id);
        continue;
      }
      final content = asset.readAsBytesSync();
      final currentHash = xxh3String(content);
      if (currentHash != entry.contentHash) {
        assetsGraph.removeAsset(asset.id);
        scanner.scanFile(asset);
      }
    }
  }
}
