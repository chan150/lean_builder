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

/// {@template scanning_task}
/// Represents a batch of assets to be scanned in an isolate.
///
/// This class encapsulates the data needed for a worker isolate to scan a set
/// of assets, including:
/// - The list of assets to scan
/// - Package resolver data needed to resolve file references
///
/// It's used to transfer data between the main isolate and worker isolates.
/// {@endtemplate}
class ScanningTask {
  /// The list of assets to scan
  final List<Asset> assets;

  /// Serialized package resolver data for file resolution
  final Map<String, dynamic> packageResolverData;

  /// {@macro scanning_task}
  ScanningTask(this.assets, this.packageResolverData);
}

/// Worker function that runs in each isolate to scan a batch of assets
///
/// This function:
/// 1. Creates a receive port and sends it back to the main isolate
/// 2. Listens for scanning tasks
/// 3. For each task, creates a scanner and processes the assets
/// 4. Sends results back to the main isolate
/// 5. Exits when it receives an 'exit' message
///
/// [sendPort] The send port to communicate with the main isolate
Future<void> scannerWorker(SendPort sendPort) async {
  final ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (dynamic message in receivePort) {
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

/// {@template references_scan_manager}
/// Manages the scanning of Dart source files for references and dependencies.
///
/// This class coordinates the scanning process, which can be done either:
/// - In parallel using multiple isolates (for initial scans)
/// - Sequentially in the main isolate (for incremental updates)
///
/// It handles:
/// - Distributing work across isolates
/// - Merging results into a unified graph
/// - Incrementally updating the graph when files change
/// - Managing file deletions, updates, and insertions
///
/// This is a core component of the build system that enables efficient
/// tracking of dependencies between files.
/// {@endtemplate}
class ReferencesScanManager {
  /// The graph that will store scanning results
  final AssetsGraph assetsGraph;

  /// Used to resolve file references
  final PackageFileResolver fileResolver;

  /// The root package being built
  final String rootPackage;

  /// {@macro references_scan_manager}
  ReferencesScanManager({required this.assetsGraph, required this.fileResolver, required this.rootPackage});

  /// {@template references_scan_manager.scan_assets}
  /// Scans Dart source files to build or update the dependency graph.
  ///
  /// This method:
  /// 1. Gathers all relevant assets from the packages to scan
  /// 2. Uses isolates for a full scan or a single-threaded approach for incremental updates
  /// 3. Handles any incrementally updated assets (added/changed/deleted)
  ///
  /// [scanOnlyRoot] When true, only scans files in the root package
  /// {@endtemplate}
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

  /// {@template references_scan_manager.scan_with_isolates}
  /// Scans assets in parallel using multiple isolates.
  ///
  /// This method:
  /// 1. Determines how many isolates to use based on available processors
  /// 2. Divides the assets into roughly equal chunks
  /// 3. Creates an isolate for each chunk
  /// 4. Collects and merges results from all isolates
  ///
  /// This approach significantly speeds up the initial scanning process.
  ///
  /// [assets] The list of assets to scan
  /// [packageResolverData] Serialized package resolver data to pass to isolates
  /// {@endtemplate}
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
    return Set<ProcessableAsset>.unmodifiable(results.expand((Iterable<ProcessableAsset> e) => e));
  }

  /// {@template references_scan_manager.process_chunk_in_isolate}
  /// Processes a chunk of assets in a separate isolate.
  ///
  /// This method:
  /// 1. Creates a communication channel to the worker isolate
  /// 2. Spawns the worker isolate with the scanning task
  /// 3. Collects and merges results back into the main graph
  /// 4. Cleans up the isolate
  ///
  /// [chunk] The assets to process in this isolate
  /// [packageResolverData] Serialized package resolver data
  /// {@endtemplate}
  Future<List<ProcessableAsset>> processChunkInIsolate(
    List<Asset> chunk,
    Map<String, dynamic> packageResolverData,
  ) async {
    Set<ProcessableAsset> processableAssets = <ProcessableAsset>{};

    // Create the receive port
    final ReceivePort receivePort = ReceivePort();
    final Completer<void> completer = Completer<void>();

    // Set up listener BEFORE spawning the isolate
    bool gotSendPort = false;
    SendPort? workerSendPort;

    receivePort.listen((dynamic message) {
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
    return List<ProcessableAsset>.of(processableAssets);
  }

  /// {@template references_scan_manager.handle_incrementally_updated_assets}
  /// Identifies and handles assets that have changed since the last build.
  ///
  /// This method compares the current state of assets with their cached state
  /// to identify:
  /// - Deleted assets
  /// - Modified assets
  ///
  /// It then updates the graph accordingly to ensure dependent files are rebuilt.
  ///
  /// [entries] The list of scanned assets to check for changes
  /// {@endtemplate}
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

  /// {@template references_scan_manager.handle_updated_asset}
  /// Updates the graph when an asset has been modified.
  ///
  /// This method:
  /// 1. Rescans the modified asset
  /// 2. Marks all dependent assets as needing to be reprocessed
  /// 3. Preserves the state of generated outputs
  ///
  /// [asset] The asset that has been updated
  /// {@endtemplate}
  void handleUpdatedAsset(Asset asset) {
    final ReferencesScanner scanner = ReferencesScanner(assetsGraph, fileResolver);
    final Map<String, List<dynamic>> dependents = assetsGraph.dependentsOf(asset.id);
    scanner.scan(asset, forceOverride: true);
    for (final MapEntry<String, List<dynamic>> dep in dependents.entries) {
      if (assetsGraph.outputs[asset.id]?.contains(dep.key) == true) {
        // if the dependent is an output of the asset, we don't need to mark it as unprocessed
        continue;
      }
      assetsGraph.updateAssetState(dep.key, AssetState.unProcessed);
    }
  }

  /// {@template references_scan_manager.handle_deleted_asset}
  /// Updates the graph when an asset has been deleted.
  ///
  /// This method:
  /// 1. Marks the asset as deleted in the graph
  /// 2. If the asset was generated by a builder, marks its generator as needing to be reprocessed
  ///
  /// [asset] The asset that has been deleted
  /// {@endtemplate}
  void handleDeletedAsset(Asset asset) {
    final String? generatorSrc = assetsGraph.getGeneratorOfOutput(asset.id);
    if (generatorSrc != null) {
      assetsGraph.updateAssetState(generatorSrc, AssetState.unProcessed);
    }
    assetsGraph.updateAssetState(asset.id, AssetState.deleted);
  }

  /// {@template references_scan_manager.handle_inserted_asset}
  /// Updates the graph when a new asset has been added.
  ///
  /// This method scans the new asset to add it and its references to the graph.
  ///
  /// [asset] The new asset that has been added
  /// {@endtemplate}
  void handleInsertedAsset(Asset asset) {
    final ReferencesScanner scanner = ReferencesScanner(assetsGraph, fileResolver);
    scanner.scan(asset);
  }
}

/// {@template processable_asset}
/// Represents an asset that needs to be processed by a builder.
///
/// This class combines:
/// - The asset itself
/// - Its current state (unprocessed, processed, deleted)
/// - Its annotation status (has top-level metadata or builder annotations)
///
/// It's used to track which assets need to be processed during a build.
/// {@endtemplate}
class ProcessableAsset {
  /// The asset to be processed
  final Asset asset;

  /// The annotation status of the asset
  final TLMFlag tlmFlag;

  /// The current state of the asset
  final AssetState state;

  /// {@macro processable_asset}
  ProcessableAsset(this.asset, this.state, this.tlmFlag);

  /// Creates a [ProcessableAsset] from a JSON representation
  ProcessableAsset.fromJson(Map<String, dynamic> json)
    : asset = FileAsset.fromJson(json['asset'] as Map<String, dynamic>),
      state = AssetState.fromIndex(json['state'] as int),
      tlmFlag = TLMFlag.fromIndex(json['tlmFlag'] as int);

  /// Converts this asset to a JSON representation for serialization
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

/// {@template tlm_flag}
/// Represents the annotation status of an asset.
///
/// This enum tracks whether an asset has:
/// - No annotations
/// - Regular top-level metadata annotations
/// - Builder annotations
/// - Both types of annotations
///
/// This information is used to determine which assets need to be processed
/// by which types of builders.
/// {@endtemplate}
enum TLMFlag {
  /// Asset has no annotations
  none,

  /// Asset has regular top-level metadata annotations
  normal,

  /// Asset has builder annotations
  builder,

  /// Asset has both regular and builder annotations
  both;

  /// Whether this asset has regular annotations
  bool get hasNormal => this == TLMFlag.normal || this == TLMFlag.both;

  /// Whether this asset has builder annotations
  bool get hasBuilder => this == TLMFlag.builder || this == TLMFlag.both;

  /// Creates a [TLMFlag] from its integer index
  static TLMFlag fromIndex(int index) {
    return TLMFlag.values[index];
  }
}
