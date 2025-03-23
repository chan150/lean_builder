import 'dart:convert';
import 'dart:io';

import 'package:code_genie/src/scanner/scan_results.dart';
import 'package:collection/collection.dart';

class AssetsGraph extends AssetsScanResults {
  static final cacheFile = File('.dart_tool/build/assets_graph.json');

  AssetsGraph(this.packagesHash) : loadedFromCache = false;

  AssetsGraph._fromCache(this.packagesHash, this.loadedFromCache);

  factory AssetsGraph.init(String packagesHash) {
    if (cacheFile.existsSync()) {
      final cachedGraph = jsonDecode(cacheFile.readAsStringSync());
      final instance = AssetsGraph.fromCache(cachedGraph, packagesHash);
      if (!instance.loadedFromCache) {
        print('Cache is outdated, rebuilding...');
        cacheFile.deleteSync(recursive: true);
      }
      return instance;
    } else {
      return AssetsGraph(packagesHash);
    }
  }

  final String packagesHash;
  final bool loadedFromCache;

  static const String version = '1.0.0';

  Uri getUriForAsset(String pathHash) {
    final asset = assets[pathHash];
    assert(asset != null, 'Asset not found: $pathHash');
    return Uri.parse(asset![0]);
  }

  List<ScannedAsset> getDependentsOf(String pathHash) {
    final effectedAssets = <ScannedAsset>[];
    for (final entry in imports.entries) {
      for (final importedFile in entry.value) {
        if (importedFile[0] == pathHash) {
          final asset = assets[entry.key]![0];
          final uri = Uri.parse(asset);
          effectedAssets.add(ScannedAsset(entry.key, uri, asset[1], asset[2] == 1));
        }
      }
    }
    return effectedAssets;
  }

  List<ScannedAsset> getAssetsForPackage(String package) {
    final assets = <ScannedAsset>[];
    for (final entry in this.assets.entries) {
      final uri = Uri.parse(entry.value[0]);
      if (uri.pathSegments.isEmpty) continue;
      if (uri.pathSegments[0] == package) {
        assets.add(ScannedAsset(entry.key, uri, entry.value[1] as String?, (entry.value[2] as int) == 1));
      }
    }
    return assets;
  }

  IdentifierReference? getIdentifierRef(String identifier, String srcFileId) {
    // First check if the identifier is declared directly in this file

    final possibleSrcs = identifiers.where((e) => e[0] == identifier).map((e) => e[1]).toSet();

    if (possibleSrcs.contains(srcFileId)) {
      final uri = getUriForAsset(srcFileId);
      return IdentifierReference(
        identifier: identifier,
        srcId: srcFileId,
        srcUri: uri,
        providerId: srcFileId,
        providerUri: uri,
      );
    }

    // Check all imports of the source file
    final fileImports = imports[srcFileId] ?? [];
    for (final importEntry in fileImports) {
      final importedFileHash = importEntry[0] as String;
      final shows = importEntry.elementAtOrNull(1) as List<dynamic>? ?? const [];
      final hides = importEntry.elementAtOrNull(2) as List<dynamic>? ?? const [];
      // Skip if the identifier is hidden or not shown
      if (shows.isNotEmpty && !shows.contains(identifier)) continue;
      if (hides.contains(identifier)) continue;

      // Check if the imported file directly declares the identifier\
      if (possibleSrcs.contains(importedFileHash)) {
        final uri = getUriForAsset(importedFileHash);
        return IdentifierReference(
          identifier: identifier,
          srcId: importedFileHash,
          srcUri: uri,
          providerId: importedFileHash,
          providerUri: uri,
        );
      }

      // Case 2b: Check if the imported file re-exports the identifier
      Set<String> reExportedSrcs = {};
      Set<String> visitedFiles = {};
      _collectProviders(importedFileHash, identifier, reExportedSrcs, visitedFiles);
      for (final srcId in possibleSrcs) {
        if (reExportedSrcs.contains(srcId)) {
          final srcUri = getUriForAsset(srcId);
          final importedUri = getUriForAsset(importedFileHash);
          return IdentifierReference(
            identifier: identifier,
            srcId: srcId,
            srcUri: srcUri,
            providerId: importedFileHash,
            providerUri: importedUri,
          );
        }
      }
    }

    return null;
  }

  void _collectProviders(String fileHash, String identifier, Set<String> providers, Set<String> visitedFiles) {
    if (visitedFiles.contains(fileHash)) return;
    visitedFiles.add(fileHash);
    assert(assets.containsKey(fileHash));
    providers.add(fileHash);
    // Check all files that export this file
    final fileExports = exports[fileHash] ?? [];
    for (final expEntry in fileExports) {
      final exportedFileHash = expEntry[0] as String;
      final shows = expEntry.elementAtOrNull(1) as List<dynamic>? ?? const [];
      final hides = expEntry.elementAtOrNull(2) as List<dynamic>? ?? const [];
      if (shows.isNotEmpty && !shows.contains(identifier)) continue;
      if (hides.contains(identifier)) continue;
      _collectProviders(exportedFileHash, identifier, providers, visitedFiles);
    }
  }

  Set<String> identifiersForAsset(String assetHash) {
    final identifiers = <String>{};
    for (final entry in this.identifiers) {
      if (entry[1] == assetHash) {
        identifiers.add(entry[0]);
      }
    }
    return identifiers;
  }

  Map<String, String> getExposedIdentifiersInside(String fileHash) {
    final identifiers = <String, String>{};
    for (final importArr in imports[fileHash] ?? []) {
      final importedIdentifiers = identifiersForAsset(importArr[0]);
      for (final identifier in importedIdentifiers) {
        identifiers[identifier] = importArr[0];
      }
    }
    return identifiers;
  }

  // Create from cached data if valid
  factory AssetsGraph.fromCache(Map<String, dynamic> json, String packagesHash) {
    final storedPackagesHash = json['packagesHash'] as String?;
    final version = json['version'] as String?;
    if (storedPackagesHash != packagesHash || version != AssetsGraph.version) {
      return AssetsGraph(packagesHash);
    }
    return AssetsScanResults.populate(AssetsGraph._fromCache(packagesHash, true), json);
  }
}

class ScannedAsset {
  ScannedAsset(this.id, this.uri, this.contentHash, this.hasAnnotation);

  final Uri uri;
  final String id;
  final String? contentHash;
  final bool hasAnnotation;

  @override
  String toString() {
    return 'PackageAsset{path: $uri, hasAnnotation: $hasAnnotation}';
  }
}

class IdentifierReference {
  IdentifierReference({
    required this.identifier,
    required this.srcId,
    required this.providerId,
    required this.srcUri,
    required this.providerUri,
  });

  final String identifier;
  final String srcId;
  final String providerId;
  final Uri srcUri;
  final Uri providerUri;

  @override
  String toString() {
    return 'IdentifierReference{identifier: $identifier, srcHash: $srcId, providerHash: $providerId}';
  }
}
