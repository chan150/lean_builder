import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/builder/builder.dart';
import 'package:lean_builder/src/graph/directive_statement.dart';
import 'package:lean_builder/src/graph/references_scan_manager.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/logger.dart';
import 'package:collection/collection.dart';
import 'package:lean_builder/src/resolvers/errors.dart';
import 'package:xxh3/xxh3.dart';

import 'identifier_ref.dart';

class AssetsGraph extends AssetsScanResults {
  static final File cacheFile = File('.dart_tool/lean_build/assets_graph.json');

  static void invalidateCache() {
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync(recursive: true);
    }
  }

  final String hash;

  final bool loadedFromCache;

  final bool shouldInvalidate;

  static const String version = '1.0.0';

  late final String _coreImportId = xxh3String(Uint8List.fromList('dart:core/core.dart'.codeUnits));

  late final List<Object?> _coreImport = <Object?>[DirectiveStatement.import, _coreImportId, '', null, null];

  AssetsGraph(this.hash) : loadedFromCache = false, shouldInvalidate = false;

  AssetsGraph._fromCache(this.hash, {this.shouldInvalidate = false}) : loadedFromCache = true;

  factory AssetsGraph.init(String hash) {
    if (cacheFile.existsSync()) {
      try {
        final cachedGraph = jsonDecode(cacheFile.readAsStringSync());
        final AssetsGraph instance = AssetsGraph.fromCache(cachedGraph, hash);
        if (!instance.loadedFromCache || instance.shouldInvalidate) {
          Logger.info('Cache is invalid, rebuilding...');
          cacheFile.deleteSync(recursive: true);
        }
        return instance;
      } catch (e) {
        Logger.info('Cache is invalid, rebuilding...');
        cacheFile.deleteSync(recursive: true);
      }
    }
    return AssetsGraph(hash);
  }

  Future<void> save() async {
    final File file = AssetsGraph.cacheFile;
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    await file.writeAsString(jsonEncode(toJson()));
  }

  void clearAll() {
    assets.clear();
    identifiers.clear();
    directives.clear();
    outputs.clear();
  }

  List<ScannedAsset> getAssetsForPackage(String package) {
    final List<ScannedAsset> assets = <ScannedAsset>[];
    for (final MapEntry<String, List> entry in this.assets.entries) {
      final Uri uri = Uri.parse(entry.value[GraphIndex.assetUri]);
      if (uri.pathSegments.isEmpty) continue;
      if (uri.pathSegments[0] == package) {
        assets.add(
          ScannedAsset(
            entry.key,
            uri,
            entry.value[GraphIndex.assetDigest] as String?,
            (entry.value[GraphIndex.assetTLMFlag] as int) == 1,
          ),
        );
      }
    }
    return assets;
  }

  void invalidateProcessedAssetsOf(String package) {
    for (final MapEntry<String, List> entry in assets.entries) {
      final Uri uri = Uri.parse(entry.value[GraphIndex.assetUri]);
      if (uri.pathSegments.isEmpty) continue;
      if (uri.pathSegments[0] == package) {
        entry.value[GraphIndex.assetState] = AssetState.unProcessed.index;
      }
    }
  }

  DeclarationRef getDeclarationRef(String identifier, Asset importingSrc, {String? importPrefix}) {
    DeclarationRef buildRef(MapEntry<String, int> srcEntry, {String? providerId}) {
      return DeclarationRef(
        identifier: identifier,
        srcId: srcEntry.key,
        srcUri: uriForAsset(srcEntry.key),
        providerId: providerId ?? srcEntry.key,
        type: SymbolType.fromValue(srcEntry.value),
        importingLibrary: importingSrc,
        importPrefix: importPrefix,
      );
    }

    final Map<String, int> possibleSrcs = Map<String, int>.fromEntries(
      identifiers
          .where((List<dynamic> e) => e[GraphIndex.identifierName] == identifier)
          .map((List<dynamic> e) => MapEntry<String, int>(e[GraphIndex.identifierSrc], e[GraphIndex.identifierType])),
    );

    final String actualSrc = getParentSrc(importingSrc.id);
    // First check if the identifier is declared directly in this file
    for (final MapEntry<String, int> entry in possibleSrcs.entries) {
      if (entry.key == importingSrc.id || entry.key == actualSrc) {
        return buildRef(entry, providerId: actualSrc);
      }
    }

    // Check all imports of the source file
    final List<List<Object?>> fileImports = <List<Object?>>[
      ...importsOf(importingSrc.id),
      if (assets.containsKey(_coreImportId)) _coreImport,
    ];

    for (final List<Object?> importEntry in fileImports) {
      final String importedFileSrc = importEntry[GraphIndex.directiveSrc] as String;
      final String? prefix = importEntry.elementAtOrNull(GraphIndex.directivePrefix) as String?;
      if (importPrefix != null && importPrefix != prefix) continue;

      // Skip if the identifier is hidden
      final List<dynamic> hides = importEntry[GraphIndex.directiveHide] as List<dynamic>? ?? const <dynamic>[];
      if (hides.contains(identifier)) continue;

      // Skip if the identifier is not shown
      final List<dynamic> shows = importEntry[GraphIndex.directiveShow] as List<dynamic>? ?? const <dynamic>[];
      if (shows.isNotEmpty && !shows.contains(identifier)) continue;

      // Check if the imported file directly declares the identifier
      for (final MapEntry<String, int> entry in possibleSrcs.entries) {
        if (entry.key == importedFileSrc) {
          return buildRef(entry, providerId: importedFileSrc);
        }
      }
    }
    for (final List<Object?> importEntry in fileImports) {
      final String importedFileSrc = importEntry[GraphIndex.directiveSrc] as String;
      final Set<String> visitedSrcs = <String>{};
      final String? src = _traceExportsOf(importedFileSrc, identifier, possibleSrcs.keys, visitedSrcs);
      if (src != null) {
        final MapEntry<String, int> srcEntry = possibleSrcs.entries.firstWhere(
          (MapEntry<String, int> k) => k.key == src,
        );
        return buildRef(srcEntry, providerId: importedFileSrc);
      }
    }
    throw IdentifierNotFoundError(identifier, importPrefix, importingSrc.shortUri);
  }

  DeclarationRef? lookupIdentifierByProvider(String name, String providerSrc) {
    if (!assets.containsKey(providerSrc)) return null;
    final Map<String, List<dynamic>> possibleSrcs = Map<String, List<dynamic>>.fromEntries(
      identifiers
          .where((List<dynamic> e) => e[GraphIndex.identifierName] == name)
          .map((List<dynamic> e) => MapEntry(e[GraphIndex.identifierSrc], e)),
    );

    // First check if the identifier is declared directly in this file
    for (final MapEntry<String, List<dynamic>> entry in possibleSrcs.entries) {
      if (entry.key == providerSrc) {
        return DeclarationRef(
          identifier: name,
          srcId: providerSrc,
          providerId: providerSrc,
          type: SymbolType.fromValue(entry.value[GraphIndex.identifierType]),
          srcUri: uriForAsset(providerSrc),
        );
      }
    }
    // trace exports
    final Set<String> visitedSrcs = <String>{};
    final String? src = _traceExportsOf(providerSrc, name, possibleSrcs.keys, visitedSrcs);
    if (src != null) {
      return DeclarationRef(
        identifier: name,
        srcId: src,
        providerId: providerSrc,
        type: SymbolType.fromValue(possibleSrcs[src]![GraphIndex.identifierType]),
        srcUri: uriForAsset(src),
      );
    }
    return null;
  }

  String? _traceExportsOf(String srcId, String identifier, Iterable<String> possibleSrcs, Set<String> visitedSrcs) {
    if (visitedSrcs.contains(srcId)) return null;
    visitedSrcs.add(srcId);

    final List<List> exports = exportsOf(srcId);
    final Set<String> checkableExports = <String>{};
    for (final List export in exports) {
      final String exportedFileSrc = export[GraphIndex.directiveSrc] as String;
      final List hides = export[GraphIndex.directiveHide] as List<dynamic>? ?? const <dynamic>[];
      if (hides.contains(identifier)) continue;
      final List shows = export[GraphIndex.directiveShow] as List<dynamic>? ?? const <dynamic>[];
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
    for (final String exportedFileHash in checkableExports) {
      final String? src = _traceExportsOf(exportedFileHash, identifier, possibleSrcs, visitedSrcs);
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
    final Set<String> identifiers = <String>{};
    for (final List entry in this.identifiers) {
      if (entry[GraphIndex.identifierSrc] == src) {
        identifiers.add(entry[GraphIndex.identifierName]);
      }
    }
    return identifiers;
  }

  Map<String, String> getExposedIdentifiersInside(String fileHash) {
    final Map<String, String> identifiers = <String, String>{};
    for (final List importArr in importsOf(fileHash)) {
      final Set<String> importedIdentifiers = identifiersForAsset(importArr[GraphIndex.directiveSrc]);
      for (final String identifier in importedIdentifiers) {
        identifiers[identifier] = importArr[GraphIndex.directiveSrc];
      }
    }
    return identifiers;
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{...super.toJson(), 'version': version, 'hash': hash};
  }

  // Create from cached data
  factory AssetsGraph.fromCache(Map<String, dynamic> json, String hash) {
    final String? lastUsedHash = json['hash'] as String?;
    final String? version = json['version'] as String?;
    final bool shouldInvalidate = lastUsedHash != hash || version != AssetsGraph.version;
    final AssetsGraph instance = AssetsGraph._fromCache(hash, shouldInvalidate: shouldInvalidate);
    return AssetsScanResults.populate(instance, json);
  }

  void invalidateDigest(String assetId) {
    if (assets.containsKey(assetId)) {
      assets[assetId]![GraphIndex.assetDigest] = null;
    }
  }

  // get any asset that depends on this asset,
  // either via direct import, part-of or via re-exports
  Map<String, List<dynamic>> dependentsOf(String id) {
    final Set<String> visited = <String>{};
    final Set<String> dependents = _dependentsOf(id, visited);
    final Map<String, List> assets = <String, List<dynamic>>{};
    for (final String dep in dependents) {
      if (dep == id) continue;
      final List? arr = this.assets[dep];
      if (arr != null) {
        assets[dep] = arr;
      }
    }
    return assets;
  }

  Set<String> _dependentsOf(String id, Set<String> visited) {
    if (visited.contains(id)) return <String>{};
    visited.add(id);
    final Set<String> dependents = <String>{};
    for (final MapEntry<String, List<List>> entry in directives.entries) {
      for (final List directive in entry.value) {
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

  String? getGeneratorOfOutput(String id) {
    for (final MapEntry<String, Set<String>> entry in outputs.entries) {
      if (entry.value.contains(id)) {
        return entry.key;
      }
    }
    return null;
  }

  List<ExportedSymbol> exportedSymbolsOf(String id) {
    final List<ExportedSymbol> exportedSymbols = <ExportedSymbol>[];
    for (final List entry in identifiers) {
      if (entry[GraphIndex.identifierSrc] == id) {
        final name = entry[GraphIndex.identifierName];
        final SymbolType type = SymbolType.fromValue(entry[GraphIndex.identifierType]);
        exportedSymbols.add(ExportedSymbol(name, type));
      }
    }
    return exportedSymbols;
  }

  bool isAGeneratedSource(String id) {
    for (final MapEntry<String, Set<String>> entry in outputs.entries) {
      if (entry.value.contains(id)) {
        return true;
      }
    }
    return false;
  }

  List<dynamic>? getInputOf(String id) {
    for (final MapEntry<String, Set<String>> entry in outputs.entries) {
      if (entry.value.contains(id)) {
        return assets[entry.key];
      }
    }
    return null;
  }

  void removeOutput(String output) {
    for (final MapEntry<String, Set<String>> entry in outputs.entries) {
      if (entry.value.contains(output)) {
        entry.value.remove(output);
        if (entry.value.isEmpty) {
          outputs.remove(entry.key);
        }
        break;
      }
    }
  }

  Set<ProcessableAsset> getProcessableAssets(PackageFileResolver fileResolver) {
    final Set<ProcessableAsset> processableAssets = <ProcessableAsset>{};
    for (final MapEntry<String, List> entry in assets.entries) {
      if (entry.value[GraphIndex.assetState] != AssetState.processed.index) {
        final TLMFlag tlmFlag = TLMFlag.fromIndex(entry.value[GraphIndex.assetTLMFlag] as int);
        final Asset asset = fileResolver.assetForUri(Uri.parse(entry.value[GraphIndex.assetUri]));
        final AssetState state = AssetState.fromIndex(entry.value[GraphIndex.assetState]);
        processableAssets.add(ProcessableAsset(asset, state, tlmFlag));
      }
    }
    return processableAssets;
  }

  Set<ProcessableAsset> getBuilderProcessableAssets(PackageFileResolver fileResolver) {
    final Set<ProcessableAsset> processableAssets = <ProcessableAsset>{};
    for (final MapEntry<String, List> entry in assets.entries) {
      final int tlmFlag = entry.value[GraphIndex.assetTLMFlag] as int;
      if (tlmFlag == TLMFlag.builder.index || tlmFlag == TLMFlag.both.index) {
        final Asset asset = fileResolver.assetForUri(Uri.parse(entry.value[GraphIndex.assetUri]));
        final AssetState state = AssetState.fromIndex(entry.value[GraphIndex.assetState]);
        processableAssets.add(ProcessableAsset(asset, state, TLMFlag.fromIndex(tlmFlag)));
      }
    }
    return processableAssets;
  }

  bool isBuilderConfigAsset(String id) {
    final tlmFlag = assets[id]?[GraphIndex.assetTLMFlag];
    return tlmFlag == TLMFlag.builder.index || tlmFlag == TLMFlag.both.index;
  }

  bool hasProcessableAssets() {
    for (final List asset in assets.values) {
      if (asset[GraphIndex.assetState] != AssetState.processed.index) {
        return true;
      }
    }
    return false;
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
  final DeclarationRef? declarationRef;

  IdentifierRef(this.name, {this.prefix, this.importPrefix, this.declarationRef});

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
    final StringBuffer buffer = StringBuffer();
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
