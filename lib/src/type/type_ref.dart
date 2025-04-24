import 'package:analyzer/dart/element/type.dart';
import 'package:lean_builder/src/element/element.dart';
import 'package:collection/collection.dart';
import 'package:lean_builder/src/graph/identifier_ref.dart' show DeclarationRef;

sealed class TypeRef {
  const TypeRef();

  bool get isNullable;

  bool get isValid => this != invalidType;

  static const voidType = NonElementTypeRef('void', isNullable: false);
  static const dynamicType = NonElementTypeRef('dynamic', isNullable: true);
  static const neverType = NonElementTypeRef('Never', isNullable: false);
  static const invalidType = NonElementTypeRef('Invalid', isNullable: false);

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

  TypeRef withNullability(bool isNullable);
}

abstract class NamedTypeRef extends TypeRef {
  String get name;

  List<TypeRef> get typeArguments;

  String? get importPrefix;

  DeclarationRef get src;

  /// then identifier that points to declaration of this type
  String get identifier;

  bool isExactly(TypeRef other);
}

abstract class TypeRefImpl extends TypeRef {
  @override
  final bool isNullable;

  const TypeRefImpl({required this.isNullable});

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
  bool operator ==(Object other) => identical(this, other) || other is TypeRefImpl && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  @override
  TypeRef withNullability(bool isNullable);
}

class NonElementTypeRef extends TypeRefImpl {
  const NonElementTypeRef(this.name, {required super.isNullable});

  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NonElementTypeRef && runtimeType == other.runtimeType;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;

  @override
  NonElementTypeRef withNullability(bool isNullable) {
    return this;
  }

  @override
  bool get isVoid => name == 'void';

  @override
  bool get isDynamic => name == 'dynamic';

  @override
  bool get isNever => name == 'Never';

  @override
  bool get isInvalid => name == 'Invalid';
}

class NamedTypeRefImpl extends TypeRefImpl implements NamedTypeRef {
  @override
  String get identifier => '$name@${src.srcId}';

  @override
  final List<TypeRef> typeArguments;

  @override
  final String? importPrefix;

  @override
  final String name;

  @override
  final DeclarationRef src;

  NamedTypeRefImpl(this.name, this.src, {super.isNullable = false, this.typeArguments = const [], this.importPrefix});

  String get _srcName => src.srcUri.toString();

  @override
  bool get isDartCoreBool => name == 'bool' && _srcName == 'dart:core/bool.dart';

  @override
  bool get isDartCoreDouble => name == 'double' && _srcName == 'dart:core/double.dart';

  @override
  bool get isDartCoreEnum => name == 'Enum' && _srcName == 'dart:core/enum.dart';

  @override
  bool get isDartCoreFunction => name == 'Function' && _srcName == 'dart:core/function.dart';

  @override
  bool get isDartCoreInt => name == 'int' && _srcName == 'dart:core/int.dart';

  @override
  bool get isDartCoreNum => name == 'num' && _srcName == 'dart:core/num.dart';

  @override
  bool get isDartCoreIterable => name == 'Iterable' && _srcName == 'dart:core/iterable.dart';

  @override
  bool get isDartCoreList => name == 'List' && _srcName == 'dart:core/list.dart';

  @override
  bool get isDartCoreMap => name == 'Map' && _srcName == 'dart:core/map.dart';

  @override
  bool get isDartCoreNull => name == 'Null' && _srcName == 'dart:core/null.dart';

  @override
  bool get isDartCoreObject => name == 'Object' && _srcName == 'dart:core/object.dart';

  @override
  bool get isDartCoreRecord => name == 'Record' && _srcName == 'dart:core/record.dart';

  @override
  bool get isDartCoreSet => name == 'Set' && _srcName == 'dart:core/set.dart';

  @override
  bool get isDartCoreString => name == 'String' && _srcName == 'dart:core/string.dart';

  @override
  bool get isDartCoreSymbol => name == 'Symbol' && _srcName == 'dart:core/symbol.dart';

  @override
  bool get isDartCoreType => name == 'Type' && _srcName == 'dart:core/type.dart';

  @override
  bool get isDartAsyncFuture => name == 'Future' && _srcName == 'dart:async/future.dart';

  @override
  bool get isDartAsyncFutureOr => name == 'FutureOr' && _srcName == 'dart:async/future.dart';

  @override
  bool get isDartAsyncStream => name == 'Stream' && _srcName == 'dart:async/stream.dart';

  @override
  bool get isDartCoreBigInt => name == 'BigInt' && _srcName == 'dart:core/bigint.dart';

  @override
  bool get isDartCoreDateTime => name == 'DateTime' && _srcName == 'dart:core/date_time.dart';

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
  NamedTypeRefImpl withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return NamedTypeRefImpl(
      name,
      src,
      isNullable: isNullable,
      typeArguments: typeArguments,
      importPrefix: importPrefix,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NamedTypeRefImpl &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          src.srcId == other.src.srcId &&
          const ListEquality().equals(typeArguments, other.typeArguments);

  @override
  int get hashCode => name.hashCode ^ src.srcId.hashCode ^ const ListEquality().hash(typeArguments);

  @override
  bool isExactly(TypeRef other) {
    if (other is NamedTypeRef) {
      return name == other.name && src.srcId == other.src.srcId;
    }
    return false;
  }
}

class FunctionTypeRef extends TypeRefImpl {
  final List<ParameterElement> parameters;
  final List<TypeParameterTypeRef> typeParameters;
  final TypeRef returnType;

  FunctionTypeRef({
    required super.isNullable,
    required this.parameters,
    this.typeParameters = const [],
    required this.returnType,
  });

  @override
  FunctionTypeRef withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return FunctionTypeRef(
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
    if (returnType != TypeRef.neverType) {
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
      other is FunctionTypeRef &&
          runtimeType == other.runtimeType &&
          const ListEquality().equals(parameters, other.parameters) &&
          const ListEquality().equals(typeParameters, other.typeParameters) &&
          returnType == other.returnType;

  @override
  int get hashCode =>
      const ListEquality().hash(parameters) ^ const ListEquality().hash(typeParameters) ^ returnType.hashCode;
}

class TypeParameterTypeRef extends TypeRefImpl {
  final TypeRef bound;
  final String name;

  TypeParameterTypeRef(this.name, {required this.bound, super.isNullable = false});

  @override
  TypeParameterTypeRef withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return TypeParameterTypeRef(name, bound: bound, isNullable: isNullable);
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(name);
    if (bound != TypeRef.dynamicType) {
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
      other is TypeParameterTypeRef && runtimeType == other.runtimeType && bound == other.bound && name == other.name;

  @override
  int get hashCode => bound.hashCode;
}

class RecordTypeRef extends TypeRefImpl {
  List<RecordTypeNamedField> namedFields;
  List<RecordTypePositionalField> positionalFields;

  RecordTypeRef({required this.positionalFields, required this.namedFields, required super.isNullable});

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
  RecordTypeRef withNullability(bool isNullable) {
    if (this.isNullable == isNullable) {
      return this;
    }
    return RecordTypeRef(positionalFields: positionalFields, namedFields: namedFields, isNullable: isNullable);
  }
}

abstract class RecordTypeField {
  /// The type of the field.
  TypeRef get type;

  const RecordTypeField();
}

/// A named field in a [RecordType].
///
/// Clients may not extend, implement or mix-in this class.
class RecordTypeNamedField implements RecordTypeField {
  /// The name of the field.
  final String name;

  @override
  final TypeRef type;

  RecordTypeNamedField(this.name, this.type);
}

/// A positional field in a [RecordType].
///
/// Clients may not extend, implement or mix-in this class.
class RecordTypePositionalField implements RecordTypeField {
  @override
  final TypeRef type;

  const RecordTypePositionalField(this.type);
}
