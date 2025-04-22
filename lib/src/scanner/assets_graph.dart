import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/builder/builder.dart';
import 'package:lean_builder/src/errors/resolver_error.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';
import 'package:lean_builder/src/scanner/directive_statement.dart';
import 'package:lean_builder/src/scanner/scan_results.dart';
import 'package:collection/collection.dart';
import 'package:xxh3/xxh3.dart';

import 'identifier_ref.dart';

class AssetsGraph extends AssetsScanResults {
  static final cacheFile = File('.dart_tool/lean_build/assets_graph.json');

  final String packagesHash;

  final bool loadedFromCache;

  static const String version = '1.0.0';

  late final _coreImportId = xxh3String(Uint8List.fromList('dart:core/core.dart'.codeUnits));

  late final _coreImport = [DirectiveStatement.import, _coreImportId, '', null, null];

  AssetsGraph(this.packagesHash) : loadedFromCache = false;

  AssetsGraph._fromCache(this.packagesHash) : loadedFromCache = true;

  factory AssetsGraph.init(String packagesHash) {
    if (cacheFile.existsSync()) {
      try {
        final cachedGraph = jsonDecode(cacheFile.readAsStringSync());
        final instance = AssetsGraph.fromCache(cachedGraph, packagesHash);
        if (!instance.loadedFromCache) {
          Logger.info('Cache is outdated, rebuilding...');
          cacheFile.deleteSync(recursive: true);
        }
        return instance;
      } catch (e) {
        Logger.info('Cache is invalid, rebuilding...');
        cacheFile.deleteSync(recursive: true);
      }
    }
    return AssetsGraph(packagesHash);
  }

  Future<void> save() async {
    final file = AssetsGraph.cacheFile;
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    await file.writeAsString(jsonEncode(toJson()));
  }

  Uri uriForAsset(String id) {
    final uri = uriForAssetOrNull(id);
    assert(uri != null, 'Asset not found: $id');
    return uri!;
  }

  Uri? uriForAssetOrNull(String id) {
    final asset = assets[id];
    if (asset == null) return null;
    return Uri.parse(asset[GraphIndex.assetUri]);
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

  DeclarationRef getDeclarationRef(String identifier, Asset importingSrc, {String? importPrefix}) {
    DeclarationRef buildRef(MapEntry<String, int> srcEntry, {String? providerId}) {
      return DeclarationRef(
        identifier: identifier,
        srcId: srcEntry.key,
        srcUri: uriForAsset(srcEntry.key),
        providerId: providerId ?? srcEntry.key,
        type: TopLevelIdentifierType.fromValue(srcEntry.value),
        importingLibrary: importingSrc,
        importPrefix: importPrefix,
      );
    }

    final possibleSrcs = Map<String, int>.fromEntries(
      identifiers
          .where((e) => e[GraphIndex.identifierName] == identifier)
          .map((e) => MapEntry(e[GraphIndex.identifierSrc], e[GraphIndex.identifierType])),
    );

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

      // Skip if the identifier is hidden
      final hides = importEntry[GraphIndex.directiveHide] as List<dynamic>? ?? const [];
      if (hides.contains(identifier)) continue;

      // Skip if the identifier is not shown
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
    throw IdentifierNotFoundError(identifier, importPrefix, importingSrc.shortUri);
  }

  DeclarationRef? lookupIdentifierByProvider(String name, String providerSrc) {
    if (!assets.containsKey(providerSrc)) return null;
    final possibleSrcs = Map<String, List<dynamic>>.fromEntries(
      identifiers
          .where((e) => e[GraphIndex.identifierName] == name)
          .map((e) => MapEntry(e[GraphIndex.identifierSrc], e)),
    );

    // First check if the identifier is declared directly in this file
    for (final entry in possibleSrcs.entries) {
      if (entry.key == providerSrc) {
        return DeclarationRef(
          identifier: name,
          srcId: providerSrc,
          providerId: providerSrc,
          type: TopLevelIdentifierType.fromValue(entry.value[GraphIndex.identifierType]),
          srcUri: uriForAsset(providerSrc),
        );
      }
    }
    // trace exports
    final visitedSrcs = <String>{};
    final src = _traceExportsOf(providerSrc, name, possibleSrcs.keys, visitedSrcs);
    if (src != null) {
      return DeclarationRef(
        identifier: name,
        srcId: src,
        providerId: providerSrc,
        type: TopLevelIdentifierType.fromValue(possibleSrcs[src]![GraphIndex.identifierType]),
        srcUri: uriForAsset(src),
      );
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

  void addOutput(Asset asset, Asset output) {
    assert(assets.containsKey(asset.id), 'Asset not found: ${asset.shortUri}');
    outputs.putIfAbsent(asset.id, () => <String>{}).add(output.id);
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
    return {...super.toJson(), 'version': version, 'packagesHash': packagesHash};
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

  void invalidateDigest(Asset asset) {
    final assetId = asset.id;
    if (assets.containsKey(assetId)) {
      assets[assetId]![GraphIndex.assetDigest] = null;
    }
  }

  // get any asset that depends on this asset,
  // either via direct import, part-of or via re-exports
  List<List<dynamic>> dependentsOf(String id) {
    final visited = <String>{};
    final dependents = _dependentsOf(id, visited);
    final assets = <List<dynamic>>[];
    for (final dep in dependents) {
      if (dep == id) continue;
      final arr = this.assets[dep];
      if (arr != null) {
        assets.add(arr);
      }
    }
    return assets;
  }

  Set<String> _dependentsOf(String id, Set<String> visited) {
    if (visited.contains(id)) return {};
    visited.add(id);
    final dependents = <String>{};
    for (final entry in directives.entries) {
      for (final directive in entry.value) {
        final type = directive[GraphIndex.directiveType];
        if (directive[GraphIndex.directiveSrc] == id) {
          if (type == DirectiveStatement.export) {
            dependents.addAll(_dependentsOf(entry.key, visited));
          } else if (type != DirectiveStatement.library) {
            dependents.add(entry.key);
          }
        } else if (type == DirectiveStatement.partOf && entry.key == id) {
          // If 'id' is the main library and 'directiveSrc' is a part of it
          dependents.add(directive[GraphIndex.directiveSrc]);
        }
      }
    }
    return dependents;
  }

  List<dynamic>? getGeneratingSourceOf(String id) {
    for (final entry in outputs.entries) {
      if (entry.value.contains(id)) {
        return assets[entry.key];
      }
    }
    return null;
  }

  List<ExportedSymbol> exportedSymbolsOf(String id) {
    final exportedSymbols = <ExportedSymbol>[];
    for (final entry in identifiers) {
      if (entry[GraphIndex.identifierSrc] == id) {
        final name = entry[GraphIndex.identifierName];
        final type = TopLevelIdentifierType.fromValue(entry[GraphIndex.identifierType]);
        exportedSymbols.add(ExportedSymbol(name, type));
      }
    }
    return exportedSymbols;
  }
}

class ScannedAsset {
  ScannedAsset(this.id, this.uri, this.digest, this.hasTopLevelMetadata);

  final Uri uri;
  final String id;
  final String? digest;
  final bool hasTopLevelMetadata;

  @override
  String toString() {
    return 'PackageAsset{path: $uri, hasTopLevelMetadata: $hasTopLevelMetadata}';
  }
}

class IdentifierRef {
  final String name;
  final String? prefix;
  final String? importPrefix;
  final DeclarationRef? location;

  IdentifierRef(this.name, {this.prefix, this.importPrefix, this.location});

  bool get isPrefixed => prefix != null;

  String get topLevelTarget => prefix != null ? prefix! : name;

  factory IdentifierRef.from(Identifier identifier, {String? importPrefix}) {
    if (identifier is PrefixedIdentifier) {
      return IdentifierRef(identifier.identifier.name, prefix: identifier.prefix.name, importPrefix: importPrefix);
    } else {
      return IdentifierRef(identifier.name, importPrefix: importPrefix);
    }
  }

  factory IdentifierRef.fromType(NamedType type) {
    return IdentifierRef(type.name2.lexeme, importPrefix: type.importPrefix?.name.lexeme);
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    if (prefix != null) {
      buffer.write('$prefix.');
    }
    buffer.write(name);
    if (importPrefix != null) {
      buffer.write('@$importPrefix');
    }
    return buffer.toString();
  }
}
