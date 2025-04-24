import 'dart:collection';
import 'dart:typed_data';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/asset/asset.dart';
import 'package:lean_builder/src/asset/package_file_resolver.dart';
import 'package:lean_builder/src/element/builder/directives_builder.dart';
import 'package:lean_builder/src/element/builder/element_builder.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/graph/identifier_ref.dart';
import 'package:lean_builder/src/graph/scan_results.dart';
import 'package:lean_builder/src/resolvers/parsed_units_cache.dart';
import 'package:lean_builder/src/resolvers/source_based_cache.dart';
import 'package:collection/collection.dart';
import 'package:lean_builder/src/type/type_checker.dart';
import 'package:lean_builder/src/type/type_ref.dart';
import 'package:synchronized/synchronized.dart';
import 'package:xxh3/xxh3.dart';

import 'constant/constant.dart';

typedef ElementPredicate<T> = bool Function(T element);

class Resolver {
  final AssetsGraph graph;
  final SrcParser parser;
  final PackageFileResolver fileResolver;
  final _libraryCache = HashMap<String, LibraryElementImpl>();
  final _typeCheckersCache = HashMap<String, TypeChecker>();
  final _resolvedUnitsCache = SourceBasedCache<(LibraryElementImpl, AstNode, DeclarationRef)>();
  final _elementResolveLocks = SourceBasedCache<Lock>();
  final _resolvedTypeRefs = SourceBasedCache<Element?>();
  final evaluatedConstantsCache = SourceBasedCache<Constant>();

  Resolver(this.graph, this.fileResolver, this.parser);

  LibraryElement resolveLibrary(Asset src, {bool preResolveTopLevelMetadata = false, bool allowSyntaxErrors = false}) {
    final library = libraryFor(src, allowSyntaxErrors: allowSyntaxErrors);
    final visitor = ElementBuilder(this, library, preResolveTopLevelMetadata: preResolveTopLevelMetadata);
    for (final child in library.compilationUnit.childEntities.whereType<AnnotatedNode>()) {
      if (child.metadata.isNotEmpty) {
        child.accept(visitor);
      }
    }
    return library;
  }

  TypeChecker typeCheckerFor(String name, String packageImport) {
    final key = '$packageImport#$name';
    if (_typeCheckersCache.containsKey(key)) {
      return _typeCheckersCache[key]!;
    }
    final typeRef = getNamedTypeRef(name, packageImport);
    final typeChecker = TypeChecker.fromTypeRef(this, typeRef);
    return _typeCheckersCache[key] = typeChecker;
  }

  NamedTypeRef getNamedTypeRef(String name, String packageImport) {
    final uri = Uri.parse(packageImport);
    if (uri.scheme != 'package') {
      throw Exception('Invalid package import: $packageImport');
    }
    final srcId = xxh3String(Uint8List.fromList(packageImport.codeUnits));
    final declarationRef = graph.lookupIdentifierByProvider(name, srcId);
    if (declarationRef == null) {
      throw Exception('Identifier $name not found in $packageImport');
    }
    if (declarationRef.type.representsNamedType) {
      return NamedTypeRefImpl(name, declarationRef);
    } else {
      throw Exception('$name does not refer to a named type');
    }
  }

  LibraryElement libraryForDirective(DirectiveElement directive) {
    final assetSrc = fileResolver.assetForUri(directive.uri);
    return libraryFor(assetSrc);
  }

  DeclarationRef getDeclarationRef(String identifier, Asset importingSrc, {String? importPrefix}) {
    return graph.getDeclarationRef(identifier, importingSrc, importPrefix: importPrefix);
  }

  Future<Element?> elementOf(TypeRef ref) async {
    if (ref is NamedTypeRef) {
      final key = _resolvedTypeRefs.keyFor(ref.src.srcId, ref.name);

      if (_resolvedTypeRefs.contains(key)) {
        return _resolvedTypeRefs[key];
      }
      final importingLibrary = ref.src.importingLibrary;
      if (importingLibrary == null) return null;
      final lock = _elementResolveLocks.putIfAbsent(key, () => Lock());
      return await lock.synchronized(() async {
        final importingLib = libraryFor(importingLibrary);
        final identifier = IdentifierRef(ref.name, importPrefix: ref.importPrefix);
        final (library, unit, _) = astNodeFor(identifier, importingLib);
        final visitor = ElementBuilder(this, library);
        unit.accept(visitor);
        final element = library.getElement(ref.name);
        if (element != null) {
          _resolvedTypeRefs.cacheKey(key, element);
          _elementResolveLocks.remove(key);
        }
        return element;
      });
    }
    return null;
  }

  LibraryElementImpl libraryFor(Asset src, {bool allowSyntaxErrors = false}) {
    return _libraryCache.putIfAbsent(src.id, () {
      final unit = parser.parse(src, allowSyntaxErrors: allowSyntaxErrors);
      return LibraryElementImpl(this, unit, src: src);
    });
  }

  (LibraryElementImpl, AstNode, DeclarationRef) astNodeFor(IdentifierRef identifier, LibraryElement enclosingLibrary) {
    final enclosingAsset = enclosingLibrary.src;
    final cacheKey = _resolvedUnitsCache.keyFor(enclosingAsset.id, identifier.toString());
    if (_resolvedUnitsCache.contains(cacheKey)) {
      return _resolvedUnitsCache[cacheKey]!;
    }

    final declarationRef =
        identifier.location ??
        getDeclarationRef(identifier.topLevelTarget, enclosingAsset, importPrefix: identifier.importPrefix);

    final srcUri = uriForAsset(declarationRef.srcId);
    final assetFile = fileResolver.assetForUri(srcUri, relativeTo: enclosingAsset);

    final library = libraryFor(assetFile);
    final compilationUnit = library.compilationUnit;

    if (declarationRef.type == TopLevelIdentifierType.$variable) {
      final unit = compilationUnit.declarations.whereType<TopLevelVariableDeclaration>().firstWhere(
        (e) => e.variables.variables.any((v) => v.name.lexeme == declarationRef.identifier),
        orElse: () => throw Exception('Identifier  ${declarationRef.identifier} not found in $srcUri'),
      );
      return _resolvedUnitsCache.cacheKey(cacheKey, (library, unit, declarationRef));
    } else if (declarationRef.type == TopLevelIdentifierType.$function) {
      final unit = compilationUnit.declarations.whereType<FunctionDeclaration>().firstWhere(
        (e) => e.name.lexeme == declarationRef.identifier,
        orElse: () => throw Exception('Identifier  ${declarationRef.identifier} not found in $srcUri'),
      );
      return _resolvedUnitsCache.cacheKey(cacheKey, (library, unit, declarationRef));
    } else if (declarationRef.type == TopLevelIdentifierType.$typeAlias) {
      final unit = compilationUnit.declarations.whereType<TypeAlias>().firstWhere(
        (e) => e.name.lexeme == declarationRef.identifier,
        orElse: () => throw Exception('Identifier  ${declarationRef.identifier} not found in $srcUri'),
      );
      return _resolvedUnitsCache.cacheKey(cacheKey, (library, unit, declarationRef));
    }

    final unit = compilationUnit.declarations.whereType<NamedCompilationUnitMember>().firstWhereOrNull(
      (e) => e.name.lexeme == declarationRef.identifier,
    );

    if (unit == null) {
      throw Exception('Identifier  ${declarationRef.identifier} not found in $srcUri');
    } else if (identifier.isPrefixed) {
      final targetIdentifier = identifier.name;

      for (final member in unit.childEntities) {
        if (member is FieldDeclaration) {
          if (member.fields.variables.any((v) => v.name.lexeme == targetIdentifier)) {
            return _resolvedUnitsCache.cacheKey(cacheKey, (library, member, declarationRef));
          }
        } else if (member is ConstructorDeclaration) {
          if ((member.name?.lexeme ?? '') == targetIdentifier) {
            return _resolvedUnitsCache.cacheKey(cacheKey, (library, member, declarationRef));
          }
        } else if (member is MethodDeclaration) {
          if (member.name.lexeme == targetIdentifier) {
            return _resolvedUnitsCache.cacheKey(cacheKey, (library, member, declarationRef));
          }
        } else if (member is EnumConstantDeclaration) {
          if (member.name.lexeme == targetIdentifier) {
            return _resolvedUnitsCache.cacheKey(cacheKey, (library, member, declarationRef));
          }
        }
      }
      throw Exception('Identifier $targetIdentifier (${identifier.toString()}) not found in $srcUri');
    }

    return _resolvedUnitsCache.cacheKey(cacheKey, (library, unit, declarationRef));
  }

  Uri uriForAsset(String id) {
    return graph.uriForAsset(id);
  }

  void resolveDirectives(LibraryElementImpl library) {
    final builder = DirectivesBuilder(this, library);
    final directives = library.compilationUnit.directives;
    for (final directive in directives) {
      directive.accept(builder);
    }
  }

  void resolveMethods(InterfaceElement elem, {ElementPredicate<MethodDeclaration>? predicate}) {
    final elementBuilder = ElementBuilder(this, elem.library);
    final declarations = elem.library.compilationUnit.declarations;
    final namedUnit = declarations.whereType<NamedCompilationUnitMember>();
    final interfaceElemDeclaration = namedUnit.firstWhere(
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

  void resolveTypeAliases(LibraryElementImpl library, {ElementPredicate<TypeAlias>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementBuilder(this, library);
    for (final typeAlias in unit.declarations.filterAs<TypeAlias>(predicate)) {
      typeAlias.accept(visitor);
    }
  }

  void resolveMixins(LibraryElementImpl library, {ElementPredicate<MixinDeclaration>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementBuilder(this, library);
    for (final mixin in unit.declarations.filterAs<MixinDeclaration>(predicate)) {
      mixin.accept(visitor);
    }
  }

  void resolveEnums(LibraryElementImpl library, {ElementPredicate<EnumDeclaration>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementBuilder(this, library);
    for (final enumDeclaration in unit.declarations.filterAs<EnumDeclaration>(predicate)) {
      enumDeclaration.accept(visitor);
    }
  }

  void resolveFunctions(LibraryElementImpl library, {ElementPredicate<FunctionDeclaration>? predicate}) {
    final unit = library.compilationUnit;
    final visitor = ElementBuilder(this, library);
    for (final function in unit.declarations.filterAs<FunctionDeclaration>(predicate)) {
      function.accept(visitor);
    }
  }

  void resolveClasses(LibraryElementImpl library, {ElementPredicate<NamedCompilationUnitMember>? predicate}) {
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
  Iterable<T> filterAs<T>([ElementPredicate<T>? predicate]) {
    if (predicate == null) return whereType<T>();
    return whereType<T>().where(predicate);
  }
}
