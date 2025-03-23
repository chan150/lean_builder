import 'dart:typed_data';

import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:collection/collection.dart';
import 'package:xxh3/xxh3.dart';

import 'directive_statement.dart';

abstract class ScanResults {
  // [src, content hash, has annotation]
  Map<String, List<dynamic>> get assets;

  // [identifier, srcHash]
  List<List<dynamic>> get identifiers;

  // [exporting file, [exported file, show, hide]]
  Map<String, List<List<dynamic>>> get exports;

  // [importing file, [imported file, show, hide]]
  Map<String, List<List<dynamic>>> get imports;

  // Set of visited assets
  Set<String> get visitedAssets;

  bool isVisited(String fileId);

  void addImport(AssetFile importingFile, DirectiveStatement statement);

  void addExport(AssetFile exportingFile, DirectiveStatement statement);

  void merge(ScanResults results);

  void addAsset(AssetFile asset, {bool isVisited = true});

  void addDeclaration(String identifier, AssetFile declaringFile);

  void removeAsset(String id);

  void updateFileInfo(AssetFile asset, {required Uint8List content, bool hasAnnotation = false});
}

class AssetsScanResults extends ScanResults {
  final _listEquals = const ListEquality().equals;

  @override
  final Map<String, List<dynamic>> assets = {};

  @override
  final List<List<dynamic>> identifiers = [];

  @override
  final Map<String, List<List<dynamic>>> exports = {};

  @override
  final Map<String, List<List<dynamic>>> imports = {};

  @override
  final Set<String> visitedAssets = {};

  AssetsScanResults();

  @override
  bool isVisited(String fileId) {
    return visitedAssets.contains(fileId);
  }

  @override
  void merge(ScanResults results) {
    assets.addAll(results.assets);
    identifiers.addAll(results.identifiers);
    exports.addAll(results.exports);
    imports.addAll(results.imports);
    visitedAssets.addAll(results.visitedAssets);
  }

  @override
  String addAsset(AssetFile asset, {bool isVisited = true}) {
    if (!assets.containsKey(asset.id)) {
      assets[asset.id] = [asset.shortPath.toString(), null, 0];
    }
    if (isVisited) visitedAssets.add(asset.id);
    return asset.id;
  }

  @override
  void addExport(AssetFile exportingFile, DirectiveStatement statement) {
    assert(assets.containsKey(exportingFile.id));
    final exportedFileHash = addAsset(statement.asset, isVisited: false);
    final exporters = exports[exportingFile.id] ?? [];
    if (exporters.isNotEmpty) {
      for (final exporter in exporters) {
        final shows = exporter.elementAtOrNull(1);
        final hides = exporter.elementAtOrNull(2);
        if (exporter[0] == exportedFileHash &&
            _listEquals(shows, statement.show) &&
            _listEquals(hides, statement.hide)) {
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

  @override
  void addImport(AssetFile importingFile, DirectiveStatement statement) {
    assert(assets.containsKey(importingFile.id));
    final importedFileHash = addAsset(statement.asset, isVisited: false);
    final importsOfFile = imports[importingFile.id] ?? [];
    if (importsOfFile.isNotEmpty) {
      for (final importedFile in importsOfFile) {
        final shows = importedFile.elementAtOrNull(1);
        final hides = importedFile.elementAtOrNull(2);
        if (importedFile[0] == importedFileHash &&
            _listEquals(shows, statement.show) &&
            _listEquals(hides, statement.hide)) {
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

  @override
  void addDeclaration(String identifier, AssetFile declaringFile) {
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

  @override
  void updateFileInfo(AssetFile asset, {required Uint8List content, bool hasAnnotation = false}) {
    assert(assets.containsKey(asset.id), 'Asset not found: $asset');
    final contentHash = asset.root ? xxh3String(content) : null;
    final assetArr = assets[asset.id]!;
    assetArr[1] = contentHash;
    assetArr[2] = hasAnnotation ? 1 : 0;
  }

  @override
  void removeAsset(String id) {
    assets.remove(id);
    visitedAssets.remove(id);
    // remove all exports that reference this asset
    exports.removeWhere((key, value) {
      value.removeWhere((element) => element[0] == id);
      return value.isEmpty;
    });
    imports.remove(id);
    // remove all identifiers that reference this asset
    identifiers.removeWhere((element) => element[1] == id);
  }

  Map<String, dynamic> toJson() {
    return {'assets': assets, 'identifiers': identifiers, 'exports': exports, 'imports': imports};
  }

  static T populate<T extends ScanResults>(T instance, Map<String, dynamic> json) {
    instance.assets.addAll((json['assets'] as Map<String, dynamic>).cast<String, List<dynamic>>());
    instance.visitedAssets.addAll(instance.assets.keys);
    for (final export in json['exports'].entries) {
      instance.exports[export.key] = (export.value as List<dynamic>).cast<List<dynamic>>();
    }
    for (final import in json['imports'].entries) {
      instance.imports[import.key] = (import.value as List<dynamic>).cast<List<dynamic>>();
    }
    instance.identifiers.addAll((json['identifiers'] as List<dynamic>).cast<List<dynamic>>());
    return instance;
  }

  factory AssetsScanResults.fromJson(Map<String, dynamic> json) {
    return populate(AssetsScanResults(), json);
  }
}
