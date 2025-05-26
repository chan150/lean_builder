import 'package:lean_builder/src/element/element.dart';
import 'package:lean_builder/src/type/type.dart';

/// Represents a substitution of type parameters with concrete types.
class Substitution {
  /// The underlying map that stores the type parameter to type argument mappings.
  final Map<TypeParameterType, DartType> _map;

  /// Creates a [Substitution] with the given map.
  Substitution(this._map);

  /// Creates a substitution that maps the given type parameters to the
  /// corresponding type arguments.
  factory Substitution.fromPairs(
    List<TypeParameterType> typeParameters,
    List<DartType> typeArguments,
  ) {
    final Map<TypeParameterType, DartType> map = <TypeParameterType, DartType>{};
    for (int i = 0; i < typeParameters.length; i++) {
      if (i >= typeArguments.length) {
        map[typeParameters[i]] = DartType.dynamicType;
      } else {
        map[typeParameters[i]] = typeArguments[i];
      }
    }
    return Substitution(map);
  }

  /// Applies this substitution to the given [type].
  ///
  /// If [isNullable] is true, the resulting type will be nullable.
  DartType substituteType(DartType type, {bool isNullable = false}) {
    if (type is TypeParameterType) {
      return _map[type]?.withNullability(type.isNullable) ?? type;
    } else if (type is InterfaceTypeImpl) {
      if (type.typeArguments.isEmpty) {
        return type;
      }
      final List<DartType> substitutedTypeArgs = type.typeArguments
          .map((DartType typeArg) => substituteType(typeArg))
          .toList();
      return InterfaceTypeImpl(
        type.name,
        type.declarationRef,
        type.resolver,
        typeArguments: substitutedTypeArgs,
        isNullable: isNullable,
      );
    } else if (type is TypeAliasTypeImpl) {
      if (type.typeArguments.isEmpty) {
        return type;
      }
      final List<DartType> substitutedTypeArgs = type.typeArguments
          .map((DartType typeArg) => substituteType(typeArg))
          .toList();
      return TypeAliasTypeImpl(
        type.name,
        type.declarationRef,
        type.resolver,
        typeArguments: substitutedTypeArgs,
        isNullable: isNullable,
      );
    } else if (type is FunctionType) {
      final DartType returnType = substituteType(type.returnType);
      final List<ParameterElement> parameters = type.parameters.map((ParameterElement param) {
        if (param is ParameterElementImpl) {
          param.type = substituteType(param.type);
        }
        return param;
      }).toList();
      return FunctionType(
        returnType: returnType,
        typeParameters: type.typeParameters,
        parameters: parameters,
        isNullable: isNullable,
      );
    } else if (type is RecordType) {
      final List<RecordTypePositionalField> positionalFields = <RecordTypePositionalField>[];
      for (final RecordTypePositionalField field in type.positionalFields) {
        positionalFields.add(
          RecordTypePositionalField(substituteType(field.type)),
        );
      }
      final List<RecordTypeNamedField> namedFields = <RecordTypeNamedField>[];
      for (final RecordTypeNamedField field in type.namedFields) {
        namedFields.add(
          RecordTypeNamedField(field.name, substituteType(field.type)),
        );
      }
      return RecordType(
        positionalFields: positionalFields,
        namedFields: namedFields,
        isNullable: isNullable,
      );
    }
    return type.withNullability(isNullable);
  }
}
