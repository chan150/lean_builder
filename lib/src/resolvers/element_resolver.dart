import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';
import 'package:lean_builder/src/resolvers/file_asset.dart';
import 'package:lean_builder/src/resolvers/package_file_resolver.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/resolvers/type/type_ref.dart';
import 'package:lean_builder/src/resolvers/element_builder/element_builder.dart';
import 'package:lean_builder/src/scanner/assets_graph.dart';
import 'package:lean_builder/src/scanner/directive_statement.dart';
import 'package:lean_builder/src/scanner/identifier_ref.dart';
import 'package:lean_builder/src/scanner/scan_results.dart';
import 'package:collection/collection.dart';
import 'package:synchronized/synchronized.dart';

import 'const/constant.dart';

typedef ResolvePredicate<T> = bool Function(T member);

class ElementResolver {
  final AssetsGraph graph;
  final SrcParser parser;
  final PackageFileResolver fileResolver;
  final Map<String, LibraryElementImpl> _libraryCache = {};
  final Map<String, (LibraryElementImpl, AstNode, DeclarationRef)> _parsedUnitCache = {};
  final Map<String, Lock> _elementResolveLocks = {};
  final Map<String, Element?> _resolvedTypeRefs = {};
  final Map<String, Constant> evaluatedConstants = {};

  ElementResolver(this.graph, this.fileResolver, this.parser);

  LibraryElement resolveLibrary(AssetSrc src) {
    final library = libraryFor(src);
    final visitor = ElementBuilder(this, library);
    for (final child in library.compilationUnit.childEntities.whereType<AnnotatedNode>()) {
      if (child.metadata.isNotEmpty) {
        child.accept(visitor);
      }
    }
    return library;
  }

  LibraryElement libraryForDirective(DirectiveElement directive) {
    final assetSrc = fileResolver.buildAssetUri(directive.uri);
    return libraryFor(assetSrc);
  }

  DeclarationRef? getDeclarationRef(String identifier, AssetSrc importingSrc, {String? importPrefix}) {
    return graph.getDeclarationRef(identifier, importingSrc, importPrefix: importPrefix);
  }

  Future<Element?> elementOf(TypeRef ref) async {
    if (ref is NamedTypeRef) {
      if (_resolvedTypeRefs.containsKey(ref.identifier)) {
        return _resolvedTypeRefs[ref.identifier];
      }

      final importingLibrary = ref.src.importingLibrary;
      if (importingLibrary == null) return null;

      final lock = _elementResolveLocks.putIfAbsent(ref.identifier, () => Lock());
      return await lock.synchronized(() async {
        final importingLib = libraryFor(importingLibrary);
        final identifier = IdentifierRef(ref.name, importPrefix: ref.importPrefix);
        final (library, unit, _) = astNodeFor(identifier, importingLib);
        final visitor = ElementBuilder(this, library);
        unit.accept(visitor);
        final element = library.getElement(ref.name);
        if (element != null) {
          _resolvedTypeRefs[ref.identifier] = element;
          _elementResolveLocks.remove(ref.identifier);
        }
        return element;
      });
    }
    return null;
  }

  LibraryElementImpl libraryFor(AssetSrc src) {
    return _libraryCache.putIfAbsent(src.id, () {
      final unit = parser.parse(src);
      return LibraryElementImpl(this, unit, src: src);
    });
  }

  (LibraryElementImpl, AstNode, DeclarationRef loc) astNodeFor(
    IdentifierRef identifier,
    LibraryElement enclosingLibrary,
  ) {
    final enclosingAsset = enclosingLibrary.src;
    final unitId = '${enclosingAsset.id}#${identifier.toString()}';
    if (_parsedUnitCache.containsKey(unitId)) {
      return _parsedUnitCache[unitId]!;
    }

    final loc =
        identifier.location ??
        getDeclarationRef(identifier.topLevelTarget, enclosingAsset, importPrefix: identifier.importPrefix);

    assert(loc != null, 'Identifier $identifier not found in ${enclosingAsset.uri}');
    final srcUri = uriForAsset(loc!.srcId);
    final assetFile = fileResolver.buildAssetUri(srcUri, relativeTo: enclosingAsset);

    final library = libraryFor(assetFile);
    final compilationUnit = library.compilationUnit;

    if (loc.type == TopLevelIdentifierType.$variable) {
      final unit = compilationUnit.declarations.whereType<TopLevelVariableDeclaration>().firstWhere(
        (e) => e.variables.variables.any((v) => v.name.lexeme == loc.identifier),
        orElse: () => throw Exception('Identifier  ${loc.identifier} not found in $srcUri'),
      );
      return _parsedUnitCache[unitId] = (library, unit, loc);
    } else if (loc.type == TopLevelIdentifierType.$function) {
      final unit = compilationUnit.declarations.whereType<FunctionDeclaration>().firstWhere(
        (e) => e.name.lexeme == loc.identifier,
        orElse: () => throw Exception('Identifier  ${loc.identifier} not found in $srcUri'),
      );
      return _parsedUnitCache[unitId] = (library, unit, loc);
    } else if (loc.type == TopLevelIdentifierType.$typeAlias) {
      final unit = compilationUnit.declarations.whereType<TypeAlias>().firstWhere(
        (e) => e.name.lexeme == loc.identifier,
        orElse: () => throw Exception('Identifier  ${loc.identifier} not found in $srcUri'),
      );
      return _parsedUnitCache[unitId] = (library, unit, loc);
    }

    final unit = compilationUnit.declarations.whereType<NamedCompilationUnitMember>().firstWhereOrNull(
      (e) => e.name.lexeme == loc.identifier,
    );

    if (unit == null) {
      throw Exception('Identifier  ${loc.identifier} not found in $srcUri');
    } else if (identifier.isPrefixed) {
      final targetIdentifier = identifier.name;

      for (final member in unit.childEntities) {
        if (member is FieldDeclaration) {
          if (member.fields.variables.any((v) => v.name.lexeme == targetIdentifier)) {
            return _parsedUnitCache[unitId] = (library, member, loc);
          }
        } else if (member is ConstructorDeclaration) {
          if ((member.name?.lexeme ?? '') == targetIdentifier) {
            return _parsedUnitCache[unitId] = (library, member, loc);
          }
        } else if (member is MethodDeclaration) {
          if (member.name.lexeme == targetIdentifier) {
            return _parsedUnitCache[unitId] = (library, member, loc);
          }
        } else if (member is EnumConstantDeclaration) {
          if (member.name.lexeme == targetIdentifier) {
            return _parsedUnitCache[unitId] = (library, member, loc);
          }
        }
      }
      throw Exception('Identifier $targetIdentifier (${identifier.toString()}) not found in $srcUri');
    }

    return _parsedUnitCache[unitId] = (library, unit, loc);
  }

  Uri uriForAsset(String id) {
    return graph.uriForAsset(id);
  }

  void resolveDirectives(LibraryElementImpl library) {
    final directives = graph.directives[library.src.id];
    if (directives == null) return;

    final libraryDir = graph.assets[library.src.id]?[3];
    if (libraryDir != null) {}

    for (final directive in directives) {
      final type = directive[GraphIndex.directiveType] as int;

      if (type == DirectiveStatement.import) {
        final element = ImportElement(
          library: library,
          uri: uriForAsset(directive[GraphIndex.directiveSrc]),
          srcId: directive[GraphIndex.directiveSrc],
          stringUri: directive[GraphIndex.directiveStringUri],
          shownNames: directive[GraphIndex.directiveShow],
          hiddenNames: directive[GraphIndex.directiveHide],
          prefix: directive.elementAtOrNull(GraphIndex.directivePrefix),
          isDeferred: directive.elementAtOrNull(GraphIndex.directiveDeferred) == 1,
        );
        library.addElement(element);
      } else if (type == DirectiveStatement.export) {
        final element = ExportElement(
          library: library,
          uri: uriForAsset(directive[GraphIndex.directiveSrc]),
          srcId: directive[GraphIndex.directiveSrc],
          stringUri: directive[GraphIndex.directiveStringUri],
          shownNames: directive[GraphIndex.directiveShow],
          hiddenNames: directive[GraphIndex.directiveHide],
        );
        library.addElement(element);
      } else if (type == DirectiveStatement.part) {
        final element = PartElement(
          uri: uriForAsset(directive[GraphIndex.directiveSrc]),
          srcId: directive[GraphIndex.directiveSrc],
          stringUri: directive[GraphIndex.directiveStringUri],
          library: library,
        );
        library.addElement(element);
      } else if (type == DirectiveStatement.partOf) {
        final element = PartOfElement(
          uri: uriForAsset(directive[GraphIndex.directiveSrc]),
          library: library,
          srcId: directive[GraphIndex.directiveSrc],
          stringUri: directive[GraphIndex.directiveStringUri],
        );
        library.addElement(element);
      } else if (type == DirectiveStatement.partOfLibrary) {
        final thisSrc = library.src.id;
        final partOf = graph.partOfOf(thisSrc);
        assert(partOf != null && partOf[GraphIndex.directiveType] == DirectiveStatement.partOfLibrary);
        final actualSrc = partOf![GraphIndex.directiveSrc];
        final element = PartOfElement(
          referencesLibraryDirective: true,
          uri: uriForAsset(actualSrc),
          library: library,
          srcId: directive[GraphIndex.directiveSrc],
          stringUri: directive[GraphIndex.directiveStringUri],
        );
        library.addElement(element);
      }
    }
  }

  void resolveMethods(InterfaceElement elem, {ResolvePredicate<MethodDeclaration>? predicate}) {
    final elementBuilder = ElementBuilder(this, elem.library);
    final declaration = elem.library.compilationUnit.declarations.whereType<NamedCompilationUnitMember>();
    final interfaceElemDeclaration = declaration.firstWhere(
      (d) => d.name.lexeme == elem.name,
      orElse: () => throw Exception('Could not find element declaration named ${elem.name}'),
    );
    final methods = interfaceElemDeclaration.childEntities.filterAs<MethodDeclaration>(predicate);
    elementBuilder.visitElementScoped(elem, () {
      for (final method in methods) {
        method.accept(elementBuilder);
      }
    });
  }

  void resolveTypeAliases(LibraryElementImpl library, {ResolvePredicate<TypeAlias>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementBuilder(this, library);
    for (final typeAlias in unit.declarations.filterAs<TypeAlias>(predicate)) {
      typeAlias.accept(visitor);
    }
  }

  void resolveMixins(LibraryElementImpl library, {ResolvePredicate<MixinDeclaration>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementBuilder(this, library);
    for (final mixin in unit.declarations.filterAs<MixinDeclaration>(predicate)) {
      mixin.accept(visitor);
    }
  }

  void resolveEnums(LibraryElementImpl library, {ResolvePredicate<EnumDeclaration>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementBuilder(this, library);
    for (final enumDeclaration in unit.declarations.filterAs<EnumDeclaration>(predicate)) {
      enumDeclaration.accept(visitor);
    }
  }

  void resolveFunctions(LibraryElementImpl library, {ResolvePredicate<FunctionDeclaration>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementBuilder(this, library);
    for (final function in unit.declarations.filterAs<FunctionDeclaration>(predicate)) {
      function.accept(visitor);
    }
  }

  void resolveClasses(LibraryElementImpl library, {ResolvePredicate<NamedCompilationUnitMember>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementBuilder(this, library);
    for (final classDeclaration in unit.declarations.filterAs<ClassDeclaration>(predicate)) {
      classDeclaration.accept(visitor);
    }

    /// class type alias are treated as classes
    for (final classTypeAlias in unit.declarations.filterAs<ClassTypeAlias>(predicate)) {
      classTypeAlias.accept(visitor);
    }
  }

  IdentifierRef resolveIdentifier(LibraryElement library, List<String> parts) {
    assert(parts.isNotEmpty, 'Identifier parts cannot be empty');
    if (parts.length == 1) {
      return IdentifierRef(parts.first);
    } else {
      final prefix = parts[0];
      final importPrefixes = graph.importPrefixesOf(library.src.id);
      final isImportPrefix = importPrefixes.contains(prefix);
      if (isImportPrefix) {
        final namedUnit = parts.length == 3 ? parts[1] : null;
        return IdentifierRef(parts.last, prefix: namedUnit, importPrefix: prefix);
      } else {
        return IdentifierRef(parts.last, prefix: parts[0]);
      }
    }
  }
}

extension IterableFilterExt<E> on Iterable<E> {
  Iterable<T> filterAs<T>([ResolvePredicate<T>? predicate]) {
    if (predicate == null) return whereType<T>();
    return whereType<T>().where(predicate);
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
