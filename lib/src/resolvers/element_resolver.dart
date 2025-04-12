import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_genie/src/resolvers/element/element.dart';
import 'package:code_genie/src/resolvers/file_asset.dart';
import 'package:code_genie/src/resolvers/package_file_resolver.dart';
import 'package:code_genie/src/resolvers/parsed_units_cache.dart';
import 'package:code_genie/src/resolvers/type/type_ref.dart';
import 'package:code_genie/src/resolvers/visitor/element_resolver_visitor.dart';
import 'package:code_genie/src/scanner/assets_graph.dart';
import 'package:code_genie/src/scanner/directive_statement.dart';
import 'package:code_genie/src/scanner/identifier_ref.dart';
import 'package:code_genie/src/scanner/scan_results.dart';
import 'package:collection/collection.dart';

typedef ResolvePredicate<T> = bool Function(T member);

class ElementResolver {
  final AssetsGraph graph;
  final SrcParser parser;
  final PackageFileResolver fileResolver;
  final Map<String, LibraryElementImpl> _libraryCache = {};
  final Map<String, (LibraryElementImpl, AstNode)> _parsedUnitCache = {};

  ElementResolver(this.graph, this.fileResolver, this.parser);

  LibraryElement resolveLibrary(AssetSrc src) {
    final unit = parser.parse(src.path, key: src.id);
    final rootLibrary = libraryFor(src);
    final visitor = ElementResolverVisitor(this, rootLibrary);
    for (final child in unit.childEntities.whereType<AnnotatedNode>()) {
      if (child.metadata.isNotEmpty) {
        child.accept(visitor);
      }
    }
    return rootLibrary;
  }

  IdentifierLocation? getIdentifierLocation(
    String identifier,
    AssetSrc importingSrc, {
    bool requireProvider = true,
    String? importPrefix,
  }) {
    return graph.getIdentifierLocation(
      identifier,
      importingSrc,
      requireProvider: requireProvider,
      importPrefix: importPrefix,
    );
  }

  Element? elementOf(TypeRef ref) {
    if (ref is NamedTypeRef) {
      final importingLib = libraryFor(ref.src.importingLibrary);
      final identifier = IdentifierRef(ref.name, importPrefix: ref.importPrefix);
      final (library, unit) = astNodeFor(identifier, importingLib);
      final visitor = ElementResolverVisitor(this, library);
      unit.accept(visitor);
      return library.getElement(ref.name);
    }
    return null;
  }

  LibraryElementImpl libraryFor(AssetSrc src) {
    return _libraryCache.putIfAbsent(src.id, () {
      final unit = parser.parse(src.path, key: src.id);
      return LibraryElementImpl(this, unit, src: src);
    });
  }

  (LibraryElementImpl, AstNode) astNodeFor(IdentifierRef identifier, LibraryElement enclosingLibrary) {
    final enclosingAsset = enclosingLibrary.src;
    final unitId = '${enclosingAsset.id}#${identifier.toString()}';
    if (_parsedUnitCache.containsKey(unitId)) {
      return _parsedUnitCache[unitId]!;
    }

    final identifierSrc =
        identifier.src ??
        getIdentifierLocation(
          identifier.topLevelTarget,
          enclosingAsset,
          requireProvider: true,
          importPrefix: identifier.importPrefix,
        );

    assert(identifierSrc != null, 'Identifier $identifier not found in ${enclosingAsset.uri}');
    final srcUri = uriForAsset(identifierSrc!.srcId);
    final assetFile = fileResolver.buildAssetUri(srcUri, relativeTo: enclosingAsset);

    final library = libraryFor(assetFile);
    final compilationUnit = library.compilationUnit;

    if (identifierSrc.type == TopLevelIdentifierType.$variable) {
      final unit = compilationUnit.declarations.whereType<TopLevelVariableDeclaration>().firstWhere(
        (e) => e.variables.variables.any((v) => v.name.lexeme == identifierSrc.identifier),
        orElse: () => throw Exception('Identifier  ${identifierSrc.identifier} not found in $srcUri'),
      );
      return _parsedUnitCache[unitId] = (library, unit);
    } else if (identifierSrc.type == TopLevelIdentifierType.$function) {
      final unit = compilationUnit.declarations.whereType<FunctionDeclaration>().firstWhere(
        (e) => e.name.lexeme == identifierSrc.identifier,
        orElse: () => throw Exception('Identifier  ${identifierSrc.identifier} not found in $srcUri'),
      );
      return _parsedUnitCache[unitId] = (library, unit);
    } else if (identifierSrc.type == TopLevelIdentifierType.$typeAlias) {
      final unit = compilationUnit.declarations.whereType<TypeAlias>().firstWhere(
        (e) => e.name.lexeme == identifierSrc.identifier,
        orElse: () => throw Exception('Identifier  ${identifierSrc.identifier} not found in $srcUri'),
      );
      return _parsedUnitCache[unitId] = (library, unit);
    }

    final unit = compilationUnit.declarations.whereType<NamedCompilationUnitMember>().firstWhereOrNull(
      (e) => e.name.lexeme == identifierSrc.identifier,
    );

    if (unit == null) {
      throw Exception('Identifier  ${identifierSrc.identifier} not found in $srcUri');
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
      throw Exception('Identifier $targetIdentifier (${identifier.toString()}) not found in $srcUri');
    }

    return _parsedUnitCache[unitId] = (library, unit);
  }

  Uri uriForAsset(String id) {
    return graph.uriForAsset(id);
  }

  void resolveDirectives(LibraryElementImpl library) {
    final directives = graph.directives[library.src.id];
    if (directives == null) return;

    for (final directive in directives) {
      if (directive[0] == DirectiveStatement.import) {
        final element = ImportElementImpl(
          uri: uriForAsset(directive[1]),
          library: library,
          prefix: directive.elementAtOrNull(4),
          combinators: [
            if (directive[2] != null) ShowElementCombinator(directive[2]),
            if (directive[3] != null) HideElementCombinator(directive[3]),
          ],
        );
        library.addElement(element);
      } else if (directive[0] == DirectiveStatement.export) {
        final element = ExportElementImpl(
          uri: uriForAsset(directive[1]),
          library: library,
          combinators: [
            if (directive[2] != null) ShowElementCombinator(directive[2]),
            if (directive[3] != null) HideElementCombinator(directive[3]),
          ],
        );
        library.addElement(element);
      } else if (directive[0] == DirectiveStatement.part) {
        final element = PartElementImpl(uri: uriForAsset(directive[1]), library: library);
        library.addElement(element);
      } else if (directive[0] == DirectiveStatement.partOf) {
        final element = PartOfElementImpl(uri: uriForAsset(directive[1]), library: library);
        library.addElement(element);
      } else if (directive[0] == DirectiveStatement.partOfLibrary) {
        final element = PartOfElementImpl(uri: uriForAsset(directive[1]), library: library);
        library.addElement(element);
      }
    }
  }

  void resolveMethods(InterfaceElement elem, {ResolvePredicate<MethodDeclaration>? predicate}) {
    final astResolver = ElementResolverVisitor(this, elem.library);
    final declaration = elem.library.compilationUnit.declarations.whereType<NamedCompilationUnitMember>();
    final interfaceElemDeclaration = declaration.firstWhere(
      (d) => d.name.lexeme == elem.name,
      orElse: () => throw Exception('Could not find element declaration named ${elem.name}'),
    );
    final methods = interfaceElemDeclaration.childEntities.filterAs<MethodDeclaration>(predicate);
    astResolver.visitElementScoped(elem, () {
      for (final method in methods) {
        method.accept(astResolver);
      }
    });
  }

  void resolveTypeAliases(LibraryElementImpl library, {ResolvePredicate<TypeAlias>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementResolverVisitor(this, library);
    for (final typeAlias in unit.declarations.filterAs<TypeAlias>(predicate)) {
      typeAlias.accept(visitor);
    }
  }

  void resolveMixins(LibraryElementImpl library, {ResolvePredicate<MixinDeclaration>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementResolverVisitor(this, library);
    for (final mixin in unit.declarations.filterAs<MixinDeclaration>(predicate)) {
      mixin.accept(visitor);
    }
  }

  void resolveEnums(LibraryElementImpl library, {ResolvePredicate<EnumDeclaration>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementResolverVisitor(this, library);
    for (final enumDeclaration in unit.declarations.filterAs<EnumDeclaration>(predicate)) {
      enumDeclaration.accept(visitor);
    }
  }

  void resolveFunctions(LibraryElementImpl library, {ResolvePredicate<FunctionDeclaration>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementResolverVisitor(this, library);
    for (final function in unit.declarations.filterAs<FunctionDeclaration>(predicate)) {
      function.accept(visitor);
    }
  }

  void resolveClasses(LibraryElementImpl library, {ResolvePredicate<ClassDeclaration>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementResolverVisitor(this, library);
    for (final classDeclaration in unit.declarations.filterAs<ClassDeclaration>(predicate)) {
      classDeclaration.accept(visitor);
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
  final IdentifierLocation? src;

  IdentifierRef(this.name, {this.prefix, this.importPrefix, this.src});

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
