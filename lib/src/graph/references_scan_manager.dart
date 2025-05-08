import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/assets_reader.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/graph/references_scanner.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:xxh3/xxh3.dart';

import 'assets_graph.dart';

class ScanningTask {
  final List<Asset> assets;
  final Map<String, dynamic> packageResolverData;

  ScanningTask(this.assets, this.packageResolverData);
}

// Worker function that runs in each isolate
Future<void> scannerWorker(SendPort sendPort) async {
  final ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    if (message is ScanningTask) {
      final PackageFileResolver fileResolver = PackageFileResolver.fromJson(message.packageResolverData);
      final AssetsScanResults resultsCollector = AssetsScanResults();
      final ReferencesScanner scanner = ReferencesScanner(resultsCollector, fileResolver);
      for (final Asset asset in message.assets) {
        scanner.scan(asset);
      }
      // Send results back to main isolate
      sendPort.send(<String, Map<String, dynamic>>{'results': resultsCollector.toJson()});
    } else if (message == 'exit') {
      break;
    }
  }

  receivePort.close();
}

class ReferencesScanManager {
  final AssetsGraph assetsGraph;
  final PackageFileResolver fileResolver;
  final String rootPackage;

  ReferencesScanManager({required this.assetsGraph, required this.fileResolver, required this.rootPackage});

  Future<void> scanAssets({bool scanOnlyRoot = false}) async {
    final FileAssetReader assetsReader = FileAssetReader(fileResolver);
    final Set<String> packagesToScan = scanOnlyRoot ? <String>{rootPackage} : fileResolver.packages;

    final Map<String, List<Asset>> assets = assetsReader.listAssetsFor(packagesToScan);
    final List<Asset> assetsList = assets.values.expand((List<Asset> e) => e).toList();
    // Only distribute work if building from scratch
    if (!assetsGraph.loadedFromCache) {
      await scanWithIsolates(assetsList, fileResolver.toJson());
    } else {
      // Use single-threaded approach for incremental updates
      final ReferencesScanner scanner = ReferencesScanner(assetsGraph, fileResolver);
      for (final Asset asset in assetsList) {
        scanner.scan(asset);
      }
    }
    handleIncrementallyUpdatedAssets(assetsGraph.getAssetsForPackage(rootPackage));
  }

  Future<Set<ProcessableAsset>> scanWithIsolates(List<Asset> assets, Map<String, dynamic> packageResolverData) async {
    final int isolateCount = Platform.numberOfProcessors - 1; // Leave one core free
    final int actualIsolateCount = isolateCount.clamp(1, assets.length);

    // Calculate chunk size - each isolate gets roughly equal work
    final int chunkSize = (assets.length / actualIsolateCount).ceil();
    final List<List<Asset>> chunks = <List<Asset>>[];

    // Split assets into chunks
    for (int i = 0; i < assets.length; i += chunkSize) {
      final int end = (i + chunkSize < assets.length) ? i + chunkSize : assets.length;
      chunks.add(assets.sublist(i, end));
    }

    final List<Future<Iterable<ProcessableAsset>>> futures = <Future<Iterable<ProcessableAsset>>>[];

    // Create and start isolates
    for (final List<Asset> chunk in chunks) {
      futures.add(processChunkInIsolate(chunk, packageResolverData));
    }
    // Wait for all isolates to complete
    final List<Iterable<ProcessableAsset>> results = await Future.wait(futures);
    return Set.unmodifiable(results.expand((Iterable<ProcessableAsset> e) => e));
  }

  Future<List<ProcessableAsset>> processChunkInIsolate(
    List<Asset> chunk,
    Map<String, dynamic> packageResolverData,
  ) async {
    Set<ProcessableAsset> processableAssets = <ProcessableAsset>{};

    // Create the receive port
    final ReceivePort receivePort = ReceivePort();
    final Completer completer = Completer();

    // Set up listener BEFORE spawning the isolate
    bool gotSendPort = false;
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
        final AssetsScanResults results = AssetsScanResults.fromJson(message['results']);
        assetsGraph.merge(results);
        completer.complete();
      }
    });

    // Spawn the isolate with our already-configured receive port
    final Isolate isolate = await Isolate.spawn(scannerWorker, receivePort.sendPort);

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

  void handleIncrementallyUpdatedAssets(List<ScannedAsset> entries) {
    for (final ScannedAsset entry in entries) {
      final Asset asset = fileResolver.assetForUri(entry.uri);
      if (!asset.existsSync()) {
        handleDeletedAsset(asset);
        continue;
      }
      final Uint8List content = asset.readAsBytesSync();
      if (xxh3String(content) != entry.digest) {
        handleUpdatedAsset(asset);
      }
    }
  }

  void handleUpdatedAsset(Asset asset) {
    final ReferencesScanner scanner = ReferencesScanner(assetsGraph, fileResolver);
    final Map<String, List> dependents = assetsGraph.dependentsOf(asset.id);
    scanner.scan(asset, forceOverride: true);
    for (final MapEntry<String, List> dep in dependents.entries) {
      if (assetsGraph.outputs[asset.id]?.contains(dep.key) == true) {
        // if the dependent is an output of the asset, we don't need to mark it as unprocessed
        continue;
      }
      assetsGraph.updateAssetState(dep.key, AssetState.unProcessed);
    }
  }

  void handleDeletedAsset(Asset asset) {
    final String? generatorSrc = assetsGraph.getGeneratorOfOutput(asset.id);
    if (generatorSrc != null) {
      assetsGraph.updateAssetState(generatorSrc, AssetState.unProcessed);
    }
    assetsGraph.updateAssetState(asset.id, AssetState.deleted);
  }

  void handleInsertedAsset(Asset asset) {
    final ReferencesScanner scanner = ReferencesScanner(assetsGraph, fileResolver);
    scanner.scan(asset);
  }
}

class ProcessableAsset {
  final Asset asset;
  final TLMFlag tlmFlag;

  final AssetState state;

  ProcessableAsset(this.asset, this.state, this.tlmFlag);

  ProcessableAsset.fromJson(Map<String, dynamic> json)
    : asset = FileAsset.fromJson(json['asset'] as Map<String, dynamic>),
      state = AssetState.fromIndex(json['state'] as int),
      tlmFlag = TLMFlag.fromIndex(json['tlmFlag'] as int);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'asset': asset.toJson(), 'state': state.index, 'tlmFlag': tlmFlag.index};
  }

  @override
  String toString() {
    return 'Asset{uri: ${asset.uri}, state: ${state.name}, tlmFlag: ${tlmFlag.index}}';
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

enum TLMFlag {
  none,
  normal,
  builder,
  both;

  bool get hasNormal => this == TLMFlag.normal || this == TLMFlag.both;
  bool get hasBuilder => this == TLMFlag.builder || this == TLMFlag.both;

  static TLMFlag fromIndex(int index) {
    return TLMFlag.values[index];
  }
}
