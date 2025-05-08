import 'dart:collection' show HashMap;
import 'dart:typed_data' show Uint8List;

import 'package:collection/collection.dart' show ListEquality;
import 'package:xxh3/xxh3.dart' show xxh3String;
import 'package:lean_builder/src/asset/asset.dart';

import 'directive_statement.dart';

/// {@template graph_index}
/// Constants for accessing data within the graph's data structures.
///
/// These constants define the indices used to access specific pieces of
/// information within the lists and maps that represent the graph's data.
/// {@endtemplate}
class GraphIndex {
  const GraphIndex._();

  /// {@template graph_index.asset}
  /// Indices for asset-related information.
  /// {@endtemplate}
  static const int assetUri = 0;

  /// Represents the values of [Asset.digest].
  static const int assetDigest = 1;

  /// {@template graph_index.asset_tlm_flag}
  /// Represents the values of [TLMFlag].
  ///
  /// 0: no annotation
  /// 1: has regular annotation
  /// 2: has builder annotation
  /// 3: has both
  /// {@endtemplate}
  static const int assetTLMFlag = 2;

  /// {@template graph_index.asset_state}
  /// Represents the values of [AssetState].
  /// {@endtemplate}
  static const int assetState = 3;

  /// Represents the values of [Asset.libraryName].
  static const int assetLibraryName = 4;

  /// {@template graph_index.identifier}
  /// Indices for identifier-related information.
  /// {@endtemplate}
  static const int identifierName = 0;

  /// Represents the values of [Asset.id].
  static const int identifierSrc = 1;

  /// Represents the values of [ReferenceType].
  static const int identifierType = 2;

  /// {@template graph_index.directive}
  /// Indices for directive-related information.
  /// {@endtemplate}
  static const int directiveType = 0;

  /// represents the target asset id the directive is pointing to
  static const int directiveSrc = 1;

  /// represents the string uri of the directive
  static const int directiveStringUri = 2;

  /// represents the show combinator of the directive
  static const int directiveShow = 3;

  /// represents the hide combinator of the directive
  static const int directiveHide = 4;

  /// represents the prefix of the directive
  static const int directivePrefix = 5;

  /// represents the deferred flag of the directive
  static const int directiveDeferred = 6;
}

/// {@template scan_results}
/// The `ScanResults` class is an abstract class that defines the structure
/// and behavior of scan results in this Dart application.
///
/// It provides methods to manage and manipulate scan results,
/// including adding and removing assets,
/// updating asset information,
/// and merging results from different scans.
/// {@endtemplate}
///
abstract class ScanResults {
  /// Represents the all the assets the scanner has seen.
  /// including the assets that are not processed yet (directives)
  HashMap<String, List<dynamic> /*uri, digest, tlm-flag, state,library-name?*/>
  get assets;

  /// Represents the identifiers that have been found in the scanned assets.
  List<List<dynamic> /*name, src, type*/> get identifiers;

  /// Represents the directives that have been found in the scanned assets.
  ///
  /// this is of every asset and it's directives
  /// it's mainly used to detect relationships between assets
  HashMap<
    String,
    List<List<dynamic> /*type, src, stringUri, show, hide, prefix?, deferred?*/>
  >
  get directives;

  /// Returns a list of all the exports and parts of a file.
  ///
  /// This has an option to include parts because in some contexts of this application
  /// parts are considered exports as they export their references to the main file.
  List<List<dynamic> /*type, src, stringUri, show, hide*/> exportsOf(
    String fileId, {
    bool includeParts = true,
  });

  /// Returns a list of all the parts of a file.
  List<List<dynamic> /*type, src, stringUri*/> partsOf(String fileId);

  /// Returns a the first part-of directive of a file.
  List<dynamic>? /*type, src, stringUri*/ partOfOf(String fileId);

  /// Returns a list of all the imports and parts of a file.
  ///
  /// This has an option to include parts because in some contexts of this application
  /// parts are considered imports as they import from the main file.
  List<List<dynamic> /*type, src, stringUri, show, hide ,prefix? ,deferred?*/>
  importsOf(String fileId, {bool includeParts = true});

  /// Returns the parent source of a file.
  ///
  /// This is used to get the main file of a part file.
  /// it returns [fileId] if the file is not a part.
  String getParentSrc(String fileId);

  /// the generated outputs sources of a file
  HashMap<String, Set<String>> get outputs;

  /// Returns true if the file has been visited.
  ///
  /// Typically we know if asset has been visited by checking if it has a digest of it's content
  bool isVisited(String fileId);

  /// Adds a directive to the asset graph.
  void addDirective(Asset asset, DirectiveStatement statement);

  /// Merges the results of another scan into this one.
  void merge(ScanResults results);

  /// Adds an asset to the asset graph.
  void addAsset(Asset asset);

  /// Adds A declaration to the asset graph.
  void addDeclaration(
    String identifier,
    Asset declaringFile,
    ReferenceType type,
  );

  /// Removes an asset from the asset graph
  ///
  /// This will remove all references to the asset from the graph
  /// including directives, identifiers and outputs
  void removeAsset(String id);

  /// Updates the asset information in the asset graph.
  void updateAssetInfo(
    Asset asset, {
    required Uint8List content,
    int tlmFlag = 0,
    String? libraryName,
  });

  /// Updates the asset state in the asset graph.
  void updateAssetState(String id, AssetState state);

  /// Returns all the prefixes of the imports of a file.
  ///
  /// if id is a part file, it returns the prefixes of the imports of the main file.
  Set<String> importPrefixesOf(String id);

  /// Adds a library part-of directive to the asset graph.
  ///
  /// this is treated differently than the regular part-of directive
  /// as library part-of do not directly point to an actual file
  void addLibraryPartOf(String uriString, Asset asset);
}

/// The Default implementation of [ScanResults].
class AssetsScanResults extends ScanResults {
  final bool Function(List<dynamic>? list1, List<dynamic>? list2) _listEquals =
      const ListEquality<dynamic>().equals;

  @override
  final HashMap<String, List<dynamic>> assets =
      HashMap<String, List<dynamic>>();

  @override
  final List<List<dynamic>> identifiers = <List<dynamic>>[];

  @override
  List<List<dynamic>> exportsOf(String fileId, {bool includeParts = true}) {
    final List<List<dynamic>>? fileDirectives = directives[fileId];
    if (fileDirectives == null) return <List<dynamic>>[];
    return List<List<dynamic>>.of(
      fileDirectives.where((List<dynamic> e) {
        if (e[GraphIndex.directiveType] == DirectiveStatement.export) {
          return true;
        } else if (includeParts &&
            e[GraphIndex.directiveType] == DirectiveStatement.part) {
          return true;
        }
        return false;
      }),
    );
  }

  @override
  List<List<dynamic>> partsOf(String fileId) {
    final List<List<dynamic>>? fileDirectives = directives[fileId];
    if (fileDirectives == null) return const <List<dynamic>>[];
    return List<List<dynamic>>.of(
      fileDirectives.where(
        (List<dynamic> e) =>
            e[GraphIndex.directiveType] == DirectiveStatement.part,
      ),
    );
  }

  @override
  List<dynamic>? partOfOf(String fileId) {
    final List<List<dynamic>>? fileDirectives = directives[fileId];
    if (fileDirectives == null) return null;
    return fileDirectives
        .where(
          (List<dynamic> e) =>
              e[GraphIndex.directiveType] == DirectiveStatement.partOf ||
              e[GraphIndex.directiveType] == DirectiveStatement.partOfLibrary,
        )
        .firstOrNull;
  }

  @override
  List<List<dynamic>> importsOf(String fileId, {bool includeParts = true}) {
    final List<List<dynamic>>? fileDirectives =
        directives[getParentSrc(fileId)];
    if (fileDirectives == null) return const <List<dynamic>>[];
    return List<List<dynamic>>.of(
      fileDirectives.where((List<dynamic> e) {
        if (e[GraphIndex.directiveType] == DirectiveStatement.import) {
          return true;
        } else if (includeParts &&
            e[GraphIndex.directiveType] == DirectiveStatement.part) {
          return true;
        }
        return false;
      }),
    );
  }

  /// Builds a new [AssetsScanResults] instance.
  AssetsScanResults();

  @override
  bool isVisited(String fileId) {
    return assets.containsKey(fileId) &&
        assets[fileId]?[GraphIndex.assetDigest] != null;
  }

  @override
  void merge(ScanResults results) {
    for (final MapEntry<String, List<dynamic>> asset
        in results.assets.entries) {
      if (assets[asset.key]?[GraphIndex.assetDigest] == null) {
        assets[asset.key] = asset.value;
      }
    }
    // [type, src, stringUri, show, hide, prefix?, deferred?]]
    for (final MapEntry<String, List<List<dynamic>>> directive
        in results.directives.entries) {
      if (!directives.containsKey(directive.key)) {
        directives[directive.key] = directive.value;
      } else {
        final List<List<dynamic>> newDirectives = directive.value;
        final List<List<dynamic>> allDirections = List<List<dynamic>>.of(
          directives[directive.key]!,
        );
        for (final List<dynamic> newDir in newDirectives) {
          bool isDuplicate = false;
          for (final List<dynamic> exDir in allDirections) {
            final bool hasNameCombinator =
                (newDir[GraphIndex.directiveType] ==
                        DirectiveStatement.export ||
                    newDir[GraphIndex.directiveType] ==
                        DirectiveStatement.import);

            if (newDir[GraphIndex.directiveType] ==
                    exDir[GraphIndex.directiveType] &&
                newDir[GraphIndex.directiveSrc] ==
                    exDir[GraphIndex.directiveSrc] &&
                (!hasNameCombinator ||
                    (_listEquals(
                          newDir[GraphIndex.directiveShow],
                          exDir[GraphIndex.directiveShow],
                        ) &&
                        _listEquals(
                          newDir[GraphIndex.directiveHide],
                          exDir[GraphIndex.directiveHide],
                        ) &&
                        newDir.elementAtOrNull(GraphIndex.directivePrefix) ==
                            exDir.elementAtOrNull(
                              GraphIndex.directivePrefix,
                            )))) {
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
      assets[asset.id] = <dynamic>[asset.shortUri.toString(), null, 0, 0];
    }
    return asset.id;
  }

  @override
  void addDirective(Asset src, DirectiveStatement statement) {
    assert(assets.containsKey(src.id));
    final String directiveSrcId = addAsset(statement.asset);
    final List<List<dynamic>> srcDirectives =
        directives[src.id] ?? <List<dynamic>>[];
    if (srcDirectives.isNotEmpty) {
      for (final List<dynamic> directive in srcDirectives) {
        final int directiveType = directive[GraphIndex.directiveType];

        /// return early if the directive is already present
        if (directiveType == DirectiveStatement.part &&
            statement.type == DirectiveStatement.partOf &&
            directive[GraphIndex.directiveSrc] == statement.asset.id) {
          return;
        }

        final List<dynamic>? shows = directive[GraphIndex.directiveShow];
        final List<dynamic>? hides = directive[GraphIndex.directiveHide];
        final String? prefix = directive.elementAtOrNull(
          GraphIndex.directivePrefix,
        );
        if (directive[GraphIndex.directiveSrc] == directiveSrcId &&
            directiveType == statement.type &&
            prefix == statement.prefix &&
            _listEquals(shows, statement.show) &&
            _listEquals(hides, statement.hide)) {
          return;
        }
      }
    }
    srcDirectives.add(<dynamic>[
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
  void addDeclaration(
    String identifier,
    Asset declaringFile,
    ReferenceType type,
  ) {
    if (!assets.containsKey(declaringFile.id)) {
      throw Exception('Asset not found: $declaringFile');
    }
    final List<dynamic>? entry = lookupIdentifier(identifier, declaringFile.id);
    if (entry == null) {
      identifiers.add(<dynamic>[identifier, declaringFile.id, type.value]);
    }
  }

  /// Looks up an identifier in the identifiers list.
  List<dynamic>? lookupIdentifier(String identifier, String src) {
    for (final List<dynamic> entry in identifiers) {
      if (entry[GraphIndex.identifierName] == identifier &&
          entry[GraphIndex.identifierSrc] == src) {
        return entry;
      }
    }
    return null;
  }

  @override
  void updateAssetInfo(
    Asset asset, {
    required Uint8List content,
    int tlmFlag = 0,
    String? libraryName,
  }) {
    assert(assets.containsKey(asset.id), 'Asset not found: $asset');
    final List<dynamic> assetArr = assets[asset.id]!;
    assetArr[GraphIndex.assetDigest] = xxh3String(content);
    assetArr[GraphIndex.assetTLMFlag] = tlmFlag;
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
    directives.removeWhere((String key, List<List<dynamic>> value) {
      value.removeWhere(
        (List<dynamic> element) => element[GraphIndex.directiveSrc] == id,
      );
      return value.isEmpty;
    });
    directives.remove(id);
    // remove all identifiers that reference this asset
    identifiers.removeWhere(
      (List<dynamic> element) => element[GraphIndex.identifierSrc] == id,
    );

    // remove all outputs that reference this asset
    for (final MapEntry<String, Set<String>> entry in outputs.entries) {
      entry.value.remove(id);
    }
    outputs.remove(id);
  }

  /// Returns the JSON representation of the scan results.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'assets': assets,
      'identifiers': identifiers,
      'directives': directives,
      'outputs': outputs.map(
        (String key, Set<String> value) =>
            MapEntry<String, List<String>>(key, value.toList()),
      ),
    };
  }

  /// Populates the instance with data from the JSON map.
  static T populate<T extends ScanResults>(
    T instance,
    Map<String, dynamic> json,
  ) {
    instance.assets.addAll(
      (json['assets'] as Map<String, dynamic>).cast<String, List<dynamic>>(),
    );
    for (final MapEntry<String, dynamic> directive
        in (json['directives'] as Map<String, dynamic>).entries) {
      instance.directives[directive.key] =
          (directive.value as List<dynamic>).cast<List<dynamic>>();
    }
    instance.identifiers.addAll(
      (json['identifiers'] as List<dynamic>).cast<List<dynamic>>(),
    );
    for (final MapEntry<String, dynamic> entry
        in (json['outputs'] as Map<String, dynamic>).entries) {
      instance.outputs[entry.key] =
          (entry.value as List<dynamic>).cast<String>().toSet();
    }
    return instance;
  }

  /// Creates a new instance of [AssetsScanResults] from a JSON map.
  factory AssetsScanResults.fromJson(Map<String, dynamic> json) {
    return populate(AssetsScanResults(), json);
  }

  @override
  final HashMap<String, List<List<dynamic>>> directives =
      HashMap<String, List<List<dynamic>>>();

  @override
  final HashMap<String, Set<String>> outputs = HashMap<String, Set<String>>();

  @override
  String toString() {
    return 'AssetsScanResults{assets: $assets, identifiers: $identifiers, directives: $directives} ';
  }

  /// Returns the URI of an asset by its ID.
  Uri uriForAsset(String id) {
    final Uri? uri = uriForAssetOrNull(id);
    assert(uri != null, 'Asset not found: $id');
    return uri!;
  }

  /// Returns the URI of an asset by its ID, or null if not found.
  Uri? uriForAssetOrNull(String id) {
    final List<dynamic>? asset = assets[id];
    if (asset == null) return null;
    return Uri.parse(asset[GraphIndex.assetUri]);
  }

  @override
  Set<String> importPrefixesOf(String id) {
    final Set<String> prefixes = <String>{};
    String targetSrc = getParentSrc(id);
    for (final List<dynamic> import in importsOf(
      targetSrc,
      includeParts: false,
    )) {
      final String? prefix = import.elementAtOrNull(GraphIndex.directivePrefix);
      if (prefix != null) {
        prefixes.add(prefix);
      }
    }
    return prefixes;
  }

  @override
  void addLibraryPartOf(String stringUri, Asset asset) {
    final List<List<dynamic>> fileDirectives = <List<dynamic>>[
      ...?directives[asset.id],
    ];
    if (fileDirectives.isEmpty) {
      directives[asset.id] = <List<dynamic>>[
        <dynamic>[DirectiveStatement.partOfLibrary, '', stringUri],
      ];
    } else {
      // avoid duplicate entries
      for (final List<dynamic> directive in fileDirectives) {
        if (directive[GraphIndex.directiveType] ==
                DirectiveStatement.partOfLibrary &&
            directive[GraphIndex.directiveStringUri] == stringUri) {
          return;
        }
      }
      directives[asset.id] = <List<dynamic>>[
        ...fileDirectives,
        <dynamic>[DirectiveStatement.partOfLibrary, '', stringUri],
      ];
    }
  }

  @override
  String getParentSrc(String fileId) {
    final List<dynamic>? partOf = partOfOf(fileId);
    if (partOf == null) return fileId;
    final int type = partOf[GraphIndex.directiveType];
    if (type == DirectiveStatement.partOf) {
      return partOf[GraphIndex.directiveSrc];
    } else if (type == DirectiveStatement.partOfLibrary) {
      for (final MapEntry<String, List<dynamic>> asset in assets.entries) {
        if (asset.value.length > GraphIndex.assetLibraryName &&
            asset.value[GraphIndex.assetLibraryName] ==
                partOf[GraphIndex.directiveStringUri]) {
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

/// An Enumeration representing the type of a reference in the asset graph.
enum ReferenceType {
  /// The reference type is unknown.
  unknown(-1),

  /// Represents a class declaration.
  $class(0),

  /// Represents a mixin declaration.
  $mixin(1),

  /// Represents an extension declaration.
  $extension(2),

  /// Represents an enum declaration.
  $enum(3),

  /// Represents a type alias declaration.
  $typeAlias(4),

  /// Represents a function declaration.
  $function(5),

  /// Represents a variable declaration.
  $variable(6);

  /// The value representing the reference type.
  final int value;

  const ReferenceType(this.value);

  /// Creates a [ReferenceType] from an integer value.
  static ReferenceType fromValue(int value) {
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

  /// Returns true if this reference type represents a class, mixin, or enum.
  bool get representsInterfaceType {
    return this == $class || this == $mixin || this == $enum;
  }

  /// Returns true if this reference type represents a named type.
  bool get representsANamedType =>
      representsInterfaceType || this == $extension || this == $typeAlias;
}

/// An Enumeration representing the state of an asset in the asset graph.
enum AssetState {
  /// The asset is already processed by builders
  processed,

  /// The asset is not processed yet
  unProcessed,

  /// The asset is deleted
  deleted;

  /// Creates an [AssetState] from an integer index.
  static AssetState fromIndex(int index) {
    return AssetState.values[index];
  }
}
