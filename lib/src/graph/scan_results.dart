import 'dart:collection';
import 'dart:typed_data';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:collection/collection.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:xxh3/xxh3.dart';

import 'directive_statement.dart';

class GraphIndex {
  const GraphIndex._();

  // asset
  static const assetUri = 0;
  static const assetDigest = 1;
  // 0 no annotation, 1 has regular annotation, 2 has builder annotation, 3 has both
  /// represents the values of [TLMFlag]
  static const assetTLMFlag = 2;

  /// represents the values of [AssetState]
  static const assetState = 3;
  static const assetLibraryName = 4;

  // identifier
  static const identifierName = 0;
  static const identifierSrc = 1;
  static const identifierType = 2;

  // directive
  static const directiveType = 0;
  static const directiveSrc = 1;
  static const directiveStringUri = 2;
  static const directiveShow = 3;
  static const directiveHide = 4;
  static const directivePrefix = 5;
  static const directiveDeferred = 6;
}

abstract class ScanResults {
  HashMap<String, List<dynamic> /*uri, digest, annotation-flag,library-name?*/> get assets;

  List<List<dynamic> /*name, src, type*/> get identifiers;

  HashMap<String, List<List<dynamic> /*type, src, stringUri, show, hide, prefix?, deferred?*/>> get directives;

  List<List<dynamic> /*type, src, stringUri, show, hide*/> exportsOf(String fileId, {bool includeParts = true});

  List<List<dynamic> /*type, src, stringUri*/> partsOf(String fileId);

  List<dynamic>? /*type, src, stringUri*/ partOfOf(String fileId);

  List<List<dynamic> /*type, src, stringUri, show, hide ,prefix? ,deferred?*/> importsOf(
    String fileId, {
    bool includeParts = true,
  });

  String getParentSrc(String fileId);

  /// the generated outputs sources of a file
  HashMap<String, Set<String>> get outputs;

  bool isVisited(String fileId);

  void addDirective(Asset asset, DirectiveStatement statement);

  void merge(ScanResults results);

  void addAsset(Asset asset);

  void addDeclaration(String identifier, Asset declaringFile, TopLevelIdentifierType type);

  void removeAsset(String id);

  void updateAssetInfo(Asset asset, {required Uint8List content, int annotationFlag = 0, String? libraryName});

  void updateAssetState(String id, AssetState state);

  bool isPart(String id);

  Set<String> importPrefixesOf(String id);

  void addLibraryPartOf(String uriString, Asset asset);
}

class AssetsScanResults extends ScanResults {
  final _listEquals = const ListEquality().equals;

  @override
  final HashMap<String, List<dynamic>> assets = HashMap();

  @override
  final List<List<dynamic>> identifiers = [];

  @override
  List<List<dynamic>> exportsOf(String fileId, {bool includeParts = true}) {
    final fileDirectives = directives[fileId];
    if (fileDirectives == null) return [];
    return List.of(
      fileDirectives.where((e) {
        if (e[GraphIndex.directiveType] == DirectiveStatement.export) {
          return true;
        } else if (includeParts && e[GraphIndex.directiveType] == DirectiveStatement.part) {
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
    return List.of(fileDirectives.where((e) => e[GraphIndex.directiveType] == DirectiveStatement.part));
  }

  @override
  List<dynamic>? partOfOf(String fileId) {
    final fileDirectives = directives[fileId];
    if (fileDirectives == null) return null;
    return fileDirectives
        .where(
          (e) =>
              e[GraphIndex.directiveType] == DirectiveStatement.partOf ||
              e[GraphIndex.directiveType] == DirectiveStatement.partOfLibrary,
        )
        .firstOrNull;
  }

  @override
  List<List<dynamic>> importsOf(String fileId, {bool includeParts = true}) {
    final fileDirectives = directives[getParentSrc(fileId)];
    if (fileDirectives == null) return const [];
    return List.of(
      fileDirectives.where((e) {
        if (e[GraphIndex.directiveType] == DirectiveStatement.import) {
          return true;
        } else if (includeParts && e[GraphIndex.directiveType] == DirectiveStatement.part) {
          return true;
        }
        return false;
      }),
    );
  }

  AssetsScanResults();

  @override
  bool isVisited(String fileId) {
    return assets.containsKey(fileId) && assets[fileId]?[GraphIndex.assetDigest] != null;
  }

  @override
  void merge(ScanResults results) {
    for (final asset in results.assets.entries) {
      if (assets[asset.key]?[GraphIndex.assetDigest] == null) {
        assets[asset.key] = asset.value;
      }
    }
    // [type, src, stringUri, show, hide, prefix?, deferred?]]
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
                (newDir[GraphIndex.directiveType] == DirectiveStatement.export ||
                    newDir[GraphIndex.directiveType] == DirectiveStatement.import);

            if (newDir[GraphIndex.directiveType] == exDir[GraphIndex.directiveType] &&
                newDir[GraphIndex.directiveSrc] == exDir[GraphIndex.directiveSrc] &&
                (!hasNameCombinator ||
                    (_listEquals(newDir[GraphIndex.directiveShow], exDir[GraphIndex.directiveShow]) &&
                        _listEquals(newDir[GraphIndex.directiveHide], exDir[GraphIndex.directiveHide]) &&
                        newDir.elementAtOrNull(GraphIndex.directivePrefix) ==
                            exDir.elementAtOrNull(GraphIndex.directivePrefix)))) {
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
    identifiers.addAll(results.identifiers);
  }

  @override
  String addAsset(Asset asset) {
    if (!assets.containsKey(asset.id)) {
      assets[asset.id] = [asset.shortUri.toString(), null, 0, 0];
    }
    return asset.id;
  }

  @override
  void addDirective(Asset src, DirectiveStatement statement) {
    assert(assets.containsKey(src.id));
    final directiveSrcId = addAsset(statement.asset);
    final srcDirectives = directives[src.id] ?? [];
    if (srcDirectives.isNotEmpty) {
      for (final directive in srcDirectives) {
        final directiveType = directive[GraphIndex.directiveType];

        /// return early if the directive is already present
        if (directiveType == DirectiveStatement.part &&
            statement.type == DirectiveStatement.partOf &&
            directive[GraphIndex.directiveSrc] == statement.asset.id) {
          return;
        }

        final shows = directive[GraphIndex.directiveShow];
        final hides = directive[GraphIndex.directiveHide];
        final prefix = directive.elementAtOrNull(GraphIndex.directivePrefix);
        if (directive[GraphIndex.directiveSrc] == directiveSrcId &&
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
      directiveSrcId,
      statement.stringUri,
      statement.show.isEmpty ? null : statement.show,
      statement.hide.isEmpty ? null : statement.hide,
      if (statement.prefix != null) statement.prefix,
      if (statement.deferred) 1,
    ]);
    directives[src.id] = srcDirectives;
  }

  @override
  void addDeclaration(String identifier, Asset declaringFile, TopLevelIdentifierType type) {
    if (!assets.containsKey(declaringFile.id)) {
      throw Exception('Asset not found: $declaringFile');
    }
    final entry = lookupIdentifier(identifier, declaringFile.id);
    if (entry == null) {
      identifiers.add([identifier, declaringFile.id, type.value]);
    }
  }

  List<dynamic>? lookupIdentifier(String identifier, String src) {
    for (final entry in identifiers) {
      if (entry[GraphIndex.identifierName] == identifier && entry[GraphIndex.identifierSrc] == src) {
        return entry;
      }
    }
    return null;
  }

  @override
  void updateAssetInfo(Asset asset, {required Uint8List content, int annotationFlag = 0, String? libraryName}) {
    assert(assets.containsKey(asset.id), 'Asset not found: $asset');
    final assetArr = assets[asset.id]!;
    assetArr[GraphIndex.assetDigest] = xxh3String(content);
    assetArr[GraphIndex.assetTLMFlag] = annotationFlag;
    assetArr[GraphIndex.assetState] = AssetState.unProcessed.index;
    if (libraryName != null) {
      if (assetArr.length < GraphIndex.assetLibraryName + 1) {
        assetArr.add(libraryName);
      } else {
        assetArr[GraphIndex.assetLibraryName] = libraryName;
      }
    }
  }

  @override
  void removeAsset(String id) {
    assets.remove(id);
    // remove all directives that reference this asset
    directives.removeWhere((key, value) {
      value.removeWhere((element) => element[GraphIndex.directiveSrc] == id);
      return value.isEmpty;
    });
    directives.remove(id);
    // remove all identifiers that reference this asset
    identifiers.removeWhere((element) => element[GraphIndex.identifierSrc] == id);
    outputs.remove(id);
  }

  Map<String, dynamic> toJson() {
    return {
      'assets': assets,
      'identifiers': identifiers,
      'directives': directives,
      'outputs': outputs.map((key, value) => MapEntry(key, value.toList())),
    };
  }

  static T populate<T extends ScanResults>(T instance, Map<String, dynamic> json) {
    instance.assets.addAll((json['assets'] as Map<String, dynamic>).cast<String, List<dynamic>>());
    for (final directive in (json['directives'] as Map<String, dynamic>).entries) {
      instance.directives[directive.key] = (directive.value as List<dynamic>).cast<List<dynamic>>();
    }
    instance.identifiers.addAll((json['identifiers'] as List<dynamic>).cast<List<dynamic>>());
    for (final entry in (json['outputs'] as Map<String, dynamic>).entries) {
      instance.outputs[entry.key] = (entry.value as List<dynamic>).cast<String>().toSet();
    }
    return instance;
  }

  factory AssetsScanResults.fromJson(Map<String, dynamic> json) {
    return populate(AssetsScanResults(), json);
  }

  @override
  final HashMap<String, List<List>> directives = HashMap();

  @override
  final HashMap<String, Set<String>> outputs = HashMap();

  @override
  String toString() {
    return 'AssetsScanResults{assets: $assets, identifiers: $identifiers, directives: $directives} ';
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

  @override
  Set<String> importPrefixesOf(String id) {
    final prefixes = <String>{};
    String targetSrc = getParentSrc(id);
    for (final import in importsOf(targetSrc, includeParts: false)) {
      final prefix = import.elementAtOrNull(GraphIndex.directivePrefix);
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
  void addLibraryPartOf(String stringUri, Asset asset) {
    final fileDirectives = [...?directives[asset.id]];
    if (fileDirectives.isEmpty) {
      directives[asset.id] = [
        [DirectiveStatement.partOfLibrary, '', stringUri],
      ];
    } else {
      // avoid duplicate entries
      for (final directive in fileDirectives) {
        if (directive[GraphIndex.directiveType] == DirectiveStatement.partOfLibrary &&
            directive[GraphIndex.directiveStringUri] == stringUri) {
          return;
        }
      }
      directives[asset.id] = [
        ...fileDirectives,
        [DirectiveStatement.partOfLibrary, '', stringUri],
      ];
    }
  }

  @override
  String getParentSrc(String fileId) {
    final partOf = partOfOf(fileId);
    if (partOf == null) return fileId;
    final type = partOf[GraphIndex.directiveType];
    if (type == DirectiveStatement.partOf) {
      return partOf[GraphIndex.directiveSrc];
    } else if (type == DirectiveStatement.partOfLibrary) {
      for (final asset in assets.entries) {
        if (asset.value.length > GraphIndex.assetLibraryName &&
            asset.value[GraphIndex.assetLibraryName] == partOf[GraphIndex.directiveStringUri]) {
          return asset.key;
        }
      }
      return fileId;
    }
    return fileId;
  }

  @override
  void updateAssetState(String id, AssetState state) {
    if (assets.containsKey(id)) {
      assets[id]![GraphIndex.assetState] = state.index;
    } else {
      throw Exception('Asset not found: $id');
    }
  }
}

enum TopLevelIdentifierType {
  unknown(-1),
  $class(0),
  $mixin(1),
  $extension(2),
  $enum(3),
  $typeAlias(4),
  $function(5),
  $variable(6);

  final int value;

  bool get representsInterfaceType {
    return this == $class || this == $mixin || this == $enum;
  }

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

  static TopLevelIdentifierType fromDeclaration(NamedCompilationUnitMember node) {
    if (node is ClassDeclaration) {
      return $class;
    } else if (node is MixinDeclaration) {
      return $mixin;
    } else if (node is ExtensionDeclaration) {
      return $extension;
    } else if (node is EnumDeclaration) {
      return $enum;
    } else if (node is TypeAlias) {
      return $typeAlias;
    } else if (node is FunctionDeclaration) {
      return $function;
    } else {
      throw ArgumentError('Invalid value: $node');
    }
  }

  bool get isInterface => this == $class || this == $mixin || this == $extension || this == $enum || this == $typeAlias;
}

enum AssetState {
  processed,
  unProcessed,
  deleted;

  static AssetState fromIndex(int index) {
    return AssetState.values[index];
  }
}
