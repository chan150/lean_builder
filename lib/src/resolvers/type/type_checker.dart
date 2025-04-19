// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/resolvers/element/element.dart';
import 'package:lean_builder/src/resolvers/element_resolver.dart';
import 'package:lean_builder/src/resolvers/type/type_ref.dart';

/// The abstractions are borrowed from the source_gen package
/// An abstraction around doing static type checking at compile/build time.
abstract class TypeChecker {
  const TypeChecker._();

  /// Create a new [TypeChecker] backed by a [TypeRef].
  factory TypeChecker.fromTypeRef(ElementResolver resolver, NamedTypeRef type) = _TypeRefChecker;

  /// Creates a new [TypeChecker] that delegates to other [checkers].
  ///
  /// This implementation will return `true` for type checks if _any_ of the
  /// provided type checkers return true, which is useful for deprecating an
  /// API:
  /// ```dart
  /// const $Foo = const TypeChecker.fromRuntime(Foo);
  /// const $Bar = const TypeChecker.fromRuntime(Bar);
  ///
  /// // Used until $Foo is deleted.
  /// const $FooOrBar = const TypeChecker.forAny(const [$Foo, $Bar]);
  /// ```
  const factory TypeChecker.any(Iterable<TypeChecker> checkers) = _AnyChecker;

  /// Returns the first annotation on [element] that is assignable to this type.
  ElementAnnotation? firstAnnotationOf(Element element) {
    if (element.metadata.isEmpty) {
      return null;
    }
    final results = annotationsOf(element);
    return results.isEmpty ? null : results.first;
  }

  /// Returns if a constant annotating [element] is assignable to this type.
  ///
  /// Throws on unresolved annotations unless [throwOnUnresolved] is `false`.
  bool hasAnnotationOf(Element element) => firstAnnotationOf(element) != null;

  /// Returns the first constant annotating [element] that is exactly this type.
  ElementAnnotation? firstAnnotationOfExact(Element element) {
    if (element.metadata.isEmpty) {
      return null;
    }
    final results = annotationsOfExact(element);
    return results.isEmpty ? null : results.first;
  }

  /// Returns if a constant annotating [element] is exactly this type.
  bool hasAnnotationOfExact(Element element) => firstAnnotationOfExact(element) != null;

  /// Returns annotating constants on [element] assignable to this type.
  Iterable<ElementAnnotation> annotationsOf(Element element) => _annotationsWhere(element, isAssignableFromType);

  Iterable<ElementAnnotation> _annotationsWhere(Element element, bool Function(TypeRef) predicate) sync* {
    for (var i = 0; i < element.metadata.length; i++) {
      final annotation = element.metadata[i];
      if (predicate(annotation.type)) {
        yield annotation;
      }
    }
  }

  /// Returns annotating constants on [element] of exactly this type.
  Iterable<ElementAnnotation> annotationsOfExact(Element element) => _annotationsWhere(element, isExactlyType);

  /// Returns `true` if the type of [element] can be assigned to this type.
  bool isAssignableFrom(Element element) {
    return isExactly(element) || (element is InterfaceElement && isAssignableFromType(element.thisType));
  }

  /// Returns `true` if [typeRef] can be assigned to this type.
  bool isAssignableFromType(TypeRef typeRef) {
    if (isExactlyType(typeRef)) {
      return true;
    }
    if (typeRef is NamedTypeRef) {
      return isSuperTypeOf(typeRef);
    }
    return false;
  }

  /// Returns `true` if representing the exact same class as [element].
  bool isExactly(Element element) {
    if (element is InterfaceElement) {
      return isExactlyType(element.thisType);
    }
    return false;
  }

  /// Returns `true` if representing the exact same type as [typeRef].
  ///
  /// This will always return false for types without a backingclass such as
  /// `void` or function types.
  bool isExactlyType(TypeRef typeRef);

  /// Returns `true` if representing a super class of [element].
  ///
  /// This check only takes into account the *extends* hierarchy. If you wish
  /// to check mixins and interfaces, use [isAssignableFrom].
  bool isSuperOf(Element element) {
    if (element is InterfaceElement) {
      return isSuperTypeOf(element.thisType);
    }
    return false;
  }

  /// Returns `true` if representing a super type of [staticType].
  ///
  /// This only takes into account the *extends* hierarchy. If you wish
  /// to check mixins and interfaces, use [isAssignableFromType].
  bool isSuperTypeOf(NamedTypeRef typeRef);
}

// Checks a static type against another static type;
class _TypeRefChecker extends TypeChecker {
  final NamedTypeRef _type;
  final ElementResolver _resolver;

  _TypeRefChecker(this._resolver, this._type) : super._();

  final _resolvedTypesCache = <String, NamedTypeRef>{};

  @override
  String toString() => _type.identifier;

  @override
  bool isExactlyType(TypeRef typeRef) {
    if (typeRef is NamedTypeRef) {
      return typeRef.isExactly(_type);
    }
    return false;
  }

  final _superTypeChecksCache = <String, bool>{};

  bool _checkSuperTypesRecursively(NamedTypeRef typeToCheck, LibraryElement importingLib) {
    final reqId = '${typeToCheck.identifier}@${importingLib.src.id}';

    if (_superTypeChecksCache.containsKey(reqId)) {
      return _superTypeChecksCache[reqId]!;
    }

    final identifier = IdentifierRef(
      typeToCheck.name,
      importPrefix: typeToCheck.importPrefix,
      location: typeToCheck.src,
    );
    final (library, unit, _) = _resolver.astNodeFor(identifier, importingLib);
    final typesToSuperCheck = <NamedTypeRef, LibraryElement>{};

    bool check(NamedType typeAnnotation) {
      final resolvedSuper = _resolveType(typeAnnotation, library);
      if (resolvedSuper.isExactly(_type)) {
        return true;
      } else {
        typesToSuperCheck[resolvedSuper] = library;
      }
      return false;
    }

    if (unit is ClassDeclaration) {
      final superType = unit.extendsClause?.superclass;
      if (superType != null && check(superType)) {
        return _superTypeChecksCache[reqId] = true;
      }
      for (final interface in [...?unit.implementsClause?.interfaces]) {
        if (check(interface)) {
          return _superTypeChecksCache[reqId] = true;
        }
      }
      for (final mixin in [...?unit.withClause?.mixinTypes]) {
        if (check(mixin)) {
          return _superTypeChecksCache[reqId] = true;
        }
        ;
      }
    } else if (unit is MixinDeclaration) {
      for (final interface in [...?unit.implementsClause?.interfaces]) {
        if (check(interface)) {
          return _superTypeChecksCache[reqId] = true;
        }
      }
    } else if (unit is EnumDeclaration) {
      for (final interface in [...?unit.implementsClause?.interfaces]) {
        if (check(interface)) {
          return _superTypeChecksCache[reqId] = true;
        }
      }
    } else {
      throw Exception('Unsupported AST node type: ${unit.runtimeType}');
    }

    for (final entry in typesToSuperCheck.entries) {
      if (_checkSuperTypesRecursively(entry.key, entry.value)) {
        return _superTypeChecksCache[reqId] = true;
      }
    }
    return _superTypeChecksCache[reqId] = false;
  }

  NamedTypeRef _resolveType(NamedType superType, LibraryElementImpl importingLib) {
    final reqId = '$superType@${importingLib.src.id}';
    print('Resolving type: $reqId');
    if (_resolvedTypesCache.containsKey(reqId)) {
      return _resolvedTypesCache[reqId]!;
    }
    final typename = superType.name2.lexeme;
    final importPrefix = superType.importPrefix;
    final identifierLocation = _resolver.getDeclarationRef(
      typename,
      importingLib.src,
      importPrefix: importPrefix?.name.lexeme,
    );
    if (identifierLocation == null) {
      throw Exception('Could not find identifier $typename in ${importingLib.src.shortUri}');
    }
    final resolvedType = NamedTypeRefImpl(typename, identifierLocation, isNullable: superType.question != null);
    return _resolvedTypesCache[reqId] = resolvedType;
  }

  @override
  bool isSuperTypeOf(TypeRef typeRef) {
    if (typeRef is NamedTypeRef) {
      final importingLibrary = typeRef.src.importingLibrary;
      if (importingLibrary == null) return false;
      final importingLib = _resolver.libraryFor(importingLibrary);
      return _checkSuperTypesRecursively(typeRef, importingLib);
    }
    return false;
  }
}

class _AnyChecker extends TypeChecker {
  final Iterable<TypeChecker> _checkers;

  const _AnyChecker(this._checkers) : super._();

  @override
  bool isExactlyType(TypeRef typeRef) {
    if (typeRef is NamedTypeRef) {
      return _checkers.any((c) => c.isExactlyType(typeRef));
    }
    return false;
  }

  @override
  bool isSuperTypeOf(NamedTypeRef typeRef) {
    return _checkers.any((c) => c.isSuperTypeOf(typeRef));
  }
}
