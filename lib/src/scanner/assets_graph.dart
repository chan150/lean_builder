import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:code_genie/src/scanner/scan_results.dart';
import 'package:collection/collection.dart';
import 'package:xxh3/xxh3.dart';

import 'identifier_ref.dart';

class AssetsGraph extends AssetsScanResults {
  static final cacheFile = File('.dart_tool/build/assets_graph.json');

  AssetsGraph(this.packagesHash) : loadedFromCache = false;

  AssetsGraph._fromCache(this.packagesHash) : loadedFromCache = true;

  late final _coreImportId = xxh3String(Uint8List.fromList('dart:core/core.dart'.codeUnits));

  factory AssetsGraph.init(String packagesHash) {
    if (cacheFile.existsSync()) {
      try {
        final cachedGraph = jsonDecode(cacheFile.readAsStringSync());
        final instance = AssetsGraph.fromCache(cachedGraph, packagesHash);
        if (!instance.loadedFromCache) {
          print('Cache is outdated, rebuilding...');
          cacheFile.deleteSync(recursive: true);
        }
        return instance;
      } catch (e) {
        print('Cache is invalid, rebuilding...');
        cacheFile.deleteSync(recursive: true);
      }
    }
    return AssetsGraph(packagesHash);
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

  IdentifierRef _buildRef(String identifier, MapEntry<String, int> srcEntry, {String? providerId}) {
    final srcUri = getUriForAsset(srcEntry.key);
    final providerUri = providerId != null ? getUriForAsset(providerId) : srcUri;
    return IdentifierRef(
      identifier: identifier,
      srcId: srcEntry.key,
      srcUri: srcUri,
      providerId: providerId ?? srcEntry.key,
      providerUri: providerUri,
      type: IdentifierType.fromValue(srcEntry.value),
    );
  }

  IdentifierRef? getIdentifierRef(String identifier, String rootSrcId, {bool requireProvider = true}) {
    final possibleSrcs = Map<String, int>.fromEntries(
      identifiers.where((e) => e[0] == identifier).map((e) => MapEntry(e[1], e[2])),
    );

    // if [requireProvider] is false, we only care about the identifier src, not the provider
    if (!requireProvider && possibleSrcs.length == 1) {
      return _buildRef(identifier, possibleSrcs.entries.first);
    }

    // First check if the identifier is declared directly in this file
    for (final entry in possibleSrcs.entries) {
      if (entry.key == rootSrcId) {
        return _buildRef(identifier, entry, providerId: rootSrcId);
      }
    }

    // Check all imports of the source file
    final fileImports = [
      if (assets.containsKey(_coreImportId)) [_coreImportId],
      ...?imports[rootSrcId],
    ];
    for (final importEntry in fileImports) {
      final importedFileHash = importEntry[0] as String;
      final shows = importEntry.elementAtOrNull(1) as List<dynamic>? ?? const [];
      final hides = importEntry.elementAtOrNull(2) as List<dynamic>? ?? const [];
      // Skip if the identifier is hidden or not shown
      if (shows.isNotEmpty && !shows.contains(identifier)) continue;
      if (hides.contains(identifier)) continue;

      // Check if the imported file directly declares the identifier
      for (final entry in possibleSrcs.entries) {
        if (entry.key == importedFileHash) {
          return _buildRef(identifier, entry, providerId: importedFileHash);
        }
      }

      // Case 2b: Check if the imported file re-exports the identifier
      Set<String> reExportedSrcs = {};
      Set<String> visitedFiles = {};

      _collectProviders(importedFileHash, identifier, reExportedSrcs, visitedFiles);
      for (final entry in possibleSrcs.entries) {
        final srcId = entry.key;
        if (reExportedSrcs.contains(srcId) || reExportedSrcs.length == 1 || reExportedSrcs.contains(rootSrcId)) {
          final providedBySourceRoot = reExportedSrcs.contains(rootSrcId);
          final importedSrcHash = providedBySourceRoot ? rootSrcId : importedFileHash;
          return _buildRef(identifier, entry, providerId: importedSrcHash);
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
      final exportedFileHash = expEntry[0];
      final shows = expEntry.elementAtOrNull(1) as List<dynamic>? ?? const [];
      final hides = expEntry.elementAtOrNull(2) as List<dynamic>? ?? const [];
      if (hides.contains(identifier)) continue;
      if (shows.contains(identifier)) {
        return;
      } else if (shows.isNotEmpty) {
        continue;
      }
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
