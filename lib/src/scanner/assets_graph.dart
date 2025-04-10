import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/scanner/directive_statement.dart';
import 'package:code_genie/src/scanner/scan_results.dart';
import 'package:collection/collection.dart';
import 'package:xxh3/xxh3.dart';

import 'identifier_ref.dart';

class AssetsGraph extends AssetsScanResults {
  static final cacheFile = File('.dart_tool/build/assets_graph.json');

  AssetsGraph(this.packagesHash) : loadedFromCache = false;

  AssetsGraph._fromCache(this.packagesHash) : loadedFromCache = true;

  late final _coreImportId = xxh3String(Uint8List.fromList('dart:core/core.dart'.codeUnits));
  late final _coreImport = [DirectiveStatement.import, _coreImportId];

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

  // List<ScannedAsset> getDependentsOf(String pathHash) {
  //   final effectedAssets = <ScannedAsset>[];
  //   for (final entry in imports.entries) {
  //     for (final importedFile in entry.value) {
  //       if (importedFile[0] == pathHash) {
  //         final asset = assets[entry.key]![0];
  //         final uri = Uri.parse(asset);
  //         effectedAssets.add(ScannedAsset(entry.key, uri, asset[1], asset[2] == 1));
  //       }
  //     }
  //   }
  //   return effectedAssets;
  // }

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

  IdentifierSrc _buildRef(String identifier, MapEntry<String, int> srcEntry, {String? providerId}) {
    final srcUri = getUriForAsset(srcEntry.key);
    final providerUri = providerId != null ? getUriForAsset(providerId) : srcUri;
    return IdentifierSrc(
      identifier: identifier,
      srcId: srcEntry.key,
      srcUri: srcUri,
      providerId: providerId ?? srcEntry.key,
      providerUri: providerUri,
      type: TopLevelIdentifierType.fromValue(srcEntry.value),
    );
  }

  IdentifierSrc? getIdentifierSrc(
    String identifier,
    String rootSrcId, {
    bool requireProvider = true,
    String? importPrefix,
  }) {
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
    final fileImports = [...importsOf(rootSrcId), if (assets.containsKey(_coreImportId)) _coreImport];

    for (final importEntry in fileImports) {
      final importedFileHash = importEntry[1] as String;
      final shows = importEntry.elementAtOrNull(2) as List<dynamic>? ?? const [];
      final hides = importEntry.elementAtOrNull(3) as List<dynamic>? ?? const [];
      final prefix = importEntry.elementAtOrNull(4) as String?;
      if (importPrefix != null && importPrefix != prefix) continue;

      // Skip if the identifier is hidden or not shown
      if (shows.isNotEmpty && !shows.contains(identifier)) continue;
      if (hides.contains(identifier)) continue;

      // Check if the imported file directly declares the identifier
      for (final entry in possibleSrcs.entries) {
        if (entry.key == importedFileHash) {
          return _buildRef(identifier, entry, providerId: importedFileHash);
        }
      }
    }
    for (final importEntry in fileImports) {
      final importedFileHash = importEntry[1] as String;
      final src = _traceExportsOf(importedFileHash, identifier, possibleSrcs.keys);
      if (src != null) {
        final srcEntry = possibleSrcs.entries.firstWhere((k) => k.key == src);
        return _buildRef(identifier, srcEntry, providerId: importedFileHash);
      }
    }
    return null;
  }

  String? _traceExportsOf(String srcId, String identifier, Iterable<String> possibleSrcs) {
    if (identifier == 'PhysicalKeyboardKey') {
      print('Trace exports of ${getUriForAsset(srcId)}');
      // if (getUriForAsset(srcId).toString() == 'dart:ui/annotations.dart') {
      //   final fileResolver = PackageFileResolver.forCurrentRoot('code_genie');
      //   final assetSrc = fileResolver.buildAssetUri(Uri.parse('dart:ui/annotations.dart'), relativeTo: null);
      //   print(assetSrc.uri);
      // }
    }
    final exports = exportsOf(srcId);
    final checkableExports = <String>{};
    for (final export in exports) {
      final exportedFileHash = export[1] as String;
      final hides = export.elementAtOrNull(3) as List<dynamic>? ?? const [];
      if (hides.contains(identifier)) continue;
      final shows = export.elementAtOrNull(2) as List<dynamic>? ?? const [];
      if (shows.isNotEmpty && !shows.contains(identifier)) continue;

      if (possibleSrcs.contains(exportedFileHash)) {
        return exportedFileHash;
      }
      // if (shows.contains(identifier)) {
      //   checkableExports.clear();
      //   checkableExports.add(exportedFileHash);
      //   break;
      // }
      checkableExports.add(exportedFileHash);
    }
    for (final exportedFileHash in checkableExports) {
      final src = _traceExportsOf(exportedFileHash, identifier, possibleSrcs);
      if (src != null) {
        return src;
      }
    }
    return null;
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
    for (final importArr in importsOf(fileHash)) {
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
      'directives': directives,
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
