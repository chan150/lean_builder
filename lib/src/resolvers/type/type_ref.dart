import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_genie/src/resolvers/element_resolver.dart';

abstract class TypeRef {
  final bool isNullable;
  final String name;

  TypeRef(this.name, {required this.isNullable});

  bool get isValid => this is! _InvalidTypeRef;

  factory TypeRef.from(TypeAnnotation? type) {
    if (type == null) {
      return _InvalidTypeRef();
    } else if (type is NamedType) {
      return NamedTypeRef.from(type);
    } else if (type is GenericFunctionType) {
      return FunctionTypeRef.from(type);
    } else if (type is RecordTypeAnnotation) {
      return RecordTypeRef.from(type);
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
  final IdentifierRef? identifierRef;

  bool get hasTypeArguments => typeArguments.isNotEmpty;

  NamedTypeRef(
    super.name, {
    required super.isNullable,
    required this.typeArguments,
    this.identifierRef,
    this.importPrefix,
  });

  factory NamedTypeRef.from(NamedType namedType, {IdentifierRef? identifierRef}) {
    final typeArguments = namedType.typeArguments?.arguments.map((e) {
      return TypeRef.from(e);
    });
    return NamedTypeRef(
      namedType.name2.lexeme,
      isNullable: namedType.question != null,
      typeArguments: [...?typeArguments],
      importPrefix: namedType.importPrefix?.name.lexeme,
      identifierRef: identifierRef,
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
  });

  factory FunctionTypeRef.from(GenericFunctionType functionType) {
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

  RecordTypeRef(super.name, {required super.isNullable, required this.positionalFields, this.namedFields});

  factory RecordTypeRef.from(RecordTypeAnnotation recordType) {
    return RecordTypeRef(
      'Record',
      isNullable: recordType.question != null,
      positionalFields: recordType.positionalFields,
      namedFields: recordType.namedFields?.fields,
    );
  }
}
