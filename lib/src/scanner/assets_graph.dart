import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/scanner/directive_statement.dart';
import 'package:code_genie/src/scanner/scan_results.dart';
import 'package:collection/collection.dart';
import 'package:xxh3/xxh3.dart';

import 'identifier_ref.dart';

class AssetsGraph extends AssetsScanResults {
  static final cacheFile = File('.dart_tool/build/assets_graph.json');

  AssetsGraph(this.packagesHash) : loadedFromCache = false;

  AssetsGraph._fromCache(this.packagesHash) : loadedFromCache = true;

  final _coreImportId = xxh3String(Uint8List.fromList('dart:core/core.dart'.codeUnits));
  late final _coreImport = [DirectiveStatement.import, _coreImportId, '', null, null];

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

  Uri uriForAsset(String id) {
    final asset = assets[id];
    assert(asset != null, 'Asset not found: $id');
    return Uri.parse(asset![GraphIndex.assetUri]);
  }

  List<ScannedAsset> getAssetsForPackage(String package) {
    final assets = <ScannedAsset>[];
    for (final entry in this.assets.entries) {
      final uri = Uri.parse(entry.value[GraphIndex.assetUri]);
      if (uri.pathSegments.isEmpty) continue;
      if (uri.pathSegments[0] == package) {
        assets.add(
          ScannedAsset(
            entry.key,
            uri,
            entry.value[GraphIndex.assetDigest] as String?,
            (entry.value[GraphIndex.assetAnnotationFlag] as int) == 1,
          ),
        );
      }
    }
    return assets;
  }

  IdentifierLocation? getIdentifierLocation(
    String identifier,
    AssetSrc importingSrc, {
    bool requireProvider = true,
    String? importPrefix,
  }) {
    IdentifierLocation buildRef(MapEntry<String, int> srcEntry, {String? providerId}) {
      return IdentifierLocation(
        identifier: identifier,
        srcId: srcEntry.key,
        srcUri: uriForAsset(srcEntry.key),
        providerId: providerId ?? srcEntry.key,
        type: TopLevelIdentifierType.fromValue(srcEntry.value),
        importingLibrary: importingSrc,
      );
    }

    final possibleSrcs = Map<String, int>.fromEntries(
      identifiers
          .where((e) => e[GraphIndex.identifierName] == identifier)
          .map((e) => MapEntry(e[GraphIndex.identifierSrc], e[GraphIndex.identifierType])),
    );

    // if [requireProvider] is false, we only care about the identifier src, not the provider
    if (!requireProvider && possibleSrcs.length == 1) {
      return buildRef(possibleSrcs.entries.first);
    }

    // First check if the identifier is declared directly in this file
    for (final entry in possibleSrcs.entries) {
      if (entry.key == importingSrc.id) {
        return buildRef(entry, providerId: importingSrc.id);
      }
    }

    // Check all imports of the source file
    final fileImports = [...importsOf(importingSrc.id), if (assets.containsKey(_coreImportId)) _coreImport];

    for (final importEntry in fileImports) {
      final importedFileSrc = importEntry[GraphIndex.directiveSrc] as String;
      final prefix = importEntry.elementAtOrNull(GraphIndex.directivePrefix) as String?;
      if (importPrefix != null && importPrefix != prefix) continue;

      final hides = importEntry[GraphIndex.directiveHide] as List<dynamic>? ?? const [];
      if (hides.contains(identifier)) continue;

      // Skip if the identifier is hidden or not shown
      final shows = importEntry[GraphIndex.directiveShow] as List<dynamic>? ?? const [];
      if (shows.isNotEmpty && !shows.contains(identifier)) continue;

      // Check if the imported file directly declares the identifier
      for (final entry in possibleSrcs.entries) {
        if (entry.key == importedFileSrc) {
          return buildRef(entry, providerId: importedFileSrc);
        }
      }
    }
    for (final importEntry in fileImports) {
      final importedFileSrc = importEntry[GraphIndex.directiveSrc] as String;
      final visitedSrcs = <String>{};
      final src = _traceExportsOf(importedFileSrc, identifier, possibleSrcs.keys, visitedSrcs);
      if (src != null) {
        final srcEntry = possibleSrcs.entries.firstWhere((k) => k.key == src);
        return buildRef(srcEntry, providerId: importedFileSrc);
      }
    }
    return null;
  }

  String? _traceExportsOf(String srcId, String identifier, Iterable<String> possibleSrcs, Set<String> visitedSrcs) {
    if (visitedSrcs.contains(srcId)) return null;
    visitedSrcs.add(srcId);

    final exports = exportsOf(srcId);
    final checkableExports = <String>{};
    for (final export in exports) {
      final exportedFileSrc = export[GraphIndex.directiveSrc] as String;
      final hides = export[GraphIndex.directiveHide] as List<dynamic>? ?? const [];
      if (hides.contains(identifier)) continue;
      final shows = export[GraphIndex.directiveShow] as List<dynamic>? ?? const [];
      if (shows.isNotEmpty && !shows.contains(identifier)) continue;

      if (possibleSrcs.contains(exportedFileSrc)) {
        return exportedFileSrc;
      }
      if (shows.contains(identifier)) {
        checkableExports.clear();
        checkableExports.add(exportedFileSrc);
        break;
      }
      checkableExports.add(exportedFileSrc);
    }
    for (final exportedFileHash in checkableExports) {
      final src = _traceExportsOf(exportedFileHash, identifier, possibleSrcs, visitedSrcs);
      if (src != null) {
        return src;
      }
    }
    return null;
  }

  Set<String> identifiersForAsset(String src) {
    final identifiers = <String>{};
    for (final entry in this.identifiers) {
      if (entry[GraphIndex.identifierSrc] == src) {
        identifiers.add(entry[GraphIndex.identifierName]);
      }
    }
    return identifiers;
  }

  Map<String, String> getExposedIdentifiersInside(String fileHash) {
    final identifiers = <String, String>{};
    for (final importArr in importsOf(fileHash)) {
      final importedIdentifiers = identifiersForAsset(importArr[GraphIndex.directiveSrc]);
      for (final identifier in importedIdentifiers) {
        identifiers[identifier] = importArr[GraphIndex.directiveSrc];
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
