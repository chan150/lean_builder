import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:xxh3/xxh3.dart';

import 'directive_statement.dart';

class AssetsGraph {
  AssetsGraph(this.packagesHash) : loadedFromCache = false;

  AssetsGraph._fromCache(this.packagesHash, this.loadedFromCache);

  final String packagesHash;
  final bool loadedFromCache;

  static const String version = '1.0.0';

  final Map<String, List<dynamic>> assets = {/*  [src, content hash, has annotation] */};
  final List<List<dynamic>> identifiers = [/* [identifier, srcHash] */];
  final Map<String, List<List<dynamic>>> exports = {};
  final Map<String, List<List<dynamic>>> imports = {};

  final visitedAssets = <String>{};
  final _srcDigests = HashMap<String, String>();

  String digestPath(String path) {
    if (_srcDigests.containsKey(path)) {
      return _srcDigests[path]!;
    }
    return _srcDigests[path] = xxh3String(Uint8List.fromList(path.codeUnits));
  }

  bool isVisited(String fileId) {
    return visitedAssets.contains(fileId);
  }

  String addAsset(FileAsset asset, {bool isVisited = true}) {
    if (!assets.containsKey(asset.id)) {
      assets[asset.id] = [asset.shortPath.toString(), null, 0];
    }
    if (isVisited) visitedAssets.add(asset.id);
    return asset.id;
  }

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

  void updateFileInfo(FileAsset asset, {required Uint8List content, bool hasAnnotation = false}) {
    assert(assets.containsKey(asset.id), 'Asset not found: $asset');
    final contentHash = asset.root ? xxh3String(content) : null;
    final assetArr = assets[asset.id]!;
    assetArr[1] = contentHash;
    assetArr[2] = hasAnnotation ? 1 : 0;
  }

  // Add a direct declaration
  void addDeclaration(String identifier, FileAsset declaringFile) {
    if (!assets.containsKey(declaringFile.id)) {
      throw Exception('Asset not found: $declaringFile');
    }
    final entry = lookupIdentifier(identifier, declaringFile.id);
    if (entry == null) {
      identifiers.add([identifier, declaringFile.id]);
    }
  }

  List<dynamic>? lookupIdentifier(String identifier, String srcHash) {
    for (final entry in identifiers) {
      if (entry[0] == identifier && entry[1] == srcHash) {
        return entry;
      }
    }
    return null;
  }

  void addExport(FileAsset exportingFile, DirectiveStatement statement) {
    assert(assets.containsKey(exportingFile.id));
    final exportedFileHash = addAsset(statement.asset, isVisited: false);
    final exporters = exports[exportingFile.id] ?? [];
    if (exporters.isNotEmpty) {
      for (final exporter in exporters) {
        if (exporter[0] == exportedFileHash) {
          return;
        }
      }
    }
    exporters.add([
      exportedFileHash,
      if (statement.show.isNotEmpty || statement.hide.isNotEmpty) statement.show,
      if (statement.hide.isNotEmpty) statement.hide,
    ]);
    exports[exportingFile.id] = exporters;
  }

  void addImport(FileAsset importingFile, DirectiveStatement statement) {
    assert(assets.containsKey(importingFile.id));
    final importedFileHash = addAsset(statement.asset, isVisited: false);
    final importsOfFile = imports[importingFile.id] ?? [];
    if (importsOfFile.isNotEmpty) {
      for (final importedFile in importsOfFile) {
        if (importedFile[0] == importedFileHash) {
          return;
        }
      }
    }
    importsOfFile.add([
      importedFileHash,
      if (statement.show.isNotEmpty || statement.hide.isNotEmpty) statement.show,
      if (statement.hide.isNotEmpty) statement.hide,
    ]);
    imports[importingFile.id] = importsOfFile;
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

  // String? getImportForIdentifier(String identifier, Set<String> imports) {
  //   final possibleProviders = getProvidersForIdentifier(identifier);
  //   for (final provider in possibleProviders) {
  //     if (imports.contains(provider)) {
  //       return provider;
  //     }
  //   }
  //   return null;
  // }

  // Uri? getSourceForIdentifier(String identifier) {
  //   for (final provider in identifiers.entries) {
  //     if (provider.key.split('@').first == identifier) {
  //       final source = assets[provider.value.first];
  //       return packageResolver.resolve(Uri.parse('package:$source.dart'));
  //     }
  //   }
  //   return null;
  // }

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

  Map<String, dynamic> toJson() {
    return {
      'assets': assets,
      'identifiers': identifiers,
      'exports': exports,
      'imports': imports,
      'packagesHash': packagesHash,
      'version': version,
    };
  }

  // Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  void removeAsset(String pathHash) {
    assets.remove(pathHash);
    visitedAssets.remove(pathHash);
    // remove all exports that reference this asset
    exports.removeWhere((key, value) {
      value.removeWhere((element) => element[0] == pathHash);
      return value.isEmpty;
    });
    imports.remove(pathHash);
    // remove all identifiers that reference this asset
    identifiers.removeWhere((element) => element[1] == pathHash);
  }

  // Create from cached data if valid
  factory AssetsGraph.fromCache(Map<String, dynamic> json, String packagesHash) {
    final storedPackagesHash = json['packagesHash'] as String?;
    final version = json['version'] as String?;
    if (storedPackagesHash != packagesHash || version != AssetsGraph.version) {
      return AssetsGraph(packagesHash);
    }
    final graph = AssetsGraph._fromCache(packagesHash, true);
    graph.assets.addAll((json['assets'] as Map<String, dynamic>).cast<String, List<dynamic>>());
    graph.visitedAssets.addAll(graph.assets.keys);
    for (final export in json['exports'].entries) {
      graph.exports[export.key] = (export.value as List<dynamic>).cast<List<dynamic>>();
    }
    for (final import in json['imports'].entries) {
      graph.imports[import.key] = (import.value as List<dynamic>).cast<List<dynamic>>();
    }
    graph.identifiers.addAll((json['identifiers'] as List<dynamic>).cast<List<dynamic>>());
    return graph;
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
