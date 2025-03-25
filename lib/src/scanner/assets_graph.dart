import 'dart:convert';
import 'dart:io';

import 'package:code_genie/src/scanner/scan_results.dart';
import 'package:collection/collection.dart';

import 'identifier_ref.dart';

class AssetsGraph extends AssetsScanResults {
  static final cacheFile = File('.dart_tool/build/assets_graph.json');

  AssetsGraph(this.packagesHash) : loadedFromCache = false;

  AssetsGraph._fromCache(this.packagesHash) : loadedFromCache = true;

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

  IdentifierRef? getIdentifierRef(String identifier, String srcFileId) {
    // First check if the identifier is declared directly in this file

    // check for core
    for (final identifierArr in identifiers) {
      if (identifierArr[0] == identifier) {
        print('src: ${assets[identifierArr[1]]?[0]}, type: ${IdentifierType.fromValue(identifierArr[2] as int).name}');
      }
    }

    final possibleSrcs = Map<String, int>.fromEntries(
      identifiers.where((e) => e[0] == identifier).map((e) => MapEntry(e[1], e[2])),
    );

    for (final entry in possibleSrcs.entries) {
      if (entry.key == srcFileId) {
        final uri = getUriForAsset(srcFileId);
        return IdentifierRef(
          identifier: identifier,
          srcId: srcFileId,
          srcUri: uri,
          providerId: srcFileId,
          providerUri: uri,
          type: IdentifierType.fromValue(entry.value),
        );
      }
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
      for (final entry in possibleSrcs.entries) {
        if (entry.key == importedFileHash) {
          final uri = getUriForAsset(importedFileHash);
          return IdentifierRef(
            identifier: identifier,
            srcId: importedFileHash,
            srcUri: uri,
            providerId: importedFileHash,
            providerUri: uri,
            type: IdentifierType.fromValue(entry.value),
          );
        }
      }

      // Case 2b: Check if the imported file re-exports the identifier
      Set<String> reExportedSrcs = {};
      Set<String> visitedFiles = {};
      _collectProviders(importedFileHash, identifier, reExportedSrcs, visitedFiles);
      for (final entry in possibleSrcs.entries) {
        final srcId = entry.key;
        if (reExportedSrcs.contains(srcId)) {
          final srcUri = getUriForAsset(srcId);
          final importedUri = getUriForAsset(importedFileHash);
          return IdentifierRef(
            identifier: identifier,
            srcId: srcId,
            srcUri: srcUri,
            providerId: importedFileHash,
            providerUri: importedUri,
            type: IdentifierType.fromValue(entry.value),
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

  @override
  Map<String, dynamic> toJson() {
    return {
      'assets': assets,
      'identifiers': identifiers,
      'exports': exports,
      'imports': imports,
      'version': version,
      'packagesHash': packagesHash,
    };
  }

  // Create from cached data if valid
  factory AssetsGraph.fromCache(Map<String, dynamic> json, String packagesHash) {
    final storedPackagesHash = json['packagesHash'] as String?;
    final version = json['version'] as String?;
    if (storedPackagesHash != packagesHash || version != AssetsGraph.version) {
      return AssetsGraph(packagesHash);
    }
    return AssetsScanResults.populate(AssetsGraph._fromCache(packagesHash), json);
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
