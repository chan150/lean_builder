import 'package:collection/collection.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/graph/identifier_ref.dart' show DeclarationRef;
import 'package:lean_builder/src/resolvers/resolver.dart';
import 'package:lean_builder/src/type/substitution.dart';

import 'core_type_source.dart';

part 'type_impl.dart';

/// {@template dart_type}
/// Base class representing a Dart type in the type system.
///
/// This is the foundation for all types in Dart, including primitive types,
/// interface types, function types, and special types.
/// {@endtemplate}
abstract class DartType {
  /// A const constructor for [DartType].
  const DartType();

  /// Whether this type is nullable.
  bool get isNullable;

  /// Return the element representing the declaration of this type, or `null`
  /// if the type is not associated with an element.
  Element? get element;

  /// Returns whether this type is valid (not an [invalidType]).
  bool get isValid => this != invalidType;

  /// returns the name of the type if it's a named type
  /// otherwise returns null
  String? get name;

  /// {@template core_type_constant}
  /// The predefined type representing `{TYPE}`.
  /// {@endtemplate}

  /// {@macro core_type_constant}
  static const VoidType voidType = VoidType.instance;

  /// {@macro core_type_constant}
  static const DynamicType dynamicType = DynamicType.instance;

  /// {@macro core_type_constant}
  static const NeverType neverType = NeverType.instance;

  /// {@macro core_type_constant}
  static const InvalidType invalidType = InvalidType.instance;

  /// {@macro core_type_constant}
  static const UnknownInferredType unknownInferredType = UnknownInferredType.instance;

  /// Return `true` if this type represents the type 'void'
  bool get isVoid;

  /// Return `true` if this type represents the type 'dynamic'
  bool get isDynamic;

  /// Return `true` if this type represents the type 'Never'
  bool get isNever;

  /// Return `true` if this type represents the type 'Invalid'
  bool get isInvalid;

  /// {@template dart_async_check}
  /// Return `true` if this type represents the type '{TYPE}' defined in the
  /// dart:async library.
  /// {@endtemplate}

  /// {@macro dart_async_check}
  bool get isDartAsyncFuture;

  /// {@macro dart_async_check}
  bool get isDartAsyncFutureOr;

  /// {@macro dart_async_check}
  bool get isDartAsyncStream;

  /// {@template dart_core_check}
  /// Return `true` if this type represents the type '{TYPE}' defined in the
  /// dart:core library.
  /// {@endtemplate}

  /// {@macro dart_core_check}
  bool get isDartCoreBool;

  /// {@macro dart_core_check}
  bool get isDartCoreDouble;

  /// {@macro dart_core_check}
  bool get isDartCoreEnum;

  /// {@macro dart_core_check}
  bool get isDartCoreFunction;

  /// {@macro dart_core_check}
  bool get isDartCoreInt;

  /// {@macro dart_core_check}
  bool get isDartCoreBigInt;

  /// {@macro dart_core_check}
  bool get isDartCoreIterable;

  /// {@macro dart_core_check}
  bool get isDartCoreList;

  /// {@macro dart_core_check}
  bool get isDartCoreMap;

  /// {@macro dart_core_check}
  bool get isDartCoreNull;

  /// {@macro dart_core_check}
  bool get isDartCoreNum;

  /// {@macro dart_core_check}
  bool get isDartCoreObject;

  /// {@macro dart_core_check}
  bool get isDartCoreRecord;

  /// {@macro dart_core_check}
  bool get isDartCoreSet;

  /// {@macro dart_core_check}
  bool get isDartCoreString;

  /// {@macro dart_core_check}
  bool get isDartCoreSymbol;

  /// {@macro dart_core_check}
  bool get isDartCoreType;

  /// {@macro dart_core_check}
  bool get isDartCoreDateTime;

  /// Returns a copy of this type with the specified nullability.
  DartType withNullability(bool isNullable);
}

/// {@template parameterized_type}
/// Represents a type that can be parameterized with type arguments.
///
/// Examples include generic classes like List<T> and Map<K,V>.
/// {@endtemplate}
abstract class ParameterizedType extends DartType {
  /// The list of type arguments for this parameterized type.
  List<DartType> get typeArguments;
}

/// {@template named_dart_type}
/// Represents a Dart type that has a name.
///
/// This could be a type alias or an interface type.
/// {@endtemplate}
abstract class NamedDartType extends ParameterizedType {
  /// The name of this type.
  @override
  String get name;

  /// The resolver used to resolve this type.
  ResolverImpl get resolver;

  /// The type arguments applied to this type.
  @override
  List<DartType> get typeArguments;

  /// Reference to the declaration of this type.
  DeclarationRef get declarationRef;

  /// then identifier that points to declaration of this type
  String get identifier;

  /// Determines if this type is exactly the same as [other].
  bool isExactly(DartType other);
}

/// {@template type_impl}
/// Base implementation of the [DartType] interface.
///
/// Provides default implementations for many methods.
/// {@endtemplate}
abstract class TypeImpl extends DartType {
  /// Whether this type is nullable.
  @override
  final bool isNullable;

  /// Creates a new [TypeImpl] with the specified nullability.
  const TypeImpl({required this.isNullable});

  @override
  bool get isDartAsyncFuture => false;

  @override
  bool get isDartAsyncFutureOr => false;

  @override
  bool get isDartAsyncStream => false;

  @override
  bool get isDartCoreBool => false;

  @override
  bool get isDartCoreDouble => false;

  @override
  bool get isDartCoreEnum => false;

  @override
  bool get isDartCoreFunction => false;

  @override
  bool get isDartCoreInt => false;

  @override
  bool get isDartCoreIterable => false;

  @override
  bool get isDartCoreList => false;

  @override
  bool get isDartCoreMap => false;

  @override
  bool get isDartCoreNull => false;

  @override
  bool get isDartCoreNum => false;

  @override
  bool get isDartCoreObject => false;

  @override
  bool get isDartCoreRecord => false;

  @override
  bool get isDartCoreSet => false;

  @override
  bool get isDartCoreString => false;

  @override
  bool get isDartCoreSymbol => false;

  @override
  bool get isDartCoreType => false;

  @override
  bool get isDartCoreDateTime => false;

  @override
  bool get isDartCoreBigInt => false;

  @override
  bool get isVoid => false;

  @override
  bool get isDynamic => false;

  @override
  bool get isNever => false;

  @override
  bool get isInvalid => false;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TypeImpl && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  @override
  DartType withNullability(bool isNullable);

  @override
  String? get name => null;
}

/// {@template non_element_type}
/// Represents a type that is not associated with an element in the source code.
///
/// Examples include special types like void, dynamic, and Never.
/// {@endtemplate}
abstract class NonElementType extends TypeImpl {
  /// Creates a new [NonElementType] with the given name and nullability.
  const NonElementType(this.name, {required super.isNullable});

  /// Non-element types don't have an associated element.
  @override
  Null get element => null;

  /// The name of this non-element type.
  @override
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NonElementType && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;

  @override
  NonElementType withNullability(bool isNullable) => this;
}

/// {@template interface_type}
/// Represents a class, mixin, or interface type in Dart.
///
/// Provides access to the type's members, interfaces, and inheritance hierarchy.
/// {@endtemplate}
abstract class InterfaceType extends NamedDartType {
  /// The element that declares this interface type.
  @override
  InterfaceElement get element;

  /// The list of interfaces implemented by this type.
  List<NamedDartType> get interfaces;

  /// The list of mixins applied to this type.
  List<NamedDartType> get mixins;

  /// The super type of this interface type, or null if it's Object.
  NamedDartType? get superType;

  /// All direct and indirect supertypes of this interface type.
  List<NamedDartType> get allSupertypes;

  /// Returns the method with the given [name], or null if not found.
  MethodElement? getMethod(String name);

  /// Returns the field with the given [name], or null if not found.
  FieldElement? getField(String name);

  /// Returns the constructor with the given [name], or null if not found.
  ConstructorElement? getConstructor(String name);

  /// Returns true if this type has a method with the given [name].
  bool hasMethod(String name);

  /// Returns true if this type has a property accessor with the given [name].
  bool hasPropertyAccessor(String name);

  /// Returns true if this type has a field with the given [name].
  bool hasField(String name);

  /// Returns true if this type has a constructor with the given [name].
  bool hasConstructor(String name);
}

/// {@template type_alias_type}
/// Represents a type alias defined using the `typedef` keyword.
///
/// Type aliases provide alternative names for existing types.
/// {@endtemplate}
abstract class TypeAliasType extends NamedDartType {
  /// The element that declares this type alias.
  @override
  TypeAliasElement get element;
}

/// {@template record_type_field}
/// Represents a field in a record type.
///
/// Record types in Dart are composite types with named or positional fields.
/// {@endtemplate}
abstract class RecordTypeField {
  /// The type of the field.
  DartType get type;

  /// Creates a new record type field.
  const RecordTypeField();
}
