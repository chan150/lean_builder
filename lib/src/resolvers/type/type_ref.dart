import 'package:analyzer/dart/ast/ast.dart';

abstract class TypeRef {
  final String? nameOverride;
  final bool isNullable;
  final String name;

  TypeRef(this.name, {required this.isNullable, this.nameOverride});

  bool get isValid => this is! _InvalidTypeRef;

  factory TypeRef.from(TypeAnnotation? type, {String? nameOverride}) {
    if (type == null) {
      return _InvalidTypeRef();
    } else if (type is NamedType) {
      return NamedTypeRef.from(type, nameOverride: nameOverride);
    } else if (type is GenericFunctionType) {
      return FunctionTypeRef.from(type, nameOverride: nameOverride);
    } else if (type is RecordTypeAnnotation) {
      return RecordTypeRef.from(type, nameOverride: nameOverride);
    } else {
      throw UnimplementedError('Unknown type: $type');
    }
  }
}

class _InvalidTypeRef extends TypeRef {
  _InvalidTypeRef() : super('', isNullable: false);
}

class NamedTypeRef extends TypeRef {
  final List<TypeRef> typeArguments;
  final String? importPrefix;

  bool get hasTypeArguments => typeArguments.isNotEmpty;

  NamedTypeRef(
    super.name, {
    required super.isNullable,
    required this.typeArguments,
    super.nameOverride,
    this.importPrefix,
  });

  factory NamedTypeRef.from(NamedType namedType, {String? nameOverride}) {
    final typeArguments = namedType.typeArguments?.arguments.map((e) {
      return TypeRef.from(e);
    });
    return NamedTypeRef(
      namedType.name2.lexeme,
      isNullable: namedType.question != null,
      typeArguments: [...?typeArguments],
      importPrefix: namedType.importPrefix?.name.lexeme,
    );
  }
}

class FunctionTypeRef extends TypeRef {
  final FormalParameterList parameters;
  final TypeParameterList? typeParameters;
  final TypeRef returnType;

  FunctionTypeRef(
    super.name, {
    required super.isNullable,
    required this.parameters,
    this.typeParameters,
    required this.returnType,
    super.nameOverride,
  });

  factory FunctionTypeRef.from(GenericFunctionType functionType, {String? nameOverride}) {
    return FunctionTypeRef(
      'Function',
      isNullable: functionType.question != null,
      parameters: functionType.parameters,
      typeParameters: functionType.typeParameters,
      returnType: TypeRef.from(functionType.returnType),
    );
  }
}

class RecordTypeRef extends TypeRef {
  NodeList<RecordTypeAnnotationNamedField>? namedFields;
  NodeList<RecordTypeAnnotationPositionalField> positionalFields;

  RecordTypeRef(
    super.name, {
    required super.isNullable,
    required this.positionalFields,
    this.namedFields,
    super.nameOverride,
  });

  factory RecordTypeRef.from(RecordTypeAnnotation recordType, {String? nameOverride}) {
    return RecordTypeRef(
      'Record',
      isNullable: recordType.question != null,
      positionalFields: recordType.positionalFields,
      namedFields: recordType.namedFields?.fields,
      nameOverride: nameOverride,
    );
  }
}
