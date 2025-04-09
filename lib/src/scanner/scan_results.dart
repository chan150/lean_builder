import 'dart:typed_data';

import 'package:analyzer/dart/ast/token.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:collection/collection.dart';
import 'package:xxh3/xxh3.dart';

import 'directive_statement.dart';

abstract class ScanResults {
  // [src, content-hash, has-annotation, library-name?]
  Map<String, List<dynamic>> get assets;

  // [identifier, srcHash]
  List<List<dynamic>> get identifiers;

  // All kinds of directives inside the file
  // export, import, part, part of
  // [exporting file, [type, uri, show, hide, prefix]]
  Map<String, List<List<dynamic>>> get directives;

  // [exporting file, [exported file, show, hide]]
  List<List<dynamic>> exportsOf(String fileId, {bool includeParts = true});

  // [exporting file, [exported file, show, hide]]
  List<List<dynamic>> partsOf(String fileId);

  List<dynamic>? partOfOf(String fileId);

  String getParentSrc(String fileId);

  // [importing file, [imported file, show, hide, prefix]]
  List<List<dynamic>> importsOf(String fileId, {bool includeParts = true});

  // Set of visited assets
  Set<String> get visitedAssets;

  bool isVisited(String fileId);

  void addDirective(AssetSrc asset, DirectiveStatement statement);

  void merge(ScanResults results);

  void addAsset(AssetSrc asset, {bool isVisited = true});

  void addDeclaration(String identifier, AssetSrc declaringFile, TopLevelIdentifierType type);

  void removeAsset(String id);

  void updateAssetInfo(AssetSrc asset, {required Uint8List content, bool hasAnnotation = false, String? libraryName});

  bool isPart(String id);

  Set<String> importPrefixesOf(String id);

  void addLibraryPartOf(String uriString, AssetSrc asset);
}

class AssetsScanResults extends ScanResults {
  final _listEquals = const ListEquality().equals;

  @override
  final Map<String, List<dynamic>> assets = {};

  @override
  final List<List<dynamic>> identifiers = [];

  @override
  List<List<dynamic>> exportsOf(String fileId, {bool includeParts = true}) {
    final fileDirectives = directives[fileId];
    if (fileDirectives == null) return [];
    return List.of(
      fileDirectives.where((e) {
        if (e[0] == DirectiveStatement.export) {
          return true;
        } else if (includeParts && e[0] == DirectiveStatement.part) {
          return true;
        }
        return false;
      }),
    );
  }

  @override
  List<List<dynamic>> partsOf(String fileId) {
    final fileDirectives = directives[fileId];
    if (fileDirectives == null) return const [];
    return List.of(fileDirectives.where((e) => e[0] == DirectiveStatement.part));
  }

  @override
  List<dynamic>? partOfOf(String fileId) {
    final fileDirectives = directives[fileId];
    if (fileDirectives == null) return null;
    return fileDirectives
        .where((e) => e[0] == DirectiveStatement.partOf || e[0] == DirectiveStatement.partOfLibrary)
        .firstOrNull;
  }

  @override
  List<List<dynamic>> importsOf(String fileId, {bool includeParts = true}) {
    final fileDirectives = directives[getParentSrc(fileId)];
    if (fileDirectives == null) return const [];
    return List.of(
      fileDirectives.where((e) {
        if (e[0] == DirectiveStatement.import) {
          return true;
        } else if (includeParts && e[0] == DirectiveStatement.part) {
          return true;
        }
        return false;
      }),
    );
  }

  @override
  final Set<String> visitedAssets = {};

  AssetsScanResults();

  @override
  bool isVisited(String fileId) {
    return visitedAssets.contains(fileId);
  }

  @override
  void merge(ScanResults results) {
    for (final asset in results.assets.entries) {
      if (assets[asset.key]?[1] == null) {
        assets[asset.key] = asset.value;
      }
    }

    for (final directive in results.directives.entries) {
      if (!directives.containsKey(directive.key)) {
        directives[directive.key] = directive.value;
      } else {
        final newDirectives = directive.value;
        final allDirections = List.of(directives[directive.key]!);
        for (final newDir in newDirectives) {
          bool isDuplicate = false;
          for (final exDir in allDirections) {
            final hasNameCombinator =
                (newDir[0] == DirectiveStatement.export || newDir[0] == DirectiveStatement.import);

            if (newDir[0] == exDir[0] &&
                newDir[1] == exDir[1] &&
                (!hasNameCombinator ||
                    (_listEquals(newDir[2], exDir[2]) &&
                        _listEquals(newDir[3], exDir[3]) &&
                        newDir.elementAtOrNull(4) == exDir.elementAtOrNull(4)))) {
              isDuplicate = true;
              break;
            }
          }
          // If the directive already exists, skip adding it
          if (!isDuplicate) {
            allDirections.add(newDir);
          }
        }
        directives[directive.key] = allDirections;
      }
    }

    visitedAssets.addAll(results.visitedAssets);
    identifiers.addAll(results.identifiers);
  }

  @override
  String addAsset(AssetSrc asset, {bool isVisited = true}) {
    if (!assets.containsKey(asset.id)) {
      assets[asset.id] = [asset.shortPath.toString(), null, 0];
    }
    if (isVisited) visitedAssets.add(asset.id);
    return asset.id;
  }

  @override
  void addDirective(AssetSrc src, DirectiveStatement statement) {
    assert(assets.containsKey(src.id));
    final directiveHash = addAsset(statement.asset, isVisited: false);
    final srcDirectives = directives[src.id] ?? [];
    if (srcDirectives.isNotEmpty) {
      for (final directive in srcDirectives) {
        final directiveType = directive.elementAtOrNull(0);

        /// return early if the directive is already present
        if (directiveType == DirectiveStatement.part &&
            statement.type == DirectiveStatement.partOf &&
            directive[1] == statement.asset.id) {
          return;
        }

        final shows = directive.elementAtOrNull(2);
        final hides = directive.elementAtOrNull(3);
        final prefix = directive.elementAtOrNull(4);
        if (directive[1] == directiveHash &&
            directiveType == statement.type &&
            prefix == statement.prefix &&
            _listEquals(shows, statement.show) &&
            _listEquals(hides, statement.hide)) {
          return;
        }
      }
    }
    srcDirectives.add([
      statement.type,
      directiveHash,
      statement.show.isEmpty ? null : statement.show,
      statement.hide.isEmpty ? null : statement.hide,
      if (statement.prefix != null) statement.prefix,
    ]);
    directives[src.id] = srcDirectives;
  }

  @override
  void addDeclaration(String identifier, AssetSrc declaringFile, TopLevelIdentifierType type) {
    if (!assets.containsKey(declaringFile.id)) {
      throw Exception('Asset not found: $declaringFile');
    }
    final entry = lookupIdentifier(identifier, declaringFile.id);
    if (entry == null) {
      identifiers.add([identifier, declaringFile.id, type.value]);
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
  void updateAssetInfo(AssetSrc asset, {required Uint8List content, bool hasAnnotation = false, String? libraryName}) {
    assert(assets.containsKey(asset.id), 'Asset not found: $asset');
    final assetArr = assets[asset.id]!;
    assetArr[1] = xxh3String(content);
    assetArr[2] = hasAnnotation ? 1 : 0;
    if (libraryName != null) {
      if (assetArr.length < 4) {
        assetArr.add(libraryName);
      } else {
        assetArr[3] = libraryName;
      }
    }
  }

  @override
  void removeAsset(String id) {
    assets.remove(id);
    visitedAssets.remove(id);
    // remove all directives that reference this asset
    directives.removeWhere((key, value) {
      value.removeWhere((element) => element[1] == id);
      return value.isEmpty;
    });
    directives.remove(id);
    // remove all identifiers that reference this asset
    identifiers.removeWhere((element) => element[1] == id);
  }

  Map<String, dynamic> toJson() {
    return {'assets': assets, 'identifiers': identifiers, 'directives': directives};
  }

  static T populate<T extends ScanResults>(T instance, Map<String, dynamic> json) {
    instance.assets.addAll((json['assets'] as Map<String, dynamic>).cast<String, List<dynamic>>());
    instance.visitedAssets.addAll(instance.assets.keys);
    for (final directive in json['directives'].entries) {
      instance.directives[directive.key] = (directive.value as List<dynamic>).cast<List<dynamic>>();
    }
    instance.identifiers.addAll((json['identifiers'] as List<dynamic>).cast<List<dynamic>>());
    return instance;
  }

  factory AssetsScanResults.fromJson(Map<String, dynamic> json) {
    return populate(AssetsScanResults(), json);
  }

  @override
  final Map<String, List<List>> directives = {};

  @override
  String toString() {
    return 'AssetsScanResults{assets: $assets, identifiers: $identifiers, directives: $directives}';
  }

  @override
  Set<String> importPrefixesOf(String id) {
    final prefixes = <String>{};
    String targetSrc = getParentSrc(id);
    for (final import in importsOf(targetSrc, includeParts: false)) {
      final prefix = import.elementAtOrNull(4);
      if (prefix != null) {
        prefixes.add(prefix);
      }
    }
    return prefixes;
  }

  @override
  bool isPart(String id) {
    return partOfOf(id) != null;
  }

  @override
  void addLibraryPartOf(String uriString, AssetSrc asset) {
    final fileDirectives = [...?directives[asset.id]];
    if (fileDirectives.isEmpty) {
      directives[asset.id] = [
        [DirectiveStatement.partOfLibrary, uriString],
      ];
    } else {
      // avoid duplicate entries
      for (final directive in fileDirectives) {
        if (directive[0] == DirectiveStatement.partOfLibrary && directive[1] == uriString) {
          return;
        }
      }
      directives[asset.id] = [
        ...fileDirectives,
        [DirectiveStatement.partOfLibrary, uriString],
      ];
    }
  }

  @override
  String getParentSrc(String fileId) {
    final partOf = partOfOf(fileId);
    if (partOf == null) return fileId;
    if (partOf[0] == DirectiveStatement.partOf) {
      return partOf[1];
    } else if (partOf[0] == DirectiveStatement.partOfLibrary) {
      for (final asset in assets.entries) {
        if (asset.value.length > 3 && asset.value[3] == partOf[1]) {
          return asset.key;
        }
      }
      return fileId;
    }
    return fileId;
  }
}

enum TopLevelIdentifierType {
  $class(0),
  $mixin(1),
  $extension(2),
  $enum(3),
  $typeAlias(4),
  $function(5),
  $variable(6);

  final int value;

  const TopLevelIdentifierType(this.value);

  static TopLevelIdentifierType fromValue(int value) {
    switch (value) {
      case 0:
        return $class;
      case 1:
        return $mixin;
      case 2:
        return $extension;
      case 3:
        return $enum;
      case 4:
        return $typeAlias;
      case 5:
        return $function;
      case 6:
        return $variable;
      default:
        throw ArgumentError('Invalid value: $value');
    }
  }

  static TopLevelIdentifierType fromKeyword(TokenType type) {
    switch (type) {
      case Keyword.CLASS:
        return $class;
      case Keyword.MIXIN:
        return $mixin;
      case Keyword.EXTENSION:
        return $extension;
      case Keyword.ENUM:
        return $enum;
      case Keyword.TYPEDEF:
        return $typeAlias;
      default:
        throw ArgumentError('Invalid value: $type');
    }
  }

  bool get isInterface => this == $class || this == $mixin || this == $extension || this == $enum || this == $typeAlias;
}
