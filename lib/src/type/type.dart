import 'package:lean_builder/builder.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:collection/collection.dart';
import 'package:lean_builder/src/graph/identifier_ref.dart' show DeclarationRef;
import 'package:lean_builder/src/type/substitution.dart';

import 'core_type_source.dart';

sealed class DartType {
  const DartType();

  bool get isNullable;

  /// Return the element representing the declaration of this type, or `null`
  /// if the type is not associated with an element.
  Element? get element;

  bool get isValid => this != invalidType;

  /// returns the name of the type if it's a named type
  /// otherwise returns null
  String? get name;

  static const voidType = VoidType.instance;
  static const dynamicType = DynamicType.instance;
  static const neverType = NeverType.instance;
  static const invalidType = InvalidType.instance;
  static const unknownInferredType = UnknownInferredType.instance;

  /// Return `true` if this type represents the type 'void'
  bool get isVoid;

  /// Return `true` if this type represents the type 'dynamic'
  bool get isDynamic;

  /// Return `true` if this type represents the type 'Never'
  bool get isNever;

  /// Return `true` if this type represents the type 'Invalid'
  bool get isInvalid;

  /// Return `true` if this type represents the type 'Future' defined in the
  /// dart:async library.
  bool get isDartAsyncFuture;

  /// Return `true` if this type represents the type 'FutureOr&lt;T&gt;' defined in
  /// the dart:async library.
  bool get isDartAsyncFutureOr;

  /// Return `true` if this type represents the type 'Stream' defined in the
  /// dart:async library.
  bool get isDartAsyncStream;

  /// Return `true` if this type represents the type 'bool' defined in the
  /// dart:core library.
  bool get isDartCoreBool;

  /// Return `true` if this type represents the type 'double' defined in the
  /// dart:core library.
  bool get isDartCoreDouble;

  /// Return `true` if this type represents the type 'Enum' defined in the
  /// dart:core library.
  bool get isDartCoreEnum;

  /// Return `true` if this type represents the type 'Function' defined in the
  /// dart:core library.
  bool get isDartCoreFunction;

  /// Return `true` if this type represents the type 'int' defined in the
  /// dart:core library.
  bool get isDartCoreInt;

  /// Return `true` if this type represents the type 'BigInt' defined in the
  /// dart:core library.
  bool get isDartCoreBigInt;

  /// Returns `true` if this type represents the type 'Iterable' defined in the
  /// dart:core library.
  bool get isDartCoreIterable;

  /// Returns `true` if this type represents the type 'List' defined in the
  /// dart:core library.
  bool get isDartCoreList;

  /// Returns `true` if this type represents the type 'Map' defined in the
  /// dart:core library.
  bool get isDartCoreMap;

  /// Return `true` if this type represents the type 'Null' defined in the
  /// dart:core library.
  bool get isDartCoreNull;

  /// Return `true` if this type represents the type 'num' defined in the
  /// dart:core library.
  bool get isDartCoreNum;

  /// Return `true` if this type represents the type `Object` defined in the
  /// dart:core library.
  bool get isDartCoreObject;

  /// Return `true` if this type represents the type 'Record' defined in the
  /// dart:core library.
  bool get isDartCoreRecord;

  /// Returns `true` if this type represents the type 'Set' defined in the
  /// dart:core library.
  bool get isDartCoreSet;

  /// Return `true` if this type represents the type 'String' defined in the
  /// dart:core library.
  bool get isDartCoreString;

  /// Returns `true` if this type represents the type 'Symbol' defined in the
  /// dart:core library.
  bool get isDartCoreSymbol;

  /// Return `true` if this type represents the type 'Type' defined in the
  /// dart:core library.
  bool get isDartCoreType;

  /// Return `true` if this type represents the type 'DateTime' defined in the
  /// dart:core library.
  bool get isDartCoreDateTime;

  DartType withNullability(bool isNullable);
}

abstract class ParameterizedType extends DartType {
  List<DartType> get typeArguments;
}

// could be a type alias or a interface type
abstract class NamedDartType extends ParameterizedType {
  @override
  String get name;

  Resolver get resolver;

  @override
  List<DartType> get typeArguments;

  DeclarationRef get declarationRef;

  /// then identifier that points to declaration of this type
  String get identifier;

  bool isExactly(DartType other);
}

abstract class TypeImpl extends DartType {
  @override
  final bool isNullable;

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

abstract class NonElementType extends TypeImpl {
  const NonElementType(this.name, {required super.isNullable});

  @override
  Null get element => null;

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

class VoidType extends NonElementType {
  const VoidType._() : super('void', isNullable: false);

  static const VoidType instance = VoidType._();

  @override
  bool get isVoid => true;
}

class DynamicType extends NonElementType {
  const DynamicType._() : super('dynamic', isNullable: true);

  static const DynamicType instance = DynamicType._();

  @override
  bool get isDynamic => true;
}

class NeverType extends NonElementType {
  const NeverType._() : super('Never', isNullable: false);

  static const NeverType instance = NeverType._();

  @override
  bool get isNever => true;
}

class InvalidType extends NonElementType {
  const InvalidType._() : super('Invalid', isNullable: false);

  static const InvalidType instance = InvalidType._();

  @override
  bool get isInvalid => true;
}

class UnknownInferredType extends NonElementType {
  const UnknownInferredType._() : super('UnknownInferred', isNullable: false);

  static const UnknownInferredType instance = UnknownInferredType._();
}

abstract class InterfaceType extends NamedDartType {
  @override
  InterfaceElement get element;

  List<NamedDartType> get interfaces;

  List<NamedDartType> get mixins;

  NamedDartType? get superType;

  List<NamedDartType> get allSupertypes;

  MethodElement? getMethod(String name);

  FieldElement? getField(String name);

  ConstructorElement? getConstructor(String name);

  bool hasMethod(String name);

  bool hasPropertyAccessor(String name);

  bool hasField(String name);

  bool hasConstructor(String name);
}

class InterfaceTypeImpl extends TypeImpl implements InterfaceType {
  @override
  String get identifier => '$name@${declarationRef.srcId}';

  @override
  final Resolver resolver;

  @override
  final List<DartType> typeArguments;

  @override
  final String name;

  @override
  final DeclarationRef declarationRef;

  InterfaceTypeImpl(
    this.name,
    this.declarationRef,
    this.resolver, {
    super.isNullable = false,
    this.typeArguments = const [],
    InterfaceElement? element,
  }) : _element = element;

  String get _srcName => declarationRef.srcUri.toString();

  @override
  bool get isDartCoreBool => name == 'bool' && _srcName == CoreTypeSource.coreBool;

  @override
  bool get isDartCoreDouble => name == 'double' && _srcName == CoreTypeSource.coreDouble;

  @override
  bool get isDartCoreEnum => name == 'Enum' && _srcName == CoreTypeSource.coreEnum;

  @override
  bool get isDartCoreFunction => name == 'Function' && _srcName == CoreTypeSource.coreFunction;

  @override
  bool get isDartCoreInt => name == 'int' && _srcName == CoreTypeSource.coreInt;

  @override
  bool get isDartCoreNum => name == 'num' && _srcName == CoreTypeSource.coreNum;

  @override
  bool get isDartCoreIterable => name == 'Iterable' && _srcName == CoreTypeSource.coreIterable;

  @override
  bool get isDartCoreList => name == 'List' && _srcName == CoreTypeSource.coreList;

  @override
  bool get isDartCoreMap => name == 'Map' && _srcName == CoreTypeSource.coreMap;

  @override
  bool get isDartCoreNull => name == 'Null' && _srcName == CoreTypeSource.coreNull;

  @override
  bool get isDartCoreObject => name == 'Object' && _srcName == CoreTypeSource.coreObject;

  @override
  bool get isDartCoreRecord => name == 'Record' && _srcName == CoreTypeSource.coreRecord;

  @override
  bool get isDartCoreSet => name == 'Set' && _srcName == CoreTypeSource.coreSet;

  @override
  bool get isDartCoreString => name == 'String' && _srcName == CoreTypeSource.coreString;

  @override
  bool get isDartCoreSymbol => name == 'Symbol' && _srcName == CoreTypeSource.coreSymbol;

  @override
  bool get isDartCoreType => name == 'Type' && _srcName == CoreTypeSource.coreType;

  @override
  bool get isDartAsyncFuture => name == 'Future' && _srcName == CoreTypeSource.asyncFuture;

  @override
  bool get isDartAsyncFutureOr => name == 'FutureOr' && _srcName == CoreTypeSource.asyncFutureOr;

  @override
  bool get isDartAsyncStream => name == 'Stream' && _srcName == CoreTypeSource.asyncStream;

  @override
  bool get isDartCoreBigInt => name == 'BigInt' && _srcName == CoreTypeSource.coreBigInt;

  @override
  bool get isDartCoreDateTime => name == 'DateTime' && _srcName == CoreTypeSource.coreDateTime;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(name);
    if (typeArguments.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeArguments.map((e) => e.toString()).join(', '));
      buffer.write('>');
    }
    if (isNullable) {
      buffer.write('?');
    }
    return buffer.toString();
  }

  @override
  InterfaceTypeImpl withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return InterfaceTypeImpl(name, declarationRef, resolver, isNullable: isNullable, typeArguments: typeArguments);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InterfaceTypeImpl &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          declarationRef.srcId == other.declarationRef.srcId &&
          const ListEquality().equals(typeArguments, other.typeArguments);

  @override
  int get hashCode => name.hashCode ^ declarationRef.srcId.hashCode ^ const ListEquality().hash(typeArguments);

  @override
  bool isExactly(DartType other) {
    if (other is NamedDartType) {
      return name == other.name && declarationRef.srcId == other.declarationRef.srcId;
    }
    return false;
  }

  InterfaceElement? _element;

  InterfaceElement _resolveElement() {
    final ele = resolver.elementOf(this);
    if (ele is! InterfaceElement) {
      throw Exception('Element of $this (${ele.runtimeType}) is not an InterfaceElement');
    }
    return ele;
  }

  @override
  InterfaceElement get element => _element ??= _resolveElement();

  @override
  List<NamedDartType> get allSupertypes => element.allSupertypes;

  @override
  List<NamedDartType> get interfaces => element.interfaces;

  @override
  List<NamedDartType> get mixins => element.mixins;

  @override
  NamedDartType? get superType => element.superType;

  @override
  ConstructorElement? getConstructor(String name) {
    return element.getConstructor(name);
  }

  @override
  FieldElement? getField(String name) {
    return element.getField(name);
  }

  @override
  MethodElement? getMethod(String name) {
    return element.getMethod(name);
  }

  @override
  bool hasConstructor(String name) {
    return element.hasConstructor(name);
  }

  @override
  bool hasField(String name) {
    return element.hasField(name);
  }

  @override
  bool hasMethod(String name) {
    return element.hasMethod(name);
  }

  @override
  bool hasPropertyAccessor(String name) {
    return element.hasPropertyAccessor(name);
  }
}

abstract class TypeAliasType extends NamedDartType {
  @override
  TypeAliasElement get element;
}

class TypeAliasTypeImpl extends TypeImpl implements TypeAliasType {
  @override
  final List<DartType> typeArguments;

  @override
  final Resolver resolver;

  @override
  final String name;

  @override
  final DeclarationRef declarationRef;

  TypeAliasTypeImpl(
    this.name,
    this.declarationRef,
    this.resolver, {
    super.isNullable = false,
    this.typeArguments = const [],
  });

  @override
  TypeAliasElement get element => _element ??= _resolveElement();

  TypeAliasElement? _element;

  TypeAliasElement _resolveElement() {
    final ele = resolver.elementOf(this);
    if (ele is! TypeAliasElement) {
      throw Exception('Element of $this is not a TypeAliasElement');
    }
    return ele;
  }

  @override
  String get identifier => '$name@${declarationRef.srcId}';

  @override
  bool isExactly(DartType other) {
    if (other is TypeAliasTypeImpl) {
      return name == other.name && declarationRef.srcId == other.declarationRef.srcId;
    }
    return false;
  }

  @override
  DartType withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return TypeAliasTypeImpl(name, declarationRef, resolver, isNullable: isNullable, typeArguments: typeArguments);
  }
}

class FunctionType extends TypeImpl {
  final List<ParameterElement> parameters;
  final List<TypeParameterType> typeParameters;
  final DartType returnType;

  FunctionType({
    required super.isNullable,
    required this.parameters,
    this.typeParameters = const [],
    required this.returnType,
  });

  @override
  FunctionType withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return FunctionType(
      isNullable: isNullable,
      parameters: parameters,
      typeParameters: typeParameters,
      returnType: returnType,
    );
  }

  @override
  String toString() {
    final requiredPositionalParams = parameters.where((p) => p.isRequiredPositional);
    final optionalPositionalParams = parameters.where((p) => p.isOptionalPositional);
    final namedParams = parameters.where((p) => p.isNamed);

    final buffer = StringBuffer();
    if (returnType != DartType.neverType) {
      buffer.write('$returnType ');
    }
    if (typeParameters.isNotEmpty) {
      buffer.write('<');
      buffer.write(typeParameters.toString());
      buffer.write('>');
    }
    buffer.write('Function');
    if (parameters.isNotEmpty) {
      buffer.write('(');
      if (requiredPositionalParams.isNotEmpty) {
        buffer.write(requiredPositionalParams.map((e) => '${e.type} ${e.name}').join(', '));
      }
      if (optionalPositionalParams.isNotEmpty) {
        if (requiredPositionalParams.isNotEmpty) {
          buffer.write(', ');
        }
        buffer.write('[');
        buffer.write(optionalPositionalParams.map((e) => '${e.type} ${e.name}').join(', '));
        buffer.write(']');
      }
      if (namedParams.isNotEmpty) {
        if (requiredPositionalParams.isNotEmpty || optionalPositionalParams.isNotEmpty) {
          buffer.write(', ');
        }
        buffer.write('{');
        buffer.write(namedParams.map((e) => '${e.type} ${e.name}').join(', '));
        buffer.write('}');
      }
      buffer.write(')');
    }
    if (isNullable) {
      buffer.write('?');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FunctionType &&
          runtimeType == other.runtimeType &&
          const ListEquality().equals(parameters, other.parameters) &&
          const ListEquality().equals(typeParameters, other.typeParameters) &&
          returnType == other.returnType;

  @override
  int get hashCode =>
      const ListEquality().hash(parameters) ^ const ListEquality().hash(typeParameters) ^ returnType.hashCode;

  Map<String, DartType> get namedParameterTypes {
    Map<String, DartType> types = <String, DartType>{};
    for (final parameter in parameters) {
      if (parameter.isNamed && parameter.isRequiredNamed) {
        types[parameter.name] = parameter.type;
      }
    }
    return types;
  }

  List<DartType> get normalParameterTypes {
    List<DartType> types = <DartType>[];
    for (final parameter in parameters) {
      if (parameter.isRequired) {
        types.add(parameter.type);
      }
    }
    return types;
  }

  List<DartType> get optionalParameterTypes {
    List<DartType> types = <DartType>[];
    for (final parameter in parameters) {
      if (parameter.isOptional) {
        types.add(parameter.type);
      }
    }
    return types;
  }

  List<String> get normalParameterNames => parameters.where((p) => p.isRequiredPositional).map((p) => p.name).toList();

  List<String> get optionalParameterNames =>
      parameters.where((p) => p.isOptionalPositional).map((p) => p.name).toList();

  @override
  Null get element => null;

  FunctionType instantiate(List<DartType> argumentTypes) {
    if (argumentTypes.length != typeParameters.length) {
      throw ArgumentError(
        "argumentTypes.length (${argumentTypes.length}) != "
        "typeParameters.length (${typeParameters.length})",
      );
    }
    if (argumentTypes.isEmpty) {
      return this;
    }

    var substitution = Substitution.fromPairs(typeParameters, argumentTypes);

    final newParams = List.of(parameters);
    for (final param in parameters.whereType<ParameterElementImpl>()) {
      param.type = substitution.substituteType(param.type);
    }

    return FunctionType(
      returnType: substitution.substituteType(returnType),
      typeParameters: const [],
      parameters: newParams,
      isNullable: isNullable,
    );
  }
}

class TypeParameterType extends TypeImpl {
  final DartType bound;

  /// todo: investigate if implemented this is needed in the const context
  /// for now it always returns null
  final DartType? promotedBound;

  @override
  final String name;

  TypeParameterType(this.name, {required this.bound, super.isNullable = false, this.promotedBound});

  @override
  TypeParameterType withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return TypeParameterType(name, bound: bound, isNullable: isNullable);
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(name);
    if (bound != DartType.dynamicType) {
      buffer.write(' extends ');
      buffer.write(bound.toString());
    }
    if (isNullable) {
      buffer.write('?');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeParameterType && runtimeType == other.runtimeType && bound == other.bound && name == other.name;

  @override
  int get hashCode => bound.hashCode;

  @override
  Null get element => null;
}

class RecordType extends TypeImpl {
  List<RecordTypeNamedField> namedFields;
  List<RecordTypePositionalField> positionalFields;

  RecordType({required this.positionalFields, required this.namedFields, required super.isNullable});

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('(');
    if (positionalFields.isNotEmpty) {
      buffer.write(positionalFields.mapIndexed((i, e) => '${e.type} ${r'$'}${i + 1}').join(', '));
    }
    if (namedFields.isNotEmpty) {
      if (positionalFields.isNotEmpty) {
        buffer.write(', ');
      }
      buffer.write('{');
      buffer.write(namedFields.map((e) => '${e.type} ${e.name}').join(', '));
      buffer.write('}');
    }
    buffer.write(')');
    if (isNullable) {
      buffer.write('?');
    }
    return buffer.toString();
  }

  @override
  RecordType withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return RecordType(positionalFields: positionalFields, namedFields: namedFields, isNullable: isNullable);
  }

  @override
  Element? get element => null;
}

abstract class RecordTypeField {
  /// The type of the field.
  DartType get type;

  const RecordTypeField();
}

/// A named field in a [RecordType].
///
/// Clients may not extend, implement or mix-in this class.
class RecordTypeNamedField implements RecordTypeField {
  /// The name of the field.
  final String name;

  @override
  final DartType type;

  RecordTypeNamedField(this.name, this.type);
}

/// A positional field in a [RecordType].
///
/// Clients may not extend, implement or mix-in this class.
class RecordTypePositionalField implements RecordTypeField {
  @override
  final DartType type;

  const RecordTypePositionalField(this.type);
}
