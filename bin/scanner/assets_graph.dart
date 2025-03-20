import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:xxh3/xxh3.dart';

import '../resolvers/package_file_resolver.dart';
import 'directive_statement.dart';

class AssetsGraph {
  AssetsGraph(this.packageResolver) : packagesHash = packageResolver.packagesHash, loadedFromCAche = false;

  AssetsGraph._fromCache(this.packageResolver, this.packagesHash, this.loadedFromCAche);

  final PackageFileResolver packageResolver;

  final String packagesHash;
  final bool loadedFromCAche;

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

  String shortenPath(String path) {
    final resolved = packageResolver.uriToPackageImport(Uri(path: path));
    return resolved.substring(8, resolved.length - 5);
  }

  bool isVisited(String path) {
    return visitedAssets.contains(digestPath(shortenPath(path)));
  }

  String addAsset(String assetPath, {bool isVisited = true}) {
    final shortPath = shortenPath(assetPath);
    final hash = digestPath(shortPath);
    if (!assets.containsKey(hash)) {
      assets[hash] = [shortPath, null, 0];
    }
    if (isVisited) visitedAssets.add(hash);
    return hash;
  }

  List<PackageAsset> getDependentsOf(String pathHash) {
    final effectedAssets = <PackageAsset>[];
    for (final entry in imports.entries) {
      for (final importedFile in entry.value) {
        if (importedFile[0] == pathHash) {
          final asset = assets[entry.key]!;
          effectedAssets.add(PackageAsset(entry.key, 'package:${asset[0]}.dart', asset[1], asset[2] == 1));
        }
      }
    }
    return effectedAssets;
  }

  List<PackageAsset> getAssetsForPackage(String package) {
    final assets = <PackageAsset>[];
    for (final entry in this.assets.entries) {
      if (entry.value[0].startsWith('$package/')) {
        assets.add(PackageAsset(entry.key, 'package:${entry.value[0]}.dart', entry.value[1], entry.value[2] == 1));
      }
    }
    return assets;
  }

  String _identifyAsset(String assetPath) {
    final shortPath = shortenPath(assetPath);
    final hash = digestPath(shortPath);
    assert(assets.containsKey(hash), 'Asset not found: $assetPath');
    return hash;
  }

  void updateFileInfo(String assetPath, String content, bool hasAnnotation) {
    final assetHash = _identifyAsset(assetPath);
    final contentHash = xxh3String(Uint8List.fromList(content.codeUnits));
    final assetArr = assets[assetHash]!;
    assetArr[1] = contentHash;
    assetArr[2] = hasAnnotation ? 1 : 0;
  }

  // Add a direct declaration
  void addDeclaration(String identifier, String declaringFile) {
    declaringFile = shortenPath(declaringFile);
    final srcHash = digestPath(declaringFile);
    if (!assets.containsKey(srcHash)) {
      throw Exception('Asset not found: $declaringFile');
    }
    final entry = lookupIdentifier(identifier, srcHash);
    if (entry == null) {
      identifiers.add([identifier, srcHash]);
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

  void addExport(String exportingFile, DirectiveStatement statement) {
    exportingFile = shortenPath(exportingFile);
    final exportingFileHash = digestPath(exportingFile);
    assert(assets.containsKey(exportingFileHash));
    final exportedFileHash = addAsset(statement.uri.path, isVisited: false);
    final exporters = exports[exportingFileHash] ?? [];
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
    exports[exportingFileHash] = exporters;
  }

  void addImport(String importingFile, DirectiveStatement statement) {
    importingFile = shortenPath(importingFile);
    final importingFileHash = digestPath(importingFile);
    assert(assets.containsKey(importingFileHash));
    final importedFileHash = addAsset(statement.uri.path, isVisited: false);
    final importsOfFile = imports[importingFileHash] ?? [];
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
    imports[importingFileHash] = importsOfFile;
  }

  Set<String> getProvidersForIdentifier(String identifier) {
    Set<String> providers = {};
    Set<String> visitedFiles = {};
    // Start with direct declarations
    for (final entry in identifiers) {
      if (entry[0] == identifier) {
        _collectProviders(entry[1], identifier, providers, visitedFiles);
      }
    }

    return providers;
  }

  void _collectProviders(String fileHash, String identifier, Set<String> providers, Set<String> visitedFiles) {
    if (visitedFiles.contains(fileHash)) return;
    visitedFiles.add(fileHash);
    assert(assets.containsKey(fileHash));
    providers.add(assets[fileHash]![0]);
    // Check all files that export this file
    for (var entry in exports.entries) {
      for (final expEntry in entry.value) {
        if (expEntry[0] == fileHash) {
          final shows = expEntry.elementAtOrNull(1) as List<dynamic>? ?? const [];
          final hides = expEntry.elementAtOrNull(2) as List<dynamic>? ?? const [];
          if (shows.isNotEmpty && !shows.contains(identifier)) continue;
          if (hides.isNotEmpty && hides.contains(identifier)) continue;
          _collectProviders(entry.key, identifier, providers, visitedFiles);
        }
      }
    }
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

  // Get all identifiers provided by a specific file
  Set<String> getIdentifiersOfFile(String filePath) {
    return {};
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

    // remove all imports that reference this asset
    imports.removeWhere((key, value) {
      value.removeWhere((element) => element[0] == pathHash);
      return value.isEmpty;
    });

    // remove all identifiers that reference this asset
    identifiers.removeWhere((element) => element[1] == pathHash);
  }

  // Create from cached data if valid
  factory AssetsGraph.fromCache(Map<String, dynamic> json, PackageFileResolver packageResolver) {
    final packagesHash = json['packagesHash'] as String;
    final version = json['version'] as String;
    if (packagesHash != packageResolver.packagesHash || version != AssetsGraph.version) {
      return AssetsGraph(packageResolver);
    }
    final graph = AssetsGraph._fromCache(packageResolver, packagesHash, true);
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

class PackageAsset {
  PackageAsset(this.pathHash, this.path, this.contentHash, this.hasAnnotation);

  final String path;
  final String pathHash;
  final String contentHash;
  final bool hasAnnotation;

  @override
  String toString() {
    return 'PackageAsset{path: $path, hasAnnotation: $hasAnnotation}';
  }
}
