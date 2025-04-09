import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_genie/src/resolvers/element/element.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/resolvers/parsed_units_cache.dart';
import 'package:code_genie/src/resolvers/visitor/element_resolver_visitor.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/scan_results.dart';
import 'package:collection/collection.dart';

class ElementResolver {
  final AssetsGraph graph;
  final SrcParser parser;
  final PackageFileResolver fileResolver;
  final Map<String, LibraryElement> _libraryCache = {};
  final Map<String, (LibraryElement, AstNode)> _parsedUnitCache = {};

  ElementResolver(this.graph, this.fileResolver, this.parser);

  LibraryElement resolveLibrary(AssetSrc src) {
    final unit = parser.parse(src.path);
    final rootLibrary = libraryFor(src);
    final visitor = ElementResolverVisitor(this, rootLibrary);
    for (final child in unit.childEntities.whereType<AnnotatedNode>()) {
      if (child.metadata.isNotEmpty) {
        child.accept(visitor);
      }
    }
    return rootLibrary;
  }

  LibraryElement libraryFor(AssetSrc src) {
    return _libraryCache.putIfAbsent(src.id, () {
      final name = src.uri.pathSegments.last;
      return LibraryElementImpl(name: name, src: src);
    });
  }

  (LibraryElement, AstNode) astNodeFor(IdentifierRef identifier, LibraryElement enclosingLibrary) {
    final enclosingAsset = enclosingLibrary.src;
    final unitId = '${enclosingAsset.id}#${identifier.toString()}';
    if (_parsedUnitCache.containsKey(unitId)) {
      return _parsedUnitCache[unitId]!;
    }

    final ref = graph.getIdentifierSrc(
      identifier.topLevelTarget,
      enclosingAsset.id,
      requireProvider: true,
      importPrefix: identifier.importPrefix,
    );

    assert(ref != null, 'Identifier $identifier not found in ${enclosingAsset.uri}');
    final assetFile = fileResolver.buildAssetUri(ref!.srcUri, relativeTo: enclosingAsset);

    final library = libraryFor(assetFile);
    final parsedUnit = parser.parse(assetFile.path);

    if (ref.type == TopLevelIdentifierType.$variable) {
      final unit = parsedUnit.declarations.whereType<TopLevelVariableDeclaration>().firstWhere(
        (e) => e.variables.variables.any((v) => v.name.lexeme == ref.identifier),
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
      return _parsedUnitCache[unitId] = (library, unit);
    } else if (ref.type == TopLevelIdentifierType.$function) {
      final unit = parsedUnit.declarations.whereType<FunctionDeclaration>().firstWhere(
        (e) => e.name.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
      return _parsedUnitCache[unitId] = (library, unit);
    } else if (ref.type == TopLevelIdentifierType.$typeAlias) {
      final unit = parsedUnit.declarations.whereType<TypeAlias>().firstWhere(
        (e) => e.name.lexeme == ref.identifier,
        orElse: () => throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}'),
      );
      return _parsedUnitCache[unitId] = (library, unit);
    }

    final unit = parsedUnit.declarations.whereType<NamedCompilationUnitMember>().firstWhereOrNull(
      (e) => e.name.lexeme == ref.identifier,
    );

    if (unit == null) {
      throw Exception('Identifier  ${ref.identifier} not found in ${ref.srcUri}');
    } else if (identifier.isPrefixed) {
      final targetIdentifier = identifier.name;

      for (final member in unit.childEntities) {
        if (member is FieldDeclaration) {
          if (member.fields.variables.any((v) => v.name.lexeme == targetIdentifier)) {
            return _parsedUnitCache[unitId] = (library, member);
          }
        } else if (member is ConstructorDeclaration) {
          if (member.name?.lexeme == targetIdentifier) {
            return _parsedUnitCache[unitId] = (library, member);
          }
        } else if (member is MethodDeclaration) {
          if (member.name.lexeme == targetIdentifier) {
            return _parsedUnitCache[unitId] = (library, member);
          }
        } else if (member is EnumConstantDeclaration) {
          if (member.name.lexeme == targetIdentifier) {
            return _parsedUnitCache[unitId] = (library, member);
          }
        }
      }
      throw Exception('Identifier $targetIdentifier (${identifier.toString()}) not found in ${ref.srcUri}');
    }

    return _parsedUnitCache[unitId] = (library, unit);
  }
}

class IdentifierRef {
  final String name;
  final String? prefix;
  final String? importPrefix;

  IdentifierRef(this.name, {this.prefix, this.importPrefix});

  bool get isPrefixed => prefix != null;

  String get topLevelTarget => prefix != null ? prefix! : name;

  factory IdentifierRef.from(Identifier identifier, {String? importPrefix}) {
    if (identifier is PrefixedIdentifier) {
      return IdentifierRef(identifier.identifier.name, prefix: identifier.prefix.name, importPrefix: importPrefix);
    } else {
      return IdentifierRef(identifier.name, importPrefix: importPrefix);
    }
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
