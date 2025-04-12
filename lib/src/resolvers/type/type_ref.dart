import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_genie/src/scanner/identifier_ref.dart';
import 'package:code_genie/src/resolvers/element/element.dart';

abstract class TypeRef {
  final bool isNullable;
  final String name;

  const TypeRef(this.name, {required this.isNullable});

  bool get isValid => this != invalidType;

  static const voidType = _NoElementType('void', isNullable: false);
  static const dynamicType = _NoElementType('dynamic', isNullable: true);
  static const neverType = _NoElementType('Never', isNullable: false);
  static const nullType = _NoElementType('Null', isNullable: true);
  static const invalidType = _NoElementType('Invalid', isNullable: false);

  static bool isVoid(String name) {
    return voidType.name == name;
  }

  static bool isDynamic(String name) {
    return dynamicType.name == name;
  }

  static bool isNever(String name) {
    return neverType.name == name;
  }

  static bool isNull(String name) {
    return nullType.name == name;
  }

  static bool isVoidOrDynamic(String name) {
    return isVoid(name) || isDynamic(name);
  }
}

class _NoElementType extends TypeRef {
  const _NoElementType(super.name, {required super.isNullable});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _NoElementType && runtimeType == other.runtimeType;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

abstract class SourcedTypeRef extends TypeRef {
  final IdentifierSrc src;

  SourcedTypeRef(super.name, this.src, {required super.isNullable});
}

class NamedTypeRef extends SourcedTypeRef {
  final List<TypeRef> typeArguments;
  final String? importPrefix;

  // final IdentifierRef? identifierRef;

  bool get hasTypeArguments => typeArguments.isNotEmpty;

  NamedTypeRef(
    super.name,
    super.src, {
    super.isNullable = false,
    this.typeArguments = const [],
    // this.identifierRef,
    this.importPrefix,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(name);
    if (hasTypeArguments) {
      buffer.write('<');
      buffer.write(typeArguments.map((e) => e.toString()).join(', '));
      buffer.write('>');
    }
    if (isNullable) {
      buffer.write('?');
    }
    return buffer.toString();
  }
}

class InterfaceTypeRef extends NamedTypeRef {
  InterfaceTypeRef(
    super.name,
    super.src, {
    this.interfaces = const [],
    this.mixins = const [],
    this.superclass,
    this.superclassConstraints = const [],
    super.isNullable = false,
    super.typeArguments = const [],
  });

  final List<InterfaceTypeRef> interfaces;
  final List<InterfaceTypeRef> mixins;

  final InterfaceTypeRef? superclass;

  final List<InterfaceTypeRef> superclassConstraints;
}

class FunctionTypeRef extends TypeRef {
  final FormalParameterList? parameters;
  final TypeParameterList? typeParameters;
  final TypeRef returnType;

  FunctionTypeRef(
    super.name, {
    required super.isNullable,
    required this.parameters,
    this.typeParameters,
    required this.returnType,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    if (typeParameters != null) {
      buffer.write('<');
      buffer.write(typeParameters.toString());
      buffer.write('>');
    }
    buffer.write(name);
    if (parameters != null) {
      buffer.write(parameters.toString());
    }
    if (isNullable) {
      buffer.write('?');
    }
    return buffer.toString();
  }
}

class TypeParameterTypeRef extends TypeRef {
  final TypeRef bound;

  final TypeParameterElement element;

  TypeParameterTypeRef(this.element, {required this.bound, required super.isNullable}) : super(element.name);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(name);
    if (isNullable) {
      buffer.write('?');
    }
    return buffer.toString();
  }
}

// class RecordTypeRef extends TypeRef {
//   NodeList<RecordTypeAnnotationNamedField>? namedFields;
//   NodeList<RecordTypeAnnotationPositionalField> positionalFields;
//
//   RecordTypeRef(super.name, {required super.isNullable, required this.positionalFields, this.namedFields});
//
//   factory RecordTypeRef.from(RecordTypeAnnotation recordType) {
//     return RecordTypeRef(
//       'Record',
//       isNullable: recordType.question != null,
//       positionalFields: recordType.positionalFields,
//       namedFields: recordType.namedFields?.fields,
//     );
//   }
// }
