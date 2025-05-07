// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:lean_builder/src/graph/assets_graph.dart';
import 'package:lean_builder/src/type/type.dart';
import 'package:xxh3/xxh3.dart';

import '../element/element.dart';

/// The abstractions are borrowed from the source_gen package
/// An abstraction around doing static type checking at compile/build time.
abstract class TypeChecker {
  const TypeChecker._();

  /// Create a new [TypeChecker] backed by a [DartType].
  factory TypeChecker.fromTypeRef(NamedDartType type) = _RefTypeChecker;

  /// The expected format of the url is either a direct package url to
  /// the source file declaring the type, or a dart core type.
  /// For example:
  /// - `package:foo/bar.dart#Baz` 'Baz' should be a declared type inside 'package:foo/bar.dart'
  /// - 'dart:core/int.dart' 'int' should be a declared type inside 'dart:core/int.dart'
  /// - `dart:core#int` 'int' which will be normalized to `dart:core/int.dart`
  factory TypeChecker.fromUrl(String url) = _UriTypeChecker;

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
  factory TypeChecker.any(Iterable<TypeChecker> checkers) = _AnyChecker;

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
  Iterable<ElementAnnotation> annotationsOf(Element element) => _annotationsWhere(element, (ref) {
    return isAssignableFromType(ref);
  });

  Iterable<ElementAnnotation> _annotationsWhere(Element element, bool Function(DartType) predicate) sync* {
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
  bool isAssignableFromType(DartType typeRef);

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
  bool isExactlyType(DartType typeRef);

  NamedDartType? matchingTypeOrSupertype(DartType typeRef);

  /// Returns `true` if representing a super class of [element].
  ///
  /// This check only takes into account the *extends* hierarchy. If you wish
  /// to check mixins and interfaces, use [isAssignableFrom].
  bool isSuperOf(Element element) {
    if (element is InterfaceElement) {
      return isSupertypeOf(element.thisType);
    }
    return false;
  }

  /// Returns `true` if representing a super type of [staticType].
  ///
  /// This only takes into account the *extends* hierarchy. If you wish
  /// to check mixins and interfaces, use [isAssignableFromType].
  bool isSupertypeOf(DartType type);
}

class _RefTypeChecker extends _TypeCheckerImpl {
  final NamedDartType _type;

  _RefTypeChecker(this._type);

  @override
  String toString() => _type.name;

  @override
  bool isExactlyType(DartType typeRef) {
    if (typeRef is NamedDartType) {
      return typeRef.isExactly(_type);
    }
    return false;
  }
}

class _UriTypeChecker extends _TypeCheckerImpl {
  final String name;
  final Uri uri;
  final String? srcId;

  factory _UriTypeChecker(String url) {
    final parts = url.split('#');
    if (parts.length != 2) {
      throw ArgumentError('Invalid url format: $url, expected format e.g package:foo/bar.dart#baz or dart:core#int');
    }
    var libraryUrl = Uri.parse(parts[0]);
    final typeName = parts[1];
    if (libraryUrl.scheme != 'package' && libraryUrl.scheme != 'dart') {
      throw ArgumentError('Invalid url format: $url, expected format e.g package:foo/bar.dart#baz or dart:core#int');
    }
    String? srcId;
    if (libraryUrl.path.endsWith('.dart')) {
      srcId = xxh3String(Uint8List.fromList(libraryUrl.toString().codeUnits));
    }

    return _UriTypeChecker._(typeName, libraryUrl, srcId);
  }

  _UriTypeChecker._(this.name, this.uri, this.srcId);

  @override
  bool isExactlyType(DartType typeRef) {
    if (typeRef is NamedDartType) {
      if (typeRef.name != name) {
        return false;
      }
      if (srcId != null) {
        return typeRef.declarationRef.srcId == srcId;
      }
      // at this point we should have something like dart:core;
      // we convert it to dart:core/core.dart
      final resolver = typeRef.resolver;
      final type = resolver.getNamedType(name, uri.toString());
      return type.isExactly(typeRef);
    }
    return false;
  }
}

// Checks a static type against another static type;
abstract class _TypeCheckerImpl extends TypeChecker {
  _TypeCheckerImpl() : super._();

  final _resolvedTypesCache = <String, InterfaceType>{};

  final _superTypeChecksCache = <String, (bool, NamedDartType?)>{};

  (bool, NamedDartType?) _checkSupertypesRecursively(
    NamedDartType typeToCheck,
    LibraryElement importingLib, {
    bool extendClauseOnly = false,
  }) {
    final reqId = '${typeToCheck.identifier}@${importingLib.src.id}';

    if (_superTypeChecksCache.containsKey(reqId)) {
      return _superTypeChecksCache[reqId]!;
    }

    final identifier = IdentifierRef(
      typeToCheck.name,
      importPrefix: typeToCheck.declarationRef.importPrefix,
      declarationRef: typeToCheck.declarationRef,
    );
    final (library, unit, _) = importingLib.resolver.astNodeFor(identifier, importingLib);
    final typesToSuperCheck = <InterfaceType, LibraryElement>{};

    (bool, InterfaceType?) check(NamedType? typeAnnotation) {
      if (typeAnnotation == null) {
        return (false, null);
      }
      final resolvedSuper = _resolveType(typeAnnotation, library);
      if (isExactlyType(resolvedSuper)) {
        return (true, resolvedSuper);
      } else {
        typesToSuperCheck[resolvedSuper] = library;
      }
      return (false, resolvedSuper);
    }

    if (extendClauseOnly) {
      if (unit is ClassDeclaration && unit.extendsClause != null) {
        final superType = unit.extendsClause!.superclass;
        final (match, type) = check(superType);
        if (match) {
          return _superTypeChecksCache[reqId] = (true, type);
        } else if (typesToSuperCheck.isNotEmpty) {
          return _checkSupertypesRecursively(typesToSuperCheck.keys.first, typesToSuperCheck.values.first);
        }
      }
      return _superTypeChecksCache[reqId] = (false, null);
    }

    if (unit is ClassDeclaration) {
      final superType = unit.extendsClause?.superclass;
      final (match, type) = check(superType);
      if (match) {
        return _superTypeChecksCache[reqId] = (true, type);
      }
      for (final interface in [...?unit.implementsClause?.interfaces]) {
        final (match, type) = check(interface);
        if (match) {
          return _superTypeChecksCache[reqId] = (true, type);
        }
      }
      for (final mixin in [...?unit.withClause?.mixinTypes]) {
        final (match, type) = check(mixin);
        if (match) {
          return _superTypeChecksCache[reqId] = (true, type);
        }
      }
    } else if (unit is MixinDeclaration) {
      for (final interface in [...?unit.implementsClause?.interfaces]) {
        final (match, type) = check(interface);
        if (match) {
          return _superTypeChecksCache[reqId] = (true, type);
        }
      }
    } else if (unit is EnumDeclaration) {
      for (final interface in [...?unit.implementsClause?.interfaces]) {
        final (match, type) = check(interface);
        if (match) {
          return _superTypeChecksCache[reqId] = (true, type);
        }
      }
    } else {
      throw Exception('Unsupported AST node type: ${unit.runtimeType}');
    }

    for (final entry in typesToSuperCheck.entries) {
      final (match, type) = _checkSupertypesRecursively(entry.key, entry.value);
      if (match) {
        return _superTypeChecksCache[reqId] = (true, type);
      }
    }
    return _superTypeChecksCache[reqId] = (false, null);
  }

  InterfaceType _resolveType(NamedType superType, LibraryElementImpl importingLib) {
    final reqId = '$superType@${importingLib.src.id}';

    if (_resolvedTypesCache.containsKey(reqId)) {
      return _resolvedTypesCache[reqId]!;
    }
    final typename = superType.name2.lexeme;
    final importPrefix = superType.importPrefix;
    final identifierLocation = importingLib.resolver.getDeclarationRef(
      typename,
      importingLib.src,
      importPrefix: importPrefix?.name.lexeme,
    );

    final resolvedType = InterfaceTypeImpl(
      typename,
      identifierLocation,
      importingLib.resolver,
      isNullable: superType.question != null,
    );
    return _resolvedTypesCache[reqId] = resolvedType;
  }

  @override
  bool isSupertypeOf(DartType typeRef) => _isSupertypeOf(typeRef, extendClauseOnly: true);

  bool _isSupertypeOf(DartType typeRef, {bool extendClauseOnly = false}) {
    if (typeRef is InterfaceType) {
      final importingLibrary = typeRef.declarationRef.importingLibrary;
      if (importingLibrary == null) return false;
      final importingLib = typeRef.resolver.libraryFor(importingLibrary);
      final (match, _) = _checkSupertypesRecursively(typeRef, importingLib, extendClauseOnly: extendClauseOnly);
      return match;
    }
    return false;
  }

  @override
  NamedDartType? matchingTypeOrSupertype(DartType typeRef) {
    if (typeRef is InterfaceType) {
      if (isExactlyType(typeRef)) {
        return typeRef;
      }
      final importingLibrary = typeRef.declarationRef.importingLibrary;
      if (importingLibrary == null) return null;
      final importingLib = typeRef.resolver.libraryFor(importingLibrary);
      final (match, superType) = _checkSupertypesRecursively(typeRef, importingLib);
      return match ? superType : null;
    }
    return null;
  }

  @override
  bool isAssignableFromType(DartType typeRef) {
    if (isExactlyType(typeRef)) {
      return true;
    }
    if (typeRef is NamedDartType) {
      return _isSupertypeOf(typeRef);
    }
    return false;
  }
}

class _AnyChecker extends TypeChecker {
  final Iterable<TypeChecker> _checkers;

  const _AnyChecker(this._checkers) : super._();

  @override
  bool isExactlyType(DartType typeRef) {
    if (typeRef is NamedDartType) {
      return _checkers.any((c) => c.isExactlyType(typeRef));
    }
    return false;
  }

  @override
  bool isSupertypeOf(DartType typeRef) {
    return _checkers.any((c) => c.isSupertypeOf(typeRef));
  }

  @override
  NamedDartType? matchingTypeOrSupertype(DartType typeRef) {
    for (final checker in _checkers) {
      final result = checker.matchingTypeOrSupertype(typeRef);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  @override
  bool isAssignableFromType(DartType typeRef) {
    return _checkers.any((c) => c.isAssignableFromType(typeRef));
  }
}
